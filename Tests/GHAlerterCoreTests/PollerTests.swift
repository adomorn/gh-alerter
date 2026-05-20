import XCTest
@testable import GHAlerterCore

final class PollerTests: XCTestCase {
    func testManualCheckSkipsWhenAlreadyRunning() async throws {
        let checker = GatedChecker()
        let poller = Poller(checker: checker)

        async let first: PollResult = poller.checkNow()

        await checker.waitUntilStarted()
        let second = await poller.checkNow()
        await checker.release()
        let firstResult = await first

        let runCount = await checker.runCount
        XCTAssertEqual(firstResult, .completed(newEvents: []))
        XCTAssertEqual(second, .skippedAlreadyRunning)
        XCTAssertEqual(runCount, 1)
    }

    @MainActor
    func testInboxStoreExtractsReviewRequestsFromEvents() throws {
        let reviewPR = samplePR(number: 1)
        let approvalPR = samplePR(number: 2)
        let store = InboxStore()

        store.apply(
            events: [
                .reviewRequested(
                    id: "review-request:owner/repo:1",
                    pr: reviewPR,
                    detectedAt: Date(timeIntervalSince1970: 10)
                ),
                .prApproved(
                    id: "approval:owner/repo:2:900",
                    pr: approvalPR,
                    actor: "alice",
                    detectedAt: Date(timeIntervalSince1970: 20)
                )
            ],
            checkedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(store.reviewRequests, [reviewPR])
    }

    @MainActor
    func testInboxStoreRetainsApprovalEvents() throws {
        let approval = GitHubEvent.prApproved(
            id: "approval:owner/repo:2:900",
            pr: samplePR(number: 2),
            actor: "alice",
            detectedAt: Date(timeIntervalSince1970: 20)
        )
        let store = InboxStore()

        store.apply(
            events: [
                .reviewRequested(
                    id: "review-request:owner/repo:1",
                    pr: samplePR(number: 1),
                    detectedAt: Date(timeIntervalSince1970: 10)
                ),
                approval
            ],
            checkedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(store.approvals, [approval])
    }

    @MainActor
    func testInboxStoreRecordsSuccessfulCheckAndClearsLastError() throws {
        let checkedAt = Date(timeIntervalSince1970: 100)
        let store = InboxStore()

        store.apply(errorMessage: "Previous failure")
        store.apply(events: [], checkedAt: checkedAt)

        XCTAssertEqual(store.lastSuccessfulCheck, checkedAt)
        XCTAssertNil(store.lastErrorMessage)
    }

    @MainActor
    func testInboxStoreRecordsErrorWithoutClearingLastSuccessfulCheck() throws {
        let checkedAt = Date(timeIntervalSince1970: 100)
        let store = InboxStore()

        store.apply(events: [], checkedAt: checkedAt)
        store.apply(errorMessage: "Network unavailable")

        XCTAssertEqual(store.lastSuccessfulCheck, checkedAt)
        XCTAssertEqual(store.lastErrorMessage, "Network unavailable")
    }

    actor GatedChecker: PollChecking {
        private(set) var runCount = 0
        private var started = false
        private var startedContinuation: CheckedContinuation<Void, Never>?
        private var releaseContinuation: CheckedContinuation<Void, Never>?

        func check() async -> PollResult {
            runCount += 1
            started = true
            startedContinuation?.resume()
            startedContinuation = nil
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
            return .completed(newEvents: [])
        }

        func waitUntilStarted() async {
            guard !started else { return }
            await withCheckedContinuation { continuation in
                startedContinuation = continuation
            }
        }

        func release() {
            releaseContinuation?.resume()
            releaseContinuation = nil
        }
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
