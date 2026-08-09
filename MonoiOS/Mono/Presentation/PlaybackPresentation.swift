//
//  PlaybackPresentation.swift
//  Mono
//
//  书库 / 搜索 / 章节页 / 迷你播放器 / 全屏播放器共用的唯一表达真相。
//  只允许出现现有服务能证明的事实：
//  - 没有显式 completion 持久化，所以不存在「已完成」状态；
//  - 「最后一章 + 位置 0」不解释为已完成，仍显示该章为上次收听章节；
//  - 时长未就绪不是 0，显示 “—”，VoiceOver 读作「时长读取中」。
//

import Foundation

// MARK: - 书级表达

struct BookPresentation: Equatable {

    /// 书级状态只有两种，没有「已完成」
    enum Status: Equatable {
        case notStarted
        /// 有可靠的上次收听章节。注意：这不代表正在播放
        case listening(chapter: Int, of: Int)
    }

    let title: String
    let chapterCount: Int
    /// nil 表示时长尚未读取完成
    let totalDuration: TimeInterval?
    let status: Status

    var chapterCountText: String { MonoFormat.chapterCountText(chapterCount) }
    var durationText: String { MonoFormat.totalDurationText(totalDuration) }

    /// “5 章 · 2 分钟” / “2 章 · —”
    var metaText: String { "\(chapterCountText) · \(durationText)" }

    /// “未开始” / “收听中 · 第 5 / 5 章”
    var statusText: String {
        switch status {
        case .notStarted:
            return "未开始"
        case let .listening(chapter, total):
            return "收听中 · 第 \(chapter) / \(total) 章"
        }
    }

    /// 书行合并语义：书名、章节数、时长、状态、当前章
    var accessibilityLabel: String {
        var parts = [title, chapterCountText, MonoFormat.spokenDuration(totalDuration)]
        switch status {
        case .notStarted:
            parts.append("未开始")
        case let .listening(chapter, total):
            parts.append("收听中")
            parts.append("第 \(chapter) 章")
            parts.append("共 \(total) 章")
        }
        return parts.joined(separator: "，")
    }
}

// MARK: - 当前收听上下文

/// 「当前加载了某一章」不等于「正在播放」，两者必须分开表达
struct NowPlayingPresentation: Equatable {

    enum Mode: Equatable {
        /// 播放器已加载且真的在出声
        case playing
        /// 播放器已加载但已暂停
        case paused
        /// 只有保存的收听位置，播放器未加载（此时没有迷你播放器）
        case history
    }

    let mode: Mode
    let bookName: String
    let chapterTitle: String
    /// 1-based
    let chapterIndex: Int
    let chapterCount: Int
    let elapsed: TimeInterval
    /// nil 表示时长未就绪
    let duration: TimeInterval?
    let rate: Float

    /// 播放器是否已经加载了这一章（决定迷你播放器是否出现）
    var hasLoadedTrack: Bool { mode != .history }

    /// “正在播放” / “已暂停” / “上次收听”
    var stateText: String {
        switch mode {
        case .playing: return "正在播放"
        case .paused: return "已暂停"
        case .history: return "上次收听"
        }
    }

    /// 书库续听区唯一主动作
    var callToAction: String { mode == .playing ? "打开播放器" : "继续收听" }

    var callToActionSymbol: String { mode == .playing ? "waveform" : "play.fill" }

    /// “第 5 / 5 章”
    var chapterIndexText: String { "第 \(chapterIndex) / \(chapterCount) 章" }

    /// “0:11 / 0:24”，时长未就绪时右侧为 “—”
    var elapsedOverDurationText: String {
        "\(MonoFormat.elapsedText(elapsed)) / \(MonoFormat.totalOrPlaceholder(duration))"
    }

    /// 本章剩余，时长未就绪时为 nil
    var remaining: TimeInterval? {
        guard let duration, duration > 0 else { return nil }
        return max(0, duration - elapsed)
    }

    var remainingText: String {
        guard let remaining else { return "本章剩余 \(MonoFormat.unresolvedDuration)" }
        return "本章剩余 \(MonoFormat.durationText(remaining))"
    }

    /// 章内进度，只到当前章，不上升为整本进度
    var chapterFraction: Double {
        guard let duration, duration > 0, elapsed.isFinite else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    /// 续听区合并语义
    var accessibilityLabel: String {
        var parts = [stateText, bookName, chapterTitle, "第 \(chapterIndex) 章", "共 \(chapterCount) 章"]
        parts.append("已播 \(MonoFormat.spokenElapsed(elapsed))")
        if let duration {
            parts.append("共 \(MonoFormat.spokenTime(duration))")
            parts.append("本章剩余 \(MonoFormat.spokenTime(max(0, duration - elapsed)))")
        } else {
            parts.append(MonoFormat.unresolvedDurationAccessibility)
        }
        return parts.joined(separator: "，")
    }
}

// MARK: - 事实 → 表达

enum PlaybackPresenter {

    /// 书级状态。纯函数：只依赖传入的事实。
    /// 不使用「最后一章 + 位置为 0」这种启发式冒充 completion。
    static func status(folderName: String,
                       chapterCount: Int,
                       tracks: [AudioTrack],
                       currentTrack: AudioTrack?,
                       lastPlayedURL: URL?) -> BookPresentation.Status {
        let total = tracks.isEmpty ? chapterCount : tracks.count
        guard total > 0 else { return .notStarted }

        if let currentTrack, currentTrack.folderName == folderName {
            if let index = index(of: currentTrack.url, in: tracks) {
                return .listening(chapter: index + 1, of: total)
            }
            return .notStarted
        }

        if let lastPlayedURL, let index = index(of: lastPlayedURL, in: tracks) {
            // 上次收听的章节即使保存位置为 0 也照常显示，不推断成「听完了」
            return .listening(chapter: index + 1, of: total)
        }

        return .notStarted
    }

    /// 用标准化路径比较，避免 /private/var 与 /var 之类的 URL 形式差异导致匹配失败
    static func index(of url: URL, in tracks: [AudioTrack]) -> Int? {
        let target = url.standardizedFileURL.path
        return tracks.firstIndex { $0.url.standardizedFileURL.path == target }
    }

    /// 当前收听上下文；从来没听过任何东西时返回 nil。
    /// 优先使用播放器里真实加载的曲目；否则回落到持久化的上次收听位置。
    /// 读取播放器与文件系统，必须在主线程调用。
    static func nowPlaying(player: AudioPlayerManager = .shared,
                           state: PlaybackStateManager = .shared,
                           files: FileService = .shared) -> NowPlayingPresentation? {
        if let track = player.currentTrack {
            let playlist = player.currentPlaylist
            let index = playlist.firstIndex(of: track) ?? player.currentIndex
            let count = max(playlist.count, index + 1)
            return NowPlayingPresentation(
                mode: player.isPlaying ? .playing : .paused,
                bookName: track.folderName,
                chapterTitle: track.displayName,
                chapterIndex: index + 1,
                chapterCount: count,
                elapsed: sanitize(player.currentTime),
                duration: resolvedDuration(player.duration),
                rate: player.playbackRate
            )
        }

        // 播放器未加载：只有持久化的上次收听位置
        guard let url = state.currentTrackURL,
              FileManager.default.fileExists(atPath: url.path),
              let folder = files.findFolder(for: url) else { return nil }
        let tracks = files.getTracks(in: folder)
        guard let index = index(of: url, in: tracks) else { return nil }

        let track = tracks[index]
        let savedPosition = state.getTrackPosition(url: url)
        let elapsed = savedPosition > 0 ? savedPosition : state.currentTime
        return NowPlayingPresentation(
            mode: .history,
            bookName: track.folderName,
            chapterTitle: track.displayName,
            chapterIndex: index + 1,
            chapterCount: tracks.count,
            elapsed: sanitize(elapsed),
            duration: resolvedDuration(track.duration),
            rate: state.playbackRate
        )
    }

    static func sanitize(_ time: TimeInterval) -> TimeInterval {
        guard time.isFinite, time > 0 else { return 0 }
        return time
    }

    /// AVPlayer 未就绪时 duration 可能是 0 / NaN / Inf，一律视作「未读取」
    static func resolvedDuration(_ duration: TimeInterval) -> TimeInterval? {
        guard duration.isFinite, duration > 0 else { return nil }
        return duration
    }
}

// MARK: - 文案格式化

enum MonoFormat {

    /// 时长未读取完成时的占位符
    static let unresolvedDuration = "—"
    /// 占位符的 VoiceOver 读法，不能读成 0
    static let unresolvedDurationAccessibility = "时长读取中"

    /// 取整口径。两种语义必须分开，不能共用一个隐式取整的 helper：
    /// - `down`：已播时间。保守向下取整，绝不显示得比真实播放位置更靠前；
    /// - `nearest`：稳定时长 / 剩余 / 倒计时。四舍五入，视觉与 VoiceOver 同口径
    ///   （23.9 秒两边都是 0:24 / 24 秒）。
    private enum Rounding {
        case down
        case nearest
    }

    static func chapterCountText(_ count: Int) -> String { "\(count) 章" }

    /// “2 分钟” / “1 小时 20 分” / “—”。1:59 记作 2 分钟，与 spokenDuration 同口径
    static func totalDurationText(_ duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite, duration > 0 else { return unresolvedDuration }
        // 不足 1 分钟的书不四舍五入成 “1 分钟”，仍然如实说「不到」
        if duration < 60 { return "不到 1 分钟" }
        let totalMinutes = max(1, Int((duration / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) 小时 \(minutes) 分" : "\(hours) 小时"
        }
        return "\(minutes) 分钟"
    }

    /// 章节时长这类短时长用时钟格式；未就绪时为 “—”
    static func totalOrPlaceholder(_ duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite, duration > 0 else { return unresolvedDuration }
        return durationText(duration)
    }

    /// 已播时间：“0:23”。向下取整
    static func elapsedText(_ time: TimeInterval) -> String {
        clockText(time, rounding: .down)
    }

    /// 时长 / 剩余 / 倒计时：“0:24”。四舍五入
    static func durationText(_ time: TimeInterval) -> String {
        clockText(time, rounding: .nearest)
    }

    /// 播放器倒计时剩余：“-0:21”。与 durationText 同口径四舍五入。
    /// 归零的一秒（含负数 / 非法值）显示 “0:00” 而不是 “-0:00”：
    /// 负号只在真的还剩至少 1 秒时出现，否则章末会读出「负零」这种不存在的时间。
    static func remainingCountdownText(_ remaining: TimeInterval) -> String {
        let totalSeconds = wholeSeconds(remaining, rounding: .nearest)
        let text = clockText(seconds: totalSeconds)
        return totalSeconds > 0 ? "-" + text : text
    }

    private static func clockText(_ time: TimeInterval, rounding: Rounding) -> String {
        clockText(seconds: wholeSeconds(time, rounding: rounding))
    }

    /// “0:24” / “12:05” / “1:02:03”
    private static func clockText(seconds totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// NaN / Inf / 负数一律归零，结束点不会出现 “-0:01”；超大值截到 99:59:59 以免 Int 溢出
    private static func wholeSeconds(_ time: TimeInterval, rounding: Rounding) -> Int {
        guard time.isFinite, time > 0 else { return 0 }
        let value = rounding == .down ? time.rounded(.down) : time.rounded()
        return value >= 359_999 ? 359_999 : Int(value)
    }

    /// VoiceOver 读已播时间：与 elapsedText 同口径向下取整
    static func spokenElapsed(_ time: TimeInterval) -> String {
        spokenText(time, rounding: .down)
    }

    /// VoiceOver 读时长 / 剩余 / 倒计时：与 durationText 同口径四舍五入
    static func spokenTime(_ time: TimeInterval) -> String {
        spokenText(time, rounding: .nearest)
    }

    /// 「11 秒」「1 分 2 秒」，不读成「0 冒号 11」
    private static func spokenText(_ time: TimeInterval, rounding: Rounding) -> String {
        let totalSeconds = wholeSeconds(time, rounding: rounding)
        guard totalSeconds > 0 else { return "0 秒" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) 小时") }
        if minutes > 0 { parts.append("\(minutes) 分") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds) 秒") }
        return parts.joined()
    }

    /// 书行里的时长读法，未就绪时读「时长读取中」
    static func spokenDuration(_ duration: TimeInterval?) -> String {
        guard let duration, duration.isFinite, duration > 0 else { return unresolvedDurationAccessibility }
        return totalDurationText(duration)
    }

    /// “1.0×” / “0.75×” / “1.5×”
    static func rateText(_ rate: Float) -> String {
        let hundredths = (rate * 100).rounded()
        let body = hundredths.truncatingRemainder(dividingBy: 10) == 0
            ? String(format: "%.1f", rate)
            : String(format: "%.2f", rate)
        return body + "×"
    }

    static func spokenRateText(_ rate: Float) -> String {
        rateText(rate).replacingOccurrences(of: "×", with: " 倍")
    }

    /// 睡眠定时剩余时间：“14:32”，与播放器工具区读法同口径
    static func countdownText(_ remaining: TimeInterval) -> String {
        durationText(remaining)
    }
}
