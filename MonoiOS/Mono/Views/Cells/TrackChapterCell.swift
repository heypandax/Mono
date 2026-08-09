//
//  TrackChapterCell.swift
//  Mono
//
//  章节行（Master 的 MChapterRow）。当前章由「短蓝竖线 + 播放/暂停图标 + 文字状态」
//  共同表达，不只靠颜色；本版本不渲染「已完成章」。
//

import UIKit

final class TrackChapterCell: UITableViewCell {

    static let identifier = "TrackChapterCell"
    /// 分隔线左缩进 = 边距 + 序号列宽 + 间距
    static let separatorLeftInset: CGFloat = DesignTokens.contentInset + 26 + DesignTokens.Spacing.md

    /// 章节行状态。没有「已完成」这一档
    enum State: Equatable {
        case plain
        case current(isPlaying: Bool, elapsed: TimeInterval, duration: TimeInterval?)
    }

    // MARK: - UI

    private let numberLabel = MonoUI.label(.subheadline, weight: .medium, color: DesignTokens.onSurfaceVariant, lines: 1, numeric: true)

    private let currentMarker: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.primary
        view.layer.cornerRadius = 1.5
        return view
    }()

    private let currentIcon = MonoUI.symbolView("play.fill", style: .caption1, color: DesignTokens.primary)
    private let titleLabel = MonoUI.label(.body, color: DesignTokens.onSurface, lines: 2)
    private let stateLabel = MonoUI.label(.caption1, color: DesignTokens.onSurfaceVariant, lines: 0, numeric: true)
    private let durationLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 1, numeric: true)

    private let leadingColumn: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        return stack
    }()

    private var columnWidthConstraint: NSLayoutConstraint?
    private var markerHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: TrackChapterCell, _) in
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

        contentView.addSubview(leadingColumn)
        leadingColumn.addSubview(numberLabel)
        leadingColumn.addSubview(currentMarker)
        leadingColumn.addSubview(currentIcon)
        contentView.addSubview(textStack)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(stateLabel)
        contentView.addSubview(durationLabel)

        durationLabel.setContentHuggingPriority(.required, for: .horizontal)
        durationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let columnWidth = leadingColumn.widthAnchor.constraint(equalToConstant: 26)
        columnWidthConstraint = columnWidth
        let markerHeight = currentMarker.heightAnchor.constraint(equalToConstant: 16)
        markerHeightConstraint = markerHeight

        NSLayoutConstraint.activate([
            leadingColumn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
            leadingColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.contentInset),
            columnWidth,

            numberLabel.topAnchor.constraint(equalTo: leadingColumn.topAnchor),
            numberLabel.centerXAnchor.constraint(equalTo: leadingColumn.centerXAnchor),
            numberLabel.bottomAnchor.constraint(lessThanOrEqualTo: leadingColumn.bottomAnchor),

            currentMarker.leadingAnchor.constraint(equalTo: leadingColumn.leadingAnchor),
            currentMarker.centerYAnchor.constraint(equalTo: currentIcon.centerYAnchor),
            currentMarker.widthAnchor.constraint(equalToConstant: 3),
            markerHeight,

            currentIcon.topAnchor.constraint(equalTo: leadingColumn.topAnchor, constant: 1),
            currentIcon.leadingAnchor.constraint(equalTo: currentMarker.trailingAnchor, constant: 6),
            currentIcon.trailingAnchor.constraint(lessThanOrEqualTo: leadingColumn.trailingAnchor),
            currentIcon.bottomAnchor.constraint(lessThanOrEqualTo: leadingColumn.bottomAnchor),
            currentMarker.bottomAnchor.constraint(lessThanOrEqualTo: leadingColumn.bottomAnchor),

            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
            textStack.leadingAnchor.constraint(equalTo: leadingColumn.trailingAnchor, constant: DesignTokens.Spacing.md),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11),

            durationLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            durationLabel.leadingAnchor.constraint(equalTo: textStack.trailingAnchor, constant: DesignTokens.Spacing.sm),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.contentInset),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget)
        ])

        // 序号列高度只由其中最高的子视图决定，避免布局不确定
        let columnHeight = leadingColumn.heightAnchor.constraint(equalToConstant: 0)
        columnHeight.priority = .defaultLow
        columnHeight.isActive = true

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "chapters.chapter.row"
    }

    private func updateAdaptiveLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        titleLabel.numberOfLines = isAccessibilitySize ? 3 : 2
        let columnWidth = min(UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 26), 40)
        columnWidthConstraint?.constant = columnWidth
        markerHeightConstraint?.constant = min(UIFontMetrics(forTextStyle: .body).scaledValue(for: 16), 30)
        // 序号列在辅助字号下会变宽，分隔线起点必须跟着走，才能对齐正文左边缘
        separatorInset = UIEdgeInsets(
            top: 0,
            left: DesignTokens.contentInset + columnWidth + DesignTokens.Spacing.md,
            bottom: 0,
            right: 0
        )
    }

    // MARK: - Configure

    func configure(index: Int, title: String, duration: TimeInterval?, state: State) {
        // 当前章的时长只有一个来源：播放器已知的合法时长优先，异步文件时长兜底。
        // 状态行、右侧时长与 VoiceOver 都用它，避免同一行出现 “0:24” 与 “—” 并存
        let effectiveDuration: TimeInterval?
        if case let .current(_, _, playerDuration) = state {
            effectiveDuration = playerDuration ?? duration
        } else {
            effectiveDuration = duration
        }

        numberLabel.text = String(format: "%02d", index)
        titleLabel.text = title
        durationLabel.text = MonoFormat.totalOrPlaceholder(effectiveDuration)

        var accessibilityParts = ["第 \(index) 章", title]

        switch state {
        case .plain:
            numberLabel.isHidden = false
            currentMarker.isHidden = true
            currentIcon.isHidden = true
            stateLabel.isHidden = true
            titleLabel.font = DesignTokens.font(.body)
            titleLabel.textColor = DesignTokens.onSurface

        case let .current(isPlaying, elapsed, _):
            numberLabel.isHidden = true
            currentMarker.isHidden = false
            currentIcon.isHidden = false
            currentIcon.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
            titleLabel.font = DesignTokens.font(.headline)
            titleLabel.textColor = DesignTokens.primary

            let stateText = isPlaying ? "正在播放" : "已暂停"
            let position = "\(MonoFormat.elapsedText(elapsed)) / \(MonoFormat.totalOrPlaceholder(effectiveDuration))"
            stateLabel.text = "\(stateText) · \(position)"
            stateLabel.isHidden = false

            accessibilityParts.append(stateText)
            accessibilityParts.append("已播 \(MonoFormat.spokenElapsed(elapsed))")
        }

        accessibilityParts.append(
            effectiveDuration.map { MonoFormat.spokenTime($0) } ?? MonoFormat.unresolvedDurationAccessibility
        )
        accessibilityLabel = accessibilityParts.joined(separator: "，")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        stateLabel.text = nil
        durationLabel.text = nil
        accessibilityLabel = nil
    }
}
