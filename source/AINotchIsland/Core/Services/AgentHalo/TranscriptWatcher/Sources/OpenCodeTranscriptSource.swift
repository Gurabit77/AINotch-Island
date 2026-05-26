import Foundation

final class OpenCodeTranscriptSource: TranscriptSource {
    let agentType: AgentType = .openCode
    private let basePath = NSHomeDirectory() + "/.opencode/sessions"

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: basePath)
    }

    func discoverActiveSessions() -> [DiscoveredTranscript] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: basePath) else { return [] }

        var results: [DiscoveredTranscript] = []
        for file in files where file.hasSuffix(".jsonl") || file.hasSuffix(".json") {
            let fullPath = basePath + "/" + file
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                  let modDate = attrs[.modificationDate] as? Date else { continue }
            let sessionId = "opencode-" + file
                .replacingOccurrences(of: ".jsonl", with: "")
                .replacingOccurrences(of: ".json", with: "")
            results.append(DiscoveredTranscript(
                sessionId: sessionId,
                filePath: fullPath,
                agentType: .openCode,
                lastModified: modDate
            ))
        }
        return results
    }

    func parseNewContent(at path: String, from offset: UInt64) -> [TranscriptEntry] {
        guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
        defer { handle.closeFile() }
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return [] }

        var entries: [TranscriptEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let role = json["role"] as? String ?? json["type"] as? String ?? ""
            let content = json["content"] as? String ?? json["message"] as? String ?? ""
            guard !content.isEmpty else { continue }

            let timestamp: Date
            if let ts = json["timestamp"] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: ts)
            } else {
                timestamp = Date()
            }

            switch role {
            case "user", "human":
                entries.append(TranscriptEntry(
                    role: .user,
                    text: String(content.prefix(500)),
                    toolName: nil,
                    timestamp: timestamp
                ))
            case "assistant", "ai", "model":
                let toolCalls = json["tool_calls"] as? [[String: Any]]
                let toolName = toolCalls?.first.flatMap { ($0["function"] as? [String: Any])?["name"] as? String }
                entries.append(TranscriptEntry(
                    role: .assistant,
                    text: String(content.prefix(500)),
                    toolName: toolName,
                    timestamp: timestamp
                ))
            default:
                break
            }
        }
        return entries
    }
}
