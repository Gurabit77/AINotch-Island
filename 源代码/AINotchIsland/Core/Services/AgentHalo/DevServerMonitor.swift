import Foundation
import Combine

struct DevServerInfo: Identifiable, Equatable {
    let id: String
    let port: UInt16
    let name: String
    let url: String
}

@MainActor
final class DevServerMonitor: ObservableObject {
    @Published var servers: [DevServerInfo] = []

    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.ayanami.agent-halo.devserver", qos: .utility)

    deinit {
        timer?.invalidate()
    }

    private nonisolated static let commonPorts: [UInt16] = [
        3000, 3001, 3030, 4000, 4200, 4321, 5000, 5173, 5174, 5175,
        5500, 5555, 8000, 8080, 8081, 8088, 8888, 9000, 9090, 1234
    ]

    private nonisolated static let portNames: [UInt16: String] = [
        3000: "Next.js / Express",
        3001: "React Dev",
        4200: "Angular",
        4321: "Astro",
        5173: "Vite",
        5174: "Vite",
        5175: "Vite",
        5500: "Live Server",
        8000: "Python / Django",
        8080: "HTTP Server",
        8081: "Metro / React Native",
        8888: "Jupyter",
        9000: "PHP / Webpack",
        1234: "Parcel",
    ]

    func start() {
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scan() {
        queue.async { [weak self] in
            let found = Self.detectServers()
            DispatchQueue.main.async {
                self?.servers = found
            }
        }
    }

    private nonisolated static func detectServers() -> [DevServerInfo] {
        var results: [DevServerInfo] = []

        for port in commonPorts {
            if isPortOpen(port) {
                let name = portNames[port] ?? "Dev Server"
                results.append(DevServerInfo(
                    id: "localhost:\(port)",
                    port: port,
                    name: name,
                    url: "http://127.0.0.1:\(port)"
                ))
            }
        }

        return results
    }

    private nonisolated static func isPortOpen(_ port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        var timeout = timeval(tv_sec: 0, tv_usec: 100000)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        return result == 0
    }
}
