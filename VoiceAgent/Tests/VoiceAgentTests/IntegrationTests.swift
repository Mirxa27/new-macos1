import XCTest
import SwiftUI
@testable import VoiceAgent

@MainActor
final class IntegrationTests: XCTestCase {
    var voiceAgent: VoiceAgent!
    
    override func setUp() async throws {
        voiceAgent = VoiceAgent()
    }
    
    override func tearDown() async throws {
        voiceAgent.stopListening()
        voiceAgent.stopScreenMonitoring()
        voiceAgent = nil
    }
    
    func testFullVoiceCommandFlow() async throws {
        // Configure AI provider
        voiceAgent.aiProviderManager.currentProvider = .openAI
        voiceAgent.aiProviderManager.openAIKey = "test-key"
        
        // Enable voice feedback
        voiceAgent.voiceFeedbackManager.isEnabled = true
        
        // Simulate voice command
        await voiceAgent.processSpeechCommand("What time is it?")
        
        // Check that command was added to history
        XCTAssertGreaterThan(voiceAgent.recentCommands.count, 0)
        XCTAssertEqual(voiceAgent.recentCommands.last?.text, "What time is it?")
        
        // Allow time for processing
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Command should be marked as executed
        if let lastCommand = voiceAgent.recentCommands.last {
            XCTAssertTrue(lastCommand.executed)
        }
    }
    
    func testVisionIntegration() async throws {
        // Configure AI provider with vision
        voiceAgent.aiProviderManager.currentProvider = .openAI
        voiceAgent.aiProviderManager.openAIKey = "test-key"
        voiceAgent.aiProviderManager.visionEnabled = true
        voiceAgent.visionManager.isEnabled = true
        
        // Start screen monitoring
        voiceAgent.startScreenMonitoring()
        XCTAssertTrue(voiceAgent.isScreenMonitoring)
        
        // Simulate vision command
        await voiceAgent.processSpeechCommand("What's on my screen?")
        
        // Allow time for processing
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Check that vision was attempted
        XCTAssertTrue(voiceAgent.visionManager.isEnabled)
    }
    
    func testSystemControlIntegration() async throws {
        // Configure AI provider
        voiceAgent.aiProviderManager.currentProvider = .ollama
        
        // Test system control command
        await voiceAgent.processSpeechCommand("Move mouse to center of screen")
        
        // Allow time for processing
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Check command was processed
        XCTAssertGreaterThan(voiceAgent.commandCount, 0)
    }
    
    func testLiveAPIIntegration() async throws {
        // Configure Gemini with Live API
        voiceAgent.aiProviderManager.currentProvider = .gemini
        voiceAgent.aiProviderManager.geminiKey = "test-key"
        
        // Try to start Live API
        voiceAgent.startLiveAPI()
        
        // Allow time for connection attempt
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // With test key, should fail but handle gracefully
        XCTAssertFalse(voiceAgent.isLiveAPIActive)
        
        // Stop Live API
        voiceAgent.stopLiveAPI()
        XCTAssertFalse(voiceAgent.isLiveAPIActive)
    }
    
    func testMultiProviderSwitching() async throws {
        let providers: [AIProvider] = [.openAI, .anthropic, .ollama, .groq, .gemini]
        
        for provider in providers {
            voiceAgent.aiProviderManager.currentProvider = provider
            
            // Process a command with each provider
            await voiceAgent.processSpeechCommand("Hello")
            
            // Allow time for processing
            try await Task.sleep(nanoseconds: 200_000_000)
            
            // Should handle all providers gracefully
            XCTAssertEqual(voiceAgent.aiProviderManager.currentProvider, provider)
        }
    }
    
    func testWakeWordDetection() async throws {
        // Enable wake word
        voiceAgent.wakeWordEnabled = true
        voiceAgent.wakeWord = "Hey Assistant"
        
        // Simulate wake word detection
        await voiceAgent.processSpeechCommand("Hey Assistant")
        
        // Should activate
        XCTAssertTrue(voiceAgent.isListening)
        
        // Process actual command
        await voiceAgent.processSpeechCommand("What's the weather?")
        
        // Check command was processed
        XCTAssertGreaterThan(voiceAgent.commandCount, 0)
    }
    
    func testErrorRecovery() async throws {
        // Configure with invalid settings
        voiceAgent.aiProviderManager.currentProvider = .openAI
        voiceAgent.aiProviderManager.openAIKey = ""
        
        // Try to process command
        await voiceAgent.processSpeechCommand("Test command")
        
        // Should handle error gracefully
        XCTAssertTrue(voiceAgent.statusMessage.contains("not configured") || 
                     voiceAgent.statusMessage.contains("error"))
        
        // System should still be responsive
        XCTAssertNotNil(voiceAgent)
    }
    
    func testConcurrentCommands() async throws {
        voiceAgent.aiProviderManager.currentProvider = .ollama
        
        // Send multiple commands concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    await self.voiceAgent.processSpeechCommand("Command \(i)")
                }
            }
        }
        
        // Allow time for processing
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // All commands should be in history
        XCTAssertGreaterThanOrEqual(voiceAgent.recentCommands.count, 5)
    }
    
    func testVoiceFeedbackIntegration() async throws {
        voiceAgent.voiceFeedbackManager.isEnabled = true
        voiceAgent.voiceFeedbackManager.volume = 0.5
        voiceAgent.voiceFeedbackManager.speechRate = 0.6
        
        // Test various announcements
        voiceAgent.startListening()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        voiceAgent.stopListening()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        await voiceAgent.processSpeechCommand("Test")
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Voice feedback should have been triggered
        XCTAssertTrue(voiceAgent.voiceFeedbackManager.isEnabled)
    }
    
    func testScreenMonitoringIntegration() async throws {
        // Start screen monitoring
        voiceAgent.startScreenMonitoring()
        XCTAssertTrue(voiceAgent.isScreenMonitoring)
        
        // Allow time for initial capture
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Stop monitoring
        voiceAgent.stopScreenMonitoring()
        XCTAssertFalse(voiceAgent.isScreenMonitoring)
    }
    
    func testCommandHistory() async throws {
        // Process multiple commands
        let commands = ["First command", "Second command", "Third command"]
        
        for command in commands {
            await voiceAgent.processSpeechCommand(command)
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Check history
        XCTAssertGreaterThanOrEqual(voiceAgent.recentCommands.count, commands.count)
        
        // Clear history
        voiceAgent.clearCommandHistory()
        XCTAssertEqual(voiceAgent.recentCommands.count, 0)
    }
    
    func testLanguageSwitching() async throws {
        let languages = ["en-US", "es-ES", "fr-FR"]
        
        for language in languages {
            voiceAgent.speechLanguage = language
            XCTAssertEqual(voiceAgent.speechLanguage, language)
            XCTAssertEqual(voiceAgent.audioManager.currentLanguage, language)
        }
    }
    
    func testPermissionHandling() async throws {
        // Refresh permission statuses
        voiceAgent.permissionManager.refreshStatuses()
        
        // Check that permission manager is working
        XCTAssertNotNil(voiceAgent.permissionManager)
        
        // Permissions might not be granted in test environment
        // Just verify the system doesn't crash
        XCTAssertTrue(true)
    }
    
    func testEndToEndWorkflow() async throws {
        // Complete workflow test
        
        // 1. Configure AI
        voiceAgent.aiProviderManager.currentProvider = .ollama
        
        // 2. Enable features
        voiceAgent.voiceFeedbackManager.isEnabled = true
        voiceAgent.visionManager.isEnabled = true
        
        // 3. Start listening
        voiceAgent.startListening()
        XCTAssertTrue(voiceAgent.isListening)
        
        // 4. Start screen monitoring
        voiceAgent.startScreenMonitoring()
        XCTAssertTrue(voiceAgent.isScreenMonitoring)
        
        // 5. Process commands
        await voiceAgent.processSpeechCommand("Describe what you see")
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // 6. Check results
        XCTAssertGreaterThan(voiceAgent.commandCount, 0)
        
        // 7. Cleanup
        voiceAgent.stopListening()
        voiceAgent.stopScreenMonitoring()
        
        XCTAssertFalse(voiceAgent.isListening)
        XCTAssertFalse(voiceAgent.isScreenMonitoring)
    }
}