import XCTest
@testable import GHAlerterCore

final class EventDetectorTests: XCTestCase {
    func testCreatesReviewRequestedEventOnlyForWatchedScopes() throws {
        let watched = try [WatchedScope(rawValue: "owner/*")]
        let detector = EventDetector(watchedScopes: watched)
        let prs = [
            samplePR(owner: "owner", repo: "repo", number: 1),
            samplePR(owner: "other", repo: "repo", number: 2)
        ]

        let events = detector.reviewRequestEvents(from: prs, now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(events.map(\.id), ["review-request:owner/repo:1"])
    }

    func testCreatesApprovalEventsOnlyForWatchedScopes() throws {
        let watched = try [WatchedScope(rawValue: "owner/*")]
        let detector = EventDetector(watchedScopes: watched)
        let approvals = [
            sampleApproval(owner: "owner", repo: "repo", number: 1, reviewID: 900, actor: "alice"),
            sampleApproval(owner: "other", repo: "repo", number: 2, reviewID: 901, actor: "bob")
        ]

        let events = detector.approvalEvents(from: approvals, now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(events.map(\.id), ["approval:owner/repo:1:900"])
    }

    func testApprovalEventIDFormatAndActorArePreserved() throws {
        let watched = try [WatchedScope(rawValue: "owner/repo")]
        let detector = EventDetector(watchedScopes: watched)
        let approval = sampleApproval(owner: "owner", repo: "repo", number: 42, reviewID: 1234, actor: "reviewer")

        let events = detector.approvalEvents(from: [approval], now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(events.map(\.id), ["approval:owner/repo:42:1234"])
        guard case .prApproved(_, _, let actor, _) = try XCTUnwrap(events.first) else {
            return XCTFail("Expected approval event")
        }
        XCTAssertEqual(actor, "reviewer")
    }

    func testExactRepoScopeDoesNotMatchSiblingRepos() throws {
        let watched = try [WatchedScope(rawValue: "owner/repo")]
        let detector = EventDetector(watchedScopes: watched)
        let prs = [
            samplePR(owner: "owner", repo: "repo", number: 1),
            samplePR(owner: "owner", repo: "sibling", number: 2)
        ]

        let events = detector.reviewRequestEvents(from: prs, now: Date(timeIntervalSince1970: 100))

        XCTAssertEqual(events.map(\.id), ["review-request:owner/repo:1"])
    }

    private func sampleApproval(
        owner: String,
        repo: String,
        number: Int,
        reviewID: Int,
        actor: String
    ) -> PullRequestApproval {
        PullRequestApproval(
            pr: samplePR(owner: owner, repo: repo, number: number),
            reviewID: reviewID,
            actor: actor
        )
    }

    private func samplePR(owner: String, repo: String, number: Int) -> PullRequestRef {
        PullRequestRef(
            owner: owner,
            repo: repo,
            number: number,
            title: "PR \(number)",
            url: URL(string: "https://github.com/\(owner)/\(repo)/pull/\(number)")!
        )
    }
}
