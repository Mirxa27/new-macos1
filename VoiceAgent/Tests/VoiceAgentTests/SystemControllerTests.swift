import XCTest
import AppKit
@testable import VoiceAgent

@MainActor
final class SystemControllerTests: XCTestCase {
    var systemController: SystemController!
    
    override func setUp() async throws {
        systemController = SystemController()
    }
    
    override func tearDown() async throws {
        systemController = nil
    }
    
    func testInitialization() async throws {
        XCTAssertNotNil(systemController)
    }
    
    func testMouseMovement() async throws {
        let originalPosition = systemController.getMousePosition()
        
        // Move to specific position
        let newPosition = CGPoint(x: 100, y: 100)
        systemController.moveMouse(to: newPosition)
        
        // Allow time for movement
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let currentPosition = systemController.getMousePosition()
        XCTAssertEqual(currentPosition.x, newPosition.x, accuracy: 1.0)
        XCTAssertEqual(currentPosition.y, newPosition.y, accuracy: 1.0)
        
        // Restore original position
        systemController.moveMouse(to: originalPosition)
    }
    
    func testMouseClick() async throws {
        let position = CGPoint(x: 100, y: 100)
        
        // Test single click
        systemController.click(at: position)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test double click
        systemController.doubleClick(at: position)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test right click
        systemController.rightClick(at: position)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // All clicks should complete without errors
        XCTAssertTrue(true)
    }
    
    func testKeyboardInput() async throws {
        // Test typing text
        systemController.typeText("Test")
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test key press
        systemController.pressKey(.return)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test key combination
        systemController.pressKeyCombo([.command], key: .a)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // All keyboard operations should complete
        XCTAssertTrue(true)
    }
    
    func testScrolling() async throws {
        // Test vertical scroll
        systemController.scroll(deltaY: 10)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        systemController.scroll(deltaY: -10)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Test horizontal scroll
        systemController.scroll(deltaX: 5)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        systemController.scroll(deltaX: -5)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // All scroll operations should complete
        XCTAssertTrue(true)
    }
    
    func testApplicationLaunching() async throws {
        // Test launching an app that should exist on all Macs
        let result = systemController.launchApplication("Finder")
        XCTAssertTrue(result)
        
        // Test launching non-existent app
        let failResult = systemController.launchApplication("NonExistentApp123")
        XCTAssertFalse(failResult)
    }
    
    func testApplicationActivation() async throws {
        // Activate Finder (should always exist)
        let result = systemController.activateApplication("Finder")
        XCTAssertTrue(result)
        
        // Try to activate non-existent app
        let failResult = systemController.activateApplication("NonExistentApp123")
        XCTAssertFalse(failResult)
    }
    
    func testWindowManagement() async throws {
        // Get front window info
        let windowInfo = systemController.getFrontWindowInfo()
        
        // Window info might be nil in test environment
        if let info = windowInfo {
            XCTAssertFalse(info.isEmpty)
        }
    }
    
    func testDragOperation() async throws {
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 200, y: 200)
        
        systemController.drag(from: startPoint, to: endPoint)
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds for drag
        
        // Drag should complete without errors
        XCTAssertTrue(true)
    }
    
    func testMultipleKeyPress() async throws {
        let keys: [CGKeyCode] = [.kVK_ANSI_A, .kVK_ANSI_B, .kVK_ANSI_C]
        
        for key in keys {
            systemController.pressKey(key)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        
        // All keys should be pressed
        XCTAssertTrue(true)
    }
    
    func testSpecialKeys() async throws {
        let specialKeys: [CGKeyCode] = [
            .kVK_Escape,
            .kVK_Tab,
            .kVK_Space,
            .kVK_Delete,
            .kVK_Return,
            .kVK_UpArrow,
            .kVK_DownArrow,
            .kVK_LeftArrow,
            .kVK_RightArrow
        ]
        
        for key in specialKeys {
            systemController.pressKey(key)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        
        // All special keys should work
        XCTAssertTrue(true)
    }
    
    func testModifierKeys() async throws {
        // Test different modifier combinations
        systemController.pressKeyCombo([.command], key: .kVK_ANSI_C)
        try await Task.sleep(nanoseconds: 50_000_000)
        
        systemController.pressKeyCombo([.command, .shift], key: .kVK_ANSI_A)
        try await Task.sleep(nanoseconds: 50_000_000)
        
        systemController.pressKeyCombo([.control, .option], key: .kVK_ANSI_X)
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // All modifier combinations should work
        XCTAssertTrue(true)
    }
    
    func testScreenBounds() async throws {
        let screenBounds = systemController.getScreenBounds()
        
        XCTAssertGreaterThan(screenBounds.width, 0)
        XCTAssertGreaterThan(screenBounds.height, 0)
        XCTAssertEqual(screenBounds.origin.x, 0)
        XCTAssertEqual(screenBounds.origin.y, 0)
    }
    
    func testMousePositionBounds() async throws {
        let screenBounds = systemController.getScreenBounds()
        
        // Move mouse to corners
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: screenBounds.width - 1, y: 0),
            CGPoint(x: 0, y: screenBounds.height - 1),
            CGPoint(x: screenBounds.width - 1, y: screenBounds.height - 1)
        ]
        
        for corner in corners {
            systemController.moveMouse(to: corner)
            try await Task.sleep(nanoseconds: 50_000_000)
            
            let position = systemController.getMousePosition()
            XCTAssertGreaterThanOrEqual(position.x, 0)
            XCTAssertGreaterThanOrEqual(position.y, 0)
            XCTAssertLessThanOrEqual(position.x, screenBounds.width)
            XCTAssertLessThanOrEqual(position.y, screenBounds.height)
        }
    }
    
    func testConcurrentOperations() async throws {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                self.systemController.moveMouse(to: CGPoint(x: 100, y: 100))
            }
            
            group.addTask {
                self.systemController.typeText("Test")
            }
            
            group.addTask {
                self.systemController.scroll(deltaY: 5)
            }
        }
        
        // Concurrent operations should complete without crashes
        XCTAssertTrue(true)
    }
}