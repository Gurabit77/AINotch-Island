
import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let startTime: TimeInterval?
    let text: String
}
