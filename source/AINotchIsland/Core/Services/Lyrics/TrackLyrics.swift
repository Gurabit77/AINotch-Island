
import SwiftUI

struct TrackLyrics: Equatable, Sendable {
    let trackKey: String
    let lines: [LyricLine]
    let isSynced: Bool

    func activeLineIndex(at elapsedTime: TimeInterval) -> Int? {
        guard isSynced, lines.isEmpty == false else { return nil }

        let playbackPosition = elapsedTime + 0.18
        return lines.lastIndex { line in
            guard let startTime = line.startTime else { return false }
            return startTime <= playbackPosition
        } ?? 0
    }
}
