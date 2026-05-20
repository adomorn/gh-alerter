import XCTest
@testable import GHAlerterCore

final class LaunchAtLoginServiceTests: XCTestCase {
    func testUnavailableMessageIsStable() {
        XCTAssertEqual(LaunchAtLoginService.unavailableMessage, "Launch at login is unavailable in this build.")
    }

    func testErrorUserMessagesAreStable() {
        XCTAssertEqual(
            LaunchAtLoginError.unavailable(LaunchAtLoginService.unavailableMessage).userMessage,
            "Launch at login is unavailable in this build."
        )
        XCTAssertEqual(
            LaunchAtLoginError.requiresApproval.userMessage,
            "Launch at login requires approval in System Settings."
        )
    }

    func testEnableDecisionReturnsAlreadyEnabledWithoutRegistering() throws {
        XCTAssertEqual(
            try LaunchAtLoginService.decision(forEnabled: true, currentStatus: .enabled),
            .returnWithoutMutation
        )
    }

    func testEnableDecisionThrowsWhenApprovalIsRequired() {
        XCTAssertThrowsError(try LaunchAtLoginService.decision(forEnabled: true, currentStatus: .requiresApproval)) { error in
            XCTAssertEqual(error as? LaunchAtLoginError, .requiresApproval)
        }
    }

    func testEnableDecisionRegistersWhenNotRegistered() throws {
        XCTAssertEqual(
            try LaunchAtLoginService.decision(forEnabled: true, currentStatus: .notRegistered),
            .register
        )
    }

    func testEnableDecisionRegistersForOtherStatuses() throws {
        XCTAssertEqual(
            try LaunchAtLoginService.decision(forEnabled: true, currentStatus: .other),
            .register
        )
    }

    func testDisableDecisionReturnsAlreadyNotRegisteredWithoutUnregistering() throws {
        XCTAssertEqual(
            try LaunchAtLoginService.decision(forEnabled: false, currentStatus: .notRegistered),
            .returnWithoutMutation
        )
    }

    func testDisableDecisionUnregistersWhenEnabledOrRequiresApproval() throws {
        XCTAssertEqual(
            try LaunchAtLoginService.decision(forEnabled: false, currentStatus: .enabled),
            .unregister
        )
        XCTAssertEqual(
            try LaunchAtLoginService.decision(forEnabled: false, currentStatus: .requiresApproval),
            .unregister
        )
    }

    func testDisableDecisionUnregistersForOtherStatuses() throws {
        XCTAssertEqual(
            try LaunchAtLoginService.decision(forEnabled: false, currentStatus: .other),
            .unregister
        )
    }
}
