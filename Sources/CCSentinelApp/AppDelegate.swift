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
    private var statsTimer: Timer?
    private var waitingPulseTimer: Timer?
    private var waitingPulseHighlighted = false
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
                self?.syncWaitingPulse(status: store.aggregateStatus)
            }
            .store(in: &cancellables)

        model.$monitoringPaused
            .sink { [weak self] _ in
                let status = self?.model.aggregateStatus ?? .idle
                self?.menuBarController?.update(status: status)
                self?.syncWaitingPulse(status: status)
            }
            .store(in: &cancellables)

        startReceiver()
        startStatsRefresh()
        controller.update(status: model.aggregateStatus)
        syncWaitingPulse(status: model.aggregateStatus)
        openPopoverOnLaunchIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statsTimer?.invalidate()
        waitingPulseTimer?.invalidate()
        receiver?.stop()
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

    private func startStatsRefresh() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.model.refreshAutoApprovalStats()
            }
        }
    }

    private func syncWaitingPulse(status: AggregateStatus) {
        if status == .waitingApproval {
            startWaitingPulse()
        } else {
            stopWaitingPulse()
        }
    }

    private func startWaitingPulse() {
        guard waitingPulseTimer == nil else {
            return
        }
        waitingPulseHighlighted = false
        waitingPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.waitingPulseHighlighted.toggle()
                self.menuBarController?.pulseWaitingApproval(self.waitingPulseHighlighted)
            }
        }
    }

    private func stopWaitingPulse() {
        waitingPulseTimer?.invalidate()
        waitingPulseTimer = nil
        waitingPulseHighlighted = false
    }

    private func openPopoverOnLaunchIfRequested() {
        guard ProcessInfo.processInfo.environment["CC_SENTINEL_OPEN_POPOVER_ON_LAUNCH"] == "1" else {
            return
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            showPopover()
        }
    }

    private func togglePopover() {
        guard popover?.isShown != true else {
            popover?.performClose(nil)
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard
            let button = menuBarController?.button,
            let popover
        else { return }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        activatePopoverWindow(popover)
    }

    private func activatePopoverWindow(_ popover: NSPopover) {
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }
}
