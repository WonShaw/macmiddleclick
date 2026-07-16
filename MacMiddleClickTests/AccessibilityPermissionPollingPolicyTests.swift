import XCTest
@testable import MacMiddleClick

final class AccessibilityPermissionPollingPolicyTests: XCTestCase {
    func testUntrustedStateUsesFrequentChecks() {
        XCTAssertEqual(
            AccessibilityPermissionPollingPolicy.schedule(isTrusted: false),
            .init(interval: 2, tolerance: 0.2)
        )
    }

    func testTrustedStateUsesLowFrequencyChecks() {
        XCTAssertEqual(
            AccessibilityPermissionPollingPolicy.schedule(isTrusted: true),
            .init(interval: 60, tolerance: 5)
        )
    }
}
