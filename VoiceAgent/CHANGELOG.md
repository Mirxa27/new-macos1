# Changelog

All notable changes to Voice Agent will be documented in this file.

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