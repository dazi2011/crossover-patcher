import Foundation

struct CrossOverCandidate: Equatable, Sendable {
    enum Support: Equatable, Sendable {
        case supported(profileID: String, displayName: String)
        case unsupported(String)
    }

    let url: URL
    let shortVersion: String?
    let buildVersion: String?
    let bundleIdentifier: String?
    let executableName: String?
    let support: Support

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var versionSummary: String {
        [shortVersion, buildVersion].compactMap { $0 }.joined(separator: " / ")
    }
}
