import Foundation

public struct GitHubClient {
    private let cli: any GitHubCLIExecuting
    private let decoder = JSONDecoder()

    public init(cli: any GitHubCLIExecuting) {
        self.cli = cli
    }

    public func reviewRequests() async throws -> [PullRequestRef] {
        let output = try await cli.run(arguments: [
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
        ])

        return try decodePullRequests(from: output)
    }

    public func myOpenPullRequests() async throws -> [PullRequestRef] {
        let output = try await cli.run(arguments: [
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
        ])

        return try decodePullRequests(from: output)
    }

    public func approvals(for pr: PullRequestRef) async throws -> [PullRequestApproval] {
        let output = try await cli.run(arguments: [
            "api",
            "--paginate",
            "--slurp",
            "repos/\(pr.owner)/\(pr.repo)/pulls/\(pr.number)/reviews?per_page=100"
        ])
        let rows = try decoder.decode([[ReviewRow]].self, from: Data(output.utf8)).flatMap { $0 }

        return rows.compactMap { row in
            guard row.state == "APPROVED" else { return nil }
            return PullRequestApproval(pr: pr, reviewID: row.id, actor: row.user.login)
        }
    }

    private func decodePullRequests(from output: String) throws -> [PullRequestRef] {
        let rows = try decoder.decode([SearchPullRequestRow].self, from: Data(output.utf8))

        return rows.compactMap(\.pullRequestRef)
    }
}

private struct SearchPullRequestRow: Decodable {
    let repository: Repository
    let number: Int
    let title: String
    let url: String

    var pullRequestRef: PullRequestRef? {
        guard
            let parsedURL = URL(string: url),
            let scheme = parsedURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            parsedURL.host?.isEmpty == false
        else {
            return nil
        }

        let parts = repository.nameWithOwner.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }

        return PullRequestRef(owner: parts[0], repo: parts[1], number: number, title: title, url: parsedURL)
    }
}

private struct Repository: Decodable {
    let nameWithOwner: String
}

private struct ReviewRow: Decodable {
    let id: Int
    let state: String
    let user: ReviewUser
}

private struct ReviewUser: Decodable {
    let login: String
}
