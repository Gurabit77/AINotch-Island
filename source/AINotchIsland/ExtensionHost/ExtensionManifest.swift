import Foundation

struct ExtensionManifest: Codable, Identifiable {
    let id: String
    let name: String
    let version: String
    let description: String
    let author: String?
    let entry: String
    let icon: String?
    let permissions: [ExtensionPermission]?
    let notchConfig: ExtensionNotchConfig?
    let autoActivate: Bool?
    let events: [String]?
    let updateInterval: Double?

    struct ExtensionNotchConfig: Codable {
        let compactWidth: CGFloat?
        let expandedWidth: CGFloat?
        let expandedHeight: CGFloat?
        let expandable: Bool?
        let strokeColor: String?
    }
}

enum ExtensionPermission: String, Codable {
    case agents = "agents"
    case system = "system"
    case network = "network"
    case notifications = "notifications"
    case storage = "storage"
}

struct LoadedExtension: Identifiable {
    let id: String
    let manifest: ExtensionManifest
    let bundlePath: URL
    var isActive: Bool = false
}
