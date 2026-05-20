import XCTest
@testable import GHAlerterCore

final class WatchedScopeTests: XCTestCase {
    func testExactRepoScopeMatchesOnlyThatRepo() throws {
        let scope = try WatchedScope(rawValue: "owner/repo")

        XCTAssertTrue(scope.matches(owner: "owner", repo: "repo"))
        XCTAssertFalse(scope.matches(owner: "owner", repo: "other"))
        XCTAssertFalse(scope.matches(owner: "other", repo: "repo"))
    }

    func testOwnerWildcardMatchesAnyRepoUnderOwner() throws {
        let scope = try WatchedScope(rawValue: "example-org/*")

        XCTAssertTrue(scope.matches(owner: "example-org", repo: "backend"))
        XCTAssertTrue(scope.matches(owner: "example-org", repo: "frontend"))
        XCTAssertFalse(scope.matches(owner: "someone", repo: "backend"))
    }

    func testMalformedScopeIsRejected() {
        XCTAssertThrowsError(try WatchedScope(rawValue: "owner"))
        XCTAssertThrowsError(try WatchedScope(rawValue: "owner/repo/extra"))
        XCTAssertThrowsError(try WatchedScope(rawValue: "/repo"))
        XCTAssertThrowsError(try WatchedScope(rawValue: "owner/"))
    }
}
