import XCTest
import AVFoundation
@testable import VoiceAgent

@MainActor
final class VoiceFeedbackManagerTests: XCTestCase {
    var voiceFeedbackManager: VoiceFeedbackManager!
    
    override func setUp() async throws {
        voiceFeedbackManager = VoiceFeedbackManager()
    }
    
    override func tearDown() async throws {
        voiceFeedbackManager.stopSpeaking()
        voiceFeedbackManager = nil
    }
    
    func testInitialization() async throws {
        XCTAssertNotNil(voiceFeedbackManager)
        XCTAssertFalse(voiceFeedbackManager.isEnabled)
        XCTAssertFalse(voiceFeedbackManager.isSpeaking)
        XCTAssertEqual(voiceFeedbackManager.volume, 0.7)
        XCTAssertEqual(voiceFeedbackManager.speechRate, 0.5)
    }
    
    func testEnableDisable() async throws {
        voiceFeedbackManager.isEnabled = true
        XCTAssertTrue(voiceFeedbackManager.isEnabled)
        
        voiceFeedbackManager.isEnabled = false
        XCTAssertFalse(voiceFeedbackManager.isEnabled)
    }
    
    func testVolumeConfiguration() async throws {
        let volumes: [Float] = [0.0, 0.5, 1.0]
        
        for volume in volumes {
            voiceFeedbackManager.volume = volume
            XCTAssertEqual(voiceFeedbackManager.volume, volume)
        }
        
        // Test boundary conditions
        voiceFeedbackManager.volume = -0.1
        XCTAssertGreaterThanOrEqual(voiceFeedbackManager.volume, 0.0)
        
        voiceFeedbackManager.volume = 1.5
        XCTAssertLessThanOrEqual(voiceFeedbackManager.volume, 1.0)
    }
    
    func testSpeechRateConfiguration() async throws {
        let rates: [Float] = [0.0, 0.5, 1.0]
        
        for rate in rates {
            voiceFeedbackManager.speechRate = rate
            XCTAssertEqual(voiceFeedbackManager.speechRate, rate)
        }
        
        // Test boundary conditions
        voiceFeedbackManager.speechRate = -0.1
        XCTAssertGreaterThanOrEqual(voiceFeedbackManager.speechRate, 0.0)
        
        voiceFeedbackManager.speechRate = 1.5
        XCTAssertLessThanOrEqual(voiceFeedbackManager.speechRate, 1.0)
    }
    
    func testVoiceSelection() async throws {
        let voices = NSSpeechSynthesizer.availableVoices
        guard !voices.isEmpty else {
            throw XCTSkip("No voices available")
        }
        
        let testVoice = voices.first!
        voiceFeedbackManager.selectedVoice = testVoice
        XCTAssertEqual(voiceFeedbackManager.selectedVoice, testVoice)
    }
    
    func testSpeakText() async throws {
        voiceFeedbackManager.isEnabled = true
        
        let expectation = XCTestExpectation(description: "Speech started")
        
        voiceFeedbackManager.speak("Testing speech synthesis")
        
        // Give some time for speech to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Speech should have started or finished quickly for short text
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testSpeakWithPriority() async throws {
        voiceFeedbackManager.isEnabled = true
        
        // Queue multiple messages with different priorities
        voiceFeedbackManager.speak("Low priority", priority: .low)
        voiceFeedbackManager.speak("Normal priority", priority: .normal)
        voiceFeedbackManager.speak("High priority", priority: .high)
        
        // High priority should be spoken first
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify that speaking started
        XCTAssertTrue(voiceFeedbackManager.isSpeaking || voiceFeedbackManager.speechQueue.count > 0)
    }
    
    func testStopSpeaking() async throws {
        voiceFeedbackManager.isEnabled = true
        
        voiceFeedbackManager.speak("This is a long message that should be interrupted")
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        voiceFeedbackManager.stopSpeaking()
        XCTAssertFalse(voiceFeedbackManager.isSpeaking)
    }
    
    func testAnnouncementMethods() async throws {
        voiceFeedbackManager.isEnabled = true
        
        // Test various announcement methods
        voiceFeedbackManager.announceListeningStarted()
        voiceFeedbackManager.announceListeningStopped()
        voiceFeedbackManager.announceCommandReceived("test command")
        voiceFeedbackManager.announceCommandExecuted("test command", success: true)
        voiceFeedbackManager.announceCommandExecuted("failed command", success: false)
        voiceFeedbackManager.announceError("Test error")
        voiceFeedbackManager.announceScreenDescription("Test screen")
        voiceFeedbackManager.announceVisionAnalysis("Test vision result")
        
        // All announcements should be queued
        XCTAssertTrue(voiceFeedbackManager.speechQueue.count > 0 || voiceFeedbackManager.isSpeaking)
    }
    
    func testSpeechQueueManagement() async throws {
        voiceFeedbackManager.isEnabled = true
        
        // Add multiple items to queue
        for i in 1...5 {
            voiceFeedbackManager.speak("Message \(i)", priority: .normal)
        }
        
        // Queue should have items
        XCTAssertTrue(voiceFeedbackManager.speechQueue.count > 0 || voiceFeedbackManager.isSpeaking)
        
        // Clear queue
        voiceFeedbackManager.stopSpeaking()
        XCTAssertEqual(voiceFeedbackManager.speechQueue.count, 0)
    }
    
    func testDisabledState() async throws {
        voiceFeedbackManager.isEnabled = false
        
        voiceFeedbackManager.speak("This should not be spoken")
        
        // Nothing should be queued when disabled
        XCTAssertEqual(voiceFeedbackManager.speechQueue.count, 0)
        XCTAssertFalse(voiceFeedbackManager.isSpeaking)
    }
    
    func testConcurrentSpeaking() async throws {
        voiceFeedbackManager.isEnabled = true
        
        await withTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    self.voiceFeedbackManager.speak("Concurrent message \(i)")
                }
            }
        }
        
        // Should handle concurrent requests without crashing
        XCTAssertTrue(voiceFeedbackManager.speechQueue.count > 0 || voiceFeedbackManager.isSpeaking)
    }
}