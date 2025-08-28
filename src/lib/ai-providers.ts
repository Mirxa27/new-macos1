import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';
import { GoogleGenerativeAI } from '@google/generative-ai';
import Groq from 'groq-sdk';
import { AiProvider, AiModel } from '@/types';

// Base interface for AI providers
interface AIProviderInterface {
  generateText(prompt: string, options?: any): Promise<string>;
  analyzeImage?(imageUrl: string, prompt: string): Promise<string>;
  streamText?(prompt: string, onChunk: (chunk: string) => void): Promise<void>;
}

// OpenAI Provider Implementation
export class OpenAIProvider implements AIProviderInterface {
  private client: OpenAI;
  private model: string;

  constructor(apiKey: string, model: string = 'gpt-4') {
    this.client = new OpenAI({ apiKey });
    this.model = model;
  }

  async generateText(prompt: string, options: any = {}): Promise<string> {
    try {
      const completion = await this.client.chat.completions.create({
        model: this.model,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: options.maxTokens || 4000,
        temperature: options.temperature || 0.7,
        ...options,
      });

      return completion.choices[0]?.message?.content || '';
    } catch (error) {
      console.error('OpenAI API error:', error);
      throw new Error('Failed to generate text with OpenAI');
    }
  }

  async analyzeImage(imageUrl: string, prompt: string): Promise<string> {
    try {
      const completion = await this.client.chat.completions.create({
        model: 'gpt-4-vision-preview',
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              { type: 'image_url', image_url: { url: imageUrl } },
            ],
          },
        ],
        max_tokens: 4000,
      });

      return completion.choices[0]?.message?.content || '';
    } catch (error) {
      console.error('OpenAI Vision API error:', error);
      throw new Error('Failed to analyze image with OpenAI Vision');
    }
  }

  async streamText(prompt: string, onChunk: (chunk: string) => void): Promise<void> {
    try {
      const stream = await this.client.chat.completions.create({
        model: this.model,
        messages: [{ role: 'user', content: prompt }],
        stream: true,
      });

      for await (const chunk of stream) {
        const content = chunk.choices[0]?.delta?.content || '';
        if (content) {
          onChunk(content);
        }
      }
    } catch (error) {
      console.error('OpenAI streaming error:', error);
      throw new Error('Failed to stream text with OpenAI');
    }
  }
}

// Anthropic Provider Implementation
export class AnthropicProvider implements AIProviderInterface {
  private client: Anthropic;
  private model: string;

  constructor(apiKey: string, model: string = 'claude-3-sonnet-20240229') {
    this.client = new Anthropic({ apiKey });
    this.model = model;
  }

  async generateText(prompt: string, options: any = {}): Promise<string> {
    try {
      const message = await this.client.messages.create({
        model: this.model,
        max_tokens: options.maxTokens || 4000,
        temperature: options.temperature || 0.7,
        messages: [{ role: 'user', content: prompt }],
      });

      return message.content[0]?.type === 'text' ? message.content[0].text : '';
    } catch (error) {
      console.error('Anthropic API error:', error);
      throw new Error('Failed to generate text with Anthropic');
    }
  }

  async analyzeImage(imageUrl: string, prompt: string): Promise<string> {
    try {
      // Fetch image and convert to base64
      const response = await fetch(imageUrl);
      const buffer = await response.arrayBuffer();
      const base64 = Buffer.from(buffer).toString('base64');
      const mediaType = response.headers.get('content-type') || 'image/jpeg';

      const message = await this.client.messages.create({
        model: this.model,
        max_tokens: 4000,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: prompt },
              {
                type: 'image',
                source: {
                  type: 'base64',
                  media_type: mediaType as any,
                  data: base64,
                },
              },
            ],
          },
        ],
      });

      return message.content[0]?.type === 'text' ? message.content[0].text : '';
    } catch (error) {
      console.error('Anthropic Vision API error:', error);
      throw new Error('Failed to analyze image with Anthropic');
    }
  }
}

// Google Gemini Provider Implementation
export class GoogleProvider implements AIProviderInterface {
  private client: GoogleGenerativeAI;
  private model: string;

  constructor(apiKey: string, model: string = 'gemini-pro') {
    this.client = new GoogleGenerativeAI(apiKey);
    this.model = model;
  }

  async generateText(prompt: string, options: any = {}): Promise<string> {
    try {
      const model = this.client.getGenerativeModel({ model: this.model });
      const result = await model.generateContent(prompt);
      const response = await result.response;
      return response.text();
    } catch (error) {
      console.error('Google AI API error:', error);
      throw new Error('Failed to generate text with Google AI');
    }
  }

  async analyzeImage(imageUrl: string, prompt: string): Promise<string> {
    try {
      const model = this.client.getGenerativeModel({ model: 'gemini-pro-vision' });
      
      // Fetch image
      const response = await fetch(imageUrl);
      const buffer = await response.arrayBuffer();
      const mimeType = response.headers.get('content-type') || 'image/jpeg';

      const imagePart = {
        inlineData: {
          data: Buffer.from(buffer).toString('base64'),
          mimeType,
        },
      };

      const result = await model.generateContent([prompt, imagePart]);
      const responseText = await result.response;
      return responseText.text();
    } catch (error) {
      console.error('Google Vision API error:', error);
      throw new Error('Failed to analyze image with Google Vision');
    }
  }
}

// Groq Provider Implementation
export class GroqProvider implements AIProviderInterface {
  private client: Groq;
  private model: string;

  constructor(apiKey: string, model: string = 'mixtral-8x7b-32768') {
    this.client = new Groq({ apiKey });
    this.model = model;
  }

  async generateText(prompt: string, options: any = {}): Promise<string> {
    try {
      const completion = await this.client.chat.completions.create({
        model: this.model,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: options.maxTokens || 4000,
        temperature: options.temperature || 0.7,
      });

      return completion.choices[0]?.message?.content || '';
    } catch (error) {
      console.error('Groq API error:', error);
      throw new Error('Failed to generate text with Groq');
    }
  }
}

// Ollama Provider Implementation (for local models)
export class OllamaProvider implements AIProviderInterface {
  private baseUrl: string;
  private model: string;

  constructor(baseUrl: string = 'http://localhost:11434', model: string = 'llama2') {
    this.baseUrl = baseUrl;
    this.model = model;
  }

  async generateText(prompt: string, options: any = {}): Promise<string> {
    try {
      const response = await fetch(`${this.baseUrl}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: this.model,
          prompt,
          stream: false,
          options: {
            temperature: options.temperature || 0.7,
            num_predict: options.maxTokens || 4000,
          },
        }),
      });

      if (!response.ok) {
        throw new Error(`Ollama API error: ${response.statusText}`);
      }

      const data = await response.json();
      return data.response || '';
    } catch (error) {
      console.error('Ollama API error:', error);
      throw new Error('Failed to generate text with Ollama');
    }
  }

  async analyzeImage(imageUrl: string, prompt: string): Promise<string> {
    try {
      // Fetch image and convert to base64
      const response = await fetch(imageUrl);
      const buffer = await response.arrayBuffer();
      const base64 = Buffer.from(buffer).toString('base64');

      const ollamaResponse = await fetch(`${this.baseUrl}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: 'llava', // Use LLaVA model for vision
          prompt,
          images: [base64],
          stream: false,
        }),
      });

      if (!ollamaResponse.ok) {
        throw new Error(`Ollama Vision API error: ${ollamaResponse.statusText}`);
      }

      const data = await ollamaResponse.json();
      return data.response || '';
    } catch (error) {
      console.error('Ollama Vision API error:', error);
      throw new Error('Failed to analyze image with Ollama');
    }
  }
}

// AI Provider Factory
export class AIProviderFactory {
  static createProvider(provider: AiProvider, model?: AiModel): AIProviderInterface {
    const apiKey = process.env[`${provider.providerType.toUpperCase()}_API_KEY`] || '';
    const modelName = model?.modelName || provider.defaultModel || '';

    switch (provider.providerType) {
      case 'openai':
        return new OpenAIProvider(apiKey, modelName);
      case 'anthropic':
        return new AnthropicProvider(apiKey, modelName);
      case 'google':
        return new GoogleProvider(apiKey, modelName);
      case 'groq':
        return new GroqProvider(apiKey, modelName);
      case 'ollama':
        return new OllamaProvider(provider.baseUrl || 'http://localhost:11434', modelName);
      default:
        throw new Error(`Unsupported provider type: ${provider.providerType}`);
    }
  }
}

// Utility functions for AI operations
export async function processVoiceCommand(
  command: string,
  provider: AiProvider,
  model?: AiModel,
  context?: any
): Promise<{ response: string; actions: any[] }> {
  const aiProvider = AIProviderFactory.createProvider(provider, model);
  
  const systemPrompt = `You are a voice assistant that helps users control their computer through natural language commands. 
Analyze the user's command and provide:
1. A natural response to the user
2. Specific system actions to execute (if any)

Available actions: click, type, key_press, scroll, app_launch, window_control, system_command

Context: ${context ? JSON.stringify(context) : 'None'}

User command: ${command}

Respond in JSON format:
{
  "response": "Natural language response to user",
  "actions": [
    {
      "type": "action_type",
      "description": "What this action does",
      "parameters": {
        // Action-specific parameters
      }
    }
  ]
}`;

  try {
    const result = await aiProvider.generateText(systemPrompt);
    const parsed = JSON.parse(result);
    return {
      response: parsed.response || 'I understand your request.',
      actions: parsed.actions || []
    };
  } catch (error) {
    console.error('Error processing voice command:', error);
    return {
      response: 'I had trouble processing that command. Could you try rephrasing it?',
      actions: []
    };
  }
}

export async function analyzeScreen(
  imageUrl: string,
  provider: AiProvider,
  model?: AiModel,
  query?: string
): Promise<any> {
  const aiProvider = AIProviderFactory.createProvider(provider, model);
  
  if (!aiProvider.analyzeImage) {
    throw new Error('This provider does not support image analysis');
  }

  const prompt = query || `Analyze this screen capture and provide:
1. A description of what's visible
2. Interactive elements (buttons, links, text fields, etc.)
3. Suggested actions the user might want to take

Respond in JSON format with detected elements and their coordinates if possible.`;

  try {
    const result = await aiProvider.analyzeImage(imageUrl, prompt);
    return JSON.parse(result);
  } catch (error) {
    console.error('Error analyzing screen:', error);
    return {
      description: 'Unable to analyze screen capture',
      elements: [],
      suggestions: []
    };
  }
}
