//
//  TrackListHeaderView.swift
//  Mono
//
//  Created by Claude on 2026/03/29.
//

import UIKit

final class TrackListHeaderView: UIView {

    // MARK: - Callback

    var onResumePlay: (() -> Void)?

    // MARK: - UI

    private let coverContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.surfaceVariant
        view.layer.cornerRadius = DesignTokens.CornerRadius.xl
        view.clipsToBounds = false
        return view
    }()

    private let musicNoteIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = DesignTokens.primary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyMedium
        label.textColor = DesignTokens.secondary
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    private let resumeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = DesignTokens.CornerRadius.xl
        button.clipsToBounds = true
        return button
    }()

    private var gradientLayer: CAGradientLayer?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = resumeButton.bounds

        // Update shadow path for cover
        coverContainer.layer.shadowPath = UIBezierPath(
            roundedRect: coverContainer.bounds,
            cornerRadius: DesignTokens.CornerRadius.xl
        ).cgPath
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear

        addSubview(coverContainer)
        coverContainer.addSubview(musicNoteIcon)
        addSubview(metadataLabel)
        addSubview(resumeButton)

        // Apply warm shadow to cover
        DesignTokens.applyWarmShadow(to: coverContainer.layer)

        // Gradient for button
        let gradient = DesignTokens.amberGlowGradient(for: .zero)
        resumeButton.layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient

        // Button action
        resumeButton.addTarget(self, action: #selector(resumeButtonTapped), for: .touchUpInside)

        // Cover constraints: full width - 48pt padding (24pt each side), 1:1 aspect ratio
        NSLayoutConstraint.activate([
            coverContainer.topAnchor.constraint(equalTo: topAnchor),
            coverContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            coverContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            coverContainer.heightAnchor.constraint(equalTo: coverContainer.widthAnchor),

            musicNoteIcon.centerXAnchor.constraint(equalTo: coverContainer.centerXAnchor),
            musicNoteIcon.centerYAnchor.constraint(equalTo: coverContainer.centerYAnchor),
            musicNoteIcon.widthAnchor.constraint(equalToConstant: 80),
            musicNoteIcon.heightAnchor.constraint(equalToConstant: 80),
        ])

        // Metadata: 8pt below cover, centered
        NSLayoutConstraint.activate([
            metadataLabel.topAnchor.constraint(equalTo: coverContainer.bottomAnchor, constant: DesignTokens.Spacing.sm),
            metadataLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            metadataLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
        ])

        // Resume button: 12pt below metadata, full width with 24pt padding, 52pt height
        NSLayoutConstraint.activate([
            resumeButton.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: DesignTokens.Spacing.md),
            resumeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.Spacing.xl),
            resumeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.Spacing.xl),
            resumeButton.heightAnchor.constraint(equalToConstant: 52),
            resumeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.Spacing.xl),
        ])
    }

    // MARK: - Configure

    func configure(trackCount: Int, totalDuration: String, progress: String, resumeChapter: String?) {
        metadataLabel.text = "\(trackCount) 个章节 · \(totalDuration) · 已听 \(progress)"

        let buttonTitle: String
        if let chapter = resumeChapter {
            buttonTitle = "继续播放 \(chapter)"
        } else {
            buttonTitle = "开始播放"
        }

        // Build attributed string with play icon + text
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: "play.fill")?.withTintColor(.white, renderingMode: .alwaysOriginal)
        let iconSize: CGFloat = 14
        attachment.bounds = CGRect(x: 0, y: -2, width: iconSize, height: iconSize)

        let attrString = NSMutableAttributedString(attachment: attachment)
        attrString.append(NSAttributedString(string: " \(buttonTitle)", attributes: [
            .font: DesignTokens.labelLarge,
            .foregroundColor: UIColor.white,
        ]))

        resumeButton.setAttributedTitle(attrString, for: .normal)
    }

    // MARK: - Actions

    @objc private func resumeButtonTapped() {
        onResumePlay?()
    }
}
