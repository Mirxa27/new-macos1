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
│   ├── VisionManager.swift            # AI-powered screen analysis and visual understanding
│   ├── ScreenManager.swift            # Screen capture and monitoring
│   ├── AIProviderManager.swift        # Multi-provider AI integration with vision support
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

### 5. VisionManager.swift
- AI-powered screen analysis using Vision framework
- Image processing and optimization for AI models
- Text detection and OCR capabilities
- UI element recognition and classification
- Visual context generation for voice commands
- Integration with OpenAI GPT-4 Vision, Claude 3, and LLaVA
- Real-time screen understanding and description
- Privacy-focused local analysis combined with cloud AI

### 6. ScreenManager.swift
- Real-time screen capture
- Screen content analysis
- Context extraction for AI
- Performance-optimized monitoring

### 6. ScreenManager.swift
- Real-time screen capture
- Screen content monitoring
- Context extraction for AI
- Performance-optimized monitoring
- Integration with vision analysis

### 7. AIProviderManager.swift
- Multi-provider support with vision capabilities
- Vision model selection and configuration
- Image-to-text processing for vision models
- Fallback systems for non-vision providers
- API request handling for both text and vision
- Model switching and configuration management

### 8. SystemController.swift
- Multi-provider support (OpenAI, Anthropic, Ollama, Groq)
- Secure API key management
- Model selection and configuration
- Request/response handling

### 9. ConfigurationView.swift
- User-friendly settings interface
- AI provider and vision model configuration
- Vision analysis settings and testing
- Voice feedback customization
- Permission management and system integration
- Real-time testing and validation
- Mouse click automation
- Keyboard input simulation
- Application launching
- System-level interactions

### 8. SystemController.swift
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

### Vision Analysis
- AI-powered screen understanding using multiple vision models
- Real-time visual context awareness
- UI element detection and classification
- Text recognition and content analysis
- Visual guidance for precise system control
- Privacy-focused local processing with cloud AI enhancement

### AI Integration
- **OpenAI**: GPT-4, GPT-4 Turbo, GPT-3.5 Turbo + Vision models
- **Anthropic**: Claude 3 Sonnet, Haiku, Opus + Vision capabilities
- **Ollama**: Local models (Llama2, CodeLlama, Mistral, etc.) + LLaVA vision
- **Groq**: Fast inference models (text-only)

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

1. **Startup**: App launches and initializes all subsystems including vision
2. **Configuration**: User configures AI provider, vision settings, voice feedback, and grants permissions
3. **Listening**: App continuously listens for voice commands
4. **Vision Analysis**: Screen is analyzed using AI vision models for context
5. **Processing**: Speech and visual context are combined and sent to AI
6. **Execution**: AI response is parsed and system actions are performed with visual guidance
7. **Feedback**: Results are displayed and spoken with detailed visual descriptions

## Command Examples

```
Voice Input: "Click on the Safari icon"
→ Voice Feedback: "Executing: Click on the Safari icon"
→ Vision Analysis: Captures screen and analyzes with AI vision model
→ AI Processing: "I can see the Safari icon in the dock at coordinates 150, 80"
→ System Action: click(x: 150, y: 80)
→ Voice Feedback: "Successfully clicked at coordinates 150, 80"
→ Voice Feedback: "Successfully opened Safari"
→ Result: Safari application launches with visual confirmation

Voice Input: "What's on my screen?"
→ Voice Feedback: "Analyzing screen visually"
→ Vision Analysis: Captures and analyzes current screen
→ AI Processing: Detailed visual understanding of screen content
→ Voice Feedback: "I can see a Safari browser window with the Apple website open. The main content shows a MacBook Pro with the heading 'Supercharged for pros'. There's a navigation bar with Mac, iPad, iPhone options."
→ Result: Detailed spoken description of current screen content

Voice Input: "Type hello world"
→ Voice Feedback: "Executing: Type hello world"
→ Vision Analysis: Identifies active text field or cursor location
→ AI Processing: "I can see the cursor is active in the search field"
→ System Action: type("hello world")
→ Voice Feedback: "Successfully typed the text"
→ Result: Text is typed at cursor location with visual verification
```

## Architecture Benefits

- **Modular Design**: Each component has a single responsibility
- **Async/Await**: Modern concurrency for responsive UI
- **Vision Integration**: AI-powered visual understanding
- **Error Handling**: Comprehensive error management
- **Extensibility**: Easy to add new AI providers, vision models, or actions
- **Security**: Secure credential storage and minimal permissions
- **Performance**: Optimized for real-time processing and vision analysis
- **Privacy**: Local processing options with user-controlled cloud integration

This architecture provides a solid foundation for a powerful voice-controlled macOS assistant with advanced vision capabilities, maintaining security, performance, and user experience standards while enabling sophisticated visual understanding and contextual awareness.