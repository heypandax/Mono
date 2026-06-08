//
//  SleepTimerOverlay.swift
//  Mono
//
//  Sleep timer overlay for setting auto-stop timers.
//

import UIKit

final class SleepTimerOverlay: UIView {

    // MARK: - Callbacks
    var onTimerSelected: ((Int) -> Void)?
    var onEndOfTrack: (() -> Void)?
    var onCancel: (() -> Void)?
    var onCustomTime: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - State
    var isTimerActive: Bool = false {
        didSet { updateLayout() }
    }
    var sleepAtEndOfTrack: Bool = false {
        didSet { updateLayout() }
    }

    /// Currently active timer minutes (to highlight the matching button)
    var activeMinutes: Int = 0

    // MARK: - Constants
    private let timerOptions: [(String, Int)] = [
        ("15 分钟", 15),
        ("30 分钟", 30),
        ("45 分钟", 45),
        ("60 分钟", 60),
        ("90 分钟", 90)
    ]

    // MARK: - UI
    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = DesignTokens.onSurface.withAlphaComponent(0.3)
        return view
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = DesignTokens.surfaceContainer
        view.layer.cornerRadius = DesignTokens.CornerRadius.sheet
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        return view
    }()

    private let dragHandle: UIView = {
        let view = UIView()
        view.backgroundColor = DesignTokens.dragHandleColor
        view.layer.cornerRadius = DesignTokens.dragHandleHeight / 2
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "睡眠定时"
        label.font = DesignTokens.headlineSmall
        label.textColor = DesignTokens.onSurface
        label.textAlignment = .center
        return label
    }()

    private var timerButtons: [UIButton] = []

    private let customTimeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("自定义时间", for: .normal)
        button.titleLabel?.font = DesignTokens.bodyLarge
        button.setTitleColor(DesignTokens.onSurface, for: .normal)
        button.backgroundColor = .clear
        button.layer.cornerRadius = DesignTokens.CornerRadius.medium
        button.layer.borderWidth = 1
        button.layer.borderColor = DesignTokens.outlineVariant.cgColor
        return button
    }()

    private let dividerView: UIView = {
        let view = UIView()
        view.backgroundColor = DesignTokens.surfaceVariant
        return view
    }()

    // "播完本曲" row
    private let endOfTrackRow: UIView = {
        let view = UIView()
        return view
    }()

    private let endOfTrackIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "bed.double.fill")
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let endOfTrackLabel: UILabel = {
        let label = UILabel()
        label.text = "播完本曲"
        label.font = DesignTokens.bodyLarge
        return label
    }()

    private let endOfTrackIndicator: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 2
        return view
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("取消定时器", for: .normal)
        button.titleLabel?.font = DesignTokens.bodyLarge
        button.setTitleColor(DesignTokens.error, for: .normal)
        button.backgroundColor = .clear
        return button
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupViews() {
        addSubview(dimmingView)
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(dimmingTapped))
        dimmingView.addGestureRecognizer(dimTap)

        addSubview(cardView)
        cardView.addSubview(dragHandle)
        cardView.addSubview(titleLabel)

        // Timer option buttons
        for (title, minutes) in timerOptions {
            let button = UIButton(type: .system)
            button.tag = minutes
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = DesignTokens.bodyLarge
            button.layer.cornerRadius = DesignTokens.CornerRadius.medium
            button.addTarget(self, action: #selector(timerOptionTapped(_:)), for: .touchUpInside)
            cardView.addSubview(button)
            timerButtons.append(button)
        }

        // Custom time
        customTimeButton.addTarget(self, action: #selector(customTimeTapped), for: .touchUpInside)
        cardView.addSubview(customTimeButton)

        // Divider
        cardView.addSubview(dividerView)

        // End of track row
        cardView.addSubview(endOfTrackRow)
        endOfTrackRow.addSubview(endOfTrackIcon)
        endOfTrackRow.addSubview(endOfTrackLabel)
        endOfTrackRow.addSubview(endOfTrackIndicator)
        let rowTap = UITapGestureRecognizer(target: self, action: #selector(endOfTrackTapped))
        endOfTrackRow.addGestureRecognizer(rowTap)

        // Cancel
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cardView.addSubview(cancelButton)

        updateLayout()
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        dimmingView.frame = bounds

        let safeBottom = safeAreaInsets.bottom
        let hPadding: CGFloat = DesignTokens.Spacing.xl
        let buttonHeight: CGFloat = 48
        let buttonSpacing: CGFloat = DesignTokens.Spacing.sm
        let handleTopMargin: CGFloat = DesignTokens.Spacing.md
        let titleTopMargin: CGFloat = DesignTokens.Spacing.xl
        let contentTopMargin: CGFloat = DesignTokens.Spacing.xl
        let dividerVMargin: CGFloat = DesignTokens.Spacing.lg

        let handleH: CGFloat = DesignTokens.dragHandleHeight
        let titleH: CGFloat = 24
        let contentWidth = bounds.width - hPadding * 2

        // Calculate card height
        var totalHeight: CGFloat = handleTopMargin + handleH
            + titleTopMargin + titleH
            + contentTopMargin
        // Timer buttons
        totalHeight += CGFloat(timerButtons.count) * buttonHeight
            + CGFloat(timerButtons.count - 1) * buttonSpacing
        // Custom button
        totalHeight += buttonSpacing + buttonHeight
        // Divider
        totalHeight += dividerVMargin + 1 + dividerVMargin
        // End of track row
        totalHeight += buttonHeight
        // Cancel button (conditional)
        if isTimerActive {
            totalHeight += DesignTokens.Spacing.lg + buttonHeight
        }
        // Bottom padding
        totalHeight += DesignTokens.Spacing.xl + safeBottom

        let cardFrame = CGRect(
            x: 0,
            y: bounds.height - totalHeight,
            width: bounds.width,
            height: totalHeight
        )
        cardView.frame = cardFrame

        // Drag handle
        dragHandle.frame = CGRect(
            x: (cardFrame.width - DesignTokens.dragHandleWidth) / 2,
            y: handleTopMargin,
            width: DesignTokens.dragHandleWidth,
            height: handleH
        )

        // Title
        let titleY = dragHandle.frame.maxY + titleTopMargin
        titleLabel.frame = CGRect(x: hPadding, y: titleY, width: contentWidth, height: titleH)

        // Timer buttons
        var currentY = titleLabel.frame.maxY + contentTopMargin
        for button in timerButtons {
            button.frame = CGRect(x: hPadding, y: currentY, width: contentWidth, height: buttonHeight)
            currentY += buttonHeight + buttonSpacing
        }
        // Adjust for last spacing
        currentY -= buttonSpacing
        currentY += buttonSpacing

        // Custom time button
        customTimeButton.frame = CGRect(x: hPadding, y: currentY, width: contentWidth, height: buttonHeight)
        currentY = customTimeButton.frame.maxY

        // Divider
        currentY += dividerVMargin
        dividerView.frame = CGRect(x: hPadding, y: currentY, width: contentWidth, height: 1)
        currentY = dividerView.frame.maxY + dividerVMargin

        // End of track row
        endOfTrackRow.frame = CGRect(x: hPadding, y: currentY, width: contentWidth, height: buttonHeight)

        let iconSize: CGFloat = 22
        endOfTrackIcon.frame = CGRect(
            x: DesignTokens.Spacing.md,
            y: (buttonHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        endOfTrackLabel.frame = CGRect(
            x: endOfTrackIcon.frame.maxX + DesignTokens.Spacing.sm,
            y: 0,
            width: contentWidth - iconSize - 60,
            height: buttonHeight
        )
        let indicatorSize: CGFloat = 24
        endOfTrackIndicator.frame = CGRect(
            x: contentWidth - indicatorSize - DesignTokens.Spacing.md,
            y: (buttonHeight - indicatorSize) / 2,
            width: indicatorSize,
            height: indicatorSize
        )

        currentY = endOfTrackRow.frame.maxY

        // Cancel button
        if isTimerActive {
            cancelButton.isHidden = false
            currentY += DesignTokens.Spacing.lg
            cancelButton.frame = CGRect(x: hPadding, y: currentY, width: contentWidth, height: buttonHeight)
        } else {
            cancelButton.isHidden = true
        }
    }

    // MARK: - Update
    private func updateLayout() {
        // Timer buttons styling
        for button in timerButtons {
            let minutes = button.tag
            if isTimerActive && minutes == activeMinutes && !sleepAtEndOfTrack {
                button.backgroundColor = DesignTokens.primaryContainer
                button.setTitleColor(DesignTokens.onPrimary, for: .normal)
            } else {
                button.backgroundColor = DesignTokens.surfaceVariant
                button.setTitleColor(DesignTokens.onSurface, for: .normal)
            }
        }

        // End of track indicator
        if sleepAtEndOfTrack {
            endOfTrackIcon.tintColor = DesignTokens.primaryContainer
            endOfTrackLabel.textColor = DesignTokens.primaryContainer
            endOfTrackIndicator.backgroundColor = DesignTokens.primaryContainer
            endOfTrackIndicator.layer.borderColor = DesignTokens.primaryContainer.cgColor
        } else {
            endOfTrackIcon.tintColor = DesignTokens.onSurface
            endOfTrackLabel.textColor = DesignTokens.onSurface
            endOfTrackIndicator.backgroundColor = .clear
            endOfTrackIndicator.layer.borderColor = DesignTokens.outline.cgColor
        }

        setNeedsLayout()
    }

    // MARK: - Actions
    @objc private func timerOptionTapped(_ sender: UIButton) {
        let minutes = sender.tag
        onTimerSelected?(minutes)
        dismiss()
    }

    @objc private func customTimeTapped() {
        onCustomTime?()
        dismiss()
    }

    @objc private func endOfTrackTapped() {
        onEndOfTrack?()
        dismiss()
    }

    @objc private func cancelTapped() {
        onCancel?()
        dismiss()
    }

    @objc private func dimmingTapped() {
        dismiss()
    }

    // MARK: - Show / Dismiss
    func show(in parentView: UIView) {
        frame = parentView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parentView.addSubview(self)

        dimmingView.alpha = 0
        let safeBottom = parentView.safeAreaInsets.bottom
        cardView.transform = CGAffineTransform(translationX: 0, y: cardView.frame.height + safeBottom)

        layoutIfNeeded()

        cardView.transform = CGAffineTransform(translationX: 0, y: cardView.frame.height + safeBottom)

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            self.dimmingView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    func dismiss() {
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: .curveEaseIn
        ) {
            self.dimmingView.alpha = 0
            self.cardView.transform = CGAffineTransform(translationX: 0, y: self.cardView.frame.height)
        } completion: { _ in
            self.onDismiss?()
            self.removeFromSuperview()
        }
    }
}
