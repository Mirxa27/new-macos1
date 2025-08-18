#if os(macOS)
import Foundation
import AppKit
import CoreGraphics
import os.log

/// Records and plays back user automation sequences
@MainActor
class AutomationRecorder: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "AutomationRecorder")
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordings: [AutomationRecording] = []
    @Published var currentRecording: AutomationRecording?
    @Published var playbackSpeed: Float = 1.0
    @Published var lastError: String?
    
    // MARK: - Recording State
    private var recordingStartTime: Date?
    private var recordedEvents: [AutomationEvent] = []
    private var eventMonitors: [Any] = []
    private var mouseTracker: Timer?
    private var lastMousePosition: CGPoint?
    private var keyboardMonitor: Any?
    private var screenCaptures: [ScreenCapture] = []
    
    // MARK: - Playback State
    private var playbackTask: Task<Void, Never>?
    private var playbackPaused = false
    private var currentEventIndex = 0
    
    // MARK: - Configuration
    var captureMouseMovement = true
    var captureKeyboard = true
    var captureScreenshots = true
    var mouseTrackingInterval: TimeInterval = 0.1
    var compressionEnabled = true
    var maxRecordingDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Storage
    private let recordingsDirectory: URL
    
    init() {
        // Setup recordings directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        recordingsDirectory = appSupport.appendingPathComponent("VoiceAgent/Recordings")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        
        // Load existing recordings
        loadRecordings()
    }
    
    // MARK: - Recording Control
    
    func startRecording(name: String? = nil) {
        guard !isRecording else { return }
        
        logger.info("Starting automation recording")
        
        isRecording = true
        recordingStartTime = Date()
        recordedEvents = []
        screenCaptures = []
        
        // Create new recording
        currentRecording = AutomationRecording(
            id: UUID(),
            name: name ?? "Recording \(Date().formatted())",
            createdAt: Date(),
            duration: 0,
            events: [],
            screenshots: [],
            metadata: RecordingMetadata()
        )
        
        // Setup event monitors
        setupEventMonitors()
        
        // Start timeout timer
        startRecordingTimeout()
        
        // Capture initial screenshot
        if captureScreenshots {
            captureCurrentScreen()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        logger.info("Stopping automation recording")
        
        isRecording = false
        
        // Remove event monitors
        removeEventMonitors()
        
        // Finalize recording
        if var recording = currentRecording {
            recording.duration = Date().timeIntervalSince(recordingStartTime ?? Date())
            recording.events = optimizeEvents(recordedEvents)
            recording.screenshots = screenCaptures
            recording.metadata.eventCount = recording.events.count
            recording.metadata.hasMouseEvents = recording.events.contains { $0.type.isMouseEvent }
            recording.metadata.hasKeyboardEvents = recording.events.contains { $0.type.isKeyboardEvent }
            
            // Save recording
            saveRecording(recording)
            recordings.append(recording)
            
            currentRecording = recording
        }
        
        recordingStartTime = nil
        recordedEvents = []
        screenCaptures = []
    }
    
    func pauseRecording() {
        guard isRecording else { return }
        
        // Add pause event
        addEvent(.pause)
        
        // Temporarily disable monitors
        removeEventMonitors()
    }
    
    func resumeRecording() {
        guard isRecording else { return }
        
        // Add resume event
        addEvent(.resume)
        
        // Re-enable monitors
        setupEventMonitors()
    }
    
    // MARK: - Event Monitoring
    
    private func setupEventMonitors() {
        // Monitor mouse events
        if captureMouseMovement {
            setupMouseMonitoring()
        }
        
        // Monitor keyboard events
        if captureKeyboard {
            setupKeyboardMonitoring()
        }
        
        // Monitor other events
        setupSystemEventMonitoring()
    }
    
    private func setupMouseMonitoring() {
        // Monitor mouse clicks
        let mouseEvents: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .scrollWheel
        ]
        
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { event in
            self.handleMouseEvent(event)
        } {
            eventMonitors.append(monitor)
        }
        
        // Track mouse position periodically
        mouseTracker = Timer.scheduledTimer(withTimeInterval: mouseTrackingInterval, repeats: true) { _ in
            self.trackMousePosition()
        }
    }
    
    private func setupKeyboardMonitoring() {
        let keyboardEvents: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
        
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: keyboardEvents) { event in
            self.handleKeyboardEvent(event)
        } {
            eventMonitors.append(monitor)
        }
    }
    
    private func setupSystemEventMonitoring() {
        // Monitor app switching
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    private func removeEventMonitors() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
        
        mouseTracker?.invalidate()
        mouseTracker = nil
        
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    // MARK: - Event Handlers
    
    private func handleMouseEvent(_ event: NSEvent) {
        guard isRecording else { return }
        
        let location = CGPoint(x: event.locationInWindow.x, y: event.locationInWindow.y)
        
        switch event.type {
        case .leftMouseDown:
            addEvent(.mouseDown(location: location, button: .left))
            
        case .leftMouseUp:
            addEvent(.mouseUp(location: location, button: .left))
            
        case .rightMouseDown:
            addEvent(.mouseDown(location: location, button: .right))
            
        case .rightMouseUp:
            addEvent(.mouseUp(location: location, button: .right))
            
        case .leftMouseDragged, .rightMouseDragged:
            addEvent(.mouseDrag(from: lastMousePosition ?? location, to: location))
            
        case .scrollWheel:
            addEvent(.scroll(deltaX: event.deltaX, deltaY: event.deltaY))
            
        default:
            break
        }
        
        lastMousePosition = location
    }
    
    private func handleKeyboardEvent(_ event: NSEvent) {
        guard isRecording else { return }
        
        switch event.type {
        case .keyDown:
            if let characters = event.characters {
                addEvent(.keyPress(key: event.keyCode, characters: characters, modifiers: event.modifierFlags))
            }
            
        case .keyUp:
            addEvent(.keyRelease(key: event.keyCode))
            
        case .flagsChanged:
            addEvent(.modifierChange(modifiers: event.modifierFlags))
            
        default:
            break
        }
    }
    
    private func trackMousePosition() {
        guard isRecording, captureMouseMovement else { return }
        
        let currentPosition = NSEvent.mouseLocation
        
        if let lastPosition = lastMousePosition,
           distance(from: lastPosition, to: currentPosition) > 5 {
            addEvent(.mouseMove(location: currentPosition))
            lastMousePosition = currentPosition
        }
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        guard isRecording,
              let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else { return }
        
        addEvent(.appSwitch(bundleID: bundleID, appName: app.localizedName ?? bundleID))
    }
    
    // MARK: - Event Management
    
    private func addEvent(_ eventType: AutomationEventType) {
        let timestamp = Date().timeIntervalSince(recordingStartTime ?? Date())
        
        let event = AutomationEvent(
            id: UUID(),
            type: eventType,
            timestamp: timestamp,
            metadata: nil
        )
        
        recordedEvents.append(event)
        
        // Capture screenshot for significant events
        if captureScreenshots && eventType.isSignificant {
            captureCurrentScreen()
        }
    }
    
    private func optimizeEvents(_ events: [AutomationEvent]) -> [AutomationEvent] {
        guard compressionEnabled else { return events }
        
        var optimized: [AutomationEvent] = []
        var lastMouseMove: AutomationEvent?
        
        for event in events {
            switch event.type {
            case .mouseMove:
                // Compress consecutive mouse moves
                lastMouseMove = event
                
            default:
                // Add pending mouse move if exists
                if let mouseMove = lastMouseMove {
                    optimized.append(mouseMove)
                    lastMouseMove = nil
                }
                optimized.append(event)
            }
        }
        
        // Add final mouse move if exists
        if let mouseMove = lastMouseMove {
            optimized.append(mouseMove)
        }
        
        return optimized
    }
    
    // MARK: - Playback Control
    
    func startPlayback(_ recording: AutomationRecording) {
        guard !isPlaying else { return }
        
        logger.info("Starting playback of: \(recording.name)")
        
        isPlaying = true
        playbackPaused = false
        currentEventIndex = 0
        currentRecording = recording
        
        playbackTask = Task {
            await playbackEvents(recording.events)
        }
    }
    
    func stopPlayback() {
        guard isPlaying else { return }
        
        logger.info("Stopping playback")
        
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
        currentEventIndex = 0
    }
    
    func pausePlayback() {
        playbackPaused = true
    }
    
    func resumePlayback() {
        playbackPaused = false
    }
    
    private func playbackEvents(_ events: [AutomationEvent]) async {
        for (index, event) in events.enumerated() {
            // Check if cancelled
            if Task.isCancelled { break }
            
            // Wait if paused
            while playbackPaused && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            currentEventIndex = index
            
            // Calculate delay
            if index > 0 {
                let previousTimestamp = events[index - 1].timestamp
                let delay = (event.timestamp - previousTimestamp) / Double(playbackSpeed)
                
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            
            // Execute event
            await executeEvent(event)
        }
        
        await MainActor.run {
            self.isPlaying = false
            self.currentEventIndex = 0
        }
    }
    
    private func executeEvent(_ event: AutomationEvent) async {
        switch event.type {
        case .mouseMove(let location):
            moveMouseSmooth(to: location)
            
        case .mouseDown(let location, let button):
            moveMouse(to: location)
            mouseDown(button: button)
            
        case .mouseUp(let location, let button):
            moveMouse(to: location)
            mouseUp(button: button)
            
        case .mouseDrag(let from, let to):
            dragMouse(from: from, to: to)
            
        case .scroll(let deltaX, let deltaY):
            scroll(deltaX: deltaX, deltaY: deltaY)
            
        case .keyPress(let key, let characters, let modifiers):
            pressKey(key, characters: characters, modifiers: modifiers)
            
        case .keyRelease(let key):
            releaseKey(key)
            
        case .modifierChange(let modifiers):
            setModifiers(modifiers)
            
        case .appSwitch(let bundleID, _):
            switchToApp(bundleID)
            
        case .wait(let duration):
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            
        case .pause, .resume:
            break // Handled during recording
            
        case .custom(let name, let data):
            logger.info("Custom event: \(name)")
        }
    }
    
    // MARK: - System Control
    
    private func moveMouse(to point: CGPoint) {
        CGWarpMouseCursorPosition(point)
    }
    
    private func moveMouseSmooth(to point: CGPoint) {
        // Smooth mouse movement animation
        let currentLocation = NSEvent.mouseLocation
        let steps = 10
        
        for i in 1...steps {
            let progress = CGFloat(i) / CGFloat(steps)
            let x = currentLocation.x + (point.x - currentLocation.x) * progress
            let y = currentLocation.y + (point.y - currentLocation.y) * progress
            
            CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
    
    private func mouseDown(button: MouseButton) {
        let location = NSEvent.mouseLocation
        let eventType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: eventType,
            mouseCursorPosition: location,
            mouseButton: button == .left ? .left : .right
        ) else { return }
        
        event.post(tap: .cghidEventTap)
    }
    
    private func mouseUp(button: MouseButton) {
        let location = NSEvent.mouseLocation
        let eventType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
        
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: eventType,
            mouseCursorPosition: location,
            mouseButton: button == .left ? .left : .right
        ) else { return }
        
        event.post(tap: .cghidEventTap)
    }
    
    private func dragMouse(from: CGPoint, to: CGPoint) {
        moveMouse(to: from)
        mouseDown(button: .left)
        moveMouseSmooth(to: to)
        mouseUp(button: .left)
    }
    
    private func scroll(deltaX: CGFloat, deltaY: CGFloat) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        ) else { return }
        
        event.post(tap: .cghidEventTap)
    }
    
    private func pressKey(_ keyCode: CGKeyCode, characters: String, modifiers: NSEvent.ModifierFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        
        // Set modifier flags
        event.flags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))
        
        event.post(tap: .cghidEventTap)
    }
    
    private func releaseKey(_ keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        event.post(tap: .cghidEventTap)
    }
    
    private func setModifiers(_ modifiers: NSEvent.ModifierFlags) {
        // Set modifier key states
        logger.debug("Setting modifiers: \(modifiers)")
    }
    
    private func switchToApp(_ bundleID: String) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
    
    // MARK: - Screenshot Capture
    
    private func captureCurrentScreen() {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else { return }
        
        let capture = ScreenCapture(
            timestamp: Date().timeIntervalSince(recordingStartTime ?? Date()),
            image: image
        )
        
        screenCaptures.append(capture)
    }
    
    // MARK: - Storage
    
    private func saveRecording(_ recording: AutomationRecording) {
        let url = recordingsDirectory.appendingPathComponent("\(recording.id.uuidString).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(recording)
            try data.write(to: url)
            
            logger.info("Saved recording: \(recording.name)")
        } catch {
            logger.error("Failed to save recording: \(error.localizedDescription)")
            lastError = "Failed to save recording"
        }
    }
    
    private func loadRecordings() {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: recordingsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for url in contents where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let recording = try decoder.decode(AutomationRecording.self, from: data)
                recordings.append(recording)
            } catch {
                logger.error("Failed to load recording: \(error.localizedDescription)")
            }
        }
        
        logger.info("Loaded \(recordings.count) recordings")
    }
    
    func deleteRecording(_ recording: AutomationRecording) {
        recordings.removeAll { $0.id == recording.id }
        
        let url = recordingsDirectory.appendingPathComponent("\(recording.id.uuidString).json")
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Export/Import
    
    func exportRecording(_ recording: AutomationRecording, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(recording)
        try data.write(to: url)
    }
    
    func importRecording(from url: URL) throws -> AutomationRecording {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let recording = try decoder.decode(AutomationRecording.self, from: data)
        recordings.append(recording)
        saveRecording(recording)
        
        return recording
    }
    
    // MARK: - Utility
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func startRecordingTimeout() {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(maxRecordingDuration * 1_000_000_000))
            
            if isRecording {
                await MainActor.run {
                    self.stopRecording()
                    self.lastError = "Recording stopped: Maximum duration reached"
                }
            }
        }
    }
}

// MARK: - Data Models

struct AutomationRecording: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var duration: TimeInterval
    var events: [AutomationEvent]
    var screenshots: [ScreenCapture]
    var metadata: RecordingMetadata
}

struct AutomationEvent: Codable, Identifiable {
    let id: UUID
    let type: AutomationEventType
    let timestamp: TimeInterval
    let metadata: [String: String]?
}

enum AutomationEventType: Codable {
    case mouseMove(location: CGPoint)
    case mouseDown(location: CGPoint, button: MouseButton)
    case mouseUp(location: CGPoint, button: MouseButton)
    case mouseDrag(from: CGPoint, to: CGPoint)
    case scroll(deltaX: CGFloat, deltaY: CGFloat)
    case keyPress(key: CGKeyCode, characters: String, modifiers: NSEvent.ModifierFlags)
    case keyRelease(key: CGKeyCode)
    case modifierChange(modifiers: NSEvent.ModifierFlags)
    case appSwitch(bundleID: String, appName: String)
    case wait(duration: TimeInterval)
    case pause
    case resume
    case custom(name: String, data: [String: String])
    
    var isMouseEvent: Bool {
        switch self {
        case .mouseMove, .mouseDown, .mouseUp, .mouseDrag, .scroll:
            return true
        default:
            return false
        }
    }
    
    var isKeyboardEvent: Bool {
        switch self {
        case .keyPress, .keyRelease, .modifierChange:
            return true
        default:
            return false
        }
    }
    
    var isSignificant: Bool {
        switch self {
        case .mouseDown, .mouseUp, .keyPress, .appSwitch:
            return true
        default:
            return false
        }
    }
}

enum MouseButton: String, Codable {
    case left
    case right
    case middle
}

struct ScreenCapture: Codable {
    let timestamp: TimeInterval
    let imageData: Data?
    
    init(timestamp: TimeInterval, image: CGImage) {
        self.timestamp = timestamp
        
        // Convert CGImage to Data
        if let data = CFDataCreateMutable(nil, 0),
           let destination = CGImageDestinationCreateWithData(data, kUTTypePNG, 1, nil) {
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
            self.imageData = data as Data
        } else {
            self.imageData = nil
        }
    }
}

struct RecordingMetadata: Codable {
    var eventCount: Int = 0
    var hasMouseEvents: Bool = false
    var hasKeyboardEvents: Bool = false
    var hasScreenshots: Bool = false
    var tags: [String] = []
    var description: String?
}

#endif