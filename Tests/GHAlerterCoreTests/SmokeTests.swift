import XCTest
@testable import GHAlerterCore

final class SmokeTests: XCTestCase {
    func testPullRequestRefId() throws {
        let pr = PullRequestRef(
            owner: "example-org",
            repo: "example-repo",
            number: 699,
            title: "Remove versioning",
            url: try XCTUnwrap(URL(string: "https://github.com/example-org/example-repo/pull/699"))
        )

        XCTAssertEqual(pr.id, "example-org/example-repo#699")
    }
}
