import XCTest
@testable import GHAlerterCore

final class AlertCheckServiceTests: XCTestCase {
    @MainActor
    func testSuccessUpdatesInboxWithFullSnapshotNotifiesOnlyNewEventsAndSavesSeenIDs() async throws {
        let reviewPR = samplePR(number: 1)
        let approvedPR = samplePR(number: 2)
        let approval = PullRequestApproval(pr: approvedPR, reviewID: 900, actor: "alice")
        let existingReviewEventID = "review-request:owner/repo:1"
        let newApprovalEventID = "approval:owner/repo:2:900"
        let settingsStore = InMemorySettingsStore(
            settings: AppSettings(
                watchedScopeRawValues: ["owner/repo"],
                reviewRequestSoundPath: "/sounds/review.aiff",
                approvalSoundPath: "/sounds/approval.aiff",
                seenEventIDs: [existingReviewEventID]
            )
        )
        let github = StubGitHubFetching(
            reviewRequests: [reviewPR],
            myOpenPullRequests: [approvedPR],
            approvalsByPRID: [approvedPR.id: [approval]]
        )
        let notifier = RecordingEventNotifying()
        let inbox = InboxStore()
        let service = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: github,
            notifier: notifier,
            inboxStore: inbox,
            now: { Date(timeIntervalSince1970: 100) }
        )

        let result = await service.check()

        XCTAssertEqual(result, .completed(newEvents: [
            .prApproved(
                id: newApprovalEventID,
                pr: approvedPR,
                actor: "alice",
                detectedAt: Date(timeIntervalSince1970: 100)
            )
        ]))
        XCTAssertEqual(inbox.reviewRequests, [reviewPR])
        XCTAssertEqual(inbox.approvals.map(\.id), [newApprovalEventID])
        XCTAssertEqual(inbox.lastSuccessfulCheck, Date(timeIntervalSince1970: 100))
        XCTAssertNil(inbox.lastErrorMessage)
        XCTAssertEqual(notifier.calls.map(\.event.id), [newApprovalEventID])
        XCTAssertEqual(notifier.calls.map(\.sound), [.file("/sounds/approval.aiff")])
        XCTAssertEqual(settingsStore.savedSettings?.seenEventIDs, [existingReviewEventID, newApprovalEventID])
    }

    @MainActor
    func testSecondRunWithAllEventsSeenKeepsInboxSnapshotButSendsNoNotifications() async throws {
        let reviewPR = samplePR(number: 3)
        let approval = PullRequestApproval(pr: reviewPR, reviewID: 901, actor: "bob")
        let reviewEventID = "review-request:owner/repo:3"
        let approvalEventID = "approval:owner/repo:3:901"
        let settingsStore = InMemorySettingsStore(
            settings: AppSettings(
                watchedScopeRawValues: ["owner/repo"],
                seenEventIDs: [reviewEventID, approvalEventID]
            )
        )
        let github = StubGitHubFetching(
            reviewRequests: [reviewPR],
            myOpenPullRequests: [reviewPR],
            approvalsByPRID: [reviewPR.id: [approval]]
        )
        let notifier = RecordingEventNotifying()
        let inbox = InboxStore()
        let service = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: github,
            notifier: notifier,
            inboxStore: inbox,
            now: { Date(timeIntervalSince1970: 200) }
        )

        let result = await service.check()

        XCTAssertEqual(result, .completed(newEvents: []))
        XCTAssertEqual(inbox.reviewRequests, [reviewPR])
        XCTAssertEqual(inbox.approvals.map(\.id), [approvalEventID])
        XCTAssertTrue(notifier.calls.isEmpty)
        XCTAssertEqual(settingsStore.savedSettings?.seenEventIDs, [reviewEventID, approvalEventID])
    }

    @MainActor
    func testMissingCustomSoundFallsBackToDefaultAndRecordsWarningWithoutDroppingSnapshot() async throws {
        let reviewPR = samplePR(number: 4)
        let settingsStore = InMemorySettingsStore(
            settings: AppSettings(
                watchedScopeRawValues: ["owner/repo"],
                reviewRequestSoundPath: "/missing/review.aiff"
            )
        )
        let github = StubGitHubFetching(reviewRequests: [reviewPR])
        let notifier = RecordingEventNotifying()
        notifier.missingSoundPaths = ["/missing/review.aiff"]
        let inbox = InboxStore()
        let service = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: github,
            notifier: notifier,
            inboxStore: inbox,
            now: { Date(timeIntervalSince1970: 300) }
        )

        let result = await service.check()

        let eventID = "review-request:owner/repo:4"
        XCTAssertEqual(result, .completed(newEvents: [
            .reviewRequested(id: eventID, pr: reviewPR, detectedAt: Date(timeIntervalSince1970: 300))
        ]))
        XCTAssertEqual(inbox.reviewRequests, [reviewPR])
        XCTAssertEqual(notifier.calls.map(\.event.id), [eventID, eventID])
        XCTAssertEqual(notifier.calls.map(\.sound), [.file("/missing/review.aiff"), .systemDefault])
        XCTAssertEqual(inbox.lastSuccessfulCheck, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(inbox.lastErrorMessage, "Sound file not found: /missing/review.aiff. Sent default notification instead.")
        XCTAssertEqual(settingsStore.savedSettings?.seenEventIDs, [eventID])
    }

    @MainActor
    func testDisabledSoundSendsSilentNotificationPreference() async throws {
        let reviewPR = samplePR(number: 6)
        let settingsStore = InMemorySettingsStore(
            settings: AppSettings(
                watchedScopeRawValues: ["owner/repo"],
                reviewRequestSoundPath: nil,
                reviewRequestSoundEnabled: false
            )
        )
        let github = StubGitHubFetching(reviewRequests: [reviewPR])
        let notifier = RecordingEventNotifying()
        let inbox = InboxStore()
        let service = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: github,
            notifier: notifier,
            inboxStore: inbox,
            now: { Date(timeIntervalSince1970: 350) }
        )

        let result = await service.check()

        let eventID = "review-request:owner/repo:6"
        XCTAssertEqual(result, .completed(newEvents: [
            .reviewRequested(id: eventID, pr: reviewPR, detectedAt: Date(timeIntervalSince1970: 350))
        ]))
        XCTAssertEqual(notifier.calls.map(\.sound), [.silent])
    }

    @MainActor
    func testNotificationFailureRecordsWarningWithoutDroppingSnapshotOrSeenState() async throws {
        let reviewPR = samplePR(number: 5)
        let settingsStore = InMemorySettingsStore(
            settings: AppSettings(watchedScopeRawValues: ["owner/repo"])
        )
        let github = StubGitHubFetching(reviewRequests: [reviewPR])
        let notifier = RecordingEventNotifying()
        notifier.failEventIDs = ["review-request:owner/repo:5"]
        let inbox = InboxStore()
        let service = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: github,
            notifier: notifier,
            inboxStore: inbox,
            now: { Date(timeIntervalSince1970: 400) }
        )

        let result = await service.check()

        let eventID = "review-request:owner/repo:5"
        XCTAssertEqual(result, .completed(newEvents: [
            .reviewRequested(id: eventID, pr: reviewPR, detectedAt: Date(timeIntervalSince1970: 400))
        ]))
        XCTAssertEqual(inbox.reviewRequests, [reviewPR])
        XCTAssertEqual(inbox.lastSuccessfulCheck, Date(timeIntervalSince1970: 400))
        XCTAssertEqual(inbox.lastErrorMessage, "Notification could not be delivered for owner/repo#5: scheduler failed")
        XCTAssertEqual(settingsStore.savedSettings?.seenEventIDs, [eventID])
    }

    @MainActor
    func testNoWatchedScopesReturnsFailedAndUpdatesInboxError() async throws {
        let settingsStore = InMemorySettingsStore(settings: AppSettings(watchedScopeRawValues: []))
        let inbox = InboxStore()
        let service = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: StubGitHubFetching(),
            notifier: RecordingEventNotifying(),
            inboxStore: inbox
        )

        let result = await service.check()

        XCTAssertEqual(result, .failed("Add at least one watched repository scope."))
        XCTAssertEqual(inbox.lastErrorMessage, "Add at least one watched repository scope.")
        XCTAssertNil(settingsStore.savedSettings)
    }

    @MainActor
    func testMalformedScopeReturnsFailedAndUpdatesInboxError() async throws {
        let settingsStore = InMemorySettingsStore(settings: AppSettings(watchedScopeRawValues: ["owner"]))
        let inbox = InboxStore()
        let service = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: StubGitHubFetching(),
            notifier: RecordingEventNotifying(),
            inboxStore: inbox
        )

        let result = await service.check()

        XCTAssertEqual(result, .failed("Malformed watched repository scope: owner"))
        XCTAssertEqual(inbox.lastErrorMessage, "Malformed watched repository scope: owner")
        XCTAssertNil(settingsStore.savedSettings)
    }

    private func samplePR(number: Int) -> PullRequestRef {
        PullRequestRef(
            owner: "owner",
            repo: "repo",
            number: number,
            title: "PR \(number)",
            url: URL(string: "https://github.com/owner/repo/pull/\(number)")!
        )
    }
}

private final class InMemorySettingsStore: SettingsStoring {
    private let settings: AppSettings
    private(set) var savedSettings: AppSettings?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func load() throws -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) throws {
        savedSettings = settings
    }
}

private final class StubGitHubFetching: GitHubFetching {
    private let reviewRequestResult: [PullRequestRef]
    private let myOpenPullRequestResult: [PullRequestRef]
    private let approvalsByPRID: [String: [PullRequestApproval]]

    init(
        reviewRequests: [PullRequestRef] = [],
        myOpenPullRequests: [PullRequestRef] = [],
        approvalsByPRID: [String: [PullRequestApproval]] = [:]
    ) {
        self.reviewRequestResult = reviewRequests
        self.myOpenPullRequestResult = myOpenPullRequests
        self.approvalsByPRID = approvalsByPRID
    }

    func reviewRequests() async throws -> [PullRequestRef] {
        reviewRequestResult
    }

    func myOpenPullRequests() async throws -> [PullRequestRef] {
        myOpenPullRequestResult
    }

    func approvals(for pr: PullRequestRef) async throws -> [PullRequestApproval] {
        approvalsByPRID[pr.id, default: []]
    }
}

private final class RecordingEventNotifying: EventNotifying {
    private(set) var calls: [(event: GitHubEvent, sound: NotificationSoundPreference)] = []
    var missingSoundPaths: Set<String> = []
    var failEventIDs: Set<String> = []

    func notify(event: GitHubEvent, sound: NotificationSoundPreference) async throws {
        calls.append((event, sound))

        if case .file(let soundPath) = sound, missingSoundPaths.contains(soundPath) {
            throw NotificationServiceError.soundFileMissing(path: soundPath)
        }

        if failEventIDs.contains(event.id) {
            throw RecordingNotificationError.schedulerFailed
        }
    }
}

private enum RecordingNotificationError: LocalizedError {
    case schedulerFailed

    var errorDescription: String? {
        "scheduler failed"
    }
}
