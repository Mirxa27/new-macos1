#if os(macOS)
import SwiftUI
import Combine

/// Main view for the Local AI Agent interface
struct LocalAIAgentView: View {
    @StateObject private var agent = LocalAIAgent()
    @StateObject private var voiceAgent = VoiceAgent()
    @State private var commandInput = ""
    @State private var showingSettings = false
    @State private var selectedCapability: LocalAIAgent.Capability?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(agent: agent)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content
            HSplitView {
                // Capabilities Sidebar
                CapabilitiesSidebar(
                    capabilities: agent.capabilities,
                    selectedCapability: $selectedCapability
                )
                .frame(minWidth: 200, idealWidth: 250)
                
                // Main Panel
                VStack {
                    // Response Area
                    ResponseView(response: agent.lastResponse)
                        .frame(maxHeight: .infinity)
                    
                    // Command Input
                    CommandInputView(
                        commandInput: $commandInput,
                        isListening: agent.isListening,
                        onSubmit: {
                            Task {
                                await agent.processCommand(commandInput)
                                commandInput = ""
                            }
                        },
                        onVoiceToggle: {
                            if agent.isListening {
                                agent.stopListening()
                            } else {
                                agent.startListening()
                            }
                        }
                    )
                    .padding()
                }
            }
            
            // Status Bar
            StatusBarView(agent: agent)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            setupIntegration()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(agent: agent)
        }
    }
    
    private func setupIntegration() {
        // Connect LocalAIAgent with VoiceAgent components
        agent.startListening()
        
        // Setup voice feedback
        voiceAgent.voiceFeedbackManager.isEnabled = true
        
        // Connect NLU engine
        Task {
            await voiceAgent.aiProviderManager.processCommand("Initialize agent", context: nil)
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var agent: LocalAIAgent
    
    var body: some View {
        HStack {
            Image(systemName: "brain")
                .font(.title)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text("Local AI Agent")
                    .font(.headline)
                Text(agent.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(agent.isActive ? .green : .secondary)
            }
            
            Spacer()
            
            // System Metrics
            if let metrics = agent.systemMetrics {
                HStack(spacing: 20) {
                    MetricView(label: "CPU", value: "\(Int(metrics.cpuUsage))%", color: colorForCPU(metrics.cpuUsage))
                    MetricView(label: "Memory", value: "\(Int(metrics.memoryUsage))%", color: colorForMemory(metrics.memoryUsage))
                    MetricView(label: "Disk", value: "\(Int(metrics.diskUsage))%", color: colorForDisk(metrics.diskUsage))
                }
            }
            
            Button(action: {}) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
        }
    }
    
    private func colorForCPU(_ usage: Double) -> Color {
        if usage > 80 { return .red }
        if usage > 60 { return .orange }
        return .green
    }
    
    private func colorForMemory(_ usage: Double) -> Color {
        if usage > 90 { return .red }
        if usage > 70 { return .orange }
        return .green
    }
    
    private func colorForDisk(_ usage: Double) -> Color {
        if usage > 90 { return .red }
        if usage > 80 { return .orange }
        return .green
    }
}

// MARK: - Metric View

struct MetricView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Capabilities Sidebar

struct CapabilitiesSidebar: View {
    let capabilities: [LocalAIAgent.Capability]
    @Binding var selectedCapability: LocalAIAgent.Capability?
    
    var body: some View {
        List(capabilities, id: \.name) { capability in
            CapabilityRow(
                capability: capability,
                isSelected: selectedCapability?.name == capability.name
            )
            .onTapGesture {
                selectedCapability = capability
            }
        }
        .listStyle(SidebarListStyle())
    }
}

// MARK: - Capability Row

struct CapabilityRow: View {
    let capability: LocalAIAgent.Capability
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: iconForCategory(capability.category))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading) {
                Text(capability.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(capability.commands.prefix(2).joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    private func iconForCategory(_ category: LocalAIAgent.Capability.Category) -> String {
        switch category {
        case .system: return "cpu"
        case .files: return "folder"
        case .network: return "network"
        case .ai: return "brain"
        case .automation: return "gearshape.2"
        case .advanced: return "star"
        }
    }
}

// MARK: - Response View

struct ResponseView: View {
    let response: String
    @State private var isCopied = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !response.isEmpty {
                    HStack {
                        Text("Response")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: copyResponse) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(response)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "text.bubble")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Ask me anything...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Example commands:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            ForEach(exampleCommands, id: \.self) { command in
                                Text("• \(command)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
    }
    
    private func copyResponse() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(response, forType: .string)
        
        withAnimation {
            isCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }
    
    private var exampleCommands: [String] {
        [
            "What's my system information?",
            "Check disk usage",
            "List processes",
            "Search web for Swift tutorials",
            "Summarize this document",
            "Write a Python script to sort files",
            "Explain quantum computing",
            "Create a meal plan for this week"
        ]
    }
}

// MARK: - Command Input View

struct CommandInputView: View {
    @Binding var commandInput: String
    let isListening: Bool
    let onSubmit: () -> Void
    let onVoiceToggle: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onVoiceToggle) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .foregroundColor(isListening ? .red : .primary)
            }
            .buttonStyle(.plain)
            .help(isListening ? "Stop listening" : "Start listening")
            
            TextField("Type a command or question...", text: $commandInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onSubmit)
            
            Button("Send", action: onSubmit)
                .disabled(commandInput.isEmpty)
        }
    }
}

// MARK: - Status Bar View

struct StatusBarView: View {
    @ObservedObject var agent: LocalAIAgent
    
    var body: some View {
        HStack {
            // Status
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(statusText)
                    .font(.caption)
            }
            
            Divider()
                .frame(height: 12)
            
            // Current command
            if !agent.currentCommand.isEmpty {
                Text("Processing: \(agent.currentCommand)")
                    .font(.caption)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Processing indicator
            if agent.processingStatus == .processing {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
    }
    
    private var statusColor: Color {
        switch agent.processingStatus {
        case .idle: return .gray
        case .processing: return .orange
        case .complete: return .green
        case .error: return .red
        }
    }
    
    private var statusText: String {
        switch agent.processingStatus {
        case .idle: return "Ready"
        case .processing: return "Processing..."
        case .complete: return "Complete"
        case .error: return "Error"
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var agent: LocalAIAgent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Agent Settings")
                .font(.title2)
                .padding()
            
            Form {
                Section("General") {
                    Toggle("Enable Continuous Listening", isOn: $agent.configuration.enableContinuousListening)
                    
                    Picker("Response Verbosity", selection: $agent.configuration.responseVerbosity) {
                        Text("Minimal").tag(Verbosity.minimal)
                        Text("Normal").tag(Verbosity.normal)
                        Text("Detailed").tag(Verbosity.detailed)
                    }
                    
                    Picker("Execution Mode", selection: $agent.configuration.executionMode) {
                        Text("Safe").tag(ExecutionMode.safe)
                        Text("Normal").tag(ExecutionMode.normal)
                        Text("Advanced").tag(ExecutionMode.advanced)
                    }
                }
                
                Section("Advanced") {
                    Toggle("Enable Learning", isOn: $agent.configuration.enableLearning)
                    Toggle("Privacy Mode", isOn: $agent.configuration.privacyMode)
                    Toggle("Debug Mode", isOn: $agent.configuration.debugMode)
                    
                    Stepper("Max Concurrent Tasks: \(agent.configuration.maxConcurrentTasks)",
                           value: $agent.configuration.maxConcurrentTasks,
                           in: 1...10)
                }
            }
            .padding()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    // Save settings
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - App Integration

/// Integrates the Local AI Agent with the main VoiceAgent app
extension VoiceAgentApp {
    func setupLocalAIAgent() {
        // Register agent commands with main voice agent
        let agent = LocalAIAgent()
        
        // Start agent
        agent.startListening()
        
        // Connect to voice feedback
        NotificationCenter.default.addObserver(
            forName: .agentSpeakResponse,
            object: nil,
            queue: .main
        ) { notification in
            if let response = notification.userInfo?["response"] as? String {
                // Use voice feedback to speak response
                self.voiceAgent.voiceFeedbackManager.speak(response, priority: .high)
            }
        }
    }
}

// MARK: - Menu Bar Integration

extension MenuBarView {
    func addAgentCommands() -> some View {
        Group {
            Divider()
            
            Menu("AI Agent") {
                Button("System Information") {
                    Task {
                        await processAgentCommand("system information")
                    }
                }
                
                Button("Check Disk Usage") {
                    Task {
                        await processAgentCommand("check disk usage")
                    }
                }
                
                Button("List Processes") {
                    Task {
                        await processAgentCommand("list processes")
                    }
                }
                
                Divider()
                
                Button("Search Web...") {
                    showSearchDialog()
                }
                
                Button("Summarize Clipboard") {
                    Task {
                        await processAgentCommand("summarize clipboard")
                    }
                }
                
                Divider()
                
                Button("Open Agent Window") {
                    openAgentWindow()
                }
            }
        }
    }
    
    private func processAgentCommand(_ command: String) async {
        let agent = LocalAIAgent()
        await agent.processCommand(command)
    }
    
    private func showSearchDialog() {
        // Show search input dialog
    }
    
    private func openAgentWindow() {
        // Open dedicated agent window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Local AI Agent"
        window.contentView = NSHostingView(rootView: LocalAIAgentView())
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

#endif