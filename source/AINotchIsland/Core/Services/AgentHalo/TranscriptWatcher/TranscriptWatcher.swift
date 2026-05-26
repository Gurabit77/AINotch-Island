import Foundation
import Combine

@MainActor
final class TranscriptWatcher: ObservableObject {
    private let state: AgentHaloState
    private let sources: [TranscriptSource]
    private var activeWatchers: [String: TranscriptFileWatcher] = [:]
    private var scanTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.ayanami.agent-halo.transcript", qos: .utility)
    // SessionIds whose attach has been *dispatched* (or completed). Kept in
    // sync with `activeWatchers` on main, but also consulted from the
    // background scan loop *before* dispatching, so that the same sessionId
    // is not enqueued multiple times in a single tick window. Without this
    // a directory with N transcript files produces N × (ticks per attach
    // round-trip) duplicate dispatches before main has a chance to update
    // `activeWatchers`.
    private let dispatchedLock = NSLock()
    private var dispatchedSessionIds: Set<String> = []

    init(state: AgentHaloState) {
        self.state = state
        self.sources = [
            CodexTranscriptSource(),
            HermesTranscriptSource(),
            CursorTranscriptSource(),
            AntigravityTranscriptSource(),
            VSCodeCopilotTranscriptSource(),
            OpenCodeTranscriptSource()
        ]
    }

    func start() {
        // The discovery pass needs *some* periodic check because the
        // filesystem doesn't give us "new file in directory" events on a
        // child level without per-directory FSEvent setup. Use a short
        // cadence so newly-created transcripts are picked up quickly, but
        // the actual session creation is event-driven (only when the
        // attached watcher reads new bytes appended after we attach).
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 2.0)
        timer.setEventHandler { [weak self] in
            self?.scanForNewSessions()
        }
        timer.resume()
        scanTimer = timer
        appendLog("started with \(sources.filter(\.isAvailable).count) available sources")
    }

    func stop() {
        scanTimer?.cancel()
        scanTimer = nil
        for (_, watcher) in activeWatchers {
            watcher.stop()
        }
        activeWatchers.removeAll()
        dispatchedLock.lock()
        dispatchedSessionIds.removeAll()
        dispatchedLock.unlock()
    }

    private func scanForNewSessions() {
        for source in sources where source.isAvailable {
            let transcripts = source.discoverActiveSessions()
            for transcript in transcripts {
                // Background-side guard: short-circuit before paying for
                // a main-queue dispatch when we already know we've handled
                // this sessionId. Main is still authoritative — see
                // attachWatcher's final check.
                dispatchedLock.lock()
                let alreadyDispatched = dispatchedSessionIds.contains(transcript.sessionId)
                if !alreadyDispatched {
                    dispatchedSessionIds.insert(transcript.sessionId)
                }
                dispatchedLock.unlock()
                if alreadyDispatched { continue }

                DispatchQueue.main.async { [weak self] in
                    self?.attachWatcher(transcript, source: source)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.dropDisappearedWatchers()
        }
    }

    private func attachWatcher(_ transcript: DiscoveredTranscript, source: TranscriptSource) {
        // If a hooked session already covers this id, skip — hooked is
        // authoritative, transcript would just duplicate.
        if state.sessions.contains(where: { $0.id == transcript.sessionId && $0.connectionType == .hooked }) {
            return
        }
        guard activeWatchers[transcript.sessionId] == nil else { return }

        let sessionId = transcript.sessionId
        let agentType = transcript.agentType
        let agentTitle = transcript.agentType.displayName

        let watcher = TranscriptFileWatcher(
            sessionId: sessionId,
            filePath: transcript.filePath,
            source: source,
            queue: queue,
            onEntries: { [weak self] entries in
                guard let self else { return }
                self.promoteIfNeeded(
                    sessionId: sessionId,
                    agentType: agentType,
                    title: agentTitle
                )
                self.handleEntries(entries, sessionId: sessionId)
            },
            onFileGone: { [weak self] in
                guard let self else { return }
                self.handleFileGone(sessionId: sessionId)
            }
        )
        activeWatchers[sessionId] = watcher
        watcher.start()
        appendLog("attached \(agentType.displayName) \(sessionId.prefix(24)) (pending)")
    }

    /// Session creation happens on the *first* real fs-event read, not on
    /// startup or a timer. This guarantees the agent is still actively
    /// writing — a finished agent whose jsonl just sits on disk never
    /// produces new bytes after we attach, so no session is created.
    private func promoteIfNeeded(sessionId: String, agentType: AgentType, title: String) {
        if state.sessions.contains(where: { $0.id == sessionId && $0.connectionType == .hooked }) {
            return
        }
        if state.sessions.contains(where: { $0.id == sessionId }) {
            return
        }
        let now = Date()
        let session = AgentSession(
            id: sessionId,
            agentType: agentType,
            status: .working,
            title: title,
            connectionType: .transcript,
            startedAt: now,
            lastUpdated: now
        )
        state.addSession(session)
        appendLog("promoted \(sessionId.prefix(12)) on first new bytes")
    }

    private func handleEntries(_ entries: [TranscriptEntry], sessionId: String) {
        guard let latest = entries.last else { return }
        var workingOn: String?
        if let tool = latest.toolName {
            workingOn = tool
        } else if latest.role == .assistant && !latest.text.isEmpty {
            workingOn = String(latest.text.prefix(100))
        } else if latest.role == .user {
            workingOn = "Processing: \(String(latest.text.prefix(80)))"
        }

        if let workingOn {
            state.updateSessionWorkingOn(id: sessionId, workingOn: workingOn)
        }
        state.touchSession(id: sessionId)
    }

    /// Triggered by the kernel via DispatchSourceFileSystemObject (.delete /
    /// .rename) the instant the transcript file disappears. End the session
    /// immediately — no polling, no timeout.
    private func handleFileGone(sessionId: String) {
        if let watcher = activeWatchers.removeValue(forKey: sessionId) {
            watcher.stop()
        }
        dispatchedLock.lock()
        dispatchedSessionIds.remove(sessionId)
        dispatchedLock.unlock()
        if state.sessions.contains(where: { $0.id == sessionId }) {
            state.updateSession(id: sessionId, status: .done)
            appendLog("file gone, ended \(sessionId.prefix(12))")
        }
    }

    /// Drop watchers whose underlying file no longer exists on disk. This is
    /// a belt-and-suspenders cleanup that catches the rare case where the
    /// kernel event was missed (e.g. moved across filesystems). It does NOT
    /// rely on any time-based heuristic.
    private func dropDisappearedWatchers() {
        for (sessionId, watcher) in activeWatchers {
            if !FileManager.default.fileExists(atPath: watcher.filePath) {
                watcher.stop()
                activeWatchers.removeValue(forKey: sessionId)
                dispatchedLock.lock()
                dispatchedSessionIds.remove(sessionId)
                dispatchedLock.unlock()
                if state.sessions.contains(where: { $0.id == sessionId && $0.connectionType == .transcript }) {
                    state.updateSession(id: sessionId, status: .done)
                    appendLog("file vanished, ended \(sessionId.prefix(12))")
                }
            }
        }
    }

    private nonisolated func appendLog(_ msg: String) {
        DebugLogWriter.shared.append("[TranscriptWatcher] \(msg)\n")
    }
}

// MARK: - File Watcher

final class TranscriptFileWatcher {
    let sessionId: String
    let filePath: String
    private let source: TranscriptSource
    private let queue: DispatchQueue
    private let onEntries: @MainActor ([TranscriptEntry]) -> Void
    private let onFileGone: @MainActor () -> Void

    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var lastOffset: UInt64 = 0
    private(set) var lastActivity: Date = Date()

    init(
        sessionId: String,
        filePath: String,
        source: TranscriptSource,
        queue: DispatchQueue,
        onEntries: @escaping @MainActor ([TranscriptEntry]) -> Void,
        onFileGone: @escaping @MainActor () -> Void
    ) {
        self.sessionId = sessionId
        self.filePath = filePath
        self.source = source
        self.queue = queue
        self.onEntries = onEntries
        self.onFileGone = onFileGone
    }

    func start() {
        queue.async { [weak self] in
            self?.openAndWatch()
        }
    }

    func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func openAndWatch() {
        fileDescriptor = open(filePath, O_RDONLY | O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        // Seek to EOF — we only care about content written *after* we attach.
        // This is what eliminates ghost sessions: a finished transcript that
        // is no longer being appended produces zero new entries, so the
        // session is never promoted.
        let fileSize = UInt64(lseek(fileDescriptor, 0, SEEK_END))
        lastOffset = fileSize

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            // .delete + .rename let us react instantly when the agent
            // tears down its transcript.
            eventMask: [.write, .extend, .attrib, .delete, .rename],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let mask = src.data
            if mask.contains(.delete) || mask.contains(.rename) {
                DispatchQueue.main.async {
                    self.onFileGone()
                }
                return
            }
            self.readNewContent()
        }
        src.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                Darwin.close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        src.resume()
        dispatchSource = src
    }

    private func readNewContent() {
        let entries = source.parseNewContent(at: filePath, from: lastOffset)
        if !entries.isEmpty {
            lastActivity = Date()
            if let attr = try? FileManager.default.attributesOfItem(atPath: filePath),
               let size = attr[.size] as? UInt64 {
                lastOffset = size
            }
            DispatchQueue.main.async { [weak self, entries] in
                guard let self else { return }
                self.onEntries(entries)
            }
        }
    }
}
