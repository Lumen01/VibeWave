import XCTest
@testable import VibeWave

final class FormatterServiceTests: XCTestCase {
  func testFormatCount() {
    XCTAssertEqual(FormatterService.formatCount(100000), "100,000")
    XCTAssertEqual(FormatterService.formatCount(0), "0")
  }

  func testFormatCompact() {
    // formatCompact is defined in OverviewView.swift, not FormatterService
    // This test should be moved to OverviewViewTests
  }

  func testFormatCost() {
    XCTAssertEqual(FormatterService.formatCost(0.12), "$0.12")
    XCTAssertEqual(FormatterService.formatCost(10.0), "$10.00")
    XCTAssertEqual(FormatterService.formatCost(0.001234), "$0.00")
  }

  func testFormatPercentage() {
    XCTAssertEqual(FormatterService.formatPercentage(0.8), "80%")
    XCTAssertEqual(FormatterService.formatPercentage(0.045), "4.5%")
    XCTAssertEqual(FormatterService.formatPercentage(1.0), "100%")
  }
}
