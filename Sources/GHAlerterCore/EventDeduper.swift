import Foundation

public struct EventDeduper {
    private var seenEventIDs: Set<String>

    public init(seenEventIDs: Set<String> = []) {
        self.seenEventIDs = seenEventIDs
    }

    public mutating func consumeNewEvents(_ events: [GitHubEvent]) -> [GitHubEvent] {
        var newEvents: [GitHubEvent] = []

        for event in events where !seenEventIDs.contains(event.id) {
            seenEventIDs.insert(event.id)
            newEvents.append(event)
        }

        return newEvents
    }

    public func hasSeen(_ id: String) -> Bool {
        seenEventIDs.contains(id)
    }

    public var snapshot: Set<String> {
        seenEventIDs
    }
}
