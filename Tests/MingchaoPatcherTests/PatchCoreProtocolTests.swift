import Foundation
import XCTest
import PatcherProtocol

final class PatchCoreProtocolTests: XCTestCase {
    func testRequestRoundTripsAllBottleModes() throws {
        for mode in BottlePatchMode.allCases {
            let request = PatchCoreRequest(
                sourceAppPath: "/Applications/CrossOver Preview.app",
                destinationAppPath: "/Applications/CrossOver Wuthering Waves Patched.app",
                bottlesRootPath: "/tmp/Bottles",
                bottleMode: mode,
                sourceBottleName: mode == .createNew ? nil : "鸣潮",
                destinationBottleName: mode == .patchExisting ? nil : "鸣潮-patched2"
            )
            let decoded = try JSONDecoder().decode(
                PatchCoreRequest.self,
                from: JSONEncoder().encode(request)
            )
            XCTAssertEqual(decoded, request)
        }
    }
}
