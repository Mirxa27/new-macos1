#if os(macOS)
import Foundation
import AppKit
import ScreenCaptureKit
import Vision
import CoreGraphics
import os.log

/// Manages vision analysis across multiple screens
@MainActor
class MultiScreenManager: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "MultiScreen")
    
    // MARK: - Published Properties
    @Published var screens: [ScreenInfo] = []
    @Published var activeScreen: ScreenInfo?
    @Published var isCapturing = false
    @Published var captureMode: CaptureMode = .activeScreen
    @Published var lastError: String?
    
    // MARK: - Screen Information
    struct ScreenInfo: Identifiable {
        let id = UUID()
        let displayID: CGDirectDisplayID
        let name: String
        let frame: CGRect
        let visibleFrame: CGRect
        let scaleFactor: CGFloat
        let isMain: Bool
        let isBuiltIn: Bool
        var lastCapture: CGImage?
        var lastCaptureTime: Date?
        var analysisResult: String?
    }
    
    // MARK: - Capture Modes
    enum CaptureMode: String, CaseIterable {
        case activeScreen = "Active Screen"
        case allScreens = "All Screens"
        case mainScreen = "Main Screen"
        case selectedScreens = "Selected Screens"
        case spanningRegion = "Spanning Region"
    }
    
    // MARK: - Properties
    private var screenContent: [CGDirectDisplayID: SCStreamOutput] = [:]
    private var captureStreams: [CGDirectDisplayID: SCStream] = [:]
    private var visionManager: VisionManager?
    private var captureTimer: Timer?
    private var selectedScreenIDs: Set<CGDirectDisplayID> = []
    private var spanningRegion: CGRect?
    
    // MARK: - Configuration
    var captureInterval: TimeInterval = 1.0
    var enableVisionAnalysis = true
    var captureQuality: Float = 0.8
    var includeMenuBar = true
    var includeDock = true
    
    init() {
        setupScreenMonitoring()
        refreshScreenList()
    }
    
    // MARK: - Screen Discovery
    
    private func setupScreenMonitoring() {
        // Monitor for screen configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc private func screenConfigurationChanged() {
        logger.info("Screen configuration changed")
        refreshScreenList()
    }
    
    func refreshScreenList() {
        screens = []
        
        // Get all online displays
        var displayCount: UInt32 = 0
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        
        CGGetOnlineDisplayList(16, &onlineDisplays, &displayCount)
        
        for i in 0..<Int(displayCount) {
            let displayID = onlineDisplays[i]
            if let screenInfo = createScreenInfo(for: displayID) {
                screens.append(screenInfo)
            }
        }
        
        // Set the main screen as active by default
        activeScreen = screens.first { $0.isMain }
        
        logger.info("Found \(screens.count) screens")
    }
    
    private func createScreenInfo(for displayID: CGDirectDisplayID) -> ScreenInfo? {
        let bounds = CGDisplayBounds(displayID)
        
        // Get screen name
        let name = getDisplayName(displayID) ?? "Display \(displayID)"
        
        // Get visible frame (excluding menu bar and dock)
        var visibleFrame = bounds
        if let screen = NSScreen.screens.first(where: { 
            $0.displayID == displayID 
        }) {
            visibleFrame = screen.visibleFrame
        }
        
        return ScreenInfo(
            displayID: displayID,
            name: name,
            frame: bounds,
            visibleFrame: visibleFrame,
            scaleFactor: getDisplayScaleFactor(displayID),
            isMain: CGDisplayIsMain(displayID) != 0,
            isBuiltIn: CGDisplayIsBuiltin(displayID) != 0
        )
    }
    
    private func getDisplayName(_ displayID: CGDirectDisplayID) -> String? {
        // Try to get the display name from IOKit
        if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
            return screen.localizedName
        }
        return nil
    }
    
    private func getDisplayScaleFactor(_ displayID: CGDirectDisplayID) -> CGFloat {
        if let mode = CGDisplayCopyDisplayMode(displayID) {
            return CGFloat(mode.pixelWidth) / CGFloat(mode.width)
        }
        return 1.0
    }
    
    // MARK: - Screen Capture
    
    func startCapturing() async throws {
        guard !isCapturing else { return }
        
        logger.info("Starting multi-screen capture in mode: \(captureMode.rawValue)")
        
        isCapturing = true
        
        switch captureMode {
        case .activeScreen:
            if let activeScreen = activeScreen {
                try await startCapture(for: activeScreen.displayID)
            }
            
        case .allScreens:
            for screen in screens {
                try await startCapture(for: screen.displayID)
            }
            
        case .mainScreen:
            if let mainScreen = screens.first(where: { $0.isMain }) {
                try await startCapture(for: mainScreen.displayID)
            }
            
        case .selectedScreens:
            for displayID in selectedScreenIDs {
                try await startCapture(for: displayID)
            }
            
        case .spanningRegion:
            try await captureSpanningRegion()
        }
        
        startCaptureTimer()
    }
    
    func stopCapturing() {
        guard isCapturing else { return }
        
        logger.info("Stopping multi-screen capture")
        
        isCapturing = false
        stopCaptureTimer()
        
        // Stop all capture streams
        for (_, stream) in captureStreams {
            stream.stopCapture()
        }
        captureStreams.removeAll()
        screenContent.removeAll()
    }
    
    private func startCapture(for displayID: CGDirectDisplayID) async throws {
        // Check for screen recording permission
        guard CGPreflightScreenCaptureAccess() else {
            throw MultiScreenError.screenRecordingPermissionDenied
        }
        
        // Get available content
        let content = try await SCShareableContent.current
        
        // Find the display
        guard let display = content.displays.first(where: { 
            $0.displayID == displayID 
        }) else {
            throw MultiScreenError.displayNotFound
        }
        
        // Create stream configuration
        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.scalesToFit = true
        config.queueDepth = 3
        
        // Create content filter
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // Create and start stream
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        // Create output handler
        let output = StreamOutput(displayID: displayID) { [weak self] image in
            Task { @MainActor in
                self?.handleCapturedImage(image, for: displayID)
            }
        }
        
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
        try await stream.startCapture()
        
        captureStreams[displayID] = stream
        screenContent[displayID] = output
        
        logger.info("Started capture for display \(displayID)")
    }
    
    private func captureSpanningRegion() async throws {
        // Capture a region that spans multiple screens
        guard let region = calculateSpanningRegion() else {
            throw MultiScreenError.invalidSpanningRegion
        }
        
        spanningRegion = region
        
        // Capture all screens that intersect with the region
        for screen in screens {
            if screen.frame.intersects(region) {
                try await startCapture(for: screen.displayID)
            }
        }
    }
    
    private func calculateSpanningRegion() -> CGRect? {
        guard !screens.isEmpty else { return nil }
        
        // Calculate bounding box of all screens
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for screen in screens {
            minX = min(minX, screen.frame.minX)
            minY = min(minY, screen.frame.minY)
            maxX = max(maxX, screen.frame.maxX)
            maxY = max(maxY, screen.frame.maxY)
        }
        
        return CGRect(x: minX, y: minY, 
                     width: maxX - minX, 
                     height: maxY - minY)
    }
    
    // MARK: - Image Handling
    
    private func handleCapturedImage(_ image: CGImage, for displayID: CGDirectDisplayID) {
        // Update screen info with captured image
        if let index = screens.firstIndex(where: { $0.displayID == displayID }) {
            screens[index].lastCapture = image
            screens[index].lastCaptureTime = Date()
            
            // Perform vision analysis if enabled
            if enableVisionAnalysis, let visionManager = visionManager {
                Task {
                    let result = await visionManager.analyzeImage(
                        image,
                        prompt: "Describe what's on this screen"
                    )
                    
                    await MainActor.run {
                        self.screens[index].analysisResult = result
                    }
                }
            }
        }
    }
    
    // MARK: - Timer Management
    
    private func startCaptureTimer() {
        stopCaptureTimer()
        
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performScheduledCapture()
            }
        }
    }
    
    private func stopCaptureTimer() {
        captureTimer?.invalidate()
        captureTimer = nil
    }
    
    private func performScheduledCapture() {
        // Trigger a new capture for active streams
        // The streams are already running, this just processes the latest frames
        logger.debug("Performing scheduled capture")
    }
    
    // MARK: - Vision Integration
    
    func setVisionManager(_ manager: VisionManager) {
        visionManager = manager
    }
    
    func analyzeScreen(_ displayID: CGDirectDisplayID, prompt: String) async -> String? {
        guard let screen = screens.first(where: { $0.displayID == displayID }),
              let image = screen.lastCapture,
              let visionManager = visionManager else {
            return nil
        }
        
        return await visionManager.analyzeImage(image, prompt: prompt)
    }
    
    func analyzeAllScreens(prompt: String) async -> [CGDirectDisplayID: String] {
        var results: [CGDirectDisplayID: String] = [:]
        
        await withTaskGroup(of: (CGDirectDisplayID, String?).self) { group in
            for screen in screens where screen.lastCapture != nil {
                group.addTask {
                    let result = await self.analyzeScreen(screen.displayID, prompt: prompt)
                    return (screen.displayID, result)
                }
            }
            
            for await (displayID, result) in group {
                if let result = result {
                    results[displayID] = result
                }
            }
        }
        
        return results
    }
    
    // MARK: - Screen Selection
    
    func selectScreen(_ displayID: CGDirectDisplayID) {
        if selectedScreenIDs.contains(displayID) {
            selectedScreenIDs.remove(displayID)
        } else {
            selectedScreenIDs.insert(displayID)
        }
    }
    
    func selectAllScreens() {
        selectedScreenIDs = Set(screens.map { $0.displayID })
    }
    
    func deselectAllScreens() {
        selectedScreenIDs.removeAll()
    }
    
    // MARK: - Screen Navigation
    
    func switchToScreen(_ displayID: CGDirectDisplayID) {
        activeScreen = screens.first { $0.displayID == displayID }
        
        if captureMode == .activeScreen && isCapturing {
            Task {
                stopCapturing()
                try? await startCapturing()
            }
        }
    }
    
    func switchToNextScreen() {
        guard let current = activeScreen,
              let currentIndex = screens.firstIndex(where: { $0.displayID == current.displayID }) else {
            return
        }
        
        let nextIndex = (currentIndex + 1) % screens.count
        activeScreen = screens[nextIndex]
    }
    
    func switchToPreviousScreen() {
        guard let current = activeScreen,
              let currentIndex = screens.firstIndex(where: { $0.displayID == current.displayID }) else {
            return
        }
        
        let previousIndex = currentIndex == 0 ? screens.count - 1 : currentIndex - 1
        activeScreen = screens[previousIndex]
    }
    
    // MARK: - Composite Image Creation
    
    func createCompositeImage() -> CGImage? {
        guard !screens.isEmpty else { return nil }
        
        // Calculate total canvas size
        guard let totalBounds = calculateSpanningRegion() else { return nil }
        
        // Create graphics context
        let width = Int(totalBounds.width)
        let height = Int(totalBounds.height)
        let bytesPerRow = width * 4
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        
        // Fill background
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw each screen's content
        for screen in screens {
            guard let image = screen.lastCapture else { continue }
            
            // Calculate position relative to total bounds
            let x = screen.frame.minX - totalBounds.minX
            let y = totalBounds.height - (screen.frame.minY - totalBounds.minY) - screen.frame.height
            
            let drawRect = CGRect(
                x: x,
                y: y,
                width: screen.frame.width,
                height: screen.frame.height
            )
            
            context.draw(image, in: drawRect)
        }
        
        return context.makeImage()
    }
    
    // MARK: - Screen Recording
    
    func startRecording(to url: URL) async throws {
        // Implementation would use AVAssetWriter to record screens
        logger.info("Starting screen recording to: \(url.path)")
    }
    
    func stopRecording() {
        logger.info("Stopping screen recording")
    }
    
    // MARK: - Utility Methods
    
    func getScreenAt(point: CGPoint) -> ScreenInfo? {
        return screens.first { $0.frame.contains(point) }
    }
    
    func getMouseScreen() -> ScreenInfo? {
        let mouseLocation = NSEvent.mouseLocation
        return getScreenAt(point: mouseLocation)
    }
    
    func captureScreenshot(of displayID: CGDirectDisplayID) -> CGImage? {
        let image = CGDisplayCreateImage(displayID)
        return image
    }
    
    func captureRegion(_ rect: CGRect, from displayID: CGDirectDisplayID) -> CGImage? {
        let image = CGDisplayCreateImage(displayID, rect: rect)
        return image
    }
}

// MARK: - Stream Output Handler

private class StreamOutput: NSObject, SCStreamOutput {
    let displayID: CGDirectDisplayID
    let imageHandler: (CGImage) -> Void
    
    init(displayID: CGDirectDisplayID, imageHandler: @escaping (CGImage) -> Void) {
        self.displayID = displayID
        self.imageHandler = imageHandler
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            imageHandler(cgImage)
        }
    }
}

// MARK: - NSScreen Extension

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}

// MARK: - Error Types

enum MultiScreenError: LocalizedError {
    case screenRecordingPermissionDenied
    case displayNotFound
    case invalidSpanningRegion
    case captureStreamCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionDenied:
            return "Screen recording permission is required"
        case .displayNotFound:
            return "Display not found"
        case .invalidSpanningRegion:
            return "Invalid spanning region configuration"
        case .captureStreamCreationFailed:
            return "Failed to create capture stream"
        }
    }
}

#endif