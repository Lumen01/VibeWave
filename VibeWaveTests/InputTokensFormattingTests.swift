import XCTest
@testable import VibeWave

final class InputTokensFormattingTests: XCTestCase {
    func testFormatsMillions() {
        XCTAssertEqual(formatInputTokensCompact(2_500_000), "2.5M")
        XCTAssertEqual(formatInputTokensCompact(3_000_000), "3M")
    }

    func testFormatsThousands() {
        XCTAssertEqual(formatInputTokensCompact(1_500), "1.5K")
        XCTAssertEqual(formatInputTokensCompact(2_000), "2K")
    }

    func testFormatsSmallValues() {
        XCTAssertEqual(formatInputTokensCompact(999), "999")
        XCTAssertEqual(formatInputTokensCompact(0), "0")
    }
}
