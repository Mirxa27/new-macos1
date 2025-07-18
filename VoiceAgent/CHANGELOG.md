# Changelog

All notable changes to Voice Agent will be documented in this file.

## [1.1.0] - 2025-07-18

### Added
- **Google Gemini Live API Integration**
  - Real-time WebSocket communication with Gemini Live API
  - Live audio streaming (bidirectional)
  - Real-time screen sharing with Gemini
  - Live conversation capabilities
  - Concurrent audio input/output processing
- **Enhanced AI Provider Support**
  - Added Google Gemini as a supported provider
  - Gemini 2.5 Flash, Gemini 1.5 Pro/Flash models
  - Full vision capabilities for Gemini models
- **Live API UI Controls**
  - Live API status monitoring in main interface
  - Start/Stop Live API session controls
  - Real-time connection status indicators
  - Live audio streaming status (listening/speaking)
  - Live API configuration panel
  - Test message functionality
- **Advanced Live Features**
  - Automatic fallback between Live API and standard API
  - WebSocket connection management with error handling
  - Real-time audio format conversion (16kHz input, 24kHz output)
  - Screen capture streaming at 1fps to Live API
  - Voice feedback integration with Live API status

### Enhanced
- Updated AI Provider protocol to support Live API methods
- Extended configuration interface with Live API settings
- Enhanced status monitoring for multiple connection types
- Improved error handling for Live API connections

### Technical
- Implemented `GeminiLiveAPIManager` for WebSocket handling
- Added Live API protocol methods to all providers
- Enhanced `VoiceAgent` with Live API control methods
- Updated UI components for Live API status display

## [1.0.0] - 2025-07-18

### Added
- Initial release of Voice Agent for macOS
- Real-time speech recognition using macOS Speech framework
- **Live voice feedback system with text-to-speech**
- **Customizable voice feedback settings (voice selection, volume, speed)**
- **Real-time audio confirmations during task execution**
- **Advanced AI Vision Analysis with GPT-4 Vision, Claude 3, and LLaVA**
- **Intelligent screen understanding and UI element detection**
- **Text recognition and content analysis from screen captures**
- **Multi-provider vision support (OpenAI, Anthropic, Ollama)**
- **Visual context-aware command processing**
- Multi-provider AI support (OpenAI, Anthropic, Ollama, Groq)
- Real-time screen monitoring and analysis
- Complete system control (clicks, typing, key presses, scrolling)
- Menu bar integration for quick access
- Configuration interface for AI providers, models, vision settings, and voice settings
- Secure API key storage in macOS Keychain
- Natural language command processing
- Support for multiple AI models per provider

### Features
- **Voice Recognition**: Continuous listening with automatic speech recognition
- **Voice Feedback**: Real-time audio responses and confirmations using system TTS
- **Vision Analysis**: AI-powered screen understanding with visual context awareness
- **AI Integration**: Support for multiple AI providers with vision capabilities
- **Screen Monitoring**: Real-time screen capture with intelligent visual analysis
- **System Automation**: Complete Mac control through voice commands with visual guidance
- **Security**: Secure credential storage and privacy-focused design
- **User Interface**: Clean SwiftUI interface with real-time status updates

### Supported AI Providers
- OpenAI (GPT-4, GPT-4 Turbo, GPT-3.5 Turbo)
  - **Vision**: GPT-4 Vision Preview, GPT-4 Turbo, GPT-4o
- Anthropic (Claude 3 Sonnet, Haiku, Opus)
  - **Vision**: Claude 3 Sonnet, Claude 3 Opus
- **Google Gemini** (Gemini 2.5 Flash, Gemini 1.5 Pro/Flash)
  - **Vision**: All Gemini models support vision
  - **Live API**: Real-time conversation with audio streaming
- Ollama (Local models: Llama2, CodeLlama, Mistral, Phi, Neural-Chat)
  - **Vision**: LLaVA, BakLLaVA (local vision models)
- Groq (Mixtral, Llama2, Gemma) - Text only

### System Requirements
- macOS 14.0 (Sonoma) or later
- Microphone access permission
- Screen recording permission
- Accessibility permission

### Known Issues
- First launch requires manual permission granting
- Screen monitoring may have slight delay on older machines
- Some complex UI interactions may need specific coordinate targeting

### Future Enhancements
- Wake word detection
- Multiple language support
- Custom voice commands
- Automation scripting
- Plugin system for custom actions