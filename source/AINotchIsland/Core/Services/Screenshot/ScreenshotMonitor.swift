import Foundation
import Combine

@MainActor
final class ScreenshotMonitor: ObservableObject {
    @Published var event: ScreenshotEvent?

    private var source: DispatchSourceFileSystemObject?
    private var lastScreenshotDate: Date = .distantPast

    func start() {
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let fd = open(desktopURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.checkForNewScreenshot(in: desktopURL)
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func checkForNewScreenshot(in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        let recentScreenshots = contents.filter { url in
            let name = url.lastPathComponent
            guard name.contains("Screenshot") || name.contains("截屏") || name.contains("Screen Shot") else {
                return false
            }
            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let created = attrs[.creationDate] as? Date else { return false }
            return now.timeIntervalSince(created) < 2
        }

        guard !recentScreenshots.isEmpty else { return }
        guard now.timeIntervalSince(lastScreenshotDate) > 2 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.lastScreenshotDate = now
            self?.event = .captured
        }
    }
}

enum ScreenshotEvent {
    case captured
}
