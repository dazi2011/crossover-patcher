import Foundation

enum BottleNameMatcher {
    private static let aliases = [
        "鸣潮",
        "鳴潮",
        "wutheringwaves",
        "wuwa",
        "mingchao",
    ]

    static func normalized(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return folded.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) || $0.value > 0x7f }
            .map(String.init)
            .joined()
            .lowercased()
    }

    static func isSimilarGameBottle(_ name: String) -> Bool {
        let candidate = normalized(name)
        return aliases.contains { candidate.contains($0) }
    }

    static func canonicalPatchedName(for sourceName: String?, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if let sourceName {
            let normalizedSource = normalized(sourceName)
            if normalizedSource.contains("鸣潮") || normalizedSource.contains("鳴潮") {
                return "鸣潮-patched"
            }
            if aliases.dropFirst(2).contains(where: normalizedSource.contains) || normalizedSource.contains("wutheringwaves") {
                return "Wuthering Waves-patched"
            }
        }
        return preferredLanguages.first?.lowercased().hasPrefix("zh") == true
            ? "鸣潮-patched"
            : "Wuthering Waves-patched"
    }

    static func uniqueName(base: String, existingNames: [String]) -> String {
        let occupied = Set(existingNames.map(normalized))
        guard occupied.contains(normalized(base)) else { return base }
        var index = 2
        while occupied.contains(normalized("\(base)\(index)")) {
            index += 1
        }
        return "\(base)\(index)"
    }
}
