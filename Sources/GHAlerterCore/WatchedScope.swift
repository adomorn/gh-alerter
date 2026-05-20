import Foundation

public enum WatchedScopeError: Error, Equatable {
    case malformed(String)
}

public struct WatchedScope: Equatable, Hashable, Codable {
    public let owner: String
    public let repo: String?

    public init(rawValue: String) throws {
        let parts = rawValue.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw WatchedScopeError.malformed(rawValue)
        }

        owner = parts[0]
        repo = parts[1] == "*" ? nil : parts[1]
    }

    public func matches(owner candidateOwner: String, repo candidateRepo: String) -> Bool {
        guard owner == candidateOwner else { return false }
        guard let repo else { return true }
        return repo == candidateRepo
    }
}
