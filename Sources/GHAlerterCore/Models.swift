import Foundation

public struct PullRequestRef: Equatable, Hashable, Codable, Identifiable {
    public let owner: String
    public let repo: String
    public let number: Int
    public let title: String
    public let url: URL

    public var id: String { "\(owner)/\(repo)#\(number)" }

    public init(owner: String, repo: String, number: Int, title: String, url: URL) {
        self.owner = owner
        self.repo = repo
        self.number = number
        self.title = title
        self.url = url
    }
}

public struct PullRequestApproval: Equatable, Codable {
    public let pr: PullRequestRef
    public let reviewID: Int
    public let actor: String

    public init(pr: PullRequestRef, reviewID: Int, actor: String) {
        self.pr = pr
        self.reviewID = reviewID
        self.actor = actor
    }
}

public enum GitHubEvent: Equatable, Codable, Identifiable {
    case reviewRequested(id: String, pr: PullRequestRef, detectedAt: Date)
    case prApproved(id: String, pr: PullRequestRef, actor: String, detectedAt: Date)

    public var id: String {
        switch self {
        case .reviewRequested(let id, _, _):
            return id
        case .prApproved(let id, _, _, _):
            return id
        }
    }

    public var pr: PullRequestRef {
        switch self {
        case .reviewRequested(_, let pr, _):
            return pr
        case .prApproved(_, let pr, _, _):
            return pr
        }
    }
}
