import XCTest
@testable import GHAlerterCore

final class NotificationServiceTests: XCTestCase {
    func testBuildsReviewRequestContent() {
        let event = GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:7",
            pr: PullRequestRef(
                owner: "owner",
                repo: "repo",
                number: 7,
                title: "Fix checkout",
                url: URL(string: "https://github.com/owner/repo/pull/7")!
            ),
            detectedAt: Date()
        )

        let content = NotificationService.notificationContent(for: event, soundPath: nil)

        XCTAssertEqual(content.title, "Review requested")
        XCTAssertEqual(content.body, "owner/repo #7: Fix checkout")
    }

    func testBuildsApprovalContentWithActorAndTitle() {
        let event = GitHubEvent.prApproved(
            id: "approval:owner/repo:8:901",
            pr: PullRequestRef(
                owner: "owner",
                repo: "repo",
                number: 8,
                title: "Add retries",
                url: URL(string: "https://github.com/owner/repo/pull/8")!
            ),
            actor: "alice",
            detectedAt: Date()
        )

        let content = NotificationService.notificationContent(for: event, soundPath: nil)

        XCTAssertEqual(content.title, "PR approved")
        XCTAssertEqual(content.body, "alice approved owner/repo #8: Add retries")
    }

    func testDraftContainsEventIDAndURL() {
        let url = URL(string: "https://github.com/owner/repo/pull/9")!
        let event = GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:9",
            pr: PullRequestRef(owner: "owner", repo: "repo", number: 9, title: "Persist state", url: url),
            detectedAt: Date()
        )

        let content = NotificationService.notificationContent(for: event, soundPath: nil)

        XCTAssertEqual(content.eventID, "review-request:owner/repo:9")
        XCTAssertEqual(content.url, url)
    }

    func testCustomSoundPathMapsToLastPathComponent() {
        let event = GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:10",
            pr: PullRequestRef(
                owner: "owner",
                repo: "repo",
                number: 10,
                title: "Notify reviewer",
                url: URL(string: "https://github.com/owner/repo/pull/10")!
            ),
            detectedAt: Date()
        )

        let content = NotificationService.notificationContent(
            for: event,
            soundPath: "/Users/test/Library/Sounds/review-request.aiff"
        )

        XCTAssertEqual(content.soundName, "review-request.aiff")
    }

    func testDefaultSoundResolverTargetsDirectUserSoundsDirectory() {
        XCTAssertEqual(
            DefaultNotificationSoundResolver.defaultSoundsDirectory,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library")
                .appendingPathComponent("Sounds")
        )
    }

    func testForegroundPresentationPolicyShowsBannerListAndSound() {
        let options = NotificationPresentationPolicy.foregroundOptions

        XCTAssertTrue(options.contains(.banner))
        XCTAssertTrue(options.contains(.list))
        XCTAssertTrue(options.contains(.sound))
    }

    func testNotifyPassesDefaultSoundRequestThroughInjectedCenter() async throws {
        let center = CapturingNotificationCenter()
        let service = NotificationService(center: center)
        let event = GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:11",
            pr: PullRequestRef(
                owner: "owner",
                repo: "repo",
                number: 11,
                title: "Wire notification",
                url: URL(string: "https://github.com/owner/repo/pull/11")!
            ),
            detectedAt: Date()
        )

        try await service.notify(event: event, soundPath: nil)

        let request = try XCTUnwrap(center.requests.single)
        XCTAssertEqual(request.identifier, "review-request:owner/repo:11")
        XCTAssertEqual(request.title, "Review requested")
        XCTAssertEqual(request.body, "owner/repo #11: Wire notification")
        XCTAssertEqual(request.userInfo["url"], "https://github.com/owner/repo/pull/11")
        XCTAssertEqual(request.sound, .default)
    }

    func testNotifyPassesSilentSoundRequestThroughInjectedCenter() async throws {
        let center = CapturingNotificationCenter()
        let service = NotificationService(center: center)

        try await service.notify(event: sampleReviewRequestEvent(number: 15), sound: .silent)

        let request = try XCTUnwrap(center.requests.single)
        XCTAssertEqual(request.identifier, "review-request:owner/repo:15")
        XCTAssertEqual(request.sound, .none)
    }

    func testNotifySurfacesInjectedSchedulingFailure() async throws {
        let expectedError = TestNotificationError.schedulingFailed
        let service = NotificationService(center: CapturingNotificationCenter(error: expectedError))
        let event = sampleReviewRequestEvent(number: 12)

        do {
            try await service.notify(event: event, soundPath: nil)
            XCTFail("Expected scheduling failure")
        } catch let error as TestNotificationError {
            XCTAssertEqual(error, expectedError)
        }
    }

    func testNotifyThrowsWhenCustomSoundFileIsMissing() async throws {
        let center = CapturingNotificationCenter()
        let service = NotificationService(
            center: center,
            soundResolver: DefaultNotificationSoundResolver(soundsDirectory: testDirectSoundsDirectory())
        )
        let missingPath = "/tmp/gh-alerter-missing-sound-\(UUID().uuidString).aiff"

        do {
            try await service.notify(event: sampleReviewRequestEvent(number: 13), soundPath: missingPath)
            XCTFail("Expected missing sound file error")
        } catch NotificationServiceError.soundFileMissing(let path) {
            XCTAssertEqual(path, missingPath)
            XCTAssertTrue(center.requests.isEmpty)
        }
    }

    func testNotifyImportsExistingCustomSoundBeforeSchedulingResolvedName() async throws {
        let center = CapturingNotificationCenter()
        let soundPlayer = CapturingSoundPlayer()
        let soundsDirectory = testDirectSoundsDirectory()
        let service = NotificationService(
            center: center,
            soundResolver: DefaultNotificationSoundResolver(soundsDirectory: soundsDirectory),
            soundPlayer: soundPlayer
        )
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gh-alerter-source-\(UUID().uuidString)")
        let soundURL = sourceDirectory.appendingPathComponent("selected-sound.aiff")
        try FileManager.default.createDirectory(
            at: soundURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let soundData = Data("sound data".utf8)
        FileManager.default.createFile(atPath: soundURL.path, contents: soundData)
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: soundsDirectory)
        }

        try await service.notify(event: sampleReviewRequestEvent(number: 14), soundPath: soundURL.path)

        let request = try XCTUnwrap(center.requests.single)
        XCTAssertEqual(request.sound, .none)
        let playedURL = try XCTUnwrap(soundPlayer.playedURLs.single)
        XCTAssertEqual(playedURL.deletingLastPathComponent().path, soundsDirectory.path)
        let resolvedSoundName = playedURL.lastPathComponent
        XCTAssertNotEqual(resolvedSoundName, soundURL.lastPathComponent)
        XCTAssertTrue(resolvedSoundName.hasSuffix("-selected-sound.aiff"))
        XCTAssertEqual(
            try Data(contentsOf: soundsDirectory.appendingPathComponent(resolvedSoundName)),
            soundData
        )
    }

    private func sampleReviewRequestEvent(number: Int) -> GitHubEvent {
        GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:\(number)",
            pr: PullRequestRef(
                owner: "owner",
                repo: "repo",
                number: number,
                title: "PR \(number)",
                url: URL(string: "https://github.com/owner/repo/pull/\(number)")!
            ),
            detectedAt: Date()
        )
    }

    private func testDirectSoundsDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("gh-alerter-sounds-\(UUID().uuidString)")
    }
}

private final class CapturingNotificationCenter: NotificationScheduling {
    private(set) var requests: [NotificationScheduleRequest] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func add(_ request: NotificationScheduleRequest) async throws {
        if let error {
            throw error
        }

        requests.append(request)
    }
}

private final class CapturingSoundPlayer: NotificationSoundPlaying {
    private(set) var playedURLs: [URL] = []

    func playSound(at url: URL) throws {
        playedURLs.append(url)
    }
}

private enum TestNotificationError: Error, Equatable {
    case schedulingFailed
}

private extension Array {
    var single: Element? {
        count == 1 ? self[0] : nil
    }
}
