#if os(macOS)
import Foundation
import os.log
import Combine

/// Monitors and optimizes application performance
@MainActor
class PerformanceMonitor: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "Performance")
    
    // MARK: - Published Properties
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var diskUsage: Double = 0.0
    @Published var networkLatency: Double = 0.0
    @Published var fps: Double = 60.0
    @Published var isOptimizing = false
    @Published var performanceScore: Double = 100.0
    @Published var alerts: [PerformanceAlert] = []
    
    // MARK: - Metrics
    private var metrics = PerformanceMetrics()
    private var historicalData: [PerformanceSnapshot] = []
    private var componentMetrics: [String: ComponentMetrics] = [:]
    
    // MARK: - Monitoring
    private var monitoringTimer: Timer?
    private var metricsCollector: MetricsCollector?
    private let updateInterval: TimeInterval = 1.0
    private var isMonitoring = false
    
    // MARK: - Thresholds
    struct Thresholds {
        var cpuWarning: Double = 70.0
        var cpuCritical: Double = 90.0
        var memoryWarning: Double = 80.0
        var memoryCritical: Double = 95.0
        var responseTimeWarning: Double = 1000.0 // ms
        var responseTimeCritical: Double = 3000.0 // ms
        var fpsWarning: Double = 30.0
        var fpsCritical: Double = 15.0
    }
    
    var thresholds = Thresholds()
    
    // MARK: - Optimization Settings
    var autoOptimize = true
    var adaptiveQuality = true
    var powerSaveMode = false
    var backgroundThrottling = true
    
    init() {
        metricsCollector = MetricsCollector()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("Starting performance monitoring")
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updateMetrics()
            }
        }
        
        // Start component-specific monitoring
        startComponentMonitoring()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        logger.info("Stopping performance monitoring")
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        stopComponentMonitoring()
    }
    
    // MARK: - Metrics Collection
    
    private func updateMetrics() {
        // Collect system metrics
        cpuUsage = metricsCollector?.getCPUUsage() ?? 0.0
        memoryUsage = metricsCollector?.getMemoryUsage() ?? 0.0
        diskUsage = metricsCollector?.getDiskUsage() ?? 0.0
        networkLatency = metricsCollector?.getNetworkLatency() ?? 0.0
        
        // Update performance metrics
        metrics.update(
            cpu: cpuUsage,
            memory: memoryUsage,
            disk: diskUsage,
            network: networkLatency,
            fps: fps
        )
        
        // Calculate performance score
        performanceScore = calculatePerformanceScore()
        
        // Store snapshot
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            cpu: cpuUsage,
            memory: memoryUsage,
            disk: diskUsage,
            network: networkLatency,
            fps: fps,
            score: performanceScore
        )
        
        historicalData.append(snapshot)
        
        // Limit historical data
        if historicalData.count > 3600 { // Keep 1 hour at 1-second intervals
            historicalData.removeFirst()
        }
        
        // Check for issues
        checkPerformanceIssues()
        
        // Auto-optimize if enabled
        if autoOptimize && performanceScore < 70 {
            Task {
                await optimizePerformance()
            }
        }
    }
    
    private func calculatePerformanceScore() -> Double {
        var score = 100.0
        
        // CPU impact (30% weight)
        if cpuUsage > thresholds.cpuCritical {
            score -= 30
        } else if cpuUsage > thresholds.cpuWarning {
            score -= 15
        }
        
        // Memory impact (30% weight)
        if memoryUsage > thresholds.memoryCritical {
            score -= 30
        } else if memoryUsage > thresholds.memoryWarning {
            score -= 15
        }
        
        // FPS impact (20% weight)
        if fps < thresholds.fpsCritical {
            score -= 20
        } else if fps < thresholds.fpsWarning {
            score -= 10
        }
        
        // Network impact (10% weight)
        if networkLatency > thresholds.responseTimeCritical {
            score -= 10
        } else if networkLatency > thresholds.responseTimeWarning {
            score -= 5
        }
        
        // Disk impact (10% weight)
        if diskUsage > 90 {
            score -= 10
        } else if diskUsage > 80 {
            score -= 5
        }
        
        return max(0, score)
    }
    
    // MARK: - Component Monitoring
    
    private func startComponentMonitoring() {
        // Monitor individual components
        componentMetrics["AudioManager"] = ComponentMetrics(name: "AudioManager")
        componentMetrics["VisionManager"] = ComponentMetrics(name: "VisionManager")
        componentMetrics["AIProvider"] = ComponentMetrics(name: "AIProvider")
        componentMetrics["SystemController"] = ComponentMetrics(name: "SystemController")
        componentMetrics["ScreenManager"] = ComponentMetrics(name: "ScreenManager")
    }
    
    private func stopComponentMonitoring() {
        componentMetrics.removeAll()
    }
    
    func recordComponentMetric(_ component: String, operation: String, duration: TimeInterval, success: Bool = true) {
        guard var metrics = componentMetrics[component] else { return }
        
        metrics.recordOperation(operation: operation, duration: duration, success: success)
        componentMetrics[component] = metrics
        
        // Log slow operations
        if duration > 1.0 {
            logger.warning("\(component).\(operation) took \(duration)s")
        }
    }
    
    // MARK: - Performance Issues
    
    private func checkPerformanceIssues() {
        var newAlerts: [PerformanceAlert] = []
        
        // Check CPU
        if cpuUsage > thresholds.cpuCritical {
            newAlerts.append(PerformanceAlert(
                type: .cpu,
                severity: .critical,
                message: "Critical CPU usage: \(Int(cpuUsage))%",
                timestamp: Date()
            ))
        } else if cpuUsage > thresholds.cpuWarning {
            newAlerts.append(PerformanceAlert(
                type: .cpu,
                severity: .warning,
                message: "High CPU usage: \(Int(cpuUsage))%",
                timestamp: Date()
            ))
        }
        
        // Check Memory
        if memoryUsage > thresholds.memoryCritical {
            newAlerts.append(PerformanceAlert(
                type: .memory,
                severity: .critical,
                message: "Critical memory usage: \(Int(memoryUsage))%",
                timestamp: Date()
            ))
        } else if memoryUsage > thresholds.memoryWarning {
            newAlerts.append(PerformanceAlert(
                type: .memory,
                severity: .warning,
                message: "High memory usage: \(Int(memoryUsage))%",
                timestamp: Date()
            ))
        }
        
        // Check FPS
        if fps < thresholds.fpsCritical {
            newAlerts.append(PerformanceAlert(
                type: .rendering,
                severity: .critical,
                message: "Critical frame rate: \(Int(fps)) FPS",
                timestamp: Date()
            ))
        }
        
        // Update alerts
        alerts = newAlerts
    }
    
    // MARK: - Performance Optimization
    
    func optimizePerformance() async {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        defer { isOptimizing = false }
        
        logger.info("Starting performance optimization")
        
        // Analyze performance bottlenecks
        let bottlenecks = analyzeBottlenecks()
        
        // Apply optimizations based on bottlenecks
        for bottleneck in bottlenecks {
            await applyOptimization(for: bottleneck)
        }
        
        // Clean up resources
        cleanupResources()
        
        // Adjust quality settings if needed
        if adaptiveQuality {
            adjustQualitySettings()
        }
        
        logger.info("Performance optimization completed")
    }
    
    private func analyzeBottlenecks() -> [PerformanceBottleneck] {
        var bottlenecks: [PerformanceBottleneck] = []
        
        // Analyze CPU bottlenecks
        if cpuUsage > thresholds.cpuWarning {
            bottlenecks.append(.highCPU(usage: cpuUsage))
        }
        
        // Analyze memory bottlenecks
        if memoryUsage > thresholds.memoryWarning {
            bottlenecks.append(.highMemory(usage: memoryUsage))
        }
        
        // Analyze component bottlenecks
        for (name, metrics) in componentMetrics {
            if metrics.averageResponseTime > 500 {
                bottlenecks.append(.slowComponent(name: name, responseTime: metrics.averageResponseTime))
            }
        }
        
        // Analyze rendering bottlenecks
        if fps < thresholds.fpsWarning {
            bottlenecks.append(.lowFrameRate(fps: fps))
        }
        
        return bottlenecks
    }
    
    private func applyOptimization(for bottleneck: PerformanceBottleneck) async {
        switch bottleneck {
        case .highCPU:
            // Reduce CPU-intensive operations
            await reduceCPULoad()
            
        case .highMemory:
            // Free up memory
            await freeMemory()
            
        case .slowComponent(let name, _):
            // Optimize specific component
            await optimizeComponent(name)
            
        case .lowFrameRate:
            // Reduce rendering complexity
            await optimizeRendering()
            
        case .networkLatency:
            // Optimize network requests
            await optimizeNetwork()
        }
    }
    
    private func reduceCPULoad() async {
        logger.info("Reducing CPU load")
        
        // Reduce update frequencies
        NotificationCenter.default.post(name: .performanceReduceCPULoad, object: nil)
        
        // Enable power save mode
        if !powerSaveMode {
            powerSaveMode = true
        }
    }
    
    private func freeMemory() async {
        logger.info("Freeing memory")
        
        // Clear caches
        NotificationCenter.default.post(name: .performanceClearCaches, object: nil)
        
        // Reduce historical data
        if historicalData.count > 600 {
            let keepCount = 600
            historicalData = Array(historicalData.suffix(keepCount))
        }
    }
    
    private func optimizeComponent(_ name: String) async {
        logger.info("Optimizing component: \(name)")
        
        // Send optimization request to component
        NotificationCenter.default.post(
            name: .performanceOptimizeComponent,
            object: nil,
            userInfo: ["component": name]
        )
    }
    
    private func optimizeRendering() async {
        logger.info("Optimizing rendering")
        
        // Reduce visual effects
        NotificationCenter.default.post(name: .performanceReduceVisualEffects, object: nil)
    }
    
    private func optimizeNetwork() async {
        logger.info("Optimizing network")
        
        // Implement request batching
        NotificationCenter.default.post(name: .performanceOptimizeNetwork, object: nil)
    }
    
    private func cleanupResources() {
        // Trigger garbage collection
        autoreleasepool {
            // Force cleanup of autoreleased objects
        }
    }
    
    private func adjustQualitySettings() {
        let qualityLevel: QualityLevel
        
        if performanceScore > 90 {
            qualityLevel = .high
        } else if performanceScore > 70 {
            qualityLevel = .medium
        } else {
            qualityLevel = .low
        }
        
        NotificationCenter.default.post(
            name: .performanceQualityChanged,
            object: nil,
            userInfo: ["quality": qualityLevel]
        )
    }
    
    // MARK: - Reporting
    
    func generatePerformanceReport() -> PerformanceReport {
        let averages = calculateAverages()
        let peaks = findPeaks()
        
        return PerformanceReport(
            timestamp: Date(),
            averageCPU: averages.cpu,
            averageMemory: averages.memory,
            averageFPS: averages.fps,
            peakCPU: peaks.cpu,
            peakMemory: peaks.memory,
            lowestFPS: peaks.fps,
            totalAlerts: alerts.count,
            componentMetrics: componentMetrics,
            recommendations: generateRecommendations()
        )
    }
    
    private func calculateAverages() -> (cpu: Double, memory: Double, fps: Double) {
        guard !historicalData.isEmpty else {
            return (0, 0, 60)
        }
        
        let cpu = historicalData.map { $0.cpu }.reduce(0, +) / Double(historicalData.count)
        let memory = historicalData.map { $0.memory }.reduce(0, +) / Double(historicalData.count)
        let fps = historicalData.map { $0.fps }.reduce(0, +) / Double(historicalData.count)
        
        return (cpu, memory, fps)
    }
    
    private func findPeaks() -> (cpu: Double, memory: Double, fps: Double) {
        guard !historicalData.isEmpty else {
            return (0, 0, 60)
        }
        
        let cpu = historicalData.map { $0.cpu }.max() ?? 0
        let memory = historicalData.map { $0.memory }.max() ?? 0
        let fps = historicalData.map { $0.fps }.min() ?? 60
        
        return (cpu, memory, fps)
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if cpuUsage > thresholds.cpuWarning {
            recommendations.append("Consider reducing the number of active features")
        }
        
        if memoryUsage > thresholds.memoryWarning {
            recommendations.append("Clear unused data and caches")
        }
        
        if fps < thresholds.fpsWarning {
            recommendations.append("Reduce visual effects or screen capture quality")
        }
        
        if networkLatency > thresholds.responseTimeWarning {
            recommendations.append("Check network connection or use local AI models")
        }
        
        return recommendations
    }
    
    // MARK: - Export
    
    func exportMetrics(to url: URL) throws {
        let data = PerformanceExport(
            snapshots: historicalData,
            componentMetrics: componentMetrics,
            alerts: alerts,
            report: generatePerformanceReport()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let jsonData = try encoder.encode(data)
        try jsonData.write(to: url)
    }
}

// MARK: - Metrics Collector

class MetricsCollector {
    private var processInfo = ProcessInfo.processInfo
    private var lastCPUInfo: host_cpu_load_info?
    private var lastNetworkCheck = Date()
    
    func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / Double(1024 * 1024) // Convert to MB
        }
        
        return 0.0
    }
    
    func getMemoryUsage() -> Double {
        let totalMemory = processInfo.physicalMemory
        
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            return (usedMemory / Double(totalMemory)) * 100.0
        }
        
        return 0.0
    }
    
    func getDiskUsage() -> Double {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let totalSpace = attributes[.systemSize] as? NSNumber,
           let freeSpace = attributes[.systemFreeSize] as? NSNumber {
            
            let usedSpace = totalSpace.doubleValue - freeSpace.doubleValue
            return (usedSpace / totalSpace.doubleValue) * 100.0
        }
        
        return 0.0
    }
    
    func getNetworkLatency() -> Double {
        // Simple ping-like measurement
        let start = Date()
        
        // Simulate network check
        if Date().timeIntervalSince(lastNetworkCheck) > 5.0 {
            lastNetworkCheck = Date()
            // In real implementation, would ping a server
        }
        
        return Date().timeIntervalSince(start) * 1000 // Convert to ms
    }
}

// MARK: - Data Models

struct PerformanceMetrics {
    var cpuUsage: Double = 0.0
    var memoryUsage: Double = 0.0
    var diskUsage: Double = 0.0
    var networkLatency: Double = 0.0
    var frameRate: Double = 60.0
    var responseTime: Double = 0.0
    
    mutating func update(cpu: Double, memory: Double, disk: Double, network: Double, fps: Double) {
        cpuUsage = cpu
        memoryUsage = memory
        diskUsage = disk
        networkLatency = network
        frameRate = fps
    }
}

struct PerformanceSnapshot: Codable {
    let timestamp: Date
    let cpu: Double
    let memory: Double
    let disk: Double
    let network: Double
    let fps: Double
    let score: Double
}

struct ComponentMetrics: Codable {
    let name: String
    var operationCount: Int = 0
    var totalDuration: TimeInterval = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var slowOperations: [(operation: String, duration: TimeInterval)] = []
    
    var averageResponseTime: TimeInterval {
        operationCount > 0 ? totalDuration / Double(operationCount) : 0
    }
    
    var successRate: Double {
        let total = successCount + failureCount
        return total > 0 ? Double(successCount) / Double(total) * 100 : 100
    }
    
    mutating func recordOperation(operation: String, duration: TimeInterval, success: Bool) {
        operationCount += 1
        totalDuration += duration
        
        if success {
            successCount += 1
        } else {
            failureCount += 1
        }
        
        if duration > 1.0 {
            slowOperations.append((operation, duration))
            if slowOperations.count > 10 {
                slowOperations.removeFirst()
            }
        }
    }
}

struct PerformanceAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let severity: Severity
    let message: String
    let timestamp: Date
    
    enum AlertType {
        case cpu, memory, disk, network, rendering, component
    }
    
    enum Severity {
        case info, warning, critical
    }
}

enum PerformanceBottleneck {
    case highCPU(usage: Double)
    case highMemory(usage: Double)
    case slowComponent(name: String, responseTime: TimeInterval)
    case lowFrameRate(fps: Double)
    case networkLatency(latency: Double)
}

enum QualityLevel: String, Codable {
    case low, medium, high
}

struct PerformanceReport: Codable {
    let timestamp: Date
    let averageCPU: Double
    let averageMemory: Double
    let averageFPS: Double
    let peakCPU: Double
    let peakMemory: Double
    let lowestFPS: Double
    let totalAlerts: Int
    let componentMetrics: [String: ComponentMetrics]
    let recommendations: [String]
}

struct PerformanceExport: Codable {
    let snapshots: [PerformanceSnapshot]
    let componentMetrics: [String: ComponentMetrics]
    let alerts: [PerformanceAlert]
    let report: PerformanceReport
}

// MARK: - Notifications

extension Notification.Name {
    static let performanceReduceCPULoad = Notification.Name("performanceReduceCPULoad")
    static let performanceClearCaches = Notification.Name("performanceClearCaches")
    static let performanceOptimizeComponent = Notification.Name("performanceOptimizeComponent")
    static let performanceReduceVisualEffects = Notification.Name("performanceReduceVisualEffects")
    static let performanceOptimizeNetwork = Notification.Name("performanceOptimizeNetwork")
    static let performanceQualityChanged = Notification.Name("performanceQualityChanged")
}

#endif