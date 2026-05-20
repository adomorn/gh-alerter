import Combine
import Foundation

@MainActor
public final class InboxStore: ObservableObject {
    @Published public private(set) var reviewRequests: [PullRequestRef] = []
    @Published public private(set) var approvals: [GitHubEvent] = []
    @Published public private(set) var lastSuccessfulCheck: Date?
    @Published public private(set) var lastErrorMessage: String?

    public init() {}

    public func applySnapshot(events: [GitHubEvent], checkedAt: Date) {
        reviewRequests = events.compactMap {
            if case .reviewRequested(_, let pr, _) = $0 { return pr }
            return nil
        }
        approvals = events.filter {
            if case .prApproved = $0 { return true }
            return false
        }
        lastSuccessfulCheck = checkedAt
        lastErrorMessage = nil
    }

    public func apply(events: [GitHubEvent], checkedAt: Date) {
        applySnapshot(events: events, checkedAt: checkedAt)
    }

    public func apply(errorMessage: String) {
        lastErrorMessage = errorMessage
    }
}
