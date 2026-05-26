
import SwiftUI

struct NowPlayingMinimalNotchView: View {
    @Environment(\.notchScale) var scale
    @ObservedObject var nowPlayingViewModel: NowPlayingViewModel
    @ObservedObject var settings: MediaAndFilesSettingsStore
    
    private var resolvedSnapshot: NowPlayingSnapshot {
        nowPlayingViewModel.snapshot ?? NowPlayingSnapshot(
            title: L10n.app("notch.nowPlaying.nothingPlaying", fallback: "Nothing Playing"),
            artist: "",
            album: "",
            duration: 0,
            elapsedTime: 0,
            playbackRate: 0,
            artworkData: nil,
            refreshedAt: .now
        )
    }
    
    var body: some View {
        let snapshot = resolvedSnapshot

        timelineContent(snapshot: snapshot)
    }

    private func timelineContent(snapshot: NowPlayingSnapshot) -> some View {
        HStack {
            CrabReactionView(scene: .listeningMusic, pixelSize: 2.5)
                .scaleEffect(0.7)
            ArtworkView(
                nowPlayingViewModel: nowPlayingViewModel,
                width: 24,
                height: 24,
                cornerRadius: 5,
                usesFlipAnimation: settings.isNowPlayingArtwork3DEffectEnabled
            )
            Spacer()
            LightweightNowPlayingEqualizerView(
                isPlaying: snapshot.isPlaying,
                color: nowPlayingViewModel.artworkPalette.equalizerBaseColor
            )
            .frame(width: 18, height: 16)
        }
        .padding(.horizontal, 14.scaled(by: scale))
    }
}
