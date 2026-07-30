import Foundation
import XCTest
@testable import MingchaoPatcher

final class CrossOverInspectorTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MingchaoPatcherCrossOverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    func testAcceptsOnlyExactPreviewMetadataAndLayout() throws {
        let app = try makeApp(shortVersion: "20260717", buildVersion: "27.0.0.40734")
        XCTAssertEqual(
            CrossOverInspector().inspect(app).support,
            .supported(
                profileID: "preview-20260717-27.0.0.40734-singlefile",
                displayName: "CrossOver Preview 20260717"
            )
        )
    }

    func testAcceptsOnlyExactCrossOver263MetadataAndLayout() throws {
        let app = try makeApp(
            shortVersion: "26.3",
            buildVersion: "26.3.0.39832",
            executable: "CrossOver",
            gptkRoot: "lib64"
        )
        XCTAssertEqual(
            CrossOverInspector().inspect(app).support,
            .supported(
                profileID: "crossover-26.3-26.3.0.39832-singlefile",
                displayName: "CrossOver 26.3"
            )
        )
    }

    func testRejectsUnknownCrossOverBuild() throws {
        let app = try makeApp(shortVersion: "26.4", buildVersion: "26.4.0.40000", executable: "CrossOver")
        guard case .unsupported = CrossOverInspector().inspect(app).support else {
            return XCTFail("unknown build must be rejected")
        }
    }

    private func makeApp(
        shortVersion: String,
        buildVersion: String,
        executable: String = "CrossOver Preview",
        gptkRoot: String = "lib"
    ) throws -> URL {
        let app = root.appendingPathComponent(UUID().uuidString).appendingPathExtension("app")
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = [
            "CFBundleShortVersionString": shortVersion,
            "CFBundleVersion": buildVersion,
            "CFBundleIdentifier": "com.codeweavers.CrossOver",
            "CFBundleExecutable": executable,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL)
        for relativePath in [
            "Contents/SharedSupport/CrossOver/bin/cxbottle",
            "Contents/SharedSupport/CrossOver/\(gptkRoot)/apple_gptk/external/D3DMetal.framework/Versions/A/D3DMetal",
        ] {
            let file = app.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: Data())
        }
        return app
    }
}
