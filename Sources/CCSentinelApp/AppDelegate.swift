import AppKit
import Combine
import SwiftUI
import CCSentinelCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var menuBarController: MenuBarController?
    private var popover: NSPopover?
    private var receiver: EventReceiver?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = MenuBarController()
        controller.onToggle = { [weak self] in
            self?.togglePopover()
        }
        controller.configure()
        menuBarController = controller

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 382, height: 560)
        popover.contentViewController = NSHostingController(rootView: StatusPopoverView(model: model))
        self.popover = popover

        model.$store
            .sink { [weak self] store in
                self?.menuBarController?.update(status: store.aggregateStatus)
            }
            .store(in: &cancellables)

        model.$monitoringPaused
            .sink { [weak self] _ in
                self?.menuBarController?.update(status: self?.model.aggregateStatus ?? .idle)
            }
            .store(in: &cancellables)

        startReceiver()
        controller.update(status: model.aggregateStatus)
    }

    private func startReceiver() {
        do {
            let receiver = try EventReceiver { [weak model] event in
                Task { @MainActor in
                    model?.apply(event)
                }
            }
            receiver.start()
            self.receiver = receiver
        } catch {
            menuBarController?.update(status: .degraded)
        }
    }

    private func togglePopover() {
        guard
            let button = menuBarController?.button,
            let popover
        else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
