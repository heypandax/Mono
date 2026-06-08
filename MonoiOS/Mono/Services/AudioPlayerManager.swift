//
//  AudioPlayerManager.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation
import AVFoundation
import MediaPlayer

// MARK: - 通知名称
extension Notification.Name {
    static let sleepTimerDidChange = Notification.Name("sleepTimerDidChange")
}

protocol AudioPlayerDelegate: AnyObject {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval)
    func playerDidChangePlayingState(_ isPlaying: Bool)
    func playerDidChangeTrack(_ track: AudioTrack?)
    func playerDidFinishTrack()
    func playerDidFailToLoad(_ track: AudioTrack)
}

// 默认空实现，各页面按需实现
extension AudioPlayerDelegate {
    func playerDidFailToLoad(_ track: AudioTrack) {}
}

final class AudioPlayerManager: NSObject {
    static let shared = AudioPlayerManager()
    
    private var delegates = NSHashTable<AnyObject>.weakObjects()

    func addDelegate(_ delegate: AudioPlayerDelegate) {
        delegates.add(delegate as AnyObject)
    }

    func removeDelegate(_ delegate: AudioPlayerDelegate) {
        delegates.remove(delegate as AnyObject)
    }

    private func notifyDelegates(_ block: (AudioPlayerDelegate) -> Void) {
        for object in delegates.allObjects {
            if let delegate = object as? AudioPlayerDelegate {
                block(delegate)
            }
        }
    }
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var playerItemStatusObserver: NSKeyValueObservation?
    
    // MARK: - 当前状态
    private(set) var currentTrack: AudioTrack?
    var currentPlaylist: [AudioTrack] = []
    var currentIndex: Int = 0
    
    /// 记录被中断前是否正在播放，用于中断结束后恢复
    private var wasPlayingBeforeInterruption = false

    /// 逻辑播放状态：中断通知到达时系统可能已把 rate 归零，
    /// 现场采样 rate 会误判为"未在播放"，导致中断结束后不恢复
    private var isLogicallyPlaying = false

    /// 当前曲目是否已触发过「跳过结尾」，防止重复触发
    private var outroSkipTriggered = false
    
    // MARK: - 睡眠定时器
    private var sleepTimer: Timer?
    private var sleepTimerEndDate: Date?
    /// 睡眠定时器模式：播完当前曲目后停止
    private(set) var sleepAtEndOfTrack = false
    
    /// 睡眠定时器剩余时间（秒），返回 nil 表示没有激活定时器
    var sleepTimerRemaining: TimeInterval? {
        guard let endDate = sleepTimerEndDate else { return nil }
        let remaining = endDate.timeIntervalSinceNow
        // 即使是负数也返回，让 checkSleepTimer 处理停止逻辑
        return remaining
    }
    
    /// 睡眠定时器是否激活
    var isSleepTimerActive: Bool {
        if sleepAtEndOfTrack { return true }
        if let remaining = sleepTimerRemaining, remaining > 0 { return true }
        return false
    }
    
    var isPlaying: Bool {
        return player?.rate ?? 0 > 0
    }
    
    var currentTime: TimeInterval {
        return player?.currentTime().seconds ?? 0
    }
    
    var duration: TimeInterval {
        return playerItem?.duration.seconds ?? 0
    }
    
    // MARK: - 倍速选项
    static let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    
    var playbackRate: Float {
        get { PlaybackStateManager.shared.playbackRate }
        set {
            PlaybackStateManager.shared.playbackRate = newValue
            if isPlaying {
                player?.rate = newValue
                // 倍速变化时更新锁屏信息，确保进度条正确
                updateNowPlayingInfo()
            }
        }
    }
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionObserver()
        setupRouteChangeObserver()
    }
    
    deinit {
        removeTimeObserver()
        playerItemStatusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 中断监听
    private func setupInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 中断开始（如来电）。此时系统往往已把 rate 归零，
            // 必须用逻辑播放状态判断，不能现场采样 rate
            wasPlayingBeforeInterruption = isLogicallyPlaying
            if wasPlayingBeforeInterruption {
                pause()
            }
            
        case .ended:
            // 中断结束，检查是否应该恢复播放
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                // 延迟一小段时间再恢复播放，确保系统准备就绪
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.play()
                }
            }
            wasPlayingBeforeInterruption = false
            
        @unknown default:
            break
        }
    }

    // MARK: - 输出设备变化监听
    private func setupRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    /// 耳机拔出 / 蓝牙断开时自动暂停（有声书标准行为，避免外放尴尬）
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else {
            return
        }
        // 该通知可能在后台线程到达，回主线程再操作
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isLogicallyPlaying else { return }
            self.pause()
        }
    }

    // MARK: - 音频会话配置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    // MARK: - 远程控制中心
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 播放/暂停控制
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // 上一曲/下一曲控制 - 锁屏显示切换按钮
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
        
        // 禁用快进/快退命令，这样锁屏会显示上一首/下一首按钮
        // 如果启用 skipForward/skipBackward，iOS 会优先显示跳过按钮而隐藏切换按钮
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        
        // 进度条拖动控制
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: event.positionTime)
            return .success
        }
    }
    
    // MARK: - 播放控制
    func play(track: AudioTrack, in playlist: [AudioTrack]) {
        currentPlaylist = playlist
        if let index = playlist.firstIndex(of: track) {
            currentIndex = index
        }
        playTrack(track)
    }
    
    func play(at index: Int) {
        guard index >= 0 && index < currentPlaylist.count else { return }
        currentIndex = index
        playTrack(currentPlaylist[index])
    }
    
    private func playTrack(_ track: AudioTrack) {
        // 保存当前曲目的播放位置（切换前）
        if let oldTrack = currentTrack, oldTrack != track {
            let position = currentTime
            let total = duration
            let outro = PlaybackStateManager.shared.getSkipOutroSeconds(forFolder: oldTrack.folderName)
            let inOutroZone = outro > 0 && total.isFinite && total > 0
                && total - position <= TimeInterval(outro) + 1
            if inOutroZone {
                // 已进入「跳过结尾」区间，视为听完并清除位置；
                // 否则下次重播该曲目恢复到此位置时会立即再次触发跳过
                PlaybackStateManager.shared.clearTrackPosition(url: oldTrack.url)
            } else if position > 0 {
                PlaybackStateManager.shared.saveTrackPosition(url: oldTrack.url, time: position)
            }
        }

        removeTimeObserver()
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        outroSkipTriggered = false
        
        currentTrack = track
        playerItem = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: playerItem)
        
        // 获取文件夹级别的设置
        let folderName = track.folderName
        let skipIntro = PlaybackStateManager.shared.getSkipIntroSeconds(forFolder: folderName)
        let skipOutro = PlaybackStateManager.shared.getSkipOutroSeconds(forFolder: folderName)
        let savedPosition = PlaybackStateManager.shared.getTrackPosition(url: track.url)

        // 监听 playerItem 状态，等加载完成后恢复位置或应用跳过开头设置
        playerItemStatusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    let skipTime = TimeInterval(skipIntro)
                    // 恢复位置不能落进「跳过结尾」区间，否则会立即触发自动切歌
                    let minTailGap = max(5, TimeInterval(skipOutro) + 1)

                    // 优先恢复保存的位置，否则使用跳过开头设置
                    if savedPosition > 0 && savedPosition < self.duration - minTailGap {
                        // 有保存的位置，恢复到该位置
                        self.seek(to: savedPosition)
                    } else if skipIntro > 0 && self.duration > skipTime + 10 {
                        // 没有保存位置，应用跳过开头
                        self.seek(to: skipTime)
                    }

                    self.updateNowPlayingInfo()
                }
            } else if item.status == .failed {
                // 文件损坏或格式不支持：复位状态并通知 UI，避免界面停留在"播放中"
                DispatchQueue.main.async {
                    self.isLogicallyPlaying = false
                    self.notifyDelegates { $0.playerDidChangePlayingState(false) }
                    self.notifyDelegates { $0.playerDidFailToLoad(track) }
                }
            }
        }
        
        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        addTimeObserver()
        player?.rate = playbackRate
        isLogicallyPlaying = true

        notifyDelegates { $0.playerDidChangeTrack(track) }
        notifyDelegates { $0.playerDidChangePlayingState(true) }
        
        // 先更新基本信息（duration 可能还是 0，等 readyToPlay 后会再次更新）
        updateNowPlayingInfo()
        saveState()
        
        // 保存该文件夹的上次播放曲目
        PlaybackStateManager.shared.saveLastPlayedTrack(url: track.url, forFolder: track.folderName)
    }
    
    func play() {
        guard player != nil else { return }
        // 已播到末尾时（如列表播完后再按播放），从头重播当前曲目
        if duration > 0, duration.isFinite, currentTime >= duration - 0.5 {
            seek(to: 0)
        }
        isLogicallyPlaying = true
        player?.rate = playbackRate
        notifyDelegates { $0.playerDidChangePlayingState(true) }
        updateNowPlayingInfo()
    }

    func pause() {
        isLogicallyPlaying = false
        player?.pause()
        notifyDelegates { $0.playerDidChangePlayingState(false) }
        updateNowPlayingInfo()
        saveState()
        
        // 暂停时保存当前曲目的播放位置
        if let track = currentTrack {
            PlaybackStateManager.shared.saveTrackPosition(url: track.url, time: currentTime)
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func playNext() {
        guard currentIndex < currentPlaylist.count - 1 else { return }
        play(at: currentIndex + 1)
    }
    
    func playPrevious() {
        // 如果播放超过3秒，回到开头；否则上一曲
        if currentTime > 3 {
            seek(to: 0)
        } else if currentIndex > 0 {
            play(at: currentIndex - 1)
        } else {
            seek(to: 0)
        }
    }

    // MARK: - 播放列表维护

    /// 曲目被删除后同步播放列表，并修正 currentIndex，防止上一/下一曲错位
    func updatePlaylist(afterDeletion newPlaylist: [AudioTrack]) {
        currentPlaylist = newPlaylist
        if let track = currentTrack, let index = newPlaylist.firstIndex(of: track) {
            currentIndex = index
        }
    }

    /// 完全停止并卸载当前播放内容（删除正在播放的文件/文件夹时调用）
    func stop() {
        isLogicallyPlaying = false
        player?.pause()
        removeTimeObserver()
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        if let item = playerItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        player = nil
        playerItem = nil
        currentTrack = nil
        currentPlaylist = []
        currentIndex = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        PlaybackStateManager.shared.clearState()
        notifyDelegates { $0.playerDidChangeTrack(nil) }
        notifyDelegates { $0.playerDidChangePlayingState(false) }
    }

    // MARK: - 进度控制
    func seek(to time: TimeInterval) {
        // duration 未就绪/加载失败时上层可能算出 NaN，seek 到非法 CMTime 会抛异常崩溃
        guard time.isFinite else { return }
        let cmTime = CMTime(seconds: max(0, time), preferredTimescale: 600)
        
        // 立即更新锁屏信息（使用目标时间），避免进度条跳动
        updateNowPlayingInfo(elapsedTime: time)
        
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            self?.saveState()
        }
    }
    
    func skipForward(_ seconds: TimeInterval) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }
    
    func skipBackward(_ seconds: TimeInterval) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }
    
    // MARK: - 睡眠定时器控制
    
    /// 设置睡眠定时器
    /// - Parameter minutes: 分钟数，0 表示取消定时器
    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        
        guard minutes > 0 else { return }
        
        sleepAtEndOfTrack = false
        sleepTimerEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkSleepTimer()
        }
        
        // 发送通知，UI 可以更新显示
        NotificationCenter.default.post(name: .sleepTimerDidChange, object: nil)
    }
    
    /// 设置播完当前曲目后停止
    func setSleepAtEndOfTrack() {
        cancelSleepTimer()
        sleepAtEndOfTrack = true
        NotificationCenter.default.post(name: .sleepTimerDidChange, object: nil)
    }
    
    /// 取消睡眠定时器
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndDate = nil
        sleepAtEndOfTrack = false
        // 在最后 30 秒淡出阶段取消时，必须恢复音量，否则会一直停留在低音量
        player?.volume = 1.0
        NotificationCenter.default.post(name: .sleepTimerDidChange, object: nil)
    }
    
    private func checkSleepTimer() {
        guard let remaining = sleepTimerRemaining else {
            return
        }
        
        // 时间到，停止播放
        if remaining <= 0 {
            player?.volume = 1.0  // 恢复音量
            pause()
            cancelSleepTimer()
            return
        }
        
        // 最后 30 秒开始淡出音量
        if remaining <= 30 && remaining > 0 {
            let volume = Float(remaining / 30.0)
            player?.volume = max(0.1, volume)  // 保持最小音量 0.1，避免完全静音
        } else {
            // 确保正常播放时音量正常
            player?.volume = 1.0
        }
        
        // 发送通知更新 UI
        NotificationCenter.default.post(name: .sleepTimerDidChange, object: nil)
    }
    
    // MARK: - 时间观察
    /// 上次更新锁屏信息的时间，用于定期刷新（蓝牙同步）
    private var lastNowPlayingUpdateTime: TimeInterval = 0
    /// 上次保存播放位置的时间
    private var lastPositionSaveTime: TimeInterval = 0
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let current = self.currentTime
            let total = self.duration
            
            guard total.isFinite && !total.isNaN else { return }
            
            self.notifyDelegates { $0.playerDidUpdateTime(current, duration: total) }
            
            // 定期更新锁屏/蓝牙进度信息
            // 使用倍速播放时更频繁更新（每5秒），正常速度每10秒更新
            let updateInterval: TimeInterval = self.playbackRate != 1.0 ? 5 : 10
            if abs(current - self.lastNowPlayingUpdateTime) >= updateInterval {
                self.lastNowPlayingUpdateTime = current
                self.updateNowPlayingInfo()
            }
            
            // 定期保存播放位置（每30秒），防止意外退出丢失进度
            if abs(current - self.lastPositionSaveTime) >= 30 {
                self.lastPositionSaveTime = current
                if let track = self.currentTrack {
                    PlaybackStateManager.shared.saveTrackPosition(url: track.url, time: current)
                    PlaybackStateManager.shared.saveState(trackURL: track.url, time: current)
                }
            }
            
            // 跳过结尾检测（使用文件夹级别设置）
            // 必须限定播放中触发：periodic observer 在 seek 时也会回调，
            // 否则暂停状态下拖进度条到结尾区间会被误触发切歌并开始播放。
            // 用 outroSkipTriggered 一次性标记代替原来的 1 秒窗口，主线程卡顿错过窗口也不会漏触发
            let folderName = self.currentTrack?.folderName ?? ""
            let skipOutro = PlaybackStateManager.shared.getSkipOutroSeconds(forFolder: folderName)
            if skipOutro > 0, self.isPlaying, !self.outroSkipTriggered,
               self.currentIndex < self.currentPlaylist.count - 1,
               total - current <= TimeInterval(skipOutro) {
                self.outroSkipTriggered = true
                self.playNext()
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    // MARK: - 播放结束
    @objc private func playerDidFinishPlaying() {
        // 播放完成，清除该曲目的保存位置（下次从头开始）
        if let track = currentTrack {
            PlaybackStateManager.shared.clearTrackPosition(url: track.url)
        }
        
        notifyDelegates { $0.playerDidFinishTrack() }

        // 如果设置了"播完本曲停止"，则停止播放
        if sleepAtEndOfTrack {
            cancelSleepTimer()
            isLogicallyPlaying = false
            notifyDelegates { $0.playerDidChangePlayingState(false) }
            return
        }

        // 自动播放下一曲
        if currentIndex < currentPlaylist.count - 1 {
            playNext()
        } else {
            // 播放列表结束
            isLogicallyPlaying = false
            notifyDelegates { $0.playerDidChangePlayingState(false) }
        }
    }
    
    // MARK: - 锁屏信息
    /// 更新锁屏播放信息
    /// - Parameter elapsedTime: 可选的已播放时间，用于 seek 时立即更新（避免使用尚未更新的 currentTime）
    private func updateNowPlayingInfo(elapsedTime: TimeInterval? = nil) {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        let elapsed = elapsedTime ?? currentTime
        let totalDuration = duration
        
        // 确保 duration 有效，否则某些蓝牙设备会显示异常
        guard totalDuration.isFinite && !totalDuration.isNaN && totalDuration > 0 else {
            return
        }
        
        // 使用实际播放速率，锁屏可以正确显示
        // 对于不支持变速的蓝牙设备，通过频繁更新 elapsedTime 来保持同步
        let rate: Double = isPlaying ? Double(playbackRate) : 0.0
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.displayName,
            MPMediaItemPropertyArtist: track.folderName,
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: totalDuration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: elapsed),
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: rate),
            MPNowPlayingInfoPropertyDefaultPlaybackRate: NSNumber(value: 1.0)
        ]
        
        // 添加曲目编号信息，方便在锁屏看到进度
        if !currentPlaylist.isEmpty {
            info[MPMediaItemPropertyAlbumTrackNumber] = NSNumber(value: currentIndex + 1)
            info[MPMediaItemPropertyAlbumTrackCount] = NSNumber(value: currentPlaylist.count)
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - 状态保存
    private func saveState() {
        PlaybackStateManager.shared.saveState(
            trackURL: currentTrack?.url,
            time: currentTime
        )
        
        // 同时保存当前曲目的播放位置
        if let track = currentTrack {
            PlaybackStateManager.shared.saveTrackPosition(url: track.url, time: currentTime)
        }
    }
    
    // MARK: - 恢复播放
    func restorePlayback() {
        guard let savedURL = PlaybackStateManager.shared.currentTrackURL,
              FileManager.default.fileExists(atPath: savedURL.path) else {
            return
        }
        
        // 找到对应的文件夹和曲目
        guard let folder = FileService.shared.findFolder(for: savedURL) else {
            return
        }
        
        let tracks = FileService.shared.getTracks(in: folder)
        // 用标准化路径比较，避免 /private/var 与 /var 等 URL 形式差异导致匹配失败
        let savedPath = savedURL.standardizedFileURL.path
        guard let track = tracks.first(where: { $0.url.standardizedFileURL.path == savedPath }) else {
            return
        }
        
        // 恢复播放列表和曲目
        currentPlaylist = tracks
        if let index = tracks.firstIndex(of: track) {
            currentIndex = index
        }
        
        // 清理之前的观察者（与 playTrack 保持一致：
        // 不清理 time observer 会导致泄漏，不清理通知会导致播放结束回调重复触发）
        removeTimeObserver()
        playerItemStatusObserver?.invalidate()
        playerItemStatusObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        outroSkipTriggered = false

        // 加载但不播放
        currentTrack = track
        playerItem = AVPlayerItem(url: track.url)
        player = AVPlayer(playerItem: playerItem)
        
        // 监听 playerItem 状态，等加载完成后更新锁屏信息
        let savedTime = PlaybackStateManager.shared.currentTime
        playerItemStatusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self = self else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    // 恢复进度
                    if savedTime > 0 {
                        let cmTime = CMTime(seconds: savedTime, preferredTimescale: 600)
                        self.player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                    self.updateNowPlayingInfo(elapsedTime: savedTime > 0 ? savedTime : nil)
                }
            }
        }
        
        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        addTimeObserver()
        notifyDelegates { $0.playerDidChangeTrack(track) }
    }
}


