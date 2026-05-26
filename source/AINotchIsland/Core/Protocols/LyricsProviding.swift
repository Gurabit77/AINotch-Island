
@MainActor
protocol LyricsProviding: AnyObject {
    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics?
}
