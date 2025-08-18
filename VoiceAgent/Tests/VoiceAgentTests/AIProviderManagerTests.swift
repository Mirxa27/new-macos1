import XCTest
@testable import VoiceAgent

@MainActor
final class AIProviderManagerTests: XCTestCase {
    var aiProviderManager: AIProviderManager!
    
    override func setUp() async throws {
        aiProviderManager = AIProviderManager()
    }
    
    override func tearDown() async throws {
        aiProviderManager = nil
    }
    
    func testInitialization() async throws {
        XCTAssertNotNil(aiProviderManager)
        XCTAssertEqual(aiProviderManager.currentProvider, .openAI)
        XCTAssertFalse(aiProviderManager.isConfigured)
    }
    
    func testProviderSwitching() async throws {
        let providers: [AIProvider] = [.openAI, .anthropic, .ollama, .groq, .gemini]
        
        for provider in providers {
            aiProviderManager.currentProvider = provider
            XCTAssertEqual(aiProviderManager.currentProvider, provider)
        }
    }
    
    func testAPIKeyConfiguration() async throws {
        // Test OpenAI configuration
        aiProviderManager.currentProvider = .openAI
        aiProviderManager.openAIKey = "test-openai-key"
        XCTAssertEqual(aiProviderManager.openAIKey, "test-openai-key")
        XCTAssertTrue(aiProviderManager.isConfigured)
        
        // Test Anthropic configuration
        aiProviderManager.currentProvider = .anthropic
        aiProviderManager.anthropicKey = "test-anthropic-key"
        XCTAssertEqual(aiProviderManager.anthropicKey, "test-anthropic-key")
        XCTAssertTrue(aiProviderManager.isConfigured)
        
        // Test Groq configuration
        aiProviderManager.currentProvider = .groq
        aiProviderManager.groqKey = "test-groq-key"
        XCTAssertEqual(aiProviderManager.groqKey, "test-groq-key")
        XCTAssertTrue(aiProviderManager.isConfigured)
        
        // Test Gemini configuration
        aiProviderManager.currentProvider = .gemini
        aiProviderManager.geminiKey = "test-gemini-key"
        XCTAssertEqual(aiProviderManager.geminiKey, "test-gemini-key")
        XCTAssertTrue(aiProviderManager.isConfigured)
        
        // Test Ollama (no key required)
        aiProviderManager.currentProvider = .ollama
        XCTAssertTrue(aiProviderManager.isConfigured)
    }
    
    func testModelSelection() async throws {
        // Test OpenAI models
        aiProviderManager.currentProvider = .openAI
        let openAIModels = ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"]
        for model in openAIModels {
            aiProviderManager.openAIModel = model
            XCTAssertEqual(aiProviderManager.openAIModel, model)
        }
        
        // Test Anthropic models
        aiProviderManager.currentProvider = .anthropic
        let anthropicModels = ["claude-3-opus", "claude-3-sonnet", "claude-3-haiku"]
        for model in anthropicModels {
            aiProviderManager.anthropicModel = model
            XCTAssertEqual(aiProviderManager.anthropicModel, model)
        }
        
        // Test Ollama models
        aiProviderManager.currentProvider = .ollama
        let ollamaModels = ["llama2", "mistral", "codellama"]
        for model in ollamaModels {
            aiProviderManager.ollamaModel = model
            XCTAssertEqual(aiProviderManager.ollamaModel, model)
        }
        
        // Test Groq models
        aiProviderManager.currentProvider = .groq
        let groqModels = ["mixtral-8x7b", "llama2-70b"]
        for model in groqModels {
            aiProviderManager.groqModel = model
            XCTAssertEqual(aiProviderManager.groqModel, model)
        }
    }
    
    func testVisionSupport() async throws {
        aiProviderManager.currentProvider = .openAI
        aiProviderManager.openAIKey = "test-key"
        aiProviderManager.visionEnabled = true
        XCTAssertTrue(aiProviderManager.supportsVision)
        
        aiProviderManager.currentProvider = .anthropic
        aiProviderManager.anthropicKey = "test-key"
        aiProviderManager.visionEnabled = true
        XCTAssertTrue(aiProviderManager.supportsVision)
        
        aiProviderManager.currentProvider = .ollama
        aiProviderManager.visionEnabled = true
        XCTAssertTrue(aiProviderManager.supportsVision)
        
        // Groq doesn't support vision
        aiProviderManager.currentProvider = .groq
        aiProviderManager.visionEnabled = true
        XCTAssertFalse(aiProviderManager.supportsVision)
        
        // Test with vision disabled
        aiProviderManager.currentProvider = .openAI
        aiProviderManager.visionEnabled = false
        XCTAssertFalse(aiProviderManager.supportsVision)
    }
    
    func testProcessCommand() async throws {
        aiProviderManager.currentProvider = .openAI
        aiProviderManager.openAIKey = "test-key"
        
        // This will fail without a real API key, but we're testing the method exists
        let result = await aiProviderManager.processCommand("Test command", context: nil)
        
        // With a test key, we expect an error result
        XCTAssertNotNil(result)
    }
    
    func testProcessVisionCommand() async throws {
        aiProviderManager.currentProvider = .openAI
        aiProviderManager.openAIKey = "test-key"
        aiProviderManager.visionEnabled = true
        
        // Create a simple test image
        let testImage = createTestImage()
        
        let result = await aiProviderManager.processVisionCommand(
            "Describe this image",
            image: testImage,
            context: nil
        )
        
        // With a test key, we expect an error result
        XCTAssertNotNil(result)
    }
    
    func testOllamaURLConfiguration() async throws {
        aiProviderManager.currentProvider = .ollama
        
        let defaultURL = "http://localhost:11434"
        XCTAssertEqual(aiProviderManager.ollamaURL, defaultURL)
        
        let customURL = "http://192.168.1.100:11434"
        aiProviderManager.ollamaURL = customURL
        XCTAssertEqual(aiProviderManager.ollamaURL, customURL)
    }
    
    func testProviderDescription() async throws {
        let providers: [AIProvider] = [.openAI, .anthropic, .ollama, .groq, .gemini]
        
        for provider in providers {
            aiProviderManager.currentProvider = provider
            let description = aiProviderManager.currentProviderDescription
            XCTAssertFalse(description.isEmpty)
            XCTAssertTrue(description.contains(provider.rawValue))
        }
    }
    
    func testConfigurationValidation() async throws {
        // Test unconfigured state
        aiProviderManager.currentProvider = .openAI
        aiProviderManager.openAIKey = ""
        XCTAssertFalse(aiProviderManager.isConfigured)
        
        // Test configured state
        aiProviderManager.openAIKey = "sk-test-key"
        XCTAssertTrue(aiProviderManager.isConfigured)
        
        // Test empty key
        aiProviderManager.openAIKey = "   "
        XCTAssertFalse(aiProviderManager.isConfigured)
    }
    
    func testLiveAPISupport() async throws {
        // Only Gemini supports Live API
        aiProviderManager.currentProvider = .gemini
        aiProviderManager.geminiKey = "test-key"
        XCTAssertTrue(aiProviderManager.supportsLiveAPI)
        
        // Other providers don't support Live API
        let nonLiveProviders: [AIProvider] = [.openAI, .anthropic, .ollama, .groq]
        for provider in nonLiveProviders {
            aiProviderManager.currentProvider = provider
            XCTAssertFalse(aiProviderManager.supportsLiveAPI)
        }
    }
    
    func testConcurrentRequests() async throws {
        aiProviderManager.currentProvider = .openAI
        aiProviderManager.openAIKey = "test-key"
        
        await withTaskGroup(of: String.self) { group in
            for i in 1...5 {
                group.addTask {
                    await self.aiProviderManager.processCommand("Test \(i)", context: nil)
                }
            }
            
            for await _ in group {
                // Process results
            }
        }
        
        // Should complete without crashes
        XCTAssertTrue(true)
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
        
        context.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return context.makeImage()
    }
}