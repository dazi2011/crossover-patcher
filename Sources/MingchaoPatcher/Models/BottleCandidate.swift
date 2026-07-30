import Foundation

struct BottleCandidate: Identifiable, Equatable, Sendable {
    let name: String
    let url: URL

    var id: String { url.path }
}
