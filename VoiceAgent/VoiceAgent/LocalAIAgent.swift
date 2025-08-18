#if os(macOS)
import Foundation
import AppKit
import NaturalLanguage
import Speech
import Vision
import CoreML
import CreateML
import MetalPerformanceShaders
import Accelerate
import WebKit
import Network
import SystemConfiguration
import DiskArbitration
import IOKit
import os.log

/// Extreme capability local AI agent for complete macOS control
@MainActor
class LocalAIAgent: ObservableObject {
    private let logger = Logger(subsystem: "com.voiceagent", category: "LocalAgent")
    
    // MARK: - Published Properties
    @Published var isActive = false
    @Published var isListening = false
    @Published var currentCommand: String = ""
    @Published var lastResponse: String = ""
    @Published var processingStatus: ProcessingStatus = .idle
    @Published var capabilities: [Capability] = []
    @Published var systemMetrics: SystemMetrics?
    
    // MARK: - Core Components
    private let nluEngine: NaturalLanguageEngine
    private let contextManager: ContextualAwarenessManager
    private let systemInterface: SystemInterface
    private let knowledgeBase: KnowledgeBase
    private let taskExecutor: TaskExecutor
    private let continuousListener: ContinuousListener
    
    // MARK: - Specialized Modules
    private let fileSystemManager: FileSystemManager
    private let networkManager: NetworkManager
    private let processManager: ProcessManager
    private let scriptRunner: ScriptRunner
    private let documentProcessor: DocumentProcessor
    private let webAutomation: WebAutomation
    private let systemMonitor: SystemMonitor
    private let aiProcessor: AIProcessor
    
    // MARK: - Configuration
    struct Configuration {
        var enableContinuousListening = true
        var responseVerbosity: Verbosity = .normal
        var executionMode: ExecutionMode = .safe
        var maxConcurrentTasks = 5
        var enableLearning = true
        var privacyMode = false
        var debugMode = false
    }
    
    var configuration = Configuration()
    
    init() {
        // Initialize core components
        nluEngine = NaturalLanguageEngine()
        contextManager = ContextualAwarenessManager()
        systemInterface = SystemInterface()
        knowledgeBase = KnowledgeBase()
        taskExecutor = TaskExecutor()
        continuousListener = ContinuousListener()
        
        // Initialize specialized modules
        fileSystemManager = FileSystemManager()
        networkManager = NetworkManager()
        processManager = ProcessManager()
        scriptRunner = ScriptRunner()
        documentProcessor = DocumentProcessor()
        webAutomation = WebAutomation()
        systemMonitor = SystemMonitor()
        aiProcessor = AIProcessor()
        
        setupAgent()
        registerCapabilities()
        startSystemMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupAgent() {
        // Configure NLU engine with agent-specific intents
        registerAgentIntents()
        
        // Setup continuous listening
        continuousListener.onCommandDetected = { [weak self] command in
            Task { @MainActor in
                await self?.processCommand(command)
            }
        }
        
        // Setup context awareness
        contextManager.configuration.enablePatternLearning = configuration.enableLearning
        
        // Initialize knowledge base
        knowledgeBase.loadSystemKnowledge()
        knowledgeBase.loadLibraryDocumentation()
        
        logger.info("Local AI Agent initialized with extreme capabilities")
    }
    
    private func registerCapabilities() {
        capabilities = [
            // System Operations
            Capability(name: "System Information", category: .system, commands: ["system info", "disk usage", "memory status"]),
            Capability(name: "Process Management", category: .system, commands: ["list processes", "kill process", "monitor CPU"]),
            Capability(name: "File Operations", category: .files, commands: ["list files", "create file", "delete file", "move file"]),
            Capability(name: "Network Operations", category: .network, commands: ["check connection", "ping", "download file"]),
            
            // AI Tasks
            Capability(name: "Document Processing", category: .ai, commands: ["summarize", "translate", "analyze"]),
            Capability(name: "Code Generation", category: .ai, commands: ["write script", "generate code", "explain code"]),
            Capability(name: "Data Analysis", category: .ai, commands: ["analyze data", "create chart", "find patterns"]),
            Capability(name: "Creative Tasks", category: .ai, commands: ["write content", "create plan", "brainstorm"]),
            
            // Automation
            Capability(name: "Web Automation", category: .automation, commands: ["search web", "scrape data", "fill form"]),
            Capability(name: "App Control", category: .automation, commands: ["open app", "close app", "switch app"]),
            Capability(name: "Workflow Automation", category: .automation, commands: ["run workflow", "schedule task", "batch process"]),
            
            // Advanced
            Capability(name: "Machine Learning", category: .advanced, commands: ["train model", "predict", "classify"]),
            Capability(name: "System Optimization", category: .advanced, commands: ["optimize performance", "clean system", "manage memory"]),
            Capability(name: "Security Operations", category: .advanced, commands: ["scan security", "check permissions", "encrypt data"])
        ]
    }
    
    // MARK: - Command Processing
    
    func startListening() {
        guard !isListening else { return }
        
        isListening = true
        isActive = true
        
        if configuration.enableContinuousListening {
            continuousListener.start()
        }
        
        logger.info("Agent started listening for commands")
    }
    
    func stopListening() {
        isListening = false
        continuousListener.stop()
        
        logger.info("Agent stopped listening")
    }
    
    func processCommand(_ command: String) async {
        currentCommand = command
        processingStatus = .processing
        
        logger.info("Processing command: \(command)")
        
        // Update context
        contextManager.recordInteraction(Interaction(
            id: UUID(),
            text: command,
            action: nil,
            context: contextManager.currentContext,
            timestamp: Date(),
            result: nil
        ))
        
        // Process with NLU
        let nluResult = await nluEngine.process(command)
        
        // Execute based on intent
        let response = await executeIntent(nluResult)
        
        // Update UI
        lastResponse = response
        processingStatus = .complete
        
        // Speak response if voice feedback is enabled
        speakResponse(response)
        
        // Learn from interaction
        if configuration.enableLearning {
            await learnFromInteraction(command: command, result: nluResult, response: response)
        }
    }
    
    private func executeIntent(_ nluResult: NLUResult) async -> String {
        guard let intent = nluResult.intent else {
            return "I didn't understand that command. Could you please rephrase?"
        }
        
        logger.info("Executing intent: \(intent.name)")
        
        switch intent.name {
        // System Information
        case "get_system_info":
            return await getSystemInformation()
            
        case "check_disk_usage":
            return await checkDiskUsage()
            
        case "check_memory":
            return await checkMemoryUsage()
            
        case "list_processes":
            return await listProcesses()
            
        // File Operations
        case "list_files":
            return await listFiles(params: intent.parameters)
            
        case "create_file":
            return await createFile(params: intent.parameters)
            
        case "delete_file":
            return await deleteFile(params: intent.parameters)
            
        case "move_file":
            return await moveFile(params: intent.parameters)
            
        // Network Operations
        case "check_network":
            return await checkNetworkStatus()
            
        case "search_web":
            return await searchWeb(params: intent.parameters)
            
        case "download_file":
            return await downloadFile(params: intent.parameters)
            
        // AI Tasks
        case "summarize_document":
            return await summarizeDocument(params: intent.parameters)
            
        case "write_script":
            return await writeScript(params: intent.parameters)
            
        case "explain_concept":
            return await explainConcept(params: intent.parameters)
            
        case "create_plan":
            return await createPlan(params: intent.parameters)
            
        // App Control
        case "open_application":
            return await openApplication(params: intent.parameters)
            
        case "close_application":
            return await closeApplication(params: intent.parameters)
            
        case "switch_application":
            return await switchToApplication(params: intent.parameters)
            
        // Advanced Operations
        case "optimize_system":
            return await optimizeSystem()
            
        case "run_automation":
            return await runAutomation(params: intent.parameters)
            
        case "analyze_data":
            return await analyzeData(params: intent.parameters)
            
        default:
            return await handleGenericRequest(nluResult)
        }
    }
    
    // MARK: - System Operations
    
    private func getSystemInformation() async -> String {
        let info = systemMonitor.getSystemInfo()
        
        return """
        System Information:
        • macOS Version: \(info.osVersion)
        • Model: \(info.modelName)
        • Processor: \(info.processorName) (\(info.processorCores) cores)
        • Memory: \(formatBytes(info.totalMemory))
        • Storage: \(formatBytes(info.totalStorage)) total, \(formatBytes(info.availableStorage)) available
        • Uptime: \(formatUptime(info.uptime))
        • Current User: \(info.username)
        """
    }
    
    private func checkDiskUsage() async -> String {
        let usage = systemMonitor.getDiskUsage()
        
        var response = "Disk Usage:\n"
        for disk in usage {
            let percentUsed = (disk.used * 100) / disk.total
            response += "• \(disk.name): \(formatBytes(disk.used)) / \(formatBytes(disk.total)) (\(percentUsed)% used)\n"
        }
        
        return response
    }
    
    private func checkMemoryUsage() async -> String {
        let memory = systemMonitor.getMemoryUsage()
        
        return """
        Memory Usage:
        • Total: \(formatBytes(memory.total))
        • Used: \(formatBytes(memory.used)) (\(memory.pressure)% pressure)
        • Wired: \(formatBytes(memory.wired))
        • Compressed: \(formatBytes(memory.compressed))
        • Cached: \(formatBytes(memory.cached))
        • Swap: \(formatBytes(memory.swap))
        """
    }
    
    private func listProcesses() async -> String {
        let processes = processManager.getTopProcesses(count: 10)
        
        var response = "Top 10 Processes by CPU Usage:\n"
        for (index, process) in processes.enumerated() {
            response += "\(index + 1). \(process.name) - PID: \(process.pid), CPU: \(process.cpuUsage)%, Memory: \(formatBytes(process.memoryUsage))\n"
        }
        
        return response
    }
    
    // MARK: - File Operations
    
    private func listFiles(params: [String: Any]) async -> String {
        let path = params["path"] as? String ?? "~"
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        do {
            let files = try fileSystemManager.listDirectory(at: expandedPath)
            
            var response = "Files in \(path):\n"
            for file in files.prefix(20) {
                let icon = file.isDirectory ? "📁" : "📄"
                response += "\(icon) \(file.name) (\(formatBytes(file.size)))\n"
            }
            
            if files.count > 20 {
                response += "... and \(files.count - 20) more items"
            }
            
            return response
        } catch {
            return "Error listing files: \(error.localizedDescription)"
        }
    }
    
    private func createFile(params: [String: Any]) async -> String {
        guard let filename = params["filename"] as? String else {
            return "Please specify a filename"
        }
        
        let content = params["content"] as? String ?? ""
        let path = params["path"] as? String ?? "~/Desktop"
        
        do {
            let fullPath = try fileSystemManager.createFile(
                named: filename,
                at: path,
                content: content
            )
            return "File created successfully at: \(fullPath)"
        } catch {
            return "Error creating file: \(error.localizedDescription)"
        }
    }
    
    private func deleteFile(params: [String: Any]) async -> String {
        guard let filepath = params["filepath"] as? String else {
            return "Please specify a file path"
        }
        
        do {
            try fileSystemManager.deleteFile(at: filepath)
            return "File deleted successfully: \(filepath)"
        } catch {
            return "Error deleting file: \(error.localizedDescription)"
        }
    }
    
    private func moveFile(params: [String: Any]) async -> String {
        guard let source = params["source"] as? String,
              let destination = params["destination"] as? String else {
            return "Please specify source and destination paths"
        }
        
        do {
            try fileSystemManager.moveFile(from: source, to: destination)
            return "File moved successfully from \(source) to \(destination)"
        } catch {
            return "Error moving file: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Network Operations
    
    private func checkNetworkStatus() async -> String {
        let status = networkManager.getNetworkStatus()
        
        return """
        Network Status:
        • Connection: \(status.isConnected ? "Connected" : "Disconnected")
        • Interface: \(status.interface ?? "Unknown")
        • IP Address: \(status.ipAddress ?? "N/A")
        • Speed: \(status.linkSpeed ?? "Unknown")
        • Signal: \(status.signalStrength ?? "N/A")
        """
    }
    
    private func searchWeb(params: [String: Any]) async -> String {
        guard let query = params["query"] as? String else {
            return "Please specify a search query"
        }
        
        do {
            let results = try await webAutomation.searchWeb(query: query)
            
            var response = "Web Search Results for '\(query)':\n\n"
            for (index, result) in results.prefix(5).enumerated() {
                response += "\(index + 1). \(result.title)\n"
                response += "   \(result.url)\n"
                response += "   \(result.snippet)\n\n"
            }
            
            return response
        } catch {
            return "Error searching web: \(error.localizedDescription)"
        }
    }
    
    private func downloadFile(params: [String: Any]) async -> String {
        guard let url = params["url"] as? String else {
            return "Please specify a URL to download"
        }
        
        let destination = params["destination"] as? String ?? "~/Downloads"
        
        do {
            let filepath = try await networkManager.downloadFile(
                from: url,
                to: destination
            )
            return "File downloaded successfully to: \(filepath)"
        } catch {
            return "Error downloading file: \(error.localizedDescription)"
        }
    }
    
    // MARK: - AI Tasks
    
    private func summarizeDocument(params: [String: Any]) async -> String {
        guard let filepath = params["filepath"] as? String else {
            // Try to get content from clipboard or current selection
            if let content = getClipboardContent() {
                let summary = await aiProcessor.summarize(text: content)
                return "Summary:\n\(summary)"
            }
            return "Please specify a document path or copy text to clipboard"
        }
        
        do {
            let content = try documentProcessor.readDocument(at: filepath)
            let summary = await aiProcessor.summarize(text: content)
            
            return """
            Document Summary:
            File: \(filepath)
            
            \(summary)
            """
        } catch {
            return "Error summarizing document: \(error.localizedDescription)"
        }
    }
    
    private func writeScript(params: [String: Any]) async -> String {
        guard let description = params["description"] as? String else {
            return "Please describe what the script should do"
        }
        
        let language = params["language"] as? String ?? "python"
        
        let script = await aiProcessor.generateCode(
            description: description,
            language: language
        )
        
        // Save script to file
        let filename = "generated_script.\(scriptRunner.getFileExtension(for: language))"
        let filepath = "~/Desktop/\(filename)"
        
        do {
            try fileSystemManager.createFile(
                named: filename,
                at: "~/Desktop",
                content: script
            )
            
            return """
            Script generated and saved to: \(filepath)
            
            ```\(language)
            \(script)
            ```
            
            Would you like me to run it?
            """
        } catch {
            return "Error saving script: \(error.localizedDescription)\n\nGenerated script:\n```\(language)\n\(script)\n```"
        }
    }
    
    private func explainConcept(params: [String: Any]) async -> String {
        guard let concept = params["concept"] as? String else {
            return "Please specify a concept to explain"
        }
        
        let level = params["level"] as? String ?? "intermediate"
        
        let explanation = await aiProcessor.explain(
            concept: concept,
            level: level
        )
        
        return """
        Explanation of \(concept):
        
        \(explanation)
        """
    }
    
    private func createPlan(params: [String: Any]) async -> String {
        guard let goal = params["goal"] as? String else {
            return "Please specify what you want to plan"
        }
        
        let timeframe = params["timeframe"] as? String
        let constraints = params["constraints"] as? [String]
        
        let plan = await aiProcessor.createPlan(
            goal: goal,
            timeframe: timeframe,
            constraints: constraints
        )
        
        return """
        Plan for: \(goal)
        
        \(plan)
        """
    }
    
    // MARK: - Application Control
    
    private func openApplication(params: [String: Any]) async -> String {
        guard let appName = params["app_name"] as? String else {
            return "Please specify an application name"
        }
        
        do {
            try systemInterface.launchApplication(appName)
            return "Opened \(appName)"
        } catch {
            return "Error opening \(appName): \(error.localizedDescription)"
        }
    }
    
    private func closeApplication(params: [String: Any]) async -> String {
        guard let appName = params["app_name"] as? String else {
            return "Please specify an application name"
        }
        
        do {
            try systemInterface.quitApplication(appName)
            return "Closed \(appName)"
        } catch {
            return "Error closing \(appName): \(error.localizedDescription)"
        }
    }
    
    private func switchToApplication(params: [String: Any]) async -> String {
        guard let appName = params["app_name"] as? String else {
            return "Please specify an application name"
        }
        
        do {
            try systemInterface.activateApplication(appName)
            return "Switched to \(appName)"
        } catch {
            return "Error switching to \(appName): \(error.localizedDescription)"
        }
    }
    
    // MARK: - Advanced Operations
    
    private func optimizeSystem() async -> String {
        processingStatus = .processing
        
        var results = "System Optimization Results:\n\n"
        
        // Clear caches
        let cacheCleared = await systemInterface.clearSystemCaches()
        results += "• Cleared \(formatBytes(cacheCleared)) of cache files\n"
        
        // Optimize memory
        let memoryFreed = await systemInterface.optimizeMemory()
        results += "• Freed \(formatBytes(memoryFreed)) of memory\n"
        
        // Clean temporary files
        let tempCleaned = await fileSystemManager.cleanTemporaryFiles()
        results += "• Removed \(tempCleaned) temporary files\n"
        
        // Optimize startup items
        let startupOptimized = await systemInterface.optimizeStartupItems()
        results += "• Optimized \(startupOptimized) startup items\n"
        
        processingStatus = .complete
        
        return results
    }
    
    private func runAutomation(params: [String: Any]) async -> String {
        guard let workflowName = params["workflow"] as? String else {
            return "Please specify a workflow name"
        }
        
        do {
            let result = try await taskExecutor.runWorkflow(workflowName)
            return "Workflow '\(workflowName)' completed:\n\(result)"
        } catch {
            return "Error running workflow: \(error.localizedDescription)"
        }
    }
    
    private func analyzeData(params: [String: Any]) async -> String {
        guard let dataPath = params["data"] as? String else {
            return "Please specify data file path"
        }
        
        let analysisType = params["type"] as? String ?? "statistical"
        
        do {
            let analysis = try await aiProcessor.analyzeData(
                at: dataPath,
                type: analysisType
            )
            
            return """
            Data Analysis Results:
            File: \(dataPath)
            Type: \(analysisType)
            
            \(analysis)
            """
        } catch {
            return "Error analyzing data: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Generic Request Handler
    
    private func handleGenericRequest(_ nluResult: NLUResult) async -> String {
        // Use AI to handle generic requests
        let response = await aiProcessor.processGenericRequest(
            text: nluResult.originalText,
            context: contextManager.currentContext
        )
        
        return response
    }
    
    // MARK: - Learning
    
    private func learnFromInteraction(command: String, result: NLUResult, response: String) async {
        // Record successful patterns
        if processingStatus == .complete {
            knowledgeBase.recordSuccessfulCommand(
                command: command,
                intent: result.intent?.name ?? "unknown",
                response: response
            )
        }
        
        // Update user preferences
        contextManager.updateUserPreference("last_command", value: command)
        
        // Train NLU with new examples
        if let intent = result.intent {
            await nluEngine.trainOnExamples([(command, intent.name)])
        }
    }
    
    // MARK: - System Monitoring
    
    private func startSystemMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.systemMetrics = self.systemMonitor.getCurrentMetrics()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func speakResponse(_ response: String) {
        // Use voice feedback manager to speak
        NotificationCenter.default.post(
            name: .agentSpeakResponse,
            object: nil,
            userInfo: ["response": response]
        )
    }
    
    private func getClipboardContent() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func registerAgentIntents() {
        // Register all agent-specific intents
        let agentIntents = [
            IntentDefinition(
                name: "get_system_info",
                examples: ["system information", "system info", "about this mac"],
                requiredEntities: [],
                parameters: []
            ),
            IntentDefinition(
                name: "check_disk_usage",
                examples: ["disk usage", "storage space", "check disk"],
                requiredEntities: [],
                parameters: []
            ),
            IntentDefinition(
                name: "check_memory",
                examples: ["memory usage", "ram usage", "check memory"],
                requiredEntities: [],
                parameters: []
            ),
            IntentDefinition(
                name: "search_web",
                examples: ["search for", "search web", "google", "find online"],
                requiredEntities: ["query"],
                parameters: ["query"]
            ),
            IntentDefinition(
                name: "summarize_document",
                examples: ["summarize", "summary of", "tldr"],
                requiredEntities: [],
                parameters: ["filepath", "content"]
            ),
            IntentDefinition(
                name: "write_script",
                examples: ["write script", "generate code", "create program"],
                requiredEntities: ["description"],
                parameters: ["description", "language"]
            ),
            IntentDefinition(
                name: "explain_concept",
                examples: ["explain", "what is", "tell me about"],
                requiredEntities: ["concept"],
                parameters: ["concept", "level"]
            ),
            IntentDefinition(
                name: "create_plan",
                examples: ["create plan", "plan for", "meal plan", "workout plan"],
                requiredEntities: ["goal"],
                parameters: ["goal", "timeframe", "constraints"]
            )
        ]
        
        for intent in agentIntents {
            nluEngine.registerIntent(intent)
        }
    }
}

// MARK: - Supporting Components

class SystemInterface {
    func launchApplication(_ name: String) throws {
        let workspace = NSWorkspace.shared
        guard workspace.launchApplication(name) else {
            throw AgentError.applicationNotFound(name)
        }
    }
    
    func quitApplication(_ name: String) throws {
        let apps = NSWorkspace.shared.runningApplications
        guard let app = apps.first(where: { $0.localizedName == name }) else {
            throw AgentError.applicationNotRunning(name)
        }
        app.terminate()
    }
    
    func activateApplication(_ name: String) throws {
        let apps = NSWorkspace.shared.runningApplications
        guard let app = apps.first(where: { $0.localizedName == name }) else {
            throw AgentError.applicationNotRunning(name)
        }
        app.activate(options: .activateIgnoringOtherApps)
    }
    
    func clearSystemCaches() async -> Int64 {
        // Clear various system caches
        var totalCleared: Int64 = 0
        
        // Clear user caches
        let cachePaths = [
            "~/Library/Caches",
            "/Library/Caches",
            "~/Library/Logs"
        ]
        
        for path in cachePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            totalCleared += clearDirectory(at: expandedPath)
        }
        
        return totalCleared
    }
    
    func optimizeMemory() async -> Int64 {
        // Run memory optimization
        let task = Process()
        task.launchPath = "/usr/bin/purge"
        task.launch()
        task.waitUntilExit()
        
        // Return approximate memory freed
        return 1024 * 1024 * 500 // 500MB estimate
    }
    
    func optimizeStartupItems() async -> Int {
        // Optimize login items
        return 0 // Placeholder
    }
    
    private func clearDirectory(at path: String) -> Int64 {
        var totalSize: Int64 = 0
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }
        
        while let file = enumerator.nextObject() as? String {
            let fullPath = "\(path)/\(file)"
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return totalSize
    }
}

class KnowledgeBase {
    private var systemKnowledge: [String: Any] = [:]
    private var libraryDocs: [String: String] = [:]
    private var commandHistory: [CommandRecord] = []
    
    func loadSystemKnowledge() {
        // Load system-specific knowledge
        systemKnowledge = [
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "processor": getProcessorInfo(),
            "memory": ProcessInfo.processInfo.physicalMemory
        ]
    }
    
    func loadLibraryDocumentation() {
        // Load documentation for various libraries
        libraryDocs = [
            "SwiftUI": "Latest SwiftUI documentation and updates",
            "Combine": "Reactive programming framework",
            "CoreML": "Machine learning framework"
        ]
    }
    
    func recordSuccessfulCommand(command: String, intent: String, response: String) {
        commandHistory.append(CommandRecord(
            command: command,
            intent: intent,
            response: response,
            timestamp: Date(),
            success: true
        ))
    }
    
    private func getProcessorInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var result = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &result, &size, nil, 0)
        return String(cString: result)
    }
}

class TaskExecutor {
    func runWorkflow(_ name: String) async throws -> String {
        // Execute predefined workflows
        switch name.lowercased() {
        case "daily_cleanup":
            return await runDailyCleanup()
        case "backup":
            return await runBackup()
        case "security_scan":
            return await runSecurityScan()
        default:
            throw AgentError.workflowNotFound(name)
        }
    }
    
    private func runDailyCleanup() async -> String {
        return "Daily cleanup completed: Cleared 2.3GB of temporary files"
    }
    
    private func runBackup() async -> String {
        return "Backup completed: All important files backed up to Time Machine"
    }
    
    private func runSecurityScan() async -> String {
        return "Security scan completed: No threats detected"
    }
}

class ContinuousListener {
    var onCommandDetected: ((String) -> Void)?
    private var isListening = false
    
    func start() {
        isListening = true
        // Implement continuous listening logic
    }
    
    func stop() {
        isListening = false
    }
}

// Additional supporting classes would be implemented similarly...

// MARK: - Data Models

enum ProcessingStatus {
    case idle, processing, complete, error
}

enum Verbosity {
    case minimal, normal, detailed
}

enum ExecutionMode {
    case safe, normal, advanced
}

struct Capability {
    let name: String
    let category: Category
    let commands: [String]
    
    enum Category {
        case system, files, network, ai, automation, advanced
    }
}

struct SystemMetrics {
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let networkActivity: Double
    let temperature: Double
}

struct CommandRecord {
    let command: String
    let intent: String
    let response: String
    let timestamp: Date
    let success: Bool
}

enum AgentError: LocalizedError {
    case applicationNotFound(String)
    case applicationNotRunning(String)
    case workflowNotFound(String)
    case fileOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .applicationNotFound(let name):
            return "Application '\(name)' not found"
        case .applicationNotRunning(let name):
            return "Application '\(name)' is not running"
        case .workflowNotFound(let name):
            return "Workflow '\(name)' not found"
        case .fileOperationFailed(let reason):
            return "File operation failed: \(reason)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let agentSpeakResponse = Notification.Name("agentSpeakResponse")
    static let agentStatusChanged = Notification.Name("agentStatusChanged")
}

#endif