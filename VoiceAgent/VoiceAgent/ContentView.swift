#if os(macOS)
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var voiceAgent: VoiceAgent
    @State private var showingConfiguration = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(voiceAgent.isListening ? .green : .gray)
                        .scaleEffect(voiceAgent.isListening ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: voiceAgent.isListening)
                    
                    Text("Voice Agent")
                        .font(.largeTitle)
                        .bold()
                    
                    Text(voiceAgent.statusMessage)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Status Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatusCard(
                        title: "Listening",
                        value: voiceAgent.isListening ? "Active" : "Inactive",
                        icon: "mic.circle",
                        color: voiceAgent.isListening ? .green : .gray
                    )
                    
                    StatusCard(
                        title: "Screen Monitor",
                        value: voiceAgent.isScreenMonitoring ? "Active" : "Inactive",
                        icon: "display",
                        color: voiceAgent.isScreenMonitoring ? .blue : .gray
                    )
                    
                    StatusCard(
                        title: "AI Provider",
                        value: voiceAgent.aiProviderManager.currentProvider?.name ?? "None",
                        icon: "brain.head.profile",
                        color: .purple
                    )
                    
                    StatusCard(
                        title: "Vision Analysis",
                        value: voiceAgent.visionManager.isVisionEnabled ? "Enabled" : "Disabled",
                        icon: voiceAgent.visionManager.isVisionEnabled ? "eye.fill" : "eye.slash",
                        color: voiceAgent.visionManager.isVisionEnabled ? .blue : .gray
                    )
                    
                    StatusCard(
                        title: "Commands",
                        value: "\(voiceAgent.commandCount)",
                        icon: "command.circle",
                        color: .orange
                    )
                    
                    StatusCard(
                        title: "Voice Feedback",
                        value: voiceAgent.voiceFeedbackManager.isSpeaking ? "Speaking" : 
                               (voiceAgent.voiceFeedbackManager.isEnabled ? "Ready" : "Disabled"),
                        icon: voiceAgent.voiceFeedbackManager.isSpeaking ? "speaker.wave.3.fill" : 
                              (voiceAgent.voiceFeedbackManager.isEnabled ? "speaker.wave.2" : "speaker.slash"),
                        color: voiceAgent.voiceFeedbackManager.isSpeaking ? .blue :
                               (voiceAgent.voiceFeedbackManager.isEnabled ? .green : .gray)
                    )
                    
                    StatusCard(
                        title: "Live API",
                        value: voiceAgent.isLiveAPIActive ? 
                               (voiceAgent.isLiveAPISpeaking ? "Speaking" : 
                                voiceAgent.isLiveAPIListening ? "Listening" : "Connected") : "Disconnected",
                        icon: voiceAgent.isLiveAPIActive ? 
                              (voiceAgent.isLiveAPISpeaking ? "speaker.wave.3.fill" : 
                               voiceAgent.isLiveAPIListening ? "waveform" : "wifi") : "wifi.slash",
                        color: voiceAgent.isLiveAPIActive ? 
                               (voiceAgent.isLiveAPISpeaking ? .blue : 
                                voiceAgent.isLiveAPIListening ? .green : .orange) : .gray
                    )
                }
                .padding(.horizontal)
                
                // Controls
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button(action: {
                            voiceAgent.toggleListening()
                        }) {
                            HStack {
                                Image(systemName: voiceAgent.isListening ? "mic.slash.circle" : "mic.circle")
                                Text(voiceAgent.isListening ? "Stop Listening" : "Start Listening")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button(action: {
                            voiceAgent.toggleScreenMonitoring()
                        }) {
                            HStack {
                                Image(systemName: voiceAgent.isScreenMonitoring ? "eye.slash" : "eye")
                                Text(voiceAgent.isScreenMonitoring ? "Stop Monitor" : "Start Monitor")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    HStack(spacing: 16) {
                        Button("Configuration") {
                            showingConfiguration = true
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Describe Screen") {
                            voiceAgent.describeCurrentScreen()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(!voiceAgent.visionManager.isVisionEnabled)
                    }
                    
                    HStack(spacing: 16) {
                        Button(voiceAgent.voiceFeedbackManager.isEnabled ? "Mute Voice" : "Enable Voice") {
                            voiceAgent.toggleVoiceFeedback()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        Button("Read Screen Text") {
                            voiceAgent.readScreenText()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .disabled(!voiceAgent.visionManager.isVisionEnabled)
                    }
                    
                    if voiceAgent.voiceFeedbackManager.isSpeaking {
                        Button("Stop Speaking") {
                            voiceAgent.stopVoiceFeedback()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Live API Controls
                    HStack(spacing: 16) {
                        Button(action: {
                            voiceAgent.toggleLiveAPI()
                        }) {
                            HStack {
                                Image(systemName: voiceAgent.isLiveAPIActive ? "wifi.slash" : "wifi")
                                Text(voiceAgent.isLiveAPIActive ? "Stop Live API" : "Start Live API")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(voiceAgent.isLiveAPIActive ? .borderedProminent : .bordered)
                        .controlSize(.large)
                        .disabled(voiceAgent.aiProviderManager.currentProvider?.supportsLiveAPI != true)
                        
                        if voiceAgent.isLiveAPIActive {
                            Button("Send Message") {
                                // For demo purposes, send a test message
                                voiceAgent.sendLiveTextMessage("Hello from Live API")
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Recent Commands
                if !voiceAgent.recentCommands.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Recent Commands")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(voiceAgent.recentCommands.prefix(5), id: \.timestamp) { command in
                                    CommandRow(command: command)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 150)
                    }
                }
                
                Spacer()
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .sheet(isPresented: $showingConfiguration) {
            ConfigurationView()
                .environmentObject(voiceAgent)
        }
    }
}

struct StatusCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .scaleEffect(title == "Voice Feedback" && value == "Speaking" ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), 
                          value: title == "Voice Feedback" && value == "Speaking")
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct CommandRow: View {
    let command: VoiceCommand
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(command.text)
                    .font(.subheadline)
                    .lineLimit(2)
                
                Text(command.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Image(systemName: command.executed ? "checkmark.circle.fill" : "clock.circle")
                    .foregroundColor(command.executed ? .green : .orange)
                
                if let result = command.result {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .environmentObject(VoiceAgent())
}
#endif
