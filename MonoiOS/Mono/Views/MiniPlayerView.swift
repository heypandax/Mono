//
//  MiniPlayerView.swift
//  Mono
//
//  Created by Phase 3 UI Overhaul
//

import UIKit

final class MiniPlayerView: UIView {

    var onTap: (() -> Void)?

    // MARK: - UI

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.surfaceContainer
        view.layer.cornerRadius = DesignTokens.CornerRadius.large
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()

    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.progressTintColor = DesignTokens.primaryContainer
        progress.trackTintColor = DesignTokens.surfaceVariant
        progress.progress = 0
        return progress
    }()

    private let trackIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "music.note")
        imageView.tintColor = DesignTokens.primary
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = DesignTokens.surfaceVariant
        imageView.layer.cornerRadius = 6
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyMedium
        label.textColor = DesignTokens.onSurface
        label.text = "未在播放"
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.labelSmall
        label.textColor = DesignTokens.secondary
        label.text = ""
        return label
    }()

    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22)), for: .normal)
        button.tintColor = DesignTokens.onSurface
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupObservers()
        updateUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(progressView)
        containerView.addSubview(trackIcon)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(playPauseButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            progressView.topAnchor.constraint(equalTo: containerView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            trackIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: DesignTokens.Spacing.md),
            trackIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            trackIcon.widthAnchor.constraint(equalToConstant: 44),
            trackIcon.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.leadingAnchor.constraint(equalTo: trackIcon.trailingAnchor, constant: DesignTokens.Spacing.md),
            titleLabel.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -DesignTokens.Spacing.md),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            playPauseButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -DesignTokens.Spacing.lg),
            playPauseButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        containerView.addGestureRecognizer(tapGesture)
    }

    private func setupObservers() {
        AudioPlayerManager.shared.addDelegate(self)
    }

    // MARK: - Actions

    @objc private func playPauseTapped() {
        AudioPlayerManager.shared.togglePlayPause()
    }

    @objc private func viewTapped() {
        onTap?()
    }

    // MARK: - Update UI

    /// Refresh mini player display (track name, playback state, etc.)
    func refreshUI() {
        let player = AudioPlayerManager.shared

        if let track = player.currentTrack {
            titleLabel.text = track.displayName
            subtitleLabel.text = track.folderName
        } else {
            titleLabel.text = "未在播放"
            subtitleLabel.text = ""
        }

        updatePlayPauseButton(isPlaying: player.isPlaying)

        let current = player.currentTime
        let duration = player.duration
        if duration > 0 && duration.isFinite {
            updateProgress(current: current, duration: duration)
        }
    }

    private func updateUI() {
        refreshUI()
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        let imageName = isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 22)), for: .normal)
    }

    private func updateProgress(current: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else {
            progressView.progress = 0
            return
        }
        progressView.progress = Float(current / duration)
    }
}

// MARK: - AudioPlayerDelegate
extension MiniPlayerView: AudioPlayerDelegate {
    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        updateProgress(current: currentTime, duration: duration)
    }

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        updatePlayPauseButton(isPlaying: isPlaying)
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateUI()
    }

    func playerDidFinishTrack() {
        // Handle track finished
    }
}
