import Foundation

struct FileChange: Identifiable, Equatable {
    let id = UUID()
    let path: String
    var additions: Int
    var deletions: Int
    var isNew: Bool
    var lastTouched: Date

    var shortPath: String {
        let components = path.split(separator: "/")
        guard components.count > 3 else { return path }
        let first = components.first!
        let lastTwo = components.suffix(2).joined(separator: "/")
        return "\(first)/…/\(lastTwo)"
    }

    var totalChanges: Int { additions + deletions }

    static func == (lhs: FileChange, rhs: FileChange) -> Bool {
        lhs.path == rhs.path && lhs.additions == rhs.additions && lhs.deletions == rhs.deletions
    }
}

@MainActor
enum FileChangeExtractor {
    private static let writeTools: Set<String> = ["Write", "write_file", "write", "MultiEdit"]
    private static let editTools: Set<String> = ["Edit", "edit_file", "edit", "MultiEdit"]

    static func extract(from session: AgentSession) -> [FileChange] {
        var changesByPath: [String: FileChange] = [:]

        for record in session.toolHistory {
            guard let filePath = record.filePath else { continue }
            let isWrite = writeTools.contains(record.tool)
            let isEdit = editTools.contains(record.tool)
            guard isWrite || isEdit else { continue }

            if var existing = changesByPath[filePath] {
                existing.lastTouched = record.timestamp
                if isEdit {
                    existing.additions += 1
                    existing.deletions += 1
                }
                changesByPath[filePath] = existing
            } else {
                changesByPath[filePath] = FileChange(
                    path: filePath,
                    additions: isWrite ? 1 : 1,
                    deletions: isWrite ? 0 : 1,
                    isNew: isWrite && !changesByPath.keys.contains(filePath),
                    lastTouched: record.timestamp
                )
            }
        }

        if let diff = session.currentApproval?.diff {
            enrichFromDiff(diff, into: &changesByPath)
        }

        return changesByPath.values.sorted { $0.lastTouched > $1.lastTouched }
    }

    private static func enrichFromDiff(_ diff: AgentDiffContent, into changes: inout [String: FileChange]) {
        let additions = diff.hunks.flatMap(\.lines).filter { $0.type == .addition }.count
        let deletions = diff.hunks.flatMap(\.lines).filter { $0.type == .deletion }.count

        if var existing = changes[diff.filePath] {
            existing.additions = max(existing.additions, additions)
            existing.deletions = max(existing.deletions, deletions)
            changes[diff.filePath] = existing
        } else {
            changes[diff.filePath] = FileChange(
                path: diff.filePath,
                additions: additions,
                deletions: deletions,
                isNew: deletions == 0 && additions > 0,
                lastTouched: Date()
            )
        }
    }
}
