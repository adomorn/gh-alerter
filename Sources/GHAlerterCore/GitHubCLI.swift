import Foundation

public enum GitHubCLIError: Error, Equatable {
    case missingExecutable
    case commandFailed(status: Int32, stderr: String)
    case invalidUTF8Output

    public var userMessage: String {
        switch self {
        case .missingExecutable:
            return "GitHub CLI is not installed or could not be found."
        case .commandFailed(_, let stderr) where Self.isAuthenticationFailure(stderr):
            return "GitHub CLI is not authenticated. Run gh auth login."
        case .commandFailed(_, let stderr) where Self.isPermissionOrSSOFailure(stderr):
            return "GitHub CLI does not have permission for this resource. Check SSO authorization and repository access."
        case .commandFailed(_, let stderr):
            return stderr.isEmpty ? "GitHub CLI command failed." : stderr
        case .invalidUTF8Output:
            return "GitHub CLI returned unreadable output."
        }
    }

    public static func isAuthenticationFailure(_ stderr: String) -> Bool {
        let authFailures = [
            "not logged",
            "authentication required",
            "http 401",
            "bad credentials"
        ]

        return authFailures.contains { stderr.localizedCaseInsensitiveContains($0) }
    }

    public static func isPermissionOrSSOFailure(_ stderr: String) -> Bool {
        let permissionFailures = [
            "saml",
            "sso",
            "permission",
            "forbidden",
            "http 403"
        ]

        return permissionFailures.contains { stderr.localizedCaseInsensitiveContains($0) }
    }
}

public protocol GitHubCLIExecuting {
    func run(arguments: [String]) async throws -> String
}

public struct GitHubCLI: GitHubCLIExecuting {
    public static let defaultCommonSearchPaths = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/Users/aterekeci/usr/local/bin/gh",
        "/usr/bin/gh"
    ]

    private let explicitExecutableURL: URL?
    private let environment: [String: String]
    private let commonSearchPaths: [String]

    public init(
        executableURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        commonSearchPaths: [String] = GitHubCLI.defaultCommonSearchPaths
    ) {
        self.explicitExecutableURL = executableURL
        self.environment = environment
        self.commonSearchPaths = commonSearchPaths
    }

    public func run(arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            try await Self.runBlocking(
                arguments: arguments,
                explicitExecutableURL: explicitExecutableURL,
                environment: environment,
                commonSearchPaths: commonSearchPaths
            )
        }.value
    }

    private static func runBlocking(
        arguments: [String],
        explicitExecutableURL: URL?,
        environment: [String: String],
        commonSearchPaths: [String]
    ) async throws -> String {
        let process = Process()
        process.executableURL = try resolveExecutable(
            explicitExecutableURL: explicitExecutableURL,
            environment: environment,
            commonSearchPaths: commonSearchPaths
        )
        process.arguments = arguments

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
        } catch {
            throw GitHubCLIError.missingExecutable
        }

        async let outputData = readData(from: output.fileHandleForReading)
        async let errorData = readData(from: error.fileHandleForReading)

        process.waitUntilExit()

        let stdoutData = await outputData
        let stderrData = await errorData

        guard let stdout = String(data: stdoutData, encoding: .utf8),
              let stderr = String(data: stderrData, encoding: .utf8) else {
            throw GitHubCLIError.invalidUTF8Output
        }

        guard process.terminationStatus == 0 else {
            throw GitHubCLIError.commandFailed(
                status: process.terminationStatus,
                stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return stdout
    }

    private static func resolveExecutable(
        explicitExecutableURL: URL?,
        environment: [String: String],
        commonSearchPaths: [String]
    ) throws -> URL {
        if let explicitExecutableURL {
            guard FileManager.default.isExecutableFile(atPath: explicitExecutableURL.path) else {
                throw GitHubCLIError.missingExecutable
            }

            return explicitExecutableURL
        }

        let pathCandidates = environment["PATH", default: ""]
            .split(separator: ":", omittingEmptySubsequences: true)
            .map { String($0) }
            .map { URL(fileURLWithPath: $0).appendingPathComponent("gh").path }

        for candidate in pathCandidates + commonSearchPaths where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        throw GitHubCLIError.missingExecutable
    }

    private static func readData(from fileHandle: FileHandle) async -> Data {
        await Task.detached(priority: .utility) {
            fileHandle.readDataToEndOfFile()
        }.value
    }
}
