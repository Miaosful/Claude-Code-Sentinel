import AppKit
import CCSentinelCore

@MainActor
final class MenuBarController {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var onToggle: (() -> Void)?
    var onShowContextMenu: (() -> Void)?
    private var currentStatus: AggregateStatus = .idle

    var button: NSStatusBarButton? {
        statusItem.button
    }

    func configure() {
        guard let button else { return }
        button.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "CC Sentinel")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(toggle)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func update(status: AggregateStatus) {
        currentStatus = status
        guard let button else { return }
        button.contentTintColor = status.menuBarColor
        button.image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: status.accessibilityDescription)
    }

    func pulseWaitingApproval(_ isHighlighted: Bool) {
        guard currentStatus == .waitingApproval, let button else {
            return
        }
        button.contentTintColor = isHighlighted ? .systemRed : .systemOrange
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
    var symbolName: String {
        switch self {
        case .idle:
            return "scope"
        case .running:
            return "dot.radiowaves.left.and.right"
        case .waitingApproval:
            return "exclamationmark.triangle.fill"
        case .degraded:
            return "xmark.octagon.fill"
        }
    }

    var menuBarColor: NSColor {
        switch self {
        case .idle:
            return .secondaryLabelColor
        case .running:
            return .systemGreen
        case .waitingApproval:
            return .systemOrange
        case .degraded:
            return .systemRed
        }
    }

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
