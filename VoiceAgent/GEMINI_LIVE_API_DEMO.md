# Gemini Live API Integration Demo

This document demonstrates the advanced Live API capabilities integrated with Google Gemini in the Voice Agent application.

## Overview

The Gemini Live API integration provides real-time, bidirectional communication with Google's Gemini models, enabling natural conversation with live audio streaming and real-time screen sharing.

## Key Features

### 🔊 Real-Time Audio Streaming
- **Bidirectional Audio**: Continuous 16kHz audio input, 24kHz audio output
- **Live Conversation**: Natural back-and-forth dialogue
- **Voice Selection**: Customizable Gemini voice (default: Zephyr)
- **Audio Processing**: Real-time PCM audio conversion and streaming

### 🖥️ Live Screen Sharing
- **Real-Time Capture**: Screen capture at 1fps automatically shared with Gemini
- **Visual Context**: Gemini can see and understand your screen in real-time
- **Dynamic Analysis**: Screen content analysis updates continuously during conversation

### 🌐 WebSocket Connection Management
- **Persistent Connection**: Maintains WebSocket connection for real-time communication
- **Auto-Reconnection**: Intelligent connection recovery
- **Status Monitoring**: Real-time connection status with visual indicators
- **Error Handling**: Comprehensive error management and user feedback

## Live API vs Standard API

| Feature | Standard API | Live API |
|---------|-------------|----------|
| **Communication** | Request/Response | Real-time WebSocket |
| **Audio** | Text-only | Live bidirectional streaming |
| **Screen Sharing** | Static screenshots | Live screen streaming |
| **Response Time** | ~2-5 seconds | Near-instantaneous |
| **Conversation Flow** | Turn-based | Natural, overlapping dialogue |
| **Interruption** | Not supported | Can interrupt Gemini mid-response |

## Usage Examples

### Starting a Live API Session

1. **Configuration Setup**:
   ```
   1. Configure Gemini provider with valid API key
   2. Navigate to Live API section in configuration
   3. Verify Live API support is available
   ```

2. **Initiating Session**:
   ```
   • Click "Start Live API" in main interface
   • Monitor connection status: "Connecting..." → "Connected"
   • Observe live streaming indicators (listening/speaking)
   ```

3. **Real-Time Interaction**:
   ```
   • Speak naturally - no wake words needed
   • Gemini responds with voice while seeing your screen
   • Interrupt or continue conversation seamlessly
   ```

### Live Conversation Examples

#### Basic Screen Assistance
```
User: "What do you see on my screen?"
Gemini: [Real-time voice] "I can see you have the Voice Agent application open with several status cards showing. The Live API is currently connected and active. I notice you have a terminal window in the background."
```

#### Interactive Screen Guidance
```
User: "Help me navigate this interface"
Gemini: [Real-time voice] "I can see the main Voice Agent interface. There are control buttons at the bottom. The 'Start Live API' button shows the session is active. Would you like me to guide you through any specific features?"
```

#### Code Assistance
```
User: "Can you help me understand this code?"
Gemini: [Real-time voice] "I can see code on your screen. It appears to be Swift code for the Live API implementation. I notice the WebSocket connection handling in the GeminiLiveAPIManager class. Would you like me to explain any specific parts?"
```

## Technical Implementation

### WebSocket Protocol
- **URL**: `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.StreamGenerateContent`
- **Authentication**: API key in URL parameters
- **Message Format**: JSON with base64-encoded audio/image data

### Audio Processing Pipeline
```
Microphone → AVAudioEngine → PCM 16kHz → Base64 → WebSocket → Gemini
Gemini → WebSocket → Base64 → PCM 24kHz → AVAudioPlayer → Speakers
```

### Screen Capture Pipeline
```
Screen → ScreenCaptureKit → CGImage → JPEG → Base64 → WebSocket → Gemini
```

### Configuration Structure
```json
{
  "response_modalities": ["AUDIO"],
  "media_resolution": "MEDIA_RESOLUTION_MEDIUM",
  "speech_config": {
    "voice_config": {
      "prebuilt_voice_config": {
        "voice_name": "Zephyr"
      }
    }
  },
  "context_window_compression": {
    "trigger_tokens": 25600,
    "sliding_window": {
      "target_tokens": 12800
    }
  }
}
```

## User Interface Integration

### Status Indicators
- **Live API Card**: Shows connection status, listening/speaking state
- **Connection Status**: "Disconnected", "Connecting...", "Connected", "Error"
- **Audio Status**: Real-time listening and speaking indicators
- **Error Display**: Clear error messages with troubleshooting hints

### Control Elements
- **Start/Stop Live API**: Primary control for session management
- **Send Test Message**: Send text messages during live session
- **Configuration Panel**: Live API settings and status monitoring
- **Voice Feedback Integration**: Announces Live API status changes

### Visual Feedback
- **Animated Icons**: Pulsating indicators for active streaming
- **Color-coded Status**: Green (connected), Orange (connecting), Red (error), Gray (disconnected)
- **Real-time Updates**: Status updates every 500ms during active session

## Advanced Features

### Session Management
- **Automatic Fallback**: Falls back to standard API if Live API fails
- **Resource Management**: Proper cleanup of WebSocket and audio resources
- **Memory Optimization**: Efficient handling of audio buffers and image data

### Error Recovery
- **Connection Retry**: Automatic reconnection on network issues
- **Graceful Degradation**: Continues with standard API if Live API unavailable
- **User Feedback**: Clear error messages and resolution suggestions

### Performance Optimization
- **Audio Buffering**: Optimized buffer sizes for real-time performance
- **Image Compression**: Efficient JPEG compression for screen captures
- **Network Management**: Smart bandwidth usage and connection pooling

## Best Practices

### For Users
1. **Stable Internet**: Ensure reliable internet connection for WebSocket stability
2. **Microphone Quality**: Use good quality microphone for clear audio input
3. **Screen Content**: Be mindful that screen content is shared in real-time
4. **Natural Speech**: Speak naturally - no need for special commands or pauses

### For Developers
1. **Error Handling**: Implement comprehensive error handling for WebSocket connections
2. **Resource Management**: Properly manage audio engines and WebSocket lifecycles
3. **User Feedback**: Provide clear status indicators and error messages
4. **Performance**: Monitor audio latency and connection stability

## Troubleshooting

### Connection Issues
- **Check API Key**: Ensure valid Gemini API key with Live API access
- **Network Connectivity**: Verify internet connection and firewall settings
- **WebSocket Support**: Ensure network allows WebSocket connections

### Audio Issues
- **Microphone Permissions**: Verify microphone access is granted
- **Audio Format**: Check system audio format compatibility
- **Latency**: Monitor for audio delay or echo issues

### Performance Issues
- **CPU Usage**: Monitor CPU usage during live sessions
- **Memory Usage**: Check for memory leaks in long sessions
- **Network Bandwidth**: Ensure sufficient bandwidth for audio/video streaming

## Future Enhancements

### Planned Features
- **Voice Interruption**: Improved interruption handling
- **Multi-language Support**: Support for multiple input/output languages
- **Custom Voice Training**: Personal voice customization
- **Enhanced Screen Analysis**: More detailed UI element recognition

### Potential Integrations
- **Home Automation**: Control smart home devices through live conversation
- **Calendar Integration**: Natural language calendar management
- **Email Assistance**: Real-time email composition and management
- **Code Generation**: Live coding assistance with screen context

## Security and Privacy

### Data Handling
- **Real-time Processing**: Audio and screen data processed in real-time
- **No Persistent Storage**: No local storage of conversation data
- **Secure Transmission**: All data encrypted via WebSocket TLS
- **API Key Security**: Keys stored securely in macOS Keychain

### User Control
- **Session Management**: Full control over when Live API is active
- **Screen Sharing**: Explicit control over screen sharing
- **Audio Control**: Mute/unmute capabilities
- **Immediate Disconnect**: Instant session termination available

This Live API integration represents a significant advancement in natural human-computer interaction, providing seamless, real-time communication with AI while maintaining user control and privacy.
## Node.js Demo

A simplified Node.js example is included at `Examples/GeminiLiveAPINodeDemo.ts`. It demonstrates how to connect to Gemini Live API using the `@google/genai` package and save streamed audio responses.

Run it with:
```bash
npm install @google/genai mime
npm install -D @types/node
ts-node Examples/GeminiLiveAPINodeDemo.ts
```

