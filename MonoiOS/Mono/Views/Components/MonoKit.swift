//
//  MonoKit.swift
//  Mono
//
//  Master v1 的共用基元：标签工厂、主按钮、进度条、首字标记、分隔线、分组标题。
//  所有页面共用同一套配置，避免样式在各 controller / cell 里重复漂移。
//

import UIKit

// MARK: - 标签工厂

enum MonoUI {

    /// 统一创建支持 Dynamic Type 的标签。numeric = true 时使用等宽数字（时间/时长必用）
    static func label(_ style: UIFont.TextStyle,
                      weight: UIFont.Weight? = nil,
                      color: UIColor,
                      lines: Int = 0,
                      numeric: Bool = false) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = numeric
            ? DesignTokens.numberFont(style, weight: weight ?? .regular)
            : DesignTokens.font(style, weight: weight)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = lines
        return label
    }

    /// 统一导航栏外观：语义色 + 系统字体，浅深模式都跟随 trait
    static func configure(navigationBar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = DesignTokens.background
        appearance.shadowColor = DesignTokens.outlineVariant
        appearance.titleTextAttributes = [.foregroundColor: DesignTokens.onSurface]
        appearance.largeTitleTextAttributes = [.foregroundColor: DesignTokens.onSurface]

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithOpaqueBackground()
        scrollEdge.backgroundColor = DesignTokens.background
        scrollEdge.shadowColor = .clear
        scrollEdge.titleTextAttributes = appearance.titleTextAttributes
        scrollEdge.largeTitleTextAttributes = appearance.largeTitleTextAttributes

        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = scrollEdge
        navigationBar.tintColor = DesignTokens.primary
    }

    /// SF Symbol 图标视图，随 Dynamic Type 缩放
    static func symbolView(_ name: String, style: UIFont.TextStyle, color: UIColor) -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: style)
        imageView.image = UIImage(systemName: name)
        imageView.tintColor = color
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }
}

// MARK: - 主按钮

/// Master 的 MButton：filled 用于唯一主动作，outline 用于恢复类次动作
final class MonoPrimaryButton: UIButton {

    enum Kind {
        case filled
        case outline
    }

    private let kind: Kind

    init(kind: Kind = .filled) {
        self.kind = kind
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        var config: UIButton.Configuration = kind == .filled ? .filled() : .plain()
        config.cornerStyle = .fixed
        config.background.cornerRadius = DesignTokens.CornerRadius.medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        config.imagePadding = DesignTokens.Spacing.sm
        config.titleLineBreakMode = .byWordWrapping

        switch kind {
        case .filled:
            config.baseBackgroundColor = DesignTokens.primary
            config.baseForegroundColor = DesignTokens.onPrimary
        case .outline:
            config.baseForegroundColor = DesignTokens.primary
            config.background.strokeColor = DesignTokens.primary
            config.background.strokeWidth = 1.5
        }

        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = DesignTokens.font(.headline)
            return outgoing
        }

        configuration = config
        titleLabel?.adjustsFontForContentSizeCategory = true
        titleLabel?.textAlignment = .center
        heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
    }

    /// 设置文案与前导图标；symbol 为 nil 时只显示文字
    func apply(title: String, symbol: String?) {
        configuration?.title = title
        configuration?.image = symbol.flatMap { UIImage(systemName: $0) }
        configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote)
        accessibilityLabel = title
    }
}

// MARK: - 章内进度条

/// Master 的 MBar：只表达当前章节的进度，绝不表达整本进度
final class MonoProgressBarView: UIView {

    private let fillView = UIView()
    private let barHeight: CGFloat
    private let rounded: Bool

    /// 0…1
    var fraction: Double = 0 {
        didSet {
            guard abs(fraction - oldValue) > 0.0001 else { return }
            setNeedsLayout()
        }
    }

    init(height: CGFloat = 4, rounded: Bool = true) {
        self.barHeight = height
        self.rounded = rounded
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        backgroundColor = DesignTokens.surfaceContainerHigh
        fillView.backgroundColor = DesignTokens.primary
        addSubview(fillView)
        if rounded {
            layer.cornerRadius = height / 2
            clipsToBounds = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: barHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let clamped = min(max(fraction, 0), 1)
        fillView.frame = CGRect(x: 0, y: 0, width: bounds.width * clamped, height: bounds.height)
    }
}

// MARK: - 首字标记

/// Master 的 MTile：克制的首字识别标记，不是假封面
final class MonoGlyphTileView: UIView {

    private let glyphLabel = MonoUI.label(.headline, weight: .semibold, color: DesignTokens.onSurfaceVariant, lines: 1)

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        backgroundColor = DesignTokens.surfaceContainer
        layer.cornerRadius = DesignTokens.CornerRadius.small
        layer.borderWidth = 1
        updateBorderColor()

        glyphLabel.textAlignment = .center
        addSubview(glyphLabel)
        NSLayoutConstraint.activate([
            glyphLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyphLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyphLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            glyphLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2)
        ])

        // CGColor 不会跟随外观自动更新，必须显式响应 trait 变化
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: MonoGlyphTileView, _) in
            view.updateBorderColor()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateBorderColor() {
        layer.borderColor = DesignTokens.outlineVariant.resolvedColor(with: traitCollection).cgColor
    }

    func apply(title: String) {
        let trimmed = title.trimmingCharacters(in: CharacterSet(charactersIn: " ·　"))
        glyphLabel.text = trimmed.isEmpty ? "·" : String(trimmed.prefix(1))
    }
}

// MARK: - 分隔线

final class MonoSeparatorView: UIView {

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        backgroundColor = DesignTokens.outlineVariant
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: DesignTokens.hairline)
    }
}

// MARK: - 列表分组标题

/// “全部书籍 ｜ 3 本 · 10 章”
final class MonoSectionHeaderView: UITableViewHeaderFooterView {

    static let identifier = "MonoSectionHeaderView"

    private let titleLabel = MonoUI.label(.caption2, weight: .semibold, color: DesignTokens.onSurfaceVariant, lines: 0)
    private let detailLabel = MonoUI.label(.caption1, color: DesignTokens.onSurfaceVariant, lines: 0, numeric: true)
    private let topSeparator = MonoSeparatorView()
    private let bottomSeparator = MonoSeparatorView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let background = UIView()
        background.backgroundColor = DesignTokens.background
        backgroundView = background

        detailLabel.textAlignment = .right
        detailLabel.setContentHuggingPriority(.required, for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        [topSeparator, titleLabel, detailLabel, bottomSeparator].forEach(contentView.addSubview)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: contentView.topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.contentInset),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DesignTokens.Spacing.sm),
            detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.contentInset),
            detailLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),

            bottomSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomSeparator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, detail: String?) {
        titleLabel.text = title
        detailLabel.text = detail
        isAccessibilityElement = true
        accessibilityTraits = .header
        accessibilityLabel = [title, detail].compactMap { $0 }.joined(separator: "，")
    }
}

// MARK: - 自适应信息区

/// 把自定义信息区放进列表第一节的单行 cell 里。
/// 相比 tableHeaderView，自适应行高在 Dynamic Type 下的行为是确定的，不需要手工测量。
final class MonoHostCell: UITableViewCell {

    init(content: UIView) {
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none
        backgroundColor = DesignTokens.background
        contentView.backgroundColor = .clear
        content.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentView.topAnchor),
            content.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
