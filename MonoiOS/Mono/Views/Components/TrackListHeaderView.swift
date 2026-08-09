//
//  TrackListHeaderView.swift
//  Mono
//
//  书内章节页的顶部信息区（Master 的 MChapterList 头部）。
//  没有假封面，也不展示推断出来的整本进度。
//

import UIKit

final class TrackListHeaderView: UIView {

    /// 唯一主动作：从第 1 章开始 / 继续第 N 章
    var onPrimaryAction: (() -> Void)?

    // MARK: - UI

    private let titleLabel = MonoUI.label(.title2, weight: .bold, color: DesignTokens.onSurface, lines: 2)
    private let metaLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 0, numeric: true)
    private let currentChapterLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 0, numeric: true)
    private let ctaButton = MonoPrimaryButton(kind: .filled)
    private let separator = MonoSeparatorView()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 3
        return stack
    }()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        setupUI()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TrackListHeaderView, _) in
            view.updateAdaptiveLayout()
        }
        updateAdaptiveLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = DesignTokens.background

        ctaButton.accessibilityIdentifier = "chapters.cta"
        ctaButton.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)

        addSubview(stack)
        addSubview(separator)
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(7, after: titleLabel)
        stack.addArrangedSubview(metaLabel)
        stack.addArrangedSubview(currentChapterLabel)
        stack.setCustomSpacing(DesignTokens.Spacing.lg, after: currentChapterLabel)
        stack.addArrangedSubview(ctaButton)

        let inset = DesignTokens.contentInset
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.sm),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            stack.bottomAnchor.constraint(equalTo: separator.topAnchor, constant: -DesignTokens.Spacing.lg),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func updateAdaptiveLayout() {
        titleLabel.numberOfLines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? 4 : 2
    }

    // MARK: - Configure

    /// - Parameters:
    ///   - currentChapterText: 没有上次收听章节时传 nil，该行隐藏
    func configure(bookTitle: String,
                   meta: String,
                   currentChapterText: String?,
                   ctaTitle: String) {
        titleLabel.text = bookTitle
        metaLabel.text = meta
        currentChapterLabel.text = currentChapterText
        currentChapterLabel.isHidden = currentChapterText == nil
        ctaButton.apply(title: ctaTitle, symbol: "play.fill")

        titleLabel.accessibilityLabel = [bookTitle, meta, currentChapterText]
            .compactMap { $0 }
            .joined(separator: "，")
        titleLabel.accessibilityTraits = .header
        metaLabel.isAccessibilityElement = false
        currentChapterLabel.isAccessibilityElement = false
    }

    // MARK: - Actions

    @objc private func primaryActionTapped() {
        onPrimaryAction?()
    }
}
