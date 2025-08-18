#if os(macOS)
import Foundation
import os.log
import Combine

/// Manages error recovery and retry mechanisms throughout the application
@MainActor
class ErrorRecoveryManager: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "ErrorRecovery")
    
    // MARK: - Published Properties
    @Published var activeErrors: [RecoverableError] = []
    @Published var isRecovering = false
    @Published var recoveryAttempts: Int = 0
    @Published var lastRecoveryTime: Date?
    @Published var errorHistory: [ErrorHistoryEntry] = []
    
    // MARK: - Recovery Strategies
    private var recoveryStrategies: [ErrorType: [RecoveryStrategy]] = [:]
    private var activeRecoveryTasks: [UUID: Task<Bool, Never>] = [:]
    private var errorPatterns: [ErrorPattern] = []
    
    // MARK: - Configuration
    struct Configuration {
        var maxRetryAttempts: Int = 3
        var retryDelay: TimeInterval = 1.0
        var exponentialBackoff: Bool = true
        var backoffMultiplier: Double = 2.0
        var maxBackoffDelay: TimeInterval = 30.0
        var autoRecovery: Bool = true
        var circuitBreakerEnabled: Bool = true
        var circuitBreakerThreshold: Int = 5
        var circuitBreakerTimeout: TimeInterval = 60.0
    }
    
    var configuration = Configuration()
    
    // MARK: - Circuit Breaker
    private var circuitBreakers: [String: CircuitBreaker] = [:]
    
    // MARK: - Error Tracking
    private var errorCounts: [String: Int] = [:]
    private var errorTimestamps: [String: [Date]] = [:]
    
    init() {
        setupDefaultStrategies()
        loadErrorPatterns()
    }
    
    // MARK: - Setup
    
    private func setupDefaultStrategies() {
        // Network errors
        recoveryStrategies[.network] = [
            RetryStrategy(maxAttempts: 3, delay: 1.0),
            FallbackStrategy(fallbackAction: { [weak self] in
                self?.switchToOfflineMode()
            }),
            CircuitBreakerStrategy()
        ]
        
        // API errors
        recoveryStrategies[.api] = [
            RetryStrategy(maxAttempts: 3, delay: 2.0, exponentialBackoff: true),
            RefreshTokenStrategy(),
            FallbackStrategy(fallbackAction: { [weak self] in
                self?.useAlternativeAPI()
            })
        ]
        
        // Audio errors
        recoveryStrategies[.audio] = [
            RestartComponentStrategy(componentName: "AudioManager"),
            RetryStrategy(maxAttempts: 2, delay: 0.5),
            FallbackStrategy(fallbackAction: { [weak self] in
                self?.disableAudioTemporarily()
            })
        ]
        
        // Vision errors
        recoveryStrategies[.vision] = [
            RetryStrategy(maxAttempts: 2, delay: 1.0),
            QualityReductionStrategy(),
            FallbackStrategy(fallbackAction: { [weak self] in
                self?.useBasicVision()
            })
        ]
        
        // System errors
        recoveryStrategies[.system] = [
            PermissionRequestStrategy(),
            RestartComponentStrategy(componentName: "SystemController"),
            UserInterventionStrategy()
        ]
        
        // Memory errors
        recoveryStrategies[.memory] = [
            MemoryCleanupStrategy(),
            CacheClearStrategy(),
            ComponentRestartStrategy()
        ]
    }
    
    private func loadErrorPatterns() {
        errorPatterns = [
            ErrorPattern(
                name: "Repeated Network Failures",
                condition: { errors in
                    errors.filter { $0.type == .network }.count > 3
                },
                action: { [weak self] in
                    self?.handleRepeatedNetworkFailures()
                }
            ),
            ErrorPattern(
                name: "Memory Pressure",
                condition: { errors in
                    errors.contains { $0.type == .memory }
                },
                action: { [weak self] in
                    self?.handleMemoryPressure()
                }
            ),
            ErrorPattern(
                name: "API Rate Limit",
                condition: { errors in
                    errors.contains { $0.code == "RATE_LIMIT_EXCEEDED" }
                },
                action: { [weak self] in
                    self?.handleRateLimitExceeded()
                }
            )
        ]
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error, context: ErrorContext) async -> Bool {
        logger.error("Handling error: \(error.localizedDescription)")
        
        // Create recoverable error
        let recoverableError = RecoverableError(
            id: UUID(),
            error: error,
            type: classifyError(error),
            context: context,
            timestamp: Date(),
            attemptCount: 0
        )
        
        // Add to active errors
        activeErrors.append(recoverableError)
        
        // Record in history
        recordErrorHistory(recoverableError)
        
        // Check for patterns
        checkErrorPatterns()
        
        // Attempt recovery if auto-recovery is enabled
        if configuration.autoRecovery {
            return await attemptRecovery(for: recoverableError)
        }
        
        return false
    }
    
    private func attemptRecovery(for recoverableError: RecoverableError) async -> Bool {
        guard recoverableError.attemptCount < configuration.maxRetryAttempts else {
            logger.error("Max retry attempts reached for error: \(recoverableError.error.localizedDescription)")
            return false
        }
        
        isRecovering = true
        defer { isRecovering = false }
        
        // Get recovery strategies for this error type
        guard let strategies = recoveryStrategies[recoverableError.type] else {
            logger.warning("No recovery strategies for error type: \(recoverableError.type)")
            return false
        }
        
        // Try each strategy
        for strategy in strategies {
            if await executeStrategy(strategy, for: recoverableError) {
                logger.info("Successfully recovered from error using \(strategy.name)")
                removeError(recoverableError)
                lastRecoveryTime = Date()
                return true
            }
        }
        
        // Update attempt count
        if let index = activeErrors.firstIndex(where: { $0.id == recoverableError.id }) {
            activeErrors[index].attemptCount += 1
            recoveryAttempts += 1
        }
        
        return false
    }
    
    private func executeStrategy(_ strategy: RecoveryStrategy, for error: RecoverableError) async -> Bool {
        logger.info("Executing recovery strategy: \(strategy.name)")
        
        // Check circuit breaker
        if configuration.circuitBreakerEnabled {
            let breakerKey = "\(error.type)-\(strategy.name)"
            if let breaker = circuitBreakers[breakerKey], breaker.isOpen {
                logger.warning("Circuit breaker is open for \(breakerKey)")
                return false
            }
        }
        
        // Apply delay with backoff
        let delay = calculateDelay(for: error)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // Execute strategy
        let success = await strategy.execute(error: error, manager: self)
        
        // Update circuit breaker
        if configuration.circuitBreakerEnabled {
            updateCircuitBreaker(for: strategy.name, success: success)
        }
        
        return success
    }
    
    private func calculateDelay(for error: RecoverableError) -> TimeInterval {
        var delay = configuration.retryDelay
        
        if configuration.exponentialBackoff {
            delay *= pow(configuration.backoffMultiplier, Double(error.attemptCount))
            delay = min(delay, configuration.maxBackoffDelay)
        }
        
        return delay
    }
    
    // MARK: - Error Classification
    
    private func classifyError(_ error: Error) -> ErrorType {
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("network") || errorString.contains("connection") {
            return .network
        } else if errorString.contains("api") || errorString.contains("request") {
            return .api
        } else if errorString.contains("audio") || errorString.contains("microphone") {
            return .audio
        } else if errorString.contains("vision") || errorString.contains("screen") {
            return .vision
        } else if errorString.contains("memory") || errorString.contains("allocation") {
            return .memory
        } else if errorString.contains("permission") || errorString.contains("access") {
            return .system
        } else {
            return .unknown
        }
    }
    
    // MARK: - Pattern Detection
    
    private func checkErrorPatterns() {
        let recentErrors = Array(activeErrors.suffix(10))
        
        for pattern in errorPatterns {
            if pattern.condition(recentErrors) {
                logger.warning("Error pattern detected: \(pattern.name)")
                pattern.action()
            }
        }
    }
    
    // MARK: - Circuit Breaker
    
    private func updateCircuitBreaker(for key: String, success: Bool) {
        if circuitBreakers[key] == nil {
            circuitBreakers[key] = CircuitBreaker(
                threshold: configuration.circuitBreakerThreshold,
                timeout: configuration.circuitBreakerTimeout
            )
        }
        
        circuitBreakers[key]?.record(success: success)
    }
    
    // MARK: - Recovery Actions
    
    private func switchToOfflineMode() {
        logger.info("Switching to offline mode")
        NotificationCenter.default.post(name: .errorRecoveryOfflineMode, object: nil)
    }
    
    private func useAlternativeAPI() {
        logger.info("Switching to alternative API")
        NotificationCenter.default.post(name: .errorRecoveryAlternativeAPI, object: nil)
    }
    
    private func disableAudioTemporarily() {
        logger.info("Temporarily disabling audio")
        NotificationCenter.default.post(name: .errorRecoveryDisableAudio, object: nil)
        
        // Re-enable after timeout
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            NotificationCenter.default.post(name: .errorRecoveryEnableAudio, object: nil)
        }
    }
    
    private func useBasicVision() {
        logger.info("Switching to basic vision mode")
        NotificationCenter.default.post(name: .errorRecoveryBasicVision, object: nil)
    }
    
    private func handleRepeatedNetworkFailures() {
        logger.warning("Handling repeated network failures")
        
        // Increase retry delays
        configuration.retryDelay *= 2
        
        // Switch to offline mode if available
        switchToOfflineMode()
    }
    
    private func handleMemoryPressure() {
        logger.warning("Handling memory pressure")
        
        // Clear caches
        NotificationCenter.default.post(name: .errorRecoveryClearCaches, object: nil)
        
        // Reduce quality settings
        NotificationCenter.default.post(name: .errorRecoveryReduceQuality, object: nil)
    }
    
    private func handleRateLimitExceeded() {
        logger.warning("Handling rate limit exceeded")
        
        // Implement exponential backoff
        configuration.exponentialBackoff = true
        configuration.backoffMultiplier = 3.0
    }
    
    // MARK: - Error Management
    
    func removeError(_ error: RecoverableError) {
        activeErrors.removeAll { $0.id == error.id }
    }
    
    func clearErrors() {
        activeErrors.removeAll()
        recoveryAttempts = 0
    }
    
    private func recordErrorHistory(_ error: RecoverableError) {
        let entry = ErrorHistoryEntry(
            timestamp: Date(),
            error: error,
            recovered: false
        )
        
        errorHistory.append(entry)
        
        // Limit history size
        if errorHistory.count > 100 {
            errorHistory.removeFirst()
        }
    }
    
    // MARK: - Manual Recovery
    
    func retryError(_ error: RecoverableError) async -> Bool {
        return await attemptRecovery(for: error)
    }
    
    func skipError(_ error: RecoverableError) {
        removeError(error)
    }
    
    func retryAllErrors() async {
        for error in activeErrors {
            _ = await attemptRecovery(for: error)
        }
    }
    
    // MARK: - Reporting
    
    func generateErrorReport() -> ErrorReport {
        let errorsByType = Dictionary(grouping: activeErrors, by: { $0.type })
        let recoveryRate = calculateRecoveryRate()
        
        return ErrorReport(
            timestamp: Date(),
            activeErrorCount: activeErrors.count,
            totalAttempts: recoveryAttempts,
            recoveryRate: recoveryRate,
            errorsByType: errorsByType.mapValues { $0.count },
            recentErrors: Array(errorHistory.suffix(20)),
            recommendations: generateRecommendations()
        )
    }
    
    private func calculateRecoveryRate() -> Double {
        let recovered = errorHistory.filter { $0.recovered }.count
        let total = errorHistory.count
        
        return total > 0 ? Double(recovered) / Double(total) * 100 : 0
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if activeErrors.filter({ $0.type == .network }).count > 2 {
            recommendations.append("Check network connectivity")
        }
        
        if activeErrors.filter({ $0.type == .api }).count > 2 {
            recommendations.append("Verify API credentials and limits")
        }
        
        if activeErrors.filter({ $0.type == .memory }).count > 0 {
            recommendations.append("Restart the application to free memory")
        }
        
        return recommendations
    }
}

// MARK: - Recovery Strategies

protocol RecoveryStrategy {
    var name: String { get }
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool
}

struct RetryStrategy: RecoveryStrategy {
    let name = "Retry"
    let maxAttempts: Int
    let delay: TimeInterval
    let exponentialBackoff: Bool
    
    init(maxAttempts: Int = 3, delay: TimeInterval = 1.0, exponentialBackoff: Bool = false) {
        self.maxAttempts = maxAttempts
        self.delay = delay
        self.exponentialBackoff = exponentialBackoff
    }
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        // Retry the original operation
        NotificationCenter.default.post(
            name: .errorRecoveryRetry,
            object: nil,
            userInfo: ["context": error.context]
        )
        
        // Wait for result
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Check if error is resolved
        return !manager.activeErrors.contains { $0.id == error.id }
    }
}

struct FallbackStrategy: RecoveryStrategy {
    let name = "Fallback"
    let fallbackAction: () -> Void
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        fallbackAction()
        return true
    }
}

struct RestartComponentStrategy: RecoveryStrategy {
    let name = "Restart Component"
    let componentName: String
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(
            name: .errorRecoveryRestartComponent,
            object: nil,
            userInfo: ["component": componentName]
        )
        
        // Wait for restart
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        return true
    }
}

struct CircuitBreakerStrategy: RecoveryStrategy {
    let name = "Circuit Breaker"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        // Circuit breaker logic is handled in the manager
        return false
    }
}

struct RefreshTokenStrategy: RecoveryStrategy {
    let name = "Refresh Token"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(name: .errorRecoveryRefreshToken, object: nil)
        
        // Wait for token refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        return true
    }
}

struct QualityReductionStrategy: RecoveryStrategy {
    let name = "Reduce Quality"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(name: .errorRecoveryReduceQuality, object: nil)
        return true
    }
}

struct MemoryCleanupStrategy: RecoveryStrategy {
    let name = "Memory Cleanup"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(name: .errorRecoveryClearCaches, object: nil)
        
        // Force garbage collection
        autoreleasepool {
            // Cleanup
        }
        
        return true
    }
}

struct CacheClearStrategy: RecoveryStrategy {
    let name = "Clear Cache"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(name: .errorRecoveryClearCaches, object: nil)
        return true
    }
}

struct ComponentRestartStrategy: RecoveryStrategy {
    let name = "Component Restart"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(
            name: .errorRecoveryRestartComponent,
            object: nil,
            userInfo: ["component": error.context.component ?? "Unknown"]
        )
        return true
    }
}

struct PermissionRequestStrategy: RecoveryStrategy {
    let name = "Request Permission"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(name: .errorRecoveryRequestPermission, object: nil)
        
        // Wait for user response
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        return true
    }
}

struct UserInterventionStrategy: RecoveryStrategy {
    let name = "User Intervention"
    
    func execute(error: RecoverableError, manager: ErrorRecoveryManager) async -> Bool {
        NotificationCenter.default.post(
            name: .errorRecoveryUserIntervention,
            object: nil,
            userInfo: ["error": error]
        )
        
        return false // Requires user action
    }
}

// MARK: - Data Models

struct RecoverableError: Identifiable {
    let id: UUID
    let error: Error
    let type: ErrorType
    let context: ErrorContext
    let timestamp: Date
    var attemptCount: Int
    var lastAttemptTime: Date?
    var recovered: Bool = false
    
    var code: String? {
        (error as NSError).domain
    }
}

enum ErrorType: String, CaseIterable {
    case network
    case api
    case audio
    case vision
    case system
    case memory
    case unknown
}

struct ErrorContext {
    let component: String?
    let operation: String?
    let additionalInfo: [String: Any]?
}

struct ErrorPattern {
    let name: String
    let condition: ([RecoverableError]) -> Bool
    let action: () -> Void
}

class CircuitBreaker {
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let threshold: Int
    private let timeout: TimeInterval
    
    var isOpen: Bool {
        if failureCount >= threshold {
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                reset()
                return false
            }
            return true
        }
        return false
    }
    
    init(threshold: Int, timeout: TimeInterval) {
        self.threshold = threshold
        self.timeout = timeout
    }
    
    func record(success: Bool) {
        if success {
            reset()
        } else {
            failureCount += 1
            lastFailureTime = Date()
        }
    }
    
    func reset() {
        failureCount = 0
        lastFailureTime = nil
    }
}

struct ErrorHistoryEntry: Codable {
    let timestamp: Date
    let error: RecoverableError
    var recovered: Bool
}

struct ErrorReport: Codable {
    let timestamp: Date
    let activeErrorCount: Int
    let totalAttempts: Int
    let recoveryRate: Double
    let errorsByType: [ErrorType: Int]
    let recentErrors: [ErrorHistoryEntry]
    let recommendations: [String]
}

// MARK: - Notifications

extension Notification.Name {
    static let errorRecoveryRetry = Notification.Name("errorRecoveryRetry")
    static let errorRecoveryOfflineMode = Notification.Name("errorRecoveryOfflineMode")
    static let errorRecoveryAlternativeAPI = Notification.Name("errorRecoveryAlternativeAPI")
    static let errorRecoveryDisableAudio = Notification.Name("errorRecoveryDisableAudio")
    static let errorRecoveryEnableAudio = Notification.Name("errorRecoveryEnableAudio")
    static let errorRecoveryBasicVision = Notification.Name("errorRecoveryBasicVision")
    static let errorRecoveryClearCaches = Notification.Name("errorRecoveryClearCaches")
    static let errorRecoveryReduceQuality = Notification.Name("errorRecoveryReduceQuality")
    static let errorRecoveryRestartComponent = Notification.Name("errorRecoveryRestartComponent")
    static let errorRecoveryRefreshToken = Notification.Name("errorRecoveryRefreshToken")
    static let errorRecoveryRequestPermission = Notification.Name("errorRecoveryRequestPermission")
    static let errorRecoveryUserIntervention = Notification.Name("errorRecoveryUserIntervention")
}

#endif