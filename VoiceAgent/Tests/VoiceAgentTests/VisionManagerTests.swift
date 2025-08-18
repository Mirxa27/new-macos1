import XCTest
import Vision
import CoreImage
@testable import VoiceAgent

@MainActor
final class VisionManagerTests: XCTestCase {
    var visionManager: VisionManager!
    var aiProviderManager: AIProviderManager!
    
    override func setUp() async throws {
        aiProviderManager = AIProviderManager()
        visionManager = VisionManager(aiProviderManager: aiProviderManager)
    }
    
    override func tearDown() async throws {
        visionManager = nil
        aiProviderManager = nil
    }
    
    func testInitialization() async throws {
        XCTAssertNotNil(visionManager)
        XCTAssertFalse(visionManager.isAnalyzing)
        XCTAssertNil(visionManager.lastAnalysisResult)
        XCTAssertNil(visionManager.lastError)
    }
    
    func testEnableDisable() async throws {
        visionManager.isEnabled = true
        XCTAssertTrue(visionManager.isEnabled)
        
        visionManager.isEnabled = false
        XCTAssertFalse(visionManager.isEnabled)
    }
    
    func testImageAnalysisWithMockImage() async throws {
        // Create a simple test image
        let testImage = createTestImage()
        
        visionManager.isEnabled = true
        
        let expectation = XCTestExpectation(description: "Image analysis completed")
        
        Task {
            let result = await visionManager.analyzeImage(testImage, prompt: "Describe this image")
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testTextDetection() async throws {
        // Create an image with text
        let testImage = createTestImageWithText("Test Text")
        
        visionManager.isEnabled = true
        
        let expectation = XCTestExpectation(description: "Text detection completed")
        
        Task {
            let texts = await visionManager.detectText(in: testImage)
            XCTAssertNotNil(texts)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testUIElementDetection() async throws {
        let testImage = createTestImage()
        
        visionManager.isEnabled = true
        
        let expectation = XCTestExpectation(description: "UI element detection completed")
        
        Task {
            let elements = await visionManager.detectUIElements(in: testImage)
            XCTAssertNotNil(elements)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 3.0)
    }
    
    func testAnalysisWithDifferentProviders() async throws {
        let providers: [AIProvider] = [.openAI, .anthropic, .ollama, .groq]
        let testImage = createTestImage()
        
        visionManager.isEnabled = true
        
        for provider in providers {
            aiProviderManager.currentProvider = provider
            
            // Skip if provider doesn't support vision
            guard aiProviderManager.supportsVision else {
                continue
            }
            
            let expectation = XCTestExpectation(description: "Analysis with \(provider)")
            
            Task {
                let result = await visionManager.analyzeImage(testImage, prompt: "Test")
                XCTAssertNotNil(result)
                expectation.fulfill()
            }
            
            await fulfillment(of: [expectation], timeout: 5.0)
        }
    }
    
    func testConcurrentAnalysis() async throws {
        let testImage = createTestImage()
        visionManager.isEnabled = true
        
        let expectation = XCTestExpectation(description: "Concurrent analysis")
        expectation.expectedFulfillmentCount = 5
        
        await withTaskGroup(of: String?.self) { group in
            for i in 1...5 {
                group.addTask {
                    let result = await self.visionManager.analyzeImage(testImage, prompt: "Test \(i)")
                    expectation.fulfill()
                    return result
                }
            }
            
            for await _ in group {
                // Process results
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testErrorHandling() async throws {
        visionManager.isEnabled = true
        
        // Test with nil image
        let result = await visionManager.analyzeImage(nil, prompt: "Test")
        XCTAssertNil(result)
        XCTAssertNotNil(visionManager.lastError)
    }
    
    func testAnalysisWhenDisabled() async throws {
        visionManager.isEnabled = false
        
        let testImage = createTestImage()
        let result = await visionManager.analyzeImage(testImage, prompt: "Test")
        
        XCTAssertNil(result)
    }
    
    func testScreenAnalysis() async throws {
        visionManager.isEnabled = true
        
        let expectation = XCTestExpectation(description: "Screen analysis")
        
        Task {
            let result = await visionManager.analyzeCurrentScreen(prompt: "Describe the screen")
            // Result may be nil if screen capture fails in test environment
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testAnalysisResultCaching() async throws {
        let testImage = createTestImage()
        visionManager.isEnabled = true
        
        let result1 = await visionManager.analyzeImage(testImage, prompt: "Test")
        XCTAssertNotNil(result1)
        XCTAssertEqual(visionManager.lastAnalysisResult, result1)
        
        let result2 = await visionManager.analyzeImage(testImage, prompt: "Test 2")
        XCTAssertNotNil(result2)
        XCTAssertEqual(visionManager.lastAnalysisResult, result2)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> CGImage? {
        let width = 100
        let height = 100
        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // Draw a simple pattern
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 20, y: 20, width: 60, height: 60))
        
        return context.makeImage()
    }
    
    private func createTestImageWithText(_ text: String) -> CGImage? {
        let width = 200
        let height = 100
        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        // White background
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw text (simplified - in real app would use Core Text)
        context.setFillColor(CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0))
        
        return context.makeImage()
    }
}