import Foundation

public enum SoundSelection: Equatable, Hashable {
    case defaultSound
    case predefined(String)
    case custom
}

public struct SoundSelectionResolver {
    private let predefinedSounds: [PredefinedNotificationSound]
    private let predefinedSoundURL: (PredefinedNotificationSound) -> URL?

    public init(
        predefinedSounds: [PredefinedNotificationSound] = PredefinedNotificationSound.all,
        predefinedSoundURL: @escaping (PredefinedNotificationSound) -> URL?
    ) {
        self.predefinedSounds = predefinedSounds
        self.predefinedSoundURL = predefinedSoundURL
    }

    public func selection(for path: String?) -> SoundSelection {
        guard let path else {
            return .defaultSound
        }

        if let sound = predefinedSounds.first(where: { predefinedSoundURL($0)?.path == path }) {
            return .predefined(sound.id)
        }

        return .custom
    }

    public func url(for selection: SoundSelection) -> URL? {
        switch selection {
        case .defaultSound, .custom:
            return nil
        case .predefined(let id):
            guard let sound = predefinedSounds.first(where: { $0.id == id }) else {
                return nil
            }

            return predefinedSoundURL(sound)
        }
    }
}
