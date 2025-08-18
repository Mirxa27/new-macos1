#if os(macOS)
import Foundation
import Vision
import CoreML
import AVFoundation
import Accelerate
import os.log

/// Advanced gesture recognition system using vision and machine learning
@MainActor
class GestureRecognitionManager: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "GestureRecognition")
    
    // MARK: - Published Properties
    @Published var isRecognizing = false
    @Published var detectedGestures: [DetectedGesture] = []
    @Published var currentGesture: GestureType?
    @Published var gestureConfidence: Float = 0.0
    @Published var handPoses: [HandPose] = []
    @Published var bodyPose: BodyPose?
    @Published var isCalibrated = false
    
    // MARK: - Vision Components
    private var handPoseRequest: VNDetectHumanHandPoseRequest?
    private var bodyPoseRequest: VNDetectHumanBodyPoseRequest?
    private var faceRequest: VNDetectFaceLandmarksRequest?
    private var customGestureModel: VNCoreMLModel?
    
    // MARK: - Gesture Tracking
    private var gestureHistory: [GestureFrame] = []
    private var gestureSequence: GestureSequence?
    private var gestureClassifier: GestureClassifier?
    private var gestureTracker: GestureTracker?
    
    // MARK: - Configuration
    struct Configuration {
        var enableHandTracking = true
        var enableBodyTracking = true
        var enableFaceTracking = true
        var enableCustomGestures = true
        var maxHandsToTrack = 2
        var confidenceThreshold: Float = 0.8
        var historyWindowSize = 30 // frames
        var smoothingEnabled = true
        var gestureTimeout: TimeInterval = 2.0
    }
    
    var configuration = Configuration()
    
    // MARK: - Gesture Definitions
    private var registeredGestures: [GestureDefinition] = []
    private var customGestureCallbacks: [GestureType: (DetectedGesture) -> Void] = [:]
    
    // MARK: - Performance
    private var processingQueue = DispatchQueue(label: "com.voiceagent.gesture", qos: .userInitiated)
    private var lastProcessTime: Date = Date()
    private var frameSkipCounter = 0
    
    init() {
        setupVisionRequests()
        setupGestureClassifier()
        registerDefaultGestures()
        loadCustomGestureModel()
    }
    
    // MARK: - Setup
    
    private func setupVisionRequests() {
        // Hand pose detection
        if configuration.enableHandTracking {
            handPoseRequest = VNDetectHumanHandPoseRequest { [weak self] request, error in
                self?.handleHandPose(request: request, error: error)
            }
            handPoseRequest?.maximumHandCount = configuration.maxHandsToTrack
        }
        
        // Body pose detection
        if configuration.enableBodyTracking {
            bodyPoseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
                self?.handleBodyPose(request: request, error: error)
            }
        }
        
        // Face landmarks for head gestures
        if configuration.enableFaceTracking {
            faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
                self?.handleFaceLandmarks(request: request, error: error)
            }
        }
    }
    
    private func setupGestureClassifier() {
        gestureClassifier = GestureClassifier()
        gestureTracker = GestureTracker()
    }
    
    private func registerDefaultGestures() {
        // Register common gestures
        registeredGestures = [
            // Hand gestures
            GestureDefinition(type: .wave, requiredFrames: 15, timeout: 2.0),
            GestureDefinition(type: .thumbsUp, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .thumbsDown, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .peace, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .ok, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .pointUp, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .pointDown, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .pointLeft, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .pointRight, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .fist, requiredFrames: 10, timeout: 1.0),
            GestureDefinition(type: .openPalm, requiredFrames: 10, timeout: 1.0),
            
            // Motion gestures
            GestureDefinition(type: .swipeLeft, requiredFrames: 20, timeout: 1.5),
            GestureDefinition(type: .swipeRight, requiredFrames: 20, timeout: 1.5),
            GestureDefinition(type: .swipeUp, requiredFrames: 20, timeout: 1.5),
            GestureDefinition(type: .swipeDown, requiredFrames: 20, timeout: 1.5),
            GestureDefinition(type: .circle, requiredFrames: 30, timeout: 2.0),
            GestureDefinition(type: .pinch, requiredFrames: 15, timeout: 1.0),
            GestureDefinition(type: .spread, requiredFrames: 15, timeout: 1.0),
            
            // Body gestures
            GestureDefinition(type: .armRaise, requiredFrames: 20, timeout: 2.0),
            GestureDefinition(type: .armsCrossed, requiredFrames: 15, timeout: 2.0),
            
            // Head gestures
            GestureDefinition(type: .nod, requiredFrames: 20, timeout: 2.0),
            GestureDefinition(type: .shake, requiredFrames: 20, timeout: 2.0),
            GestureDefinition(type: .tilt, requiredFrames: 15, timeout: 1.5)
        ]
    }
    
    private func loadCustomGestureModel() {
        // Load custom Core ML model for gesture recognition if available
        guard let modelURL = Bundle.main.url(forResource: "GestureClassifier", withExtension: "mlmodelc") else {
            logger.info("No custom gesture model found")
            return
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL)
            customGestureModel = try VNCoreMLModel(for: model)
            logger.info("Custom gesture model loaded successfully")
        } catch {
            logger.error("Failed to load custom gesture model: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recognition Control
    
    func startRecognition() {
        guard !isRecognizing else { return }
        
        logger.info("Starting gesture recognition")
        isRecognizing = true
        
        // Reset state
        gestureHistory.removeAll()
        detectedGestures.removeAll()
        currentGesture = nil
    }
    
    func stopRecognition() {
        guard isRecognizing else { return }
        
        logger.info("Stopping gesture recognition")
        isRecognizing = false
    }
    
    // MARK: - Frame Processing
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isRecognizing else { return }
        
        // Skip frames for performance
        if shouldSkipFrame() {
            frameSkipCounter += 1
            return
        }
        
        processingQueue.async { [weak self] in
            self?.analyzeFrame(pixelBuffer)
        }
    }
    
    private func shouldSkipFrame() -> Bool {
        // Process every 2nd frame for performance
        return frameSkipCounter % 2 != 0
    }
    
    private func analyzeFrame(_ pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        var requests: [VNRequest] = []
        
        if let handRequest = handPoseRequest {
            requests.append(handRequest)
        }
        
        if let bodyRequest = bodyPoseRequest {
            requests.append(bodyRequest)
        }
        
        if let faceRequest = faceRequest {
            requests.append(faceRequest)
        }
        
        // Add custom model request if available
        if let customModel = customGestureModel {
            let customRequest = VNCoreMLRequest(model: customModel) { [weak self] request, error in
                self?.handleCustomGesture(request: request, error: error)
            }
            requests.append(customRequest)
        }
        
        do {
            try handler.perform(requests)
            
            // Process accumulated data
            processGestureData()
            
        } catch {
            logger.error("Failed to perform vision requests: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Vision Handlers
    
    private func handleHandPose(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanHandPoseObservation] else { return }
        
        Task { @MainActor in
            self.handPoses = observations.compactMap { observation in
                self.createHandPose(from: observation)
            }
            
            // Detect hand gestures
            for handPose in self.handPoses {
                if let gesture = self.detectHandGesture(handPose) {
                    self.addDetectedGesture(gesture)
                }
            }
        }
    }
    
    private func handleBodyPose(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNHumanBodyPoseObservation],
              let observation = observations.first else { return }
        
        Task { @MainActor in
            self.bodyPose = self.createBodyPose(from: observation)
            
            // Detect body gestures
            if let bodyPose = self.bodyPose,
               let gesture = self.detectBodyGesture(bodyPose) {
                self.addDetectedGesture(gesture)
            }
        }
    }
    
    private func handleFaceLandmarks(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation],
              let observation = observations.first,
              let landmarks = observation.landmarks else { return }
        
        Task { @MainActor in
            // Detect head gestures
            if let gesture = self.detectHeadGesture(from: landmarks) {
                self.addDetectedGesture(gesture)
            }
        }
    }
    
    private func handleCustomGesture(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation],
              let topResult = results.first else { return }
        
        Task { @MainActor in
            if topResult.confidence >= self.configuration.confidenceThreshold {
                let gesture = DetectedGesture(
                    type: .custom(topResult.identifier),
                    confidence: topResult.confidence,
                    timestamp: Date(),
                    boundingBox: nil,
                    landmarks: nil
                )
                self.addDetectedGesture(gesture)
            }
        }
    }
    
    // MARK: - Gesture Detection
    
    private func createHandPose(from observation: VNHumanHandPoseObservation) -> HandPose? {
        do {
            let points = try observation.recognizedPoints(.all)
            
            // Extract key points
            let thumb = points[.thumbTip]
            let index = points[.indexTip]
            let middle = points[.middleTip]
            let ring = points[.ringTip]
            let little = points[.littleTip]
            let wrist = points[.wrist]
            
            return HandPose(
                thumb: thumb?.location,
                index: index?.location,
                middle: middle?.location,
                ring: ring?.location,
                little: little?.location,
                wrist: wrist?.location,
                confidence: observation.confidence,
                chirality: observation.chirality
            )
        } catch {
            logger.error("Failed to extract hand pose: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func createBodyPose(from observation: VNHumanBodyPoseObservation) -> BodyPose? {
        do {
            let points = try observation.recognizedPoints(.all)
            
            return BodyPose(
                head: points[.nose]?.location,
                leftShoulder: points[.leftShoulder]?.location,
                rightShoulder: points[.rightShoulder]?.location,
                leftElbow: points[.leftElbow]?.location,
                rightElbow: points[.rightElbow]?.location,
                leftWrist: points[.leftWrist]?.location,
                rightWrist: points[.rightWrist]?.location,
                leftHip: points[.leftHip]?.location,
                rightHip: points[.rightHip]?.location,
                confidence: observation.confidence
            )
        } catch {
            logger.error("Failed to extract body pose: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func detectHandGesture(_ handPose: HandPose) -> DetectedGesture? {
        // Analyze finger positions to detect gestures
        
        // Thumbs up detection
        if isThumbsUp(handPose) {
            return DetectedGesture(
                type: .thumbsUp,
                confidence: handPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        // Peace sign detection
        if isPeaceSign(handPose) {
            return DetectedGesture(
                type: .peace,
                confidence: handPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        // OK sign detection
        if isOKSign(handPose) {
            return DetectedGesture(
                type: .ok,
                confidence: handPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        // Pointing detection
        if let direction = getPointingDirection(handPose) {
            return DetectedGesture(
                type: direction,
                confidence: handPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        // Fist detection
        if isFist(handPose) {
            return DetectedGesture(
                type: .fist,
                confidence: handPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        // Open palm detection
        if isOpenPalm(handPose) {
            return DetectedGesture(
                type: .openPalm,
                confidence: handPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        return nil
    }
    
    private func detectBodyGesture(_ bodyPose: BodyPose) -> DetectedGesture? {
        // Arms raised detection
        if areArmsRaised(bodyPose) {
            return DetectedGesture(
                type: .armRaise,
                confidence: bodyPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        // Arms crossed detection
        if areArmsCrossed(bodyPose) {
            return DetectedGesture(
                type: .armsCrossed,
                confidence: bodyPose.confidence,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        return nil
    }
    
    private func detectHeadGesture(from landmarks: VNFaceLandmarks2D) -> DetectedGesture? {
        // Store landmarks in history for motion detection
        let frame = GestureFrame(
            timestamp: Date(),
            handPoses: handPoses,
            bodyPose: bodyPose,
            faceLandmarks: landmarks
        )
        
        gestureHistory.append(frame)
        
        // Keep history window size limited
        if gestureHistory.count > configuration.historyWindowSize {
            gestureHistory.removeFirst()
        }
        
        // Detect head motion patterns
        if isNodding() {
            return DetectedGesture(
                type: .nod,
                confidence: 0.9,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        if isShaking() {
            return DetectedGesture(
                type: .shake,
                confidence: 0.9,
                timestamp: Date(),
                boundingBox: nil,
                landmarks: nil
            )
        }
        
        return nil
    }
    
    // MARK: - Gesture Analysis
    
    private func isThumbsUp(_ hand: HandPose) -> Bool {
        guard let thumb = hand.thumb,
              let index = hand.index,
              let middle = hand.middle,
              let ring = hand.ring,
              let little = hand.little else { return false }
        
        // Thumb should be up, other fingers down
        return thumb.y > index.y &&
               index.y < middle.y &&
               middle.y < ring.y &&
               ring.y < little.y
    }
    
    private func isPeaceSign(_ hand: HandPose) -> Bool {
        guard let index = hand.index,
              let middle = hand.middle,
              let ring = hand.ring,
              let little = hand.little else { return false }
        
        // Index and middle up, others down
        let indexUp = index.y > ring.y
        let middleUp = middle.y > ring.y
        let ringDown = ring.y < index.y
        let littleDown = little.y < middle.y
        
        return indexUp && middleUp && ringDown && littleDown
    }
    
    private func isOKSign(_ hand: HandPose) -> Bool {
        guard let thumb = hand.thumb,
              let index = hand.index else { return false }
        
        // Thumb and index tips close together
        let distance = sqrt(pow(thumb.x - index.x, 2) + pow(thumb.y - index.y, 2))
        return distance < 0.05
    }
    
    private func getPointingDirection(_ hand: HandPose) -> GestureType? {
        guard let index = hand.index,
              let middle = hand.middle,
              let wrist = hand.wrist else { return nil }
        
        // Check if index is extended
        let indexExtended = distance(from: index, to: wrist) > distance(from: middle, to: wrist)
        
        if indexExtended {
            // Determine direction
            let angle = atan2(index.y - wrist.y, index.x - wrist.x)
            
            if angle > -0.25 * .pi && angle < 0.25 * .pi {
                return .pointRight
            } else if angle > 0.25 * .pi && angle < 0.75 * .pi {
                return .pointUp
            } else if angle > -0.75 * .pi && angle < -0.25 * .pi {
                return .pointDown
            } else {
                return .pointLeft
            }
        }
        
        return nil
    }
    
    private func isFist(_ hand: HandPose) -> Bool {
        guard let thumb = hand.thumb,
              let index = hand.index,
              let middle = hand.middle,
              let ring = hand.ring,
              let little = hand.little,
              let wrist = hand.wrist else { return false }
        
        // All fingers close to wrist
        let avgDistance = [thumb, index, middle, ring, little]
            .map { distance(from: $0, to: wrist) }
            .reduce(0, +) / 5
        
        return avgDistance < 0.15
    }
    
    private func isOpenPalm(_ hand: HandPose) -> Bool {
        guard let thumb = hand.thumb,
              let index = hand.index,
              let middle = hand.middle,
              let ring = hand.ring,
              let little = hand.little,
              let wrist = hand.wrist else { return false }
        
        // All fingers extended
        let avgDistance = [thumb, index, middle, ring, little]
            .map { distance(from: $0, to: wrist) }
            .reduce(0, +) / 5
        
        return avgDistance > 0.25
    }
    
    private func areArmsRaised(_ body: BodyPose) -> Bool {
        guard let leftWrist = body.leftWrist,
              let rightWrist = body.rightWrist,
              let leftShoulder = body.leftShoulder,
              let rightShoulder = body.rightShoulder else { return false }
        
        // Both wrists above shoulders
        return leftWrist.y > leftShoulder.y && rightWrist.y > rightShoulder.y
    }
    
    private func areArmsCrossed(_ body: BodyPose) -> Bool {
        guard let leftWrist = body.leftWrist,
              let rightWrist = body.rightWrist,
              let leftShoulder = body.leftShoulder,
              let rightShoulder = body.rightShoulder else { return false }
        
        // Wrists on opposite sides of body
        let leftCrossed = leftWrist.x > rightShoulder.x
        let rightCrossed = rightWrist.x < leftShoulder.x
        
        return leftCrossed && rightCrossed
    }
    
    private func isNodding() -> Bool {
        guard gestureHistory.count >= 20 else { return false }
        
        // Analyze vertical head movement pattern
        let recentFrames = Array(gestureHistory.suffix(20))
        var verticalMovements: [CGFloat] = []
        
        for i in 1..<recentFrames.count {
            if let current = recentFrames[i].faceLandmarks?.noseCrest?.normalizedPoints.first,
               let previous = recentFrames[i-1].faceLandmarks?.noseCrest?.normalizedPoints.first {
                verticalMovements.append(current.y - previous.y)
            }
        }
        
        // Look for up-down pattern
        return detectOscillation(in: verticalMovements, threshold: 0.01)
    }
    
    private func isShaking() -> Bool {
        guard gestureHistory.count >= 20 else { return false }
        
        // Analyze horizontal head movement pattern
        let recentFrames = Array(gestureHistory.suffix(20))
        var horizontalMovements: [CGFloat] = []
        
        for i in 1..<recentFrames.count {
            if let current = recentFrames[i].faceLandmarks?.noseCrest?.normalizedPoints.first,
               let previous = recentFrames[i-1].faceLandmarks?.noseCrest?.normalizedPoints.first {
                horizontalMovements.append(current.x - previous.x)
            }
        }
        
        // Look for left-right pattern
        return detectOscillation(in: horizontalMovements, threshold: 0.01)
    }
    
    private func detectOscillation(in values: [CGFloat], threshold: CGFloat) -> Bool {
        guard values.count >= 4 else { return false }
        
        var signChanges = 0
        var previousSign = values[0] > 0
        
        for value in values.dropFirst() {
            let currentSign = value > 0
            if currentSign != previousSign && abs(value) > threshold {
                signChanges += 1
                previousSign = currentSign
            }
        }
        
        return signChanges >= 3
    }
    
    // MARK: - Gesture Processing
    
    private func processGestureData() {
        // Analyze gesture sequence for complex gestures
        detectMotionGestures()
        
        // Clean up old gestures
        cleanupOldGestures()
    }
    
    private func detectMotionGestures() {
        guard gestureHistory.count >= 10 else { return }
        
        // Detect swipe gestures
        if let swipe = detectSwipe() {
            addDetectedGesture(swipe)
        }
        
        // Detect circle gesture
        if let circle = detectCircle() {
            addDetectedGesture(circle)
        }
        
        // Detect pinch/spread
        if let pinchSpread = detectPinchSpread() {
            addDetectedGesture(pinchSpread)
        }
    }
    
    private func detectSwipe() -> DetectedGesture? {
        guard let tracker = gestureTracker,
              handPoses.count > 0 else { return nil }
        
        let motion = tracker.analyzeMotion(from: gestureHistory)
        
        switch motion {
        case .swipeLeft:
            return DetectedGesture(type: .swipeLeft, confidence: 0.85, timestamp: Date())
        case .swipeRight:
            return DetectedGesture(type: .swipeRight, confidence: 0.85, timestamp: Date())
        case .swipeUp:
            return DetectedGesture(type: .swipeUp, confidence: 0.85, timestamp: Date())
        case .swipeDown:
            return DetectedGesture(type: .swipeDown, confidence: 0.85, timestamp: Date())
        default:
            return nil
        }
    }
    
    private func detectCircle() -> DetectedGesture? {
        // Implement circle detection logic
        return nil
    }
    
    private func detectPinchSpread() -> DetectedGesture? {
        guard handPoses.count >= 1,
              let hand = handPoses.first,
              let thumb = hand.thumb,
              let index = hand.index else { return nil }
        
        let currentDistance = distance(from: thumb, to: index)
        
        // Compare with previous frames
        if gestureHistory.count >= 10 {
            let previousFrames = Array(gestureHistory.suffix(10))
            if let previousHand = previousFrames.first?.handPoses.first,
               let prevThumb = previousHand.thumb,
               let prevIndex = previousHand.index {
                
                let previousDistance = distance(from: prevThumb, to: prevIndex)
                let change = currentDistance - previousDistance
                
                if change < -0.05 {
                    return DetectedGesture(type: .pinch, confidence: 0.8, timestamp: Date())
                } else if change > 0.05 {
                    return DetectedGesture(type: .spread, confidence: 0.8, timestamp: Date())
                }
            }
        }
        
        return nil
    }
    
    private func addDetectedGesture(_ gesture: DetectedGesture) {
        Task { @MainActor in
            self.detectedGestures.append(gesture)
            self.currentGesture = gesture.type
            self.gestureConfidence = gesture.confidence
            
            // Trigger callback if registered
            if let callback = self.customGestureCallbacks[gesture.type] {
                callback(gesture)
            }
            
            // Send notification
            NotificationCenter.default.post(
                name: .gestureDetected,
                object: nil,
                userInfo: ["gesture": gesture]
            )
        }
    }
    
    private func cleanupOldGestures() {
        let cutoffTime = Date().addingTimeInterval(-5.0)
        detectedGestures = detectedGestures.filter { $0.timestamp > cutoffTime }
    }
    
    // MARK: - Calibration
    
    func calibrate() async {
        logger.info("Starting gesture calibration")
        
        // Implement calibration logic
        // Could involve recording baseline poses, adjusting thresholds, etc.
        
        isCalibrated = true
    }
    
    // MARK: - Custom Gestures
    
    func registerCustomGesture(_ definition: GestureDefinition, callback: @escaping (DetectedGesture) -> Void) {
        registeredGestures.append(definition)
        customGestureCallbacks[definition.type] = callback
        
        logger.info("Registered custom gesture: \(definition.type)")
    }
    
    func trainCustomGesture(name: String, samples: [CVPixelBuffer]) async throws {
        // Implement custom gesture training using Core ML Create
        logger.info("Training custom gesture: \(name)")
    }
    
    // MARK: - Utility
    
    private func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
    }
}

// MARK: - Supporting Classes

class GestureClassifier {
    func classify(poses: [HandPose]) -> GestureType? {
        // Implement gesture classification logic
        return nil
    }
}

class GestureTracker {
    func analyzeMotion(from history: [GestureFrame]) -> MotionType {
        // Implement motion analysis
        return .none
    }
}

// MARK: - Data Models

enum GestureType: Hashable {
    // Hand gestures
    case wave
    case thumbsUp
    case thumbsDown
    case peace
    case ok
    case pointUp
    case pointDown
    case pointLeft
    case pointRight
    case fist
    case openPalm
    
    // Motion gestures
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case circle
    case pinch
    case spread
    
    // Body gestures
    case armRaise
    case armsCrossed
    
    // Head gestures
    case nod
    case shake
    case tilt
    
    // Custom
    case custom(String)
}

enum MotionType {
    case none
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case circle
    case pinch
    case spread
}

struct DetectedGesture: Identifiable {
    let id = UUID()
    let type: GestureType
    let confidence: Float
    let timestamp: Date
    var boundingBox: CGRect?
    var landmarks: [CGPoint]?
}

struct HandPose {
    let thumb: CGPoint?
    let index: CGPoint?
    let middle: CGPoint?
    let ring: CGPoint?
    let little: CGPoint?
    let wrist: CGPoint?
    let confidence: Float
    let chirality: VNChirality
}

struct BodyPose {
    let head: CGPoint?
    let leftShoulder: CGPoint?
    let rightShoulder: CGPoint?
    let leftElbow: CGPoint?
    let rightElbow: CGPoint?
    let leftWrist: CGPoint?
    let rightWrist: CGPoint?
    let leftHip: CGPoint?
    let rightHip: CGPoint?
    let confidence: Float
}

struct GestureFrame {
    let timestamp: Date
    let handPoses: [HandPose]
    let bodyPose: BodyPose?
    let faceLandmarks: VNFaceLandmarks2D?
}

struct GestureSequence {
    let frames: [GestureFrame]
    let startTime: Date
    let endTime: Date
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct GestureDefinition {
    let type: GestureType
    let requiredFrames: Int
    let timeout: TimeInterval
}

// MARK: - Notifications

extension Notification.Name {
    static let gestureDetected = Notification.Name("gestureDetected")
    static let gestureCalibrationComplete = Notification.Name("gestureCalibrationComplete")
}

#endif