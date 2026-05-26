import Foundation

final class CodexTranscriptSource: TranscriptSource {
    let agentType: AgentType = .codex
    private let basePath = NSHomeDirectory() + "/.codex/sessions"

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: basePath)
    }

    func discoverActiveSessions() -> [DiscoveredTranscript] {
        let fm = FileManager.default
        let cal = Calendar.current
        let now = Date()

        var results: [DiscoveredTranscript] = []
        for dayOffset in 0...1 {
            guard let date = cal.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let components = cal.dateComponents([.year, .month, .day], from: date)
            let dayDir = String(format: "%@/%04d/%02d/%02d", basePath, components.year!, components.month!, components.day!)
            guard let files = try? fm.contentsOfDirectory(atPath: dayDir) else { continue }

            for file in files where file.hasSuffix(".jsonl") {
                let fullPath = dayDir + "/" + file
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }
                let sessionId = "codex-" + file.replacingOccurrences(of: ".jsonl", with: "")
                results.append(DiscoveredTranscript(
                    sessionId: sessionId,
                    filePath: fullPath,
                    agentType: .codex,
                    lastModified: modDate
                ))
            }
        }
        return results
    }

    func parseNewContent(at path: String, from offset: UInt64) -> [TranscriptEntry] {
        guard let data = readFrom(path: path, offset: offset) else { return [] }
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var entries: [TranscriptEntry] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            let payload = json["payload"] as? [String: Any] ?? json
            let payloadType = payload["type"] as? String ?? ""
            let timestamp = parseTimestamp(json["timestamp"])

            switch type {
            case "event_msg":
                if payloadType == "user_message", let msg = payload["message"] as? String, !msg.isEmpty {
                    entries.append(TranscriptEntry(
                        role: .user,
                        text: String(msg.prefix(500)),
                        toolName: nil,
                        timestamp: timestamp
                    ))
                } else if payloadType == "agent_message", let msg = payload["message"] as? String, !msg.isEmpty {
                    entries.append(TranscriptEntry(
                        role: .assistant,
                        text: String(msg.prefix(500)),
                        toolName: nil,
                        timestamp: timestamp
                    ))
                }
            case "response_item":
                if let item = payload["item"] as? [String: Any],
                   let content = item["content"] as? [[String: Any]] {
                    for block in content {
                        if let blockType = block["type"] as? String {
                            if blockType == "text", let t = block["text"] as? String, !t.isEmpty {
                                entries.append(TranscriptEntry(
                                    role: .assistant,
                                    text: String(t.prefix(500)),
                                    toolName: nil,
                                    timestamp: timestamp
                                ))
                            } else if blockType == "tool_call" || blockType == "function_call" {
                                let name = block["name"] as? String ?? block["function"] as? String ?? "tool"
                                entries.append(TranscriptEntry(
                                    role: .assistant,
                                    text: name,
                                    toolName: name,
                                    timestamp: timestamp
                                ))
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        return entries
    }

    private func readFrom(path: String, offset: UInt64) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { handle.closeFile() }
        handle.seek(toFileOffset: offset)
        let data = handle.readDataToEndOfFile()
        return data.isEmpty ? nil : data
    }

    private func parseTimestamp(_ value: Any?) -> Date {
        if let str = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: str) ?? Date()
        }
        if let num = value as? TimeInterval {
            return Date(timeIntervalSince1970: num)
        }
        return Date()
    }
}
