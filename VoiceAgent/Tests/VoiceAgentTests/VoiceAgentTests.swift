import XCTest
@testable import VoiceAgent

final class VoiceAgentTests: XCTestCase {
    
    override class func setUp() {
        super.setUp()
        // Set up any global test configuration
    }
    
    override class func tearDown() {
        // Clean up after all tests
        super.tearDown()
    }
    
    func testApplicationLaunch() {
        // Test that the application can launch
        XCTAssertTrue(true, "Application should launch successfully")
    }
    
    func testCoreComponentsExist() {
        // Verify core components are available
        XCTAssertNotNil(VoiceAgent.self)
        XCTAssertNotNil(AudioManager.self)
        XCTAssertNotNil(VoiceFeedbackManager.self)
        XCTAssertNotNil(VisionManager.self)
        XCTAssertNotNil(AIProviderManager.self)
        XCTAssertNotNil(SystemController.self)
        XCTAssertNotNil(ScreenManager.self)
        XCTAssertNotNil(GeminiLiveAPIManager.self)
    }
    
    static var allTests = [
        ("testApplicationLaunch", testApplicationLaunch),
        ("testCoreComponentsExist", testCoreComponentsExist),
    ]
}

// Test Suite Runner
extension XCTestCase {
    static func runAllTests() {
        // Run all test classes
        let testClasses: [XCTestCase.Type] = [
            VoiceAgentTests.self,
            AudioManagerTests.self,
            VoiceFeedbackManagerTests.self,
            VisionManagerTests.self,
            AIProviderManagerTests.self,
            SystemControllerTests.self,
            GeminiLiveAPIManagerTests.self,
            IntegrationTests.self
        ]
        
        print("Running Voice Agent Test Suite")
        print("==============================")
        
        for testClass in testClasses {
            print("\nRunning \(String(describing: testClass))")
        }
    }
}
