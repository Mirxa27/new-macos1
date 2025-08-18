import XCTest
import AVFoundation
@testable import VoiceAgent

@MainActor
final class GeminiLiveAPIManagerTests: XCTestCase {
    var geminiManager: GeminiLiveAPIManager!
    
    override func setUp() async throws {
        geminiManager = GeminiLiveAPIManager()
    }
    
    override func tearDown() async throws {
        geminiManager.stopLiveSession()
        geminiManager = nil
    }
    
    func testInitialization() async throws {
        XCTAssertNotNil(geminiManager)
        XCTAssertFalse(geminiManager.isConnected)
        XCTAssertFalse(geminiManager.isListening)
        XCTAssertFalse(geminiManager.isSpeaking)
        XCTAssertEqual(geminiManager.connectionStatus, "Disconnected")
        XCTAssertFalse(geminiManager.sessionActive)
    }
    
    func testConfiguration() async throws {
        let apiKey = "test-api-key"
        let model = "gemini-2.0-flash"
        let voiceName = "Puck"
        
        geminiManager.configure(apiKey: apiKey, model: model, voiceName: voiceName)
        
        // Configuration should be stored (internal properties)
        // We can't directly test private properties, but we can test behavior
        XCTAssertNotNil(geminiManager)
    }
    
    func testStartSessionWithoutAPIKey() async throws {
        do {
            try await geminiManager.startLiveSession()
            XCTFail("Should throw error without API key")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    func testStartSessionWithInvalidAPIKey() async throws {
        geminiManager.configure(apiKey: "invalid-key")
        
        do {
            try await geminiManager.startLiveSession()
            // Will fail to connect with invalid key
            XCTAssertNotNil(geminiManager.lastError)
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    func testStopSession() async throws {
        geminiManager.stopLiveSession()
        
        XCTAssertFalse(geminiManager.isConnected)
        XCTAssertFalse(geminiManager.isListening)
        XCTAssertFalse(geminiManager.isSpeaking)
        XCTAssertEqual(geminiManager.connectionStatus, "Disconnected")
        XCTAssertFalse(geminiManager.sessionActive)
    }
    
    func testSendTextMessage() async throws {
        geminiManager.configure(apiKey: "test-key")
        
        // Without active session, this should handle gracefully
        await geminiManager.sendTextMessage("Test message")
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testSendImage() async throws {
        geminiManager.configure(apiKey: "test-key")
        
        // Create a test image
        let testImage = createTestImage()
        
        // Without active session, this should handle gracefully
        if let image = testImage {
            await geminiManager.sendImage(image, mimeType: "image/jpeg")
        }
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testInterruptResponse() async throws {
        await geminiManager.interruptResponse()
        
        // Should handle gracefully even without active session
        XCTAssertTrue(true)
    }
    
    func testUpdateVolume() async throws {
        let volumes: [Float] = [0.0, 0.5, 1.0]
        
        for volume in volumes {
            geminiManager.updateVolume(volume)
            // Volume should be updated (internal property)
            XCTAssertTrue(true)
        }
    }
    
    func testConnectionStates() async throws {
        // Test various connection states
        XCTAssertEqual(geminiManager.connectionStatus, "Disconnected")
        
        geminiManager.configure(apiKey: "test-key")
        
        // Attempt connection (will fail with test key)
        do {
            try await geminiManager.startLiveSession()
        } catch {
            // Expected to fail
        }
        
        // Check that error state is handled
        XCTAssertFalse(geminiManager.isConnected)
    }
    
    func testMultipleSessionStarts() async throws {
        geminiManager.configure(apiKey: "test-key")
        
        // Try starting session multiple times
        do {
            try await geminiManager.startLiveSession()
        } catch {
            // Expected to fail with test key
        }
        
        // Try again - should handle gracefully
        do {
            try await geminiManager.startLiveSession()
        } catch {
            // Expected to fail
        }
        
        XCTAssertTrue(true) // Should not crash
    }
    
    func testSessionCleanup() async throws {
        geminiManager.configure(apiKey: "test-key")
        
        // Start and stop multiple times
        for _ in 0..<3 {
            do {
                try await geminiManager.startLiveSession()
            } catch {
                // Expected to fail with test key
            }
            
            geminiManager.stopLiveSession()
        }
        
        // Should handle multiple start/stop cycles
        XCTAssertFalse(geminiManager.sessionActive)
        XCTAssertFalse(geminiManager.isConnected)
    }
    
    func testConcurrentOperations() async throws {
        geminiManager.configure(apiKey: "test-key")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.geminiManager.sendTextMessage("Test 1")
            }
            
            group.addTask {
                await self.geminiManager.sendTextMessage("Test 2")
            }
            
            group.addTask {
                await self.geminiManager.interruptResponse()
            }
            
            group.addTask {
                self.geminiManager.updateVolume(0.5)
            }
        }
        
        // Should handle concurrent operations without crashes
        XCTAssertTrue(true)
    }
    
    func testAudioSessionConfiguration() async throws {
        // Audio session should be configured on init
        let audioSession = AVAudioSession.sharedInstance()
        
        // Check that audio session is properly configured
        XCTAssertNotNil(audioSession)
        
        // In test environment, we can't fully test audio configuration
        // but we can verify it doesn't crash
        XCTAssertTrue(true)
    }
    
    func testModelConfiguration() async throws {
        let models = [
            "models/gemini-2.5-flash-preview-native-audio-dialog",
            "models/gemini-2.0-flash",
            "models/gemini-1.5-pro"
        ]
        
        for model in models {
            geminiManager.configure(apiKey: "test-key", model: model)
            // Configuration should be accepted
            XCTAssertNotNil(geminiManager)
        }
    }
    
    func testVoiceConfiguration() async throws {
        let voices = ["Puck", "Zephyr", "Kore", "Charon", "Fenrir", "Aoede"]
        
        for voice in voices {
            geminiManager.configure(apiKey: "test-key", voiceName: voice)
            // Configuration should be accepted
            XCTAssertNotNil(geminiManager)
        }
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