import SwiftUI
import CCSentinelCore

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Integration") {
                Text("Install or remove Claude Code hooks from the menu bar popover.")
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Text("CC Sentinel stores events locally and does not send data to external services.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
