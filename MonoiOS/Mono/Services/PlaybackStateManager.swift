//
//  PlaybackStateManager.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation

final class PlaybackStateManager {
    static let shared = PlaybackStateManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let currentTrackURL = "mono_current_track_url"
        static let currentTime = "mono_current_time"
        static let playbackRate = "mono_playback_rate"
        // 设置项
        static let skipIntroSeconds = "mono_skip_intro_seconds"
        static let skipOutroSeconds = "mono_skip_outro_seconds"
        static let autoPlayOnLaunch = "mono_auto_play_on_launch"
        static let rememberPositionPerTrack = "mono_remember_position_per_track"
        static let sleepTimerMinutes = "mono_sleep_timer_minutes"

        // 文件夹/曲目级 key 前缀 —— getter/setter 与删除清理逻辑共用同一来源，
        // 避免改前缀时漏改某处导致数据读不回（getter）或清不掉（cleanup）。
        static let folderSkipIntroPrefix = "mono_folder_skip_intro_"
        static let folderSkipOutroPrefix = "mono_folder_skip_outro_"
        static let folderLastTrackPrefix = "mono_folder_last_track_"
        static let trackPositionPrefix = "mono_track_position_"
    }
    
    private init() {}

    // MARK: - 路径持久化辅助

    /// 当前 Documents 目录
    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 把持久化的路径解析回 URL：
    /// - 相对路径：基于当前 Documents 拼接
    /// - 绝对路径（旧版本数据）：原路径存在则直接用；否则截取 "/Documents/" 之后的部分迁移到当前容器
    private func resolveStoredPath(_ stored: String) -> URL? {
        guard stored.hasPrefix("/") else {
            return documentsURL.appendingPathComponent(stored)
        }
        if FileManager.default.fileExists(atPath: stored) {
            return URL(fileURLWithPath: stored)
        }
        if let range = stored.range(of: "/Documents/") {
            let relative = String(stored[range.upperBound...])
            let migrated = documentsURL.appendingPathComponent(relative)
            if FileManager.default.fileExists(atPath: migrated.path) {
                return migrated
            }
        }
        return nil
    }

    // MARK: - 播放倍速
    var playbackRate: Float {
        get {
            let rate = defaults.float(forKey: Keys.playbackRate)
            return rate > 0 ? rate : 1.0
        }
        set {
            defaults.set(newValue, forKey: Keys.playbackRate)
        }
    }
    
    // MARK: - 当前播放的音频URL
    var currentTrackURL: URL? {
        get {
            guard let stored = defaults.string(forKey: Keys.currentTrackURL) else {
                return nil
            }
            return resolveStoredPath(stored)
        }
        set {
            if let url = newValue {
                defaults.set(url.documentsRelativePath, forKey: Keys.currentTrackURL)
            } else {
                defaults.removeObject(forKey: Keys.currentTrackURL)
            }
        }
    }
    
    // MARK: - 当前播放时间
    var currentTime: TimeInterval {
        get {
            return defaults.double(forKey: Keys.currentTime)
        }
        set {
            guard newValue.isFinite, newValue >= 0 else { return }
            defaults.set(newValue, forKey: Keys.currentTime)
        }
    }
    
    // MARK: - 保存播放状态
    func saveState(trackURL: URL?, time: TimeInterval) {
        currentTrackURL = trackURL
        currentTime = time
    }
    
    // MARK: - 清除状态
    func clearState() {
        defaults.removeObject(forKey: Keys.currentTrackURL)
        defaults.removeObject(forKey: Keys.currentTime)
    }
    
    // MARK: - 设置项
    
    /// 全局跳过开头秒数（作为新文件夹的默认值）
    var defaultSkipIntroSeconds: Int {
        get { defaults.integer(forKey: Keys.skipIntroSeconds) }
        set { defaults.set(newValue, forKey: Keys.skipIntroSeconds) }
    }
    
    /// 全局跳过结尾秒数（作为新文件夹的默认值）
    var defaultSkipOutroSeconds: Int {
        get { defaults.integer(forKey: Keys.skipOutroSeconds) }
        set { defaults.set(newValue, forKey: Keys.skipOutroSeconds) }
    }
    
    // MARK: - 文件夹级别的跳过设置
    
    // 注意：持久化 key 不能用 hashValue —— Swift 的 hashValue 每次进程启动随机化，
    // 跨启动 key 会变，数据将永远读不回来。直接用文件夹名/相对路径本身做 key。

    /// 获取文件夹的跳过开头秒数
    func getSkipIntroSeconds(forFolder folderName: String) -> Int {
        let key = Keys.folderSkipIntroPrefix + folderName
        if defaults.object(forKey: key) == nil {
            // 如果没有设置过，返回全局默认值
            return defaultSkipIntroSeconds
        }
        return defaults.integer(forKey: key)
    }

    /// 设置文件夹的跳过开头秒数
    func setSkipIntroSeconds(_ seconds: Int, forFolder folderName: String) {
        defaults.set(seconds, forKey: Keys.folderSkipIntroPrefix + folderName)
    }

    /// 获取文件夹的跳过结尾秒数
    func getSkipOutroSeconds(forFolder folderName: String) -> Int {
        let key = Keys.folderSkipOutroPrefix + folderName
        if defaults.object(forKey: key) == nil {
            return defaultSkipOutroSeconds
        }
        return defaults.integer(forKey: key)
    }

    /// 设置文件夹的跳过结尾秒数
    func setSkipOutroSeconds(_ seconds: Int, forFolder folderName: String) {
        defaults.set(seconds, forKey: Keys.folderSkipOutroPrefix + folderName)
    }
    
    /// 兼容旧接口：获取当前播放曲目所在文件夹的跳过开头秒数
    var skipIntroSeconds: Int {
        get {
            if let url = currentTrackURL {
                let folderName = url.deletingLastPathComponent().lastPathComponent
                return getSkipIntroSeconds(forFolder: folderName)
            }
            return defaultSkipIntroSeconds
        }
    }
    
    /// 兼容旧接口：获取当前播放曲目所在文件夹的跳过结尾秒数
    var skipOutroSeconds: Int {
        get {
            if let url = currentTrackURL {
                let folderName = url.deletingLastPathComponent().lastPathComponent
                return getSkipOutroSeconds(forFolder: folderName)
            }
            return defaultSkipOutroSeconds
        }
    }
    
    /// 启动时自动播放
    var autoPlayOnLaunch: Bool {
        get { defaults.bool(forKey: Keys.autoPlayOnLaunch) }
        set { defaults.set(newValue, forKey: Keys.autoPlayOnLaunch) }
    }
    
    /// 记住每个曲目的播放位置
    var rememberPositionPerTrack: Bool {
        get {
            // 默认为 true
            if defaults.object(forKey: Keys.rememberPositionPerTrack) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.rememberPositionPerTrack)
        }
        set { defaults.set(newValue, forKey: Keys.rememberPositionPerTrack) }
    }
    
    // MARK: - 每个曲目的播放位置

    /// 曲目位置的持久化 key：用相对路径，重装后依然稳定
    private func trackPositionKey(for url: URL) -> String {
        return Keys.trackPositionPrefix + url.documentsRelativePath
    }

    /// 保存曲目的播放位置
    func saveTrackPosition(url: URL, time: TimeInterval) {
        // NaN/负数防御：duration 未就绪时上层可能传入非法值，NaN 无法写入 plist
        guard rememberPositionPerTrack, time.isFinite, time >= 0 else { return }
        defaults.set(time, forKey: trackPositionKey(for: url))
    }

    /// 获取曲目的播放位置
    func getTrackPosition(url: URL) -> TimeInterval {
        guard rememberPositionPerTrack else { return 0 }
        return defaults.double(forKey: trackPositionKey(for: url))
    }

    /// 清除曲目的播放位置
    func clearTrackPosition(url: URL) {
        defaults.removeObject(forKey: trackPositionKey(for: url))
    }
    
    // MARK: - 每个文件夹的上次播放曲目
    
    /// 保存文件夹上次播放的曲目URL
    func saveLastPlayedTrack(url: URL, forFolder folderName: String) {
        defaults.set(url.documentsRelativePath, forKey: Keys.folderLastTrackPrefix + folderName)
    }

    /// 获取文件夹上次播放的曲目URL
    func getLastPlayedTrack(forFolder folderName: String) -> URL? {
        guard let stored = defaults.string(forKey: Keys.folderLastTrackPrefix + folderName) else { return nil }
        return resolveStoredPath(stored)
    }

    /// 仅当记录仍指向这条音频时清除，避免删除/损坏文件在同路径重导后复活旧状态。
    func clearLastPlayedTrack(ifMatching url: URL, forFolder folderName: String) {
        let key = Keys.folderLastTrackPrefix + folderName
        guard let stored = defaults.string(forKey: key) else { return }
        guard let storedURL = resolveStoredPath(stored) else { return }
        guard storedURL.standardizedFileURL.path == url.standardizedFileURL.path else { return }
        defaults.removeObject(forKey: key)
    }

    // MARK: - 数据管理

    /// 删除文件夹时清除其全部相关数据（跳过设置、上次播放曲目、各曲目进度），
    /// 避免 UserDefaults 中残留孤儿 key 无限增长
    func clearFolderData(forFolder folderName: String) {
        defaults.removeObject(forKey: Keys.folderSkipIntroPrefix + folderName)
        defaults.removeObject(forKey: Keys.folderSkipOutroPrefix + folderName)
        defaults.removeObject(forKey: Keys.folderLastTrackPrefix + folderName)

        // 该文件夹下所有曲目的进度 key（相对路径形如 "文件夹名/文件名"）
        let positionPrefix = Keys.trackPositionPrefix + folderName + "/"
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(positionPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// 清除所有播放进度数据
    func clearAllProgress() {
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(Keys.trackPositionPrefix) ||
               key.hasPrefix(Keys.folderLastTrackPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
        clearState()
    }
}

