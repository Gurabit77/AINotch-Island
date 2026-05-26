import Foundation
import Combine

@MainActor
final class SystemLoadMonitor: ObservableObject {
    @Published private(set) var cpuUsage: Double = 0.0
    @Published private(set) var isHighLoad: Bool = false

    private var timer: AnyCancellable?

    func start() {
        timer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.sample()
            }
        sample()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func sample() {
        let usage = Self.readCPUUsage()
        cpuUsage = usage
        isHighLoad = usage > 80
    }

    private static func readCPUUsage() -> Double {
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &loadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(loadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2)
        let nice = Double(loadInfo.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return ((user + system + nice) / total) * 100
    }
}
