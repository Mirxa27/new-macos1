#if os(macOS)
import SwiftUI

struct ConfigurationView: View {
    @EnvironmentObject var voiceAgent: VoiceAgent
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProviderIndex = 0
    @State private var selectedModelIndex = 0
    @State private var selectedVisionModelIndex = 0
    @State private var apiKey = ""
    @State private var customBaseURL = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedVoiceIndex = 0
    @State private var availableVoices: [VoiceInfo] = []
    @State private var wakeWord = ""
    @State private var selectedLanguageIndex = 0
    @State private var systemPromptText = ""
    @State private var visionPromptText = ""
    private let languageOptions: [(name: String, code: String)] = [
        ("English (US)", "en-US"),
        ("English (UK)", "en-GB"),
        ("Spanish", "es-ES"),
        ("French", "fr-FR")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Form {
                    Section(header: Text("AI Provider Configuration")) {
                        // Provider Selection
                        Picker("Provider", selection: $selectedProviderIndex) {
                            ForEach(0..<voiceAgent.aiProviderManager.providers.count, id: \.self) { index in
                                Text(voiceAgent.aiProviderManager.providers[index].name)
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedProviderIndex) { _, newValue in
                            updateModelSelection()
                        }
                        
                        // Model Selection
                        if !currentProvider.models.isEmpty {
                            Picker("Model", selection: $selectedModelIndex) {
                                ForEach(0..<currentProvider.models.count, id: \.self) { index in
                                    Text(currentProvider.models[index])
                                        .tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Vision Model Selection (if provider supports vision)
                        if currentProvider.supportsVision && !currentProvider.visionModels.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Vision Models")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Vision Model", selection: $selectedVisionModelIndex) {
                                    ForEach(0..<currentProvider.visionModels.count, id: \.self) { index in
                                        Text(currentProvider.visionModels[index])
                                            .tag(index)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        // API Key / Configuration
                        if currentProvider.name != "Ollama" {
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("Base URL (optional)", text: $customBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .placeholder(when: customBaseURL.isEmpty) {
                                    Text("http://localhost:11434")
                                        .foregroundColor(.secondary)
                                }
                        }
                        
                        // Configuration Status
                        HStack {
                            Image(systemName: currentProvider.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundColor(currentProvider.isConfigured ? .green : .orange)
                            
                            Text(currentProvider.isConfigured ? "Configured" : "Not Configured")
                                .foregroundColor(currentProvider.isConfigured ? .green : .orange)
                            
                            if currentProvider.supportsVision {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.blue)
                                    .help("Supports vision analysis")
                            }
                        }
                    }
                    
                    Section(header: Text("Vision Analysis")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable Vision Analysis", isOn: $voiceAgent.visionManager.isVisionEnabled)
                            
                            if voiceAgent.visionManager.isVisionEnabled {
                                Toggle("Use Vision When Available", isOn: $voiceAgent.aiProviderManager.useVisionWhenAvailable)
                                    .disabled(!currentProvider.supportsVision)
                                
                                if !currentProvider.supportsVision {
                                    Text("Current AI provider does not support vision analysis")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                HStack {
                                    Button("Test Vision") {
                                        testVisionAnalysis()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(!currentProvider.supportsVision)
                                    
                                    Button("Describe Current Screen") {
                                        voiceAgent.describeCurrentScreen()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                if let lastAnalysis = voiceAgent.visionManager.lastAnalysis {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Last Analysis:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text(lastAnalysis.summary)
                                            .font(.caption)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("Voice Recognition")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Listening Language")
                                .font(.subheadline)
                            
                            Picker("Language", selection: $selectedLanguageIndex) {
                                ForEach(0..<languageOptions.count, id: \..self) { index in
                                    Text(languageOptions[index].name).tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedLanguageIndex) { _, newValue in
                                let code = languageOptions[newValue].code
                                voiceAgent.updateSpeechLanguage(code)
                            }

                            Text("Wake Word")
                                .font(.subheadline)

                            Toggle("Enable Wake Word", isOn: $voiceAgent.wakeWordEnabled)

                            TextField("Wake word", text: $wakeWord)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: wakeWord) { _, newValue in
                                    voiceAgent.updateWakeWord(newValue)
                                }
                        }
                    }
                    
                    Section(header: Text("Voice Feedback")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable Voice Feedback", isOn: $voiceAgent.voiceFeedbackManager.isEnabled)
                            
                            if voiceAgent.voiceFeedbackManager.isEnabled {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Voice")
                                        .font(.subheadline)
                                    
                                    Picker("Voice", selection: $selectedVoiceIndex) {
                                        ForEach(0..<availableVoices.count, id: \.self) { index in
                                            Text(availableVoices[index].displayName)
                                                .tag(index)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .onChange(of: selectedVoiceIndex) { _, newValue in
                                        if newValue < availableVoices.count {
                                            voiceAgent.voiceFeedbackManager.setVoice(availableVoices[newValue].identifier)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Volume: \\(Int(voiceAgent.voiceFeedbackManager.volume * 100))%")
                                            .font(.subheadline)
                                        
                                        Slider(value: Binding(
                                            get: { voiceAgent.voiceFeedbackManager.volume },
                                            set: { voiceAgent.voiceFeedbackManager.setVolume($0) }
                                        ), in: 0...1)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Speed: \\(Int(voiceAgent.voiceFeedbackManager.rate * 100))%")
                                            .font(.subheadline)
                                        
                                        Slider(value: Binding(
                                            get: { voiceAgent.voiceFeedbackManager.rate },
                                            set: { voiceAgent.voiceFeedbackManager.setRate($0) }
                                        ), in: 0.1...1.0)
                                    }
                                    
                                    HStack {
                                        Button("Test Voice") {
                                            voiceAgent.voiceFeedbackManager.speak("Hello! This is a test of the voice feedback system.")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        
                                        if voiceAgent.voiceFeedbackManager.isSpeaking {
                                            Button("Stop") {
                                                voiceAgent.voiceFeedbackManager.stopSpeaking()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section(header: Text("Prompt Settings")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("System Prompt")
                                .font(.subheadline)

                            TextEditor(text: $systemPromptText)
                                .frame(minHeight: 80)
                                .border(Color.secondary)

                            Text("Vision Prompt")
                                .font(.subheadline)

                            TextEditor(text: $visionPromptText)
                                .frame(minHeight: 80)
                                .border(Color.secondary)
                        }
                    }
                    
                    Section(header: Text("Live API")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: currentProvider.supportsLiveAPI ? "wifi" : "wifi.slash")
                                    .foregroundColor(currentProvider.supportsLiveAPI ? .green : .gray)
                                
                                VStack(alignment: .leading) {
                                    Text("Live API Support")
                                        .font(.subheadline)
                                    
                                    Text(currentProvider.supportsLiveAPI ? 
                                         "\(currentProvider.name) supports real-time conversation" : 
                                         "\(currentProvider.name) does not support Live API")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if currentProvider.supportsLiveAPI {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Status: ")
                                            .font(.subheadline)
                                        
                                        Text(voiceAgent.liveAPIConnectionStatus)
                                            .font(.subheadline)
                                            .foregroundColor(voiceAgent.isLiveAPIActive ? .green : .gray)
                                    }
                                    
                                    HStack(spacing: 12) {
                                        Button(voiceAgent.isLiveAPIActive ? "Stop Live API" : "Start Live API") {
                                            voiceAgent.toggleLiveAPI()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(!currentProvider.isConfigured)
                                        
                                        if voiceAgent.isLiveAPIActive {
                                            Button("Send Test Message") {
                                                voiceAgent.sendLiveTextMessage("Hello from configuration!")
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                    
                                    if voiceAgent.isLiveAPIActive {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Image(systemName: voiceAgent.isLiveAPIListening ? "waveform" : "waveform.slash")
                                                    .foregroundColor(voiceAgent.isLiveAPIListening ? .green : .gray)
                                                    .font(.caption)
                                                
                                                Text("Listening: \(voiceAgent.isLiveAPIListening ? "Yes" : "No")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Spacer()
                                                
                                                Image(systemName: voiceAgent.isLiveAPISpeaking ? "speaker.wave.2" : "speaker.slash")
                                                    .foregroundColor(voiceAgent.isLiveAPISpeaking ? .blue : .gray)
                                                    .font(.caption)
                                                
                                                Text("Speaking: \(voiceAgent.isLiveAPISpeaking ? "Yes" : "No")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(header: Text("System Permissions")) {
                        PermissionRow(
                            title: "Microphone Access",
                            description: "Required for voice recognition",
                            isGranted: $voiceAgent.permissionManager.microphoneGranted,
                            onRequest: {
                                voiceAgent.permissionManager.requestMicrophonePermission { _ in }
                            }
                        )

                        PermissionRow(
                            title: "Screen Recording",
                            description: "Required for screen monitoring and vision analysis",
                            isGranted: $voiceAgent.permissionManager.screenGranted,
                            onRequest: {
                                voiceAgent.permissionManager.requestScreenPermission { _ in }
                            }
                        )

                        PermissionRow(
                            title: "Accessibility",
                            description: "Required for system control",
                            isGranted: $voiceAgent.permissionManager.accessibilityGranted,
                            onRequest: {
                                voiceAgent.permissionManager.openAccessibilitySettings()
                            }
                        )
                    }
                }
                .formStyle(.grouped)
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Test Configuration") {
                        testConfiguration()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!currentProvider.isConfigured)
                    
                    Button("Save") {
                        saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Configuration")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Configuration", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadCurrentConfiguration()
            loadVoiceSettings()
            voiceAgent.permissionManager.refreshStatuses()
            systemPromptText = getSystemPrompt()
            visionPromptText = getVisionSystemPrompt()
        }
    }
    
    private var currentProvider: AIProvider {
        return voiceAgent.aiProviderManager.providers[selectedProviderIndex]
    }
    
    private func loadCurrentConfiguration() {
        if let currentProvider = voiceAgent.aiProviderManager.currentProvider,
           let index = voiceAgent.aiProviderManager.providers.firstIndex(where: { $0.name == currentProvider.name }) {
            selectedProviderIndex = index
        }
        
        updateModelSelection()
    }
    
    private func updateModelSelection() {
        let provider = currentProvider
        if let currentModel = voiceAgent.aiProviderManager.selectedModel,
           let modelIndex = provider.models.firstIndex(of: currentModel) {
            selectedModelIndex = modelIndex
        } else {
            selectedModelIndex = 0
        }
        
        // Clear API key when switching providers
        apiKey = ""
        customBaseURL = ""
    }
    
    private func saveConfiguration() {
        do {
            let provider = currentProvider
            let selectedModel = selectedModelIndex < provider.models.count ? provider.models[selectedModelIndex] : provider.models.first ?? ""
            
            if provider.name == "Ollama" {
                try provider.configure(apiKey: customBaseURL.isEmpty ? "http://localhost:11434" : customBaseURL, model: selectedModel)
            } else {
                try provider.configure(apiKey: apiKey, model: selectedModel)
            }
            
            voiceAgent.aiProviderManager.selectProvider(provider)
            voiceAgent.aiProviderManager.selectModel(selectedModel)

            updateSystemPrompt(systemPromptText)
            updateVisionSystemPrompt(visionPromptText)
            
            alertMessage = "Configuration saved successfully!"
            showingAlert = true
            
        } catch {
            alertMessage = "Failed to save configuration: \\(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    private func testConfiguration() {
        Task {
            do {
                let provider = currentProvider
                let response = try await provider.processCommand("Say hello", screenContext: "Test screen context")
                
                await MainActor.run {
                    alertMessage = "Test successful! Response: \\(response.prefix(100))..."
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Test failed: \\(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func testVisionAnalysis() {
        Task {
            do {
                // Take a screenshot and analyze it
                if let screenshot = await voiceAgent.screenManager.takeScreenshot() {
                    let analysis = try await voiceAgent.aiProviderManager.analyzeScreenImage(
                        screenshot, 
                        prompt: "Describe what you see in this screenshot"
                    )
                    
                    await MainActor.run {
                        alertMessage = "Vision test successful! Analysis: \\(analysis.prefix(200))..."
                        showingAlert = true
                        
                        // Also speak the result
                        voiceAgent.voiceFeedbackManager.speak("Vision analysis complete", priority: .normal)
                    }
                } else {
                    await MainActor.run {
                        alertMessage = "Failed to capture screenshot for vision test"
                        showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Vision test failed: \\(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func loadVoiceSettings() {
        availableVoices = voiceAgent.voiceFeedbackManager.getAvailableVoices()
        
        // Find current voice index
        if let currentVoiceId = voiceAgent.voiceFeedbackManager.selectedVoice.isEmpty ? nil : voiceAgent.voiceFeedbackManager.selectedVoice,
           let index = availableVoices.firstIndex(where: { $0.identifier == currentVoiceId }) {
            selectedVoiceIndex = index
        }
        
        // Load vision model selection
        if currentProvider.supportsVision && !currentProvider.visionModels.isEmpty {
            selectedVisionModelIndex = 0
        }

        // Load speech language
        if let index = languageOptions.firstIndex(where: { $0.code == voiceAgent.speechLanguage }) {
            selectedLanguageIndex = index
        }

        wakeWord = voiceAgent.wakeWord
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    @Binding var isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant") {
                    onRequest()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    ConfigurationView()
        .environmentObject(VoiceAgent())
}
#endif
