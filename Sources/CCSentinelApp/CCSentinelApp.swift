import SwiftUI

@main
struct CCSentinelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // CC Sentinel is a menu-bar (accessory) app; there is no app menu, so a
        // SwiftUI Settings scene is unreachable. The real settings window is
        // hosted by AppDelegate.showSettingsWindow() and shares the live
        // AppModel. A `Settings { EmptyView() }` scene never auto-presents a
        // window (unlike WindowGroup), and the `.accessory` activation policy
        // keeps the app out of the Dock, so nothing shows on launch.
        Settings {
            EmptyView()
        }
    }
}
