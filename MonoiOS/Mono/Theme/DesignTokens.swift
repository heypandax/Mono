//
//  DesignTokens.swift
//  Mono
//
//  Mono Master v1 —— 中性冷灰底 + 单一静蓝强调色，浅色与 OLED 深色两套语义 token。
//  颜色一律是 trait-aware 的动态色，禁止在 controller / cell 里散落字面色值。
//

import UIKit

enum DesignTokens {

    // MARK: - Colors

    /// 浅色 / 深色两套值合成一个动态色，随系统外观自动切换
    private static func dynamic(light: String, dark: String) -> UIColor {
        let lightColor = UIColor(hex: light)
        let darkColor = UIColor(hex: dark)
        return UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        }
    }

    static let primary = dynamic(light: "2C63D8", dark: "5E9BFF")
    static let onPrimary = dynamic(light: "FFFFFF", dark: "04214F")
    static let primaryContainer = dynamic(light: "E4EBFA", dark: "152947")

    static let background = dynamic(light: "FFFFFF", dark: "000000")
    static let surface = dynamic(light: "FFFFFF", dark: "000000")
    static let surfaceContainer = dynamic(light: "F1F3F5", dark: "141517")
    static let surfaceContainerHigh = dynamic(light: "E7EAEE", dark: "1E2023")

    static let onSurface = dynamic(light: "17181A", dark: "F2F3F5")
    static let onSurfaceVariant = dynamic(light: "5F666E", dark: "A7ADB4")

    static let outline = dynamic(light: "D6D9DE", dark: "303338")
    static let outlineVariant = dynamic(light: "E8EAEE", dark: "1D1F22")

    static let error = dynamic(light: "C8443C", dark: "FF6B60")
    static let disabled = dynamic(light: "A9AEB5", dark: "5A6067")

    // MARK: - Derived surfaces

    /// 浮在内容之上的表面（迷你播放器、弹层）：浅色用纯白，深色抬升一层
    static let elevatedSurface = dynamic(light: "FFFFFF", dark: "141517")

    /// 设置页这类分组列表的页面底色
    static let groupedBackground = dynamic(light: "F1F3F5", dark: "000000")

    /// 分组列表里的单元格底色
    static let groupedCellBackground = dynamic(light: "FFFFFF", dark: "141517")

    /// 选中态底色（倍速 / 睡眠选项）
    static let selectedOptionBackground = dynamic(light: "E4EBFA", dark: "1E2023")

    /// 弹层遮罩
    static let scrim = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0, alpha: 0.6)
            : UIColor(red: 16.0 / 255, green: 18.0 / 255, blue: 21.0 / 255, alpha: 0.32)
    }

    // MARK: - Typography

    /// 取「默认字号档位」下的字号，再用 UIFontMetrics 缩放，
    /// 这样配合 adjustsFontForContentSizeCategory 才能随 Dynamic Type 实时更新
    private static let defaultSizeTraits = UITraitCollection(preferredContentSizeCategory: .large)

    /// 语义层级字体。weight 为 nil 时使用文本样式自带的字重
    static func font(_ style: UIFont.TextStyle, weight: UIFont.Weight? = nil) -> UIFont {
        guard let weight else { return UIFont.preferredFont(forTextStyle: style) }
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: defaultSizeTraits)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: base.pointSize, weight: weight))
    }

    /// 等宽数字字体，所有时间 / 时长必须使用，避免逐秒跳动时抖动
    static func numberFont(_ style: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: defaultSizeTraits)
        let mono = UIFont.monospacedDigitSystemFont(ofSize: base.pointSize, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: mono)
    }

    // MARK: - Metrics

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
    }

    /// 最小命中区（HIG）
    static let hitTarget: CGFloat = 44

    /// 页面水平边距
    static let contentInset: CGFloat = 16

    /// iPad 上的内容列最大宽度（列表）
    static let listMaxWidth: CGFloat = 760

    /// iPad 上的内容列最大宽度（播放器，与 Master 一致）
    static let playerMaxWidth: CGFloat = 560

    /// 发丝线粗细
    static var hairline: CGFloat { 1.0 / max(UIScreen.main.scale, 1) }

    // MARK: - Motion

    /// Reduce Motion 打开时不依赖位移 / 弹簧传达状态
    static var prefersReducedMotion: Bool { UIAccessibility.isReduceMotionEnabled }
}
