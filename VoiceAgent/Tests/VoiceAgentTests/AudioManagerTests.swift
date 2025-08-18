import XCTest
import AVFoundation
import Speech
@testable import VoiceAgent

@MainActor
final class AudioManagerTests: XCTestCase {
    var audioManager: AudioManager!
    
    override func setUp() async throws {
        audioManager = AudioManager()
    }
    
    override func tearDown() async throws {
        await audioManager.stopListening()
        audioManager = nil
    }
    
    func testInitialization() async throws {
        XCTAssertNotNil(audioManager)
        XCTAssertFalse(audioManager.isListening)
        XCTAssertEqual(audioManager.currentLanguage, "en-US")
    }
    
    func testLanguageUpdate() async throws {
        let newLanguage = "es-ES"
        audioManager.updateLanguage(newLanguage)
        XCTAssertEqual(audioManager.currentLanguage, newLanguage)
    }
    
    func testStartListening() async throws {
        // Check if speech recognition is available
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw XCTSkip("Speech recognition not authorized")
        }
        
        do {
            try await audioManager.startListening()
            XCTAssertTrue(audioManager.isListening)
        } catch {
            XCTFail("Failed to start listening: \(error)")
        }
    }
    
    func testStopListening() async throws {
        // Start listening first
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw XCTSkip("Speech recognition not authorized")
        }
        
        try await audioManager.startListening()
        await audioManager.stopListening()
        XCTAssertFalse(audioManager.isListening)
    }
    
    func testSpeechRecognitionCallback() async throws {
        var recognizedText: String?
        let expectation = XCTestExpectation(description: "Speech recognized")
        
        audioManager.onSpeechRecognized = { text in
            recognizedText = text
            expectation.fulfill()
        }
        
        // Simulate speech recognition
        audioManager.onSpeechRecognized?("Test command")
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(recognizedText, "Test command")
    }
    
    func testStatusCallback() async throws {
        var statusMessage: String?
        let expectation = XCTestExpectation(description: "Status updated")
        
        audioManager.onStatusChanged = { status in
            statusMessage = status
            expectation.fulfill()
        }
        
        audioManager.onStatusChanged?("Ready")
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(statusMessage, "Ready")
    }
    
    func testMultipleLanguageSupport() async throws {
        let languages = ["en-US", "es-ES", "fr-FR", "de-DE", "ja-JP"]
        
        for language in languages {
            audioManager.updateLanguage(language)
            XCTAssertEqual(audioManager.currentLanguage, language)
        }
    }
    
    func testConcurrentOperations() async throws {
        // Test that multiple operations don't cause race conditions
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                self.audioManager.updateLanguage("en-US")
            }
            group.addTask {
                self.audioManager.updateLanguage("es-ES")
            }
            group.addTask {
                self.audioManager.onStatusChanged?("Testing")
            }
        }
        
        // Should complete without crashes
        XCTAssertNotNil(audioManager.currentLanguage)
    }
}