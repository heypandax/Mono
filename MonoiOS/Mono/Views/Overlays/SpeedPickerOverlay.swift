//
//  SpeedPickerOverlay.swift
//  Mono
//
//  倍速弹层（Master 的 MSpeedSheet）。保留全部 9 档真实速率。
//

import UIKit

final class SpeedPickerOverlay: MonoSheetOverlay {

    var onSpeedSelected: ((Float) -> Void)?

    var currentSpeed: Float = 1.0 {
        didSet { updateSelection() }
    }

    private let speeds = AudioPlayerManager.availableRates
    private var rows: [MonoOptionRowView] = []

    init() {
        super.init(title: "播放速度")
        accessibilityIdentifier = "sheet.speed"
        buildRows()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildRows() {
        for (index, speed) in speeds.enumerated() {
            let row = MonoOptionRowView(
                title: MonoFormat.rateText(speed),
                showsSeparator: index < speeds.count - 1,
                numericTitle: true
            )
            row.accessibilityLabel = MonoFormat.spokenRateText(speed)
            row.tag = index
            row.addTarget(self, action: #selector(speedTapped(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(row)
            rows.append(row)
        }
        updateSelection()
    }

    private func updateSelection() {
        for (index, row) in rows.enumerated() {
            row.applySelection(abs(speeds[index] - currentSpeed) < 0.01)
        }
    }

    @objc private func speedTapped(_ sender: MonoOptionRowView) {
        guard sender.tag < speeds.count else { return }
        onSpeedSelected?(speeds[sender.tag])
        dismiss()
    }
}
