import SwiftUI
import Combine

@MainActor
final class KeyboardNavigationState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var isActive = false

    weak var viewModel: AgentHaloViewModel?

    var selectedSession: AgentSession? {
        guard let vm = viewModel else { return nil }
        let sessions = vm.state.visibleSessions
        guard isActive, selectedIndex >= 0, selectedIndex < sessions.count else { return nil }
        return sessions[selectedIndex]
    }

    func handleKey(_ event: NSEvent) -> Bool {
        guard isActive, let vm = viewModel else { return false }
        let sessions = vm.state.visibleSessions
        guard !sessions.isEmpty else { return false }

        switch event.charactersIgnoringModifiers {
        case "j": // down
            selectedIndex = min(selectedIndex + 1, sessions.count - 1)
            return true
        case "k": // up
            selectedIndex = max(selectedIndex - 1, 0)
            return true
        case "g": // jump to terminal
            if let session = selectedSession {
                _ = vm.jumpToTerminal(for: session)
            }
            return true
        case "a": // approve
            if let session = selectedSession, let approval = session.currentApproval {
                vm.respondToApproval(requestId: approval.id, action: .allow)
            }
            return true
        case "d": // deny
            if let session = selectedSession, let approval = session.currentApproval {
                vm.respondToApproval(requestId: approval.id, action: .deny)
            }
            return true
        case "x": // kill
            if let session = selectedSession {
                vm.killSession(session)
            }
            return true
        case "q", "\u{1B}": // escape - deactivate
            isActive = false
            return true
        default:
            if event.keyCode == 36 { // Enter - toggle detail (no-op for now, reserved)
                return true
            }
            return false
        }
    }

    func activate() {
        isActive = true
        selectedIndex = 0
    }

    func clampIndex(to count: Int) {
        if count == 0 {
            selectedIndex = 0
            isActive = false
        } else if selectedIndex >= count {
            selectedIndex = count - 1
        }
    }
}
