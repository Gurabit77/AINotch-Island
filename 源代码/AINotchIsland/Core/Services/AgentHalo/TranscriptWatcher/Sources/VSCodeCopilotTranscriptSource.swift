import Foundation

final class VSCodeCopilotTranscriptSource: TranscriptSource {
    let agentType: AgentType = .copilot
    private let basePath = NSHomeDirectory() + "/Library/Application Support/Code/User/workspaceStorage"

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: basePath)
    }

    func discoverActiveSessions() -> [DiscoveredTranscript] {
        let fm = FileManager.default
        guard let workspaces = try? fm.contentsOfDirectory(atPath: basePath) else { return [] }

        var results: [DiscoveredTranscript] = []
        for workspace in workspaces {
            let sessionDirs = [
                basePath + "/" + workspace + "/chatSessions",
                basePath + "/" + workspace + "/chatEditingSessions"
            ]

            for dir in sessionDirs {
                guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
                for file in files where file.hasSuffix(".json") {
                    let fullPath = dir + "/" + file
                    guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                          let modDate = attrs[.modificationDate] as? Date else { continue }
                    let sessionId = "vscode-" + file.replacingOccurrences(of: ".json", with: "")
                    results.append(DiscoveredTranscript(
                        sessionId: sessionId,
                        filePath: fullPath,
                        agentType: .copilot,
                        lastModified: modDate
                    ))
                }
            }
        }
        return results
    }

    func parseNewContent(at path: String, from offset: UInt64) -> [TranscriptEntry] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }

        let messages: [[String: Any]]
        if let msgs = json["messages"] as? [[String: Any]] {
            messages = msgs
        } else if let requests = json["requests"] as? [[String: Any]] {
            var allMsgs: [[String: Any]] = []
            for req in requests {
                if let msg = req["message"] as? [String: Any] {
                    allMsgs.append(msg)
                }
                if let resp = req["response"] as? [String: Any],
                   let respMsg = resp["message"] as? [String: Any] {
                    allMsgs.append(respMsg)
                }
            }
            messages = allMsgs
        } else {
            return []
        }

        var entries: [TranscriptEntry] = []
        for msg in messages.suffix(20) {
            guard let role = msg["role"] as? String else { continue }
            let content: String
            if let c = msg["content"] as? String {
                content = c
            } else if let parts = msg["content"] as? [[String: Any]] {
                content = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
            } else {
                continue
            }
            guard !content.isEmpty else { continue }

            let convRole: ConversationRole = (role == "user") ? .user : .assistant
            entries.append(TranscriptEntry(
                role: convRole,
                text: String(content.prefix(500)),
                toolName: nil,
                timestamp: Date()
            ))
        }
        return entries
    }
}
