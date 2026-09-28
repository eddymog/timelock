import XCTest
@testable import Timelock

final class DomainNormalizerTests: XCTestCase {
    func testNormalizesURLsAndDomains() {
        let cases: [(String, String)] = [
            ("https://www.YouTube.com/watch?v=1", "youtube.com"),
            ("youtube.com", "youtube.com"),
            ("sub.example.co.uk", "sub.example.co.uk"),
            ("HTTP://EXAMPLE.COM:8080/path", "example.com"),
            ("  example.com/path  ", "example.com"),
        ]

        for (input, expected) in cases {
            XCTAssertEqual(DomainNormalizer.normalize(input), expected, input)
        }
    }

    func testRejectsInvalidDomains() {
        let invalid = ["", "garbage", "a b.com", "x;rm.com", "https://", "-bad.com", "bad-.com", "user@example.com", "ftp://example.com"]

        for input in invalid {
            XCTAssertNil(DomainNormalizer.normalize(input), input)
        }
    }

    func testExpansionAddsWWWAndRemovesDuplicates() {
        XCTAssertEqual(
            DomainNormalizer.expanded(["youtube.com", "youtube.com", "www.youtube.com"]),
            ["youtube.com", "www.youtube.com"]
        )
    }
}
