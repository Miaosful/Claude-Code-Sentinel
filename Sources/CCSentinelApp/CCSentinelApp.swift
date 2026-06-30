import SwiftUI

@main
struct CCSentinelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsSceneView()
        }
    }
}

private struct SettingsSceneView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        SettingsView(model: model)
    }
}
