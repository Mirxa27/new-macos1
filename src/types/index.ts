// Core Types for Voice Agent Application

export interface User {
  id: string;
  email: string;
  fullName: string;
  role: 'super_admin' | 'admin' | 'user';
  isActive: boolean;
  emailVerified: boolean;
  profileImageUrl?: string;
  createdAt: string;
  updatedAt: string;
  lastLoginAt?: string;
}

export interface AiProvider {
  id: string;
  name: string;
  providerType: 'openai' | 'anthropic' | 'google' | 'groq' | 'ollama';
  apiKeyEncrypted?: string;
  baseUrl?: string;
  isEnabled: boolean;
  defaultModel?: string;
  maxTokens: number;
  temperature: number;
  timeoutSeconds: number;
  rateLimitPerMinute: number;
  supportsVision: boolean;
  supportsAudio: boolean;
  configuration: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

export interface AiModel {
  id: string;
  providerId: string;
  modelName: string;
  displayName: string;
  modelType: 'text' | 'vision' | 'audio' | 'multimodal';
  maxTokens: number;
  costPer1kInputTokens?: number;
  costPer1kOutputTokens?: number;
  isEnabled: boolean;
  capabilities: Record<string, any>;
  provider?: AiProvider;
}

export interface VoiceSession {
  id: string;
  userId: string;
  sessionName?: string;
  aiProviderId?: string;
  aiModelId?: string;
  wakeWord?: string;
  languageCode: string;
  voiceFeedbackEnabled: boolean;
  continuousListening: boolean;
  screenMonitoringEnabled: boolean;
  sessionStatus: 'active' | 'paused' | 'completed' | 'error';
  startedAt: string;
  endedAt?: string;
  totalDurationSeconds: number;
  totalTokensUsed: number;
  totalCost: number;
  metadata: Record<string, any>;
  user?: User;
  aiProvider?: AiProvider;
  aiModel?: AiModel;
  voiceCommands?: VoiceCommand[];
}

export interface VoiceCommand {
  id: string;
  sessionId: string;
  userId: string;
  commandText: string;
  processedCommand?: string;
  aiResponse?: string;
  commandType: 'general' | 'system_control' | 'screen_analysis' | 'automation';
  executionStatus: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled';
  confidenceScore?: number;
  processingTimeMs?: number;
  tokensUsed: number;
  cost: number;
  errorMessage?: string;
  screenCaptureUrl?: string;
  audioFileUrl?: string;
  createdAt: string;
  completedAt?: string;
  systemActions?: SystemAction[];
}

export interface SystemAction {
  id: string;
  commandId: string;
  actionType: 'click' | 'type' | 'key_press' | 'scroll' | 'app_launch' | 'window_control' | 'system_command';
  targetElement?: string;
  coordinates?: { x: number; y: number };
  inputText?: string;
  keyCombination?: string;
  applicationName?: string;
  success: boolean;
  executionTimeMs?: number;
  errorDetails?: string;
  createdAt: string;
}

export interface ScreenCapture {
  id: string;
  sessionId?: string;
  commandId?: string;
  userId: string;
  imageUrl: string;
  imageWidth?: number;
  imageHeight?: number;
  fileSizeBytes?: number;
  analysisText?: string;
  detectedElements: any[];
  confidenceScores: Record<string, number>;
  createdAt: string;
}

export interface SystemConfiguration {
  id: string;
  configKey: string;
  configValue: string;
  dataType: 'string' | 'number' | 'boolean' | 'json';
  description?: string;
  isPublic: boolean;
  category: string;
  createdAt: string;
  updatedAt: string;
}

export interface UserPreference {
  id: string;
  userId: string;
  preferenceKey: string;
  preferenceValue: string;
  dataType: 'string' | 'number' | 'boolean' | 'json';
  createdAt: string;
  updatedAt: string;
}

export interface AutomationScript {
  id: string;
  userId: string;
  name: string;
  description?: string;
  triggerPhrase?: string;
  scriptContent: any[];
  isEnabled: boolean;
  executionCount: number;
  lastExecutedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Notification {
  id: string;
  userId: string;
  title: string;
  message: string;
  notificationType: 'info' | 'warning' | 'error' | 'success';
  isRead: boolean;
  actionUrl?: string;
  expiresAt?: string;
  createdAt: string;
}

export interface ApiUsageLog {
  id: string;
  userId?: string;
  providerId?: string;
  modelId?: string;
  endpoint: string;
  requestTokens: number;
  responseTokens: number;
  totalCost: number;
  responseTimeMs?: number;
  statusCode?: number;
  errorMessage?: string;
  createdAt: string;
}

export interface PerformanceMetric {
  id: string;
  sessionId?: string;
  userId?: string;
  metricName: string;
  metricValue: number;
  metricUnit?: string;
  timestampRecorded: string;
  metadata: Record<string, any>;
}

// API Response Types
export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T = any> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  totalPages: number;
}

// Form Types
export interface LoginForm {
  email: string;
  password: string;
}

export interface RegisterForm {
  email: string;
  password: string;
  confirmPassword: string;
  fullName: string;
}

export interface AiProviderForm {
  name: string;
  providerType: string;
  apiKey?: string;
  baseUrl?: string;
  defaultModel?: string;
  maxTokens: number;
  temperature: number;
  timeoutSeconds: number;
  rateLimitPerMinute: number;
  supportsVision: boolean;
  supportsAudio: boolean;
  configuration: Record<string, any>;
}

export interface VoiceSessionForm {
  sessionName?: string;
  aiProviderId?: string;
  aiModelId?: string;
  wakeWord?: string;
  languageCode: string;
  voiceFeedbackEnabled: boolean;
  continuousListening: boolean;
  screenMonitoringEnabled: boolean;
}

// Audio and Speech Types
export interface SpeechRecognitionResult {
  transcript: string;
  confidence: number;
  isFinal: boolean;
}

export interface TextToSpeechOptions {
  text: string;
  voice?: string;
  rate?: number;
  pitch?: number;
  volume?: number;
}

// Screen Analysis Types
export interface ScreenAnalysisResult {
  elements: DetectedElement[];
  text: string;
  actions: SuggestedAction[];
  confidence: number;
}

export interface DetectedElement {
  id: string;
  type: string;
  text?: string;
  bounds: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
  confidence: number;
  clickable: boolean;
}

export interface SuggestedAction {
  type: string;
  description: string;
  confidence: number;
  element?: DetectedElement;
}

// WebSocket Types
export interface WebSocketMessage {
  type: string;
  payload: any;
  timestamp: string;
}

export interface VoiceStreamMessage extends WebSocketMessage {
  type: 'voice_stream';
  payload: {
    audioData: ArrayBuffer;
    sessionId: string;
  };
}

export interface CommandMessage extends WebSocketMessage {
  type: 'command';
  payload: {
    commandText: string;
    sessionId: string;
  };
}

export interface ResponseMessage extends WebSocketMessage {
  type: 'response';
  payload: {
    response: string;
    sessionId: string;
    commandId: string;
  };
}
