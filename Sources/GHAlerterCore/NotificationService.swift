import Foundation
import UserNotifications

public struct NotificationDraft: Equatable {
    public let title: String
    public let body: String
    public let eventID: String
    public let url: URL
    public let soundName: String?
}

public enum NotificationScheduleSound: Equatable {
    case none
    case `default`
    case named(String)
}

public enum NotificationSoundPreference: Equatable {
    case silent
    case systemDefault
    case file(String)
}

public struct NotificationScheduleRequest: Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let userInfo: [String: String]
    public let sound: NotificationScheduleSound
}

public protocol NotificationScheduling {
    func add(_ request: NotificationScheduleRequest) async throws
}

public protocol NotificationSoundResolving {
    func resolveSoundName(for soundPath: String?) throws -> String?
}

public enum NotificationServiceError: Error, Equatable {
    case soundFileMissing(path: String)
}

public final class DefaultNotificationSoundResolver: NotificationSoundResolving {
    public static let defaultSoundsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library")
        .appendingPathComponent("Sounds")

    private let soundsDirectory: URL
    private let fileManager: FileManager

    public init(
        soundsDirectory: URL = DefaultNotificationSoundResolver.defaultSoundsDirectory,
        fileManager: FileManager = .default
    ) {
        self.soundsDirectory = soundsDirectory
        self.fileManager = fileManager
    }

    public func resolveSoundName(for soundPath: String?) throws -> String? {
        guard let soundPath else {
            return nil
        }

        guard fileManager.fileExists(atPath: soundPath) else {
            throw NotificationServiceError.soundFileMissing(path: soundPath)
        }

        try fileManager.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)

        let sourceURL = URL(fileURLWithPath: soundPath)
        let resolvedSoundName = "\(Self.stableHash(for: sourceURL.path))-\(sourceURL.lastPathComponent)"
        let destinationURL = soundsDirectory.appendingPathComponent(resolvedSoundName)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return resolvedSoundName
    }

    private static func stableHash(for value: String) -> String {
        let hash = value.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partialResult, byte in
            (partialResult ^ UInt64(byte)) &* 1_099_511_628_211
        }

        return String(hash, radix: 16)
    }
}

public final class UserNotificationCenterScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func add(_ request: NotificationScheduleRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo = request.userInfo

        switch request.sound {
        case .none:
            break
        case .default:
            content.sound = .default
        case .named(let soundName):
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        }

        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil
        )
        try await center.add(notificationRequest)
    }
}

public final class NotificationService {
    private let center: any NotificationScheduling
    private let soundResolver: any NotificationSoundResolving

    public init(
        center: any NotificationScheduling = UserNotificationCenterScheduler(),
        soundResolver: any NotificationSoundResolving = DefaultNotificationSoundResolver()
    ) {
        self.center = center
        self.soundResolver = soundResolver
    }

    public static func notificationContent(for event: GitHubEvent, soundPath: String?) -> NotificationDraft {
        let pr = event.pr
        let soundName = soundPath.map { URL(fileURLWithPath: $0).lastPathComponent }

        switch event {
        case .reviewRequested(let id, _, _):
            return NotificationDraft(
                title: "Review requested",
                body: "\(pr.owner)/\(pr.repo) #\(pr.number): \(pr.title)",
                eventID: id,
                url: pr.url,
                soundName: soundName
            )
        case .prApproved(let id, _, let actor, _):
            return NotificationDraft(
                title: "PR approved",
                body: "\(actor) approved \(pr.owner)/\(pr.repo) #\(pr.number): \(pr.title)",
                eventID: id,
                url: pr.url,
                soundName: soundName
            )
        }
    }

    public func requestPermission() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    public func notify(event: GitHubEvent, soundPath: String?) async throws {
        let sound: NotificationSoundPreference = soundPath.map(NotificationSoundPreference.file) ?? .systemDefault
        try await notify(event: event, sound: sound)
    }

    public func notify(event: GitHubEvent, sound: NotificationSoundPreference) async throws {
        let soundPath: String?
        switch sound {
        case .silent, .systemDefault:
            soundPath = nil
        case .file(let path):
            soundPath = path
        }

        let draft = Self.notificationContent(for: event, soundPath: soundPath)
        let scheduleSound: NotificationScheduleSound
        switch sound {
        case .silent:
            scheduleSound = .none
        case .systemDefault:
            scheduleSound = .default
        case .file:
            let resolvedSoundName = try soundResolver.resolveSoundName(for: soundPath)
            scheduleSound = resolvedSoundName.map(NotificationScheduleSound.named) ?? .default
        }

        let request = NotificationScheduleRequest(
            identifier: draft.eventID,
            title: draft.title,
            body: draft.body,
            userInfo: ["url": draft.url.absoluteString],
            sound: scheduleSound
        )
        try await center.add(request)
    }
}
