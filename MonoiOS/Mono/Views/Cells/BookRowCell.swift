//
//  BookRowCell.swift
//  Mono
//
//  书库与搜索结果共用的平整书行（Master 的 MBookRow）。
//  没有假封面，没有整本百分比；状态同时由文字和图形表达，不只靠颜色。
//

import UIKit

final class BookRowCell: UITableViewCell {

    static let identifier = "BookRowCell"
    /// 分隔线左缩进 = 边距 + 标记宽 + 间距
    static let separatorLeftInset: CGFloat = DesignTokens.contentInset + 44 + DesignTokens.Spacing.md

    // MARK: - UI

    private let tileView = MonoGlyphTileView()
    private let titleLabel = MonoUI.label(.headline, color: DesignTokens.onSurface, lines: 2)
    private let metaLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 0, numeric: true)
    private let statusIcon = MonoUI.symbolView("circle", style: .caption2, color: DesignTokens.onSurfaceVariant)
    private let statusLabel = MonoUI.label(.caption1, color: DesignTokens.onSurfaceVariant, lines: 0, numeric: true)

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = DesignTokens.Spacing.xs
        return stack
    }()

    private let statusStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        return stack
    }()

    private var tileSizeConstraints: [NSLayoutConstraint] = []

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: BookRowCell, _) in
            cell.updateAdaptiveLayout()
        }
        updateAdaptiveLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = DesignTokens.background
        contentView.backgroundColor = .clear
        let selected = UIView()
        selected.backgroundColor = DesignTokens.surfaceContainer
        selectedBackgroundView = selected

        contentView.addSubview(tileView)
        contentView.addSubview(textStack)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(metaLabel)
        textStack.addArrangedSubview(statusStack)
        statusStack.addArrangedSubview(statusIcon)
        statusStack.addArrangedSubview(statusLabel)

        let tileWidth = tileView.widthAnchor.constraint(equalToConstant: 44)
        let tileHeight = tileView.heightAnchor.constraint(equalToConstant: 44)
        tileSizeConstraints = [tileWidth, tileHeight]

        NSLayoutConstraint.activate([
            tileView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
            tileView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.contentInset),
            tileWidth,
            tileHeight,

            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
            textStack.leadingAnchor.constraint(equalTo: tileView.trailingAnchor, constant: DesignTokens.Spacing.md),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.contentInset),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget)
        ])

        // 合并语义：整行朗读书名、章节数、时长与状态
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "library.book.row"
    }

    private func updateAdaptiveLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        titleLabel.numberOfLines = isAccessibilitySize ? 3 : 2
        // 标记随字号放大但设上限，避免大字号下挤走正文
        let scaled = min(UIFontMetrics(forTextStyle: .headline).scaledValue(for: 44), 62)
        tileSizeConstraints.forEach { $0.constant = scaled }
        // 标记放大后分隔线起点必须跟着走，才能对齐正文左边缘
        separatorInset = UIEdgeInsets(
            top: 0,
            left: DesignTokens.contentInset + scaled + DesignTokens.Spacing.md,
            bottom: 0,
            right: 0
        )
    }

    // MARK: - Configure

    func configure(with presentation: BookPresentation) {
        tileView.apply(title: presentation.title)
        titleLabel.text = presentation.title
        metaLabel.text = presentation.metaText
        statusLabel.text = presentation.statusText

        switch presentation.status {
        case .notStarted:
            statusIcon.image = UIImage(systemName: "circle")
        case .listening:
            statusIcon.image = UIImage(systemName: "play.fill")
        }

        accessibilityLabel = presentation.accessibilityLabel
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        metaLabel.text = nil
        statusLabel.text = nil
        accessibilityLabel = nil
    }
}
