import Foundation
import AppKit
import Vision
import CoreML

@MainActor
class VisionManager: ObservableObject {
    private let aiProviderManager: AIProviderManager

    @Published var isVisionEnabled = true
    @Published var lastAnalysis: ScreenAnalysis?
    @Published var analysisHistory: [ScreenAnalysis] = []
    
    private let maxHistoryCount = 10
    private var visionQueue = DispatchQueue(label: "com.voiceagent.vision", qos: .userInitiated)
    
    struct ScreenAnalysis {
        let id = UUID()
        let timestamp: Date
        let screenshot: NSImage
        let detectedText: [String]
        let uiElements: [UIElement]
        let aiDescription: String
        let confidence: Float
        
        var summary: String {
            var components: [String] = []
            
            if !detectedText.isEmpty {
                components.append("Text detected: \(detectedText.count) items")
            }
            
            if !uiElements.isEmpty {
                components.append("UI elements: \(uiElements.count)")
            }
            
            return components.joined(separator: ", ")
        }
    }
    
    struct UIElement {
        let type: ElementType
        let bounds: CGRect
        let confidence: Float
        let text: String?
        
        enum ElementType: String, CaseIterable {
            case button = "Button"
            case textField = "Text Field"
            case window = "Window"
            case menu = "Menu"
            case icon = "Icon"
            case text = "Text"
            case image = "Image"
            case unknown = "Unknown"
            
            var description: String {
                return self.rawValue
            }
        }
    }
    
    func analyzeScreen(image: NSImage, useAI: Bool = true) async -> ScreenAnalysis? {
        guard isVisionEnabled else { return nil }
        
        return await withCheckedContinuation { continuation in
            visionQueue.async {
                Task {
                    do {
                        // Detect text using Vision framework
                        let detectedText = await self.detectText(in: image)
                        
                        // Detect UI elements using Vision framework
                        let uiElements = await self.detectUIElements(in: image)
                        
                        // Get AI description if enabled
                        var aiDescription = ""
                        if useAI {
                            aiDescription = await self.getAIDescription(for: image) ?? "No AI description available"
                        }
                        
                        let textScore = min(1.0, Float(detectedText.count) / 10.0)
                        let elementScore: Float
                        if uiElements.isEmpty {
                            elementScore = 0.0
                        } else {
                            let total = uiElements.map { $0.confidence }.reduce(0, +)
                            elementScore = total / Float(uiElements.count)
                        }

                        let confidence = min(1.0, (textScore + elementScore) / 2)

                        let analysis = ScreenAnalysis(
                            timestamp: Date(),
                            screenshot: image,
                            detectedText: detectedText,
                            uiElements: uiElements,
                            aiDescription: aiDescription,
                            confidence: confidence
                        )
                        
                        await MainActor.run {
                            self.lastAnalysis = analysis
                            self.analysisHistory.insert(analysis, at: 0)
                            
                            if self.analysisHistory.count > self.maxHistoryCount {
                                self.analysisHistory.removeLast()
                            }
                        }
                        
                        continuation.resume(returning: analysis)
                        
                    } catch {
                        print("Vision analysis error: \(error)")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    private func detectText(in image: NSImage) async -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("Text detection error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let detectedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                continuation.resume(returning: detectedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform text detection: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    private func detectUIElements(in image: NSImage) async -> [UIElement] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        return await withCheckedContinuation { continuation in
            var elements: [UIElement] = []
            
            // Detect rectangles (potential UI elements)
            let rectangleRequest = VNDetectRectanglesRequest { request, error in
                if let observations = request.results as? [VNRectangleObservation] {
                    for observation in observations.prefix(20) { // Limit to prevent too many results
                        let bounds = VNImageRectForNormalizedRect(
                            observation.boundingBox,
                            Int(image.size.width),
                            Int(image.size.height)
                        )
                        
                        let element = UIElement(
                            type: .unknown,
                            bounds: bounds,
                            confidence: observation.confidence,
                            text: nil
                        )
                        elements.append(element)
                    }
                }
            }
            
            rectangleRequest.minimumAspectRatio = 0.1
            rectangleRequest.maximumAspectRatio = 10.0
            rectangleRequest.minimumSize = 0.01
            rectangleRequest.maximumObservations = 20
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([rectangleRequest])
                continuation.resume(returning: elements)
            } catch {
                print("Failed to perform UI element detection: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    private func getAIDescription(for image: NSImage) async -> String? {
        return await analyzeImageWithAI(image)
    }

    private func analyzeImageWithAI(_ image: NSImage) async -> String? {
        do {
            return try await aiProviderManager.analyzeScreenImage(
                image,
                prompt: "Describe what you see in this screenshot in detail. Include UI elements, text content, and overall layout."
            )
        } catch {
            print("AI analysis error: \(error)")
            return nil
        }
    }
    
    func generateDetailedDescription() -> String {
        guard let analysis = lastAnalysis else {
            return "No screen analysis available"
        }
        
        var description: [String] = []
        
        // Add timestamp
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        description.append("Screen analyzed at \(formatter.string(from: analysis.timestamp))")
        
        // Add detected text summary
        if !analysis.detectedText.isEmpty {
            let textCount = analysis.detectedText.count
            let sampleText = analysis.detectedText.prefix(3).joined(separator: ", ")
            description.append("Found \(textCount) text elements including: \(sampleText)")
        }
        
        // Add UI elements summary
        if !analysis.uiElements.isEmpty {
            let elementCount = analysis.uiElements.count
            description.append("Detected \(elementCount) user interface elements")
        }
        
        // Add AI description if available
        if !analysis.aiDescription.isEmpty && analysis.aiDescription != "No AI description available" {
            description.append("Visual analysis: \(analysis.aiDescription)")
        }
        
        return description.joined(separator: ". ")
    }
    
    func generateContextualDescription(for command: String) -> String {
        guard let analysis = lastAnalysis else {
            return "Unable to analyze current screen context"
        }
        
        let commandLower = command.lowercased()
        var contextualInfo: [String] = []
        
        // Analyze command intent and provide relevant context
        if commandLower.contains("click") || commandLower.contains("button") {
            let buttonLikeElements = analysis.uiElements.filter { element in
                element.type == .button || 
                (element.bounds.width > 50 && element.bounds.height > 20 && element.bounds.height < 60)
            }
            
            if !buttonLikeElements.isEmpty {
                contextualInfo.append("I can see \(buttonLikeElements.count) clickable elements on the screen")
            }
        }
        
        if commandLower.contains("text") || commandLower.contains("type") || commandLower.contains("field") {
            let textElements = analysis.uiElements.filter { $0.type == .textField }
            if !textElements.isEmpty {
                contextualInfo.append("There are \(textElements.count) text input areas visible")
            }
            
            if !analysis.detectedText.isEmpty {
                contextualInfo.append("Current screen contains text about: \(analysis.detectedText.prefix(2).joined(separator: ", "))")
            }
        }
        
        if commandLower.contains("read") || commandLower.contains("what") {
            if !analysis.detectedText.isEmpty {
                let mainText = analysis.detectedText.prefix(5).joined(separator: ", ")
                contextualInfo.append("Main text on screen: \(mainText)")
            }
        }
        
        // Add AI description for better context
        if !analysis.aiDescription.isEmpty && analysis.aiDescription != "No AI description available" {
            contextualInfo.append(analysis.aiDescription)
        }
        
        if contextualInfo.isEmpty {
            return "Current screen shows standard desktop interface"
        }
        
        return contextualInfo.joined(separator: ". ")
    }
    
    func findElementNear(description: String) -> UIElement? {
        guard let analysis = lastAnalysis else { return nil }
        
        let descriptionLower = description.lowercased()
        
        // Simple heuristics to find elements based on description
        for element in analysis.uiElements {
            if let text = element.text?.lowercased() {
                if text.contains(descriptionLower) || descriptionLower.contains(text) {
                    return element
                }
            }
            
            // Check element type
            if descriptionLower.contains(element.type.rawValue.lowercased()) {
                return element
            }
        }
        
        return nil
    }
    
    func toggleVisionAnalysis() {
        isVisionEnabled.toggle()
        UserDefaults.standard.set(isVisionEnabled, forKey: "visionEnabled")
    }
    
    func clearHistory() {
        analysisHistory.removeAll()
        lastAnalysis = nil
    }
    
    init(aiProviderManager: AIProviderManager) {
        self.aiProviderManager = aiProviderManager
        loadSettings()
    }
    
    private func loadSettings() {
        isVisionEnabled = UserDefaults.standard.object(forKey: "visionEnabled") as? Bool ?? true
    }
}
