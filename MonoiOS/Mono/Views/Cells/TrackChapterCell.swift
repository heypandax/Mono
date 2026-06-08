//
//  TrackChapterCell.swift
//  Mono
//
//  Created by Claude on 2026/03/29.
//

import UIKit

final class TrackChapterCell: UITableViewCell {

    static let identifier = "TrackChapterCell"

    // MARK: - UI

    /// Left area container (40pt width)
    private let statusContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Normal state: chapter number
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.labelMedium
        label.textColor = DesignTokens.secondary
        label.textAlignment = .center
        return label
    }()

    /// Completed state: checkmark icon
    private let completedIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.tintColor = DesignTokens.primary
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()

    /// Playing state: waveform icon
    private let playingIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "waveform")
        imageView.tintColor = DesignTokens.primaryContainer
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()

    /// Center: chapter name
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyLarge
        label.textColor = DesignTokens.onSurface
        label.numberOfLines = 2
        return label
    }()

    /// Right: duration
    private let durationLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.labelMedium
        label.textColor = DesignTokens.outline
        label.textAlignment = .right
        return label
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
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        accessoryType = .none
        separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)

        contentView.addSubview(statusContainer)
        statusContainer.addSubview(numberLabel)
        statusContainer.addSubview(completedIcon)
        statusContainer.addSubview(playingIcon)
        contentView.addSubview(nameLabel)
        contentView.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            // Status container: 40pt wide, vertically centered
            statusContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DesignTokens.Spacing.lg),
            statusContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusContainer.widthAnchor.constraint(equalToConstant: 40),
            statusContainer.heightAnchor.constraint(equalToConstant: 40),

            // Number label centered in container
            numberLabel.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),

            // Completed icon centered in container
            completedIcon.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            completedIcon.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            completedIcon.widthAnchor.constraint(equalToConstant: 20),
            completedIcon.heightAnchor.constraint(equalToConstant: 20),

            // Playing icon centered in container
            playingIcon.centerXAnchor.constraint(equalTo: statusContainer.centerXAnchor),
            playingIcon.centerYAnchor.constraint(equalTo: statusContainer.centerYAnchor),
            playingIcon.widthAnchor.constraint(equalToConstant: 20),
            playingIcon.heightAnchor.constraint(equalToConstant: 20),

            // Name label
            nameLabel.leadingAnchor.constraint(equalTo: statusContainer.trailingAnchor, constant: DesignTokens.Spacing.sm),
            nameLabel.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -DesignTokens.Spacing.sm),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Duration label
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            durationLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            durationLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
        ])
    }

    // MARK: - Configure

    func configure(with track: AudioTrack, index: Int, isPlaying: Bool, isCompleted: Bool) {
        nameLabel.text = track.displayName
        durationLabel.text = track.duration.formattedTime
        numberLabel.text = "\(index)"

        if isPlaying {
            // Playing state
            numberLabel.isHidden = true
            completedIcon.isHidden = true
            playingIcon.isHidden = false
            nameLabel.textColor = DesignTokens.primaryContainer
        } else if isCompleted {
            // Completed state
            numberLabel.isHidden = true
            completedIcon.isHidden = false
            playingIcon.isHidden = true
            nameLabel.textColor = DesignTokens.onSurface
        } else {
            // Normal state
            numberLabel.isHidden = false
            completedIcon.isHidden = true
            playingIcon.isHidden = true
            nameLabel.textColor = DesignTokens.onSurface
        }
    }
}
