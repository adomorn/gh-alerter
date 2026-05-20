import Foundation

public struct AppSettings: Equatable, Codable {
    public var watchedScopeRawValues: [String]
    public var pollingIntervalSeconds: TimeInterval
    public var reviewRequestSoundPath: String?
    public var approvalSoundPath: String?
    public var reviewRequestSoundEnabled: Bool
    public var approvalSoundEnabled: Bool
    public var launchAtLogin: Bool
    public var seenEventIDs: Set<String>

    public init(
        watchedScopeRawValues: [String] = [],
        pollingIntervalSeconds: TimeInterval = 300,
        reviewRequestSoundPath: String? = nil,
        approvalSoundPath: String? = nil,
        reviewRequestSoundEnabled: Bool = true,
        approvalSoundEnabled: Bool = true,
        launchAtLogin: Bool = false,
        seenEventIDs: Set<String> = []
    ) {
        self.watchedScopeRawValues = watchedScopeRawValues
        self.pollingIntervalSeconds = pollingIntervalSeconds
        self.reviewRequestSoundPath = reviewRequestSoundPath
        self.approvalSoundPath = approvalSoundPath
        self.reviewRequestSoundEnabled = reviewRequestSoundEnabled
        self.approvalSoundEnabled = approvalSoundEnabled
        self.launchAtLogin = launchAtLogin
        self.seenEventIDs = seenEventIDs
    }

    public mutating func selectDefaultSoundIfNeeded(path: String) {
        if reviewRequestSoundEnabled && reviewRequestSoundPath == nil {
            reviewRequestSoundPath = path
        }

        if approvalSoundEnabled && approvalSoundPath == nil {
            approvalSoundPath = path
        }
    }

    private enum CodingKeys: String, CodingKey {
        case watchedScopeRawValues
        case pollingIntervalSeconds
        case reviewRequestSoundPath
        case approvalSoundPath
        case reviewRequestSoundEnabled
        case approvalSoundEnabled
        case launchAtLogin
        case seenEventIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            watchedScopeRawValues: try container.decodeIfPresent([String].self, forKey: .watchedScopeRawValues) ?? [],
            pollingIntervalSeconds: try container.decodeIfPresent(TimeInterval.self, forKey: .pollingIntervalSeconds) ?? 300,
            reviewRequestSoundPath: try container.decodeIfPresent(String.self, forKey: .reviewRequestSoundPath),
            approvalSoundPath: try container.decodeIfPresent(String.self, forKey: .approvalSoundPath),
            reviewRequestSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .reviewRequestSoundEnabled) ?? true,
            approvalSoundEnabled: try container.decodeIfPresent(Bool.self, forKey: .approvalSoundEnabled) ?? true,
            launchAtLogin: try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false,
            seenEventIDs: try container.decodeIfPresent(Set<String>.self, forKey: .seenEventIDs) ?? []
        )
    }
}

public struct SettingsStore {
    private let fileURL: URL

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GHAlerter", isDirectory: true)
        fileURL = base.appendingPathComponent("settings.json")
    }

    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return AppSettings()
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    public func save(_ settings: AppSettings) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
