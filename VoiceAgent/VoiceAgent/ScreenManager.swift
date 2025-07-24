#if os(macOS)
import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

@MainActor
class ScreenManager: ObservableObject {
    private var stream: SCStream?
    private var isMonitoring = false
    private var lastScreenshot: NSImage?
    private var monitoringTimer: Timer?
    
    var onScreenChanged: ((String) -> Void)?
    
    func startMonitoring() async throws {
        guard !isMonitoring else { return }
        
        // Request screen recording permission
        let hasPermission = await requestScreenCapturePermission()
        guard hasPermission else {
            throw ScreenManagerError.screenCaptureNotAuthorized
        }
        
        // Get available content
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        guard let display = availableContent.displays.first else {
            throw ScreenManagerError.noDisplayAvailable
        }
        
        // Create filter for the main display
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Configure stream
        let configuration = SCStreamConfiguration()
        configuration.width = Int(display.width / 2) // Reduce resolution for performance
        configuration.height = Int(display.height / 2)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2) // 2 FPS
        configuration.queueDepth = 5
        
        // Create and start stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        
        try await stream?.startCapture()
        
        isMonitoring = true
        
        // Start periodic analysis
        startPeriodicAnalysis()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        Task {
            await stream?.stopCapture()
            stream = nil
            isMonitoring = false
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }
    
    private func startPeriodicAnalysis() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.analyzeCurrentScreen()
            }
        }
    }
    
    private func analyzeCurrentScreen() async {
        guard let screenshot = lastScreenshot else { return }
        
        // Convert screenshot to description
        let description = await analyzeScreenshot(screenshot)
        onScreenChanged?(description)
    }
    
    private func analyzeScreenshot(_ image: NSImage) async -> String {
        // This is a simplified analysis - in a real implementation, you might:
        // 1. Use Vision framework for text detection
        // 2. Use Core ML models for UI element detection
        // 3. Send to AI service for detailed analysis
        
        var elements: [String] = []
        
        // Get window information
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]]
        
        if let windows = windowList {
            let visibleApps = Set(windows.compactMap { window in
                window[kCGWindowOwnerName] as? String
            }).filter { !$0.isEmpty }
            
            elements.append("Visible applications: \(visibleApps.joined(separator: ", "))")
        }
        
        // Get current application
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            elements.append("Active application: \(frontmostApp.localizedName ?? "Unknown")")
        }
        
        // Get screen size and resolution info
        if let screen = NSScreen.main {
            let frame = screen.frame
            elements.append("Screen resolution: \(Int(frame.width))x\(Int(frame.height))")
        }
        
        return elements.joined(separator: "\n")
    }
    
    func getCurrentScreenDescription() async -> String {
        if let screenshot = lastScreenshot {
            return await analyzeScreenshot(screenshot)
        } else {
            return "No screen data available"
        }
    }
    
    private func requestScreenCapturePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            // For macOS 10.15+, we need to request screen recording permission
            let options: [CFString: Any] = [kCGWindowListOptionOnScreenOnly: true]
            let windowList = CGWindowListCopyWindowInfo(CGWindowListOption(rawValue: 0), kCGNullWindowID)
            
            // If we can get the window list, we have permission
            let hasPermission = windowList != nil
            continuation.resume(returning: hasPermission)
        }
    }
    
    func takeScreenshot() async -> NSImage? {
        guard let screen = NSScreen.main else { return nil }
        
        let rect = screen.frame
        guard let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else {
            return nil
        }
        
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)
        
        lastScreenshot = image
        return image
    }
}

extension ScreenManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        Task { @MainActor in
            // Convert CVPixelBuffer to NSImage
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                return
            }
            
            let size = NSSize(width: cgImage.width, height: cgImage.height)
            lastScreenshot = NSImage(cgImage: cgImage, size: size)
        }
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            print("Screen capture stream stopped with error: \(error)")
            isMonitoring = false
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }
}

enum ScreenManagerError: Error, LocalizedError {
    case screenCaptureNotAuthorized
    case noDisplayAvailable
    case streamCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .screenCaptureNotAuthorized:
            return "Screen capture permission not granted"
        case .noDisplayAvailable:
            return "No display available for capture"
        case .streamCreationFailed:
            return "Failed to create screen capture stream"
        }
    }
}
#endif
