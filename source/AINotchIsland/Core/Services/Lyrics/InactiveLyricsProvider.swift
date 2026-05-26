
import Foundation

@MainActor
final class InactiveLyricsProvider: LyricsProviding {
    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics? {
        nil
    }
}
