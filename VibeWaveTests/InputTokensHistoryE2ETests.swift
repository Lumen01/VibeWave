import XCTest
@testable import VibeWave
import GRDB
import Combine

/// End-to-end tests for Input Tokens History Chart integration
@MainActor
final class InputTokensHistoryE2ETests: XCTestCase {
    var viewModel: HistoryViewModel!
    var dbPool: DatabasePool!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory database
        dbPool = try! DatabasePool(path: ":memory:")
        
        // Initialize HistoryViewModel with database
        // Use Task to access MainActor safely
        let expectation = XCTestExpectation(description: "ViewModel initialized")
        Task { @MainActor in
            self.viewModel = HistoryViewModel(dbPool: self.dbPool)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    override func tearDown() {
        cancellables.removeAll()
        
        // Clean up on main actor
        let expectation = XCTestExpectation(description: "Cleanup complete")
        Task { @MainActor in
            self.viewModel = nil
            self.dbPool = nil
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testInputTokensChartView_InitialState_DisplaysNoData() {
        // Given: Empty database
        // When: View loaded
        // Then: Should show empty data array
        
        XCTAssertTrue(viewModel.inputTokensData.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    func testLoadInputTokensHistory_SetsIsLoadingToFalseAfterComplete() {
        // Given: HistoryViewModel initialized
        // When: loadInputTokensHistory called
        // Then: isLoading should eventually be false
        
        let expectation = XCTestExpectation(description: "isLoading becomes false")
        
        viewModel.$isLoading
            .dropFirst() // Skip initial value
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.loadInputTokensHistory()
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testInputTokensData_PlaceholderAfterLoadingWithEmptyDatabase() {
        // Given: Empty database
        // When: loadInputTokensHistory completes
        // Then: inputTokensData should be placeholder points
        
        let expectation = XCTestExpectation(description: "loading completes")
        
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.loadInputTokensHistory()
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(viewModel.inputTokensData.count, 30, "Default range should render 30 placeholder points")
        XCTAssertTrue(viewModel.inputTokensData.allSatisfy { $0.totalTokens == 0 })
    }
    
    func testTimeRangeChange_TriggersReload() {
        // Given: Initial time range loaded
        // When: Changing selectedTimeRange
        // Then: inputTokensData should be reloaded
        
        // Change time range
        viewModel.selectedTimeRange = .last24Hours
        
        // The change should trigger loadInputTokensHistory automatically due to didSet
        // We'll verify this by checking isLoading transitions
        let expectation = XCTestExpectation(description: "isLoading transitions occur")
        
        var isLoadingStates: [Bool] = []
        
        viewModel.$isLoading
            .sink { isLoading in
                isLoadingStates.append(isLoading)
                
                // Wait for loading to complete
                if isLoadingStates.count >= 2 && !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 3.0)
        
        // Should have gone from false -> true -> false
        XCTAssertEqual(isLoadingStates.count, 3)
        XCTAssertEqual(isLoadingStates[0], false) // Initial
        XCTAssertEqual(isLoadingStates[1], true)  // Loading started
        XCTAssertEqual(isLoadingStates[2], false) // Loading completed
    }
}
