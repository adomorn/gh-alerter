import AppKit
import SwiftUI
import UserNotifications
import GHAlerterCore

@main
struct GHAlerterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    private var inboxStore: InboxStore?
    private var menuBarController: MenuBarController?
    private var poller: Poller?
    private var pollingTimer: Timer?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let inboxStore = InboxStore()
        let settingsStore = SettingsStore()
        seedDefaultNotificationSounds(settingsStore: settingsStore)
        let githubClient = GitHubClient(cli: GitHubCLI())
        let notificationService = NotificationService()
        let alertService = GitHubAlertCheckService(
            settingsStore: settingsStore,
            github: githubClient,
            notifier: notificationService,
            inboxStore: inboxStore
        )
        let poller = Poller(checker: alertService)

        self.inboxStore = inboxStore
        self.poller = poller
        UNUserNotificationCenter.current().delegate = self
        Task {
            do {
                let isAuthorized = try await notificationService.requestPermission()
                guard isAuthorized else {
                    await MainActor.run {
                        inboxStore.apply(errorMessage: "Notifications are disabled for GH Alerter. Enable notifications in System Settings, then restart the app.")
                    }
                    return
                }
            } catch {
                await MainActor.run {
                    inboxStore.apply(errorMessage: "Notification permission could not be checked: \(error.localizedDescription)")
                }
                return
            }

            await MainActor.run {
                self.checkNow()
                self.startPollingTimer(settingsStore: settingsStore)
            }
        }

        menuBarController = MenuBarController(
            inboxStore: inboxStore,
            onCheckNow: { [weak self] in
                self?.checkNow()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollingTimer?.invalidate()
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindowController?.window {
            settingsWindowController = nil
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        NotificationPresentationPolicy.foregroundOptions
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard
            let rawURL = response.notification.request.content.userInfo["url"] as? String,
            let url = URL(string: rawURL)
        else {
            return
        }

        await MainActor.run {
            _ = NSWorkspace.shared.open(url)
        }
    }

    private func startPollingTimer(settingsStore: SettingsStore) {
        let interval: TimeInterval
        do {
            interval = max(60, try settingsStore.load().pollingIntervalSeconds)
        } catch {
            interval = 300
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkNow()
            }
        }
    }

    private func seedDefaultNotificationSounds(settingsStore: SettingsStore) {
        guard
            let firstSound = PredefinedNotificationSound.all.first,
            let defaultSoundURL = predefinedSoundURL(for: firstSound)
        else {
            return
        }

        do {
            var settings = try settingsStore.load()
            settings.selectDefaultSoundIfNeeded(path: defaultSoundURL.path)
            settings.refreshBundledSoundPaths(currentBundlePathFor: bundledSoundPath(fileName:))
            try settingsStore.save(settings)
        } catch {
            // Settings UI will surface persisted settings errors when the user opens it.
        }
    }

    private func bundledSoundPath(fileName: String) -> String? {
        let fileURL = URL(fileURLWithPath: fileName)
        return Bundle.main.url(
            forResource: fileURL.deletingPathExtension().lastPathComponent,
            withExtension: fileURL.pathExtension,
            subdirectory: "Sounds"
        )?.path
    }

    private func predefinedSoundURL(for sound: PredefinedNotificationSound) -> URL? {
        bundledSoundPath(fileName: sound.fileName).map(URL.init(fileURLWithPath:))
    }

    private func checkNow() {
        guard let poller else { return }
        Task {
            _ = await poller.checkNow()
        }
    }

    private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            settingsWindowController.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "GH Alerter Settings"
        settingsWindow.minSize = NSSize(width: 460, height: 520)
        settingsWindow.contentViewController = NSHostingController(
            rootView: SettingsView()
                .frame(minWidth: 460, minHeight: 520)
        )
        settingsWindow.delegate = self
        settingsWindow.setContentSize(NSSize(width: 460, height: 520))
        settingsWindow.center()

        let windowController = NSWindowController(window: settingsWindow)
        settingsWindowController = windowController
        windowController.showWindow(nil)
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
