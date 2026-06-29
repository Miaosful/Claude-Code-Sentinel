import SwiftUI
import CCSentinelCore

struct SettingsView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        Form {
            Section(localized(.autoApprovalConfigTitle)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized(.autoApprovalConfigPath))
                        .foregroundStyle(.secondary)
                    Text(model.autoApprovalConfigFileURL.path)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .truncationMode(.middle)
                    HStack(spacing: 8) {
                        Button {
                            model.revealAutoApprovalConfigInFinder()
                        } label: {
                            Label(localized(.autoApprovalRevealConfig), systemImage: "folder")
                        }
                        Button {
                            model.presentImportAutoApprovalConfigPanel()
                        } label: {
                            Label(localized(.autoApprovalImportConfig), systemImage: "square.and.arrow.down")
                        }
                        Button {
                            model.presentExportAutoApprovalConfigPanel()
                        } label: {
                            Label(localized(.autoApprovalExportConfig), systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
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
        .frame(width: 460)
    }

    private func localized(_ key: L10nKey) -> String {
        model.localized(key)
    }
}
