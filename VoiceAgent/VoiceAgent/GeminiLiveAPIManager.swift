#if os(macOS)
//
//  GeminiLiveAPIManager.swift
//  VoiceAgent
//
//  Manages Gemini Live API WebSocket connections for real-time audio and visual interaction
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import Network
import os.log

@MainActor
class GeminiLiveAPIManager: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent.gemini", category: "LiveAPI")
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var connectionStatus = "Disconnected"
    @Published var lastError: String?
    @Published var sessionActive = false
    
    // MARK: - Configuration
    private var apiKey: String?
    private var model = "models/gemini-2.5-flash-preview-native-audio-dialog"
    private var voiceName = "Zephyr"
    
    // MARK: - WebSocket and Networking
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    // MARK: - Audio Management
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioPlayer: AVAudioPlayer?
    private var audioFormat: AVAudioFormat?
    
    // Audio Configuration
    private let sampleRate: Double = 16000
    private let channels: AVAudioChannelCount = 1
    private let outputSampleRate: Double = 24000
    private let bufferSize: AVAudioFrameCount = 1024
    
    // MARK: - Screen Capture
    private var screenCaptureTimer: Timer?
    private var isCapturingScreen = false
    
    // MARK: - Session Management
    private var sessionId: String?
    private var isSessionSetup = false
    
    // MARK: - Initialization
    init() {
        setupAudioSession()
        setupURLSession()
    }
    
    deinit {
        stopLiveSession()
    }
    
    // MARK: - Configuration
    func configure(apiKey: String, model: String? = nil, voiceName: String? = nil) {
        self.apiKey = apiKey
        if let model = model {
            self.model = model
        }
        if let voiceName = voiceName {
            self.voiceName = voiceName
        }
    }
    
    // MARK: - Session Management
    func startLiveSession() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw GeminiLiveAPIError.invalidAPIKey
        }
        
        guard !sessionActive else {
            logger.info("Live session already active")
            return
        }
        
        do {
            try await establishWebSocketConnection()
            try await setupAudioEngine()
            try await sendInitialConfiguration()
            
            await MainActor.run {
                self.sessionActive = true
                self.isConnected = true
                self.connectionStatus = "Connected"
                self.lastError = nil
            }
            
            // Start concurrent tasks
            Task { await self.listenForWebSocketMessages() }
            Task { await self.startAudioCapture() }
            Task { await self.startScreenCapture() }
            
            logger.info("Gemini Live API session started successfully")
            
        } catch {
            logger.error("Failed to start live session: \(error.localizedDescription)")
            await MainActor.run {
                self.lastError = error.localizedDescription
                self.connectionStatus = "Failed to Connect"
            }
            throw error
        }
    }
    
    func stopLiveSession() {
        Task { @MainActor in
            sessionActive = false
            isConnected = false
            isListening = false
            isSpeaking = false
            connectionStatus = "Disconnected"
            isSessionSetup = false
            sessionId = nil
            
            // Stop audio engine
            audioEngine?.stop()
            audioEngine = nil
            
            // Stop screen capture
            screenCaptureTimer?.invalidate()
            screenCaptureTimer = nil
            isCapturingScreen = false
            
            // Close WebSocket
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
            
            logger.info("Gemini Live API session stopped")
        }
    }
    
    // MARK: - WebSocket Connection
    private func establishWebSocketConnection() async throws {
        guard let apiKey = apiKey else {
            throw GeminiLiveAPIError.invalidAPIKey
        }
        
        // Gemini Live API WebSocket URL
        let baseURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.StreamGenerateContent"
        let urlString = "\(baseURL)?key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw GeminiLiveAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        logger.info("WebSocket connection established to Gemini Live API")
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        urlSession = URLSession(configuration: config)
    }
    
    // MARK: - Audio Setup
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            logger.info("Audio session configured successfully")
        } catch {
            logger.error("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioEngine() async throws {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            throw GeminiLiveAPIError.audioSetupFailed
        }
        
        inputNode = audioEngine.inputNode
        
        // Configure audio format for Gemini (16kHz, mono, PCM)
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        )
        
        guard let audioFormat = audioFormat else {
            throw GeminiLiveAPIError.audioFormatUnsupported
        }
        
        // Install tap on input node to capture audio
        inputNode?.installTap(onBus: 0, bufferSize: bufferSize, format: audioFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                await self?.sendAudioData(buffer: buffer)
            }
        }
        
        try audioEngine.start()
        
        await MainActor.run {
            self.isListening = true
        }
        
        logger.info("Audio engine started successfully")
    }
    
    // MARK: - Initial Configuration
    private func sendInitialConfiguration() async throws {
        let config = GeminiLiveConfig(
            responseModalities: ["AUDIO"],
            mediaResolution: "MEDIA_RESOLUTION_MEDIUM",
            speechConfig: GeminiSpeechConfig(
                voiceConfig: GeminiVoiceConfig(
                    prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(voiceName: voiceName)
                )
            ),
            contextWindowCompression: GeminiContextWindowCompression(
                triggerTokens: 25600,
                slidingWindow: GeminiSlidingWindow(targetTokens: 12800)
            )
        )
        
        let setupMessage = GeminiLiveMessage(
            setupConfig: config
        )
        
        try await sendWebSocketMessage(setupMessage)
        isSessionSetup = true
        
        logger.info("Initial configuration sent to Gemini Live API")
    }
    
    // MARK: - Audio Streaming
    private func startAudioCapture() async {
        // Audio capture is handled by the tap we installed on the input node
        logger.info("Audio capture started")
    }
    
    private func sendAudioData(buffer: AVAudioPCMBuffer) async {
        guard sessionActive, isSessionSetup else { return }
        
        guard let channelData = buffer.int16ChannelData?[0] else { return }
        
        let frameCount = Int(buffer.frameLength)
        let audioData = Data(bytes: channelData, count: frameCount * MemoryLayout<Int16>.size)
        
        let audioMessage = GeminiLiveMessage(
            realtimeInput: GeminiRealtimeInput(
                mediaChunks: [
                    GeminiMediaChunk(
                        mimeType: "audio/pcm",
                        data: audioData.base64EncodedString()
                    )
                ]
            )
        )
        
        do {
            try await sendWebSocketMessage(audioMessage)
        } catch {
            logger.error("Failed to send audio data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Screen Capture
    private func startScreenCapture() async {
        guard !isCapturingScreen else { return }
        
        isCapturingScreen = true
        
        await MainActor.run {
            self.screenCaptureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    await self?.captureAndSendScreen()
                }
            }
        }
        
        logger.info("Screen capture started")
    }
    
    private func captureAndSendScreen() async {
        guard sessionActive, isSessionSetup else { return }
        
        do {
            let displays = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true).displays
            
            guard let display = displays.first else { return }
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 1024
            configuration.height = 768
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            
            // Convert CGImage to JPEG data
            let imageData = try await convertImageToJPEGData(image)
            
            let screenMessage = GeminiLiveMessage(
                realtimeInput: GeminiRealtimeInput(
                    mediaChunks: [
                        GeminiMediaChunk(
                            mimeType: "image/jpeg",
                            data: imageData.base64EncodedString()
                        )
                    ]
                )
            )
            
            try await sendWebSocketMessage(screenMessage)
            
        } catch {
            logger.error("Failed to capture and send screen: \(error.localizedDescription)")
        }
    }
    
    private func convertImageToJPEGData(_ cgImage: CGImage) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let mutableData = CFDataCreateMutable(nil, 0),
                      let destination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) else {
                    continuation.resume(throwing: GeminiLiveAPIError.imageConversionFailed)
                    return
                }
                
                CGImageDestinationAddImage(destination, cgImage, nil)
                
                if CGImageDestinationFinalize(destination) {
                    continuation.resume(returning: mutableData as Data)
                } else {
                    continuation.resume(throwing: GeminiLiveAPIError.imageConversionFailed)
                }
            }
        }
    }
    
    // MARK: - WebSocket Communication
    private func sendWebSocketMessage(_ message: GeminiLiveMessage) async throws {
        guard let webSocketTask = webSocketTask else {
            throw GeminiLiveAPIError.webSocketNotConnected
        }
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(message)
        
        let webSocketMessage = URLSessionWebSocketTask.Message.data(jsonData)
        try await webSocketTask.send(webSocketMessage)
    }
    
    private func listenForWebSocketMessages() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            while sessionActive {
                let message = try await webSocketTask.receive()
                await handleWebSocketMessage(message)
            }
        } catch {
            logger.error("WebSocket listening error: \(error.localizedDescription)")
            await MainActor.run {
                self.lastError = "Connection lost: \(error.localizedDescription)"
                self.connectionStatus = "Disconnected"
                self.isConnected = false
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .data(let data):
            await processAudioResponse(data)
        case .string(let text):
            await processTextResponse(text)
        @unknown default:
            logger.warning("Received unknown WebSocket message type")
        }
    }
    
    private func processAudioResponse(_ data: Data) async {
        do {
            let response = try JSONDecoder().decode(GeminiLiveResponse.self, from: data)
            
            if let audioData = response.candidates?.first?.content?.parts?.first?.inlineData?.data {
                await playAudioResponse(audioData)
            }
            
            if let text = response.candidates?.first?.content?.parts?.first?.text {
                logger.info("Received text response: \(text)")
            }
            
        } catch {
            logger.error("Failed to process audio response: \(error.localizedDescription)")
        }
    }
    
    private func processTextResponse(_ text: String) async {
        logger.info("Received text message: \(text)")
        // Handle text-based responses from Gemini
    }
    
    private func playAudioResponse(_ base64AudioData: String) async {
        guard let audioData = Data(base64Encoded: base64AudioData) else {
            logger.error("Failed to decode base64 audio data")
            return
        }
        
        do {
            await MainActor.run {
                self.isSpeaking = true
            }
            
            let audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer.play()
            
            // Wait for audio to finish playing
            while audioPlayer.isPlaying {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            
            await MainActor.run {
                self.isSpeaking = false
            }
            
        } catch {
            logger.error("Failed to play audio response: \(error.localizedDescription)")
            await MainActor.run {
                self.isSpeaking = false
            }
        }
    }
    
    // MARK: - Public Methods
    func sendTextMessage(_ text: String) async throws {
        let textMessage = GeminiLiveMessage(
            realtimeInput: GeminiRealtimeInput(
                text: text
            )
        )
        
        try await sendWebSocketMessage(textMessage)
    }
    
    func updateVoice(_ voiceName: String) async throws {
        self.voiceName = voiceName
        
        if sessionActive {
            // Send voice configuration update
            let voiceUpdate = GeminiLiveMessage(
                updateConfig: GeminiUpdateConfig(
                    speechConfig: GeminiSpeechConfig(
                        voiceConfig: GeminiVoiceConfig(
                            prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig(voiceName: voiceName)
                        )
                    )
                )
            )
            
            try await sendWebSocketMessage(voiceUpdate)
        }
    }
}

// MARK: - Data Models
struct GeminiLiveConfig: Codable {
    let responseModalities: [String]
    let mediaResolution: String
    let speechConfig: GeminiSpeechConfig
    let contextWindowCompression: GeminiContextWindowCompression
    
    enum CodingKeys: String, CodingKey {
        case responseModalities = "response_modalities"
        case mediaResolution = "media_resolution"
        case speechConfig = "speech_config"
        case contextWindowCompression = "context_window_compression"
    }
}

struct GeminiSpeechConfig: Codable {
    let voiceConfig: GeminiVoiceConfig
    
    enum CodingKeys: String, CodingKey {
        case voiceConfig = "voice_config"
    }
}

struct GeminiVoiceConfig: Codable {
    let prebuiltVoiceConfig: GeminiPrebuiltVoiceConfig
    
    enum CodingKeys: String, CodingKey {
        case prebuiltVoiceConfig = "prebuilt_voice_config"
    }
}

struct GeminiPrebuiltVoiceConfig: Codable {
    let voiceName: String
    
    enum CodingKeys: String, CodingKey {
        case voiceName = "voice_name"
    }
}

struct GeminiContextWindowCompression: Codable {
    let triggerTokens: Int
    let slidingWindow: GeminiSlidingWindow
    
    enum CodingKeys: String, CodingKey {
        case triggerTokens = "trigger_tokens"
        case slidingWindow = "sliding_window"
    }
}

struct GeminiSlidingWindow: Codable {
    let targetTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case targetTokens = "target_tokens"
    }
}

struct GeminiLiveMessage: Codable {
    let setupConfig: GeminiLiveConfig?
    let realtimeInput: GeminiRealtimeInput?
    let updateConfig: GeminiUpdateConfig?
    
    enum CodingKeys: String, CodingKey {
        case setupConfig = "setup"
        case realtimeInput = "realtime_input"
        case updateConfig = "update"
    }
    
    init(setupConfig: GeminiLiveConfig) {
        self.setupConfig = setupConfig
        self.realtimeInput = nil
        self.updateConfig = nil
    }
    
    init(realtimeInput: GeminiRealtimeInput) {
        self.setupConfig = nil
        self.realtimeInput = realtimeInput
        self.updateConfig = nil
    }
    
    init(updateConfig: GeminiUpdateConfig) {
        self.setupConfig = nil
        self.realtimeInput = nil
        self.updateConfig = updateConfig
    }
}

struct GeminiRealtimeInput: Codable {
    let mediaChunks: [GeminiMediaChunk]?
    let text: String?
    
    enum CodingKeys: String, CodingKey {
        case mediaChunks = "media_chunks"
        case text
    }
    
    init(mediaChunks: [GeminiMediaChunk]) {
        self.mediaChunks = mediaChunks
        self.text = nil
    }
    
    init(text: String) {
        self.mediaChunks = nil
        self.text = text
    }
}

struct GeminiMediaChunk: Codable {
    let mimeType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

struct GeminiUpdateConfig: Codable {
    let speechConfig: GeminiSpeechConfig?
    
    enum CodingKeys: String, CodingKey {
        case speechConfig = "speech_config"
    }
}

struct GeminiLiveResponse: Codable {
    let candidates: [GeminiCandidate]?
    let turnComplete: Bool?
    
    enum CodingKeys: String, CodingKey {
        case candidates
        case turnComplete = "turn_complete"
    }
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

struct GeminiPart: Codable {
    let text: String?
    let inlineData: GeminiInlineData?
    
    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
    }
}

struct GeminiInlineData: Codable {
    let mimeType: String
    let data: String
    
    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

// MARK: - Error Types
enum GeminiLiveAPIError: Error, LocalizedError {
    case invalidAPIKey
    case invalidURL
    case webSocketNotConnected
    case audioSetupFailed
    case audioFormatUnsupported
    case imageConversionFailed
    case networkError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing Gemini API key"
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .webSocketNotConnected:
            return "WebSocket connection not established"
        case .audioSetupFailed:
            return "Failed to setup audio engine"
        case .audioFormatUnsupported:
            return "Audio format not supported"
        case .imageConversionFailed:
            return "Failed to convert image to JPEG"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}#endif
