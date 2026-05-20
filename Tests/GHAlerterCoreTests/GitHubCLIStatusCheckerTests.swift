import XCTest
@testable import GHAlerterCore

final class GitHubCLIStatusCheckerTests: XCTestCase {
    func testReadyStatusUsesLoggedInLineWhenAvailable() async {
        let checker = GitHubCLIStatusChecker(cli: StubCLI(output: """
        github.com
          ✓ Logged in to github.com account adomorn
        """))

        let status = await checker.check()

        XCTAssertEqual(status, .ready(message: "✓ Logged in to github.com account adomorn"))
    }

    func testMissingExecutableMapsToMissingStatus() async {
        let checker = GitHubCLIStatusChecker(cli: StubCLI(error: GitHubCLIError.missingExecutable))

        let status = await checker.check()

        XCTAssertEqual(status, .missing)
    }

    func testAuthenticationFailureMapsToUnauthenticatedStatus() async {
        let checker = GitHubCLIStatusChecker(
            cli: StubCLI(error: GitHubCLIError.commandFailed(status: 1, stderr: "not logged into any GitHub hosts"))
        )

        let status = await checker.check()

        XCTAssertEqual(status, .unauthenticated)
    }

    func testSSOFailureMapsToAccessNeedsAuthorizationStatus() async {
        let checker = GitHubCLIStatusChecker(
            cli: StubCLI(error: GitHubCLIError.commandFailed(status: 1, stderr: "SAML SSO authorization is required"))
        )

        let status = await checker.check()

        XCTAssertEqual(status, .accessNeedsAuthorization)
    }
}

private struct StubCLI: GitHubCLIExecuting {
    let output: String
    let error: Error?

    init(output: String = "", error: Error? = nil) {
        self.output = output
        self.error = error
    }

    func run(arguments: [String]) async throws -> String {
        XCTAssertEqual(arguments, ["auth", "status", "-a"])
        if let error {
            throw error
        }

        return output
    }
}
