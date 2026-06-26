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
