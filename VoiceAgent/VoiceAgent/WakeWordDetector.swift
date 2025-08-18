#if os(macOS)
import Foundation
import AVFoundation
import Speech
import Accelerate
import os.log

/// Advanced wake word detection system using audio analysis and speech recognition
@MainActor
class WakeWordDetector: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "WakeWord")
    
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var isDetected = false
    @Published var confidence: Float = 0.0
    @Published var lastDetectionTime: Date?
    @Published var detectionCount = 0
    
    // MARK: - Configuration
    @Published var wakeWord = "Hey Assistant"
    @Published var sensitivity: Float = 0.7 // 0.0 to 1.0
    @Published var usePhonemeMatching = true
    @Published var useContinuousListening = true
    @Published var timeoutInterval: TimeInterval = 30.0 // Auto-stop after detection
    
    // MARK: - Audio Components
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    private var audioBuffer: AVAudioPCMBuffer?
    
    // MARK: - Speech Recognition
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Audio Analysis
    private var fftSetup: FFTSetup?
    private let fftSize = 2048
    private var energyThreshold: Float = 0.01
    private var previousEnergy: Float = 0.0
    
    // MARK: - Detection State
    private var isProcessing = false
    private var detectionTimer: Timer?
    private var cooldownTimer: Timer?
    private let cooldownInterval: TimeInterval = 2.0
    
    // MARK: - Callbacks
    var onWakeWordDetected: ((String, Float) -> Void)?
    var onTimeout: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Wake Word Variations
    private var wakeWordVariations: [String] = []
    private var phonemePatterns: [String] = []
    
    // MARK: - Performance Metrics
    private var detectionLatency: TimeInterval = 0
    private var falsePositiveCount = 0
    private var missedDetectionCount = 0
    
    init() {
        setupAudioSession()
        setupSpeechRecognizer()
        setupFFT()
        generateWakeWordVariations()
    }
    
    deinit {
        stopListening()
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Request microphone permission if needed
            audioSession.requestRecordPermission { [weak self] granted in
                if !granted {
                    Task { @MainActor in
                        self?.logger.error("Microphone permission denied")
                        self?.onError?(WakeWordError.microphonePermissionDenied)
                    }
                }
            }
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription)")
            onError?(error)
        }
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                if status != .authorized {
                    self?.logger.error("Speech recognition not authorized")
                    self?.onError?(WakeWordError.speechRecognitionNotAuthorized)
                }
            }
        }
    }
    
    private func setupFFT() {
        fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))
    }
    
    // MARK: - Wake Word Management
    
    func updateWakeWord(_ newWakeWord: String) {
        wakeWord = newWakeWord
        generateWakeWordVariations()
        
        if isListening {
            restartListening()
        }
    }
    
    private func generateWakeWordVariations() {
        wakeWordVariations = [
            wakeWord.lowercased(),
            wakeWord.uppercased(),
            wakeWord.capitalized
        ]
        
        // Add common variations
        let words = wakeWord.lowercased().components(separatedBy: " ")
        if words.count > 1 {
            // Add variations without spaces
            wakeWordVariations.append(words.joined())
            
            // Add variations with different word orders (for 2-word phrases)
            if words.count == 2 {
                wakeWordVariations.append("\(words[1]) \(words[0])")
            }
        }
        
        // Generate phoneme patterns if enabled
        if usePhonemeMatching {
            generatePhonemePatterns()
        }
    }
    
    private func generatePhonemePatterns() {
        // Simplified phoneme generation - in production, use a proper phoneme library
        phonemePatterns = wakeWordVariations.map { variation in
            variation
                .replacingOccurrences(of: "hey", with: "HH EY")
                .replacingOccurrences(of: "hi", with: "HH AY")
                .replacingOccurrences(of: "hello", with: "HH AH L OW")
                .replacingOccurrences(of: "assistant", with: "AH S IH S T AH N T")
                .replacingOccurrences(of: "computer", with: "K AH M P Y UW T ER")
        }
    }
    
    // MARK: - Listening Control
    
    func startListening() {
        guard !isListening else { return }
        
        logger.info("Starting wake word detection for: \(self.wakeWord)")
        
        do {
            try setupAudioEngine()
            try startAudioEngine()
            startSpeechRecognition()
            
            isListening = true
            isDetected = false
            
            if useContinuousListening {
                startDetectionTimer()
            }
            
        } catch {
            logger.error("Failed to start listening: \(error.localizedDescription)")
            onError?(error)
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        logger.info("Stopping wake word detection")
        
        isListening = false
        isDetected = false
        
        stopAudioEngine()
        stopSpeechRecognition()
        stopDetectionTimer()
        stopCooldownTimer()
    }
    
    private func restartListening() {
        stopListening()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startListening()
        }
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw WakeWordError.audioEngineSetupFailed
        }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw WakeWordError.audioInputNodeUnavailable
        }
        
        audioFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 1024
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: audioFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
    }
    
    private func startAudioEngine() throws {
        guard let audioEngine = audioEngine else { return }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        logger.info("Audio engine started")
    }
    
    private func stopAudioEngine() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        
        logger.info("Audio engine stopped")
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard !isProcessing, !isDetected else { return }
        
        // Analyze audio energy
        let energy = calculateEnergy(buffer)
        
        // Check if there's significant audio activity
        if energy > energyThreshold {
            // Send to speech recognition
            recognitionRequest?.append(buffer)
            
            // Perform frequency analysis if needed
            if usePhonemeMatching {
                analyzeFrequencySpectrum(buffer)
            }
        }
        
        previousEnergy = energy
    }
    
    private func calculateEnergy(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        
        let channelDataPointer = channelData[0]
        let frameLength = Int(buffer.frameLength)
        
        var energy: Float = 0.0
        vDSP_measqv(channelDataPointer, 1, &energy, vDSP_Length(frameLength))
        
        return energy / Float(frameLength)
    }
    
    private func analyzeFrequencySpectrum(_ buffer: AVAudioPCMBuffer) {
        guard let fftSetup = fftSetup,
              let channelData = buffer.floatChannelData else { return }
        
        let channelDataPointer = channelData[0]
        let frameLength = min(Int(buffer.frameLength), fftSize)
        
        // Prepare FFT buffers
        var realPart = [Float](repeating: 0, count: fftSize/2)
        var imagPart = [Float](repeating: 0, count: fftSize/2)
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        
        // Copy audio data
        var windowedData = [Float](repeating: 0, count: fftSize)
        for i in 0..<frameLength {
            windowedData[i] = channelDataPointer[i]
        }
        
        // Apply window function
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(windowedData, 1, window, 1, &windowedData, 1, vDSP_Length(fftSize))
        
        // Convert to split complex format
        windowedData.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize/2))
            }
        }
        
        // Perform FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
        
        // Analyze spectrum for voice characteristics
        analyzeVoiceCharacteristics(magnitudes)
    }
    
    private func analyzeVoiceCharacteristics(_ magnitudes: [Float]) {
        // Voice fundamental frequency typically 85-255 Hz
        // Calculate frequency bins
        guard let audioFormat = audioFormat else { return }
        
        let sampleRate = Float(audioFormat.sampleRate)
        let binResolution = sampleRate / Float(fftSize)
        
        // Find fundamental frequency range bins
        let minVoiceBin = Int(85.0 / binResolution)
        let maxVoiceBin = Int(255.0 / binResolution)
        
        // Calculate energy in voice range
        var voiceEnergy: Float = 0.0
        for i in minVoiceBin...min(maxVoiceBin, magnitudes.count - 1) {
            voiceEnergy += magnitudes[i]
        }
        
        // Normalize and update confidence based on voice energy
        let normalizedVoiceEnergy = voiceEnergy / Float(maxVoiceBin - minVoiceBin)
        updateConfidence(baseConfidence: confidence, voiceEnergy: normalizedVoiceEnergy)
    }
    
    // MARK: - Speech Recognition
    
    private func startSpeechRecognition() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest,
              let speechRecognizer = speechRecognizer else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
    }
    
    private func stopSpeechRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            logger.error("Speech recognition error: \(error.localizedDescription)")
            
            // Restart recognition if it's a temporary error
            if (error as NSError).code == 203 { // Audio queue error
                Task { @MainActor in
                    self.restartListening()
                }
            }
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription.formattedString.lowercased()
        
        // Check for wake word in transcription
        checkForWakeWord(in: transcription, isFinal: result.isFinal)
        
        if result.isFinal && useContinuousListening && !isDetected {
            // Restart recognition for continuous listening
            Task { @MainActor in
                self.restartSpeechRecognition()
            }
        }
    }
    
    private func restartSpeechRecognition() {
        stopSpeechRecognition()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startSpeechRecognition()
        }
    }
    
    // MARK: - Wake Word Detection
    
    private func checkForWakeWord(in transcription: String, isFinal: Bool) {
        let startTime = Date()
        
        for variation in wakeWordVariations {
            if transcription.contains(variation) {
                let detectionConfidence = calculateConfidence(
                    transcription: transcription,
                    wakeWord: variation,
                    isFinal: isFinal
                )
                
                if detectionConfidence >= sensitivity {
                    handleWakeWordDetection(
                        detectedPhrase: variation,
                        confidence: detectionConfidence,
                        latency: Date().timeIntervalSince(startTime)
                    )
                    return
                }
            }
        }
        
        // Check phoneme patterns if no direct match
        if usePhonemeMatching && !phonemePatterns.isEmpty {
            checkPhonemePatterns(transcription, isFinal: isFinal)
        }
    }
    
    private func checkPhonemePatterns(_ transcription: String, isFinal: Bool) {
        // Simplified phoneme matching - in production, use proper phoneme analysis
        let transcriptionPhonemes = generateSimplePhonemes(transcription)
        
        for (index, pattern) in phonemePatterns.enumerated() {
            let similarity = calculatePhonemeSimilarity(transcriptionPhonemes, pattern)
            
            if similarity >= sensitivity {
                let detectedVariation = wakeWordVariations[min(index, wakeWordVariations.count - 1)]
                handleWakeWordDetection(
                    detectedPhrase: detectedVariation,
                    confidence: similarity,
                    latency: 0
                )
                return
            }
        }
    }
    
    private func generateSimplePhonemes(_ text: String) -> String {
        // Very simplified phoneme generation
        return text
            .replacingOccurrences(of: "ey", with: "EY")
            .replacingOccurrences(of: "ay", with: "AY")
            .replacingOccurrences(of: "oh", with: "OW")
            .uppercased()
    }
    
    private func calculatePhonemeSimilarity(_ phonemes1: String, _ phonemes2: String) -> Float {
        // Simple Levenshtein distance-based similarity
        let distance = levenshteinDistance(phonemes1, phonemes2)
        let maxLength = max(phonemes1.count, phonemes2.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        return 1.0 - (Float(distance) / Float(maxLength))
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)
        
        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Array.count][s2Array.count]
    }
    
    private func calculateConfidence(transcription: String, wakeWord: String, isFinal: Bool) -> Float {
        var confidence: Float = 0.0
        
        // Base confidence from exact match
        if transcription == wakeWord {
            confidence = 1.0
        } else if transcription.hasPrefix(wakeWord) {
            confidence = 0.9
        } else if transcription.contains(wakeWord) {
            confidence = 0.8
        }
        
        // Adjust for transcription length
        let lengthRatio = Float(wakeWord.count) / Float(transcription.count)
        confidence *= (0.5 + lengthRatio * 0.5)
        
        // Boost confidence for final results
        if isFinal {
            confidence *= 1.1
        }
        
        // Consider audio energy
        confidence *= (0.7 + min(previousEnergy * 3, 0.3))
        
        return min(confidence, 1.0)
    }
    
    private func updateConfidence(baseConfidence: Float, voiceEnergy: Float) {
        confidence = (baseConfidence * 0.7 + voiceEnergy * 0.3)
    }
    
    // MARK: - Detection Handling
    
    private func handleWakeWordDetection(detectedPhrase: String, confidence: Float, latency: TimeInterval) {
        guard !isDetected else { return }
        
        logger.info("Wake word detected: '\(detectedPhrase)' with confidence: \(confidence)")
        
        isDetected = true
        self.confidence = confidence
        lastDetectionTime = Date()
        detectionCount += 1
        detectionLatency = latency
        
        // Notify callback
        onWakeWordDetected?(detectedPhrase, confidence)
        
        // Start cooldown
        startCooldownTimer()
        
        // Stop listening if not continuous
        if !useContinuousListening {
            stopListening()
        }
    }
    
    // MARK: - Timer Management
    
    private func startDetectionTimer() {
        stopDetectionTimer()
        
        detectionTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleTimeout()
            }
        }
    }
    
    private func stopDetectionTimer() {
        detectionTimer?.invalidate()
        detectionTimer = nil
    }
    
    private func startCooldownTimer() {
        stopCooldownTimer()
        
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: cooldownInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.resetDetection()
            }
        }
    }
    
    private func stopCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }
    
    private func handleTimeout() {
        logger.info("Wake word detection timeout")
        
        onTimeout?()
        
        if useContinuousListening {
            restartListening()
        } else {
            stopListening()
        }
    }
    
    private func resetDetection() {
        isDetected = false
        confidence = 0.0
        
        if useContinuousListening && isListening {
            logger.info("Reset detection, continuing to listen")
        }
    }
    
    // MARK: - Performance Metrics
    
    func getPerformanceMetrics() -> WakeWordPerformanceMetrics {
        return WakeWordPerformanceMetrics(
            detectionCount: detectionCount,
            averageLatency: detectionLatency,
            falsePositiveRate: Float(falsePositiveCount) / Float(max(detectionCount, 1)),
            missedDetectionRate: Float(missedDetectionCount) / Float(max(detectionCount + missedDetectionCount, 1)),
            averageConfidence: confidence
        )
    }
    
    func reportFalsePositive() {
        falsePositiveCount += 1
        logger.info("False positive reported. Total: \(falsePositiveCount)")
    }
    
    func reportMissedDetection() {
        missedDetectionCount += 1
        logger.info("Missed detection reported. Total: \(missedDetectionCount)")
    }
}

// MARK: - Supporting Types

enum WakeWordError: LocalizedError {
    case microphonePermissionDenied
    case speechRecognitionNotAuthorized
    case audioEngineSetupFailed
    case audioInputNodeUnavailable
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required for wake word detection"
        case .speechRecognitionNotAuthorized:
            return "Speech recognition authorization is required"
        case .audioEngineSetupFailed:
            return "Failed to setup audio engine"
        case .audioInputNodeUnavailable:
            return "Audio input node is not available"
        }
    }
}

struct WakeWordPerformanceMetrics {
    let detectionCount: Int
    let averageLatency: TimeInterval
    let falsePositiveRate: Float
    let missedDetectionRate: Float
    let averageConfidence: Float
}

#endif