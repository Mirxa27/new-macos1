# Voice Agent Project Structure

This document outlines the complete structure of the Voice Agent macOS application.

## Project Overview

```
VoiceAgent/
├── VoiceAgent.xcodeproj/
│   └── project.pbxproj                 # Xcode project configuration
├── VoiceAgent/
│   ├── VoiceAgentApp.swift            # Main app entry point with menu bar
│   ├── ContentView.swift              # Main UI with status and controls
│   ├── ConfigurationView.swift        # Settings interface for AI providers
│   ├── VoiceAgent.swift               # Core coordinator class
│   ├── AudioManager.swift             # Speech recognition and audio handling
│   ├── VoiceFeedbackManager.swift     # Text-to-speech and voice feedback
│   ├── ScreenManager.swift            # Screen capture and monitoring
│   ├── AIProviderManager.swift        # Multi-provider AI integration
│   ├── SystemController.swift         # System automation and control
│   ├── VoiceAgent.entitlements        # App permissions and capabilities
│   ├── Assets.xcassets/               # App icons and resources
│   │   ├── AppIcon.appiconset/
│   │   ├── AccentColor.colorset/
│   │   └── Contents.json
│   └── Preview Content/               # SwiftUI preview assets
│       └── Preview Assets.xcassets/
├── README.md                          # Comprehensive documentation
├── CHANGELOG.md                       # Version history and updates
├── LICENSE                            # MIT license
├── Package.swift                      # Swift package configuration
└── build-script.txt                  # Build automation script
```

## Core Components

### 1. VoiceAgentApp.swift
- Main application entry point
- Menu bar integration
- Window management
- Global keyboard shortcuts

### 2. VoiceAgent.swift
- Central coordinator class
- Manages all subsystems
- Command processing pipeline
- State management and UI updates

### 3. AudioManager.swift
- Real-time speech recognition
- Microphone input handling
- Speech-to-text conversion
- Audio session management

### 4. VoiceFeedbackManager.swift
- Text-to-speech synthesis
- Voice feedback configuration
- Real-time audio confirmations
- Customizable voice settings (voice, volume, speed)
- Priority-based speech queuing

### 5. ScreenManager.swift
- Real-time screen capture
- Screen content analysis
- Context extraction for AI
- Performance-optimized monitoring

### 6. AIProviderManager.swift
- Multi-provider support (OpenAI, Anthropic, Ollama, Groq)
- Secure API key management
- Model selection and configuration
- Request/response handling

### 7. SystemController.swift
- Mouse click automation
- Keyboard input simulation
- Application launching
- System-level interactions

### 8. ConfigurationView.swift
- User-friendly settings interface
- AI provider configuration
- Permission management
- Testing and validation

## Key Features Implemented

### Voice Recognition
- Continuous speech listening
- Real-time transcription
- Automatic command detection
- Multiple language support ready

### Voice Feedback
- Real-time text-to-speech responses
- Customizable voice selection from system voices
- Adjustable volume and speaking speed
- Priority-based speech management
- Action confirmations and status updates

### AI Integration
- **OpenAI**: GPT-4, GPT-4 Turbo, GPT-3.5 Turbo
- **Anthropic**: Claude 3 Sonnet, Haiku, Opus
- **Ollama**: Local models (Llama2, CodeLlama, Mistral, etc.)
- **Groq**: Fast inference models

### System Control
- Precise mouse clicking
- Text input automation
- Keyboard shortcuts
- Application management
- Scrolling and navigation

### Screen Monitoring
- Real-time screen capture
- Context-aware analysis
- Application state detection
- UI element recognition

### Security & Privacy
- Keychain integration for API keys
- Minimal data collection
- Local processing when possible
- Granular permission controls

## Build Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Frameworks**: SwiftUI, Speech, AVFoundation, ScreenCaptureKit

## Permissions Required

1. **Microphone Access** - For voice input
2. **Screen Recording** - For screen monitoring
3. **Accessibility** - For system control

## Usage Workflow

1. **Startup**: App launches and initializes all subsystems
2. **Configuration**: User configures AI provider, voice feedback settings, and grants permissions
3. **Listening**: App continuously listens for voice commands
4. **Processing**: Speech is converted to text and sent to AI
5. **Execution**: AI response is parsed and system actions are performed
6. **Feedback**: Results are displayed to user

## Command Examples

```
Voice Input: "Click on the Safari icon"
→ Voice Feedback: "Executing: Click on the Safari icon"
→ AI Processing: Analyzes screen context
→ System Action: click(x: 100, y: 50)
→ Voice Feedback: "Successfully clicked at coordinates 100, 50"
→ Result: Safari application launches

Voice Input: "Type hello world"
→ Voice Feedback: "Executing: Type hello world"
→ AI Processing: Identifies typing command
→ System Action: type("hello world")
→ Voice Feedback: "Successfully typed the text"
→ Result: Text is typed at cursor location

Voice Input: "Scroll down on this page"
→ Voice Feedback: "Executing: Scroll down on this page"
→ AI Processing: Understands scroll direction
→ System Action: scroll("down")
→ Voice Feedback: "Successfully scrolled down"
→ Result: Page scrolls downward
```

## Architecture Benefits

- **Modular Design**: Each component has a single responsibility
- **Async/Await**: Modern concurrency for responsive UI
- **Error Handling**: Comprehensive error management
- **Extensibility**: Easy to add new AI providers or actions
- **Security**: Secure credential storage and minimal permissions
- **Performance**: Optimized for real-time processing

This architecture provides a solid foundation for a powerful voice-controlled macOS assistant while maintaining security, performance, and user experience standards.