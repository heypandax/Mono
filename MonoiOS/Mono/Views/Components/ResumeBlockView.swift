//
//  ResumeBlockView.swift
//  Mono
//
//  书库首屏的「继续收听」区域（Master 的 MResume）。
//  只展示可靠事实：当前书、完整章节标题、第 N / M 章、章内时间与章内进度。
//  没有整本百分比，也没有整本进度条。
//

import UIKit

final class ResumeBlockView: UIView {

    /// 唯一主动作
    var onPrimaryAction: (() -> Void)?

    // MARK: - UI

    private let stateMarker: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.primary
        view.layer.cornerRadius = 1.5
        return view
    }()

    private let stateLabel = MonoUI.label(.caption2, weight: .semibold, color: DesignTokens.primary, lines: 1)
    private let chapterLabel = MonoUI.label(.title3, weight: .semibold, color: DesignTokens.onSurface, lines: 2)
    private let bookLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 2)
    private let positionLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 1, numeric: true)
    private let remainingLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 1, numeric: true)
    private let progressBar = MonoProgressBarView()
    private let ctaButton = MonoPrimaryButton(kind: .filled)

    /// 时间行在大字号下会换行，所以用可换行的水平堆叠
    private let timeStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = DesignTokens.Spacing.md
        return stack
    }()

    /// 合并成一个无障碍元素的信息区（CTA 单独成为按钮）
    private let infoContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isAccessibilityElement = true
        return view
    }()

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = DesignTokens.background
        setupUI()

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: ResumeBlockView, _) in
            view.updateAdaptiveLayout()
        }
        updateAdaptiveLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        addSubview(infoContainer)
        [stateMarker, stateLabel, chapterLabel, bookLabel, timeStack, progressBar].forEach(infoContainer.addSubview)
        timeStack.addArrangedSubview(positionLabel)
        timeStack.addArrangedSubview(remainingLabel)
        remainingLabel.textAlignment = .right
        positionLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        ctaButton.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)
        ctaButton.accessibilityIdentifier = "library.resume.cta"
        addSubview(ctaButton)

        let inset = DesignTokens.contentInset

        NSLayoutConstraint.activate([
            infoContainer.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.Spacing.sm),
            infoContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            infoContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),

            stateMarker.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor),
            stateMarker.centerYAnchor.constraint(equalTo: stateLabel.centerYAnchor),
            stateMarker.widthAnchor.constraint(equalToConstant: 3),
            stateMarker.heightAnchor.constraint(equalTo: stateLabel.heightAnchor, multiplier: 0.9),

            stateLabel.topAnchor.constraint(equalTo: infoContainer.topAnchor),
            stateLabel.leadingAnchor.constraint(equalTo: stateMarker.trailingAnchor, constant: 7),
            stateLabel.trailingAnchor.constraint(lessThanOrEqualTo: infoContainer.trailingAnchor),

            chapterLabel.topAnchor.constraint(equalTo: stateLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            chapterLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor),
            chapterLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor),

            bookLabel.topAnchor.constraint(equalTo: chapterLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            bookLabel.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor),
            bookLabel.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor),

            timeStack.topAnchor.constraint(equalTo: bookLabel.bottomAnchor, constant: 6),
            timeStack.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor),
            timeStack.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor),

            progressBar.topAnchor.constraint(equalTo: timeStack.bottomAnchor, constant: 6),
            progressBar.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: infoContainer.bottomAnchor),

            ctaButton.topAnchor.constraint(equalTo: infoContainer.bottomAnchor, constant: DesignTokens.Spacing.md),
            ctaButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            ctaButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -inset),
            ctaButton.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            ctaButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])

        let ctaWidth = ctaButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset)
        ctaWidth.priority = .defaultHigh
        ctaWidth.isActive = true
    }

    private func updateAdaptiveLayout() {
        // 大字号下允许长章节名多占一行，而不是中途截断
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        chapterLabel.numberOfLines = isAccessibilitySize ? 3 : 2
        timeStack.axis = isAccessibilitySize ? .vertical : .horizontal
        timeStack.alignment = isAccessibilitySize ? .leading : .firstBaseline
        remainingLabel.textAlignment = isAccessibilitySize ? .left : .right
    }

    // MARK: - Configure

    func configure(with presentation: NowPlayingPresentation) {
        stateLabel.text = presentation.stateText
        chapterLabel.text = presentation.chapterTitle
        bookLabel.text = presentation.bookName
        positionLabel.text = "\(presentation.chapterIndexText) · \(presentation.elapsedOverDurationText)"
        remainingLabel.text = presentation.remainingText
        progressBar.fraction = presentation.chapterFraction

        infoContainer.accessibilityLabel = presentation.accessibilityLabel
        ctaButton.apply(title: presentation.callToAction, symbol: presentation.callToActionSymbol)
    }

    // MARK: - Actions

    @objc private func primaryActionTapped() {
        onPrimaryAction?()
    }
}
