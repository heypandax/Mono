//
//  MonoSheetOverlay.swift
//  Mono
//
//  倍速 / 睡眠共用的底部弹层（Master 的 MSheet + MOptionRow）。
//  四条关闭路径等价：关闭按钮、下滑、点击遮罩、Escape；
//  Reduce Motion 下改为交叉淡入，不靠位移传达状态。
//

import UIKit

// MARK: - 选项行

final class MonoOptionRowView: UIControl {

    enum Tone {
        case normal
        case danger
    }

    private let titleLabel = MonoUI.label(.body, color: DesignTokens.onSurface, lines: 0)
    private let valueLabel = MonoUI.label(.footnote, color: DesignTokens.onSurfaceVariant, lines: 0, numeric: true)
    private let checkmark = MonoUI.symbolView("checkmark", style: .body, color: DesignTokens.primary)
    private let separator = MonoSeparatorView()

    private var tone: Tone
    private let numericTitle: Bool
    private var isSelectedRow = false

    init(title: String, value: String? = nil, tone: Tone = .normal, showsSeparator: Bool = true, numericTitle: Bool = false) {
        self.tone = tone
        self.numericTitle = numericTitle
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        if numericTitle {
            titleLabel.font = DesignTokens.numberFont(.body)
        }
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.isHidden = value == nil
        separator.isHidden = !showsSeparator

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, checkmark])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = DesignTokens.Spacing.sm
        stack.isUserInteractionEnabled = false
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(stack)
        addSubview(separator)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.contentInset),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.contentInset),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.contentInset),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = [title, value].compactMap { $0 }.joined(separator: "，")
        applySelection(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 同一行在不同状态下换文案与语气（睡眠弹层的「取消 / 关闭定时」）
    func updateTitle(_ title: String, tone: Tone) {
        self.tone = tone
        titleLabel.text = title
        accessibilityLabel = title
        applySelection(isSelectedRow)
    }

    /// 选中态同时用底色、字重和对勾表达，不只靠颜色
    func applySelection(_ selected: Bool) {
        isSelectedRow = selected
        checkmark.isHidden = !selected
        backgroundColor = selected ? DesignTokens.selectedOptionBackground : .clear

        switch tone {
        case .normal:
            titleLabel.textColor = selected ? DesignTokens.primary : DesignTokens.onSurface
        case .danger:
            titleLabel.textColor = DesignTokens.error
        }
        titleLabel.font = numericTitle
            ? DesignTokens.numberFont(.body, weight: selected ? .semibold : .regular)
            : DesignTokens.font(.body, weight: selected ? .semibold : nil)
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    override var isHighlighted: Bool {
        didSet {
            guard !isSelectedRow else { return }
            backgroundColor = isHighlighted ? DesignTokens.surfaceContainer : .clear
        }
    }
}

// MARK: - 弹层基类

class MonoSheetOverlay: UIView, UIGestureRecognizerDelegate {

    var onDismiss: (() -> Void)?

    private let dimmingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.scrim
        return view
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.elevatedSurface
        view.layer.cornerRadius = DesignTokens.CornerRadius.large
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.clipsToBounds = true
        return view
    }()

    private let grabber: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.outline
        view.layer.cornerRadius = 2.5
        view.isAccessibilityElement = false
        return view
    }()

    private let titleLabel = MonoUI.label(.headline, color: DesignTokens.onSurface, lines: 0)

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        config.baseForegroundColor = DesignTokens.onSurfaceVariant
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "关闭"
        button.accessibilityIdentifier = "sheet.close"
        button.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        return button
    }()

    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        return scroll
    }()

    /// 子类往这里添加内容
    let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 0
        return stack
    }()

    private weak var focusReturnView: UIView?
    private var cardBottomConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.accessibilityTraits = .header
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        accessibilityViewIsModal = true

        addSubview(dimmingView)
        addSubview(cardView)
        cardView.addSubview(grabber)
        cardView.addSubview(titleLabel)
        cardView.addSubview(closeButton)
        let headerSeparator = MonoSeparatorView()
        cardView.addSubview(headerSeparator)
        cardView.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.delegate = self
        cardView.addGestureRecognizer(pan)
        // 内部滚动先等这一手势判定：向下且已在顶部才由弹层接管，否则立即失败让位给滚动
        scrollView.panGestureRecognizer.require(toFail: pan)

        let bottom = cardView.bottomAnchor.constraint(equalTo: bottomAnchor)
        cardBottomConstraint = bottom

        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottom,
            cardView.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: DesignTokens.Spacing.xxl),

            grabber.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 6),
            grabber.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),

            // 卡片背景、grabber 与分隔线全出血；文字与命中区必须躲开刘海横屏的左右安全区
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: grabber.bottomAnchor, constant: DesignTokens.Spacing.sm),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.safeAreaLayoutGuide.leadingAnchor, constant: DesignTokens.contentInset),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            closeButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: DesignTokens.Spacing.sm),
            closeButton.trailingAnchor.constraint(equalTo: cardView.safeAreaLayoutGuide.trailingAnchor, constant: -DesignTokens.Spacing.sm),
            closeButton.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 2),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: DesignTokens.hitTarget),

            headerSeparator.topAnchor.constraint(equalTo: closeButton.bottomAnchor),
            headerSeparator.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),

            // 选项行的文字 / 值 / 对勾随之落在安全区内（竖屏左右安全区为 0，视觉不变）
            scrollView.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: cardView.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: cardView.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: cardView.safeAreaLayoutGuide.bottomAnchor, constant: -DesignTokens.Spacing.sm),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // 弹层高度贴合内容；内容过高时被上面的 top >= 安全区约束截断并滚动
        let contentHeight = scrollView.heightAnchor.constraint(equalTo: contentStack.heightAnchor)
        contentHeight.priority = UILayoutPriority(999)
        contentHeight.isActive = true
    }

    // MARK: - 键盘

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(dismissTapped))]
    }

    // MARK: - Show / Dismiss

    /// - Parameter returningFocusTo: 关闭后把 VoiceOver 焦点还给触发它的控件
    func show(in parentView: UIView, returningFocusTo focusView: UIView? = nil) {
        focusReturnView = focusView
        translatesAutoresizingMaskIntoConstraints = false
        parentView.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor),
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
        parentView.layoutIfNeeded()
        becomeFirstResponder()

        dimmingView.alpha = 0
        if DesignTokens.prefersReducedMotion {
            alpha = 0
            UIView.animate(withDuration: 0.2) {
                self.alpha = 1
                self.dimmingView.alpha = 1
            } completion: { _ in
                UIAccessibility.post(notification: .screenChanged, argument: self.titleLabel)
            }
            return
        }

        cardView.transform = CGAffineTransform(translationX: 0, y: cardView.bounds.height)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5) {
            self.dimmingView.alpha = 1
            self.cardView.transform = .identity
        } completion: { _ in
            UIAccessibility.post(notification: .screenChanged, argument: self.titleLabel)
        }
    }

    @objc private func dismissTapped() {
        dismiss()
    }

    func dismiss(returnFocus: Bool = true, completion: (() -> Void)? = nil) {
        resignFirstResponder()
        let cleanup: (Bool) -> Void = { [weak self] _ in
            guard let self else { return }
            self.onDismiss?()
            self.removeFromSuperview()
            if returnFocus {
                UIAccessibility.post(notification: .layoutChanged, argument: self.focusReturnView)
            }
            completion?()
        }

        if DesignTokens.prefersReducedMotion {
            UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }, completion: cleanup)
            return
        }
        UIView.animate(withDuration: 0.25, animations: {
            self.dimmingView.alpha = 0
            self.cardView.transform = CGAffineTransform(translationX: 0, y: self.cardView.bounds.height)
        }, completion: cleanup)
    }

    // MARK: - 下滑关闭

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self).y
        if DesignTokens.prefersReducedMotion {
            guard gesture.state == .ended || gesture.state == .cancelled else { return }
            let velocity = gesture.velocity(in: self).y
            if translation > cardView.bounds.height / 3 || velocity > 800 {
                dismiss()
            }
            return
        }
        switch gesture.state {
        case .changed:
            cardView.transform = CGAffineTransform(translationX: 0, y: max(0, translation))
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: self).y
            if translation > cardView.bounds.height / 3 || velocity > 800 {
                dismiss()
            } else {
                UIView.animate(withDuration: 0.2) { self.cardView.transform = .identity }
            }
        default:
            break
        }
    }

    // MARK: - 手势协调

    /// 只有「纵向向下 + 内部滚动已经到顶」时弹层才接管下滑关闭；
    /// 向上滑、横向滑或内容还没滚到顶，都让给内部 scroll view。
    /// 抓手与标题栏不属于滚动区，在那里始终可以下滑关闭。
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let velocity = pan.velocity(in: self)
        guard velocity.y > 0, abs(velocity.y) > abs(velocity.x) else { return false }
        guard scrollView.bounds.contains(pan.location(in: scrollView)) else { return true }
        return scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 0.5
    }
}
