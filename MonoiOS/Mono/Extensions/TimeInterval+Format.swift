//
//  TimeInterval+Format.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import Foundation

extension TimeInterval {
    /// 格式化为 mm:ss 或 h:mm:ss
    var formattedTime: String {
        guard self.isFinite && !self.isNaN else { return "00:00" }

        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// 格式化为 “Xh Ym” 或 “Ym”（用于书库/章节总时长展示）。
    /// 仅处理有效正值；无效值的占位符由调用方决定（列表用“—”，章节页用“0m”）。
    var hoursMinutesText: String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

extension Int {
    /// 把秒数格式化为「关闭 / X 秒 / X 分钟 / X 分 Y 秒」，用于跳过开头/结尾设置的展示
    var skipDurationText: String {
        if self == 0 { return "关闭" }
        if self < 60 { return "\(self) 秒" }
        let minutes = self / 60
        let seconds = self % 60
        return seconds == 0 ? "\(minutes) 分钟" : "\(minutes) 分 \(seconds) 秒"
    }
}



