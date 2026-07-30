import XCTest
@testable import MingchaoPatcher

final class BottleNameMatcherTests: XCTestCase {
    func testRecognizesChineseEnglishAndCommonVariants() {
        let matching = [
            "鸣潮",
            "鳴潮-測試",
            "Wuthering Waves",
            "Wuthering_Waves Game",
            "wuthering-waves-patched2",
            "WUWA",
            "Ming Chao Trial",
            "鸣潮 - FineWine Trial",
        ]
        for name in matching {
            XCTAssertTrue(BottleNameMatcher.isSimilarGameBottle(name), name)
        }
    }

    func testRejectsUnrelatedBottles() {
        for name in ["原神", "The Witcher 3", "Wave Editor", "CrossOver"] {
            XCTAssertFalse(BottleNameMatcher.isSimilarGameBottle(name), name)
        }
    }

    func testCanonicalNamesFollowDetectedLanguage() {
        XCTAssertEqual(BottleNameMatcher.canonicalPatchedName(for: "鸣潮 - Trial"), "鸣潮-patched")
        XCTAssertEqual(BottleNameMatcher.canonicalPatchedName(for: "Wuthering Waves"), "Wuthering Waves-patched")
        XCTAssertEqual(
            BottleNameMatcher.canonicalPatchedName(for: nil, preferredLanguages: ["zh-Hans"]),
            "鸣潮-patched"
        )
        XCTAssertEqual(
            BottleNameMatcher.canonicalPatchedName(for: nil, preferredLanguages: ["en-US"]),
            "Wuthering Waves-patched"
        )
    }

    func testOccupiedPatchedNameAppendsSequentialNumber() {
        XCTAssertEqual(
            BottleNameMatcher.uniqueName(
                base: "鸣潮-patched",
                existingNames: ["鸣潮-patched", "鸣潮 patched2", "鸣潮_PATCHED3"]
            ),
            "鸣潮-patched4"
        )
        XCTAssertEqual(
            BottleNameMatcher.uniqueName(
                base: "Wuthering Waves-patched",
                existingNames: ["Wuthering Waves-patched"]
            ),
            "Wuthering Waves-patched2"
        )
    }
}
