import SwiftUI
import CCSentinelCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section(title: localized(.autoApprovalConfigTitle)) {
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
                    .controlSize(.small)
                }

                section(title: localized(.settingsIntegrationTitle)) {
                    Text(localized(.settingsIntegrationDetail))
                        .foregroundStyle(.secondary)
                }

                section(title: localized(.settingsPrivacyTitle)) {
                    Text(localized(.settingsPrivacyDetail))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 520)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func localized(_ key: L10nKey) -> String {
        model.localized(key)
    }
}
