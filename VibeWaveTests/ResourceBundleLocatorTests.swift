import XCTest
@testable import VibeWave

final class ResourceBundleLocatorTests: XCTestCase {
  func testLocateBundle_findsBundleInAppContentsResources() throws {
    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let appBundleURL = tempRoot.appendingPathComponent("VibeWave.app", isDirectory: true)
    let resourcesURL = appBundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("Resources", isDirectory: true)
    let resourceBundleURL = resourcesURL.appendingPathComponent("VibeWave_VibeWave.bundle", isDirectory: true)
    try FileManager.default.createDirectory(at: resourceBundleURL, withIntermediateDirectories: true)

    let bundle = ResourceBundleLocator.locateBundle(
      in: [appBundleURL],
      bundleName: "VibeWave_VibeWave"
    )

    XCTAssertNotNil(bundle)
    XCTAssertEqual(bundle?.bundleURL.lastPathComponent, "VibeWave_VibeWave.bundle")
  }
}
