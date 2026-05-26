import Foundation

final class CursorTranscriptSource: TranscriptSource {
    let agentType: AgentType = .cursor
    private let basePath = NSHomeDirectory() + "/.cursor/projects"

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: basePath)
    }

    func discoverActiveSessions() -> [DiscoveredTranscript] {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(atPath: basePath) else { return [] }

        var results: [DiscoveredTranscript] = []
        for project in projects {
            let transcriptsDir = basePath + "/" + project + "/agent-transcripts"
            guard let files = try? fm.contentsOfDirectory(atPath: transcriptsDir) else { continue }

            for file in files where file.hasSuffix(".txt") {
                let fullPath = transcriptsDir + "/" + file
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }
                let sessionId = "cursor-" + file.replacingOccurrences(of: ".txt", with: "")
                results.append(DiscoveredTranscript(
                    sessionId: sessionId,
                    filePath: fullPath,
                    agentType: .cursor,
                    lastModified: modDate
                ))
            }
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
        let blocks = text.components(separatedBy: "\nuser:\n")

        for block in blocks where !block.isEmpty {
            let parts = block.components(separatedBy: "\nA:\n")
            if parts.count >= 1 {
                let userText = parts[0]
                    .replacingOccurrences(of: "<user_query>\n", with: "")
                    .replacingOccurrences(of: "\n</user_query>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !userText.isEmpty && userText != "user:" {
                    entries.append(TranscriptEntry(
                        role: .user,
                        text: String(userText.prefix(500)),
                        toolName: nil,
                        timestamp: Date()
                    ))
                }
            }
            if parts.count >= 2 {
                let assistantText = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !assistantText.isEmpty {
                    entries.append(TranscriptEntry(
                        role: .assistant,
                        text: String(assistantText.prefix(500)),
                        toolName: nil,
                        timestamp: Date()
                    ))
                }
            }
        }
        return entries
    }
}
