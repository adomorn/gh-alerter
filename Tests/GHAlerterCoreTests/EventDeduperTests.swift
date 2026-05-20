import XCTest
@testable import GHAlerterCore

final class EventDeduperTests: XCTestCase {
    func testKeepsOnlyNewEventsAndMarksThemSeen() throws {
        let old = GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:1",
            pr: samplePR(number: 1),
            detectedAt: Date(timeIntervalSince1970: 10)
        )
        let new = GitHubEvent.prApproved(
            id: "approval:owner/repo:2:900",
            pr: samplePR(number: 2),
            actor: "malik",
            detectedAt: Date(timeIntervalSince1970: 20)
        )
        var deduper = EventDeduper(seenEventIDs: [old.id])

        let result = deduper.consumeNewEvents([old, new])

        XCTAssertEqual(result.map(\.id), [new.id])
        XCTAssertTrue(deduper.hasSeen(old.id))
        XCTAssertTrue(deduper.hasSeen(new.id))
    }

    func testReviewRequestedEventRoundTripsThroughCodable() throws {
        let event = GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:1",
            pr: samplePR(number: 1),
            detectedAt: Date(timeIntervalSince1970: 10)
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(GitHubEvent.self, from: data)

        XCTAssertEqual(decoded, event)
    }

    func testPrApprovedEventRoundTripsThroughCodable() throws {
        let event = GitHubEvent.prApproved(
            id: "approval:owner/repo:2:900",
            pr: samplePR(number: 2),
            actor: "malik",
            detectedAt: Date(timeIntervalSince1970: 20)
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(GitHubEvent.self, from: data)

        XCTAssertEqual(decoded, event)
    }

    func testSameBatchDuplicatesAreReturnedOnceAndMarkedSeenOnce() throws {
        let event = GitHubEvent.reviewRequested(
            id: "review-request:owner/repo:1",
            pr: samplePR(number: 1),
            detectedAt: Date(timeIntervalSince1970: 10)
        )
        var deduper = EventDeduper()

        let result = deduper.consumeNewEvents([event, event])

        XCTAssertEqual(result.map(\.id), [event.id])
        XCTAssertEqual(deduper.snapshot, [event.id])
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
