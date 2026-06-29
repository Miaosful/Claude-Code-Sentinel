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
    private var breathingTimer: Timer?
    private var breathingPhase: Double = 0
    private let breathingCycleDuration: TimeInterval = 1.8
    private let breathingInterval: TimeInterval = 0.05

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
        if breathingTimer != nil, status == .waitingApproval {
            return
        }
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
        if active {
            startBreathing()
        } else {
            stopBreathing()
        }
    }

    private func startBreathing() {
        guard breathingTimer == nil else { return }
        breathingPhase = 0
        applyBreathingFrame()
        let timer = Timer(timeInterval: breathingInterval, target: self, selector: #selector(breathingTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        breathingTimer = timer
    }

    private func stopBreathing() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        update(status: currentStatus)
    }

    @objc private func breathingTick() {
        applyBreathingFrame()
    }

    private func applyBreathingFrame() {
        guard let button else { return }
        let intensity = (sin(2.0 * .pi * breathingPhase) + 1) / 2
        breathingPhase = (breathingPhase + breathingStep).truncatingRemainder(dividingBy: 1)

        if iconStyle == .dot {
            button.image = breathingDotImage(color: .systemYellow, intensity: intensity)
            button.contentTintColor = nil
        } else {
            button.image = renderImage(status: .waitingApproval, style: .symbol)
            button.contentTintColor = NSColor.systemYellow.withAlphaComponent(0.45 + 0.55 * CGFloat(intensity))
        }
    }

    private var breathingStep: Double {
        breathingInterval / breathingCycleDuration
    }

    private func breathingDotImage(color: NSColor, intensity: Double) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        let dotRect = NSRect(x: 4, y: 4, width: 10, height: 10)
        let haloAlpha = CGFloat(0.08 + 0.30 * intensity)
        let haloGrowth = CGFloat(2.0 + 2.5 * intensity)
        color.withAlphaComponent(haloAlpha).setFill()
        NSBezierPath(ovalIn: dotRect.insetBy(dx: -haloGrowth, dy: -haloGrowth)).fill()
        let coreAlpha = CGFloat(0.55 + 0.45 * intensity)
        color.withAlphaComponent(coreAlpha).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
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
