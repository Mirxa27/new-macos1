import Foundation

protocol AIProvider {
    var name: String { get }
    var models: [String] { get }
    var visionModels: [String] { get }
    var isConfigured: Bool { get }
    var supportsVision: Bool { get }
    
    func configure(apiKey: String, model: String) throws
    func processCommand(_ command: String, screenContext: String) async throws -> String
    func processCommandWithVision(_ command: String, screenContext: String, image: NSImage) async throws -> String
    func analyzeImage(_ image: NSImage, prompt: String?) async throws -> String
}

class AIProviderManager: ObservableObject {
    @Published var providers: [AIProvider] = []
    @Published var currentProvider: AIProvider?
    @Published var selectedModel: String = ""
    @Published var useVisionWhenAvailable = true
    @Published var visionAnalysisEnabled = true
    
    init() {
        setupProviders()
        loadConfiguration()
    }
    
    private func setupProviders() {
        providers = [
            OpenAIProvider(),
            AnthropicProvider(),
            OllamaProvider(),
            GroqProvider()
        ]
    }
    
    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        
        if let providerName = defaults.string(forKey: "selectedProvider") {
            currentProvider = providers.first { $0.name == providerName }
        }
        
        selectedModel = defaults.string(forKey: "selectedModel") ?? ""
        useVisionWhenAvailable = defaults.object(forKey: "useVisionWhenAvailable") as? Bool ?? true
        visionAnalysisEnabled = defaults.object(forKey: "visionAnalysisEnabled") as? Bool ?? true
    }
    
    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(currentProvider?.name, forKey: "selectedProvider")
        defaults.set(selectedModel, forKey: "selectedModel")
        defaults.set(useVisionWhenAvailable, forKey: "useVisionWhenAvailable")
        defaults.set(visionAnalysisEnabled, forKey: "visionAnalysisEnabled")
    }
    
    func selectProvider(_ provider: AIProvider) {
        currentProvider = provider
        selectedModel = provider.models.first ?? ""
        saveConfiguration()
    }
    
    func selectModel(_ model: String) {
        selectedModel = model
        saveConfiguration()
    }
    
    func processCommandWithVision(_ command: String, image: NSImage?) async throws -> String {
        guard let provider = currentProvider else {
            throw AIProviderError.notConfigured
        }
        
        let screenContext = "Recent screen analysis available"
        
        if let image = image, provider.supportsVision && useVisionWhenAvailable {
            return try await provider.processCommandWithVision(command, screenContext: screenContext, image: image)
        } else {
            return try await provider.processCommand(command, screenContext: screenContext)
        }
    }
    
    func analyzeScreenImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        guard let provider = currentProvider else {
            throw AIProviderError.notConfigured
        }
        
        guard provider.supportsVision else {
            throw AIProviderError.visionNotSupported
        }
        
        return try await provider.analyzeImage(image, prompt: prompt)
    }
    
    func toggleVisionUsage() {
        useVisionWhenAvailable.toggle()
        saveConfiguration()
    }
}

// MARK: - OpenAI Provider
class OpenAIProvider: AIProvider {
    let name = "OpenAI"
    let models = ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"]
    let visionModels = ["gpt-4-vision-preview", "gpt-4-turbo", "gpt-4o"]
    let supportsVision = true
    
    private var apiKey: String = ""
    private var selectedModel: String = "gpt-4"
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
    
    func configure(apiKey: String, model: String) throws {
        guard !apiKey.isEmpty else {
            throw AIProviderError.invalidAPIKey
        }
        
        self.apiKey = apiKey
        self.selectedModel = model
        
        // Save to keychain
        try saveToKeychain(key: "openai_api_key", value: apiKey)
        UserDefaults.standard.set(model, forKey: "openai_model")
    }
    
    func processCommand(_ command: String, screenContext: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.notConfigured
        }
        
        let prompt = buildPrompt(command: command, screenContext: screenContext)
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.1
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = result?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content ?? "No response received"
    }
    
    func processCommandWithVision(_ command: String, screenContext: String, image: NSImage) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.notConfigured
        }
        
        // Convert image to base64
        guard let base64Image = imageToBase64(image) else {
            throw AIProviderError.imageProcessingFailed
        }
        
        let prompt = buildVisionPrompt(command: command, screenContext: screenContext)
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = [
            "model": visionModels.contains(selectedModel) ? selectedModel : "gpt-4-vision-preview",
            "messages": [
                ["role": "system", "content": visionSystemPrompt],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.1
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = result?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content ?? "No vision response received"
    }
    
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.notConfigured
        }
        
        guard let base64Image = imageToBase64(image) else {
            throw AIProviderError.imageProcessingFailed
        }
        
        let analysisPrompt = prompt ?? "Describe what you see in this screenshot in detail. Include UI elements, text content, and overall layout."
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = [
            "model": "gpt-4-vision-preview",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": analysisPrompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64Image)",
                                "detail": "high"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.1
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = result?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
    
    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // Resize image if too large (OpenAI has size limits)
        let maxSize: CGFloat = 1024
        let originalSize = image.size
        
        var newSize = originalSize
        if originalSize.width > maxSize || originalSize.height > maxSize {
            let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
            newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        guard let resizedTiffData = resizedImage.tiffRepresentation,
              let resizedBitmap = NSBitmapImageRep(data: resizedTiffData),
              let pngData = resizedBitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData.base64EncodedString()
    }
    
    init() {
        // Load saved configuration
        if let savedKey = loadFromKeychain(key: "openai_api_key") {
            self.apiKey = savedKey
        }
        self.selectedModel = UserDefaults.standard.string(forKey: "openai_model") ?? "gpt-4"
    }
}

// MARK: - Anthropic Provider
class AnthropicProvider: AIProvider {
    let name = "Anthropic"
    let models = ["claude-3-sonnet-20240229", "claude-3-haiku-20240307", "claude-3-opus-20240229"]
    let visionModels = ["claude-3-sonnet-20240229", "claude-3-opus-20240229"]
    let supportsVision = true
    
    private var apiKey: String = ""
    private var selectedModel: String = "claude-3-sonnet-20240229"
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
    
    func configure(apiKey: String, model: String) throws {
        guard !apiKey.isEmpty else {
            throw AIProviderError.invalidAPIKey
        }
        
        self.apiKey = apiKey
        self.selectedModel = model
        
        try saveToKeychain(key: "anthropic_api_key", value: apiKey)
        UserDefaults.standard.set(model, forKey: "anthropic_model")
    }
    
    func processCommand(_ command: String, screenContext: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.notConfigured
        }
        
        let prompt = buildPrompt(command: command, screenContext: screenContext)
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody = [
            "model": selectedModel,
            "max_tokens": 500,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "system": systemPrompt
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String
        
        return text ?? "No response received"
    }
    
    func processCommandWithVision(_ command: String, screenContext: String, image: NSImage) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.notConfigured
        }
        
        guard let base64Image = imageToBase64(image) else {
            throw AIProviderError.imageProcessingFailed
        }
        
        let prompt = buildVisionPrompt(command: command, screenContext: screenContext)
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody = [
            "model": selectedModel,
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/png",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "system": visionSystemPrompt
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String
        
        return text ?? "No vision response received"
    }
    
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.notConfigured
        }
        
        guard let base64Image = imageToBase64(image) else {
            throw AIProviderError.imageProcessingFailed
        }
        
        let analysisPrompt = prompt ?? "Describe what you see in this screenshot in detail. Include UI elements, text content, and overall layout."
        
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody = [
            "model": selectedModel,
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": analysisPrompt],
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/png",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        let text = content?.first?["text"] as? String
        
        return text ?? "No image analysis received"
    }
    
    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // Resize image if too large
        let maxSize: CGFloat = 1024
        let originalSize = image.size
        
        var newSize = originalSize
        if originalSize.width > maxSize || originalSize.height > maxSize {
            let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
            newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        guard let resizedTiffData = resizedImage.tiffRepresentation,
              let resizedBitmap = NSBitmapImageRep(data: resizedTiffData),
              let pngData = resizedBitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData.base64EncodedString()
    }
    
    init() {
        if let savedKey = loadFromKeychain(key: "anthropic_api_key") {
            self.apiKey = savedKey
        }
        self.selectedModel = UserDefaults.standard.string(forKey: "anthropic_model") ?? "claude-3-sonnet-20240229"
    }
    
    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        // Resize image if too large
        let maxSize: CGFloat = 1024
        let originalSize = image.size
        
        var newSize = originalSize
        if originalSize.width > maxSize || originalSize.height > maxSize {
            let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
            newSize = CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        guard let resizedTiffData = resizedImage.tiffRepresentation,
              let resizedBitmap = NSBitmapImageRep(data: resizedTiffData),
              let pngData = resizedBitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData.base64EncodedString()
    }
}

// MARK: - Ollama Provider (Local)
class OllamaProvider: AIProvider {
    let name = "Ollama"
    let models = ["llama2", "codellama", "mistral", "phi", "neural-chat"]
    let visionModels = ["llava", "bakllava"]
    let supportsVision = true
    
    private var selectedModel: String = "llama2"
    private var baseURL: String = "http://localhost:11434"
    
    var isConfigured: Bool {
        return true // Ollama is always "configured" if running locally
    }
    
    func configure(apiKey: String, model: String) throws {
        // Ollama doesn't need API key, but we can set the model and base URL
        self.selectedModel = model
        if !apiKey.isEmpty {
            self.baseURL = apiKey // Use apiKey field for custom base URL
        }
        
        UserDefaults.standard.set(model, forKey: "ollama_model")
        UserDefaults.standard.set(baseURL, forKey: "ollama_base_url")
    }
    
    func processCommand(_ command: String, screenContext: String) async throws -> String {
        let prompt = buildPrompt(command: command, screenContext: screenContext)
        
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "model": selectedModel,
            "prompt": "\(systemPrompt)\n\nUser: \(prompt)",
            "stream": false
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let responseText = result?["response"] as? String
        
        return responseText ?? "No response received"
    }
    
    func processCommandWithVision(_ command: String, screenContext: String, image: NSImage) async throws -> String {
        guard let base64Image = imageToBase64(image) else {
            throw AIProviderError.imageProcessingFailed
        }
        
        let prompt = buildVisionPrompt(command: command, screenContext: screenContext)
        
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let visionModel = visionModels.contains(selectedModel) ? selectedModel : "llava"
        
        let requestBody = [
            "model": visionModel,
            "prompt": prompt,
            "images": [base64Image],
            "stream": false
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let responseText = result?["response"] as? String
        
        return responseText ?? "No vision response received"
    }
    
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
        guard let base64Image = imageToBase64(image) else {
            throw AIProviderError.imageProcessingFailed
        }
        
        let analysisPrompt = prompt ?? "Describe what you see in this screenshot in detail. Include UI elements, text content, and overall layout."
        
        let url = URL(string: "\(baseURL)/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "model": "llava",
            "prompt": analysisPrompt,
            "images": [base64Image],
            "stream": false
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let responseText = result?["response"] as? String
        
        return responseText ?? "No image analysis received"
    }
    
    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData.base64EncodedString()
    }
    
    init() {
        self.selectedModel = UserDefaults.standard.string(forKey: "ollama_model") ?? "llama2"
        self.baseURL = UserDefaults.standard.string(forKey: "ollama_base_url") ?? "http://localhost:11434"
    }
    
    private func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData.base64EncodedString()
    }
}

// MARK: - Groq Provider
class GroqProvider: AIProvider {
    let name = "Groq"
    let models = ["mixtral-8x7b-32768", "llama2-70b-4096", "gemma-7b-it"]
    let visionModels: [String] = [] // Groq doesn't support vision yet
    let supportsVision = false
    
    private var apiKey: String = ""
    private var selectedModel: String = "mixtral-8x7b-32768"
    
    var isConfigured: Bool {
        return !apiKey.isEmpty
    }
    
    func configure(apiKey: String, model: String) throws {
        guard !apiKey.isEmpty else {
            throw AIProviderError.invalidAPIKey
        }
        
        self.apiKey = apiKey
        self.selectedModel = model
        
        try saveToKeychain(key: "groq_api_key", value: apiKey)
        UserDefaults.standard.set(model, forKey: "groq_model")
    }
    
    func processCommand(_ command: String, screenContext: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIProviderError.notConfigured
        }
        
        let prompt = buildPrompt(command: command, screenContext: screenContext)
        
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody = [
            "model": selectedModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.1
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIProviderError.apiRequestFailed
        }
        
        let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = result?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let content = message?["content"] as? String
        
        return content ?? "No response received"
    }
    
    func processCommandWithVision(_ command: String, screenContext: String, image: NSImage) async throws -> String {
        // Groq doesn't support vision, fall back to text-only
        return try await processCommand(command, screenContext: screenContext)
    }
    
    func analyzeImage(_ image: NSImage, prompt: String? = nil) async throws -> String {
    
    init() {
        if let savedKey = loadFromKeychain(key: "groq_api_key") {
            self.apiKey = savedKey
        }
        self.selectedModel = UserDefaults.standard.string(forKey: "groq_model") ?? "mixtral-8x7b-32768"
    }
}

// MARK: - Helper Functions
private let visionSystemPrompt = """
You are a macOS voice assistant with vision capabilities that can see and control the computer through voice commands.

Your role is to interpret user voice commands while analyzing the current screen image to provide context-aware responses.

Available actions:
- click(x, y) - Click at specific coordinates
- type("text") - Type specific text
- key("keyname") - Press a specific key (enter, space, tab, command, etc.)
- scroll("direction") - Scroll in a direction (up, down, left, right)
- open("appname") - Open an application

When responding:
1. Analyze the provided screenshot to understand the current screen context
2. Identify relevant UI elements, buttons, text fields, and content
3. If the command requires a system action, respond with the exact action format
4. If the command is conversational or informational, provide detailed visual descriptions
5. Use the visual information to provide precise coordinates and context

Examples:
- "click on the red button" → Analyze screenshot, find red button, respond "click(150, 300)"
- "what's on my screen?" → Describe visible elements, windows, text, and layout
- "type in the search box" → Find search field, click it first "click(200, 100)", then "type(search text)"

Be precise with coordinates based on what you can see in the image.
"""

private func buildVisionPrompt(command: String, screenContext: String) -> String {
    return """
    Current Screen Context (from previous analysis):
    \(screenContext)
    
    User Command: \(command)
    
    Please analyze the provided screenshot image and the user command to provide the appropriate response or action. Use the visual information to give precise coordinates and detailed context.
    """
}

// MARK: - Keychain Helpers
private func saveToKeychain(key: String, value: String) throws {
    let data = value.data(using: .utf8)!
    
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]
    
    SecItemDelete(query as CFDictionary)
    
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw AIProviderError.keychainError
    }
}

private func loadFromKeychain(key: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var dataTypeRef: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
    
    if status == errSecSuccess {
        if let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
    }
    
    return nil
}

enum AIProviderError: Error, LocalizedError {
    case invalidAPIKey
    case notConfigured
    case apiRequestFailed
    case keychainError
    case imageProcessingFailed
    case visionNotSupported
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .notConfigured:
            return "AI provider not configured"
        case .apiRequestFailed:
            return "API request failed"
        case .keychainError:
            return "Keychain operation failed"
        case .imageProcessingFailed:
            return "Failed to process image for vision analysis"
        case .visionNotSupported:
            return "This provider does not support vision capabilities"
        }
    }
}