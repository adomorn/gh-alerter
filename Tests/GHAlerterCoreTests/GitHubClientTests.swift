import XCTest
@testable import GHAlerterCore

final class GitHubClientTests: XCTestCase {
    func testParsesReviewRequestedSearchResults() async throws {
        let cli = RecordingCLI(output: """
        [{"repository":{"nameWithOwner":"owner/repo"},"number":42,"title":"Fix bug","url":"https://github.com/owner/repo/pull/42"}]
        """)
        let client = GitHubClient(cli: cli)

        let results = try await client.reviewRequests()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].owner, "owner")
        XCTAssertEqual(results[0].repo, "repo")
        XCTAssertEqual(results[0].number, 42)
        XCTAssertEqual(cli.invocations, [[
            "search",
            "prs",
            "--state",
            "open",
            "--review-requested",
            "@me",
            "--limit",
            "1000",
            "--json",
            "repository,number,title,url"
        ]])
    }

    func testParsesMyOpenPullRequests() async throws {
        let cli = RecordingCLI(output: """
        [{"repository":{"nameWithOwner":"owner/repo"},"number":9,"title":"My PR","url":"https://github.com/owner/repo/pull/9"}]
        """)
        let client = GitHubClient(cli: cli)

        let results = try await client.myOpenPullRequests()

        XCTAssertEqual(results.map(\.id), ["owner/repo#9"])
        XCTAssertEqual(cli.invocations, [[
            "search",
            "prs",
            "--state",
            "open",
            "--author",
            "@me",
            "--limit",
            "1000",
            "--json",
            "repository,number,title,url"
        ]])
    }

    func testParsesApprovalsForPullRequest() async throws {
        let cli = RecordingCLI(output: """
        [[{"id":901,"state":"COMMENTED","user":{"login":"alice"}},{"id":902,"state":"APPROVED","user":{"login":"malik"}}]]
        """)
        let client = GitHubClient(cli: cli)
        let pr = samplePR()

        let approvals = try await client.approvals(for: pr)

        XCTAssertEqual(approvals, [PullRequestApproval(pr: pr, reviewID: 902, actor: "malik")])
        XCTAssertEqual(cli.invocations, [[
            "api",
            "--paginate",
            "--slurp",
            "repos/owner/repo/pulls/9/reviews?per_page=100"
        ]])
    }

    func testParsesApprovalsAcrossPaginatedReviewPages() async throws {
        let cli = RecordingCLI(output: """
        [[{"id":901,"state":"COMMENTED","user":{"login":"alice"}}],[{"id":902,"state":"APPROVED","user":{"login":"malik"}}]]
        """)
        let client = GitHubClient(cli: cli)
        let pr = samplePR()

        let approvals = try await client.approvals(for: pr)

        XCTAssertEqual(approvals, [PullRequestApproval(pr: pr, reviewID: 902, actor: "malik")])
    }

    func testMalformedSearchJSONThrows() async throws {
        let cli = RecordingCLI(output: "{")
        let client = GitHubClient(cli: cli)

        try await assertThrows {
            _ = try await client.reviewRequests()
        }
    }

    func testMissingRepositoryNameWithOwnerThrows() async throws {
        let cli = RecordingCLI(output: """
        [{"repository":{},"number":42,"title":"Fix bug","url":"https://github.com/owner/repo/pull/42"}]
        """)
        let client = GitHubClient(cli: cli)

        try await assertThrows {
            _ = try await client.reviewRequests()
        }
    }

    func testInvalidURLSearchRowIsSkipped() async throws {
        let cli = RecordingCLI(output: """
        [{"repository":{"nameWithOwner":"owner/repo"},"number":42,"title":"Fix bug","url":"://bad"}]
        """)
        let client = GitHubClient(cli: cli)

        let results = try await client.reviewRequests()

        XCTAssertEqual(results, [])
    }

    func testMixedValidAndBusinessInvalidSearchRowsReturnValidRows() async throws {
        let cli = RecordingCLI(output: """
        [
          {"repository":{"nameWithOwner":"owner/repo"},"number":42,"title":"Fix bug","url":"https://github.com/owner/repo/pull/42"},
          {"repository":{"nameWithOwner":"not-a-repo-name"},"number":43,"title":"Bad repo","url":"https://github.com/owner/repo/pull/43"},
          {"repository":{"nameWithOwner":"owner/repo"},"number":44,"title":"Bad URL","url":"://bad"}
        ]
        """)
        let client = GitHubClient(cli: cli)

        let results = try await client.reviewRequests()

        XCTAssertEqual(results.map(\.id), ["owner/repo#42"])
    }

    private func samplePR() -> PullRequestRef {
        PullRequestRef(
            owner: "owner",
            repo: "repo",
            number: 9,
            title: "My PR",
            url: URL(string: "https://github.com/owner/repo/pull/9")!
        )
    }

    private func assertThrows(_ operation: () async throws -> Void) async throws {
        do {
            try await operation()
            XCTFail("Expected operation to throw")
        } catch {
            return
        }
    }

    private final class RecordingCLI: GitHubCLIExecuting {
        let output: String
        private(set) var invocations: [[String]] = []

        init(output: String) {
            self.output = output
        }

        func run(arguments: [String]) async throws -> String {
            invocations.append(arguments)
            return output
        }
    }
}
