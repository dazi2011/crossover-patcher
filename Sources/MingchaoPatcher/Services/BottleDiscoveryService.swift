import Foundation

struct BottleDiscoveryService {
    static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CrossOver/Bottles", isDirectory: true)
    }

    func allBottles(at root: URL = Self.defaultRoot) -> [BottleCandidate] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isDirectory == true,
                  values.isSymbolicLink != true,
                  values.isHidden != true,
                  url.lastPathComponent.caseInsensitiveCompare("default") != .orderedSame,
                  FileManager.default.fileExists(atPath: url.appendingPathComponent("system.reg").path)
            else { return nil }
            return BottleCandidate(name: url.lastPathComponent, url: url)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func similarBottles(at root: URL = Self.defaultRoot) -> [BottleCandidate] {
        allBottles(at: root).filter { BottleNameMatcher.isSimilarGameBottle($0.name) }
    }
}
