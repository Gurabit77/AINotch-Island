import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    var isEnabled = true

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notify(title: String, body: String, category: NotificationCategory, sessionId: String? = nil) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        if let sessionId { content.userInfo["sessionId"] = sessionId }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func notifyApproval(_ approval: AgentApprovalRequest, agentName: String) {
        notify(
            title: "⚠️ \(agentName) needs approval",
            body: approval.title,
            category: .approval,
            sessionId: approval.sessionId
        )
    }

    func notifyTaskComplete(session: AgentSession) {
        notify(
            title: "✅ \(session.agentType.displayName) finished",
            body: session.title,
            category: .taskComplete,
            sessionId: session.id
        )
    }

    func notifyError(session: AgentSession, message: String) {
        notify(
            title: "❌ \(session.agentType.displayName) error",
            body: message,
            category: .error,
            sessionId: session.id
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Clicking notification expands the notch panel
        await MainActor.run {
            NotificationCenter.default.post(name: .agentHaloExpandRequested, object: nil)
        }
    }
}

enum NotificationCategory: String {
    case approval = "AGENT_APPROVAL"
    case taskComplete = "AGENT_TASK_COMPLETE"
    case error = "AGENT_ERROR"
}

extension Notification.Name {
    static let agentHaloExpandRequested = Notification.Name("agentHaloExpandRequested")
}
