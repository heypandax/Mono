//
//  SpeedPickerOverlay.swift
//  Mono
//
//  Speed picker overlay for playback rate selection.
//

import UIKit

final class SpeedPickerOverlay: UIView {

    // MARK: - Callbacks
    var onSpeedSelected: ((Float) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - State
    var currentSpeed: Float = 1.0 {
        didSet { updateButtons() }
    }

    // MARK: - Constants
    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

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
        label.text = "播放速度"
        label.font = DesignTokens.headlineSmall
        label.textColor = DesignTokens.onSurface
        label.textAlignment = .center
        return label
    }()

    private var speedButtons: [UIButton] = []

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
        // Dimming background
        addSubview(dimmingView)
        let dimTap = UITapGestureRecognizer(target: self, action: #selector(dimmingTapped))
        dimmingView.addGestureRecognizer(dimTap)

        // Card
        addSubview(cardView)
        cardView.addSubview(dragHandle)
        cardView.addSubview(titleLabel)

        // Speed buttons
        for speed in speeds {
            let button = UIButton(type: .system)
            button.tag = Int(speed * 100) // encode speed as tag
            let title = speed.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(speed)).0x"
                : "\(speed)x"
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = DesignTokens.bodyLarge
            button.layer.cornerRadius = DesignTokens.CornerRadius.medium
            button.addTarget(self, action: #selector(speedButtonTapped(_:)), for: .touchUpInside)
            cardView.addSubview(button)
            speedButtons.append(button)
        }

        updateButtons()
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        dimmingView.frame = bounds

        let safeBottom = safeAreaInsets.bottom
        let buttonWidth: CGFloat = 96
        let buttonHeight: CGFloat = 44
        let gridSpacing: CGFloat = DesignTokens.Spacing.sm
        let horizontalPadding: CGFloat = DesignTokens.Spacing.xl
        let handleTopMargin: CGFloat = DesignTokens.Spacing.md
        let titleTopMargin: CGFloat = DesignTokens.Spacing.xl

        let gridWidth = buttonWidth * 3 + gridSpacing * 2
        let rows = 3
        let gridHeight = buttonHeight * CGFloat(rows) + gridSpacing * CGFloat(rows - 1)

        let handleHeight: CGFloat = DesignTokens.dragHandleHeight
        let titleHeight: CGFloat = 24
        let gridTopMargin: CGFloat = DesignTokens.Spacing.xl

        let cardHeight = handleTopMargin + handleHeight
            + titleTopMargin + titleHeight
            + gridTopMargin + gridHeight
            + DesignTokens.Spacing.xl + safeBottom

        let cardFrame = CGRect(
            x: 0,
            y: bounds.height - cardHeight,
            width: bounds.width,
            height: cardHeight
        )
        cardView.frame = cardFrame

        // Drag handle
        dragHandle.frame = CGRect(
            x: (cardFrame.width - DesignTokens.dragHandleWidth) / 2,
            y: handleTopMargin,
            width: DesignTokens.dragHandleWidth,
            height: handleHeight
        )

        // Title
        let titleY = dragHandle.frame.maxY + titleTopMargin
        titleLabel.frame = CGRect(
            x: horizontalPadding,
            y: titleY,
            width: cardFrame.width - horizontalPadding * 2,
            height: titleHeight
        )

        // Grid
        let gridOriginX = (cardFrame.width - gridWidth) / 2
        let gridOriginY = titleLabel.frame.maxY + gridTopMargin

        for (index, button) in speedButtons.enumerated() {
            let col = index % 3
            let row = index / 3
            let x = gridOriginX + CGFloat(col) * (buttonWidth + gridSpacing)
            let y = gridOriginY + CGFloat(row) * (buttonHeight + gridSpacing)
            button.frame = CGRect(x: x, y: y, width: buttonWidth, height: buttonHeight)
        }
    }

    // MARK: - Update
    private func updateButtons() {
        for button in speedButtons {
            let speed = Float(button.tag) / 100.0
            if abs(speed - currentSpeed) < 0.01 {
                button.backgroundColor = DesignTokens.primaryContainer
                button.setTitleColor(DesignTokens.onPrimary, for: .normal)
            } else {
                button.backgroundColor = DesignTokens.surfaceVariant
                button.setTitleColor(DesignTokens.onSurface, for: .normal)
            }
        }
    }

    // MARK: - Actions
    @objc private func speedButtonTapped(_ sender: UIButton) {
        let speed = Float(sender.tag) / 100.0
        onSpeedSelected?(speed)
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

        // Initial state: card offscreen, dimming invisible
        dimmingView.alpha = 0
        let safeBottom = parentView.safeAreaInsets.bottom
        cardView.transform = CGAffineTransform(translationX: 0, y: cardView.frame.height + safeBottom)

        layoutIfNeeded()

        // Re-apply transform after layout
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
