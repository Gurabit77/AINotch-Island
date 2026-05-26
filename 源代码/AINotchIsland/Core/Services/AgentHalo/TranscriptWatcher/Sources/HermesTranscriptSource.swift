import Foundation

final class HermesTranscriptSource: TranscriptSource {
    let agentType: AgentType = .hermes
    private let basePath = NSHomeDirectory() + "/.hermes/sessions"

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: basePath)
    }

    func discoverActiveSessions() -> [DiscoveredTranscript] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: basePath) else { return [] }

        var results: [DiscoveredTranscript] = []
        for file in files where file.hasSuffix(".jsonl") {
            let fullPath = basePath + "/" + file
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                  let modDate = attrs[.modificationDate] as? Date else { continue }
            let sessionId = "hermes-" + file.replacingOccurrences(of: ".jsonl", with: "")
            results.append(DiscoveredTranscript(
                sessionId: sessionId,
                filePath: fullPath,
                agentType: .hermes,
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
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let role = json["role"] as? String else { continue }

            let timestamp: Date
            if let ts = json["timestamp"] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: ts)
            } else if let ts = json["timestamp"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                timestamp = formatter.date(from: ts) ?? Date()
            } else {
                timestamp = Date()
            }

            switch role {
            case "user":
                if let content = json["content"] as? String, !content.isEmpty {
                    entries.append(TranscriptEntry(
                        role: .user,
                        text: String(content.prefix(500)),
                        toolName: nil,
                        timestamp: timestamp
                    ))
                }
            case "assistant":
                let content = json["content"] as? String ?? ""
                let toolCalls = json["tool_calls"] as? [[String: Any]]
                if let calls = toolCalls, let first = calls.first {
                    let name = (first["function"] as? [String: Any])?["name"] as? String ?? "tool"
                    entries.append(TranscriptEntry(
                        role: .assistant,
                        text: name,
                        toolName: name,
                        timestamp: timestamp
                    ))
                } else if !content.isEmpty {
                    entries.append(TranscriptEntry(
                        role: .assistant,
                        text: String(content.prefix(500)),
                        toolName: nil,
                        timestamp: timestamp
                    ))
                }
            case "tool":
                break
            default:
                break
            }
        }
        return entries
    }
}
