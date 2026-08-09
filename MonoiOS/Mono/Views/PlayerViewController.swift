//
//  PlayerViewController.swift
//  Mono
//
//  全屏播放器（Master 的 MPlayer）。没有假封面：视觉焦点由排版、进度与控制关系承担。
//  只保留真实存在行为的控件；首章/末章用 isEnabled 真正禁用。
//

import UIKit

/// VoiceOver 上下轻扫按 5 秒调整，而不是默认的 10% 步进
final class PlaybackSlider: UISlider {

    var onAccessibilityAdjust: ((TimeInterval) -> Void)?

    override func accessibilityIncrement() {
        onAccessibilityAdjust?(5)
    }

    override func accessibilityDecrement() {
        onAccessibilityAdjust?(-5)
    }

    /// 视觉轨道保持纤细，但把垂直触控范围扩到至少 44pt。
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let extra = max(0, (DesignTokens.hitTarget - bounds.height) / 2)
        return bounds.insetBy(dx: 0, dy: -extra).contains(point)
    }
}

/// 底部「倍速 / 睡眠」条目：标签 + 当前值，值本身也是文字，不只靠颜色
final class PlayerToolControl: UIControl {

    private let captionLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 1)
    private let valueLabel = MonoUI.label(.headline, color: DesignTokens.onSurface, lines: 1, numeric: true)
    private let stack = UIStackView()

    /// 普通字号：居中的单行两列
    private var compactConstraints: [NSLayoutConstraint] = []
    /// 辅助字号：占满整行、可换行，「播完本章」与倒计时不会被压缩
    private var accessibilityConstraints: [NSLayoutConstraint] = []

    init(caption: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        captionLabel.text = caption

        stack.translatesAutoresizingMaskIntoConstraints = false
        [captionLabel, valueLabel].forEach(stack.addArrangedSubview)
        stack.isUserInteractionEnabled = false
        addSubview(stack)

        compactConstraints = [
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: DesignTokens.Spacing.sm),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -DesignTokens.Spacing.sm)
        ]
        // 定宽而不是「不超过」，标签才能确定地换行而不是被截断
        accessibilityConstraints = [
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.contentInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.contentInset)
        ]

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget + 8)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = caption

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (control: PlayerToolControl, _) in
            control.updateAdaptiveLayout()
        }
        updateAdaptiveLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateAdaptiveLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        NSLayoutConstraint.deactivate(isAccessibilitySize ? compactConstraints : accessibilityConstraints)
        NSLayoutConstraint.activate(isAccessibilitySize ? accessibilityConstraints : compactConstraints)

        stack.axis = isAccessibilitySize ? .vertical : .horizontal
        stack.alignment = isAccessibilitySize ? .leading : .firstBaseline
        stack.spacing = isAccessibilitySize ? 2 : DesignTokens.Spacing.sm
        captionLabel.numberOfLines = isAccessibilitySize ? 0 : 1
        valueLabel.numberOfLines = isAccessibilitySize ? 0 : 1
    }

    func apply(value: String, accessibilityValue: String) {
        valueLabel.text = value
        self.accessibilityValue = accessibilityValue
    }
}

final class PlayerViewController: UIViewController {

    /// iPhone 上真正全屏；Reduce Motion 时改为交叉淡入
    static func present(from presenter: UIViewController) {
        let playerVC = PlayerViewController()
        playerVC.modalPresentationStyle = .fullScreen
        if DesignTokens.prefersReducedMotion {
            playerVC.modalTransitionStyle = .crossDissolve
        }
        presenter.present(playerVC, animated: true)
    }

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        return scroll
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        return stack
    }()

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.down")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        config.baseForegroundColor = DesignTokens.onSurfaceVariant
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "关闭"
        button.accessibilityIdentifier = "player.close"
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return button
    }()

    private let stateLabel = MonoUI.label(.caption2, weight: .semibold, color: DesignTokens.onSurfaceVariant, lines: 1)
    private let chapterIndexLabel = MonoUI.label(.footnote, weight: .semibold, color: DesignTokens.primary, lines: 1, numeric: true)
    private let titleLabel = MonoUI.label(.title1, weight: .bold, color: DesignTokens.onSurface, lines: 0)
    private let bookLabel = MonoUI.label(.callout, color: DesignTokens.onSurfaceVariant, lines: 2)

    private let progressSlider: PlaybackSlider = {
        let slider = PlaybackSlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = DesignTokens.primary
        slider.maximumTrackTintColor = DesignTokens.surfaceContainerHigh
        slider.accessibilityLabel = "播放进度"
        slider.accessibilityIdentifier = "player.progress"
        return slider
    }()

    private let elapsedLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 1, numeric: true)
    private let remainingLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 1, numeric: true)

    private lazy var previousButton = makeTransportButton(
        symbol: "backward.end.fill", pointSize: 22, label: "上一章",
        identifier: "player.previous", action: #selector(previousTapped)
    )
    private lazy var skipBackwardButton = makeTransportButton(
        symbol: "gobackward.5", pointSize: 27, label: "后退 5 秒",
        identifier: "player.back5", action: #selector(skipBackwardTapped)
    )
    private lazy var skipForwardButton = makeTransportButton(
        symbol: "goforward.5", pointSize: 27, label: "前进 5 秒",
        identifier: "player.forward5", action: #selector(skipForwardTapped)
    )
    private lazy var nextButton = makeTransportButton(
        symbol: "forward.end.fill", pointSize: 22, label: "下一章",
        identifier: "player.next", action: #selector(nextTapped)
    )

    private lazy var playPauseButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = DesignTokens.primary
        config.baseForegroundColor = DesignTokens.onPrimary
        config.image = UIImage(systemName: "play.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "播放"
        button.accessibilityIdentifier = "player.playPause"
        button.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 72),
            button.heightAnchor.constraint(equalToConstant: 72)
        ])
        return button
    }()

    private lazy var rateControl: PlayerToolControl = {
        let control = PlayerToolControl(caption: "倍速")
        control.accessibilityLabel = "播放速度"
        control.accessibilityIdentifier = "player.speed"
        control.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)
        return control
    }()

    private lazy var sleepControl: PlayerToolControl = {
        let control = PlayerToolControl(caption: "睡眠")
        control.accessibilityLabel = "睡眠定时"
        control.accessibilityIdentifier = "player.sleep"
        control.addTarget(self, action: #selector(sleepTimerTapped), for: .touchUpInside)
        return control
    }()

    /// 工具区分隔线的容器：普通字号里是竖线（上下留白），辅助字号里是整行横线
    private let toolDivider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let toolDividerLine: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.outlineVariant
        view.isAccessibilityElement = false
        return view
    }()

    private let toolsRow: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.alignment = .fill
        return stack
    }()

    private let flexibleSpacer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.init(1), for: .vertical)
        view.setContentCompressionResistancePriority(.init(1), for: .vertical)
        view.heightAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        return view
    }()

    // MARK: - State

    private var isSeeking = false
    /// 工具区两种轴向的约束，切换时必须显式停用另一套，避免 stack 轴变化后冲突
    private var toolsHorizontalConstraints: [NSLayoutConstraint] = []
    private var toolsVerticalConstraints: [NSLayoutConstraint] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSliderActions()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sleepTimerDidChange),
            name: .sleepTimerDidChange,
            object: nil
        )
        AudioPlayerManager.shared.addDelegate(self)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (vc: PlayerViewController, _) in
            vc.updateSliderThumb()
        }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (vc: PlayerViewController, _) in
            vc.updateToolsLayout()
        }
        updateSliderThumb()
        updateUI()
    }

    /// 嵌套 stack 里的多行标签，首次测量时 bounds 宽度还是 0，intrinsic 高度会按「单行不限宽」算出来，
    /// 辅助字号下就表现为标题只画出前几行、后半段被裁掉。拿到真实宽度后回写 preferredMaxLayoutWidth 再重新测量。
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        var needsRelayout = false
        for label in [titleLabel, bookLabel] {
            let width = label.bounds.width
            // 差值门限让第二趟收敛，否则每次布局都会再触发一次布局
            guard width > 0, abs(label.preferredMaxLayoutWidth - width) > 0.5 else { continue }
            label.preferredMaxLayoutWidth = width
            label.invalidateIntrinsicContentSize()
            needsRelayout = true
        }
        if needsRelayout {
            view.setNeedsLayout()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = DesignTokens.background
        view.accessibilityIdentifier = "player.root"

        let closeRow = UIView()
        closeRow.translatesAutoresizingMaskIntoConstraints = false
        closeRow.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: closeRow.leadingAnchor, constant: -10),
            closeButton.topAnchor.constraint(equalTo: closeRow.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: closeRow.bottomAnchor),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget)
        ])

        let identityStack = UIStackView(arrangedSubviews: [stateLabel, chapterIndexLabel, titleLabel, bookLabel])
        identityStack.translatesAutoresizingMaskIntoConstraints = false
        identityStack.axis = .vertical
        identityStack.alignment = .fill
        identityStack.spacing = 10
        identityStack.setCustomSpacing(12, after: titleLabel)
        chapterIndexLabel.isAccessibilityElement = false
        titleLabel.accessibilityTraits.insert(.header)
        // 章节名来自文件名，可能是没有空格的长串；按字符断行才保证 CJK 与无空格文件名都能折行而不是横向截断
        titleLabel.lineBreakMode = .byCharWrapping
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        // 身份区整体不参与压缩：辅助字号下多出来的高度由 flexibleSpacer（优先级 1）先让位，
        // 标题宁可把内容顶出一屏交给滚动，也不能被挤掉后半段
        identityStack.setContentCompressionResistancePriority(.required, for: .vertical)

        let timesRow = UIStackView(arrangedSubviews: [elapsedLabel, remainingLabel])
        timesRow.translatesAutoresizingMaskIntoConstraints = false
        timesRow.axis = .horizontal
        timesRow.distribution = .equalSpacing
        remainingLabel.textAlignment = .right
        // 完整的时间语义已由进度条的 accessibilityValue 承担（已播…共…剩余…）。
        // 这两个裸时钟标签只服务于视觉，留在无障碍树里就是重复的 0:23 / 0:00 停顿
        elapsedLabel.isAccessibilityElement = false
        remainingLabel.isAccessibilityElement = false

        // 滑杆视觉 4pt，命中区 44pt
        let sliderContainer = UIView()
        sliderContainer.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(progressSlider)
        NSLayoutConstraint.activate([
            progressSlider.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor),
            progressSlider.trailingAnchor.constraint(equalTo: sliderContainer.trailingAnchor),
            progressSlider.centerYAnchor.constraint(equalTo: sliderContainer.centerYAnchor),
            sliderContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget)
        ])

        let transportRow = UIStackView(arrangedSubviews: [
            previousButton, skipBackwardButton, playPauseButton, skipForwardButton, nextButton
        ])
        transportRow.translatesAutoresizingMaskIntoConstraints = false
        transportRow.axis = .horizontal
        transportRow.alignment = .center
        transportRow.distribution = .equalSpacing

        toolDivider.addSubview(toolDividerLine)
        [rateControl, toolDivider, sleepControl].forEach(toolsRow.addArrangedSubview)

        // 竖线上下各留 12pt，不与下方横分割线连成 T 形
        toolsHorizontalConstraints = [
            toolDivider.widthAnchor.constraint(equalToConstant: DesignTokens.hairline),
            toolDividerLine.centerXAnchor.constraint(equalTo: toolDivider.centerXAnchor),
            toolDividerLine.widthAnchor.constraint(equalToConstant: DesignTokens.hairline),
            toolDividerLine.topAnchor.constraint(equalTo: toolDivider.topAnchor, constant: DesignTokens.Spacing.md),
            toolDividerLine.bottomAnchor.constraint(equalTo: toolDivider.bottomAnchor, constant: -DesignTokens.Spacing.md),
            rateControl.widthAnchor.constraint(equalTo: sleepControl.widthAnchor)
        ]
        // 辅助字号下改为纵向整行工具项，中间是整行 hairline
        toolsVerticalConstraints = [
            toolDividerLine.leadingAnchor.constraint(equalTo: toolDivider.leadingAnchor),
            toolDividerLine.trailingAnchor.constraint(equalTo: toolDivider.trailingAnchor),
            toolDividerLine.topAnchor.constraint(equalTo: toolDivider.topAnchor),
            toolDividerLine.bottomAnchor.constraint(equalTo: toolDivider.bottomAnchor),
            toolDividerLine.heightAnchor.constraint(equalToConstant: DesignTokens.hairline)
        ]

        let toolsSeparator = MonoSeparatorView()

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        [closeRow, identityStack, flexibleSpacer, sliderContainer, timesRow,
         transportRow, toolsSeparator, toolsRow].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(20, after: closeRow)
        contentStack.setCustomSpacing(2, after: sliderContainer)
        contentStack.setCustomSpacing(22, after: timesRow)
        contentStack.setCustomSpacing(24, after: transportRow)

        let horizontalInset: CGFloat = 22
        // 关闭按钮在安全区内再留一点呼吸，命中框不会贴着状态栏
        let topBreathing = DesignTokens.Spacing.sm
        NSLayoutConstraint.activate([
            // 背景由 view.backgroundColor 全屏铺满；可交互内容一律在安全区内
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // 只纵向滚动：内容宽度锁死为可视宽度
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: topBreathing),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.sm),
            contentStack.centerXAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerXAnchor),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: DesignTokens.playerMaxWidth),
            // 至少铺满一屏（让 flexibleSpacer 把工具区顶到底部），超出时照常滚动
            contentStack.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor,
                                                 constant: -(topBreathing + DesignTokens.Spacing.sm))
        ])
        let fullWidth = contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor,
                                                           constant: -horizontalInset * 2)
        fullWidth.priority = .defaultHigh
        fullWidth.isActive = true

        updateToolsLayout()
    }

    /// 普通字号双列 + 竖分隔线；辅助字号纵向整行 + 横分隔线。Trait 运行时切换后立即生效
    private func updateToolsLayout() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        NSLayoutConstraint.deactivate(isAccessibilitySize ? toolsHorizontalConstraints : toolsVerticalConstraints)
        NSLayoutConstraint.activate(isAccessibilitySize ? toolsVerticalConstraints : toolsHorizontalConstraints)
        toolsRow.axis = isAccessibilitySize ? .vertical : .horizontal
    }

    private func makeTransportButton(symbol: String,
                                     pointSize: CGFloat,
                                     label: String,
                                     identifier: String,
                                     action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = label
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
        // 禁用态不是只变淡：isEnabled = false 同时带来 not enabled 语义
        button.configurationUpdateHandler = { button in
            button.configuration?.baseForegroundColor = button.isEnabled
                ? DesignTokens.onSurface
                : DesignTokens.disabled
        }
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget)
        ])
        return button
    }

    private func setupSliderActions() {
        progressSlider.addTarget(self, action: #selector(sliderTouchBegan), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        progressSlider.onAccessibilityAdjust = { [weak self] delta in
            guard let self else { return }
            let player = AudioPlayerManager.shared
            guard PlaybackPresenter.resolvedDuration(player.duration) != nil else { return }
            delta > 0 ? player.skipForward(delta) : player.skipBackward(-delta)
            self.updateProgress(current: player.currentTime, duration: player.duration)
        }
    }

    /// 滑块颜色是 CGColor 绘制的，必须随外观重新生成
    private func updateSliderThumb() {
        let size: CGFloat = 14
        let color = DesignTokens.primary.resolvedColor(with: traitCollection)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            color.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        progressSlider.setThumbImage(image, for: .normal)
        progressSlider.setThumbImage(image, for: .highlighted)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

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
        let player = AudioPlayerManager.shared
        guard player.currentIndex > 0 else { return }
        player.play(at: player.currentIndex - 1)
    }

    @objc private func nextTapped() {
        AudioPlayerManager.shared.playNext()
    }

    @objc private func rateTapped() {
        let overlay = SpeedPickerOverlay()
        overlay.currentSpeed = AudioPlayerManager.shared.playbackRate
        overlay.onSpeedSelected = { [weak self] speed in
            AudioPlayerManager.shared.playbackRate = speed
            self?.updateRateControl()
        }
        overlay.show(in: view, returningFocusTo: rateControl)
    }

    @objc private func sleepTimerTapped() {
        let player = AudioPlayerManager.shared
        let overlay = SleepTimerOverlay()
        overlay.isTimerActive = player.isSleepTimerActive
        overlay.sleepAtEndOfTrack = player.sleepAtEndOfTrack
        if let remaining = player.sleepTimerRemaining, remaining > 0 {
            // 向上取整，刚设完 30 分钟时高亮的仍然是 30 分钟这一档
            overlay.activeMinutes = Int((remaining / 60).rounded(.up))
        }
        overlay.onTimerSelected = { player.setSleepTimer(minutes: $0) }
        overlay.onEndOfTrack = { player.setSleepAtEndOfTrack() }
        overlay.onCancel = { player.cancelSleepTimer() }
        overlay.onCustomTime = { [weak self] in self?.showCustomSleepTimerInput() }
        overlay.show(in: view, returningFocusTo: sleepControl)
    }

    private func showCustomSleepTimerInput() {
        // 范围与服务层同一个上限，输入越界时不静默落空，先在提示语里说清楚
        let maxMinutes = AudioPlayerManager.maxSleepTimerMinutes
        let alert = UIAlertController(
            title: "自定义定时",
            message: "请输入 1 到 \(maxMinutes) 之间的分钟数（最长 24 小时）",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "分钟"
            textField.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            guard let text = alert.textFields?.first?.text,
                  let minutes = Int(text),
                  (1...maxMinutes).contains(minutes) else { return }
            AudioPlayerManager.shared.setSleepTimer(minutes: minutes)
        })
        present(alert, animated: true)
    }

    @objc private func sliderTouchBegan() {
        isSeeking = true
    }

    @objc private func sliderValueChanged() {
        guard let duration = PlaybackPresenter.resolvedDuration(AudioPlayerManager.shared.duration) else { return }
        let newTime = TimeInterval(progressSlider.value) * duration
        elapsedLabel.text = MonoFormat.elapsedText(newTime)
        remainingLabel.text = MonoFormat.remainingCountdownText(duration - newTime)
    }

    @objc private func sliderTouchEnded() {
        defer { isSeeking = false }
        // duration 未就绪时不 seek，否则会算出非法时间
        guard let duration = PlaybackPresenter.resolvedDuration(AudioPlayerManager.shared.duration) else { return }
        AudioPlayerManager.shared.seek(to: TimeInterval(progressSlider.value) * duration)
    }

    @objc private func sleepTimerDidChange() {
        updateSleepControl()
    }

    // MARK: - Update

    private func updateUI() {
        let player = AudioPlayerManager.shared

        if let presentation = PlaybackPresenter.nowPlaying(player: player), presentation.hasLoadedTrack {
            stateLabel.text = presentation.stateText
            chapterIndexLabel.text = presentation.chapterIndexText
            chapterIndexLabel.isHidden = false
            titleLabel.text = presentation.chapterTitle
            bookLabel.text = presentation.bookName
        } else {
            stateLabel.text = "未在播放"
            chapterIndexLabel.isHidden = true
            titleLabel.text = "没有正在收听的章节"
            bookLabel.text = nil
        }

        updateTransportAvailability()
        updatePlayPauseButton(isPlaying: player.isPlaying, announce: false)
        updateRateControl()
        updateSleepControl()
        updateProgress(current: player.currentTime, duration: player.duration)
        updateIdentityAccessibility()
    }

    /// 首章禁用上一章、末章禁用下一章：真正 isEnabled = false，不是只把颜色调淡
    private func updateTransportAvailability() {
        let player = AudioPlayerManager.shared
        let hasPlaylist = !player.currentPlaylist.isEmpty
        previousButton.isEnabled = hasPlaylist && player.currentIndex > 0
        nextButton.isEnabled = hasPlaylist && player.currentIndex < player.currentPlaylist.count - 1
    }

    private func updatePlayPauseButton(isPlaying: Bool, announce: Bool) {
        playPauseButton.configuration?.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
        playPauseButton.accessibilityLabel = isPlaying ? "暂停" : "播放"
        // 没有加载章节时不要把「未在播放」覆盖成「已暂停」
        if AudioPlayerManager.shared.currentTrack != nil {
            stateLabel.text = isPlaying ? "正在播放" : "已暂停"
        }
        updateIdentityAccessibility()
        if announce {
            UIAccessibility.post(notification: .announcement, argument: isPlaying ? "正在播放" : "已暂停")
        }
    }

    private func updateRateControl() {
        let rate = AudioPlayerManager.shared.playbackRate
        rateControl.apply(value: MonoFormat.rateText(rate), accessibilityValue: MonoFormat.spokenRateText(rate))
    }

    private func updateIdentityAccessibility() {
        let parts = [stateLabel.text, chapterIndexLabel.isHidden ? nil : chapterIndexLabel.text]
        stateLabel.accessibilityLabel = parts.compactMap { $0 }.joined(separator: "，")
    }

    private func updateSleepControl() {
        let player = AudioPlayerManager.shared
        if player.sleepAtEndOfTrack {
            sleepControl.apply(value: "播完本章", accessibilityValue: "播完本章后暂停")
        } else if let remaining = player.sleepTimerRemaining, remaining > 0 {
            let text = MonoFormat.countdownText(remaining)
            sleepControl.apply(value: text, accessibilityValue: "还剩 \(MonoFormat.spokenTime(remaining))")
        } else {
            sleepControl.apply(value: "关闭", accessibilityValue: "关闭")
        }
    }

    private func updateProgress(current: TimeInterval, duration: TimeInterval) {
        guard !isSeeking else { return }

        guard let resolved = PlaybackPresenter.resolvedDuration(duration) else {
            progressSlider.value = 0
            progressSlider.isEnabled = false
            elapsedLabel.text = MonoFormat.elapsedText(PlaybackPresenter.sanitize(current))
            remainingLabel.text = MonoFormat.unresolvedDuration
            progressSlider.accessibilityValue = MonoFormat.unresolvedDurationAccessibility
            return
        }

        let elapsed = min(PlaybackPresenter.sanitize(current), resolved)
        progressSlider.isEnabled = true
        progressSlider.value = Float(elapsed / resolved)
        elapsedLabel.text = MonoFormat.elapsedText(elapsed)
        remainingLabel.text = MonoFormat.remainingCountdownText(resolved - elapsed)
        progressSlider.accessibilityValue = [
            MonoFormat.spokenElapsed(elapsed),
            "共 \(MonoFormat.spokenTime(resolved))",
            "剩余 \(MonoFormat.spokenTime(resolved - elapsed))"
        ].joined(separator: "，")
    }
}

// MARK: - AudioPlayerDelegate

extension PlayerViewController: AudioPlayerDelegate {

    func playerDidUpdateTime(_ currentTime: TimeInterval, duration: TimeInterval) {
        updateProgress(current: currentTime, duration: duration)
        updateSleepControl()
    }

    func playerDidChangePlayingState(_ isPlaying: Bool) {
        updatePlayPauseButton(isPlaying: isPlaying, announce: true)
    }

    func playerDidChangeTrack(_ track: AudioTrack?) {
        updateUI()
    }

    func playerDidFinishTrack() {}
}
