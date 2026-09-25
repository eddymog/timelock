import XCTest
@testable import Timelock

final class HexColorTests: XCTestCase {

    func testParsesValidHex() throws {
        let red = try XCTUnwrap(HexColor.rgb("#FF0000"))
        XCTAssertEqual(red.red, 1, accuracy: 0.001)
        XCTAssertEqual(red.green, 0, accuracy: 0.001)
        let mid = try XCTUnwrap(HexColor.rgb("336699"))   // '#' optional
        XCTAssertEqual(mid.red, 0x33 / 255.0, accuracy: 0.001)
        XCTAssertEqual(mid.blue, 0x99 / 255.0, accuracy: 0.001)
    }

    func testRejectsInvalidHex() {
        for bad in ["", "#FFF", "#GG0000", "#12345678", "red"] {
            XCTAssertNil(HexColor.rgb(bad), bad)
        }
    }

    func testFormatsHex() {
        XCTAssertEqual(HexColor.hex(red: 1, green: 0.5, blue: 0), "#FF8000")
    }
}
