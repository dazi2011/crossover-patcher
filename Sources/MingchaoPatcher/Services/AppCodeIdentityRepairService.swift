import Foundation

struct CodeIdentityRepairResult: Equatable {
    let cdHash: String?
}

protocol AppCodeIdentityRepairing: AnyObject, Sendable {
    func repair(appURL: URL) throws -> CodeIdentityRepairResult
}

struct CodeIdentityCommandResult {
    let standardOutput: Data
    let standardError: Data

    var combinedText: String {
        String(decoding: standardOutput + standardError, as: UTF8.self)
    }
}

protocol CodeIdentityCommandRunning: AnyObject {
    func run(executable: URL, arguments: [String]) throws -> CodeIdentityCommandResult
}

struct CodeIdentityCommandError: LocalizedError {
    let executable: URL
    let status: Int32
    let detail: String

    var errorDescription: String? {
        let suffix = detail.isEmpty ? "没有附加错误信息。" : detail
        return "\(executable.lastPathComponent) 失败（退出码 \(status)）：\(suffix)"
    }
}

final class SystemCodeIdentityCommandRunner: CodeIdentityCommandRunning {
    func run(executable: URL, arguments: [String]) throws -> CodeIdentityCommandResult {
        let process = Process()
        let captureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("crossover-patcher-command-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: captureDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: captureDirectory) }

        let outputURL = captureDirectory.appendingPathComponent("stdout")
        let errorURL = captureDirectory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let standardOutput = try FileHandle(forWritingTo: outputURL)
        let standardError = try FileHandle(forWritingTo: errorURL)
        defer {
            try? standardOutput.close()
            try? standardError.close()
        }

        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()
        try standardOutput.close()
        try standardError.close()

        let outputData = try Data(contentsOf: outputURL)
        let errorData = try Data(contentsOf: errorURL)
        guard process.terminationStatus == 0 else {
            throw CodeIdentityCommandError(
                executable: executable,
                status: process.terminationStatus,
                detail: String(decoding: errorData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return CodeIdentityCommandResult(standardOutput: outputData, standardError: errorData)
    }
}

struct AppCodeIdentityRepairError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class AppCodeIdentityRepairService: AppCodeIdentityRepairing, @unchecked Sendable {
    static let nonceFileName = "CodeIdentityRepairNonce.txt"

    private let fileManager: FileManager
    private let commandRunner: CodeIdentityCommandRunning
    private let nonceProvider: () -> String
    private let codesignURL = URL(fileURLWithPath: "/usr/bin/codesign", isDirectory: false)

    init(
        fileManager: FileManager = .default,
        commandRunner: CodeIdentityCommandRunning = SystemCodeIdentityCommandRunner(),
        nonceProvider: @escaping () -> String = { UUID().uuidString }
    ) {
        self.fileManager = fileManager
        self.commandRunner = commandRunner
        self.nonceProvider = nonceProvider
    }

    func repair(appURL: URL) throws -> CodeIdentityRepairResult {
        let appURL = appURL.standardizedFileURL
        guard appURL.pathExtension.lowercased() == "app" else {
            throw AppCodeIdentityRepairError(message: "PatchCore 输出不是 App bundle，无法刷新代码身份。")
        }

        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist", isDirectory: false)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: infoPlistURL.path),
              fileManager.fileExists(atPath: resourcesURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw AppCodeIdentityRepairError(message: "PatchCore 输出缺少完整的 Contents/Resources 或 Info.plist。")
        }

        let entitlements = try commandRunner.run(
            executable: codesignURL,
            arguments: ["-d", "--entitlements", ":-", appURL.path]
        ).standardOutput
        guard !entitlements.isEmpty,
              (try? PropertyListSerialization.propertyList(from: entitlements, options: [], format: nil)) != nil else {
            throw AppCodeIdentityRepairError(message: "无法保留输出 App 的原 entitlement，已拒绝重新签名。")
        }

        let temporaryEntitlementsURL = fileManager.temporaryDirectory
            .appendingPathComponent("crossover-patcher-entitlements-\(UUID().uuidString).plist")
        try entitlements.write(to: temporaryEntitlementsURL, options: .atomic)
        defer { try? fileManager.removeItem(at: temporaryEntitlementsURL) }

        let nonceURL = resourcesURL.appendingPathComponent(Self.nonceFileName, isDirectory: false)
        let previousNonce = try? Data(contentsOf: nonceURL)
        let nonceData = Data("Code identity repair nonce: \(nonceProvider())\n".utf8)
        try nonceData.write(to: nonceURL, options: .atomic)

        do {
            try sign(appURL: appURL, entitlementsURL: temporaryEntitlementsURL)
            try verify(appURL: appURL)
        } catch {
            do {
                if let previousNonce {
                    try previousNonce.write(to: nonceURL, options: .atomic)
                } else if fileManager.fileExists(atPath: nonceURL.path) {
                    try fileManager.removeItem(at: nonceURL)
                }
                try sign(appURL: appURL, entitlementsURL: temporaryEntitlementsURL)
                try verify(appURL: appURL)
            } catch let rollbackError {
                throw AppCodeIdentityRepairError(
                    message: "刷新代码身份失败，恢复原签名也失败：\(rollbackError.localizedDescription)"
                )
            }
            throw error
        }

        let identity = try? commandRunner.run(
            executable: codesignURL,
            arguments: ["-dvvv", appURL.path]
        ).combinedText
        return CodeIdentityRepairResult(cdHash: identity.flatMap(Self.parseCDHash))
    }

    private func sign(appURL: URL, entitlementsURL: URL) throws {
        _ = try commandRunner.run(
            executable: codesignURL,
            arguments: [
                "--force",
                "--sign", "-",
                "--timestamp=none",
                "--entitlements", entitlementsURL.path,
                appURL.path,
            ]
        )
    }

    private func verify(appURL: URL) throws {
        _ = try commandRunner.run(
            executable: codesignURL,
            arguments: ["--verify", "--deep", "--strict", "--verbose=2", appURL.path]
        )
    }

    private static func parseCDHash(_ text: String) -> String? {
        text.split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("CDHash=") }
            .map { String($0.dropFirst("CDHash=".count)) }
    }
}
