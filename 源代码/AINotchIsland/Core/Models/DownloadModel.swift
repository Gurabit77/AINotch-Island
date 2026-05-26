
import Foundation

struct DownloadModel: Equatable, Identifiable {
    let url: URL
    let displayName: String
    let directoryName: String
    let byteCount: Int64
    let estimatedTotalByteCount: Int64
    let progress: Double
    let startedAt: Date
    let lastUpdatedAt: Date
    let isTemporaryFile: Bool
    let bytesPerSecond: Int64

    var id: String {
        url.standardizedFileURL.path
    }
}
