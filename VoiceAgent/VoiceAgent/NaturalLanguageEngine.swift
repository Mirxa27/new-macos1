#if os(macOS)
import Foundation
import NaturalLanguage
import CoreML
import CreateML
import os.log

/// Advanced Natural Language Understanding engine for intelligent command processing
@MainActor
class NaturalLanguageEngine: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "NLU")
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var lastIntent: Intent?
    @Published var entities: [Entity] = []
    @Published var sentiment: Sentiment = .neutral
    @Published var confidence: Double = 0.0
    @Published var context: ConversationContext?
    
    // MARK: - NLP Components
    private var tokenizer: NLTokenizer
    private var tagger: NLTagger
    private var languageRecognizer: NLLanguageRecognizer
    private var sentimentAnalyzer: NLModel?
    private var intentClassifier: NLModel?
    private var entityExtractor: EntityExtractor
    
    // MARK: - Language Models
    private var customModels: [String: MLModel] = [:]
    private var embeddingModel: NLEmbedding?
    private var contextualEmbeddings: [String: [Double]] = [:]
    
    // MARK: - Intent Recognition
    private var registeredIntents: [IntentDefinition] = []
    private var intentPatterns: [String: [Pattern]] = [:]
    private var intentExamples: [String: [String]] = [:]
    
    // MARK: - Context Management
    private var conversationHistory: [Utterance] = []
    private var sessionContext: SessionContext
    private var domainKnowledge: DomainKnowledge
    
    // MARK: - Configuration
    struct Configuration {
        var language: NLLanguage = .english
        var maxHistorySize = 50
        var confidenceThreshold = 0.7
        var enableContextualUnderstanding = true
        var enableSentimentAnalysis = true
        var enableEntityLinking = true
        var enableCoreference = true
        var useTransferLearning = true
    }
    
    var configuration = Configuration()
    
    init() {
        // Initialize NLP components
        tokenizer = NLTokenizer(unit: .word)
        tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
        languageRecognizer = NLLanguageRecognizer()
        entityExtractor = EntityExtractor()
        sessionContext = SessionContext()
        domainKnowledge = DomainKnowledge()
        
        setupLanguageModels()
        registerDefaultIntents()
        loadCustomModels()
    }
    
    // MARK: - Setup
    
    private func setupLanguageModels() {
        // Setup embedding model
        if let embedding = NLEmbedding.wordEmbedding(for: configuration.language) {
            embeddingModel = embedding
            logger.info("Word embedding model loaded for \(configuration.language.rawValue)")
        }
        
        // Setup sentiment analyzer
        setupSentimentAnalyzer()
        
        // Setup intent classifier
        setupIntentClassifier()
    }
    
    private func setupSentimentAnalyzer() {
        // In production, load a trained Core ML model
        // For now, using NaturalLanguage framework's built-in sentiment
        logger.info("Sentiment analyzer initialized")
    }
    
    private func setupIntentClassifier() {
        // Load or train intent classification model
        Task {
            await trainIntentClassifier()
        }
    }
    
    private func registerDefaultIntents() {
        registeredIntents = [
            // System control intents
            IntentDefinition(
                name: "open_application",
                examples: ["open safari", "launch mail", "start finder"],
                requiredEntities: ["application"],
                parameters: ["app_name"]
            ),
            IntentDefinition(
                name: "close_application",
                examples: ["close safari", "quit mail", "exit finder"],
                requiredEntities: ["application"],
                parameters: ["app_name"]
            ),
            IntentDefinition(
                name: "switch_application",
                examples: ["switch to safari", "go to mail", "focus finder"],
                requiredEntities: ["application"],
                parameters: ["app_name"]
            ),
            
            // Navigation intents
            IntentDefinition(
                name: "navigate",
                examples: ["go to website", "navigate to page", "open url"],
                requiredEntities: ["url", "website"],
                parameters: ["destination"]
            ),
            IntentDefinition(
                name: "search",
                examples: ["search for", "find", "look up"],
                requiredEntities: ["query"],
                parameters: ["search_query", "search_scope"]
            ),
            
            // File management intents
            IntentDefinition(
                name: "create_file",
                examples: ["create new document", "make a file", "new text file"],
                requiredEntities: ["file_type"],
                parameters: ["file_name", "file_type", "location"]
            ),
            IntentDefinition(
                name: "open_file",
                examples: ["open document", "show file", "display pdf"],
                requiredEntities: ["file_name"],
                parameters: ["file_path"]
            ),
            
            // Communication intents
            IntentDefinition(
                name: "send_message",
                examples: ["send message to", "text", "message"],
                requiredEntities: ["recipient", "message"],
                parameters: ["to", "body", "app"]
            ),
            IntentDefinition(
                name: "make_call",
                examples: ["call", "phone", "dial"],
                requiredEntities: ["contact"],
                parameters: ["phone_number", "contact_name"]
            ),
            
            // Automation intents
            IntentDefinition(
                name: "start_recording",
                examples: ["start recording", "record actions", "begin automation"],
                requiredEntities: [],
                parameters: ["recording_name"]
            ),
            IntentDefinition(
                name: "play_automation",
                examples: ["play recording", "run automation", "execute macro"],
                requiredEntities: ["automation_name"],
                parameters: ["automation_id", "speed"]
            ),
            
            // Settings intents
            IntentDefinition(
                name: "change_setting",
                examples: ["change setting", "update preference", "set option"],
                requiredEntities: ["setting_name", "setting_value"],
                parameters: ["setting", "value"]
            ),
            
            // Query intents
            IntentDefinition(
                name: "get_information",
                examples: ["what is", "tell me about", "show me"],
                requiredEntities: ["topic"],
                parameters: ["query_type", "subject"]
            ),
            IntentDefinition(
                name: "get_status",
                examples: ["status of", "check", "how is"],
                requiredEntities: ["status_item"],
                parameters: ["item", "metric"]
            )
        ]
        
        // Build pattern database
        for intent in registeredIntents {
            intentPatterns[intent.name] = intent.examples.map { Pattern(text: $0) }
            intentExamples[intent.name] = intent.examples
        }
    }
    
    private func loadCustomModels() {
        // Load any custom Core ML models for NLU
        let modelNames = ["IntentClassifier", "EntityExtractor", "SentimentAnalyzer"]
        
        for modelName in modelNames {
            if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") {
                do {
                    let model = try MLModel(contentsOf: modelURL)
                    customModels[modelName] = model
                    logger.info("Loaded custom model: \(modelName)")
                } catch {
                    logger.error("Failed to load model \(modelName): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Text Processing
    
    func process(_ text: String) async -> NLUResult {
        isProcessing = true
        defer { isProcessing = false }
        
        logger.info("Processing text: \(text)")
        
        // Language detection
        let language = detectLanguage(text)
        
        // Tokenization
        let tokens = tokenize(text)
        
        // POS tagging and lemmatization
        let taggedTokens = tagTokens(tokens, text: text)
        
        // Entity extraction
        let extractedEntities = await extractEntities(from: text, tokens: taggedTokens)
        entities = extractedEntities
        
        // Intent classification
        let intent = await classifyIntent(text: text, entities: extractedEntities)
        lastIntent = intent
        
        // Sentiment analysis
        if configuration.enableSentimentAnalysis {
            sentiment = analyzeSentiment(text)
        }
        
        // Contextual understanding
        if configuration.enableContextualUnderstanding {
            await updateContext(text: text, intent: intent, entities: extractedEntities)
        }
        
        // Coreference resolution
        if configuration.enableCoreference {
            await resolveCoreferences(in: text)
        }
        
        // Calculate confidence
        confidence = calculateConfidence(intent: intent, entities: extractedEntities)
        
        // Add to conversation history
        addToHistory(text: text, intent: intent, entities: extractedEntities)
        
        return NLUResult(
            originalText: text,
            language: language,
            tokens: tokens,
            intent: intent,
            entities: extractedEntities,
            sentiment: sentiment,
            confidence: confidence,
            context: context
        )
    }
    
    // MARK: - Language Detection
    
    private func detectLanguage(_ text: String) -> NLLanguage {
        languageRecognizer.reset()
        languageRecognizer.processString(text)
        
        return languageRecognizer.dominantLanguage ?? configuration.language
    }
    
    // MARK: - Tokenization
    
    private func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            tokens.append(Token(
                text: token,
                range: tokenRange,
                type: .word
            ))
            return true
        }
        
        return tokens
    }
    
    // MARK: - POS Tagging
    
    private func tagTokens(_ tokens: [Token], text: String) -> [TaggedToken] {
        tagger.string = text
        
        var taggedTokens: [TaggedToken] = []
        
        for token in tokens {
            let tags = tagger.tags(in: token.range, unit: .word, scheme: .lexicalClass)
            
            let posTag = tags.compactMap { $0.0 }.first ?? .other
            let lemma = getLemma(for: token.text)
            
            taggedTokens.append(TaggedToken(
                token: token,
                posTag: posTag,
                lemma: lemma
            ))
        }
        
        return taggedTokens
    }
    
    private func getLemma(for word: String) -> String {
        // In production, use lemmatization model
        // For now, return lowercase version
        return word.lowercased()
    }
    
    // MARK: - Entity Extraction
    
    private func extractEntities(from text: String, tokens: [TaggedToken]) async -> [Entity] {
        var extractedEntities: [Entity] = []
        
        // Named entity recognition
        tagger.string = text
        let options: NLTagger.Options = [.omitWhitespace, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag {
                let entityText = String(text[range])
                
                let entity = Entity(
                    text: entityText,
                    type: mapTagToEntityType(tag),
                    range: range,
                    confidence: 0.9
                )
                
                extractedEntities.append(entity)
            }
            return true
        }
        
        // Custom entity extraction
        let customEntities = await entityExtractor.extract(from: text)
        extractedEntities.append(contentsOf: customEntities)
        
        // Entity linking
        if configuration.enableEntityLinking {
            extractedEntities = await linkEntities(extractedEntities)
        }
        
        return extractedEntities
    }
    
    private func mapTagToEntityType(_ tag: NLTag) -> EntityType {
        switch tag {
        case .personalName: return .person
        case .placeName: return .location
        case .organizationName: return .organization
        default: return .other
        }
    }
    
    private func linkEntities(_ entities: [Entity]) async -> [Entity] {
        // Link entities to knowledge base
        var linkedEntities = entities
        
        for (index, entity) in entities.enumerated() {
            if let linkedEntity = domainKnowledge.lookupEntity(entity.text) {
                linkedEntities[index].linkedData = linkedEntity
            }
        }
        
        return linkedEntities
    }
    
    // MARK: - Intent Classification
    
    private func classifyIntent(text: String, entities: [Entity]) async -> Intent? {
        // Rule-based matching first
        if let ruleBasedIntent = matchRuleBasedIntent(text: text) {
            return ruleBasedIntent
        }
        
        // ML-based classification
        if let mlIntent = await classifyWithML(text: text) {
            return mlIntent
        }
        
        // Pattern matching
        if let patternIntent = matchPatternIntent(text: text) {
            return patternIntent
        }
        
        // Fuzzy matching with examples
        return fuzzyMatchIntent(text: text)
    }
    
    private func matchRuleBasedIntent(text: String) -> Intent? {
        let lowercaseText = text.lowercased()
        
        for intent in registeredIntents {
            for example in intent.examples {
                if lowercaseText.contains(example.lowercased()) {
                    return Intent(
                        name: intent.name,
                        confidence: 0.95,
                        parameters: extractParameters(from: text, for: intent)
                    )
                }
            }
        }
        
        return nil
    }
    
    private func classifyWithML(text: String) async -> Intent? {
        guard let classifier = customModels["IntentClassifier"] else { return nil }
        
        // Prepare input features
        let features = prepareFeatures(from: text)
        
        // Make prediction
        do {
            let prediction = try classifier.prediction(from: features)
            
            // Extract intent from prediction
            if let intentName = prediction.featureValue(for: "intent")?.stringValue,
               let confidence = prediction.featureValue(for: "confidence")?.doubleValue {
                
                return Intent(
                    name: intentName,
                    confidence: confidence,
                    parameters: [:]
                )
            }
        } catch {
            logger.error("ML classification failed: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    private func matchPatternIntent(text: String) -> Intent? {
        for (intentName, patterns) in intentPatterns {
            for pattern in patterns {
                if pattern.matches(text) {
                    return Intent(
                        name: intentName,
                        confidence: 0.85,
                        parameters: pattern.extractParameters(from: text)
                    )
                }
            }
        }
        
        return nil
    }
    
    private func fuzzyMatchIntent(text: String) -> Intent? {
        guard let embedding = embeddingModel else { return nil }
        
        // Get text embedding
        guard let textVector = embedding.vector(for: text) else { return nil }
        
        var bestMatch: (intent: String, similarity: Double) = ("", 0.0)
        
        // Compare with intent examples
        for (intentName, examples) in intentExamples {
            for example in examples {
                if let exampleVector = embedding.vector(for: example) {
                    let similarity = cosineSimilarity(textVector, exampleVector)
                    
                    if similarity > bestMatch.similarity {
                        bestMatch = (intentName, similarity)
                    }
                }
            }
        }
        
        if bestMatch.similarity >= configuration.confidenceThreshold {
            return Intent(
                name: bestMatch.intent,
                confidence: bestMatch.similarity,
                parameters: [:]
            )
        }
        
        return nil
    }
    
    private func extractParameters(from text: String, for intent: IntentDefinition) -> [String: Any] {
        var parameters: [String: Any] = [:]
        
        // Extract parameters based on intent definition
        for param in intent.parameters {
            // Simple extraction logic - in production, use more sophisticated methods
            if let value = extractParameterValue(param, from: text) {
                parameters[param] = value
            }
        }
        
        return parameters
    }
    
    private func extractParameterValue(_ parameter: String, from text: String) -> String? {
        // Implement parameter extraction logic
        return nil
    }
    
    // MARK: - Sentiment Analysis
    
    private func analyzeSentiment(_ text: String) -> Sentiment {
        // Use custom model if available
        if let sentimentModel = customModels["SentimentAnalyzer"] {
            return analyzeSentimentWithML(text, model: sentimentModel)
        }
        
        // Fallback to simple analysis
        return simpleSentimentAnalysis(text)
    }
    
    private func analyzeSentimentWithML(_ text: String, model: MLModel) -> Sentiment {
        // Prepare features and make prediction
        let features = prepareFeatures(from: text)
        
        do {
            let prediction = try model.prediction(from: features)
            
            if let sentiment = prediction.featureValue(for: "sentiment")?.stringValue {
                return Sentiment(rawValue: sentiment) ?? .neutral
            }
        } catch {
            logger.error("Sentiment analysis failed: \(error.localizedDescription)")
        }
        
        return .neutral
    }
    
    private func simpleSentimentAnalysis(_ text: String) -> Sentiment {
        let positiveWords = ["good", "great", "excellent", "happy", "love", "wonderful"]
        let negativeWords = ["bad", "terrible", "awful", "hate", "horrible", "angry"]
        
        let lowercaseText = text.lowercased()
        var score = 0
        
        for word in positiveWords {
            if lowercaseText.contains(word) {
                score += 1
            }
        }
        
        for word in negativeWords {
            if lowercaseText.contains(word) {
                score -= 1
            }
        }
        
        if score > 0 {
            return .positive
        } else if score < 0 {
            return .negative
        } else {
            return .neutral
        }
    }
    
    // MARK: - Context Management
    
    private func updateContext(text: String, intent: Intent?, entities: [Entity]) async {
        // Update session context
        sessionContext.lastUtterance = text
        sessionContext.lastIntent = intent
        sessionContext.lastEntities = entities
        sessionContext.timestamp = Date()
        
        // Update conversation context
        if context == nil {
            context = ConversationContext()
        }
        
        context?.addTurn(
            utterance: text,
            intent: intent,
            entities: entities,
            sentiment: sentiment
        )
        
        // Maintain context window
        context?.pruneOldTurns(maxTurns: configuration.maxHistorySize)
    }
    
    private func resolveCoreferences(in text: String) async {
        // Resolve pronouns and references
        let pronouns = ["it", "this", "that", "they", "them", "he", "she"]
        
        for pronoun in pronouns {
            if text.lowercased().contains(pronoun) {
                // Look for antecedent in context
                if let antecedent = findAntecedent(for: pronoun) {
                    logger.debug("Resolved '\(pronoun)' to '\(antecedent)'")
                }
            }
        }
    }
    
    private func findAntecedent(for pronoun: String) -> String? {
        // Search conversation history for antecedent
        guard let context = context else { return nil }
        
        // Simple heuristic - return last mentioned entity
        for turn in context.turns.reversed() {
            if !turn.entities.isEmpty {
                return turn.entities.first?.text
            }
        }
        
        return nil
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateConfidence(intent: Intent?, entities: [Entity]) -> Double {
        var confidence = 0.0
        
        // Intent confidence
        if let intent = intent {
            confidence += intent.confidence * 0.6
        }
        
        // Entity confidence
        if !entities.isEmpty {
            let avgEntityConfidence = entities.map { $0.confidence }.reduce(0, +) / Double(entities.count)
            confidence += avgEntityConfidence * 0.3
        }
        
        // Context confidence
        if context != nil {
            confidence += 0.1
        }
        
        return min(confidence, 1.0)
    }
    
    // MARK: - History Management
    
    private func addToHistory(text: String, intent: Intent?, entities: [Entity]) {
        let utterance = Utterance(
            text: text,
            intent: intent,
            entities: entities,
            sentiment: sentiment,
            timestamp: Date()
        )
        
        conversationHistory.append(utterance)
        
        // Limit history size
        if conversationHistory.count > configuration.maxHistorySize {
            conversationHistory.removeFirst()
        }
    }
    
    // MARK: - Training
    
    private func trainIntentClassifier() async {
        logger.info("Training intent classifier")
        
        // Prepare training data
        var trainingData: [(text: String, label: String)] = []
        
        for intent in registeredIntents {
            for example in intent.examples {
                trainingData.append((example, intent.name))
            }
        }
        
        // In production, use Create ML to train model
        // For now, we'll use the rule-based system
        
        logger.info("Intent classifier training completed")
    }
    
    // MARK: - Utility
    
    private func prepareFeatures(from text: String) -> MLFeatureProvider {
        // Prepare features for ML models
        // In production, implement proper feature extraction
        return MLDictionaryFeatureProvider(dictionary: ["text": text])!
    }
    
    private func cosineSimilarity(_ vector1: [Double], _ vector2: [Double]) -> Double {
        guard vector1.count == vector2.count else { return 0.0 }
        
        var dotProduct = 0.0
        var magnitude1 = 0.0
        var magnitude2 = 0.0
        
        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            magnitude1 += vector1[i] * vector1[i]
            magnitude2 += vector2[i] * vector2[i]
        }
        
        magnitude1 = sqrt(magnitude1)
        magnitude2 = sqrt(magnitude2)
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0.0 }
        
        return dotProduct / (magnitude1 * magnitude2)
    }
    
    // MARK: - Custom Intent Registration
    
    func registerIntent(_ definition: IntentDefinition) {
        registeredIntents.append(definition)
        intentPatterns[definition.name] = definition.examples.map { Pattern(text: $0) }
        intentExamples[definition.name] = definition.examples
        
        logger.info("Registered custom intent: \(definition.name)")
    }
    
    func trainOnExamples(_ examples: [(text: String, intent: String)]) async {
        for (text, intentName) in examples {
            if intentExamples[intentName] == nil {
                intentExamples[intentName] = []
            }
            intentExamples[intentName]?.append(text)
        }
        
        // Retrain models with new examples
        await trainIntentClassifier()
    }
}

// MARK: - Supporting Classes

class EntityExtractor {
    func extract(from text: String) async -> [Entity] {
        // Custom entity extraction logic
        var entities: [Entity] = []
        
        // Extract dates
        let dateEntities = extractDates(from: text)
        entities.append(contentsOf: dateEntities)
        
        // Extract numbers
        let numberEntities = extractNumbers(from: text)
        entities.append(contentsOf: numberEntities)
        
        // Extract custom entities
        let customEntities = extractCustomEntities(from: text)
        entities.append(contentsOf: customEntities)
        
        return entities
    }
    
    private func extractDates(from text: String) -> [Entity] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            
            return Entity(
                text: String(text[range]),
                type: .date,
                range: range,
                confidence: 0.95
            )
        }
    }
    
    private func extractNumbers(from text: String) -> [Entity] {
        // Extract numeric entities
        return []
    }
    
    private func extractCustomEntities(from text: String) -> [Entity] {
        // Extract domain-specific entities
        return []
    }
}

class DomainKnowledge {
    private var knowledgeBase: [String: LinkedData] = [:]
    
    init() {
        loadKnowledgeBase()
    }
    
    private func loadKnowledgeBase() {
        // Load domain knowledge
        knowledgeBase = [
            "Safari": LinkedData(type: "application", id: "com.apple.Safari"),
            "Mail": LinkedData(type: "application", id: "com.apple.Mail"),
            "Finder": LinkedData(type: "application", id: "com.apple.Finder")
        ]
    }
    
    func lookupEntity(_ text: String) -> LinkedData? {
        return knowledgeBase[text]
    }
}

// MARK: - Data Models

struct NLUResult {
    let originalText: String
    let language: NLLanguage
    let tokens: [Token]
    let intent: Intent?
    let entities: [Entity]
    let sentiment: Sentiment
    let confidence: Double
    let context: ConversationContext?
}

struct Token {
    let text: String
    let range: Range<String.Index>
    let type: TokenType
}

enum TokenType {
    case word
    case punctuation
    case whitespace
    case other
}

struct TaggedToken {
    let token: Token
    let posTag: NLTag
    let lemma: String
}

struct Intent {
    let name: String
    let confidence: Double
    let parameters: [String: Any]
}

struct IntentDefinition {
    let name: String
    let examples: [String]
    let requiredEntities: [String]
    let parameters: [String]
}

struct Entity {
    let text: String
    let type: EntityType
    let range: Range<String.Index>
    let confidence: Double
    var linkedData: LinkedData?
}

enum EntityType {
    case person
    case location
    case organization
    case date
    case time
    case number
    case email
    case url
    case phoneNumber
    case application
    case file
    case other
}

struct LinkedData {
    let type: String
    let id: String
    var attributes: [String: Any] = [:]
}

enum Sentiment: String {
    case positive
    case negative
    case neutral
    case mixed
}

struct Pattern {
    let text: String
    private let regex: NSRegularExpression?
    
    init(text: String) {
        self.text = text
        self.regex = try? NSRegularExpression(pattern: text, options: .caseInsensitive)
    }
    
    func matches(_ text: String) -> Bool {
        guard let regex = regex else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    func extractParameters(from text: String) -> [String: Any] {
        // Extract parameters from matched text
        return [:]
    }
}

struct Utterance {
    let text: String
    let intent: Intent?
    let entities: [Entity]
    let sentiment: Sentiment
    let timestamp: Date
}

class SessionContext {
    var lastUtterance: String?
    var lastIntent: Intent?
    var lastEntities: [Entity] = []
    var timestamp: Date?
    var sessionId = UUID()
}

class ConversationContext {
    var turns: [ConversationTurn] = []
    var topic: String?
    var startTime = Date()
    
    func addTurn(utterance: String, intent: Intent?, entities: [Entity], sentiment: Sentiment) {
        let turn = ConversationTurn(
            utterance: utterance,
            intent: intent,
            entities: entities,
            sentiment: sentiment,
            timestamp: Date()
        )
        turns.append(turn)
    }
    
    func pruneOldTurns(maxTurns: Int) {
        if turns.count > maxTurns {
            turns = Array(turns.suffix(maxTurns))
        }
    }
}

struct ConversationTurn {
    let utterance: String
    let intent: Intent?
    let entities: [Entity]
    let sentiment: Sentiment
    let timestamp: Date
}

#endif