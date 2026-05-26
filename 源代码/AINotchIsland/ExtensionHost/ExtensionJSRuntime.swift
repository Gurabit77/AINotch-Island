@preconcurrency import JavaScriptCore
import Foundation
import UserNotifications
import os.log

@MainActor
final class ExtensionJSRuntime {
    let context: JSContext
    let extensionId: String
    private weak var agentState: AgentHaloState?
    private var updateHandler: ((ViewNode) -> Void)?
    private var timerRefs: [Int: Timer] = [:]
    private var nextTimerId: Int = 1
    private var eventListeners: [String: [JSValue]] = [:]

    init(extensionId: String, agentState: AgentHaloState?) {
        self.extensionId = extensionId
        self.agentState = agentState
        self.context = JSContext()!
        setupConsole()
        setupTimers()
        setupAgentHaloAPI()
        setupSystemAPI()
        setupStorageAPI()
        setupNotificationsAPI()
        setupUIAPI()
    }

    func onViewUpdate(_ handler: @escaping (ViewNode) -> Void) {
        self.updateHandler = handler
    }

    func loadScript(at url: URL) throws {
        let source = try String(contentsOf: url, encoding: .utf8)
        context.evaluateScript(source)
        if let exception = context.exception {
            throw ExtensionRuntimeError.scriptError(exception.toString() ?? "Unknown error")
        }
    }

    func callRender() -> ViewNode? {
        guard let renderFn = context.objectForKeyedSubscript("render"),
              !renderFn.isUndefined else {
            return nil
        }
        let result = renderFn.call(withArguments: [])
        guard let result, !result.isUndefined, !result.isNull else { return nil }
        return ViewNodeParser.parse(result)
    }

    func callActivate() {
        if let fn = context.objectForKeyedSubscript("activate"), !fn.isUndefined {
            fn.call(withArguments: [])
        }
    }

    func callDeactivate() {
        if let fn = context.objectForKeyedSubscript("deactivate"), !fn.isUndefined {
            fn.call(withArguments: [])
        }
        timerRefs.values.forEach { $0.invalidate() }
        timerRefs.removeAll()
        eventListeners.removeAll()
    }

    func emitEvent(_ eventName: String, data: [String: Any] = [:]) {
        guard let listeners = eventListeners[eventName] else { return }
        let jsData = JSValue(object: data, in: context)
        for listener in listeners {
            listener.call(withArguments: [jsData as Any])
        }
        if let node = callRender() {
            updateHandler?(node)
        }
    }

    private func setupConsole() {
        let consoleLog: @convention(block) (String) -> Void = { message in
            AppLogger.extensions.info("[Extension:\(self.extensionId)] \(message)")
        }
        let console = JSValue(newObjectIn: context)!
        console.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        console.setObject(consoleLog, forKeyedSubscript: "warn" as NSString)
        console.setObject(consoleLog, forKeyedSubscript: "error" as NSString)
        context.setObject(console, forKeyedSubscript: "console" as NSString)
    }

    private func setupTimers() {
        let setInterval: @convention(block) (JSValue, Double) -> Int = { [weak self] callback, ms in
            guard let self else { return -1 }
            let id = self.nextTimerId
            self.nextTimerId += 1
            let timer = Timer.scheduledTimer(withTimeInterval: ms / 1000.0, repeats: true) { _ in
                Task { @MainActor in
                    callback.call(withArguments: [])
                    if let node = self.callRender() {
                        self.updateHandler?(node)
                    }
                }
            }
            self.timerRefs[id] = timer
            return id
        }

        let clearInterval: @convention(block) (Int) -> Void = { [weak self] id in
            self?.timerRefs[id]?.invalidate()
            self?.timerRefs.removeValue(forKey: id)
        }

        let setTimeout: @convention(block) (JSValue, Double) -> Int = { [weak self] callback, ms in
            guard let self else { return -1 }
            let id = self.nextTimerId
            self.nextTimerId += 1
            let timer = Timer.scheduledTimer(withTimeInterval: ms / 1000.0, repeats: false) { _ in
                Task { @MainActor in
                    callback.call(withArguments: [])
                    self.timerRefs.removeValue(forKey: id)
                    if let node = self.callRender() {
                        self.updateHandler?(node)
                    }
                }
            }
            self.timerRefs[id] = timer
            return id
        }

        context.setObject(setInterval, forKeyedSubscript: "setInterval" as NSString)
        context.setObject(clearInterval, forKeyedSubscript: "clearInterval" as NSString)
        context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)
        context.setObject(clearInterval, forKeyedSubscript: "clearTimeout" as NSString)
    }

    private func setupAgentHaloAPI() {
        let agentHalo = JSValue(newObjectIn: context)!

        // agents namespace
        let agents = JSValue(newObjectIn: context)!

        let getAgents: @convention(block) () -> [[String: Any]] = { [weak self] in
            guard let state = self?.agentState else { return [] }
            return state.sessions.map { session in
                [
                    "id": session.id,
                    "type": session.agentType.rawValue,
                    "status": session.status.rawValue,
                    "title": session.title,
                    "workingOn": session.workingOn ?? "",
                    "connectionType": session.connectionType.rawValue,
                ] as [String: Any]
            }
        }

        let getStatus: @convention(block) () -> String = { [weak self] in
            guard let state = self?.agentState else { return "idle" }
            switch state.globalStatus {
            case .idle: return "idle"
            case .working: return "working"
            case .waitingApproval: return "waiting"
            case .error: return "error"
            }
        }

        let getActiveCount: @convention(block) () -> Int = { [weak self] in
            self?.agentState?.activeCount ?? 0
        }

        agents.setObject(getAgents, forKeyedSubscript: "getAgents" as NSString)
        agents.setObject(getStatus, forKeyedSubscript: "getStatus" as NSString)
        agents.setObject(getActiveCount, forKeyedSubscript: "getActiveCount" as NSString)
        agentHalo.setObject(agents, forKeyedSubscript: "agents" as NSString)

        // sessions namespace
        let sessions = JSValue(newObjectIn: context)!

        let getAll: @convention(block) () -> [[String: Any]] = { [weak self] in
            guard let state = self?.agentState else { return [] }
            return state.sessions.map { s in
                [
                    "id": s.id,
                    "agentType": s.agentType.rawValue,
                    "status": s.status.rawValue,
                    "title": s.title,
                    "workingOn": s.workingOn ?? "",
                    "subAgentCount": s.subAgentCount,
                    "connectionType": s.connectionType.rawValue,
                    "startedAt": s.startedAt.timeIntervalSince1970,
                    "lastUpdated": s.lastUpdated.timeIntervalSince1970,
                ] as [String: Any]
            }
        }

        let getActive: @convention(block) () -> [[String: Any]] = { [weak self] in
            guard let state = self?.agentState else { return [] }
            return state.sessions.filter { $0.status != .done && $0.status != .idle }.map { s in
                [
                    "id": s.id,
                    "agentType": s.agentType.rawValue,
                    "status": s.status.rawValue,
                    "title": s.title,
                    "workingOn": s.workingOn ?? "",
                ] as [String: Any]
            }
        }

        sessions.setObject(getAll, forKeyedSubscript: "getAll" as NSString)
        sessions.setObject(getActive, forKeyedSubscript: "getActive" as NSString)
        agentHalo.setObject(sessions, forKeyedSubscript: "sessions" as NSString)

        // approvals namespace
        let approvals = JSValue(newObjectIn: context)!

        let getPending: @convention(block) () -> [[String: Any]] = { [weak self] in
            guard let state = self?.agentState else { return [] }
            return state.pendingApprovals.map { a in
                [
                    "id": a.id,
                    "sessionId": a.sessionId,
                    "title": a.title,
                    "description": a.description,
                    "riskLevel": a.riskLevel.rawValue,
                    "toolName": a.toolName ?? "",
                ] as [String: Any]
            }
        }

        approvals.setObject(getPending, forKeyedSubscript: "getPending" as NSString)
        agentHalo.setObject(approvals, forKeyedSubscript: "approvals" as NSString)

        // event subscription: AgentHalo.on(eventName, callback)
        let on: @convention(block) (String, JSValue) -> Void = { [weak self] eventName, callback in
            guard let self else { return }
            if self.eventListeners[eventName] == nil {
                self.eventListeners[eventName] = []
            }
            self.eventListeners[eventName]?.append(callback)
        }
        agentHalo.setObject(on, forKeyedSubscript: "on" as NSString)

        context.setObject(agentHalo, forKeyedSubscript: "AgentHalo" as NSString)
    }

    private func setupSystemAPI() {
        let system = JSValue(newObjectIn: context)!

        // battery
        let battery = JSValue(newObjectIn: context)!
        let batteryLevel: @convention(block) () -> Int = {
            Int(ProcessInfo.processInfo.thermalState.rawValue)
        }
        let isCharging: @convention(block) () -> Bool = { false }
        battery.setObject(batteryLevel, forKeyedSubscript: "level" as NSString)
        battery.setObject(isCharging, forKeyedSubscript: "isCharging" as NSString)
        system.setObject(battery, forKeyedSubscript: "battery" as NSString)

        // time
        let time = JSValue(newObjectIn: context)!
        let now: @convention(block) () -> Double = { Date().timeIntervalSince1970 }
        time.setObject(now, forKeyedSubscript: "now" as NSString)
        system.setObject(time, forKeyedSubscript: "time" as NSString)

        // platform
        let platform = JSValue(newObjectIn: context)!
        let osVersion: @convention(block) () -> String = { ProcessInfo.processInfo.operatingSystemVersionString }
        let hostName: @convention(block) () -> String = { ProcessInfo.processInfo.hostName }
        platform.setObject(osVersion, forKeyedSubscript: "osVersion" as NSString)
        platform.setObject(hostName, forKeyedSubscript: "hostName" as NSString)
        system.setObject(platform, forKeyedSubscript: "platform" as NSString)

        context.setObject(system, forKeyedSubscript: "System" as NSString)
    }

    private func setupStorageAPI() {
        let storage = JSValue(newObjectIn: context)!
        let prefix = "ext.\(extensionId)."

        let get: @convention(block) (String) -> Any? = { key in
            UserDefaults.standard.object(forKey: prefix + key)
        }

        let set: @convention(block) (String, Any) -> Void = { key, value in
            UserDefaults.standard.set(value, forKey: prefix + key)
        }

        let remove: @convention(block) (String) -> Void = { key in
            UserDefaults.standard.removeObject(forKey: prefix + key)
        }

        storage.setObject(get, forKeyedSubscript: "get" as NSString)
        storage.setObject(set, forKeyedSubscript: "set" as NSString)
        storage.setObject(remove, forKeyedSubscript: "remove" as NSString)

        context.setObject(storage, forKeyedSubscript: "Storage" as NSString)
    }

    private func setupNotificationsAPI() {
        let notifications = JSValue(newObjectIn: context)!

        let show: @convention(block) (String, String) -> Void = { title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }

        notifications.setObject(show, forKeyedSubscript: "show" as NSString)
        context.setObject(notifications, forKeyedSubscript: "Notifications" as NSString)
    }

    private func setupUIAPI() {
        let uiScript = """
        const UI = {
            text: function(content, style) { return { type: "text", content: String(content), style: style || {} }; },
            image: function(systemName, style) { return { type: "image", systemName: systemName, style: style || {} }; },
            hstack: function(children, options) { return { type: "hstack", children: children || [], spacing: options?.spacing, style: options?.style || {} }; },
            vstack: function(children, options) { return { type: "vstack", children: children || [], spacing: options?.spacing, style: options?.style || {} }; },
            zstack: function(children, style) { return { type: "zstack", children: children || [], style: style || {} }; },
            spacer: function(minLength) { return { type: "spacer", minLength: minLength }; },
            divider: function() { return { type: "divider" }; },
            progress: function(value, total, style) { return { type: "progress", value: value, total: total || 1, style: style || {} }; },
            capsule: function(child, style) { return { type: "capsule", child: child, style: style || {} }; },
        };
        """
        context.evaluateScript(uiScript)
    }
}

enum ExtensionRuntimeError: Error {
    case scriptError(String)
    case manifestNotFound
    case invalidManifest
    case entryNotFound
}
