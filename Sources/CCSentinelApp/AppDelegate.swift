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
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = MenuBarController()
        controller.onToggle = { [weak self] in
            self?.togglePopover()
        }
        controller.onShowContextMenu = { [weak self] in
            self?.showContextMenu()
        }
        controller.configure()
        menuBarController = controller

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: StatusPopoverView.preferredWidth, height: StatusPopoverView.preferredHeight)
        popover.contentViewController = NSHostingController(rootView: StatusPopoverView(model: model))
        self.popover = popover

        model.$store
            .sink { [weak self] _ in
                let status = self?.model.aggregateStatus ?? .idle
                self?.menuBarController?.update(status: status)
            }
            .store(in: &cancellables)

        model.$monitoringPaused
            .sink { [weak self] _ in
                let status = self?.model.aggregateStatus ?? .idle
                self?.menuBarController?.update(status: status)
            }
            .store(in: &cancellables)

        model.$iconStylePreference
            .sink { [weak self] style in
                self?.menuBarController?.applyIconStyle(style)
            }
            .store(in: &cancellables)

        startReceiver()
        startStatsRefresh()
        controller.applyIconStyle(model.iconStylePreference)
        controller.update(status: model.aggregateStatus)
        openPopoverOnLaunchIfRequested()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statsTimer?.invalidate()
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
                self?.model.refreshRuntimeStatus()
            }
        }
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

        model.refreshHookInstallationStatus()
        model.refreshRuntimeStatus()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        activatePopoverWindow(popover)
    }

    private func activatePopoverWindow(_ popover: NSPopover) {
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }

    private func showContextMenu() {
        popover?.performClose(nil)
        guard let button = menuBarController?.button else { return }

        let menu = NSMenu()
        let languageItem = NSMenuItem(title: model.localized(.languageMenu), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()

        for preference in AppLanguagePreference.allCases {
            let item = NSMenuItem(
                title: model.localized(preference.titleKey),
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preference.rawValue
            item.state = model.languagePreference == preference ? .on : .off
            languageMenu.addItem(item)
        }

        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        let iconStyleItem = NSMenuItem(title: model.localized(.iconStyleMenu), action: nil, keyEquivalent: "")
        let iconStyleMenu = NSMenu()

        for style in MenuBarIconStyle.allCases {
            let item = NSMenuItem(
                title: model.localized(style.titleKey),
                action: #selector(selectIconStyle(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = style.rawValue
            item.state = model.iconStylePreference == style ? .on : .off
            iconStyleMenu.addItem(item)
        }

        iconStyleItem.submenu = iconStyleMenu
        menu.addItem(iconStyleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: model.localized(.quit), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.minY - 4), in: button)
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let preference = AppLanguagePreference(rawValue: rawValue)
        else { return }
        model.languagePreference = preference
    }

    @objc private func selectIconStyle(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let style = MenuBarIconStyle(rawValue: rawValue)
        else { return }
        model.iconStylePreference = style
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
