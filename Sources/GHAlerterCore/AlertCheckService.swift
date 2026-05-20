import Foundation

public protocol SettingsStoring {
    func load() throws -> AppSettings
    func save(_ settings: AppSettings) throws
}

extension SettingsStore: SettingsStoring {}

public protocol GitHubFetching {
    func reviewRequests() async throws -> [PullRequestRef]
    func myOpenPullRequests() async throws -> [PullRequestRef]
    func approvals(for pr: PullRequestRef) async throws -> [PullRequestApproval]
}

extension GitHubClient: GitHubFetching {}

public protocol EventNotifying {
    func notify(event: GitHubEvent, sound: NotificationSoundPreference) async throws
}

extension NotificationService: EventNotifying {}

public actor GitHubAlertCheckService: PollChecking {
    private let settingsStore: any SettingsStoring
    private let github: any GitHubFetching
    private let notifier: any EventNotifying
    private let inboxStore: InboxStore
    private let now: @Sendable () -> Date

    public init(
        settingsStore: any SettingsStoring = SettingsStore(),
        github: any GitHubFetching,
        notifier: any EventNotifying = NotificationService(),
        inboxStore: InboxStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.settingsStore = settingsStore
        self.github = github
        self.notifier = notifier
        self.inboxStore = inboxStore
        self.now = now
    }

    public func check() async -> PollResult {
        do {
            var settings = try settingsStore.load()
            let watchedScopes = try parseWatchedScopes(settings.watchedScopeRawValues)
            let detectedAt = now()
            let detector = EventDetector(watchedScopes: watchedScopes)

            let reviewRequests = try await github.reviewRequests()
            let reviewRequestEvents = detector.reviewRequestEvents(from: reviewRequests, now: detectedAt)
            let approvals = try await fetchApprovalsForMyOpenPullRequests()
            let approvalEvents = detector.approvalEvents(from: approvals, now: detectedAt)
            let currentEvents = reviewRequestEvents + approvalEvents

            var deduper = EventDeduper(seenEventIDs: settings.seenEventIDs)
            let newEvents = deduper.consumeNewEvents(currentEvents)
            let warnings = try await notify(events: newEvents, settings: settings)

            settings.seenEventIDs = deduper.snapshot
            try settingsStore.save(settings)
            await inboxStore.applySnapshot(events: currentEvents, checkedAt: detectedAt)

            if !warnings.isEmpty {
                await inboxStore.apply(errorMessage: warnings.joined(separator: "\n"))
            }

            return .completed(newEvents: newEvents)
        } catch {
            let message = userFacingMessage(for: error)
            await inboxStore.apply(errorMessage: message)
            return .failed(message)
        }
    }

    private func fetchApprovalsForMyOpenPullRequests() async throws -> [PullRequestApproval] {
        let pullRequests = try await github.myOpenPullRequests()
        var approvals: [PullRequestApproval] = []

        for pr in pullRequests {
            approvals.append(contentsOf: try await github.approvals(for: pr))
        }

        return approvals
    }

    private func notify(events: [GitHubEvent], settings: AppSettings) async throws -> [String] {
        var warnings: [String] = []

        for event in events {
            do {
                try await notifier.notify(event: event, sound: sound(for: event, settings: settings))
            } catch NotificationServiceError.soundFileMissing(let path) {
                try await notifier.notify(event: event, sound: .systemDefault)
                warnings.append("Sound file not found: \(path). Sent default notification instead.")
            } catch {
                warnings.append("Notification could not be delivered for \(event.pr.id): \(error.localizedDescription)")
            }
        }

        return warnings
    }

    private func sound(for event: GitHubEvent, settings: AppSettings) -> NotificationSoundPreference {
        switch event {
        case .reviewRequested:
            guard settings.reviewRequestSoundEnabled else {
                return .silent
            }

            return settings.reviewRequestSoundPath.map(NotificationSoundPreference.file) ?? .systemDefault
        case .prApproved:
            guard settings.approvalSoundEnabled else {
                return .silent
            }

            return settings.approvalSoundPath.map(NotificationSoundPreference.file) ?? .systemDefault
        }
    }

    private func parseWatchedScopes(_ rawValues: [String]) throws -> [WatchedScope] {
        guard !rawValues.isEmpty else {
            throw AlertCheckServiceError.noWatchedScopes
        }

        do {
            return try rawValues.map(WatchedScope.init(rawValue:))
        } catch WatchedScopeError.malformed(let rawValue) {
            throw AlertCheckServiceError.malformedScope(rawValue)
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        switch error {
        case AlertCheckServiceError.noWatchedScopes:
            return "Add at least one watched repository scope."
        case AlertCheckServiceError.malformedScope(let rawValue):
            return "Malformed watched repository scope: \(rawValue)"
        case let githubError as GitHubCLIError:
            return githubError.userMessage
        default:
            return error.localizedDescription
        }
    }
}

private enum AlertCheckServiceError: Error, Equatable {
    case noWatchedScopes
    case malformedScope(String)
}
