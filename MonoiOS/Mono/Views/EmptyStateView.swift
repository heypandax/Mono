//
//  EmptyStateView.swift
//  Mono
//
//  空书库（Master 的 MEmpty）。只解释导入协议，唯一主动作是「如何导入有声书」。
//

import UIKit

final class EmptyStateView: UIView {

    var onImportHelpTapped: (() -> Void)?

    // MARK: - UI

    private let titleLabel = MonoUI.label(.title2, weight: .bold, color: DesignTokens.onSurface)
    private let leadLabel = MonoUI.label(.body, color: DesignTokens.onSurfaceVariant)
    private let bulletStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = DesignTokens.Spacing.sm
        return stack
    }()

    private let actionButton = MonoPrimaryButton(kind: .filled)

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = DesignTokens.Spacing.md
        return stack
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        return scroll
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = DesignTokens.background
        accessibilityIdentifier = "library.empty"

        titleLabel.text = "书库还是空的"
        leadLabel.text = "Mono 按文件夹组织有声书："
        ["一本书 = 一个文件夹", "一章 = 一个音频文件"].forEach { bulletStack.addArrangedSubview(makeBullet($0)) }

        actionButton.apply(title: "如何导入有声书", symbol: "tray.and.arrow.down")
        actionButton.accessibilityIdentifier = "library.empty.importHelp"
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        addSubview(scrollView)
        scrollView.addSubview(contentStack)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(leadLabel)
        contentStack.addArrangedSubview(bulletStack)
        contentStack.setCustomSpacing(DesignTokens.Spacing.xl, after: bulletStack)
        contentStack.addArrangedSubview(actionButton)

        let inset = DesignTokens.contentInset + DesignTokens.Spacing.md

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: DesignTokens.Spacing.xl),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.xl),
            contentStack.centerYAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerYAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: inset),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -inset),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -inset * 2),
            scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    private func makeBullet(_ text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = DesignTokens.onSurfaceVariant
        dot.layer.cornerRadius = 2.5

        let label = MonoUI.label(.body, color: DesignTokens.onSurface)
        label.text = text

        container.addSubview(dot)
        container.addSubview(label)
        container.isAccessibilityElement = true
        container.accessibilityLabel = text

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dot.widthAnchor.constraint(equalToConstant: 5),
            dot.heightAnchor.constraint(equalToConstant: 5),
            dot.centerYAnchor.constraint(equalTo: label.firstBaselineAnchor, constant: -5),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    // MARK: - Actions

    @objc private func actionTapped() {
        onImportHelpTapped?()
    }
}
