//
//  PlayerViewController.swift
//  Mono
//
//  Created by 李大鹏 on 2025/12/20.
//

import UIKit

final class PlayerViewController: UIViewController {

    // MARK: - UI Components

    private let dragHandle: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.dragHandleColor
        view.layer.cornerRadius = DesignTokens.dragHandleHeight / 2
        return view
    }()

    private let nowPlayingLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "正在播放"
        label.font = DesignTokens.labelMedium
        label.textColor = DesignTokens.secondary
        label.textAlignment = .center
        return label
    }()

    private let trackIconView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.surfaceVariant
        view.layer.cornerRadius = DesignTokens.CornerRadius.xl
        view.clipsToBounds = false
        return view
    }()

    private let trackIconImage: UIImageView = {
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
        label.font = DesignTokens.headlineMedium
        label.textColor = DesignTokens.onSurface
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.bodyMedium
        label.textColor = DesignTokens.secondary
        label.textAlignment = .center
        return label
    }()

    private let progressSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = DesignTokens.primaryContainer
        slider.maximumTrackTintColor = DesignTokens.surfaceVariant
        slider.setThumbImage(makeThumbImage(size: 12), for: .normal)
        return slider
    }()

    private let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.monoDigits(size: 12)
        label.textColor = DesignTokens.secondary
        label.text = "00:00"
        return label
    }()

    private let remainingTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignTokens.monoDigits(size: 12)
        label.textColor = DesignTokens.secondary
        label.text = "-00:00"
        label.textAlignment = .right
        return label
    }()

    private lazy var previousButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 22)
        button.setImage(UIImage(systemName: "backward.end.fill", withConfiguration: config), for: .normal)
        button.tintColor = DesignTokens.onSurfaceVariant
        button.addTarget(self, action: #selector(previousTapped), for: .touchUpInside)
        return button
    }()

    private lazy var skipBackwardButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 28)
        button.setImage(UIImage(systemName: "gobackward.5", withConfiguration: config), for: .normal)
        button.tintColor = DesignTokens.onSurface
        button.addTarget(self, action: #selector(skipBackwardTapped), for: .touchUpInside)
        return button
    }()

    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 64)
        button.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = DesignTokens.primaryContainer
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        return button
    }()

    private lazy var skipForwardButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 28)
        button.setImage(UIImage(systemName: "goforward.5", withConfiguration: config), for: .normal)
        button.tintColor = DesignTokens.onSurface
        button.addTarget(self, action: #selector(skipForwardTapped), for: .touchUpInside)
        return button
    }()

    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 22)
        button.setImage(UIImage(systemName: "forward.end.fill", withConfiguration: config), for: .normal)
        button.tintColor = DesignTokens.onSurfaceVariant
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        return button
    }()

    // Bottom toolbar buttons
    private lazy var rateButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = DesignTokens.labelLarge
        button.setTitleColor(DesignTokens.onSurface, for: .normal)
        button.backgroundColor = DesignTokens.surfaceContainer
        button.layer.cornerRadius = DesignTokens.CornerRadius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        button.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)
        return button
    }()

    private lazy var sleepTimerButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(DesignTokens.onSurface, for: .normal)
        button.setImage(UIImage(systemName: "moon.zzz", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)), for: .normal)
        button.tintColor = DesignTokens.onSurface
        button.backgroundColor = DesignTokens.surfaceContainer
        button.layer.cornerRadius = DesignTokens.CornerRadius.medium
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        button.addTarget(self, action: #selector(sleepTimerTapped), for: .touchUpInside)
        return button
    }()

    // Controls container for horizontal layout
    private let controlsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    // Bottom toolbar container
    private let toolbarStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()

    // MARK: - State
    private var isSeeking = false
    private var lastSleepTimerState: String = ""

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupModalAppearance()
        setupUI()
        setupSliderActions()
        setupSleepTimerObserver()

        AudioPlayerManager.shared.addDelegate(self)
        updateUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Modal Setup
    private func setupModalAppearance() {
        if let sheet = sheetPresentationController {
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = DesignTokens.CornerRadius.sheet
        }
    }

    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = DesignTokens.background

        // Add all subviews
        view.addSubview(dragHandle)
        view.addSubview(nowPlayingLabel)
        view.addSubview(trackIconView)
        trackIconView.addSubview(trackIconImage)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(progressSlider)
        view.addSubview(currentTimeLabel)
        view.addSubview(remainingTimeLabel)

        // Controls row using spacer views for precise spacing
        view.addSubview(controlsStack)
        let leftSpacer1 = makeSpacer(width: 20)
        let leftSpacer2 = makeSpacer(width: 24)
        let rightSpacer1 = makeSpacer(width: 24)
        let rightSpacer2 = makeSpacer(width: 20)

        controlsStack.addArrangedSubview(previousButton)
        controlsStack.addArrangedSubview(leftSpacer1)
        controlsStack.addArrangedSubview(skipBackwardButton)
        controlsStack.addArrangedSubview(leftSpacer2)
        controlsStack.addArrangedSubview(playPauseButton)
        controlsStack.addArrangedSubview(rightSpacer1)
        controlsStack.addArrangedSubview(skipForwardButton)
        controlsStack.addArrangedSubview(rightSpacer2)
        controlsStack.addArrangedSubview(nextButton)

        // Bottom toolbar
        view.addSubview(toolbarStack)
        toolbarStack.addArrangedSubview(rateButton)
        toolbarStack.addArrangedSubview(sleepTimerButton)

        // Apply warm shadow to album art
        DesignTokens.applyWarmShadow(to: trackIconView.layer)

        NSLayoutConstraint.activate([
            // Drag handle: centered, 12pt below safe area top
            dragHandle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.md),
            dragHandle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: DesignTokens.dragHandleWidth),
            dragHandle.heightAnchor.constraint(equalToConstant: DesignTokens.dragHandleHeight),

            // "正在播放" label: centered, 16pt below drag handle
            nowPlayingLabel.topAnchor.constraint(equalTo: dragHandle.bottomAnchor, constant: DesignTokens.Spacing.lg),
            nowPlayingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Album art: centered, square, below nowPlayingLabel
            // 用 view 宽度约束而不是 UIScreen.main，避免 iPad/分屏下尺寸错误
            trackIconView.topAnchor.constraint(equalTo: nowPlayingLabel.bottomAnchor, constant: DesignTokens.Spacing.xl),
            trackIconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trackIconView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -80),
            trackIconView.heightAnchor.constraint(equalTo: trackIconView.widthAnchor),

            // Music note icon inside art
            trackIconImage.centerXAnchor.constraint(equalTo: trackIconView.centerXAnchor),
            trackIconImage.centerYAnchor.constraint(equalTo: trackIconView.centerYAnchor),
            trackIconImage.widthAnchor.constraint(equalToConstant: 80),
            trackIconImage.heightAnchor.constraint(equalToConstant: 80),

            // Title: 24pt below art
            titleLabel.topAnchor.constraint(equalTo: trackIconView.bottomAnchor, constant: DesignTokens.Spacing.xl),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),

            // Subtitle: 4pt below title
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: DesignTokens.Spacing.xs),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),

            // Progress slider: 32pt below subtitle
            progressSlider.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: DesignTokens.Spacing.xxl),
            progressSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xl),
            progressSlider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xl),

            // Time labels
            currentTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: DesignTokens.Spacing.sm),
            currentTimeLabel.leadingAnchor.constraint(equalTo: progressSlider.leadingAnchor),

            remainingTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: DesignTokens.Spacing.sm),
            remainingTimeLabel.trailingAnchor.constraint(equalTo: progressSlider.trailingAnchor),

            // Controls row: 32pt below progress area
            controlsStack.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: DesignTokens.Spacing.xxl),
            controlsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Play/pause button size
            playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            playPauseButton.heightAnchor.constraint(equalToConstant: 80),

            // Bottom toolbar: 40pt below controls
            toolbarStack.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: DesignTokens.Spacing.xxxl),
            toolbarStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DesignTokens.Spacing.xxl),
            toolbarStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DesignTokens.Spacing.xxl),

            // Toolbar button heights
            rateButton.heightAnchor.constraint(equalToConstant: 36),
            sleepTimerButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func makeSpacer(width: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: width).isActive = true
        return spacer
    }

    private func setupSliderActions() {
        progressSlider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    // MARK: - Actions
    @objc private func playPauseTapped() {
        AudioPlayerManager.shared.togglePlayPause()
    }

    @objc private func skipBackwardTapped() {
        AudioPlayerManager.shared.skipBackward(5)
    }

    @objc private func skipForwardTapped() {
        AudioPlayerManager.shared.skipForward(5)
    }

    @objc private func previousTapped() {
        AudioPlayerManager.shared.playPrevious()
    }

    @objc private func nextTapped() {
        AudioPlayerManager.shared.playNext()
    }

    @objc private func rateTapped() {
        showSpeedPicker()
    }

    @objc private func sliderTouchBegan() {
        isSeeking = true
    }

    @objc private func sliderValueChanged() {
        let duration = AudioPlayerManager.shared.duration
        let newTime = TimeInterval(progressSlider.value) * duration
        currentTimeLabel.text = newTime.formattedTime
        remainingTimeLabel.text = "-\((duration - newTime).formattedTime)"
    }

    @objc private func sliderTouchEnded() {
        defer { isSeeking = false }
        let duration = AudioPlayerManager.shared.duration
        // duration 未就绪（NaN/0）时不 seek，否则会算出非法时间
        guard duration > 0, duration.isFinite else { return }
        let newTime = TimeInterval(progressSlider.value) * duration
        AudioPlayerManager.shared.seek(to: newTime)
    }

    // MARK: - Speed Picker Overlay
    private func showSpeedPicker() {
        let overlay = SpeedPickerOverlay()
        overlay.currentSpeed = AudioPlayerManager.shared.playbackRate
        overlay.onSpeedSelected = { [weak self] speed in
            AudioPlayerManager.shared.playbackRate = speed
            self?.updateRateButton()
        }
        overlay.show(in: self.view)
    }

    // MARK: - Sleep Timer
    private func setupSleepTimerObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sleepTimerDidChange),
            name: .sleepTimerDidChange,
            object: nil
        )
    }

    @objc private func sleepTimerTapped() {
        showSleepTimerOverlay()
    }

    @objc private func sleepTimerDidChange() {
        updateSleepTimerButton()
    }

    private func showSleepTimerOverlay() {
        let player = AudioPlayerManager.shared
        let overlay = SleepTimerOverlay()
        overlay.isTimerActive = player.isSleepTimerActive
        overlay.sleepAtEndOfTrack = player.sleepAtEndOfTrack

        // Determine active minutes for highlighting
        if let remaining = player.sleepTimerRemaining, remaining > 0 {
            // Approximate to nearest option
            let totalMinutes = Int(remaining / 60)
            overlay.activeMinutes = totalMinutes
        }

        overlay.onTimerSelected = { minutes in
            player.setSleepTimer(minutes: minutes)
        }
        overlay.onEndOfTrack = {
            player.setSleepAtEndOfTrack()
        }
        overlay.onCancel = {
            player.cancelSleepTimer()
        }
        overlay.onCustomTime = { [weak self] in
            self?.showCustomSleepTimerInput()
        }
        overlay.show(in: self.view)
    }

    private func showCustomSleepTimerInput() {
        let alert = UIAlertController(title: "自定义定时", message: "请输入分钟数", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "分钟"
            textField.keyboardType = .numberPad
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            if let text = alert.textFields?.first?.text,
               let minutes = Int(text), minutes > 0 {
                AudioPlayerManager.shared.setSleepTimer(minutes: minutes)
            }
        })

        present(alert, animated: true)
    }

    private func updateSleepTimerButton() {
        let player = AudioPlayerManager.shared

        let title: String
        let isActive: Bool

        if player.sleepAtEndOfTrack {
            title = "本曲"
            isActive = true
        } else if let remaining = player.sleepTimerRemaining, remaining > 0 {
            let totalSeconds = Int(remaining)
            title = String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
            isActive = true
        } else {
            title = "定时"
            isActive = false
        }

        let stateCategory = isActive ? "active" : "inactive"
        if lastSleepTimerState != stateCategory {
            lastSleepTimerState = stateCategory

            let iconName = isActive ? "moon.fill" : "moon.zzz"
            let color: UIColor = isActive ? DesignTokens.primaryContainer : DesignTokens.onSurface

            sleepTimerButton.setImage(UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14)), for: .normal)
            sleepTimerButton.tintColor = color
            sleepTimerButton.setTitleColor(color, for: .normal)
        }

        UIView.performWithoutAnimation {
            sleepTimerButton.setTitle(title, for: .normal)
            sleepTimerButton.layoutIfNeeded()
        }
    }

    // MARK: - Update UI
    private func updateUI() {
        let player = AudioPlayerManager.shared

        if let track = player.currentTrack {
            titleLabel.text = track.displayName
            subtitleLabel.text = track.folderName
        } else {
            titleLabel.text = "未在播放"
            subtitleLabel.text = ""
        }

        updatePlayPauseButton(isPlaying: player.isPlaying)
        updateRateButton()
        updateSleepTimerButton()
        updateProgress(current: player.currentTime, duration: player.duration)
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        let imageName = isPlaying ? "pause.circle.fill" : "play.circle.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 64)
        playPauseButton.setImage(UIImage(systemName: imageName, withConfiguration: config), for: .normal)
    }

    private func updateRateButton() {
        let rate = AudioPlayerManager.shared.playbackRate
        let title = rate == 1.0 ? "1x" : "\(rate)x"
        rateButton.setTitle(title, for: .normal)
    }

    private func updateProgress(current: TimeInterval, duration: TimeInterval) {
        guard !isSeeking else { return }
        guard duration > 0 && duration.isFinite else {
            progressSlider.value = 0
            currentTimeLabel.text = "00:00"
            remainingTimeLabel.text = "-00:00"
            return
        }

        progressSlider.value = Float(current / duration)
        currentTimeLabel.text = current.formattedTime
        remainingTimeLabel.text = "-\((duration - current).formattedTime)"
    }

    // MARK: - Helper
    private static func makeThumbImage(size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            DesignTokens.surfaceContainer.setFill()
            context.cgContext.fillEllipse(in: rect)
            DesignTokens.primary.setStroke()
            context.cgContext.setLineWidth(1.5)
            context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.75, dy: 0.75))
        }
    }
}

// MARK: - AudioPlayerDelegate
extension PlayerViewController: AudioPlayerDelegate {
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
        // Track finished
    }
}
