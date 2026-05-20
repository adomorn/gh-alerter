import XCTest
@testable import GHAlerterCore

final class SettingsStoreTests: XCTestCase {
    func testSavesAndLoadsSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SettingsStore(directory: directory)
        let settings = AppSettings(
            watchedScopeRawValues: ["owner/*"],
            pollingIntervalSeconds: 300,
            reviewRequestSoundPath: "/tmp/review.aiff",
            approvalSoundPath: "/tmp/approval.aiff",
            launchAtLogin: true,
            seenEventIDs: ["event-1"]
        )

        try store.save(settings)
        let loaded = try store.load()

        XCTAssertEqual(loaded, settings)
    }

    func testLoadReturnsDefaultSettingsWhenFileDoesNotExist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SettingsStore(directory: directory)

        let loaded = try store.load()

        XCTAssertEqual(loaded, AppSettings())
    }

    func testSaveCreatesSettingsDirectoryWhenMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SettingsStore(directory: directory)

        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))

        try store.save(AppSettings())

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testDecodingOldSettingsDefaultsSoundEnabledFlagsToTrue() throws {
        let json = Data("""
        {
          "watchedScopeRawValues": ["owner/repo"],
          "pollingIntervalSeconds": 300,
          "reviewRequestSoundPath": null,
          "approvalSoundPath": null,
          "launchAtLogin": false,
          "seenEventIDs": []
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertTrue(settings.reviewRequestSoundEnabled)
        XCTAssertTrue(settings.approvalSoundEnabled)
    }

    func testDefaultSettingsUseFiveMinutePollingAndNoSeenEvents() {
        let settings = AppSettings()

        XCTAssertEqual(settings.pollingIntervalSeconds, 300)
        XCTAssertTrue(settings.seenEventIDs.isEmpty)
        XCTAssertTrue(settings.reviewRequestSoundEnabled)
        XCTAssertTrue(settings.approvalSoundEnabled)
    }

    func testDefaultSoundPathFillsEmptyEnabledSounds() {
        var settings = AppSettings()

        settings.selectDefaultSoundIfNeeded(path: "/bundle/Sounds/ping.wav")

        XCTAssertEqual(settings.reviewRequestSoundPath, "/bundle/Sounds/ping.wav")
        XCTAssertEqual(settings.approvalSoundPath, "/bundle/Sounds/ping.wav")
    }

    func testDefaultSoundPathDoesNotOverwriteExistingOrDisabledSounds() {
        var settings = AppSettings(
            reviewRequestSoundPath: "/custom/review.wav",
            approvalSoundPath: nil,
            approvalSoundEnabled: false
        )

        settings.selectDefaultSoundIfNeeded(path: "/bundle/Sounds/ping.wav")

        XCTAssertEqual(settings.reviewRequestSoundPath, "/custom/review.wav")
        XCTAssertNil(settings.approvalSoundPath)
    }
}
