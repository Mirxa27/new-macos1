import Foundation
import AppKit
import ApplicationServices
import Carbon

enum SystemAction {
    case click(x: Int, y: Int)
    case type(text: String)
    case keyPress(key: String)
    case scroll(direction: String)
    case openApp(name: String)
}

class SystemController: ObservableObject {
    
    func executeAction(_ action: SystemAction) async throws -> String {
        switch action {
        case .click(let x, let y):
            return try await performClick(x: x, y: y)
        case .type(let text):
            return try await performType(text: text)
        case .keyPress(let key):
            return try await performKeyPress(key: key)
        case .scroll(let direction):
            return try await performScroll(direction: direction)
        case .openApp(let name):
            return try await performOpenApp(name: name)
        }
    }
    
    private func performClick(x: Int, y: Int) async throws -> String {
        guard await requestAccessibilityPermission() else {
            throw SystemControllerError.accessibilityNotGranted
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let point = CGPoint(x: x, y: y)
                
                // Create mouse events
                let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
                let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
                
                // Post events
                mouseDown?.post(tap: .cghidEventTap)
                mouseUp?.post(tap: .cghidEventTap)
                
                continuation.resume(returning: "Successfully clicked at coordinates \(x), \(y)")
            }
        }
    }
    
    private func performType(text: String) async throws -> String {
        guard await requestAccessibilityPermission() else {
            throw SystemControllerError.accessibilityNotGranted
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                for character in text {
                    if let keyEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                        let unicodeString = String(character)
                        keyEvent.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString.utf16.map { $0 })
                        keyEvent.post(tap: .cghidEventTap)
                        
                        // Key up event
                        if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                            keyUpEvent.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString.utf16.map { $0 })
                            keyUpEvent.post(tap: .cghidEventTap)
                        }
                    }
                    
                    // Small delay between characters
                    usleep(10000) // 10ms
                }
                
                continuation.resume(returning: "Successfully typed the text")
            }
        }
    }
    
    private func performKeyPress(key: String) async throws -> String {
        guard await requestAccessibilityPermission() else {
            throw SystemControllerError.accessibilityNotGranted
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let keyCode = self.getKeyCode(for: key.lowercased())
                let modifiers = self.getModifiers(for: key.lowercased())
                
                if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                    keyDown.flags = modifiers
                    keyDown.post(tap: .cghidEventTap)
                }
                
                if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                    keyUp.flags = modifiers
                    keyUp.post(tap: .cghidEventTap)
                }
                
                continuation.resume(returning: "Successfully pressed \(key) key")
            }
        }
    }
    
    private func performScroll(direction: String) async throws -> String {
        guard await requestAccessibilityPermission() else {
            throw SystemControllerError.accessibilityNotGranted
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let currentLocation = NSEvent.mouseLocation.asCGPoint() else {
                    continuation.resume(returning: "Failed to get mouse location")
                    return
                }
                
                var scrollX: Int32 = 0
                var scrollY: Int32 = 0
                
                switch direction.lowercased() {
                case "up":
                    scrollY = 5
                case "down":
                    scrollY = -5
                case "left":
                    scrollX = 5
                case "right":
                    scrollX = -5
                default:
                    continuation.resume(returning: "Unknown scroll direction: \(direction)")
                    return
                }
                
                if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: scrollY, wheel2: scrollX, wheel3: 0) {
                    scrollEvent.location = currentLocation
                    scrollEvent.post(tap: .cghidEventTap)
                }
                
                continuation.resume(returning: "Successfully scrolled \(direction)")
            }
        }
    }
    
    private func performOpenApp(name: String) async throws -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let workspace = NSWorkspace.shared
                
                // Try to find and launch the application
                if let appURL = workspace.urlForApplication(withBundleIdentifier: name) ??
                                workspace.urlForApplication(withBundleIdentifier: "com.apple.\(name.lowercased())") ??
                                self.findApplicationByName(name) {
                    
                    do {
                        try workspace.launchApplication(at: appURL, options: [], configuration: [:])
                        continuation.resume(returning: "Successfully opened \(name)")
                    } catch {
                        continuation.resume(returning: "Failed to open \(name)")
                    }
                } else {
                    continuation.resume(returning: "Could not find application \(name)")
                }
            }
        }
    }
    
    private func findApplicationByName(_ name: String) -> URL? {
        let fileManager = FileManager.default
        let applicationDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
            "/Applications/Utilities"
        ]
        
        for dir in applicationDirs {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: dir)
                for item in contents {
                    if item.lowercased().contains(name.lowercased()) && item.hasSuffix(".app") {
                        return URL(fileURLWithPath: "\(dir)/\(item)")
                    }
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
    
    private func requestAccessibilityPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let trusted = AXIsProcessTrusted()
                if !trusted {
                    // Request permission
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
                    AXIsProcessTrustedWithOptions(options as CFDictionary)
                }
                continuation.resume(returning: trusted)
            }
        }
    }
    
    private func getKeyCode(for key: String) -> CGKeyCode {
        let keyCodes: [String: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34,
            "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31, "p": 35, "q": 12,
            "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26,
            "8": 28, "9": 25,
            "enter": 36, "return": 36, "space": 49, "tab": 48, "escape": 53,
            "delete": 51, "backspace": 51,
            "up": 126, "down": 125, "left": 123, "right": 124,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111
        ]
        
        return keyCodes[key] ?? 0
    }
    
    private func getModifiers(for key: String) -> CGEventFlags {
        switch key.lowercased() {
        case let k where k.contains("command"):
            return .maskCommand
        case let k where k.contains("option"):
            return .maskAlternate
        case let k where k.contains("shift"):
            return .maskShift
        case let k where k.contains("control"):
            return .maskControl
        default:
            return []
        }
    }
}

extension NSPoint {
    func asCGPoint() -> CGPoint? {
        guard let screen = NSScreen.main else { return nil }
        let screenFrame = screen.frame
        return CGPoint(x: self.x, y: screenFrame.height - self.y)
    }
}

enum SystemControllerError: Error, LocalizedError {
    case accessibilityNotGranted
    case actionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission not granted. Please enable accessibility access in System Preferences."
        case .actionFailed(let message):
            return "Action failed: \(message)"
        }
    }
}