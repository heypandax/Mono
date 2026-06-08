//
//  ProgressRingView.swift
//  Mono
//

import UIKit

final class ProgressRingView: UIView {

    // MARK: - Properties

    var progress: CGFloat = 0 {
        didSet {
            let clamped = min(max(progress, 0), 1)
            if animated {
                animateProgress(to: clamped)
            } else {
                progressLayer.strokeEnd = clamped
            }
        }
    }

    var lineWidth: CGFloat = 3 {
        didSet {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
        }
    }

    var trackColor: UIColor = DesignTokens.surfaceVariant {
        didSet { trackLayer.strokeColor = trackColor.cgColor }
    }

    var progressColor: UIColor = DesignTokens.primaryContainer {
        didSet { progressLayer.strokeColor = progressColor.cgColor }
    }

    var animated: Bool = true

    // MARK: - Layers

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePaths()
    }

    // MARK: - Setup

    private func setupLayers() {
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = trackColor.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }

    private func updatePaths() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let startAngle: CGFloat = -.pi / 2
        let endAngle: CGFloat = startAngle + 2 * .pi

        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )

        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    // MARK: - Animation

    private func animateProgress(to value: CGFloat) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = value
        animation.duration = 0.35
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        progressLayer.strokeEnd = value
        progressLayer.add(animation, forKey: "progressAnimation")
    }
}
