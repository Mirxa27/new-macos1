#if os(macOS)
import Foundation
import SwiftUI
import Speech

struct VoiceCommand {
    let id = UUID()
    let text: String
    let timestamp: Date
    var executed: Bool = false
    var result: String?
}

@MainActor
class VoiceAgent: ObservableObject {
    @Published var isListening = false
    @Published var isScreenMonitoring = false
    @Published var statusMessage = "Ready to listen"
    @Published var commandCount = 0
    @Published var recentCommands: [VoiceCommand] = []
    
    // Live API Properties
    @Published var isLiveAPIActive = false
    @Published var liveAPIConnectionStatus = "Disconnected"
    @Published var isLiveAPIListening = false
    @Published var isLiveAPISpeaking = false

    // Speech settings
    @Published var speechLanguage: String = UserDefaults.standard.string(forKey: "speechLanguage") ?? "en-US"
    @Published var wakeWordEnabled: Bool = UserDefaults.standard.object(forKey: "wakeWordEnabled") as? Bool ?? false
    @Published var wakeWord: String = UserDefaults.standard.string(forKey: "wakeWord") ?? "Hey Assistant"
    
    let audioManager = AudioManager()
    let screenManager = ScreenManager()
    let aiProviderManager = AIProviderManager()
    let systemController = SystemController()
    let voiceFeedbackManager = VoiceFeedbackManager()
    let visionManager: VisionManager
    let permissionManager = PermissionManager()
    
    private var commandProcessingTask: Task<Void, Never>?
    
    init() {
        visionManager = VisionManager(aiProviderManager: aiProviderManager)
        setupAudioManager()
        setupScreenManager()
        setupVisionManager()
        audioManager.updateLanguage(speechLanguage)
        permissionManager.refreshStatuses()

        if wakeWordEnabled {
            Task {
                try? await audioManager.startListening()
                isListening = true
                statusMessage = "Listening for wake word..."
            }
        }
    }
    
    private func setupAudioManager() {
        audioManager.onSpeechRecognized = { [weak self] text in
            Task { @MainActor in
                self?.processSpeechCommand(text)
            }
        }
        
        audioManager.onStatusChanged = { [weak self] status in
            Task { @MainActor in
                self?.statusMessage = status
            }
        }
    }
    
    private func setupScreenManager() {
        screenManager.onScreenChanged = { [weak self] description in
            Task { @MainActor in
                self?.processScreenContext(description)
            }
        }
    }
    
    private func setupVisionManager() {
        // Vision manager will work automatically with screen captures
    }
    
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    func startListening() {
        Task {
            do {
                try await audioManager.startListening()
                isListening = true
                statusMessage = "Listening for commands..."
                voiceFeedbackManager.announceListeningStarted()
            } catch {
                statusMessage = "Failed to start listening: \(error.localizedDescription)"
                voiceFeedbackManager.announceError(error.localizedDescription)
            }
        }
    }
    
    func stopListening() {
        audioManager.stopListening()
        isListening = false
        statusMessage = "Stopped listening"
        voiceFeedbackManager.announceListeningStopped()
    }
    
    func toggleScreenMonitoring() {
        if isScreenMonitoring {
            stopScreenMonitoring()
        } else {
            startScreenMonitoring()
        }
    }
    
    func startScreenMonitoring() {
        Task {
            do {
                try await screenManager.startMonitoring()
                isScreenMonitoring = true
                statusMessage = "Monitoring screen..."
                voiceFeedbackManager.announceScreenMonitoringStarted()
            } catch {
                statusMessage = "Failed to start screen monitoring: \(error.localizedDescription)"
                voiceFeedbackManager.announceError(error.localizedDescription)
            }
        }
    }
    
    func stopScreenMonitoring() {
        screenManager.stopMonitoring()
        isScreenMonitoring = false
        statusMessage = "Stopped screen monitoring"
        voiceFeedbackManager.announceScreenMonitoringStopped()
    }
    
    private func processSpeechCommand(_ text: String) {
        var processedText = text
        if wakeWordEnabled {
            let lower = text.lowercased()
            let trigger = wakeWord.lowercased()
            guard lower.hasPrefix(trigger) else { return }
            processedText = String(text.dropFirst(trigger.count)).trimmingCharacters(in: .whitespaces)
        }

        let command = VoiceCommand(text: processedText, timestamp: Date())
        recentCommands.insert(command, at: 0)
        commandCount += 1
        
        if recentCommands.count > 10 {
            recentCommands.removeLast()
        }
        
        statusMessage = "Processing: \(processedText)"
        voiceFeedbackManager.announceCommandReceived(processedText)
        
        commandProcessingTask?.cancel()
        commandProcessingTask = Task {
            await executeCommand(command)
        }
    }
    
    private func executeCommand(_ command: VoiceCommand) async {
        do {
            guard let provider = aiProviderManager.currentProvider else {
                let errorMsg = "No AI provider configured"
                updateCommandResult(command, result: errorMsg)
                voiceFeedbackManager.announceError(errorMsg)
                return
            }
            
            voiceFeedbackManager.announceAIThinking()
            
            // Get current screen screenshot for vision analysis
            let currentScreenshot = await screenManager.takeScreenshot()
            var response: String
            
            // Use vision if available and enabled
            if let screenshot = currentScreenshot,
               provider.supportsVision,
               aiProviderManager.useVisionWhenAvailable,
               visionManager.isVisionEnabled {
                
                // Perform vision analysis
                if let analysis = await visionManager.analyzeScreen(image: screenshot, useAI: true) {
                    voiceFeedbackManager.speak("Analyzing screen visually", priority: .low)
                    
                    // Get enhanced context from vision analysis
                    let visionContext = visionManager.generateContextualDescription(for: command.text)

                    response = try await aiProviderManager.processCommandWithVision(command.text, screenContext: visionContext, image: screenshot)
                    
                    // Provide detailed voice feedback about what was seen
                    if !analysis.aiDescription.isEmpty {
                        voiceFeedbackManager.speak("I can see: \(analysis.aiDescription.prefix(100))", priority: .low)
                    }
                } else {
                    // Fallback to regular processing
                    let screenContext = await screenManager.getCurrentScreenDescription()
                    response = try await provider.processCommand(command.text, screenContext: screenContext)
                }
            } else {
                // Regular processing without vision
                let screenContext = await screenManager.getCurrentScreenDescription()
                response = try await provider.processCommand(command.text, screenContext: screenContext)
            }
            
            if let action = parseActionFromResponse(response) {
                let result = try await systemController.executeAction(action)
                updateCommandResult(command, result: result, executed: true)
                voiceFeedbackManager.announceCommandCompleted(result)
                
                // Provide specific feedback based on action type
                await provideActionFeedback(action)
            } else {
                updateCommandResult(command, result: response)
                voiceFeedbackManager.announceCommandCompleted(response)
            }
            
            await MainActor.run {
                statusMessage = "Command completed"
            }
            
        } catch {
            let errorMsg = "Error: \(error.localizedDescription)"
            updateCommandResult(command, result: errorMsg)
            voiceFeedbackManager.announceError(error.localizedDescription)
            await MainActor.run {
                statusMessage = "Command failed"
            }
        }
    }
    
    private func updateCommandResult(_ command: VoiceCommand, result: String, executed: Bool = false) {
        Task { @MainActor in
            if let index = recentCommands.firstIndex(where: { $0.id == command.id }) {
                var updatedCommand = recentCommands[index]
                updatedCommand.result = result
                updatedCommand.executed = executed
                recentCommands[index] = updatedCommand
            }
        }
    }
    
    private func parseActionFromResponse(_ response: String) -> SystemAction? {
        let lowercased = response.lowercased()
        
        if lowercased.contains("click") {
            if let coordinates = extractCoordinates(from: response) {
                return .click(x: coordinates.x, y: coordinates.y)
            }
        } else if lowercased.contains("type") {
            if let text = extractTextToType(from: response) {
                return .type(text: text)
            }
        } else if lowercased.contains("key") || lowercased.contains("press") {
            if let key = extractKey(from: response) {
                return .keyPress(key: key)
            }
        } else if lowercased.contains("scroll") {
            if let direction = extractScrollDirection(from: response) {
                return .scroll(direction: direction)
            }
        } else if lowercased.contains("open") || lowercased.contains("launch") {
            if let app = extractAppName(from: response) {
                return .openApp(name: app)
            }
        }
        
        return nil
    }
    
    private func extractCoordinates(from text: String) -> (x: Int, y: Int)? {
        let pattern = #"(\d+),\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let xRange = Range(match.range(at: 1), in: text)!
        let yRange = Range(match.range(at: 2), in: text)!
        
        guard let x = Int(text[xRange]), let y = Int(text[yRange]) else {
            return nil
        }
        
        return (x: x, y: y)
    }
    
    private func extractTextToType(from text: String) -> String? {
        let patterns = [
            #"type[:\s]+"([^"]+)""#,
            #"type[:\s]+(.+)"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }
            
            let range = Range(match.range(at: 1), in: text)!
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func extractKey(from text: String) -> String? {
        let commonKeys = ["enter", "return", "space", "tab", "escape", "delete", "backspace", 
                         "up", "down", "left", "right", "command", "option", "shift", "control"]
        
        let lowercased = text.lowercased()
        for key in commonKeys {
            if lowercased.contains(key) {
                return key
            }
        }
        
        return nil
    }
    
    private func extractScrollDirection(from text: String) -> String? {
        let lowercased = text.lowercased()
        if lowercased.contains("up") { return "up" }
        if lowercased.contains("down") { return "down" }
        if lowercased.contains("left") { return "left" }
        if lowercased.contains("right") { return "right" }
        return nil
    }
    
    private func extractAppName(from text: String) -> String? {
        let patterns = [
            #"open[:\s]+"([^"]+)""#,
            #"launch[:\s]+"([^"]+)""#,
            #"open[:\s]+(.+)"#,
            #"launch[:\s]+(.+)"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }
            
            let range = Range(match.range(at: 1), in: text)!
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    private func processScreenContext(_ description: String) {
        // This could be used to provide additional context to the AI
        // For now, we'll just update the status
        statusMessage = "Screen context updated"
    }
    
    private func provideActionFeedback(_ action: SystemAction) async {
        switch action {
        case .click(let x, let y):
            voiceFeedbackManager.confirmClick(at: CGPoint(x: x, y: y))
        case .type(let text):
            voiceFeedbackManager.confirmTyping(text)
        case .keyPress(let key):
            voiceFeedbackManager.confirmKeyPress(key)
        case .scroll(let direction):
            voiceFeedbackManager.confirmScroll(direction)
        case .openApp(let name):
            voiceFeedbackManager.confirmAppLaunch(name)
        }
    }
    
    // Voice feedback controls
    func toggleVoiceFeedback() {
        voiceFeedbackManager.toggleEnabled()
    }
    
    func stopVoiceFeedback() {
        voiceFeedbackManager.stopSpeaking()
    }

    func updateSpeechLanguage(_ code: String) {
        speechLanguage = code
        audioManager.updateLanguage(code)
        UserDefaults.standard.set(code, forKey: "speechLanguage")
    }

    func updateWakeWord(_ word: String) {
        wakeWord = word
        UserDefaults.standard.set(word, forKey: "wakeWord")
    }

    func toggleWakeWordEnabled() {
        wakeWordEnabled.toggle()
        UserDefaults.standard.set(wakeWordEnabled, forKey: "wakeWordEnabled")
    }
    
    // Vision controls
    func toggleVisionAnalysis() {
        visionManager.toggleVisionAnalysis()
    }
    
    func describeCurrentScreen() {
        Task {
            if let screenshot = await screenManager.takeScreenshot() {
                if let analysis = await visionManager.analyzeScreen(image: screenshot, useAI: true) {
                    let description = visionManager.generateDetailedDescription()
                    voiceFeedbackManager.speak(description, priority: .normal)
                } else {
                    voiceFeedbackManager.speak("Unable to analyze current screen", priority: .normal)
                }
            } else {
                voiceFeedbackManager.speak("Unable to capture current screen", priority: .normal)
            }
        }
    }
    
    func readScreenText() {
        Task {
            if let screenshot = await screenManager.takeScreenshot() {
                if let analysis = await visionManager.analyzeScreen(image: screenshot, useAI: false) {
                    if !analysis.detectedText.isEmpty {
                        let textContent = analysis.detectedText.prefix(10).joined(separator: ", ")
                        voiceFeedbackManager.speak("Screen text includes: \(textContent)", priority: .normal)
                    } else {
                        voiceFeedbackManager.speak("No text detected on current screen", priority: .normal)
                    }
                } else {
                    voiceFeedbackManager.speak("Unable to read screen text", priority: .normal)
                }
            }
        }
    }    
    // MARK: - Live API Controls
    func toggleLiveAPI() {
        if isLiveAPIActive {
            stopLiveAPI()
        } else {
            startLiveAPI()
        }
    }
    
    func startLiveAPI() {
        Task {
            do {
                guard let provider = aiProviderManager.currentProvider else {
                    let errorMsg = "No AI provider configured"
                    liveAPIConnectionStatus = "Error: " + errorMsg
                    voiceFeedbackManager.announceError(errorMsg)
                    return
                }
                
                guard provider.supportsLiveAPI else {
                    let errorMsg = "Current provider does not support Live API"
                    liveAPIConnectionStatus = "Error: " + errorMsg
                    voiceFeedbackManager.announceError(errorMsg)
                    return
                }
                
                liveAPIConnectionStatus = "Connecting..."
                voiceFeedbackManager.speak("Starting Live API session", priority: .high)
                
                try await provider.startLiveSession()
                
                await MainActor.run {
                    self.isLiveAPIActive = true
                    self.liveAPIConnectionStatus = "Connected"
                    
                    // Monitor Live API status if it's a Gemini provider
                    if let geminiProvider = provider as? GeminiProvider {
                        self.isLiveAPIListening = geminiProvider.liveAPIListening
                        self.isLiveAPISpeaking = geminiProvider.liveAPISpeaking
                        
                        // Start monitoring Live API status
                        self.startMonitoringLiveAPI(geminiProvider)
                    }
                }
                
                voiceFeedbackManager.speak("Live API session active", priority: .high)
                
                // Disable regular listening when Live API is active
                if isListening {
                    stopListening()
                }
                
            } catch {
                await MainActor.run {
                    self.liveAPIConnectionStatus = "Failed: " + error.localizedDescription
                }
                voiceFeedbackManager.announceError("Failed to start Live API: " + error.localizedDescription)
            }
        }
    }
    
    func stopLiveAPI() {
        Task {
            if let provider = aiProviderManager.currentProvider {
                await provider.stopLiveSession()
            }
            
            await MainActor.run {
                self.isLiveAPIActive = false
                self.liveAPIConnectionStatus = "Disconnected"
                self.isLiveAPIListening = false
                self.isLiveAPISpeaking = false
            }
            
            voiceFeedbackManager.speak("Live API session ended", priority: .high)
        }
    }
    
    private func startMonitoringLiveAPI(_ geminiProvider: GeminiProvider) {
        Task {
            while isLiveAPIActive {
                await MainActor.run {
                    self.isLiveAPIListening = geminiProvider.liveAPIListening
                    self.isLiveAPISpeaking = geminiProvider.liveAPISpeaking
                    
                    if geminiProvider.liveAPIConnected {
                        self.liveAPIConnectionStatus = "Connected"
                    } else {
                        self.liveAPIConnectionStatus = "Disconnected"
                        self.isLiveAPIActive = false
                    }
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    func sendLiveTextMessage(_ text: String) {
        Task {
            do {
                guard let provider = aiProviderManager.currentProvider,
                      provider.supportsLiveAPI,
                      isLiveAPIActive else {
                    voiceFeedbackManager.announceError("Live API not active")
                    return
                }
                
                if let geminiProvider = provider as? GeminiProvider {
                    try await geminiProvider.sendLiveTextMessage(text)
                    voiceFeedbackManager.speak("Message sent to Live API", priority: .low)
                }
                
            } catch {
                voiceFeedbackManager.announceError("Failed to send message: " + error.localizedDescription)
            }
        }
    }
}
#endif
