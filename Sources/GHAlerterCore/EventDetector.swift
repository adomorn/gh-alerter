import Foundation

public struct EventDetector {
    private let watchedScopes: [WatchedScope]

    public init(watchedScopes: [WatchedScope]) {
        self.watchedScopes = watchedScopes
    }

    public func reviewRequestEvents(from prs: [PullRequestRef], now: Date = Date()) -> [GitHubEvent] {
        prs.filter(isWatched).map { pr in
            .reviewRequested(
                id: "review-request:\(pr.owner)/\(pr.repo):\(pr.number)",
                pr: pr,
                detectedAt: now
            )
        }
    }

    public func approvalEvents(from approvals: [PullRequestApproval], now: Date = Date()) -> [GitHubEvent] {
        approvals.filter { isWatched($0.pr) }.map { approval in
            .prApproved(
                id: "approval:\(approval.pr.owner)/\(approval.pr.repo):\(approval.pr.number):\(approval.reviewID)",
                pr: approval.pr,
                actor: approval.actor,
                detectedAt: now
            )
        }
    }

    private func isWatched(_ pr: PullRequestRef) -> Bool {
        watchedScopes.contains { $0.matches(owner: pr.owner, repo: pr.repo) }
    }
}
