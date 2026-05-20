import Foundation

public struct PredefinedNotificationSound: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let fileName: String

    public init(id: String, displayName: String, fileName: String) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
    }

    public static let all: [PredefinedNotificationSound] = [
        PredefinedNotificationSound(id: "ping", displayName: "Ping", fileName: "ping.wav"),
        PredefinedNotificationSound(id: "pop", displayName: "Pop", fileName: "pop.wav"),
        PredefinedNotificationSound(id: "glass", displayName: "Glass", fileName: "glass.wav"),
        PredefinedNotificationSound(id: "pulse", displayName: "Pulse", fileName: "pulse.wav"),
        PredefinedNotificationSound(id: "bell", displayName: "Bell", fileName: "bell.wav"),
        PredefinedNotificationSound(id: "tap", displayName: "Tap", fileName: "tap.wav"),
        PredefinedNotificationSound(id: "bloom", displayName: "Bloom", fileName: "bloom.wav"),
        PredefinedNotificationSound(id: "signal", displayName: "Signal", fileName: "signal.wav"),
        PredefinedNotificationSound(id: "lift", displayName: "Lift", fileName: "lift.wav"),
        PredefinedNotificationSound(id: "soft-alert", displayName: "Soft Alert", fileName: "soft-alert.wav")
    ]
}
