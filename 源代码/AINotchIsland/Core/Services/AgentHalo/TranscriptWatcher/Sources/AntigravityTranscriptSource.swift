import Foundation

final class AntigravityTranscriptSource: TranscriptSource {
    let agentType: AgentType = .geminiCLI
    private let basePath = NSHomeDirectory() + "/.gemini/antigravity/conversations"

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: basePath)
    }

    func discoverActiveSessions() -> [DiscoveredTranscript] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: basePath) else { return [] }

        var results: [DiscoveredTranscript] = []
        for file in files where file.hasSuffix(".pb") {
            let fullPath = basePath + "/" + file
            guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                  let modDate = attrs[.modificationDate] as? Date else { continue }
            let sessionId = "antigravity-" + file.replacingOccurrences(of: ".pb", with: "")
            results.append(DiscoveredTranscript(
                sessionId: sessionId,
                filePath: fullPath,
                agentType: .geminiCLI,
                lastModified: modDate
            ))
        }
        return results
    }

    func parseNewContent(at path: String, from offset: UInt64) -> [TranscriptEntry] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return [] }
        let texts = extractUTF8Strings(from: data, minLength: 20)
        guard !texts.isEmpty else { return [] }

        var entries: [TranscriptEntry] = []
        for (index, text) in texts.suffix(10).enumerated() {
            let role: ConversationRole = (index % 2 == 0) ? .user : .assistant
            entries.append(TranscriptEntry(
                role: role,
                text: String(text.prefix(500)),
                toolName: nil,
                timestamp: Date()
            ))
        }
        return entries
    }

    private func extractUTF8Strings(from data: Data, minLength: Int) -> [String] {
        var strings: [String] = []
        var i = 0
        let bytes = [UInt8](data)
        let count = bytes.count

        while i < count {
            // Look for protobuf length-delimited field (wire type 2)
            let wireType = bytes[i] & 0x07
            if wireType == 2 {
                i += 1
                // Decode varint length
                var length: Int = 0
                var shift = 0
                while i < count {
                    let b = Int(bytes[i])
                    i += 1
                    length |= (b & 0x7F) << shift
                    shift += 7
                    if b & 0x80 == 0 { break }
                }

                if length >= minLength && length <= 10000 && i + length <= count {
                    let slice = Data(bytes[i..<(i + length)])
                    if let str = String(data: slice, encoding: .utf8),
                       str.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isWhitespace || $0.isNewline || $0.isCJKCharacter }) {
                        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.count >= minLength {
                            strings.append(trimmed)
                        }
                    }
                    i += length
                } else if length > 0 && i + length <= count {
                    i += length
                } else {
                    i += 1
                }
            } else {
                i += 1
            }
        }
        return strings
    }
}

private extension Character {
    var isCJKCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        let value = scalar.value
        return (0x4E00...0x9FFF).contains(value) ||
               (0x3400...0x4DBF).contains(value) ||
               (0x20000...0x2A6DF).contains(value) ||
               (0x3000...0x303F).contains(value) ||
               (0xFF00...0xFFEF).contains(value)
    }
}
