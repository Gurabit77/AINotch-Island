import Foundation
import Combine
import DiskArbitration

enum ExternalDriveEvent: Equatable {
    case connected(name: String)
    case ejected(name: String)
}

@MainActor
final class ExternalDriveMonitor: ObservableObject {
    @Published var event: ExternalDriveEvent?
    @Published private(set) var connectedDrives: [String] = []

    private var session: DASession?
    private var knownDisks: Set<String> = []

    func start() {
        guard let session = DASessionCreate(kCFAllocatorDefault) else { return }
        self.session = session
        DASessionSetDispatchQueue(session, DispatchQueue.global(qos: .utility))

        let ctx = Unmanaged.passUnretained(self).toOpaque()

        DARegisterDiskAppearedCallback(session, nil, { disk, context in
            guard let context else { return }
            let monitor = Unmanaged<ExternalDriveMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handleDiskAppeared(disk)
        }, ctx)

        DARegisterDiskDisappearedCallback(session, nil, { disk, context in
            guard let context else { return }
            let monitor = Unmanaged<ExternalDriveMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.handleDiskDisappeared(disk)
        }, ctx)
    }

    func stop() {
        session = nil
        knownDisks.removeAll()
    }

    private func handleDiskAppeared(_ disk: DADisk) {
        guard let desc = DADiskCopyDescription(disk) as? [String: Any],
              let proto = desc[kDADiskDescriptionDeviceProtocolKey as String] as? String,
              proto == "USB" || proto == "Thunderbolt",
              let name = desc[kDADiskDescriptionVolumeNameKey as String] as? String,
              !name.isEmpty else { return }

        let diskName = name
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.knownDisks.contains(diskName) else { return }
            self.knownDisks.insert(diskName)
            self.connectedDrives.append(diskName)
            self.event = .connected(name: diskName)
        }
    }

    private func handleDiskDisappeared(_ disk: DADisk) {
        guard let desc = DADiskCopyDescription(disk) as? [String: Any],
              let name = desc[kDADiskDescriptionVolumeNameKey as String] as? String,
              !name.isEmpty else { return }

        let diskName = name
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.knownDisks.remove(diskName)
            self.connectedDrives.removeAll { $0 == diskName }
            self.event = .ejected(name: diskName)
        }
    }
}
