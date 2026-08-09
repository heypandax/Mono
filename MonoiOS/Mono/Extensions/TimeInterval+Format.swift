//
//  TimeInterval+Format.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation

// 时间与时长的展示格式统一收敛到 MonoFormat（见 Presentation/PlaybackPresentation.swift），
// 避免同一个时间在书库、章节页和播放器里出现三种写法。

extension Int {
    /// 把秒数格式化为「关闭 / X 秒 / X 分钟 / X 分 Y 秒」，用于跳过片头/片尾设置的展示
    var skipDurationText: String {
        if self == 0 { return "关闭" }
        if self < 60 { return "\(self) 秒" }
        let minutes = self / 60
        let seconds = self % 60
        return seconds == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(seconds) 秒"
    }
}
