import { PrismaClient, UserRole, UserStatus, BillingPlan } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Starting database seed...');

  // Create Super Admin
  const superAdminPassword = await bcrypt.hash('SuperAdmin@2024!', 12);
  const superAdmin = await prisma.user.upsert({
    where: { email: 'superadmin@voiceagent.com' },
    update: {},
    create: {
      email: 'superadmin@voiceagent.com',
      username: 'superadmin',
      password: superAdminPassword,
      firstName: 'Super',
      lastName: 'Admin',
      role: UserRole.SUPER_ADMIN,
      status: UserStatus.ACTIVE,
      emailVerified: true,
      emailVerifiedAt: new Date(),
    },
  });

  console.log('✅ Created Super Admin:', superAdmin.email);

  // Create System Configurations
  const systemConfigs = [
    {
      key: 'app.name',
      value: JSON.stringify('Voice Agent Platform'),
      category: 'general',
      description: 'Application name',
      isEditable: true,
    },
    {
      key: 'app.version',
      value: JSON.stringify('1.0.0'),
      category: 'general',
      description: 'Application version',
      isEditable: false,
    },
    {
      key: 'app.maintenance_mode',
      value: JSON.stringify(false),
      category: 'general',
      description: 'Enable maintenance mode',
      isEditable: true,
    },
    {
      key: 'auth.session_duration',
      value: JSON.stringify(86400), // 24 hours in seconds
      category: 'authentication',
      description: 'Session duration in seconds',
      isEditable: true,
    },
    {
      key: 'auth.max_login_attempts',
      value: JSON.stringify(5),
      category: 'authentication',
      description: 'Maximum failed login attempts before account lock',
      isEditable: true,
    },
    {
      key: 'auth.lockout_duration',
      value: JSON.stringify(900), // 15 minutes in seconds
      category: 'authentication',
      description: 'Account lockout duration in seconds',
      isEditable: true,
    },
    {
      key: 'auth.password_min_length',
      value: JSON.stringify(8),
      category: 'authentication',
      description: 'Minimum password length',
      isEditable: true,
    },
    {
      key: 'auth.require_email_verification',
      value: JSON.stringify(true),
      category: 'authentication',
      description: 'Require email verification for new accounts',
      isEditable: true,
    },
    {
      key: 'api.rate_limit_default',
      value: JSON.stringify(1000),
      category: 'api',
      description: 'Default API rate limit per hour',
      isEditable: true,
    },
    {
      key: 'api.rate_limit_window',
      value: JSON.stringify(3600),
      category: 'api',
      description: 'Rate limit window in seconds',
      isEditable: true,
    },
    {
      key: 'ai.default_provider',
      value: JSON.stringify('OPENAI'),
      category: 'ai',
      description: 'Default AI provider',
      isEditable: true,
    },
    {
      key: 'ai.openai_api_key',
      value: JSON.stringify(''),
      category: 'ai',
      description: 'OpenAI API Key',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'ai.anthropic_api_key',
      value: JSON.stringify(''),
      category: 'ai',
      description: 'Anthropic API Key',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'ai.google_api_key',
      value: JSON.stringify(''),
      category: 'ai',
      description: 'Google AI API Key',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'ai.default_model',
      value: JSON.stringify('gpt-4-turbo-preview'),
      category: 'ai',
      description: 'Default AI model',
      isEditable: true,
    },
    {
      key: 'ai.max_tokens',
      value: JSON.stringify(2000),
      category: 'ai',
      description: 'Maximum tokens per request',
      isEditable: true,
    },
    {
      key: 'ai.temperature',
      value: JSON.stringify(0.7),
      category: 'ai',
      description: 'Default temperature for AI responses',
      isEditable: true,
    },
    {
      key: 'storage.provider',
      value: JSON.stringify('s3'),
      category: 'storage',
      description: 'Storage provider (s3, local, cloudinary)',
      isEditable: true,
    },
    {
      key: 'storage.s3_bucket',
      value: JSON.stringify(''),
      category: 'storage',
      description: 'S3 bucket name',
      isEditable: true,
    },
    {
      key: 'storage.s3_region',
      value: JSON.stringify('us-east-1'),
      category: 'storage',
      description: 'S3 region',
      isEditable: true,
    },
    {
      key: 'storage.s3_access_key',
      value: JSON.stringify(''),
      category: 'storage',
      description: 'S3 access key',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'storage.s3_secret_key',
      value: JSON.stringify(''),
      category: 'storage',
      description: 'S3 secret key',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'email.provider',
      value: JSON.stringify('sendgrid'),
      category: 'email',
      description: 'Email service provider',
      isEditable: true,
    },
    {
      key: 'email.from_address',
      value: JSON.stringify('noreply@voiceagent.com'),
      category: 'email',
      description: 'Default from email address',
      isEditable: true,
    },
    {
      key: 'email.from_name',
      value: JSON.stringify('Voice Agent Platform'),
      category: 'email',
      description: 'Default from name',
      isEditable: true,
    },
    {
      key: 'email.sendgrid_api_key',
      value: JSON.stringify(''),
      category: 'email',
      description: 'SendGrid API key',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'webhook.timeout',
      value: JSON.stringify(30),
      category: 'webhook',
      description: 'Webhook timeout in seconds',
      isEditable: true,
    },
    {
      key: 'webhook.retry_count',
      value: JSON.stringify(3),
      category: 'webhook',
      description: 'Number of webhook retry attempts',
      isEditable: true,
    },
    {
      key: 'webhook.retry_delay',
      value: JSON.stringify(60),
      category: 'webhook',
      description: 'Delay between retry attempts in seconds',
      isEditable: true,
    },
    {
      key: 'billing.stripe_public_key',
      value: JSON.stringify(''),
      category: 'billing',
      description: 'Stripe publishable key',
      isEditable: true,
    },
    {
      key: 'billing.stripe_secret_key',
      value: JSON.stringify(''),
      category: 'billing',
      description: 'Stripe secret key',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'billing.stripe_webhook_secret',
      value: JSON.stringify(''),
      category: 'billing',
      description: 'Stripe webhook secret',
      isSecret: true,
      isEditable: true,
    },
    {
      key: 'limits.free.max_agents',
      value: JSON.stringify(1),
      category: 'limits',
      description: 'Maximum agents for free plan',
      isEditable: true,
    },
    {
      key: 'limits.free.max_conversations',
      value: JSON.stringify(100),
      category: 'limits',
      description: 'Maximum conversations per month for free plan',
      isEditable: true,
    },
    {
      key: 'limits.starter.max_agents',
      value: JSON.stringify(5),
      category: 'limits',
      description: 'Maximum agents for starter plan',
      isEditable: true,
    },
    {
      key: 'limits.starter.max_conversations',
      value: JSON.stringify(1000),
      category: 'limits',
      description: 'Maximum conversations per month for starter plan',
      isEditable: true,
    },
    {
      key: 'limits.professional.max_agents',
      value: JSON.stringify(20),
      category: 'limits',
      description: 'Maximum agents for professional plan',
      isEditable: true,
    },
    {
      key: 'limits.professional.max_conversations',
      value: JSON.stringify(10000),
      category: 'limits',
      description: 'Maximum conversations per month for professional plan',
      isEditable: true,
    },
    {
      key: 'analytics.enable_tracking',
      value: JSON.stringify(true),
      category: 'analytics',
      description: 'Enable analytics tracking',
      isEditable: true,
    },
    {
      key: 'analytics.google_analytics_id',
      value: JSON.stringify(''),
      category: 'analytics',
      description: 'Google Analytics tracking ID',
      isEditable: true,
    },
    {
      key: 'security.enable_2fa',
      value: JSON.stringify(true),
      category: 'security',
      description: 'Enable two-factor authentication',
      isEditable: true,
    },
    {
      key: 'security.cors_origins',
      value: JSON.stringify(['http://localhost:3000', 'https://voiceagent.vercel.app']),
      category: 'security',
      description: 'Allowed CORS origins',
      isEditable: true,
    },
    {
      key: 'security.jwt_secret',
      value: JSON.stringify(process.env.JWT_SECRET || 'your-secret-key-change-in-production'),
      category: 'security',
      description: 'JWT secret key',
      isSecret: true,
      isEditable: false,
    },
  ];

  for (const config of systemConfigs) {
    await prisma.systemConfig.upsert({
      where: { key: config.key },
      update: {
        value: config.value,
        description: config.description,
      },
      create: config,
    });
  }

  console.log('✅ Created system configurations');

  // Create demo admin user
  const adminPassword = await bcrypt.hash('Admin@2024!', 12);
  const adminUser = await prisma.user.upsert({
    where: { email: 'admin@voiceagent.com' },
    update: {},
    create: {
      email: 'admin@voiceagent.com',
      username: 'admin',
      password: adminPassword,
      firstName: 'Admin',
      lastName: 'User',
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
      emailVerified: true,
      emailVerifiedAt: new Date(),
    },
  });

  console.log('✅ Created Admin user:', adminUser.email);

  // Create demo team
  const demoTeam = await prisma.team.create({
    data: {
      name: 'Demo Team',
      slug: 'demo-team',
      description: 'Demo team for testing',
      ownerId: adminUser.id,
      billingPlan: BillingPlan.PROFESSIONAL,
      maxMembers: 50,
      maxAgents: 20,
      maxApiCalls: 100000,
      members: {
        create: {
          userId: adminUser.id,
          role: 'OWNER',
        },
      },
    },
  });

  console.log('✅ Created demo team:', demoTeam.name);

  // Create sample voice agent
  const sampleAgent = await prisma.voiceAgent.create({
    data: {
      name: 'Assistant Pro',
      description: 'Professional AI assistant for customer support',
      voice: 'alloy',
      language: 'en-US',
      personality: 'Professional, friendly, and helpful',
      systemPrompt: 'You are a professional AI assistant. Be helpful, concise, and friendly.',
      temperature: 0.7,
      maxTokens: 2000,
      provider: 'OPENAI',
      modelName: 'gpt-4-turbo-preview',
      status: 'ACTIVE',
      isPublic: true,
      userId: adminUser.id,
      teamId: demoTeam.id,
      capabilities: JSON.stringify([
        'conversation',
        'translation',
        'summarization',
        'sentiment-analysis',
        'code-generation',
      ]),
      tools: JSON.stringify([
        {
          name: 'web_search',
          description: 'Search the web for information',
          enabled: true,
        },
        {
          name: 'calculator',
          description: 'Perform mathematical calculations',
          enabled: true,
        },
        {
          name: 'weather',
          description: 'Get weather information',
          enabled: true,
        },
      ]),
      publishedAt: new Date(),
    },
  });

  console.log('✅ Created sample voice agent:', sampleAgent.name);

  console.log('🎉 Database seed completed successfully!');
  console.log('\n📝 Login Credentials:');
  console.log('Super Admin: superadmin@voiceagent.com / SuperAdmin@2024!');
  console.log('Admin: admin@voiceagent.com / Admin@2024!');
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });