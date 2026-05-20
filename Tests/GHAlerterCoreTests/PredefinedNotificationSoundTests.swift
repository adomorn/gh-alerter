import XCTest
@testable import GHAlerterCore

final class PredefinedNotificationSoundTests: XCTestCase {
    func testProvidesTenStableChoices() {
        let sounds = PredefinedNotificationSound.all

        XCTAssertEqual(sounds.count, 10)
        XCTAssertEqual(sounds.map(\.id), [
            "ping",
            "pop",
            "glass",
            "pulse",
            "bell",
            "tap",
            "bloom",
            "signal",
            "lift",
            "soft-alert"
        ])
    }

    func testEachChoiceHasAWavFileName() {
        for sound in PredefinedNotificationSound.all {
            XCTAssertFalse(sound.displayName.isEmpty)
            XCTAssertEqual(URL(fileURLWithPath: sound.fileName).pathExtension, "wav")
        }
    }
}
