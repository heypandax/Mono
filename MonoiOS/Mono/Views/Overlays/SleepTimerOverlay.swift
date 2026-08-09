//
//  SleepTimerOverlay.swift
//  Mono
//
//  睡眠定时弹层（Master 的 MSleepSheet）。
//  激活态同时显示文字与剩余时间，不只用颜色表示已激活。
//

import UIKit

final class SleepTimerOverlay: MonoSheetOverlay {

    // MARK: - Callbacks

    var onTimerSelected: ((Int) -> Void)?
    var onEndOfTrack: (() -> Void)?
    var onCancel: (() -> Void)?
    var onCustomTime: (() -> Void)?

    // MARK: - State

    var isTimerActive: Bool = false { didSet { updateSelection() } }
    var sleepAtEndOfTrack: Bool = false { didSet { updateSelection() } }
    /// 当前激活的分钟档位（向上取整，刚设完 30 分钟仍高亮 30 分钟）
    var activeMinutes: Int = 0 { didSet { updateSelection() } }

    // MARK: - UI

    private let presets = [15, 30, 45, 60, 90]
    private var presetRows: [MonoOptionRowView] = []
    private var endOfTrackRow: MonoOptionRowView?
    private var trailingRow: MonoOptionRowView?

    private let activeBanner: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = DesignTokens.selectedOptionBackground
        view.isHidden = true
        return view
    }()

    private let remainingLabel = MonoUI.label(.headline, color: DesignTokens.primary, lines: 1, numeric: true)
    private let remainingCaption = MonoUI.label(.caption1, color: DesignTokens.onSurfaceVariant, lines: 0)

    // MARK: - Init

    init() {
        super.init(title: "睡眠定时")
        accessibilityIdentifier = "sheet.sleep"
        buildContent()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sleepTimerDidChange),
            name: .sleepTimerDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Build

    private func buildContent() {
        buildActiveBanner()
        contentStack.addArrangedSubview(activeBanner)

        for minutes in presets {
            let row = MonoOptionRowView(title: "\(minutes) 分钟")
            row.tag = minutes
            row.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(row)
            presetRows.append(row)
        }

        let customRow = MonoOptionRowView(title: "自定义…")
        customRow.addTarget(self, action: #selector(customTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(customRow)

        let endRow = MonoOptionRowView(title: "播完本章")
        endRow.addTarget(self, action: #selector(endOfTrackTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(endRow)
        endOfTrackRow = endRow

        let trailing = MonoOptionRowView(title: "取消", tone: .normal, showsSeparator: false)
        trailing.addTarget(self, action: #selector(trailingTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(trailing)
        trailingRow = trailing

        updateSelection()
    }

    private func buildActiveBanner() {
        let icon = MonoUI.symbolView("moon.fill", style: .body, color: DesignTokens.primary)
        let textStack = UIStackView(arrangedSubviews: [remainingLabel, remainingCaption])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        remainingCaption.text = "到时后暂停播放"

        activeBanner.addSubview(icon)
        activeBanner.addSubview(textStack)
        activeBanner.isAccessibilityElement = true

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: activeBanner.leadingAnchor, constant: DesignTokens.contentInset),
            icon.centerYAnchor.constraint(equalTo: activeBanner.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: DesignTokens.Spacing.md),
            textStack.trailingAnchor.constraint(equalTo: activeBanner.trailingAnchor, constant: -DesignTokens.contentInset),
            textStack.topAnchor.constraint(equalTo: activeBanner.topAnchor, constant: DesignTokens.Spacing.md),
            textStack.bottomAnchor.constraint(equalTo: activeBanner.bottomAnchor, constant: -DesignTokens.Spacing.md)
        ])
    }

    // MARK: - Update

    private func updateSelection() {
        let player = AudioPlayerManager.shared

        if sleepAtEndOfTrack {
            activeBanner.isHidden = false
            remainingLabel.text = "播完本章"
            remainingCaption.text = "本章结束后暂停播放"
            activeBanner.accessibilityLabel = "播完本章后暂停播放"
        } else if isTimerActive, let remaining = player.sleepTimerRemaining, remaining > 0 {
            activeBanner.isHidden = false
            remainingLabel.text = "还剩 \(MonoFormat.countdownText(remaining))"
            remainingCaption.text = "到时后暂停播放"
            activeBanner.accessibilityLabel = "还剩 \(MonoFormat.spokenTime(remaining))，到时后暂停播放"
        } else {
            activeBanner.isHidden = true
        }

        for row in presetRows {
            row.applySelection(isTimerActive && !sleepAtEndOfTrack && row.tag == activeMinutes)
        }
        endOfTrackRow?.applySelection(sleepAtEndOfTrack)
        trailingRow?.applySelection(false)
        trailingRow?.updateTitle(isTimerActive ? "关闭定时" : "取消",
                                 tone: isTimerActive ? .danger : .normal)
    }

    @objc private func sleepTimerDidChange() {
        let player = AudioPlayerManager.shared
        sleepAtEndOfTrack = player.sleepAtEndOfTrack
        isTimerActive = player.isSleepTimerActive
        if let remaining = player.sleepTimerRemaining, remaining > 0 {
            activeMinutes = Int((remaining / 60).rounded(.up))
        } else {
            activeMinutes = 0
        }
    }

    // MARK: - Actions

    @objc private func presetTapped(_ sender: MonoOptionRowView) {
        onTimerSelected?(sender.tag)
        dismiss()
    }

    @objc private func customTapped() {
        let action = onCustomTime
        dismiss(returnFocus: false, completion: action)
    }

    @objc private func endOfTrackTapped() {
        onEndOfTrack?()
        dismiss()
    }

    /// 未激活时是「取消」（等价于关闭弹层），激活时是破坏性的「关闭定时」
    @objc private func trailingTapped() {
        if isTimerActive || sleepAtEndOfTrack {
            onCancel?()
        }
        dismiss()
    }
}
