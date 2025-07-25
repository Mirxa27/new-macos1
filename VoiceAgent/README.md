# Voice Agent for macOS

A comprehensive macOS voice assistant that can control your Mac through natural language voice commands, with support for multiple AI providers and real-time screen monitoring.

## Features

- **Real-time Speech Recognition**: Continuous voice listening using macOS Speech framework
- **Live Voice Feedback**: Real-time audio confirmation and status updates during task execution
- **Advanced Vision Analysis**: AI-powered screen understanding with GPT-4 Vision, Claude 3, and local vision models
- **Multi-Provider AI Support**: Works with OpenAI, Anthropic, Gemini (with Live API), Ollama (local), and Groq
- **Gemini Live API**: Real-time conversation with live audio streaming and screen sharing
- **Intelligent Screen Monitoring**: Real-time screen capture with AI-enhanced contextual analysis
- **System Control**: Complete Mac automation including clicks, typing, key presses, scrolling, and app launching
- **Menu Bar Integration**: Quick access and control from the menu bar
- **Configuration Interface**: Easy setup and management of AI providers, models, vision settings, and voice feedback
- **Custom Wake Word & Language Selection**: Choose your preferred listening language and optional wake word trigger
- **Custom Prompts**: Adjust the system and vision prompts for personalized behavior

## AI Providers Supported

1. **OpenAI** - GPT-4, GPT-4 Turbo, GPT-3.5 Turbo
   - **Vision Models**: GPT-4 Vision, GPT-4 Turbo, GPT-4o
   - **Capabilities**: Advanced screen analysis, UI element detection, text reading
   
2. **Anthropic** - Claude 3 Sonnet, Haiku, Opus
   - **Vision Models**: Claude 3 Sonnet, Claude 3 Opus
   - **Capabilities**: Detailed visual understanding, contextual screen analysis
   
3. **Ollama** - Local models (Llama2, CodeLlama, Mistral, Phi, Neural-Chat)
   - **Vision Models**: LLaVA, BakLLaVA
   - **Capabilities**: Privacy-focused local vision analysis
   
4. **Google Gemini** - Gemini 2.5 Flash, Gemini 1.5 Pro/Flash
   - **Vision Models**: Gemini 2.5 Flash, Gemini 1.5 Pro/Flash
   - **Live API**: Real-time conversation with audio streaming and screen sharing
   - **Capabilities**: Advanced multimodal understanding, real-time interaction
   
5. **Groq** - Mixtral, Llama2, Gemma
   - **Vision Support**: Not available (text-only)

## System Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Microphone access permission
- Screen recording permission
- Accessibility permission

## Installation

1. Open the project in Xcode
2. Build and run the application
3. Grant the required permissions when prompted:
   - Microphone access for voice recognition
   - Screen recording for screen monitoring
   - Accessibility for system control

## Configuration

1. Launch the app and click "Configuration" or use the menu bar
2. **AI Provider Setup:**
   - Select your preferred AI provider
   - Enter your API key (not required for Ollama)
   - Choose your preferred model
   - Enable vision models if supported
   - Test the configuration
3. **Vision Analysis Setup:**
   - Enable vision analysis
   - Choose to use vision when available
   - Test vision capabilities
   - Configure screen analysis frequency
4. **Voice Feedback Setup:**
   - Enable/disable voice feedback
   - Select voice from available system voices
   - Adjust volume and speaking speed
   - Test voice feedback
5. **Speech Recognition Settings:**
   - Choose your preferred listening language
   - Enable a custom wake word and specify the phrase
6. **Live API Setup (Gemini only):**
   - Enable Live API for real-time conversation
   - Test Live API connection
   - Monitor audio streaming status
   - Send test messages
7. **Prompt Settings:**
   - Customize the assistant's System Prompt
   - Customize the Vision Prompt for screen analysis
8. Save settings

### Custom Prompts

Use the **Prompt Settings** section to fine-tune how the assistant behaves. The
System Prompt controls text-based commands, while the Vision Prompt guides
screen analysis. Changes are saved automatically.

## Usage

### Voice Commands

The app responds to natural language commands such as:

- **Navigation**: "Click on the Safari icon", "Scroll down", "Go to the next tab"
- **Typing**: "Type hello world", "Enter my email address"
- **Application Control**: "Open Safari", "Launch Terminal", "Switch to Finder"
- **System Actions**: "Press Enter", "Hit Command+C", "Close this window"

### Menu Bar Controls

- Start/Stop listening
- Enable/Disable voice feedback
- Stop speaking (when voice feedback is active)
- Show configuration window
- Quit application

### Main Window

- View listening status
- Monitor screen capture status
- View voice feedback status and controls
- Monitor Live API connection and streaming status
- Control Live API sessions (start/stop)
- See recent commands and their results
- Access configuration settings
- Control voice feedback (mute/unmute, stop speaking)

## Voice Command Examples

The app now provides intelligent visual understanding with detailed voice responses:

```
You: "What's on my screen?"
App: "Analyzing screen visually"
App: "I can see a Safari browser window with the Apple website. There's a navigation bar at the top with Home, Mac, iPad, and iPhone options. The main content shows a large image of the new MacBook Pro."

You: "Click on the search button"
App: "Executing: Click on the search button"
App: "I can see a search icon in the top right corner of the Safari window"
App: "Successfully clicked at coordinates 1200, 120"

You: "Read the text on the page"
App: "Executing: Read the text on the page"
App: "Screen text includes: MacBook Pro, Supercharged for pros, M3 Pro and M3 Max, Available now"

You: "Type in the search box"
App: "Executing: Type in the search box"
App: "I can see the search field is now active with a blinking cursor"
App: "Successfully typed the text"
```

## Permissions Required

### Microphone Access
- Required for voice recognition
- Granted automatically on first use

### Screen Recording
- Required for screen monitoring and contextual understanding
- Must be granted in System Preferences > Security & Privacy > Privacy > Screen Recording

### Accessibility
- Required for system control (clicking, typing, etc.)
- Must be granted in System Preferences > Security & Privacy > Privacy > Accessibility

## Security & Privacy

- API keys are securely stored in the macOS Keychain
- Screen data is processed locally and only sent to AI providers for command interpretation
- No persistent storage of voice recordings or screen captures
- All permissions can be revoked at any time in System Preferences

## API Key Setup

### OpenAI
1. Get your API key from https://platform.openai.com/
2. Enter it in the configuration screen

### Anthropic
1. Get your API key from https://console.anthropic.com/
2. Enter it in the configuration screen

### Google Gemini
1. Get your API key from https://makersuite.google.com/app/apikey
2. Enter it in the configuration screen
3. For Live API features, ensure you have access to Gemini Live API

### Groq
1. Get your API key from https://console.groq.com/
2. Enter it in the configuration screen

### Ollama (Local)
1. Install Ollama from https://ollama.ai/
2. Run `ollama pull llama2` (or your preferred model)
3. No API key required - just ensure Ollama is running

## Troubleshooting

### Voice Recognition Not Working
- Check microphone permissions in System Preferences
- Ensure your microphone is working in other applications
- Try restarting the app

### Voice Feedback Not Working
- Check that voice feedback is enabled in configuration
- Verify system volume is not muted
- Try different voice in settings
- Restart the app if voice becomes unresponsive

### Vision Analysis Not Working
- Ensure screen recording permission is granted
- Check that your AI provider supports vision (OpenAI, Anthropic, or Ollama with LLaVA)
- Verify vision analysis is enabled in configuration
- Try switching to a vision-capable model

### Screen Monitoring Not Working
- Grant screen recording permission in System Preferences
- Restart the app after granting permissions

### System Control Not Working
- Grant accessibility permission in System Preferences
- Add the app to the list of allowed applications in Accessibility settings

### AI Provider Not Responding
- Verify your API key is correct
- Check your internet connection
- Ensure the selected model is available

### Live API Connection Issues (Gemini)
- Ensure you have a valid Gemini API key
- Check your internet connection
- Verify Live API access is enabled for your account
- Try stopping and restarting the Live API session
- Check firewall settings for WebSocket connections
- Try a different provider

## Development

### Building from Source
1. Clone the repository
2. Open `VoiceAgent.xcodeproj` in Xcode
3. Build and run (macOS only)
   - The app relies on Apple's `Speech` framework which is only available on macOS.
   - On other platforms `swift build` will compile a small fallback executable that simply prints `VoiceAgent is only supported on macOS.`

### Non-macOS Platforms

If you run `swift build` on Linux or another non-macOS system, the build will succeed but the resulting executable only prints:

```
VoiceAgent is only supported on macOS.
```

This allows CI pipelines to verify the package compiles even without macOS.
4. Optionally run the Node.js demo under `Examples` to test Gemini Live API from the command line:
   ```bash
   cd Examples
   npm install
   npm run build
   npm start -- "Your message here"
   ```

### Architecture
- **VoiceAgent**: Main coordinator class
- **AudioManager**: Handles speech recognition
- **VoiceFeedbackManager**: Manages text-to-speech and voice feedback
- **VisionManager**: AI-powered screen analysis and visual understanding
- **ScreenManager**: Manages screen capture and monitoring
- **AIProviderManager**: Manages multiple AI providers with vision support
- **SystemController**: Handles system automation
- **ConfigurationView**: Settings interface

### Adding New AI Providers
1. Implement the `AIProvider` protocol
2. Add the provider to `AIProviderManager.setupProviders()`
3. Update the configuration interface if needed

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This application requires significant system permissions to function properly. Use responsibly and ensure you trust the AI providers you configure. The developers are not responsible for any actions taken by the voice assistant.