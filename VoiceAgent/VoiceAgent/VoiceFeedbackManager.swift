#if os(macOS)
import Foundation
import AVFoundation

class VoiceFeedbackManager: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isEnabled = true
    @Published var isSpeaking = false
    @Published var volume: Float = 0.8
    @Published var rate: Float = 0.5
    @Published var selectedVoice: String = ""
    
    private var availableVoices: [AVSpeechSynthesisVoice] = []
    
    override init() {
        super.init()
        setupSynthesizer()
        loadSettings()
    }
    
    private func setupSynthesizer() {
        synthesizer.delegate = self
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Set default voice (prefer system default or first English voice)
        if selectedVoice.isEmpty {
            if let defaultVoice = AVSpeechSynthesisVoice(language: "en-US") {
                selectedVoice = defaultVoice.identifier
            } else if let firstVoice = availableVoices.first {
                selectedVoice = firstVoice.identifier
            }
        }
    }
    
    func speak(_ text: String, priority: FeedbackPriority = .normal) {
        guard isEnabled, !text.isEmpty else { return }
        
        // Handle priority - interrupt if high priority
        if priority == .high && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        } else if priority == .low && synthesizer.isSpeaking {
            return // Don't speak if already speaking and low priority
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure utterance
        if let voice = AVSpeechSynthesisVoice(identifier: selectedVoice) {
            utterance.voice = voice
        }
        
        utterance.volume = volume
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        
        // Add slight pause for natural speech
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        synthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    func pauseSpeaking() {
        synthesizer.pauseSpeaking(at: .immediate)
    }
    
    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }
    
    func getAvailableVoices() -> [VoiceInfo] {
        return availableVoices.map { voice in
            VoiceInfo(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: voice.quality.rawValue
            )
        }.sorted { $0.name < $1.name }
    }
    
    func setVoice(_ voiceIdentifier: String) {
        selectedVoice = voiceIdentifier
        saveSettings()
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        saveSettings()
    }
    
    func setRate(_ newRate: Float) {
        rate = max(0.1, min(1.0, newRate))
        saveSettings()
    }
    
    func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled && synthesizer.isSpeaking {
            stopSpeaking()
        }
        saveSettings()
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: "voiceFeedbackEnabled")
        defaults.set(volume, forKey: "voiceFeedbackVolume")
        defaults.set(rate, forKey: "voiceFeedbackRate")
        defaults.set(selectedVoice, forKey: "voiceFeedbackVoice")
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: "voiceFeedbackEnabled") as? Bool ?? true
        volume = defaults.object(forKey: "voiceFeedbackVolume") as? Float ?? 0.8
        rate = defaults.object(forKey: "voiceFeedbackRate") as? Float ?? 0.5
        selectedVoice = defaults.string(forKey: "voiceFeedbackVoice") ?? ""
    }
}

extension VoiceFeedbackManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

enum FeedbackPriority {
    case low       // Background info, can be skipped
    case normal    // Standard feedback
    case high      // Important, interrupts current speech
}

struct VoiceInfo {
    let identifier: String
    let name: String
    let language: String
    let quality: Int
    
    var displayName: String {
        return "\(name) (\(language))"
    }
    
    var qualityDescription: String {
        switch quality {
        case 1: return "Default"
        case 2: return "Enhanced"
        case 3: return "Premium"
        default: return "Standard"
        }
    }
}

// MARK: - Predefined Feedback Messages
extension VoiceFeedbackManager {
    
    // System Status Messages
    func announceListeningStarted() {
        speak("Voice Agent is now listening", priority: .normal)
    }
    
    func announceListeningStopped() {
        speak("Voice listening stopped", priority: .normal)
    }
    
    func announceCommandReceived(_ command: String) {
        let shortCommand = String(command.prefix(50))
        speak("Executing: \(shortCommand)", priority: .normal)
    }
    
    func announceCommandCompleted(_ result: String) {
        speak(result, priority: .normal)
    }
    
    func announceError(_ error: String) {
        speak("Error: \(error)", priority: .high)
    }
    
    // Action Confirmations
    func confirmClick(at point: CGPoint) {
        speak("Clicked at \(Int(point.x)), \(Int(point.y))", priority: .low)
    }
    
    func confirmTyping(_ text: String) {
        let shortText = String(text.prefix(30))
        speak("Typed: \(shortText)", priority: .low)
    }
    
    func confirmKeyPress(_ key: String) {
        speak("Pressed \(key)", priority: .low)
    }
    
    func confirmScroll(_ direction: String) {
        speak("Scrolled \(direction)", priority: .low)
    }
    
    func confirmAppLaunch(_ appName: String) {
        speak("Opened \(appName)", priority: .normal)
    }
    
    // AI Provider Messages
    func announceAIProviderChanged(_ providerName: String) {
        speak("Switched to \(providerName)", priority: .normal)
    }
    
    func announceAIThinking() {
        speak("Thinking...", priority: .low)
    }
    
    // Screen Monitoring Messages
    func announceScreenMonitoringStarted() {
        speak("Screen monitoring enabled", priority: .normal)
    }
    
    func announceScreenMonitoringStopped() {
        speak("Screen monitoring disabled", priority: .normal)
    }
}#endif
