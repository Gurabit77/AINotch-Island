import Foundation

final class DebugLogWriter: Sendable {
    static let shared = DebugLogWriter(filename: "debug.log")
    static let conversation = DebugLogWriter(filename: "conversation-monitor.log")

    private let maxSize: UInt64 = 5 * 1024 * 1024
    private let logFile: String
    private let oldLogFile: String
    private let queue = DispatchQueue(label: "com.ayanami.agent-halo.logwriter")

    init(filename: String) {
        let basePath = NSHomeDirectory() + "/.agent-halo"
        logFile = basePath + "/\(filename)"
        oldLogFile = basePath + "/\(filename).old"
    }

    func append(_ msg: String) {
        guard let data = msg.data(using: .utf8) else { return }
        queue.async { [self] in
            rotateIfNeeded()
            let fm = FileManager.default
            if fm.fileExists(atPath: logFile) {
                if let fh = FileHandle(forWritingAtPath: logFile) {
                    fh.seekToEndOfFile()
                    fh.write(data)
                    fh.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFile))
            }
        }
    }

    private func rotateIfNeeded() {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: logFile),
              let size = attrs[.size] as? UInt64,
              size > maxSize else { return }
        try? fm.removeItem(atPath: oldLogFile)
        try? fm.moveItem(atPath: logFile, toPath: oldLogFile)
    }
}
