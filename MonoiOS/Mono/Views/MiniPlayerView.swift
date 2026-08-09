//
//  MiniPlayerView.swift
//  Mono
//
//  迷你播放器（Master 的 MMini）。只在播放器真的加载了某一章时出现，
//  播放/暂停图标必须与真实 isPlaying 一致。
//

import UIKit

final class MiniPlayerView: UIView {

    /// 点击信息区展开全屏播放器
    var onTap: (() -> Void)?

    // MARK: - UI

    private let topSeparator = MonoSeparatorView()
    private let progressBar = MonoProgressBarView(height: 2, rounded: false)

    private let infoControl: UIControl = {
        let control = UIControl()
        control.translatesAutoresizingMaskIntoConstraints = false
        control.isAccessibilityElement = true
        control.accessibilityTraits = .button
        control.accessibilityIdentifier = "miniPlayer.open"
        return control
    }()

    private let titleLabel = MonoUI.label(.subheadline, weight: .semibold, color: DesignTokens.onSurface, lines: 1)
    private let subtitleLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 1, numeric: true)

    private lazy var playPauseButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "play.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        config.baseForegroundColor = DesignTokens.onSurface
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "miniPlayer.playPause"
        return button
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        AudioPlayerManager.shared.addDelegate(self)
        refreshUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Metrics

    /// 迷你播放器实际盖住内容的高度。
    /// 背景铺到屏幕底部，所以总高里包含底部安全区；而宿主 scroll view 的
    /// adjustedContentInset 已经含同一段安全区，直接用 bounds.height 会重复计入。
    var contentOverlapHeight: CGFloat {
        isHidden ? 0 : max(0, bounds.height - safeAreaInsets.bottom)
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = DesignTokens.elevatedSurface
        accessibilityIdentifier = "miniPlayer.root"

        addSubview(topSeparator)
        addSubview(progressBar)
        addSubview(infoControl)
        infoControl.addSubview(titleLabel)
        infoControl.addSubview(subtitleLabel)
        addSubview(playPauseButton)

        titleLabel.isAccessibilityElement = false
        subtitleLabel.isAccessibilityElement = false
        infoControl.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),

            progressBar.topAnchor.constraint(equalTo: topSeparator.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            // 背景与进度线全宽出血，但文字与按钮必须落在自己的安全区内：
            // 刘海横屏、以及底部 Home Indicator 都靠这里躲开
            infoControl.topAnchor.constraint(equalTo: progressBar.bottomAnchor),
            infoControl.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: DesignTokens.contentInset),
            infoControl.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            infoControl.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -DesignTokens.Spacing.sm),

            titleLabel.topAnchor.constraint(equalTo: infoControl.topAnchor, constant: DesignTokens.Spacing.sm),
            titleLabel.leadingAnchor.constraint(equalTo: infoControl.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: infoControl.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: infoControl.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: infoControl.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: infoControl.bottomAnchor, constant: -DesignTokens.Spacing.sm),

            playPauseButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            playPauseButton.centerYAnchor.constraint(equalTo: infoControl.centerYAnchor),
            playPauseButton.widthAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget),
            playPauseButton.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget),

            // 最小高度只约束安全区以上的可见内容，不把 Home Indicator 那段算进去
            safeAreaLayoutGuide.bottomAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 58)
        ])
    }

    // MARK: - Actions

    @objc private func playPauseTapped() {
        AudioPlayerManager.shared.togglePlayPause()
    }

    @objc private func infoTapped() {
        onTap?()
    }

    // MARK: - Update

    /// 刷新章节名、书名、倍速、进度与播放态
    func refreshUI() {
        let player = AudioPlayerManager.shared
        guard let track = player.currentTrack else {
            titleLabel.text = nil
            subtitleLabel.text = nil
            progressBar.fraction = 0
            infoControl.accessibilityLabel = nil
            return
        }

        titleLabel.text = track.displayName
        subtitleLabel.text = "\(track.folderName) · \(MonoFormat.rateText(player.playbackRate))"
        updateInfoAccessibility(for: track, isPlaying: player.isPlaying)
        infoControl.accessibilityHint = "打开全屏播放器"

        updatePlayPauseButton(isPlaying: player.isPlaying)
        updateProgress(current: player.currentTime, duration: player.duration)
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        playPauseButton.configuration?.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
        playPauseButton.accessibilityLabel = isPlaying ? "暂停" : "播放"
    }

    private func updateInfoAccessibility(for track: AudioTrack, isPlaying: Bool) {
        let playbackState = isPlaying ? "正在播放" : "已暂停"
        infoControl.accessibilityLabel = "\(playbackState)：\(track.displayName)，\(track.folderName)"
    }

    private func updateProgress(current: TimeInterval, duration: TimeInterval) {
        guard let resolved = PlaybackPresenter.resolvedDuration(duration), current.isFinite else {
            progressBar.fraction = 0
            return
        }
        progressBar.fraction = min(max(current / resolved, 0), 1)
    }
}

// MARK: - AudioPlayerDelegate

extension MiniPlayerView: AudioPlayerDelegate {

    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        updateProgress(current: currentTime, duration: duration)
    }

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        updatePlayPauseButton(isPlaying: isPlaying)
        if let track = AudioPlayerManager.shared.currentTrack {
            updateInfoAccessibility(for: track, isPlaying: isPlaying)
        }
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        refreshUI()
    }

    func playerDidFinishTrack() {}
}
