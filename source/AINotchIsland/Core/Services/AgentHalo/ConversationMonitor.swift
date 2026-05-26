import Foundation
import Combine

@MainActor
final class ConversationMonitor: ObservableObject {
    @Published var conversations: [String: SessionConversation] = [:]

    private var watchers: [String: SessionFileWatcher] = [:]
    private let queue = DispatchQueue(label: "com.ayanami.agent-halo.conversation", qos: .utility)
    private let claudeProjectsPath = NSHomeDirectory() + "/.claude/projects"
    static let maxMessages = 20
    static let maxTextLength = 500

    func startMonitoring(sessionId: String) {
        guard watchers[sessionId] == nil else { return }

        appendLog("startMonitoring: \(sessionId)")
        conversations[sessionId] = SessionConversation(isMonitoring: false)

        // Look for the jsonl asynchronously, with bounded retries scheduled
        // back onto the queue between attempts (not Thread.sleep, which
        // would block every other utility-queue task — transcript watcher,
        // git monitor, etc — for the full 5-second window when the file
        // doesn't exist yet).
        attemptLocateJSONL(sessionId: sessionId, retriesLeft: 5)
    }

    private func attemptLocateJSONL(sessionId: String, retriesLeft: Int) {
        queue.async { [weak self] in
            guard let self else { return }
            if let filePath = self.findJSONLFileOnce(sessionId: sessionId) {
                DispatchQueue.main.async {
                    // If monitoring was cancelled in the meantime, skip.
                    guard self.conversations[sessionId] != nil,
                          self.watchers[sessionId] == nil else { return }
                    self.appendLog("JSONL found: \(filePath)")
                    self.startFileWatcher(sessionId: sessionId, filePath: filePath)
                }
                return
            }

            if retriesLeft <= 0 {
                DispatchQueue.main.async {
                    self.appendLog("JSONL not found for \(sessionId)")
                    self.conversations[sessionId]?.isMonitoring = false
                }
                return
            }

            // Re-enqueue a retry after 1s without blocking the queue.
            self.queue.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.attemptLocateJSONL(sessionId: sessionId, retriesLeft: retriesLeft - 1)
            }
        }
    }

    func stopMonitoring(sessionId: String) {
        watchers[sessionId]?.stop()
        watchers.removeValue(forKey: sessionId)
    }

    private nonisolated func findJSONLFileOnce(sessionId: String) -> String? {
        let fm = FileManager.default
        let fileName = sessionId + ".jsonl"
        guard let dirs = try? fm.contentsOfDirectory(atPath: claudeProjectsPath) else {
            return nil
        }
        for dir in dirs {
            let candidate = claudeProjectsPath + "/" + dir + "/" + fileName
            if fm.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private func startFileWatcher(sessionId: String, filePath: String) {
        let watcher = SessionFileWatcher(
            sessionId: sessionId,
            filePath: filePath,
            queue: queue
        ) { [weak self] messages in
            guard let self else { return }
            self.handleNewMessages(sessionId: sessionId, messages: messages)
        }
        watchers[sessionId] = watcher
        conversations[sessionId]?.isMonitoring = true
        watcher.start()
    }

    private func handleNewMessages(sessionId: String, messages: [ConversationMessage]) {
        guard !messages.isEmpty else { return }
        appendLog("handleNewMessages: \(sessionId) count=\(messages.count)")

        var conversation = conversations[sessionId] ?? SessionConversation(isMonitoring: true)

        for msg in messages {
            if conversation.messages.contains(where: { $0.id == msg.id }) { continue }
            conversation.messages.append(msg)

            switch msg.role {
            case .user:
                conversation.lastUserPrompt = msg.text
            case .assistant:
                if let tool = msg.toolName {
                    conversation.currentToolUse = tool
                } else if !msg.text.isEmpty {
                    conversation.lastAssistantText = msg.text
                    conversation.currentToolUse = nil
                }
            }
        }

        if conversation.messages.count > Self.maxMessages {
            conversation.messages = Array(conversation.messages.suffix(Self.maxMessages))
        }

        conversations[sessionId] = conversation
        appendLog("conversation \(sessionId): \(conversation.messages.count) msgs, monitoring=\(conversation.isMonitoring)")
    }

    private nonisolated func appendLog(_ msg: String) {
        DebugLogWriter.conversation.append("[ConvMon] \(Date()) \(msg)\n")
    }
}

// MARK: - File Watcher

private final class SessionFileWatcher {
    let sessionId: String
    let filePath: String
    let queue: DispatchQueue
    let onMessages: @MainActor ([ConversationMessage]) -> Void

    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var lastOffset: UInt64 = 0

    init(
        sessionId: String,
        filePath: String,
        queue: DispatchQueue,
        onMessages: @escaping @MainActor ([ConversationMessage]) -> Void
    ) {
        self.sessionId = sessionId
        self.filePath = filePath
        self.queue = queue
        self.onMessages = onMessages
    }

    func start() {
        queue.async { [weak self] in
            self?.openAndWatch()
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func openAndWatch() {
        fileDescriptor = open(filePath, O_RDONLY | O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        // Seek to end, only read new content
        lastOffset = UInt64(lseek(fileDescriptor, 0, SEEK_END))

        // But first do an initial read of the last few messages for context
        readTailMessages()

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.readNewContent()
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                Darwin.close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source.resume()
        self.source = source
    }

    private func readTailMessages() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return }
        guard let text = String(data: data, encoding: .utf8) else { return }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        let recentLines = lines.suffix(50)

        var messages: [ConversationMessage] = []
        for line in recentLines {
            if let msg = parseLine(String(line)) {
                messages.append(msg)
            }
        }

        let recent = Array(messages.suffix(ConversationMonitor.maxMessages))
        if !recent.isEmpty {
            DispatchQueue.main.async { [weak self, recent] in
                guard let self else { return }
                self.onMessages(recent)
            }
        }
    }

    private func readNewContent() {
        let readFd = open(filePath, O_RDONLY)
        guard readFd >= 0 else { return }
        defer { Darwin.close(readFd) }

        lseek(readFd, off_t(lastOffset), SEEK_SET)

        var buffer = [UInt8](repeating: 0, count: 65536)
        var allNewData = Data()

        while true {
            let bytesRead = read(readFd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            allNewData.append(Data(bytes: buffer, count: bytesRead))
        }

        guard !allNewData.isEmpty else { return }
        lastOffset += UInt64(allNewData.count)

        guard let text = String(data: allNewData, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        var messages: [ConversationMessage] = []
        for line in lines {
            if let msg = parseLine(String(line)) {
                messages.append(msg)
            }
        }

        if !messages.isEmpty {
            DispatchQueue.main.async { [weak self, messages] in
                guard let self else { return }
                self.onMessages(messages)
            }
        }
    }

    private func parseLine(_ line: String) -> ConversationMessage? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let type = json["type"] as? String,
              (type == "user" || type == "assistant") else {
            return nil
        }

        guard let uuid = json["uuid"] as? String,
              let message = json["message"] as? [String: Any],
              let content = message["content"] else {
            return nil
        }

        let role: ConversationRole = type == "user" ? .user : .assistant
        let timestamp: Date
        if let ts = json["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            timestamp = formatter.date(from: ts) ?? Date()
        } else {
            timestamp = Date()
        }

        var text = ""
        var toolName: String?

        if let contentArray = content as? [[String: Any]] {
            for item in contentArray {
                guard let itemType = item["type"] as? String else { continue }
                switch itemType {
                case "text":
                    if let t = item["text"] as? String {
                        if !t.isEmpty && !t.hasPrefix("[System:") {
                            text = String(t.prefix(ConversationMonitor.maxTextLength))
                        }
                    }
                case "tool_use":
                    toolName = item["name"] as? String
                    if text.isEmpty, let name = toolName {
                        text = name
                    }
                case "tool_result":
                    break
                default:
                    break
                }
            }
        } else if let contentStr = content as? String {
            text = String(contentStr.prefix(ConversationMonitor.maxTextLength))
        }

        guard !text.isEmpty || toolName != nil else { return nil }

        return ConversationMessage(
            id: uuid,
            role: role,
            text: text,
            timestamp: timestamp,
            toolName: toolName
        )
    }
}
