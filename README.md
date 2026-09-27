# GH Alerter

A native macOS menu bar app that tracks GitHub review requests and pull request approvals through the GitHub CLI.

## Features

- Watch repositories or organizations for review activity.
- View detected events in a menu bar inbox.
- Configure polling intervals and separate sounds for review requests and approvals.
- Enable launch at login from the app's settings.

## Requirements

- macOS 13 or later.
- Swift 5.9 or later, supplied by a compatible Xcode installation or command line tools.
- [GitHub CLI](https://cli.github.com/), authenticated with access to the repositories you want to watch.

## Build and run

```sh
git clone https://github.com/adomorn/gh-alerter.git
cd gh-alerter
gh auth status
swift build
swift test
bash scripts/build-app.sh
open dist/GHAlerter.app
```

If GitHub CLI is not authenticated, run `gh auth login` first. For organization repositories, your existing GitHub access and any required SSO authorization must also be valid.

The build script creates a local app bundle. Signing and notarization are separate distribution steps; a local build is not a signed release.

Open Settings from the menu bar app to configure watched scopes, polling, and notification sounds. Allow notifications in macOS when prompted.

## Project layout

- `Sources/GHAlerterApp`: SwiftUI/AppKit application and bundled resources.
- `Sources/GHAlerterCore`: GitHub CLI integration, polling, event detection, and settings.
- `Tests/GHAlerterCoreTests`: unit tests for the core behavior.
- `scripts/build-app.sh`: local application bundle creation.
- `scripts/build-signed-dmg.sh`: distribution packaging for a configured signing environment.

## Contributing

Include the macOS and Swift versions, expected behavior, and reproduction steps in bug reports. Run `swift test` before submitting a change. Remove repository-sensitive data and credentials from logs before sharing them.

See [SECURITY.md](SECURITY.md) for security reporting and [NOTICE.md](NOTICE.md) for bundled sound provenance. The repository does not currently declare a project-wide license.
