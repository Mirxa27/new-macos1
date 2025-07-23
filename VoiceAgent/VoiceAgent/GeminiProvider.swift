#if os(macOS)
//
//  GeminiProvider.swift
//  VoiceAgent
//
//  Google Gemini AI provider implementation with Live API support
//

import Foundation
import AppKit
import Security

class GeminiProvider: AIProvider, ObservableObject {
    let name = "Gemini"
    let models = [
        "gemini-2.5-flash-preview",
        "gemini-1.5-pro-latest",
        "gemini-1.5-flash-latest"
    ]
    
    let visionModels = [
        "gemini-2.5-flash-preview",
        "gemini-1.5-pro-latest",
        "gemini-1.5-flash-latest"
    ]
    
    let supportsVision = true
    let supportsLiveAPI = true
    
    private var apiKey: String?
    private var selectedModel = "gemini-2.5-flash-preview"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"
    
    // Live API Manager
    private var liveAPIManager: GeminiLiveAPIManager?
    @Published var liveAPIConnected = false
    @Published var liveAPIListening = false
    @Published var liveAPISpeaking = false
    
    // MARK: - Configuration
    func configure(apiKey: String, model: String?) {
        self.apiKey = apiKey
        if let model = model {
            self.selectedModel = model
        }
        saveAPIKey(apiKey)
        
        // Configure live API manager if it exists
        if let manager = liveAPIManager {
            manager.configure(apiKey: apiKey, model: selectedModel)
        }
    }
    
    // MARK: - Standard API Methods
    func processCommand(_ command: String, context: String) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.configurationMissing
        }
        
        let prompt = buildPrompt(command: command, context: context)
        return try await makeAPIRequest(prompt: prompt, model: selectedModel)
    }
    
    func processCommandWithVision(_ command: String, screenContext: String, image: NSImage) async throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AIProviderError.imageProcessingFailed
        }
        return try await processCommandWithVision(command, context: screenContext, imageData: pngData)
    }

    private func processCommandWithVision(_ command: String, context: String, imageData: Data) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.configurationMissing
        }
        
        let base64Image = imageToBase64(imageData)
        let prompt = buildVisionPrompt(command: command, context: context)
        
        return try await makeVisionAPIRequest(prompt: prompt, imageData: base64Image, model: selectedModel)
    }
    
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.configurationMissing
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AIProviderError.imageProcessingFailed
        }

        let base64Image = imageToBase64(pngData)
        let analysisPrompt = prompt ?? "Describe what you see in this screenshot in detail. Include UI elements, text content, and overall layout."
        return try await makeVisionAPIRequest(prompt: analysisPrompt, imageData: base64Image, model: selectedModel)
    }
    
    // MARK: - Live API Implementation
    func startLiveSession() async throws {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIProviderError.configurationMissing
        }
        
        if liveAPIManager == nil {
            liveAPIManager = GeminiLiveAPIManager()
        }
        
        guard let manager = liveAPIManager else {
            throw AIProviderError.liveAPINotImplemented
        }
        
        manager.configure(apiKey: apiKey, model: selectedModel)
        
        try await manager.startLiveSession()
        
        // Update published properties
        await MainActor.run {
            self.liveAPIConnected = manager.isConnected
            self.liveAPIListening = manager.isListening
            self.liveAPISpeaking = manager.isSpeaking
        }
        
        // Start monitoring manager state
        startMonitoringLiveAPI()
    }
    
    func stopLiveSession() async {
        liveAPIManager?.stopLiveSession()
        
        await MainActor.run {
            self.liveAPIConnected = false
            self.liveAPIListening = false
            self.liveAPISpeaking = false
        }
    }
    
    func sendLiveAudio(_ audioData: Data) async throws {
        // Audio is handled automatically by the live API manager
        // This method is kept for compatibility but audio streaming
        // is managed internally by GeminiLiveAPIManager
    }
    
    func sendLiveImage(_ imageData: Data) async throws {
        // Screen capture is handled automatically by the live API manager
        // This method is kept for compatibility but screen streaming
        // is managed internally by GeminiLiveAPIManager
    }
    
    func sendLiveTextMessage(_ text: String) async throws {
        guard let manager = liveAPIManager else {
            throw AIProviderError.liveAPINotImplemented
        }
        
        try await manager.sendTextMessage(text)
    }
    
    func isLiveSessionActive() -> Bool {
        return liveAPIManager?.sessionActive ?? false
    }
    
    func getLiveAPIStatus() -> (connected: Bool, listening: Bool, speaking: Bool) {
        guard let manager = liveAPIManager else {
            return (false, false, false)
        }
        
        return (manager.isConnected, manager.isListening, manager.isSpeaking)
    }
    
    private func startMonitoringLiveAPI() {
        Task {
            while liveAPIManager?.sessionActive == true {
                await MainActor.run {
                    if let manager = self.liveAPIManager {
                        self.liveAPIConnected = manager.isConnected
                        self.liveAPIListening = manager.isListening
                        self.liveAPISpeaking = manager.isSpeaking
                    }
                }
                
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }
    
    // MARK: - Private API Methods
    private func makeAPIRequest(prompt: String, model: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AIProviderError.configurationMissing
        }
        
        let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)")!
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.8,
                "topK": 40,
                "maxOutputTokens": 1024
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIProviderError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIProviderError.invalidResponse
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func makeVisionAPIRequest(prompt: String, imageData: String, model: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw AIProviderError.configurationMissing
        }
        
        let url = URL(string: "\(baseURL)/\(model):generateContent?key=\(apiKey)")!
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": imageData
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "topP": 0.8,
                "topK": 40,
                "maxOutputTokens": 1024
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIProviderError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIProviderError.invalidResponse
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Helper Methods
    private func imageToBase64(_ imageData: Data) -> String {
        return imageData.base64EncodedString()
    }
    
    private func buildPrompt(command: String, context: String) -> String {
        return """
        You are a helpful voice assistant for macOS. The user has given you this command: "\(command)"
        
        Current system context: \(context)
        
        Provide a clear, concise response that helps the user understand what action will be taken or what information is being provided. Keep responses brief and conversational.
        """
    }
    
    private func buildVisionPrompt(command: String, context: String) -> String {
        return """
        You are a helpful voice assistant for macOS with vision capabilities. The user has given you this command: "\(command)"
        
        Current system context: \(context)
        
        Analyze the provided screenshot and provide a helpful response based on what you can see on the screen. Consider the visual elements, text, UI components, and their relationship to the user's command.
        
        Keep responses brief and conversational.
        """
    }
    
    // MARK: - Keychain Integration
    private func saveAPIKey(_ key: String) {
        let keychainItem = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "VoiceAgent-Gemini",
            kSecAttrAccount as String: "api-key",
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ] as [String : Any]
        
        SecItemDelete(keychainItem as CFDictionary)
        SecItemAdd(keychainItem as CFDictionary, nil)
    }
    
    private func loadAPIKey() -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "VoiceAgent-Gemini",
            kSecAttrAccount as String: "api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String : Any]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    init() {
        self.apiKey = loadAPIKey()
    }
}#endif
