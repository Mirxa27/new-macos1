import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('Starting database seeding...');

  // Create Super Admin user
  const hashedPassword = await bcrypt.hash('SuperAdmin123!', 12);
  
  const superAdmin = await prisma.user.upsert({
    where: { email: 'admin@voiceagent.com' },
    update: {},
    create: {
      email: 'admin@voiceagent.com',
      passwordHash: hashedPassword,
      fullName: 'Super Administrator',
      role: 'SUPER_ADMIN',
      isActive: true,
      emailVerified: true,
    },
  });

  console.log('Created super admin user:', superAdmin.email);

  // Create default AI providers
  const providers = [
    {
      name: 'OpenAI',
      providerType: 'OPENAI' as const,
      baseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4',
      supportsVision: true,
      supportsAudio: true,
      configuration: { organization: '', project: '' },
    },
    {
      name: 'Anthropic',
      providerType: 'ANTHROPIC' as const,
      baseUrl: 'https://api.anthropic.com',
      defaultModel: 'claude-3-sonnet-20240229',
      supportsVision: true,
      supportsAudio: false,
      configuration: { version: '2023-06-01' },
    },
    {
      name: 'Google Gemini',
      providerType: 'GOOGLE' as const,
      baseUrl: 'https://generativelanguage.googleapis.com',
      defaultModel: 'gemini-pro',
      supportsVision: true,
      supportsAudio: true,
      configuration: { version: 'v1' },
    },
    {
      name: 'Groq',
      providerType: 'GROQ' as const,
      baseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'mixtral-8x7b-32768',
      supportsVision: false,
      supportsAudio: false,
      configuration: {},
    },
    {
      name: 'Ollama',
      providerType: 'OLLAMA' as const,
      baseUrl: 'http://localhost:11434',
      defaultModel: 'llama2',
      supportsVision: true,
      supportsAudio: false,
      configuration: { keep_alive: '5m' },
    },
  ];

  for (const provider of providers) {
    const createdProvider = await prisma.aiProvider.upsert({
      where: { name: provider.name },
      update: {},
      create: {
        ...provider,
        createdBy: superAdmin.id,
      },
    });

    console.log('Created AI provider:', createdProvider.name);

    // Create default models for each provider
    const models = getModelsForProvider(provider.name);
    for (const model of models) {
      await prisma.aiModel.upsert({
        where: {
          providerId_modelName: {
            providerId: createdProvider.id,
            modelName: model.modelName,
          },
        },
        update: {},
        create: {
          ...model,
          providerId: createdProvider.id,
        },
      });
    }

    console.log(`Created ${models.length} models for ${provider.name}`);
  }

  // Create system configurations
  const configs = [
    {
      configKey: 'app_name',
      configValue: 'Voice Agent Pro',
      dataType: 'STRING' as const,
      description: 'Application name',
      isPublic: true,
      category: 'general',
    },
    {
      configKey: 'app_version',
      configValue: '1.0.0',
      dataType: 'STRING' as const,
      description: 'Application version',
      isPublic: true,
      category: 'general',
    },
    {
      configKey: 'max_session_duration_hours',
      configValue: '8',
      dataType: 'NUMBER' as const,
      description: 'Maximum session duration in hours',
      isPublic: false,
      category: 'limits',
    },
    {
      configKey: 'max_daily_commands',
      configValue: '1000',
      dataType: 'NUMBER' as const,
      description: 'Maximum commands per user per day',
      isPublic: false,
      category: 'limits',
    },
    {
      configKey: 'default_ai_provider',
      configValue: 'openai',
      dataType: 'STRING' as const,
      description: 'Default AI provider for new users',
      isPublic: false,
      category: 'ai',
    },
    {
      configKey: 'enable_screen_monitoring',
      configValue: 'true',
      dataType: 'BOOLEAN' as const,
      description: 'Enable screen monitoring by default',
      isPublic: false,
      category: 'features',
    },
    {
      configKey: 'enable_voice_feedback',
      configValue: 'true',
      dataType: 'BOOLEAN' as const,
      description: 'Enable voice feedback by default',
      isPublic: false,
      category: 'features',
    },
    {
      configKey: 'default_language',
      configValue: 'en-US',
      dataType: 'STRING' as const,
      description: 'Default language for speech recognition',
      isPublic: false,
      category: 'speech',
    },
    {
      configKey: 'max_file_upload_size_mb',
      configValue: '10',
      dataType: 'NUMBER' as const,
      description: 'Maximum file upload size in MB',
      isPublic: false,
      category: 'limits',
    },
    {
      configKey: 'session_timeout_minutes',
      configValue: '30',
      dataType: 'NUMBER' as const,
      description: 'Session timeout in minutes',
      isPublic: false,
      category: 'security',
    },
  ];

  for (const config of configs) {
    await prisma.systemConfiguration.upsert({
      where: { configKey: config.configKey },
      update: {},
      create: {
        ...config,
        createdBy: superAdmin.id,
      },
    });
  }

  console.log(`Created ${configs.length} system configurations`);

  // Create demo user preferences
  const preferences = [
    {
      preferenceKey: 'theme',
      preferenceValue: 'system',
      dataType: 'STRING' as const,
    },
    {
      preferenceKey: 'language',
      preferenceValue: 'en-US',
      dataType: 'STRING' as const,
    },
    {
      preferenceKey: 'voice_feedback_enabled',
      preferenceValue: 'true',
      dataType: 'BOOLEAN' as const,
    },
    {
      preferenceKey: 'wake_word',
      preferenceValue: 'hey assistant',
      dataType: 'STRING' as const,
    },
  ];

  for (const pref of preferences) {
    await prisma.userPreference.upsert({
      where: {
        userId_preferenceKey: {
          userId: superAdmin.id,
          preferenceKey: pref.preferenceKey,
        },
      },
      update: {},
      create: {
        ...pref,
        userId: superAdmin.id,
      },
    });
  }

  console.log(`Created ${preferences.length} user preferences`);

  console.log('Database seeding completed successfully!');
}

function getModelsForProvider(providerName: string) {
  switch (providerName) {
    case 'OpenAI':
      return [
        {
          modelName: 'gpt-4',
          displayName: 'GPT-4',
          modelType: 'TEXT' as const,
          maxTokens: 8192,
          costPer1kInputTokens: 0.03,
          costPer1kOutputTokens: 0.06,
        },
        {
          modelName: 'gpt-4-vision-preview',
          displayName: 'GPT-4 Vision',
          modelType: 'VISION' as const,
          maxTokens: 4096,
          costPer1kInputTokens: 0.01,
          costPer1kOutputTokens: 0.03,
        },
        {
          modelName: 'gpt-3.5-turbo',
          displayName: 'GPT-3.5 Turbo',
          modelType: 'TEXT' as const,
          maxTokens: 4096,
          costPer1kInputTokens: 0.001,
          costPer1kOutputTokens: 0.002,
        },
      ];
    case 'Anthropic':
      return [
        {
          modelName: 'claude-3-sonnet-20240229',
          displayName: 'Claude 3 Sonnet',
          modelType: 'TEXT' as const,
          maxTokens: 200000,
          costPer1kInputTokens: 0.003,
          costPer1kOutputTokens: 0.015,
        },
        {
          modelName: 'claude-3-opus-20240229',
          displayName: 'Claude 3 Opus',
          modelType: 'TEXT' as const,
          maxTokens: 200000,
          costPer1kInputTokens: 0.015,
          costPer1kOutputTokens: 0.075,
        },
        {
          modelName: 'claude-3-haiku-20240307',
          displayName: 'Claude 3 Haiku',
          modelType: 'TEXT' as const,
          maxTokens: 200000,
          costPer1kInputTokens: 0.00025,
          costPer1kOutputTokens: 0.00125,
        },
      ];
    case 'Google Gemini':
      return [
        {
          modelName: 'gemini-pro',
          displayName: 'Gemini Pro',
          modelType: 'TEXT' as const,
          maxTokens: 32768,
          costPer1kInputTokens: 0.0005,
          costPer1kOutputTokens: 0.0015,
        },
        {
          modelName: 'gemini-pro-vision',
          displayName: 'Gemini Pro Vision',
          modelType: 'VISION' as const,
          maxTokens: 16384,
          costPer1kInputTokens: 0.0005,
          costPer1kOutputTokens: 0.0015,
        },
      ];
    case 'Groq':
      return [
        {
          modelName: 'mixtral-8x7b-32768',
          displayName: 'Mixtral 8x7B',
          modelType: 'TEXT' as const,
          maxTokens: 32768,
          costPer1kInputTokens: 0.0002,
          costPer1kOutputTokens: 0.0002,
        },
      ];
    case 'Ollama':
      return [
        {
          modelName: 'llama2',
          displayName: 'Llama 2',
          modelType: 'TEXT' as const,
          maxTokens: 4096,
          costPer1kInputTokens: 0,
          costPer1kOutputTokens: 0,
        },
        {
          modelName: 'llava',
          displayName: 'LLaVA',
          modelType: 'VISION' as const,
          maxTokens: 4096,
          costPer1kInputTokens: 0,
          costPer1kOutputTokens: 0,
        },
      ];
    default:
      return [];
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
