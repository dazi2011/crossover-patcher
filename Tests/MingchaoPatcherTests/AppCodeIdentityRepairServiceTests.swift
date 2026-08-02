import Foundation
import XCTest
@testable import MingchaoPatcher

final class AppCodeIdentityRepairServiceTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeIdentityRepairTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    func testWritesNonceResignsTopLevelAndDeepVerifies() throws {
        let app = try makeApp()
        let sentinel = app.appendingPathComponent("Contents/SharedSupport/runtime.bin")
        let sentinelBefore = try Data(contentsOf: sentinel)
        let runner = FakeCodeIdentityCommandRunner()
        runner.identityText = "Identifier=dev.crossover-patcher.test\nCDHash=0123456789abcdef\n"
        let service = AppCodeIdentityRepairService(
            commandRunner: runner,
            nonceProvider: { "fixed-nonce" }
        )

        let result = try service.repair(appURL: app)

        XCTAssertEqual(result.cdHash, "0123456789abcdef")
        XCTAssertEqual(
            try String(contentsOf: app.appendingPathComponent("Contents/Resources/CodeIdentityRepairNonce.txt")),
            "Code identity repair nonce: fixed-nonce\n"
        )
        XCTAssertEqual(try Data(contentsOf: sentinel), sentinelBefore)

        let sign = try XCTUnwrap(runner.arguments.first { $0.contains("--force") })
        XCTAssertFalse(sign.contains("--deep"), "nested framework signatures must remain untouched")
        XCTAssertTrue(sign.contains("--entitlements"))
        XCTAssertEqual(runner.entitlementsSeenDuringSigning.count, 1)

        let verify = try XCTUnwrap(runner.arguments.first { $0.contains("--verify") })
        XCTAssertTrue(verify.contains("--deep"))
        XCTAssertTrue(verify.contains("--strict"))
    }

    func testSigningFailureRestoresPreviousNonceAndCodeIdentity() throws {
        let app = try makeApp()
        let nonce = app.appendingPathComponent("Contents/Resources/CodeIdentityRepairNonce.txt")
        try Data("previous nonce\n".utf8).write(to: nonce)
        let runner = FakeCodeIdentityCommandRunner()
        runner.signFailuresRemaining = 1
        let service = AppCodeIdentityRepairService(
            commandRunner: runner,
            nonceProvider: { "replacement" }
        )

        XCTAssertThrowsError(try service.repair(appURL: app))
        XCTAssertEqual(try String(contentsOf: nonce), "previous nonce\n")
        XCTAssertEqual(runner.arguments.filter { $0.contains("--force") }.count, 2)
        XCTAssertEqual(runner.arguments.filter { $0.contains("--verify") }.count, 1)
    }

    func testRealCodesignChangesOnlyBundleIdentity() throws {
        let app = try makeApp()
        let executable = app.appendingPathComponent("Contents/MacOS/TestHost")
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: executable)
        let plist: [String: Any] = [
            "CFBundleExecutable": "TestHost",
            "CFBundleIdentifier": "dev.crossover-patcher.identity-test",
            "CFBundlePackageType": "APPL",
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: app.appendingPathComponent("Contents/Info.plist"), options: .atomic)

        let entitlements = root.appendingPathComponent("entitlements.plist")
        try Data(FakeCodeIdentityCommandRunner.entitlements.utf8).write(to: entitlements)
        try runCodesign([
            "--force", "--sign", "-", "--timestamp=none",
            "--entitlements", entitlements.path, app.path,
        ])
        let executableBefore = try unsignedExecutableData(executable)
        let cdHashBefore = try cdHash(of: app)

        let result = try AppCodeIdentityRepairService(
            nonceProvider: { "real-codesign-test" }
        ).repair(appURL: app)

        XCTAssertNotEqual(result.cdHash, cdHashBefore)
        XCTAssertEqual(try unsignedExecutableData(executable), executableBefore)
        try runCodesign(["--verify", "--deep", "--strict", "--verbose=2", app.path])
    }

    private func makeApp() throws -> URL {
        let app = root.appendingPathComponent("CrossOver Patched.app", isDirectory: true)
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        let sharedSupport = app.appendingPathComponent("Contents/SharedSupport", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sharedSupport, withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: app.appendingPathComponent("Contents/Info.plist"))
        try Data("runtime sentinel".utf8).write(to: sharedSupport.appendingPathComponent("runtime.bin"))
        return app
    }

    private func cdHash(of app: URL) throws -> String {
        let result = try runCodesign(["-dvvv", app.path])
        return try XCTUnwrap(
            result.split(whereSeparator: \.isNewline)
                .first { $0.hasPrefix("CDHash=") }
                .map { String($0.dropFirst("CDHash=".count)) }
        )
    }

    private func unsignedExecutableData(_ executable: URL) throws -> Data {
        let copy = root.appendingPathComponent("unsigned-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: executable, to: copy)
        try runCodesign(["--remove-signature", copy.path])
        return try Data(contentsOf: copy)
    }

    @discardableResult
    private func runCodesign(_ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw AppCodeIdentityRepairError(message: text)
        }
        return text
    }
}

private final class FakeCodeIdentityCommandRunner: CodeIdentityCommandRunning {
    var arguments: [[String]] = []
    var entitlementsSeenDuringSigning: [Data] = []
    var identityText = "CDHash=deadbeef\n"
    var signFailuresRemaining = 0

    func run(executable: URL, arguments: [String]) throws -> CodeIdentityCommandResult {
        self.arguments.append(arguments)

        if arguments.starts(with: ["-d", "--entitlements", ":-"]) {
            return CodeIdentityCommandResult(
                standardOutput: Data(Self.entitlements.utf8),
                standardError: Data()
            )
        }
        if arguments.contains("--force") {
            if let index = arguments.firstIndex(of: "--entitlements"), arguments.indices.contains(index + 1) {
                entitlementsSeenDuringSigning.append(try Data(contentsOf: URL(fileURLWithPath: arguments[index + 1])))
            }
            if signFailuresRemaining > 0 {
                signFailuresRemaining -= 1
                throw CodeIdentityCommandError(executable: executable, status: 1, detail: "expected failure")
            }
        }
        if arguments.first == "-dvvv" {
            return CodeIdentityCommandResult(
                standardOutput: Data(),
                standardError: Data(identityText.utf8)
            )
        }
        return CodeIdentityCommandResult(standardOutput: Data(), standardError: Data())
    }

    static let entitlements = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/></dict></plist>
    """
}
