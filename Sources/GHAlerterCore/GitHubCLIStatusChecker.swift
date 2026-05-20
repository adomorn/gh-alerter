import Foundation

public enum GitHubCLIStatus: Equatable {
    case ready(message: String)
    case missing
    case unauthenticated
    case accessNeedsAuthorization
    case failed(message: String)

    public var title: String {
        switch self {
        case .ready:
            return "Ready"
        case .missing:
            return "GitHub CLI is not installed"
        case .unauthenticated:
            return "GitHub CLI is not authenticated"
        case .accessNeedsAuthorization:
            return "GitHub access needs authorization"
        case .failed:
            return "GitHub CLI check failed"
        }
    }

    public var detail: String {
        switch self {
        case .ready(let message):
            return message
        case .missing:
            return "Install GitHub CLI, then authenticate it before using GH Alerter."
        case .unauthenticated:
            return "Run gh auth login in Terminal."
        case .accessNeedsAuthorization:
            return "Run gh auth refresh -s repo,read:org and authorize organization SSO if prompted."
        case .failed(let message):
            return message
        }
    }
}

public struct GitHubCLIStatusChecker {
    private let cli: any GitHubCLIExecuting

    public init(cli: any GitHubCLIExecuting = GitHubCLI()) {
        self.cli = cli
    }

    public func check() async -> GitHubCLIStatus {
        do {
            let output = try await cli.run(arguments: ["auth", "status", "-a"])
            return .ready(message: readyMessage(from: output))
        } catch GitHubCLIError.missingExecutable {
            return .missing
        } catch GitHubCLIError.commandFailed(_, let stderr)
            where GitHubCLIError.isAuthenticationFailure(stderr) {
            return .unauthenticated
        } catch GitHubCLIError.commandFailed(_, let stderr)
            where GitHubCLIError.isPermissionOrSSOFailure(stderr) {
            return .accessNeedsAuthorization
        } catch let error as GitHubCLIError {
            return .failed(message: error.userMessage)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    private func readyMessage(from output: String) -> String {
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.localizedCaseInsensitiveContains("logged in to") {
                return trimmed
            }
        }

        return "GitHub CLI is installed and authenticated."
    }
}
