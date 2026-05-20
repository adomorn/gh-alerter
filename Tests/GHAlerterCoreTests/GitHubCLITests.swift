import XCTest
@testable import GHAlerterCore

final class GitHubCLITests: XCTestCase {
    func testMapsMissingExecutable() {
        let error = GitHubCLIError.missingExecutable
        XCTAssertEqual(error.userMessage, "GitHub CLI is not installed or could not be found.")
    }

    func testMapsUnauthenticatedOutput() {
        let error = GitHubCLIError.commandFailed(status: 1, stderr: "You are not logged into any GitHub hosts")
        XCTAssertEqual(error.userMessage, "GitHub CLI is not authenticated. Run gh auth login.")
    }

    func testMapsAdditionalAuthenticationFailures() {
        let messages = [
            "authentication required",
            "HTTP 401",
            "Bad credentials"
        ]

        for message in messages {
            let error = GitHubCLIError.commandFailed(status: 1, stderr: message)
            XCTAssertEqual(error.userMessage, "GitHub CLI is not authenticated. Run gh auth login.")
        }
    }

    func testMapsSSOAndPermissionFailures() {
        let messages = [
            "SAML SSO authorization is required",
            "Resource protected by organization SSO",
            "permission denied"
        ]

        for message in messages {
            let error = GitHubCLIError.commandFailed(status: 1, stderr: message)
            XCTAssertEqual(error.userMessage, "GitHub CLI does not have permission for this resource. Check SSO authorization and repository access.")
        }
    }

    func testSuccessfulStdoutReturnsExpectedOutput() async throws {
        let executable = try makeExecutableScript(named: "gh", contents: """
        #!/bin/sh
        printf 'expected output\\n'
        """)
        let cli = GitHubCLI(executableURL: executable)

        let output = try await cli.run(arguments: ["ignored"])

        XCTAssertEqual(output, "expected output\n")
    }

    func testNonzeroExitTrimsStderrIntoCommandFailed() async throws {
        let executable = try makeExecutableScript(named: "gh", contents: """
        #!/bin/sh
        printf '  failed with spaces  \\n' >&2
        exit 7
        """)
        let cli = GitHubCLI(executableURL: executable)

        do {
            _ = try await cli.run(arguments: [])
            XCTFail("Expected commandFailed")
        } catch let error as GitHubCLIError {
            XCTAssertEqual(error, .commandFailed(status: 7, stderr: "failed with spaces"))
        }
    }

    func testMissingExecutableMapsToMissingExecutable() async throws {
        let missingURL = try makeTemporaryDirectory().appendingPathComponent("missing-gh")
        let cli = GitHubCLI(executableURL: missingURL)

        do {
            _ = try await cli.run(arguments: [])
            XCTFail("Expected missingExecutable")
        } catch let error as GitHubCLIError {
            XCTAssertEqual(error, .missingExecutable)
        }
    }

    func testMissingResolvedGHMapsToMissingExecutable() async throws {
        let cli = GitHubCLI(environment: ["PATH": ""], commonSearchPaths: [])

        do {
            _ = try await cli.run(arguments: [])
            XCTFail("Expected missingExecutable")
        } catch let error as GitHubCLIError {
            XCTAssertEqual(error, .missingExecutable)
        }
    }

    func testResolvesGHFromPATHAndPassesArgumentsDirectly() async throws {
        let directory = try makeTemporaryDirectory()
        _ = try makeExecutableScript(named: "gh", in: directory, contents: """
        #!/bin/sh
        printf '%s %s\\n' "$1" "$2"
        """)
        let cli = GitHubCLI(environment: ["PATH": directory.path], commonSearchPaths: [])

        let output = try await cli.run(arguments: ["api", "user"])

        XCTAssertEqual(output, "api user\n")
    }

    func testLargeStdoutAndStderrDoNotDeadlock() async throws {
        let executable = try makeExecutableScript(named: "gh", contents: """
        #!/bin/sh
        /usr/bin/yes x | /usr/bin/head -c 262144
        /usr/bin/yes y | /usr/bin/head -c 262144 >&2
        """)
        let cli = GitHubCLI(executableURL: executable)

        let output = try await cli.run(arguments: [])

        XCTAssertEqual(output.utf8.count, 262_144)
    }

    private func makeExecutableScript(named name: String, contents: String) throws -> URL {
        try makeExecutableScript(named: name, in: makeTemporaryDirectory(), contents: contents)
    }

    private func makeExecutableScript(named name: String, in directory: URL, contents: String) throws -> URL {
        let scriptURL = directory.appendingPathComponent(name)
        try contents.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GHAlerterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory
    }
}
