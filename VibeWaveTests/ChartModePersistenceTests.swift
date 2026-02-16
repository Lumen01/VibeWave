import XCTest
import GRDB
@testable import VibeWave

@MainActor
final class ChartModePersistenceTests: XCTestCase {
    private var dbPool: DatabasePool!
    private let inputModeKey = "history.inputTokens.chartMode"
    private let sessionsModeKey = "history.sessions.chartMode"
    private let usageSectionModeKey = "history.usageSection.chartMode"
    private let activitySectionModeKey = "history.activitySection.chartMode"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: inputModeKey)
        UserDefaults.standard.removeObject(forKey: sessionsModeKey)
        UserDefaults.standard.removeObject(forKey: usageSectionModeKey)
        UserDefaults.standard.removeObject(forKey: activitySectionModeKey)
        dbPool = try! DatabasePool(path: ":memory:")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: inputModeKey)
        UserDefaults.standard.removeObject(forKey: sessionsModeKey)
        UserDefaults.standard.removeObject(forKey: usageSectionModeKey)
        UserDefaults.standard.removeObject(forKey: activitySectionModeKey)
        dbPool = nil
        super.tearDown()
    }

    func testDefaultModeIsBarWhenNoPersistedValue() {
        let viewModel = HistoryViewModel(dbPool: dbPool)
        XCTAssertEqual(viewModel.inputTokensChartMode, .bar)
        XCTAssertEqual(viewModel.usageSectionChartMode, .bar)
        XCTAssertEqual(viewModel.activitySectionChartMode, .bar)
    }

    func testPersistedModeIsLoaded() {
        UserDefaults.standard.set(ChartDisplayMode.line.rawValue, forKey: inputModeKey)
        UserDefaults.standard.set(ChartDisplayMode.line.rawValue, forKey: usageSectionModeKey)
        UserDefaults.standard.set(ChartDisplayMode.line.rawValue, forKey: activitySectionModeKey)

        let viewModel = HistoryViewModel(dbPool: dbPool)

        XCTAssertEqual(viewModel.inputTokensChartMode, .line)
        XCTAssertEqual(viewModel.usageSectionChartMode, .line)
        XCTAssertEqual(viewModel.activitySectionChartMode, .line)
    }

    func testModeChangePersistsToUserDefaults() {
        let viewModel = HistoryViewModel(dbPool: dbPool)

        viewModel.inputTokensChartMode = .line
        viewModel.usageSectionChartMode = .line
        viewModel.activitySectionChartMode = .line

        XCTAssertEqual(UserDefaults.standard.string(forKey: inputModeKey), ChartDisplayMode.line.rawValue)
        XCTAssertEqual(UserDefaults.standard.string(forKey: usageSectionModeKey), ChartDisplayMode.line.rawValue)
        XCTAssertEqual(UserDefaults.standard.string(forKey: activitySectionModeKey), ChartDisplayMode.line.rawValue)
    }

    func testUsageSectionModeFallsBackToLegacyInputModeKey() {
        UserDefaults.standard.set(ChartDisplayMode.line.rawValue, forKey: inputModeKey)

        let viewModel = HistoryViewModel(dbPool: dbPool)

        XCTAssertEqual(viewModel.usageSectionChartMode, .line)
    }

    func testActivitySectionModeFallsBackToLegacySessionsModeKey() {
        UserDefaults.standard.set(ChartDisplayMode.line.rawValue, forKey: sessionsModeKey)

        let viewModel = HistoryViewModel(dbPool: dbPool)

        XCTAssertEqual(viewModel.activitySectionChartMode, .line)
    }

    func testNewSectionModeKeyOverridesLegacyKey() {
        UserDefaults.standard.set(ChartDisplayMode.bar.rawValue, forKey: inputModeKey)
        UserDefaults.standard.set(ChartDisplayMode.line.rawValue, forKey: usageSectionModeKey)

        let viewModel = HistoryViewModel(dbPool: dbPool)

        XCTAssertEqual(viewModel.usageSectionChartMode, .line)
    }
}
