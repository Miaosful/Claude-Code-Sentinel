import SwiftUI
import CCSentinelCore

struct StatusPopoverView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                summary
                approvalRequestSection
                sessions
                controlPanel
                autoApprovalStats
                integrationMessage
            }
            .padding(12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: 382, alignment: .topLeading)
        .frame(maxHeight: 560, alignment: .topLeading)
        .background(Color.ccPopoverBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            SentinelMark(color: statusColor)
                .frame(width: 34, height: 34)
                .background(Color.ccCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.ccPanelBorder, lineWidth: 1)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(localized(.appName))
                    .font(.system(size: 15, weight: .bold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.24), radius: 3)
                    Text(localized(.summaryCurrentState))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(statusTitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.primary)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            RadarMark(color: statusColor)
                .frame(width: 54, height: 54)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ccCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.ccPanelBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var approvalRequestSection: some View {
        if let focus = model.approvalFocus {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle(localized(.approvalRequestTitle), trailing: focus.source.rawValue.uppercased())
                approvalRequest(focus)
            }
        }
    }

    private func approvalRequest(_ focus: ApprovalFocus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text(localized(.statusWaitingApproval))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                sourcePill(focus.source)
            }
            Text(focus.cwd)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            toolLine(tool: focus.toolName, summary: focus.summary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.44), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var sessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(localized(.sessionsTitle), trailing: sessionCountLabel)

            if model.store.sessions.isEmpty {
                emptySessionRow
            } else {
                ForEach(model.store.sessions) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private var emptySessionRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(localized(model.requiresHookSetup ? .hooksMissingShort : .noActiveSessionsShort))
                        .font(.caption.weight(.bold))
                }
                Spacer()
                Text(localized(.sourceSystem))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.ccControlBorder, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Text(localized(model.requiresHookSetup ? .hooksMissingDetail : .noActiveSessionsDetail))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ccMutedPanelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.ccPanelBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            autoApprovalToggle
            actionGrid
        }
    }

    private var autoApprovalToggle: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(localized(.autoApprovalPolicy))
                    .font(.caption.weight(.bold))
                Text(autoApprovalCopy)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $model.autoApprovalEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(10)
        .background(Color.ccMutedPanelBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.ccPanelBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var actionGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Button {
                    model.installHooks()
                } label: {
                    Label(localized(.installHooks), systemImage: "arrow.down.to.line.compact")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CCActionButtonStyle(kind: .primary))

                Button {
                    model.pauseOrResumeMonitoring()
                } label: {
                    Label(model.monitoringPaused ? localized(.resumeMonitoring) : localized(.pauseMonitoring), systemImage: model.monitoringPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CCActionButtonStyle(kind: .secondary))
            }
            GridRow {
                Button {
                    model.clearStaleSessions()
                } label: {
                    Label(localized(.clearStale), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CCActionButtonStyle(kind: .secondary))

                Button {
                    model.uninstallHooks()
                } label: {
                    Label(localized(.uninstallHooks), systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CCActionButtonStyle(kind: .secondary))
            }
        }
    }

    @ViewBuilder
    private var integrationMessage: some View {
        if let message = model.integrationMessage {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized(message.key))
                    .font(.caption.weight(.bold))
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
            .padding(10)
            .background(Color.ccMutedPanelBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(message.isError ? Color.red.opacity(0.44) : Color.ccPanelBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var autoApprovalStats: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                statCard(title: localized(.autoApprovedToday), value: model.autoApprovedToday, detail: model.autoApprovedToday == 0 ? localized(.autoApprovedNoneToday) : localized(.autoApprovedTodayTrend))
                statCard(title: localized(.autoApprovedTotal), value: model.autoApprovedTotal, detail: localized(.autoApprovedTotalTrend))
            }
            autoApprovalLog
        }
    }

    private var autoApprovalLog: some View {
        HStack(spacing: 8) {
            Text(autoApprovalLastAction)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.ccCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.ccPanelBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sessionRow(_ session: ClaudeSession) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(sessionColor(session.status))
                        .frame(width: 8, height: 8)
                    Text(sessionStatusTitle(session.status))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(session.status == .waitingApproval ? .orange : .primary)
                }
                Spacer()
                sourcePill(session.source)
            }
            Text(session.cwd)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if let lastToolName = session.lastToolName {
                toolLine(tool: lastToolName, summary: session.lastToolSummary ?? "")
            }
        }
        .padding(10)
        .background(sessionBackground(for: session))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(session.status == .waitingApproval ? Color.orange.opacity(0.44) : Color.ccPanelBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sectionTitle(_ title: String, trailing: String) -> some View {
        HStack {
            Text(title.uppercased())
            Spacer()
            Text(trailing)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }

    private func sourcePill(_ source: SessionSource) -> some View {
        Text(source.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(sourceColor(source))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(sourceColor(source).opacity(0.10))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(sourceColor(source).opacity(0.24), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func toolLine(tool: String, summary: String) -> some View {
        HStack(spacing: 7) {
            Text(tool)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 42, alignment: .leading)
            Text(summary.isEmpty ? "-" : summary)
                .font(.caption2.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    private func fieldLabel(_ key: L10nKey) -> some View {
        Text(localized(key))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func sessionBackground(for session: ClaudeSession) -> some View {
        if session.status == .waitingApproval {
            Rectangle().fill(Color.orange.opacity(0.10))
        } else {
            Rectangle().fill(Color.ccMutedPanelBackground)
        }
    }

    private func statCard(title: String, value: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(value)")
                .font(.system(size: 25, weight: .bold))
                .monospacedDigit()
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(value == 0 ? Color.secondary : Color.green)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color.ccCardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.ccPanelBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusTitle: String {
        if model.requiresHookSetup {
            return localized(.statusSetupNeeded)
        }
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
        if model.requiresHookSetup {
            return localized(.detailHooksMissing)
        }
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
        if model.requiresHookSetup {
            return Color(red: 0.11, green: 0.44, blue: 0.91)
        }
        switch model.aggregateStatus {
        case .idle:
            return Color(red: 0.24, green: 0.27, blue: 0.33)
        case .running:
            return Color(red: 0.12, green: 0.62, blue: 0.35)
        case .waitingApproval:
            return Color(red: 0.77, green: 0.48, blue: 0.06)
        case .degraded:
            return Color(red: 0.83, green: 0.25, blue: 0.29)
        }
    }

    private var headerSubtitle: String {
        if model.monitoringPaused {
            return localized(.headerPaused)
        }
        if model.requiresHookSetup {
            return localized(.headerHooksMissing)
        }
        switch model.aggregateStatus {
        case .idle:
            return localized(.headerNoActiveSessions)
        case .running:
            return "\(model.store.sessions.count) \(localized(.headerSessionsAllClear))"
        case .waitingApproval:
            let waitingCount = model.store.sessions.filter { $0.status == .waitingApproval }.count
            return "\(model.store.sessions.count) \(localized(.sessionsTitle).lowercased()) · \(waitingCount) \(localized(.headerNeedsApproval))"
        case .degraded:
            return localized(.headerHooksSilent)
        }
    }

    private var sessionCountLabel: String {
        if model.monitoringPaused {
            return localized(.sessionCountPaused)
        }
        if model.requiresHookSetup {
            return localized(.sessionCountHooksMissing)
        }
        let count = model.store.sessions.count
        return count == 0 ? localized(.sessionCountNone) : "\(count) \(localized(.sessionCountActive))"
    }

    private var autoApprovalCopy: String {
        if model.autoApprovalEnabled {
            return String(
                format: localized(.autoApprovalOnDetail),
                model.autoApprovedToday,
                model.autoApprovedTotal
            )
        }
        return localized(.autoApprovalOffDetail)
    }

    private var autoApprovalLastAction: String {
        if model.autoApprovedTotal == 0 {
            return localized(.autoApprovalNoLastAction)
        }
        return localized(.autoApprovalLastAction)
    }

    private func sessionColor(_ status: SessionStatus) -> Color {
        switch status {
        case .running:
            return Color(red: 0.12, green: 0.62, blue: 0.35)
        case .waitingApproval:
            return Color(red: 0.77, green: 0.48, blue: 0.06)
        case .error, .stale:
            return Color(red: 0.83, green: 0.25, blue: 0.29)
        case .idle, .ended:
            return .secondary
        }
    }

    private func sourceColor(_ source: SessionSource) -> Color {
        switch source {
        case .vscode:
            return Color(red: 0.11, green: 0.44, blue: 0.91)
        case .cli:
            return Color(red: 0.24, green: 0.27, blue: 0.33)
        case .unknown:
            return .secondary
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

private extension Color {
    static let ccPopoverBackground = Color(red: 0.94, green: 0.95, blue: 0.94)
    static let ccCardBackground = Color(red: 0.98, green: 0.99, blue: 0.98)
    static let ccMutedPanelBackground = Color(red: 0.89, green: 0.90, blue: 0.89)
    static let ccSecondaryButtonBackground = Color(red: 0.86, green: 0.87, blue: 0.86)
    static let ccPanelBorder = Color(red: 0.74, green: 0.76, blue: 0.75)
    static let ccControlBorder = Color(red: 0.68, green: 0.70, blue: 0.69)
}

private struct SentinelMark: View {
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.88), lineWidth: 1.8)
                .frame(width: 21, height: 21)
            Path { path in
                path.move(to: CGPoint(x: 17, y: 10))
                path.addLine(to: CGPoint(x: 22, y: 5))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
        }
        .frame(width: 26, height: 26)
    }
}

private struct RadarMark: View {
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.28), lineWidth: 2)
                .frame(width: 44, height: 44)
            Circle()
                .stroke(color.opacity(0.28), lineWidth: 2)
                .frame(width: 22, height: 22)
            Path { path in
                path.move(to: CGPoint(x: 27, y: 27))
                path.addLine(to: CGPoint(x: 44, y: 12))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .frame(width: 54, height: 54)
    }
}

private struct CCActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(kind == .primary ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .frame(minHeight: 36)
            .background(background(configuration: configuration))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(kind == .primary ? Color.white.opacity(0.22) : Color.ccControlBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func background(configuration: Configuration) -> AnyShapeStyle {
        if kind == .primary {
            return AnyShapeStyle(
                Color(red: 0.11, green: 0.44, blue: 0.91)
                    .opacity(configuration.isPressed ? 0.82 : 1.0)
            )
        }
        return AnyShapeStyle(
            Color.ccSecondaryButtonBackground
                .opacity(configuration.isPressed ? 0.76 : 1.0)
        )
    }
}
