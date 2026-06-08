//
//  AudiobookCardCell.swift
//  Mono
//
//  Created by Phase 3 UI Overhaul
//

import UIKit

enum AudiobookStatus {
    case listening
    case completed
    case notStarted
}

final class AudiobookCardCell: UITableViewCell {

    static let identifier = "AudiobookCardCell"

    // MARK: - UI Elements

    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.surfaceContainer
        view.layer.cornerRadius = DesignTokens.CornerRadius.xl
        view.clipsToBounds = false
        return view
    }()

    private let coverImageView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.surfaceVariant
        view.layer.cornerRadius = DesignTokens.CornerRadius.medium
        view.clipsToBounds = true
        return view
    }()

    private let coverIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = DesignTokens.primary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.headlineSmall
        label.textColor = DesignTokens.onSurface
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let metadataLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodySmall
        label.textColor = DesignTokens.secondary
        label.numberOfLines = 1
        return label
    }()

    private let statusBadge: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        return view
    }()

    private let statusIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.labelSmall
        label.numberOfLines = 1
        return label
    }()

    private let progressRing: ProgressRingView = {
        let ring = ProgressRingView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.lineWidth = 3
        return ring
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(cardView)
        cardView.addSubview(coverImageView)
        coverImageView.addSubview(coverIcon)
        cardView.addSubview(titleLabel)
        cardView.addSubview(metadataLabel)
        cardView.addSubview(statusBadge)
        statusBadge.addSubview(statusIcon)
        statusBadge.addSubview(statusLabel)
        cardView.addSubview(progressRing)

        let cardPadding: CGFloat = DesignTokens.Spacing.lg

        NSLayoutConstraint.activate([
            // Card container
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: DesignTokens.Spacing.sm),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DesignTokens.Spacing.sm),

            // Cover image
            coverImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: cardPadding),
            coverImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 64),
            coverImageView.heightAnchor.constraint(equalToConstant: 64),

            // Cover icon
            coverIcon.centerXAnchor.constraint(equalTo: coverImageView.centerXAnchor),
            coverIcon.centerYAnchor.constraint(equalTo: coverImageView.centerYAnchor),
            coverIcon.widthAnchor.constraint(equalToConstant: 28),
            coverIcon.heightAnchor.constraint(equalToConstant: 28),

            // Progress ring
            progressRing.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -cardPadding),
            progressRing.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            progressRing.widthAnchor.constraint(equalToConstant: 40),
            progressRing.heightAnchor.constraint(equalToConstant: 40),

            // Title
            titleLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: DesignTokens.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: progressRing.leadingAnchor, constant: -DesignTokens.Spacing.md),
            titleLabel.topAnchor.constraint(equalTo: coverImageView.topAnchor, constant: 2),

            // Metadata
            metadataLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metadataLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            metadataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),

            // Status badge
            statusBadge.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusBadge.topAnchor.constraint(equalTo: metadataLabel.bottomAnchor, constant: DesignTokens.Spacing.sm),
            statusBadge.heightAnchor.constraint(equalToConstant: 20),

            // Status icon
            statusIcon.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 8),
            statusIcon.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 10),
            statusIcon.heightAnchor.constraint(equalToConstant: 10),

            // Status label
            statusLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -8),
            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
        ])

        DesignTokens.applyWarmShadow(to: cardView.layer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardView.layer.shadowPath = UIBezierPath(
            roundedRect: cardView.bounds,
            cornerRadius: DesignTokens.CornerRadius.xl
        ).cgPath
    }

    // MARK: - Configuration

    func configure(
        folder: AudioFolder,
        trackCount: Int,
        totalDurationFormatted: String,
        progress: CGFloat,
        status: AudiobookStatus,
        lastActivity: String?
    ) {
        titleLabel.text = folder.name
        metadataLabel.text = "\(trackCount) 个章节 \u{00B7} \(totalDurationFormatted)"
        progressRing.progress = progress

        configureStatusBadge(status: status)
    }

    private func configureStatusBadge(status: AudiobookStatus) {
        switch status {
        case .listening:
            statusBadge.backgroundColor = DesignTokens.primaryContainer
            statusLabel.text = "正在听"
            statusLabel.textColor = DesignTokens.onPrimary
            statusIcon.image = UIImage(systemName: "waveform", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold))
            statusIcon.tintColor = DesignTokens.onPrimary
            statusIcon.isHidden = false

        case .completed:
            statusBadge.backgroundColor = DesignTokens.surfaceVariant
            statusLabel.text = "已完成"
            statusLabel.textColor = DesignTokens.secondary
            statusIcon.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold))
            statusIcon.tintColor = DesignTokens.secondary
            statusIcon.isHidden = false

        case .notStarted:
            statusBadge.backgroundColor = DesignTokens.outlineVariant.withAlphaComponent(0.3)
            statusLabel.text = "未开始"
            statusLabel.textColor = DesignTokens.secondary
            statusIcon.image = nil
            statusIcon.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        metadataLabel.text = nil
        progressRing.progress = 0
    }
}
