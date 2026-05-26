import SwiftUI

struct OnboardingNotchThirdStepView: View {
    @ObservedObject private var hookInstaller = HookInstaller.shared
    @State private var installed = false

    var body: some View {
        HStack {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
                .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.app("notch.onboarding.hookSetup", fallback: "Connect AI Agents"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !installed {
                    Text(L10n.app("notch.onboarding.hookSetupDesc", fallback: "Install hooks to monitor Claude Code, Codex, Cursor and Amp in real time."))
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(3)
                        .padding(.trailing)
                } else {
                    hookStatusList
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hookStatusList: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(hookInstaller.hookStatus.sorted(by: { $0.key < $1.key })), id: \.key) { source, status in
                HStack(spacing: 4) {
                    Circle()
                        .fill(dotColor(for: status))
                        .frame(width: 6, height: 6)
                    Text(source.capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(statusLabel(status))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func dotColor(for status: HookInstaller.HookStatus) -> Color {
        switch status {
        case .installed: return .green
        case .notInstalled: return .orange
        case .error: return .red
        case .toolNotFound: return .gray
        }
    }

    private func statusLabel(_ status: HookInstaller.HookStatus) -> String {
        switch status {
        case .installed: return L10n.app("hook.status.installed", fallback: "Connected")
        case .notInstalled: return L10n.app("hook.status.notInstalled", fallback: "Not installed")
        case .error: return L10n.app("hook.status.error", fallback: "Error")
        case .toolNotFound: return L10n.app("hook.status.notFound", fallback: "Not detected")
        }
    }

    func installHooks() {
        hookInstaller.installAll()
        installed = true
    }
}
