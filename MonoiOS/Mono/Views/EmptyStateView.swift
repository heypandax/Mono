//
//  EmptyStateView.swift
//  Mono
//
//  Created by Phase 3 UI Overhaul
//

import UIKit

final class EmptyStateView: UIView {

    // MARK: - Callback

    var onImportHelpTapped: (() -> Void)?

    // MARK: - UI Elements

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = DesignTokens.Spacing.xl
        return stack
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "headphones", withConfiguration: UIImage.SymbolConfiguration(pointSize: 60, weight: .regular))
        imageView.tintColor = DesignTokens.surfaceVariant
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "还没有任何有声书"
        label.font = DesignTokens.headlineMedium
        label.textColor = DesignTokens.onSurface
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "通过 Finder 或 iTunes 将音频\n文件夹传输到此 App 即可开始"
        label.font = DesignTokens.bodyMedium
        label.textColor = DesignTokens.secondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var linkButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("了解如何导入 \u{203A}", for: .normal)
        button.titleLabel?.font = DesignTokens.labelLarge
        button.setTitleColor(DesignTokens.primaryContainer, for: .normal)
        button.addTarget(self, action: #selector(linkTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear

        addSubview(stackView)

        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(bodyLabel)
        stackView.addArrangedSubview(linkButton)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.xxxl),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.xxxl),
        ])
    }

    // MARK: - Actions

    @objc private func linkTapped() {
        onImportHelpTapped?()
    }
}
