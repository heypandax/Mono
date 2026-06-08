//
//  DesignTokens.swift
//  Mono
//
//  Design system: "The Modern Bibliophile"
//  Warm amber/gold palette with editorial typography
//

import UIKit

enum DesignTokens {

    // MARK: - Colors

    static let background = UIColor(hex: "FAF7F2")
    static let surface = UIColor(hex: "FCF9F4")
    static let surfaceContainer = UIColor(hex: "F0EDE9")
    static let surfaceContainerHigh = UIColor(hex: "EBE8E3")
    static let surfaceContainerHighest = UIColor(hex: "E5E2DD")
    static let surfaceVariant = UIColor(hex: "E5E2DD")
    static let surfaceDim = UIColor(hex: "DCDAD5")

    static let primary = UIColor(hex: "855300")
    static let primaryContainer = UIColor(hex: "D4890E")
    static let onPrimary = UIColor.white
    static let primaryFixed = UIColor(hex: "FFDDB8")
    static let inversePrimary = UIColor(hex: "FFB95E")

    static let secondary = UIColor(hex: "635D58")
    static let secondaryContainer = UIColor(hex: "EAE1DA")
    static let onSecondary = UIColor.white

    static let tertiary = UIColor(hex: "00658F")
    static let tertiaryContainer = UIColor(hex: "21A3E2")

    static let onSurface = UIColor(hex: "1C1C19")
    static let onSurfaceVariant = UIColor(hex: "524435")
    static let onBackground = UIColor(hex: "1C1C19")

    static let outline = UIColor(hex: "857463")
    static let outlineVariant = UIColor(hex: "D7C3AF")

    static let error = UIColor(hex: "BA1A1A")
    static let errorContainer = UIColor(hex: "FFDAD6")

    static let inverseSurface = UIColor(hex: "31302D")
    static let inverseOnSurface = UIColor(hex: "F3F0EB")

    // MARK: - Typography

    /// Serif 字体 (替代 Newsreader) — 用于标题、书名
    static func serif(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif)?
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        if let descriptor = descriptor {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    /// Sans-serif 字体 (替代 Manrope) — 用于正文、标签
    static func sansSerif(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.rounded)?
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        if let descriptor = descriptor {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }

    // 标题字体
    static let headlineLarge = serif(size: 24, weight: .semibold)
    static let headlineMedium = serif(size: 20, weight: .semibold)
    static let headlineSmall = serif(size: 17, weight: .medium)

    // 正文字体
    static let bodyLarge = sansSerif(size: 16, weight: .regular)
    static let bodyMedium = sansSerif(size: 14, weight: .regular)
    static let bodySmall = sansSerif(size: 12, weight: .regular)

    // 标签字体
    static let labelLarge = sansSerif(size: 14, weight: .medium)
    static let labelMedium = sansSerif(size: 12, weight: .medium)
    static let labelSmall = sansSerif(size: 10, weight: .medium)

    // 等宽数字字体 (用于时间显示)
    static func monoDigits(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        return .monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let sheet: CGFloat = 40
        static let full: CGFloat = 9999
    }

    // MARK: - Shadows

    /// 温暖的琥珀色环境阴影
    static func applyWarmShadow(to layer: CALayer, radius: CGFloat = 24, opacity: Float = 0.06) {
        layer.shadowColor = primary.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = radius
    }

    // MARK: - Gradient

    /// 琥珀色渐变 (135° from #855300 to #D4890E)
    static func amberGlowGradient(for bounds: CGRect) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = [primary.cgColor, primaryContainer.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = bounds
        gradient.cornerRadius = CornerRadius.xl
        return gradient
    }

    // MARK: - Drag Handle

    static let dragHandleWidth: CGFloat = 36
    static let dragHandleHeight: CGFloat = 5
    static let dragHandleColor = surfaceVariant
}
