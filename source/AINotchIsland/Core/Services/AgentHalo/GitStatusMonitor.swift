import Foundation
import Combine

struct GitStatusInfo: Equatable {
    let branch: String
    let changedFiles: Int
    let stagedFiles: Int
    let untrackedFiles: Int
    let lastCommitMessage: String?
    let lastCommitTimeAgo: String?
    let isGitRepo: Bool
    let aheadCount: Int
    let behindCount: Int
    let hasRemote: Bool
    let stashCount: Int

    var totalChanges: Int { changedFiles + stagedFiles + untrackedFiles }
}

@MainActor
final class GitStatusMonitor: ObservableObject {
    @Published var statuses: [String: GitStatusInfo] = [:]

    private var timers: [String: Timer] = [:]
    private let queue = DispatchQueue(label: "com.ayanami.agent-halo.git", qos: .utility)

    deinit {
        timers.values.forEach { $0.invalidate() }
    }

    func startMonitoring(sessionId: String, directory: String) {
        stopMonitoring(sessionId: sessionId)
        fetchGitStatus(sessionId: sessionId, directory: directory)

        let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchGitStatus(sessionId: sessionId, directory: directory)
            }
        }
        timers[sessionId] = timer
    }

    func tryStartFromPID(sessionId: String, pid: Int32) {
        guard statuses[sessionId] == nil else { return }
        queue.async { [weak self] in
            guard let dir = Self.detectCWD(pid: pid) else { return }
            DispatchQueue.main.async {
                self?.startMonitoring(sessionId: sessionId, directory: dir)
            }
        }
    }

    func stopMonitoring(sessionId: String) {
        timers[sessionId]?.invalidate()
        timers.removeValue(forKey: sessionId)
    }

    private func fetchGitStatus(sessionId: String, directory: String) {
        queue.async { [weak self] in
            let info = Self.queryGit(directory: directory)
            DispatchQueue.main.async {
                self?.statuses[sessionId] = info
            }
        }
    }

    private nonisolated static func queryGit(directory: String) -> GitStatusInfo {
        let branch = runGit(["rev-parse", "--abbrev-ref", "HEAD"], in: directory) ?? ""
        guard !branch.isEmpty else {
            return GitStatusInfo(
                branch: "", changedFiles: 0, stagedFiles: 0, untrackedFiles: 0,
                lastCommitMessage: nil, lastCommitTimeAgo: nil, isGitRepo: false,
                aheadCount: 0, behindCount: 0, hasRemote: false, stashCount: 0
            )
        }

        let statusOutput = runGit(["status", "--porcelain"], in: directory) ?? ""
        let lines = statusOutput.split(separator: "\n")
        var changed = 0, staged = 0, untracked = 0
        for line in lines {
            guard line.count >= 2 else { continue }
            let x = line[line.startIndex]
            let y = line[line.index(after: line.startIndex)]
            if x == "?" { untracked += 1 }
            else {
                if x != " " && x != "?" { staged += 1 }
                if y != " " && y != "?" { changed += 1 }
            }
        }

        let commitMsg = runGit(["log", "-1", "--format=%s"], in: directory)
        let commitTime = runGit(["log", "-1", "--format=%ar"], in: directory)

        var ahead = 0, behind = 0, hasRemote = false
        if let abOutput = runGit(["rev-list", "--left-right", "--count", "@{upstream}...HEAD"], in: directory) {
            hasRemote = true
            let parts = abOutput.split(whereSeparator: { $0.isWhitespace })
            if parts.count == 2 {
                behind = Int(parts[0]) ?? 0
                ahead = Int(parts[1]) ?? 0
            }
        }

        var stashCount = 0
        if let stashOutput = runGit(["stash", "list"], in: directory), !stashOutput.isEmpty {
            stashCount = stashOutput.split(separator: "\n").count
        }

        return GitStatusInfo(
            branch: branch,
            changedFiles: changed,
            stagedFiles: staged,
            untrackedFiles: untracked,
            lastCommitMessage: commitMsg,
            lastCommitTimeAgo: commitTime,
            isGitRepo: true,
            aheadCount: ahead,
            behindCount: behind,
            hasRemote: hasRemote,
            stashCount: stashCount
        )
    }

    private nonisolated static func runGit(_ args: [String], in directory: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.environment = ["GIT_TERMINAL_PROMPT": "0"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Schedule a hard timeout — git can hang on stuck SSH /
            // network credential prompts even with GIT_TERMINAL_PROMPT=0,
            // and we don't want a single bad repo to wedge the monitor
            // for the rest of the session. 5s is plenty for any local
            // status/log command on a sane repo.
            let timeoutWork = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5, execute: timeoutWork)

            // Drain stdout BEFORE waitUntilExit. git log / git diff in a
            // big repo can produce > 64 KB which fills the pipe buffer; if
            // we wait first, the child blocks on write() forever and we
            // deadlock. Reading first lets the child make progress, and
            // EOF on the read implies the child has exited or closed
            // stdout, so the subsequent wait returns immediately.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            timeoutWork.cancel()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private nonisolated static func detectCWD(pid: Int32) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-p", "\(pid)", "-d", "cwd", "-Fn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let timeoutWork = DispatchWorkItem {
                if process.isRunning { process.terminate() }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3, execute: timeoutWork)
            // Same pipe-deadlock guard as runGit above: drain before wait.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            timeoutWork.cancel()
            guard process.terminationStatus == 0 else { return nil }
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            for line in output.split(separator: "\n") {
                if line.hasPrefix("n") && line.count > 1 {
                    let path = String(line.dropFirst())
                    if FileManager.default.fileExists(atPath: path) {
                        return path
                    }
                }
            }
        } catch {}
        return nil
    }
}
