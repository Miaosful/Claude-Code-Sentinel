import AppKit
import Combine
import SwiftUI
import CCSentinelCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var menuBarController: MenuBarController?
    private var popover: NSPopover?
    private var settingsWindowController: NSWindowController?
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
        let view = StatusPopoverView(model: model, onOpenSettings: { [weak self] in
            self?.requestSettingsWindow()
        }) { [weak popover] height in
            guard let popover else { return }
            popover.contentSize = NSSize(width: StatusPopoverView.preferredWidth, height: height)
        }
        let hostingController = NSHostingController(rootView: view)
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: StatusPopoverView.preferredWidth, height: StatusPopoverView.preferredMaxHeight)
        self.popover = popover

        model.$store
            .sink { [weak self] _ in
                let status = self?.model.aggregateStatus ?? .idle
                self?.syncStatus(status)
            }
            .store(in: &cancellables)

        model.$monitoringPaused
            .sink { [weak self] _ in
                let status = self?.model.aggregateStatus ?? .idle
                self?.syncStatus(status)
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
        syncStatus(model.aggregateStatus)
        openPopoverOnLaunchIfRequested()
        openSettingsOnLaunchIfRequested()
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

    private func syncStatus(_ status: AggregateStatus) {
        menuBarController?.update(status: status)
        menuBarController?.setWaitingGlow(active: status == .waitingApproval)
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

    private func openSettingsOnLaunchIfRequested() {
        guard ProcessInfo.processInfo.environment["CC_SENTINEL_OPEN_SETTINGS_ON_LAUNCH"] == "1" else {
            return
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            requestSettingsWindow()
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
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: model.localized(.settings), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    @objc private func openSettings() {
        requestSettingsWindow()
    }

    private func requestSettingsWindow() {
        popover?.performClose(nil)
        DispatchQueue.main.async { [weak self] in
            self?.showSettingsWindow()
        }
    }

    private func showSettingsWindow() {
        if let window = settingsWindowController?.window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView(model: model))
        hostingController.sizingOptions = []
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = model.localized(.settings)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentMinSize = NSSize(width: 460, height: 320)
        window.center()

        let controller = NSWindowController(window: window)
        settingsWindowController = controller

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }
}
