import SwiftUI
import CCSentinelCore

struct StatusPopoverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            summary
            Divider()
            sessions
            Divider()
            controls
            autoApprovalStats
        }
        .padding(14)
        .frame(width: 382, alignment: .topLeading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(.appName))
                    .font(.headline)
                Text("\(model.store.sessions.count) \(localized(.sessionsTitle).lowercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(statusTitle, systemImage: model.aggregateStatus.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusColor)
            Text(statusDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized(.sessionsTitle).uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if model.store.sessions.isEmpty {
                Text("No active Claude Code sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(model.store.sessions) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private var controls: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Button(model.monitoringPaused ? "Resume monitoring" : localized(.pauseMonitoring)) {
                    model.pauseOrResumeMonitoring()
                }
                Button(localized(.clearStale)) {
                    model.clearStaleSessions()
                }
            }
            GridRow {
                Button(localized(.installHooks)) {}
                Button(localized(.uninstallHooks)) {}
            }
        }
        .buttonStyle(.bordered)
    }

    private var autoApprovalStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(localized(.autoApprovalPolicy), isOn: $model.autoApprovalEnabled)
                .toggleStyle(.switch)

            HStack(spacing: 8) {
                statCard(title: localized(.autoApprovedToday), value: model.autoApprovedToday)
                statCard(title: localized(.autoApprovedTotal), value: model.autoApprovedTotal)
            }
        }
    }

    private func sessionRow(_ session: ClaudeSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.status.rawValue)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(session.source.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(session.cwd)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            if let lastToolName = session.lastToolName {
                Text(lastToolName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statCard(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusTitle: String {
        switch model.aggregateStatus {
        case .idle:
            return localized(.statusIdle)
        case .running:
            return localized(.statusRunning)
        case .waitingApproval:
            return localized(.statusWaitingApproval)
        case .degraded:
            return localized(.statusDegraded)
        }
    }

    private var statusDetail: String {
        switch model.aggregateStatus {
        case .idle:
            return "No active Claude Code sessions are reporting."
        case .running:
            return "Claude Code sessions are active."
        case .waitingApproval:
            return "A session is blocked on an approval request."
        case .degraded:
            return model.monitoringPaused ? "Monitoring is paused." : "Event state may be incomplete."
        }
    }

    private var statusColor: Color {
        switch model.aggregateStatus {
        case .idle:
            return .secondary
        case .running:
            return .green
        case .waitingApproval:
            return .orange
        case .degraded:
            return .red
        }
    }

    private func localized(_ key: L10nKey) -> String {
        NSLocalizedString(key.rawValue, bundle: .module, comment: "")
    }
}

private extension AggregateStatus {
    var symbolName: String {
        switch self {
        case .idle:
            return "scope"
        case .running:
            return "dot.radiowaves.left.and.right"
        case .waitingApproval:
            return "exclamationmark.triangle.fill"
        case .degraded:
            return "xmark.octagon.fill"
        }
    }
}
