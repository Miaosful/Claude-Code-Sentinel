import SwiftUI
import CCSentinelCore

struct StatusPopoverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                summary
                approvalRequest
                Divider()
                sessions
                Divider()
                controls
                integrationMessage
                autoApprovalStats
            }
            .padding(14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: 382, alignment: .topLeading)
        .frame(maxHeight: 560, alignment: .topLeading)
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

    @ViewBuilder
    private var approvalRequest: some View {
        if let focus = model.approvalFocus {
            VStack(alignment: .leading, spacing: 8) {
                Label(localized(.approvalRequestTitle), systemImage: "hand.raised.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
                    GridRow {
                        fieldLabel(.approvalTool)
                        Text(focus.toolName)
                            .font(.caption.weight(.semibold))
                    }
                    GridRow {
                        fieldLabel(.approvalSource)
                        Text(focus.source.rawValue.uppercased())
                            .font(.caption)
                    }
                    GridRow {
                        fieldLabel(.approvalWorkspace)
                        Text(focus.cwd)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    GridRow {
                        fieldLabel(.approvalSummary)
                        Text(focus.summary)
                            .font(.caption)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.orange.opacity(0.45), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localized(.sessionsTitle).uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if model.store.sessions.isEmpty {
                Text(localized(.noActiveSessions))
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
                Button(model.monitoringPaused ? localized(.resumeMonitoring) : localized(.pauseMonitoring)) {
                    model.pauseOrResumeMonitoring()
                }
                Button(localized(.clearStale)) {
                    model.clearStaleSessions()
                }
            }
            GridRow {
                Button(localized(.installHooks)) {
                    model.installHooks()
                }
                Button(localized(.uninstallHooks)) {
                    model.uninstallHooks()
                }
            }
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var integrationMessage: some View {
        if let message = model.integrationMessage {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized(message.key))
                    .font(.caption.weight(.semibold))
                if !message.detail.isEmpty {
                    Text(message.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .foregroundStyle(message.isError ? .red : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
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
                Text(sessionStatusTitle(session.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(session.status == .waitingApproval ? .orange : .primary)
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
            if let summary = session.lastToolSummary, !summary.isEmpty {
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .background(sessionBackground(for: session))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(session.status == .waitingApproval ? Color.orange.opacity(0.45) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fieldLabel(_ key: L10nKey) -> some View {
        Text(localized(key))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func sessionBackground(for session: ClaudeSession) -> some View {
        if session.status == .waitingApproval {
            Rectangle().fill(Color.orange.opacity(0.12))
        } else {
            Rectangle().fill(.quaternary.opacity(0.35))
        }
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
            return localized(.detailIdle)
        case .running:
            return localized(.detailRunning)
        case .waitingApproval:
            return localized(.detailWaitingApproval)
        case .degraded:
            return model.monitoringPaused ? localized(.detailPaused) : localized(.detailDegraded)
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

    private func sessionStatusTitle(_ status: SessionStatus) -> String {
        switch status {
        case .running:
            return localized(.sessionStatusRunning)
        case .waitingApproval:
            return localized(.sessionStatusWaitingApproval)
        case .idle:
            return localized(.sessionStatusIdle)
        case .ended:
            return localized(.sessionStatusEnded)
        case .stale:
            return localized(.sessionStatusStale)
        case .error:
            return localized(.sessionStatusError)
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
