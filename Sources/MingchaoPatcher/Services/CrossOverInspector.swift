import Foundation

struct CrossOverInspector {
    static let supportedBundleIdentifier = "com.codeweavers.CrossOver"

    private struct ShellProfile: Codable {
        let identifier: String
        let displayName: String
        let shortVersion: String
        let buildVersion: String
        let wineVersion: String?
        let executableName: String
        let requiredPaths: [String]
    }

    private static let fallbackProfiles = [
        ShellProfile(
            identifier: "preview-20260717-27.0.0.40734-singlefile",
            displayName: "CrossOver Preview 20260717",
            shortVersion: "20260717",
            buildVersion: "27.0.0.40734",
            wineVersion: "wine-11.12-8850-g4f57914690f",
            executableName: "CrossOver Preview",
            requiredPaths: [
                "Contents/SharedSupport/CrossOver/bin/cxbottle",
                "Contents/SharedSupport/CrossOver/lib/apple_gptk/external/D3DMetal.framework/Versions/A/D3DMetal",
            ]
        ),
        ShellProfile(
            identifier: "crossover-26.3-26.3.0.39832-singlefile",
            displayName: "CrossOver 26.3",
            shortVersion: "26.3",
            buildVersion: "26.3.0.39832",
            wineVersion: "wine-11.0-8726-g2e2f5fca349",
            executableName: "CrossOver",
            requiredPaths: [
                "Contents/SharedSupport/CrossOver/bin/cxbottle",
                "Contents/SharedSupport/CrossOver/lib64/apple_gptk/external/D3DMetal.framework/Versions/A/D3DMetal",
            ]
        ),
    ]

    private let profiles: [ShellProfile]

    init() {
        profiles = Self.loadBundledProfiles() ?? Self.fallbackProfiles
    }

    func inspect(_ rawURL: URL) -> CrossOverCandidate {
        let url = rawURL.standardizedFileURL
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        let plist = readPlist(plistURL)
        let shortVersion = plist?["CFBundleShortVersionString"] as? String
        let buildVersion = plist?["CFBundleVersion"] as? String
        let bundleIdentifier = plist?["CFBundleIdentifier"] as? String
        let executableName = plist?["CFBundleExecutable"] as? String

        let support: CrossOverCandidate.Support
        if url.pathExtension.lowercased() != "app" {
            support = .unsupported("请选择一个 .app 应用。")
        } else if bundleIdentifier != Self.supportedBundleIdentifier {
            support = .unsupported("不是官方 CrossOver 应用，或已被其他工具修改。")
        } else if let profile = profiles.first(where: {
            $0.shortVersion == shortVersion &&
                $0.buildVersion == buildVersion &&
                $0.executableName == executableName
        }) {
            if let missing = profile.requiredPaths.first(where: {
            !FileManager.default.fileExists(atPath: url.appendingPathComponent($0).path)
            }) {
                support = .unsupported("CrossOver 内容不完整：缺少 \(missing)。")
            } else {
                support = .supported(profileID: profile.identifier, displayName: profile.displayName)
            }
        } else {
            let versions = profiles.map { "\($0.shortVersion) / \($0.buildVersion)" }.joined(separator: "、")
            support = .unsupported("当前仅支持：\(versions)。")
        }

        return CrossOverCandidate(
            url: url,
            shortVersion: shortVersion,
            buildVersion: buildVersion,
            bundleIdentifier: bundleIdentifier,
            executableName: executableName,
            support: support
        )
    }

    private func readPlist(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return nil }
        return value as? [String: Any]
    }

    private static func loadBundledProfiles() -> [ShellProfile]? {
        let core = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/PatchCore")
        guard FileManager.default.isExecutableFile(atPath: core.path) else { return nil }
        let process = Process()
        let output = Pipe()
        process.executableURL = core
        process.arguments = ["list-profiles"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
        ]
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let decoded = try JSONDecoder().decode([ShellProfile].self, from: data)
            return decoded.isEmpty ? nil : decoded
        } catch {
            return nil
        }
    }
}
