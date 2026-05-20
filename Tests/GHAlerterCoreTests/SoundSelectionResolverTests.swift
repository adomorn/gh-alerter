import XCTest
@testable import GHAlerterCore

final class SoundSelectionResolverTests: XCTestCase {
    func testNilPathSelectsDefaultSound() {
        let resolver = SoundSelectionResolver(predefinedSoundURL: { _ in nil })

        XCTAssertEqual(resolver.selection(for: nil), .defaultSound)
    }

    func testPredefinedPathSelectsMatchingSound() {
        let sounds = [
            PredefinedNotificationSound(id: "one", displayName: "One", fileName: "one.wav"),
            PredefinedNotificationSound(id: "two", displayName: "Two", fileName: "two.wav")
        ]
        let resolver = SoundSelectionResolver(predefinedSounds: sounds) { sound in
            URL(fileURLWithPath: "/bundle/Sounds/\(sound.fileName)")
        }

        XCTAssertEqual(resolver.selection(for: "/bundle/Sounds/two.wav"), .predefined("two"))
    }

    func testUnknownPathSelectsCustomSound() {
        let resolver = SoundSelectionResolver(predefinedSoundURL: { sound in
            URL(fileURLWithPath: "/bundle/Sounds/\(sound.fileName)")
        })

        XCTAssertEqual(resolver.selection(for: "/Users/test/alert.wav"), SoundSelection.custom)
    }

    func testReturnsURLForPredefinedSelection() {
        let sounds = [PredefinedNotificationSound(id: "one", displayName: "One", fileName: "one.wav")]
        let resolver = SoundSelectionResolver(predefinedSounds: sounds) { sound in
            URL(fileURLWithPath: "/bundle/Sounds/\(sound.fileName)")
        }

        XCTAssertEqual(resolver.url(for: .predefined("one"))?.path, "/bundle/Sounds/one.wav")
    }
}
