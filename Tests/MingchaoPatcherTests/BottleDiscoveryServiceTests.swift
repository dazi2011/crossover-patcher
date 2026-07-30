import Foundation
import XCTest
@testable import MingchaoPatcher

final class BottleDiscoveryServiceTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MingchaoPatcherBottleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    func testEnumeratesOfficialBottleShapeAndFiltersAliases() throws {
        try createBottle("鸣潮")
        try createBottle("Wuthering_Waves-patched2")
        try createBottle("原神")
        try createBottle("default")
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Incomplete", isDirectory: true),
            withIntermediateDirectories: true
        )

        let service = BottleDiscoveryService()
        XCTAssertEqual(service.allBottles(at: root).map(\.name), ["Wuthering_Waves-patched2", "原神", "鸣潮"])
        XCTAssertEqual(service.similarBottles(at: root).map(\.name), ["Wuthering_Waves-patched2", "鸣潮"])
    }

    private func createBottle(_ name: String) throws {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("REGEDIT4\n".utf8).write(to: directory.appendingPathComponent("system.reg"))
    }
}
