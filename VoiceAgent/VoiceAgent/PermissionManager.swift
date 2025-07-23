#if os(macOS)
import Foundation
import AVFoundation
import AppKit
import CoreGraphics
import ApplicationServices
import Speech

class PermissionManager: ObservableObject {
    @Published var microphoneGranted: Bool = false
    @Published var screenGranted: Bool = false
    @Published var accessibilityGranted: Bool = false

    init() {
        refreshStatuses()
    }

    func refreshStatuses() {
        microphoneGranted = AVAudioSession.sharedInstance().recordPermission == .granted
        screenGranted = CGPreflightScreenCaptureAccess()
        accessibilityGranted = AXIsProcessTrusted()
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphoneGranted = granted
                completion(granted)
            }
        }
    }

    func requestScreenPermission(completion: @escaping (Bool) -> Void) {
        let granted = CGRequestScreenCaptureAccess()
        DispatchQueue.main.async {
            self.screenGranted = granted
            completion(granted)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = AXIsProcessTrusted()
    }
}
#endif
