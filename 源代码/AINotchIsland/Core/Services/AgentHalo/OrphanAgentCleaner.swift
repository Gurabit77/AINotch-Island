import Foundation
import Combine

/// Daily background sweep that terminates "orphan" AI agent CLI processes —
/// instances whose owning terminal has long since closed but whose process
/// was adopted by launchd (ppid == 1) and is now silently consuming memory
/// and occasionally network sockets.
///
/// Mirrors the logic of `scripts/cleanup-orphan-agents.sh` so users can
/// run the same checks manually for diagnosis. Behavior:
///   • only kills processes with ppid == 1 (true orphans)
///   • only those at least `minimumAgeMinutes` old (default 60) — avoids
///     racing a freshly-started daemon
///   • skips known service-mode invocations (hermes gateway, mcp servers,
///     app-server, anything with --listen / --port / --daemon flags)
///   • two-stage termination: SIGTERM first, SIGKILL only for holdouts
///   • runs at most once per `runInterval` (default 24h) — persists last
///     run timestamp to UserDefaults
///
/// Trade-off: we deliberately do NOT enumerate every "claude" binary on
/// disk. The patterns mirror what the AgentRegistry recognizes, so if
/// the user added a new agent type to the registry they get coverage for
/// free; conversely an unknown CLI tool that happens to be named
/// "claude-something" won't be touched.
@MainActor
final class OrphanAgentCleaner {
    static let shared = OrphanAgentCleaner()

    private let runInterval: TimeInterval = 24 * 60 * 60
    private let minimumAgeSeconds: TimeInterval = 60 * 60
    private let lastRunKey = "com.ayanami.agentHalo.orphanCleanerLastRun"
    private var timer: Timer?

    // Patterns that identify a process as an AI agent CLI. Each entry is a
    // POSIX ERE evaluated against the full command line. Keep this in sync
    // with `scripts/cleanup-orphan-agents.sh` and the registry's
    // `processPatterns`.
    private let agentPatterns: [String] = [
        "\\bclaude\\b",
        "/claude($| )",
        "node .*/\\.npm-global/bin/claude",
        "\\bcodex\\b",
        "\\bmimo\\b",
        "node .*/\\.npm-global/bin/mimo",
        "hermes_cli",
        "/hermes($| )",
        "kiro-cli",
        "kiro_cli",
        "openclaw",
        "\\baider\\b",
        "\\bgemini\\b"
    ]

    // Substrings that disqualify a candidate even if its command matches a
    // pattern — bridges, IDE helpers, electron renderers, etc.
    private let excludeSubstrings: [String] = [
        "agent-halo-bridge", "AINotch Island",
        "Helper", "helper", "app-server", "extension-host",
        "Gemini Helper", "Cursor Helper", "Chrome", "Electron Framework",
        "tui.js", "kiro_cli_desktop", "sourcekit-lsp", "Sparkle"
    ]

    // Substrings that mark a process as an intentional long-running daemon
    // the user is still using (despite ppid == 1). Skipping these protects
    // hermes gateway, mcp servers, etc.
    private let serviceModeSubstrings: [String] = [
        "gateway run", "--listen stdio", "--listen tcp", "--port ",
        "--daemon", "app-server", "--replace"
    ]

    /// Start the daily timer. If the last run is older than `runInterval`
    /// (or never happened), executes immediately on launch.
    func start() {
        scheduleCheck()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.scheduleCheck() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Public entry for manual / diagnostic invocations. Returns the list
    /// of pids that were targeted.
    @discardableResult
    func runNow(force: Bool = false) -> [Int32] {
        return performSweep(force: force)
    }

    /// Inspect candidates without killing anything. Useful for a future
    /// settings UI that shows the user what would be cleaned.
    func dryRun() -> [OrphanCandidate] {
        return findOrphans()
    }

    // MARK: - Internals

    private func scheduleCheck() {
        let last = UserDefaults.standard.double(forKey: lastRunKey)
        let now = Date().timeIntervalSince1970
        guard now - last >= runInterval else { return }
        UserDefaults.standard.set(now, forKey: lastRunKey)

        // Defer to a background queue: scanning ps output and shelling out
        // to kill should not run on the main thread, and there's no UI
        // dependency for this work. Hop back to main only for the actual
        // mutation/logging since both APIs are main-actor isolated.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                _ = self.performSweep(force: true)
            }
        }
    }

    private func performSweep(force: Bool) -> [Int32] {
        let candidates = findOrphans()
        guard !candidates.isEmpty else {
            DebugLogWriter.shared.append("[OrphanCleaner] no orphans found\n")
            return []
        }

        let summary = candidates.map { "pid=\($0.pid) age=\(Int($0.ageSeconds))s cmd=\($0.command.prefix(80))" }.joined(separator: "; ")
        DebugLogWriter.shared.append("[OrphanCleaner] sweeping \(candidates.count): \(summary)\n")

        guard force else { return candidates.map(\.pid) }

        // SIGTERM all, sleep 3s, then SIGKILL anything still alive.
        for c in candidates { kill(c.pid, SIGTERM) }
        Thread.sleep(forTimeInterval: 3.0)
        var killed = 0
        for c in candidates {
            if kill(c.pid, 0) == 0 {
                kill(c.pid, SIGKILL)
            } else {
                killed += 1
            }
        }
        DebugLogWriter.shared.append("[OrphanCleaner] terminated \(killed)/\(candidates.count)\n")
        return candidates.map(\.pid)
    }

    private func findOrphans() -> [OrphanCandidate] {
        let snapshot = takeProcessSnapshot()
        var orphans: [OrphanCandidate] = []
        for info in snapshot {
            // Orphan filter: only launchd-adopted processes.
            guard info.ppid == 1 else { continue }

            // Agent pattern match.
            guard agentPatterns.contains(where: { pattern in
                info.command.range(of: pattern, options: .regularExpression) != nil
            }) else { continue }

            // Exclude bridges, helpers, etc.
            if excludeSubstrings.contains(where: { info.command.contains($0) }) {
                continue
            }

            // Skip service-mode daemons.
            if serviceModeSubstrings.contains(where: { info.command.contains($0) }) {
                continue
            }

            // Age threshold.
            guard info.ageSeconds >= minimumAgeSeconds else { continue }

            orphans.append(OrphanCandidate(
                pid: info.pid,
                ppid: info.ppid,
                command: info.command,
                ageSeconds: info.ageSeconds
            ))
        }
        return orphans
    }

    private struct PSEntry {
        let pid: Int32
        let ppid: Int32
        let ageSeconds: TimeInterval
        let command: String
    }

    /// One-shot ps invocation. Using `etime=` gives us [[dd-]hh:]mm:ss
    /// which we parse to seconds.
    private func takeProcessSnapshot() -> [PSEntry] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-eo", "pid=,ppid=,etime=,command="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var result: [PSEntry] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // pid ppid etime cmd…
            let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 4,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]) else { continue }
            let age = Self.parseEtime(String(parts[2]))
            result.append(PSEntry(pid: pid, ppid: ppid, ageSeconds: age, command: String(parts[3])))
        }
        return result
    }

    private static func parseEtime(_ raw: String) -> TimeInterval {
        // Forms: "ss", "mm:ss", "hh:mm:ss", "dd-hh:mm:ss"
        var s = raw
        var days: Int = 0
        if let dashIdx = s.firstIndex(of: "-") {
            days = Int(s[..<dashIdx]) ?? 0
            s = String(s[s.index(after: dashIdx)...])
        }
        let parts = s.split(separator: ":").map { Int($0) ?? 0 }
        var hours = 0, minutes = 0, seconds = 0
        switch parts.count {
        case 3: hours = parts[0]; minutes = parts[1]; seconds = parts[2]
        case 2: minutes = parts[0]; seconds = parts[1]
        case 1: seconds = parts[0]
        default: break
        }
        return TimeInterval(days * 86400 + hours * 3600 + minutes * 60 + seconds)
    }
}

struct OrphanCandidate: Identifiable {
    var id: Int32 { pid }
    let pid: Int32
    let ppid: Int32
    let command: String
    let ageSeconds: TimeInterval
}
