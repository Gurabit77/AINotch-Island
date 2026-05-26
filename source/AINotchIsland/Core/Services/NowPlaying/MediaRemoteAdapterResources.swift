import Foundation

struct MediaRemoteAdapterResources {
    let scriptURL: URL
    let frameworkURL: URL
    let testClientURL: URL?

    static func resolve(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) -> MediaRemoteAdapterResources? {
        let scriptDirectories = [
            bundle.resourceURL,
            bundle.resourceURL?.appendingPathComponent(resourceDirectoryName)
        ].compactMap { $0 }

        let frameworkDirectories = [
            bundle.privateFrameworksURL,
            bundle.resourceURL,
            bundle.resourceURL?.appendingPathComponent(resourceDirectoryName)
        ].compactMap { $0 }

        for scriptDirectoryURL in scriptDirectories {
            for frameworkDirectoryURL in frameworkDirectories {
                if let resources = makeResources(
                    scriptDirectoryURL: scriptDirectoryURL,
                    frameworkDirectoryURL: frameworkDirectoryURL,
                    fileManager: fileManager
                ) {
                    return resources
                }
            }
        }

        #if DEBUG
        // Dev-time fallback only: when running from Xcode without bundling
        // the resources, fall back to the source tree path. We gate this
        // on DEBUG so the embedded #filePath literal (which contains the
        // contributor's absolute build path) never ships in release
        // binaries.
        return makeResources(
            scriptDirectoryURL: sourceResourceDirectoryURL,
            frameworkDirectoryURL: sourceResourceDirectoryURL,
            fileManager: fileManager
        )
        #else
        return nil
        #endif
    }

    func invocationArguments(for commandArguments: [String]) -> [String] {
        var arguments = [
            scriptURL.path,
            frameworkURL.path
        ]

        if let testClientURL {
            arguments.append(testClientURL.path)
        }

        arguments.append(contentsOf: commandArguments)
        return arguments
    }
}

private extension MediaRemoteAdapterResources {
    static let resourceDirectoryName = "MediaRemoteAdapter"

    #if DEBUG
    static let sourceResourceDirectoryURL: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent(resourceDirectoryName)
    }()
    #endif

    static func makeResources(
        scriptDirectoryURL: URL,
        frameworkDirectoryURL: URL,
        fileManager: FileManager
    ) -> MediaRemoteAdapterResources? {
        let scriptURL = scriptDirectoryURL.appendingPathComponent("mediaremote-adapter.pl")
        let frameworkURL = frameworkDirectoryURL.appendingPathComponent("MediaRemoteAdapter.framework")
        let frameworkBinaryURL = frameworkURL.appendingPathComponent("MediaRemoteAdapter")
        let testClientURL = scriptDirectoryURL.appendingPathComponent("MediaRemoteAdapterTestClient")

        guard
            fileManager.fileExists(atPath: scriptURL.path),
            fileManager.fileExists(atPath: frameworkBinaryURL.path)
        else {
            return nil
        }

        return MediaRemoteAdapterResources(
            scriptURL: scriptURL,
            frameworkURL: frameworkURL,
            testClientURL: fileManager.fileExists(atPath: testClientURL.path) ? testClientURL : nil
        )
    }
}
