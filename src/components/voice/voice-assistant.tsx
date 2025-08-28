'use client';

import { useState, useEffect, useRef } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { 
  Mic, 
  MicOff, 
  Send, 
  Square, 
  Volume2, 
  VolumeX,
  Camera,
  Settings
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useSession } from 'next-auth/react';
import { cn } from '@/lib/utils';
import toast from 'react-hot-toast';

interface VoiceAssistantProps {
  onListeningChange?: (isListening: boolean) => void;
  onStatsUpdate?: (stats: any) => void;
}

interface VoiceCommand {
  id: string;
  text: string;
  response?: string;
  timestamp: string;
  status: 'processing' | 'completed' | 'error';
}

export function VoiceAssistant({ onListeningChange, onStatsUpdate }: VoiceAssistantProps) {
  const { data: session } = useSession();
  const [isListening, setIsListening] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [textInput, setTextInput] = useState('');
  const [commands, setCommands] = useState<VoiceCommand[]>([]);
  const [currentTranscript, setCurrentTranscript] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [voiceEnabled, setVoiceEnabled] = useState(true);
  const [continuousMode, setContinuousMode] = useState(false);
  
  const recognitionRef = useRef<SpeechRecognition | null>(null);
  const synthRef = useRef<SpeechSynthesis | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);

  // Initialize speech recognition
  useEffect(() => {
    if (typeof window !== 'undefined' && 'SpeechRecognition' in window || 'webkitSpeechRecognition' in window) {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      recognitionRef.current = new SpeechRecognition();
      
      recognitionRef.current.continuous = true;
      recognitionRef.current.interimResults = true;
      recognitionRef.current.lang = 'en-US';

      recognitionRef.current.onstart = () => {
        setIsListening(true);
        onListeningChange?.(true);
      };

      recognitionRef.current.onresult = (event) => {
        let interimTranscript = '';
        let finalTranscript = '';

        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalTranscript += transcript;
          } else {
            interimTranscript += transcript;
          }
        }

        setCurrentTranscript(interimTranscript);

        if (finalTranscript) {
          handleVoiceCommand(finalTranscript.trim());
          setCurrentTranscript('');
        }
      };

      recognitionRef.current.onerror = (event) => {
        console.error('Speech recognition error:', event.error);
        toast.error('Speech recognition error: ' + event.error);
        setIsListening(false);
        onListeningChange?.(false);
      };

      recognitionRef.current.onend = () => {
        setIsListening(false);
        onListeningChange?.(false);
        
        if (continuousMode && !isProcessing) {
          // Restart recognition in continuous mode
          setTimeout(() => {
            startListening();
          }, 1000);
        }
      };
    }

    // Initialize speech synthesis
    if (typeof window !== 'undefined') {
      synthRef.current = window.speechSynthesis;
    }

    return () => {
      stopListening();
    };
  }, [continuousMode, isProcessing, onListeningChange]);

  const startListening = async () => {
    try {
      if (recognitionRef.current) {
        recognitionRef.current.start();
        toast.success('Voice recognition started');
      }
    } catch (error) {
      console.error('Error starting speech recognition:', error);
      toast.error('Failed to start voice recognition');
    }
  };

  const stopListening = () => {
    if (recognitionRef.current) {
      recognitionRef.current.stop();
    }
    setIsListening(false);
    onListeningChange?.(false);
  };

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaRecorderRef.current = new MediaRecorder(stream);
      audioChunksRef.current = [];

      mediaRecorderRef.current.ondataavailable = (event) => {
        audioChunksRef.current.push(event.data);
      };

      mediaRecorderRef.current.onstop = () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/wav' });
        // Here you would typically send the audio blob to your API for processing
        console.log('Audio recording completed:', audioBlob);
      };

      mediaRecorderRef.current.start();
      setIsRecording(true);
      toast.success('Audio recording started');
    } catch (error) {
      console.error('Error starting audio recording:', error);
      toast.error('Failed to start audio recording');
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
      
      // Stop all tracks to release the microphone
      mediaRecorderRef.current.stream?.getTracks().forEach(track => track.stop());
    }
  };

  const handleVoiceCommand = async (text: string) => {
    if (!text || isProcessing) return;

    const newCommand: VoiceCommand = {
      id: Date.now().toString(),
      text,
      timestamp: new Date().toISOString(),
      status: 'processing'
    };

    setCommands(prev => [newCommand, ...prev]);
    setIsProcessing(true);

    try {
      // Send command to API
      const response = await fetch('/api/voice/commands', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          command: text,
          sessionId: session?.user?.id,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to process command');
      }

      const result = await response.json();
      
      // Update command with response
      setCommands(prev => 
        prev.map(cmd => 
          cmd.id === newCommand.id 
            ? { ...cmd, response: result.response, status: 'completed' }
            : cmd
        )
      );

      // Speak response if voice is enabled
      if (voiceEnabled && result.response) {
        speakText(result.response);
      }

      // Update stats
      onStatsUpdate?.({
        totalCommands: commands.length + 1,
        successRate: 95,
        averageResponseTime: 1200,
        activeSessions: 1,
      });

    } catch (error) {
      console.error('Error processing command:', error);
      setCommands(prev => 
        prev.map(cmd => 
          cmd.id === newCommand.id 
            ? { ...cmd, response: 'Sorry, I encountered an error processing your command.', status: 'error' }
            : cmd
        )
      );
      toast.error('Failed to process voice command');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleTextSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (textInput.trim()) {
      handleVoiceCommand(textInput.trim());
      setTextInput('');
    }
  };

  const speakText = (text: string) => {
    if (synthRef.current && voiceEnabled) {
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.rate = 0.9;
      utterance.pitch = 1;
      utterance.volume = 0.8;
      synthRef.current.speak(utterance);
    }
  };

  const takeScreenshot = async () => {
    try {
      // Note: This would require additional permissions and API implementation
      const response = await fetch('/api/voice/screenshot', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error('Failed to take screenshot');
      }

      const result = await response.json();
      toast.success('Screenshot captured and analyzed');
      
      // Process the screenshot with AI
      if (result.analysis) {
        const analysisCommand: VoiceCommand = {
          id: Date.now().toString(),
          text: 'Screen analysis requested',
          response: result.analysis,
          timestamp: new Date().toISOString(),
          status: 'completed'
        };
        setCommands(prev => [analysisCommand, ...prev]);
      }
    } catch (error) {
      console.error('Error taking screenshot:', error);
      toast.error('Failed to capture screenshot');
    }
  };

  return (
    <div className="w-full max-w-4xl mx-auto space-y-6">
      {/* Voice Controls */}
      <Card className="glass-morphism">
        <CardContent className="p-6">
          <div className="flex flex-col sm:flex-row items-center justify-center space-y-4 sm:space-y-0 sm:space-x-6">
            {/* Main Voice Button */}
            <div className="relative">
              <Button
                size="lg"
                variant={isListening ? "destructive" : "default"}
                className={cn(
                  "h-20 w-20 rounded-full mobile-touch-target",
                  isListening && "voice-recording"
                )}
                onClick={isListening ? stopListening : startListening}
                disabled={isProcessing}
              >
                {isListening ? (
                  <MicOff className="h-8 w-8" />
                ) : (
                  <Mic className="h-8 w-8" />
                )}
              </Button>
              
              {isListening && (
                <div className="absolute -bottom-6 left-1/2 transform -translate-x-1/2">
                  <Badge variant="destructive" className="animate-pulse">
                    Listening...
                  </Badge>
                </div>
              )}
            </div>

            {/* Voice Waveform Animation */}
            {isListening && (
              <motion.div
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.8 }}
                className="voice-waveform"
              >
                {[...Array(5)].map((_, i) => (
                  <div key={i} className="voice-waveform-bar" />
                ))}
              </motion.div>
            )}

            {/* Control Buttons */}
            <div className="flex space-x-3">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setVoiceEnabled(!voiceEnabled)}
                className="mobile-touch-target"
              >
                {voiceEnabled ? (
                  <Volume2 className="h-4 w-4" />
                ) : (
                  <VolumeX className="h-4 w-4" />
                )}
              </Button>
              
              <Button
                variant="outline"
                size="sm"
                onClick={takeScreenshot}
                className="mobile-touch-target"
              >
                <Camera className="h-4 w-4" />
              </Button>
              
              <Button
                variant="outline"
                size="sm"
                onClick={() => setContinuousMode(!continuousMode)}
                className="mobile-touch-target"
              >
                <Settings className="h-4 w-4" />
              </Button>
            </div>
          </div>

          {/* Current Transcript */}
          <AnimatePresence>
            {currentTranscript && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                className="mt-4 p-3 bg-muted rounded-lg text-center"
              >
                <p className="text-sm text-muted-foreground">
                  {currentTranscript}
                </p>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Settings */}
          <div className="mt-4 flex flex-wrap items-center justify-center gap-2 text-xs text-muted-foreground">
            <Badge variant={continuousMode ? "default" : "outline"}>
              Continuous: {continuousMode ? "On" : "Off"}
            </Badge>
            <Badge variant={voiceEnabled ? "default" : "outline"}>
              Voice Feedback: {voiceEnabled ? "On" : "Off"}
            </Badge>
            <Badge variant={isProcessing ? "default" : "outline"}>
              Status: {isProcessing ? "Processing" : "Ready"}
            </Badge>
          </div>
        </CardContent>
      </Card>

      {/* Text Input Alternative */}
      <Card>
        <CardContent className="p-4">
          <form onSubmit={handleTextSubmit} className="flex space-x-2">
            <Input
              placeholder="Type your command here..."
              value={textInput}
              onChange={(e) => setTextInput(e.target.value)}
              disabled={isProcessing}
              className="flex-1"
            />
            <Button
              type="submit"
              disabled={!textInput.trim() || isProcessing}
              className="mobile-touch-target"
            >
              <Send className="h-4 w-4" />
            </Button>
          </form>
        </CardContent>
      </Card>

      {/* Command History */}
      {commands.length > 0 && (
        <Card>
          <CardContent className="p-4">
            <h3 className="font-semibold mb-4">Recent Commands</h3>
            <div className="space-y-3 max-h-96 overflow-y-auto">
              {commands.slice(0, 10).map((command) => (
                <motion.div
                  key={command.id}
                  initial={{ opacity: 0, x: -20 }}
                  animate={{ opacity: 1, x: 0 }}
                  className="border rounded-lg p-3 space-y-2"
                >
                  <div className="flex items-start justify-between">
                    <p className="text-sm font-medium">{command.text}</p>
                    <Badge
                      variant={
                        command.status === 'completed' ? 'default' :
                        command.status === 'error' ? 'destructive' : 'outline'
                      }
                      className="text-xs"
                    >
                      {command.status}
                    </Badge>
                  </div>
                  
                  {command.response && (
                    <div className="text-sm text-muted-foreground bg-muted p-2 rounded">
                      {command.response}
                    </div>
                  )}
                  
                  <p className="text-xs text-muted-foreground">
                    {new Date(command.timestamp).toLocaleTimeString()}
                  </p>
                </motion.div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

// Extend the Window interface for speech recognition
declare global {
  interface Window {
    SpeechRecognition: any;
    webkitSpeechRecognition: any;
  }
}
