import Foundation

public enum PollResult: Equatable {
    case completed(newEvents: [GitHubEvent])
    case skippedAlreadyRunning
    case failed(String)
}

public protocol PollChecking: Actor {
    func check() async -> PollResult
}

public actor Poller {
    private let checker: any PollChecking
    private var isRunning = false

    public init(checker: any PollChecking) {
        self.checker = checker
    }

    public func checkNow() async -> PollResult {
        guard !isRunning else { return .skippedAlreadyRunning }
        isRunning = true
        defer { isRunning = false }
        return await checker.check()
    }
}
