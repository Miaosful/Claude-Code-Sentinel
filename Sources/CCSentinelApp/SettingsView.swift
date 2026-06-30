import SwiftUI
import CCSentinelCore

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AutoApprovalSettingsCard(model: model)
                AppearanceSettingsCard(model: model)
                IntegrationSettingsCard(model: model)
                AboutSettingsCard(model: model)
            }
            .padding(18)
        }
        .background(Color.ccPopoverBackground)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.ccCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct AutoApprovalSettingsCard: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsCard(title: model.localized(.autoApprovalPolicy)) {
            Toggle("", isOn: $model.autoApprovalEnabled)
                .labelsHidden()
                .toggleStyle(.switch)

            LabeledContent(model.localized(.autoApprovalWorkspace)) {
                Text(model.autoApprovalConfig.workspace.isEmpty ? "—" : model.autoApprovalConfig.workspace)
                    .font(.caption.monospaced())
                    .lineLimit(1).truncationMode(.middle)
            }

            if let profile = model.autoApprovalConfig.profile {
                LabeledContent(model.localized(.autoApprovalConfigTitle)) {
                    Text(profile.name).font(.caption)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(model.localized(.autoApprovalRules)).font(.caption).foregroundStyle(.secondary)
                if model.autoApprovalConfig.rules.isEmpty {
                    Text("—").font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.autoApprovalConfig.rules, id: \.id) { rule in
                            RuleRow(model: model, rule: rule)
                        }
                    }
                    .padding(8)
                    .background(Color.ccPopoverBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(model.localized(.autoApprovalRulesReadonlyHint))
                    .font(.caption2).foregroundStyle(.secondary)
            }

            HStack {
                Button(model.localized(.autoApprovalRevealConfig)) { model.revealAutoApprovalConfigInFinder() }
                Button(model.localized(.autoApprovalImportConfig)) { model.presentImportAutoApprovalConfigPanel() }
                Button(model.localized(.autoApprovalExportConfig)) { model.presentExportAutoApprovalConfigPanel() }
            }
            .controlSize(.small)

            Text(model.autoApprovalConfigFileURL.path)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)

            LabeledContent(model.localized(.autoApprovedToday)) { Text("\(model.autoApprovedToday)") }
            LabeledContent(model.localized(.autoApprovedTotal)) { Text("\(model.autoApprovedTotal)") }
        }
    }
}

private struct RuleRow: View {
    @ObservedObject var model: AppModel
    let rule: AutoApprovalRule

    private var effectColor: Color { rule.effect == .allow ? .green : .red }
    private var effectText: String {
        model.localized(rule.effect == .allow ? .autoApprovalRuleAllow : .autoApprovalRuleDeny)
    }
    private var scopeText: String? {
        switch rule.scope {
        case .workspace: return model.localized(.autoApprovalScopeWorkspace)
        case .any: return model.localized(.autoApprovalScopeAny)
        case .none: return nil
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(effectText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(effectColor)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(effectColor.opacity(0.12))
                .clipShape(Capsule())
            Text(rule.tool).font(.caption.weight(.semibold))
            if let scopeText { Text("· \(scopeText)").font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
        if let keywords = rule.match?.commandContains, !keywords.isEmpty {
            Text(keywords.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AppearanceSettingsCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        SettingsCard(title: model.localized(.settingsAppearanceTitle)) {
            Picker(model.localized(.settingsLanguage),
                   selection: $model.languagePreference) {
                ForEach(AppLanguagePreference.allCases, id: \.self) { preference in
                    Text(model.localized(preference.titleKey)).tag(preference)
                }
            }
            Picker(model.localized(.settingsIconStyle),
                   selection: $model.iconStylePreference) {
                ForEach(MenuBarIconStyle.allCases, id: \.self) { style in
                    Text(model.localized(style.titleKey)).tag(style)
                }
            }
        }
    }
}

private struct IntegrationSettingsCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        SettingsCard(title: model.localized(.settingsIntegrationTitle)) {
            HStack {
                Text(model.localized(model.hooksInstalled ? .integrationHooksInstalled : .headerHooksMissing))
                    .font(.caption)
                    .foregroundStyle(model.hooksInstalled ? .green : .secondary)
                Spacer()
                Button(model.localized(model.hooksInstalled ? .integrationUninstall : .integrationInstall)) {
                    model.hooksInstalled ? model.uninstallHooks() : model.installHooks()
                }
                .controlSize(.small)
            }

            Toggle(model.localized(model.monitoringPaused ? .integrationResumeMonitoring : .integrationPauseMonitoring),
                   isOn: Binding(get: { !model.monitoringPaused }, set: { _ in model.pauseOrResumeMonitoring() }))
                .toggleStyle(.switch)
        }
    }
}

private struct AboutSettingsCard: View {
    @ObservedObject var model: AppModel
    var body: some View {
        SettingsCard(title: model.localized(.settingsAboutTitle)) {
            LabeledContent(model.localized(.settingsVersion)) {
                Text(CCSentinelVersion.current).font(.caption)
            }
            Text(model.localized(.settingsPrivacyDetail))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
