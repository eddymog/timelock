import XCTest
@testable import Timelock

@MainActor
final class ErrorCenterTests: XCTestCase {
    private struct Boom: LocalizedError {
        var errorDescription: String? { "disk on fire" }
    }

    func testReportPublishesMessageWithContext() {
        let errors = ErrorCenter()
        errors.report(Boom(), while: "Saving the session")
        XCTAssertEqual(errors.current?.message, "Saving the session failed: disk on fire")
    }

    func testDismissClearsCurrentError() {
        let errors = ErrorCenter()
        errors.report(Boom(), while: "Saving")
        errors.dismiss()
        XCTAssertNil(errors.current)
    }

    func testPerformReportsThrownErrorAndReturnsFalse() {
        let errors = ErrorCenter()
        let ok = errors.perform("Saving") { throw Boom() }
        XCTAssertFalse(ok)
        XCTAssertNotNil(errors.current)
    }

    func testPerformSucceedsSilently() {
        let errors = ErrorCenter()
        XCTAssertTrue(errors.perform("Saving") {})
        XCTAssertNil(errors.current)
    }
}
