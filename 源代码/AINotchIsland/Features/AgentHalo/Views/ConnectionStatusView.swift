import SwiftUI

struct ConnectionStatusView: View {
    var socketServer: AgentHaloSocketServer
    @ObservedObject var hookInstaller: HookInstaller

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            socketSection
            Divider()
            hookSection
            Divider()
            statsSection
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var socketSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.app("agent.connection.socketServer", fallback: "Socket Server"), systemImage: "network")
                .font(.system(size: 11, weight: .semibold))

            HStack(spacing: 6) {
                Circle()
                    .fill(socketServer.isListening ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(socketServer.isListening ? L10n.app("agent.connection.listening", fallback: "Listening") : L10n.app("agent.connection.notRunning", fallback: "Not running"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var hookSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.app("agent.connection.hooks", fallback: "Hooks"), systemImage: "link")
                .font(.system(size: 11, weight: .semibold))

            ForEach(Array(hookInstaller.hookStatus.sorted(by: { $0.key < $1.key })), id: \.key) { source, status in
                HStack(spacing: 6) {
                    Image(systemName: statusIcon(status))
                        .font(.system(size: 9))
                        .foregroundStyle(statusColor(status))
                    Text(source.capitalized)
                        .font(.system(size: 10))
                    Spacer()
                    Text(status.rawValue)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.app("agent.connection.stats", fallback: "Stats"), systemImage: "chart.bar")
                .font(.system(size: 11, weight: .semibold))

            HStack {
                Text(L10n.app("agent.connection.eventsReceived", fallback: "Events received:"))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(socketServer.totalEventsReceived)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }

            if let lastTime = socketServer.lastEventTime {
                HStack {
                    Text(L10n.app("agent.connection.lastEvent", fallback: "Last event:"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(lastTime, style: .relative)
                        .font(.system(size: 10, design: .monospaced))
                }
            }
        }
    }

    private func statusIcon(_ status: HookInstaller.HookStatus) -> String {
        switch status {
        case .installed: return "checkmark.circle.fill"
        case .notInstalled: return "xmark.circle"
        case .toolNotFound: return "questionmark.circle"
        case .error: return "exclamationmark.triangle"
        }
    }

    private func statusColor(_ status: HookInstaller.HookStatus) -> Color {
        switch status {
        case .installed: return .green
        case .notInstalled: return .orange
        case .toolNotFound: return .gray
        case .error: return .red
        }
    }
}
