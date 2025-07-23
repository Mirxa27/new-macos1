#if os(macOS)
import Foundation
import Speech
import AVFoundation

class AudioManager: NSObject, ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()

    private(set) var languageCode: String = "en-US"
    
    var onSpeechRecognized: ((String) -> Void)?
    var onStatusChanged: ((String) -> Void)?
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }

    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
        speechRecognizer?.delegate = self
    }

    func updateLanguage(_ code: String) {
        languageCode = code
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: code))
        speechRecognizer?.delegate = self
    }
    
    func startListening() async throws {
        // Cancel any previous recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Request authorization
        let authStatus = await requestSpeechAuthorization()
        guard authStatus == .authorized else {
            throw AudioManagerError.speechNotAuthorized
        }
        
        // Request microphone permission
        let microphonePermission = await requestMicrophonePermission()
        guard microphonePermission else {
            throw AudioManagerError.microphoneNotAuthorized
        }
        
        // Setup audio session
        try setupAudioSession()
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AudioManagerError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        guard let speechRecognizer = speechRecognizer else {
            throw AudioManagerError.speechRecognizerNotAvailable
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                
                if result.isFinal {
                    isFinal = true
                    DispatchQueue.main.async {
                        self?.onSpeechRecognized?(transcription)
                    }
                }
            }
            
            if error != nil || isFinal {
                self?.audioEngine.stop()
                self?.audioEngine.inputNode.removeTap(onBus: 0)
                self?.recognitionRequest = nil
                self?.recognitionTask = nil
                
                if let error = error {
                    DispatchQueue.main.async {
                        self?.onStatusChanged?("Speech recognition error: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        onStatusChanged?("Listening...")
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        onStatusChanged?("Stopped listening")
    }
    
    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
}

extension AudioManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if available {
                self.onStatusChanged?("Speech recognizer available")
            } else {
                self.onStatusChanged?("Speech recognizer not available")
            }
        }
    }
}

enum AudioManagerError: Error, LocalizedError {
    case speechNotAuthorized
    case microphoneNotAuthorized
    case unableToCreateRequest
    case speechRecognizerNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .speechNotAuthorized:
            return "Speech recognition not authorized"
        case .microphoneNotAuthorized:
            return "Microphone access not authorized"
        case .unableToCreateRequest:
            return "Unable to create speech recognition request"
        case .speechRecognizerNotAvailable:
            return "Speech recognizer not available"
        }
    }
}
#endif
