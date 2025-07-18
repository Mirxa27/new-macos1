import SwiftUI

@main
struct VoiceAgentApp: App {
    @StateObject private var voiceAgent = VoiceAgent()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(voiceAgent)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        MenuBarExtra("Voice Agent", systemImage: "mic.circle.fill") {
            VStack {
                Button(voiceAgent.isListening ? "Stop Listening" : "Start Listening") {
                    voiceAgent.toggleListening()
                }
                .keyboardShortcut(voiceAgent.isListening ? .cancelAction : .defaultAction)
                
                Button(voiceAgent.voiceFeedbackManager.isEnabled ? "Disable Voice Feedback" : "Enable Voice Feedback") {
                    voiceAgent.toggleVoiceFeedback()
                }
                
                if voiceAgent.voiceFeedbackManager.isSpeaking {
                    Button("Stop Speaking") {
                        voiceAgent.stopVoiceFeedback()
                    }
                }
                
                Divider()
                
                Button("Show Configuration") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
        }
        .menuBarExtraStyle(.window)
    }
}