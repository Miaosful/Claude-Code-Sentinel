import AppKit
import CCSentinelCore

enum MenuBarIconStyle: String, CaseIterable, Sendable {
    case dot
    case symbol

    var titleKey: L10nKey {
        switch self {
        case .dot: return .iconStyleDot
        case .symbol: return .iconStyleSymbol
        }
    }
}

@MainActor
final class MenuBarController {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var onToggle: (() -> Void)?
    var onShowContextMenu: (() -> Void)?
    private var currentStatus: AggregateStatus = .idle
    private var iconStyle: MenuBarIconStyle = .dot
    private var glowLayer: CALayer?

    var button: NSStatusBarButton? {
        statusItem.button
    }

    func configure() {
        guard let button else { return }
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toggle)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.wantsLayer = true
        button.layer?.masksToBounds = false
    }

    func update(status: AggregateStatus) {
        currentStatus = status
        guard let button else { return }
        button.image = renderImage(status: status, style: iconStyle)
        button.contentTintColor = tintColor(status: status)
    }

    func applyIconStyle(_ style: MenuBarIconStyle) {
        iconStyle = style
        update(status: currentStatus)
    }

    private func tintColor(status: AggregateStatus) -> NSColor {
        switch status {
        case .idle:
            return .secondaryLabelColor
        case .running:
            return .systemGreen
        case .waitingApproval:
            return .systemYellow
        case .degraded:
            return .systemRed
        }
    }

    private func symbolName(status: AggregateStatus, style: MenuBarIconStyle) -> String {
        switch (status, style) {
        case (.idle, _):
            return "scope"
        case (.running, .symbol):
            return "dot.radiowaves.left.and.right"
        case (.waitingApproval, .symbol):
            return "exclamationmark.triangle.fill"
        case (.degraded, .symbol):
            return "xmark.octagon.fill"
        case (.running, .dot), (.waitingApproval, .dot), (.degraded, .dot):
            return "circle.fill"
        }
    }

    private func renderImage(status: AggregateStatus, style: MenuBarIconStyle) -> NSImage? {
        if style == .dot, status != .idle {
            return coloredDotImage(color: tintColor(status: status))
        }
        return NSImage(
            systemSymbolName: symbolName(status: status, style: style),
            accessibilityDescription: status.accessibilityDescription
        )
    }

    private func coloredDotImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let dotRect = NSRect(x: 4, y: 4, width: 10, height: 10)
        color.withAlphaComponent(0.25).setFill()
        NSBezierPath(ovalIn: dotRect.insetBy(dx: -2, dy: -2)).fill()
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    func setWaitingGlow(active: Bool) {
        guard let button else { return }
        if active {
            startWaitingGlow(in: button)
        } else {
            stopWaitingGlow()
        }
    }

    private func startWaitingGlow(in button: NSStatusBarButton) {
        guard glowLayer == nil, let host = button.layer else { return }
        host.masksToBounds = false

        let glow = CALayer()
        glow.bounds = CGRect(x: 0, y: 0, width: 4, height: 4)
        glow.position = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
        glow.cornerRadius = 2
        glow.backgroundColor = NSColor.systemYellow.cgColor
        glow.shadowColor = NSColor.systemYellow.cgColor
        glow.shadowOpacity = 0.0
        glow.shadowRadius = 3
        host.addSublayer(glow)
        glowLayer = glow

        let swell = CABasicAnimation(keyPath: "shadowRadius")
        swell.fromValue = 3
        swell.toValue = 15
        swell.duration = 1.9
        swell.timingFunction = CAMediaTimingFunction(name: .easeOut)
        swell.repeatCount = .infinity

        let fade = CABasicAnimation(keyPath: "shadowOpacity")
        fade.fromValue = 0.85
        fade.toValue = 0.0
        fade.duration = 1.9
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.repeatCount = .infinity

        glow.add(swell, forKey: "glowSwell")
        glow.add(fade, forKey: "glowFade")

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.78
        pulse.duration = 0.95
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        host.add(pulse, forKey: "coreBreathe")
    }

    private func stopWaitingGlow() {
        glowLayer?.removeFromSuperlayer()
        glowLayer = nil
        button?.layer?.removeAnimation(forKey: "coreBreathe")
        button?.layer?.opacity = 1.0
    }

    @objc private func toggle() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            onShowContextMenu?()
        } else {
            onToggle?()
        }
    }
}

private extension AggregateStatus {
    var accessibilityDescription: String {
        switch self {
        case .idle:
            return "CC Sentinel idle"
        case .running:
            return "CC Sentinel running"
        case .waitingApproval:
            return "CC Sentinel waiting approval"
        case .degraded:
            return "CC Sentinel degraded"
        }
    }
}
