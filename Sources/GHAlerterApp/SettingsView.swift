import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers
import GHAlerterCore

struct SettingsView: View {
    private let settingsStore = SettingsStore()
    private let githubCLIStatusChecker = GitHubCLIStatusChecker()
    @State private var settings = AppSettings()
    @State private var newScope = ""
    @State private var statusMessage: String?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var githubCLIStatus: GitHubCLIStatus?
    @State private var isCheckingGitHubCLI = false

    var body: some View {
        Form {
            Section("GitHub CLI") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(githubCLIStatus?.title ?? "Checking GitHub CLI...")
                        .font(.headline)

                    Text(githubCLIStatus?.detail ?? "GH Alerter uses your local gh authentication.")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    HStack {
                        Button(isCheckingGitHubCLI ? "Checking..." : "Check Again") {
                            Task {
                                await checkGitHubCLIStatus()
                            }
                        }
                        .disabled(isCheckingGitHubCLI)

                        if githubCLIStatus == .missing {
                            Button("Install Page") {
                                openURL("https://cli.github.com")
                            }
                            Button("Copy brew install") {
                                copyToPasteboard("brew install gh")
                            }
                        }

                        if githubCLIStatus == .unauthenticated {
                            Button("Copy login command") {
                                copyToPasteboard("gh auth login")
                            }
                        }

                        if githubCLIStatus == .accessNeedsAuthorization {
                            Button("Copy refresh command") {
                                copyToPasteboard("gh auth refresh -s repo,read:org")
                            }
                        }
                    }
                }
            }

            Section("Watched scopes") {
                if settings.watchedScopeRawValues.isEmpty {
                    Text("No watched scopes configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.watchedScopeRawValues, id: \.self) { scope in
                        HStack {
                            Text(scope)
                            Spacer()
                            Button("Remove") {
                                settings.watchedScopeRawValues.removeAll { $0 == scope }
                                saveSettings()
                            }
                        }
                    }
                }

                HStack {
                    TextField("owner/repo or owner/*", text: $newScope)
                    Button("Add") {
                        addScope()
                    }
                    .disabled(newScope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Polling") {
                Stepper(
                    value: pollingIntervalMinutes,
                    in: 1...120,
                    step: 1
                ) {
                    Text("Every \(Int(settings.pollingIntervalSeconds / 60)) minutes")
                }
                .onChange(of: settings.pollingIntervalSeconds) { _ in
                    saveSettings()
                }
            }

            Section("Sounds") {
                soundPicker(
                    title: "Review request",
                    path: settings.reviewRequestSoundPath,
                    isEnabled: settings.reviewRequestSoundEnabled,
                    setPath: { settings.reviewRequestSoundPath = $0 },
                    setEnabled: { settings.reviewRequestSoundEnabled = $0 }
                )
                soundPicker(
                    title: "Approval",
                    path: settings.approvalSoundPath,
                    isEnabled: settings.approvalSoundEnabled,
                    setPath: { settings.approvalSoundPath = $0 },
                    setEnabled: { settings.approvalSoundEnabled = $0 }
                )
            }

            Section("Launch") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
        .task {
            loadSettings()
            await checkGitHubCLIStatus()
        }
    }

    private var pollingIntervalMinutes: Binding<Double> {
        Binding(
            get: {
                settings.pollingIntervalSeconds / 60
            },
            set: { newValue in
                settings.pollingIntervalSeconds = newValue * 60
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { isEnabled in
                do {
                    try LaunchAtLoginService.setEnabled(isEnabled)
                    settings.launchAtLogin = isEnabled
                    saveSettings()
                } catch let error as LaunchAtLoginError {
                    statusMessage = error.userMessage
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        )
    }

    private func soundPicker(
        title: String,
        path: String?,
        isEnabled: Bool,
        setPath: @escaping (String?) -> Void,
        setEnabled: @escaping (Bool) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(title, selection: Binding(
                get: {
                    soundSelectionValue(for: path, isEnabled: isEnabled)
                },
                set: { selection in
                    applySoundSelection(selection, setPath: setPath, setEnabled: setEnabled)
                }
            )) {
                Text("Off").tag(SoundSelection.defaultSound)
                ForEach(PredefinedNotificationSound.all) { sound in
                    Text(sound.displayName).tag(SoundSelection.predefined(sound.id))
                }
                Text("Custom file...").tag(SoundSelection.custom)
            }

            if let path, soundSelectionValue(for: path, isEnabled: isEnabled) == .custom {
                HStack {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose") {
                        chooseCustomSound(setPath: setPath, setEnabled: setEnabled)
                    }
                }
            }

            Button("Preview") {
                previewSound(path: path)
            }
            .disabled(!isEnabled)
        }
    }

    private func addScope() {
        let trimmed = newScope.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            _ = try WatchedScope(rawValue: trimmed)
            if !settings.watchedScopeRawValues.contains(trimmed) {
                settings.watchedScopeRawValues.append(trimmed)
            }
            newScope = ""
            saveSettings()
        } catch {
            statusMessage = "Invalid scope. Use owner/repo or owner/*."
        }
    }

    private func loadSettings() {
        do {
            settings = try settingsStore.load()
            if let defaultSoundPath = firstPredefinedSoundPath() {
                settings.selectDefaultSoundIfNeeded(path: defaultSoundPath)
                try settingsStore.save(settings)
            }
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveSettings() {
        do {
            let persistedSettings = try settingsStore.load()
            settings.seenEventIDs = persistedSettings.seenEventIDs
            try settingsStore.save(settings)
            statusMessage = "Settings saved."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func chooseSoundFile() -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func chooseCustomSound(
        setPath: @escaping (String?) -> Void,
        setEnabled: @escaping (Bool) -> Void
    ) {
        if let selectedPath = chooseSoundFile() {
            setEnabled(true)
            setPath(selectedPath)
            saveSettings()
        }
    }

    private func applySoundSelection(
        _ selection: SoundSelection,
        setPath: @escaping (String?) -> Void,
        setEnabled: @escaping (Bool) -> Void
    ) {
        switch selection {
        case .defaultSound:
            setEnabled(false)
            setPath(nil)
            saveSettings()
        case .predefined(let id):
            guard
                let sound = PredefinedNotificationSound.all.first(where: { $0.id == id }),
                let url = predefinedSoundURL(for: sound)
            else {
                statusMessage = "Predefined sound is missing from the app bundle."
                return
            }

            setEnabled(true)
            setPath(url.path)
            saveSettings()
        case .custom:
            chooseCustomSound(setPath: setPath, setEnabled: setEnabled)
        }
    }

    private func previewSound(path: String?) {
        guard let path else {
            NSSound(named: "Submarine")?.play()
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer = player
            player.prepareToPlay()
            player.play()
        } catch {
            statusMessage = "Could not preview sound: \(error.localizedDescription)"
        }
    }

    private func soundSelectionValue(for path: String?, isEnabled: Bool) -> SoundSelection {
        guard isEnabled else {
            return .defaultSound
        }

        return SoundSelectionResolver(predefinedSoundURL: predefinedSoundURL(for:)).selection(for: path)
    }

    private func firstPredefinedSoundPath() -> String? {
        guard let firstSound = PredefinedNotificationSound.all.first else {
            return nil
        }

        return predefinedSoundURL(for: firstSound)?.path
    }

    private func predefinedSoundURL(for sound: PredefinedNotificationSound) -> URL? {
        let fileURL = URL(fileURLWithPath: sound.fileName)
        return Bundle.main.url(
            forResource: fileURL.deletingPathExtension().lastPathComponent,
            withExtension: fileURL.pathExtension,
            subdirectory: "Sounds"
        )
    }

    private func checkGitHubCLIStatus() async {
        isCheckingGitHubCLI = true
        githubCLIStatus = await githubCLIStatusChecker.check()
        isCheckingGitHubCLI = false
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        statusMessage = "Copied: \(value)"
    }

    private func openURL(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }
}
