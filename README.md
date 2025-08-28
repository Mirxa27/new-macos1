# Voice Agent Pro - Web Application

A comprehensive full-stack voice-controlled AI assistant web application with advanced features for productivity and automation.

## 🚀 Features

### Voice & AI Capabilities
- **Multi-Provider AI Support**: OpenAI, Anthropic, Google Gemini, Groq, and Ollama
- **Real-time Voice Recognition**: Continuous speech processing with WebRTC
- **Text-to-Speech**: Natural voice responses with customizable voices
- **Vision Analysis**: AI-powered screen capture analysis and understanding
- **Live Audio Streaming**: Real-time bidirectional audio with Gemini Live API

### Web Application Features
- **Responsive Design**: Mobile-first approach with full cross-device compatibility
- **Admin Panel**: Comprehensive management dashboard for all configurations
- **User Management**: Role-based access control (Super Admin, Admin, User)
- **Session Monitoring**: Real-time tracking of voice sessions and commands
- **Analytics Dashboard**: Performance metrics and usage statistics
- **API Management**: RESTful APIs for all functionality

### System Integration
- **Screen Control**: Click, type, scroll, and application control
- **Automation Scripts**: Custom workflow creation and execution
- **Real-time Notifications**: WebSocket-based live updates
- **File Management**: Upload, storage, and processing capabilities
- **Database Integration**: PostgreSQL with Prisma ORM

## 🛠 Technology Stack

### Frontend
- **Next.js 14**: React framework with App Router
- **TypeScript**: Type-safe development
- **Tailwind CSS**: Utility-first styling with custom components
- **Framer Motion**: Smooth animations and transitions
- **Radix UI**: Accessible component primitives
- **React Hook Form**: Form validation and management

### Backend
- **Next.js API Routes**: Serverless functions
- **NextAuth.js**: Authentication and session management
- **Prisma**: Type-safe database ORM
- **PostgreSQL**: Primary database
- **Socket.io**: Real-time communication
- **WebRTC**: Voice streaming and recording

### AI & Voice
- **OpenAI SDK**: GPT models and vision
- **Anthropic SDK**: Claude models
- **Google Generative AI**: Gemini models
- **Groq SDK**: Fast inference
- **Web Speech API**: Browser-native speech recognition

### Deployment
- **Vercel**: Production hosting and deployment
- **Vercel Postgres**: Managed database
- **Environment Variables**: Secure configuration management

## 📋 Prerequisites

- Node.js 18+ and npm
- PostgreSQL database (or Vercel Postgres)
- AI Provider API keys (OpenAI, Anthropic, etc.)

## 🚀 Quick Start

### 1. Clone and Install

```bash
git clone <repository-url>
cd voice-agent-web
npm install
```

### 2. Environment Setup

```bash
cp .env.example .env.local
```

Update `.env.local` with your configuration:

```env
# Database
DATABASE_URL="your-postgresql-connection-string"
POSTGRES_URL="your-postgresql-connection-string"

# Authentication
NEXTAUTH_SECRET="your-secure-random-string"
NEXTAUTH_URL="http://localhost:3000"

# AI Provider API Keys
OPENAI_API_KEY="your-openai-api-key"
ANTHROPIC_API_KEY="your-anthropic-api-key"
GOOGLE_API_KEY="your-google-api-key"
GROQ_API_KEY="your-groq-api-key"

# Security
ENCRYPTION_KEY="your-32-character-encryption-key"
```

### 3. Database Setup

```bash
# Generate Prisma client
npx prisma generate

# Run database migrations
npx prisma db push

# Seed initial data (optional)
npx prisma db seed
```

### 4. Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### 5. Default Admin Login

```
Email: admin@voiceagent.com
Password: SuperAdmin123!
```

## 📁 Project Structure

```
voice-agent-web/
├── src/
│   ├── app/                    # Next.js App Router
│   │   ├── api/               # API routes
│   │   ├── admin/             # Admin panel pages
│   │   ├── login/             # Authentication pages
│   │   └── globals.css        # Global styles
│   ├── components/            # Reusable components
│   │   ├── ui/               # Base UI components
│   │   ├── admin/            # Admin-specific components
│   │   ├── voice/            # Voice assistant components
│   │   └── layout/           # Layout components
│   ├── lib/                  # Utility libraries
│   │   ├── auth.ts           # Authentication logic
│   │   ├── db.ts             # Database connection
│   │   ├── ai-providers.ts   # AI provider implementations
│   │   └── utils.ts          # General utilities
│   ├── types/                # TypeScript type definitions
│   └── hooks/                # Custom React hooks
├── prisma/
│   └── schema.prisma         # Database schema
├── public/                   # Static assets
├── vercel.json              # Vercel deployment config
└── package.json             # Dependencies and scripts
```

## 🔧 Configuration

### AI Providers

Configure AI providers in the admin panel:

1. Navigate to `/admin`
2. Go to "AI Providers" tab
3. Add/edit provider configurations
4. Set API keys, models, and parameters

### User Management

Manage users through the admin interface:

1. Create new users
2. Assign roles (Super Admin, Admin, User)
3. Monitor user activity
4. Manage permissions

### System Settings

Configure system-wide settings:

1. Default AI provider and model
2. Session timeouts and limits
3. File upload restrictions
4. Feature toggles

## 🌐 Deployment to Vercel

### 1. Prepare for Deployment

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login
```

### 2. Configure Environment Variables

Add these environment variables in your Vercel dashboard:

- `DATABASE_URL`
- `NEXTAUTH_SECRET`
- `NEXTAUTH_URL`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GOOGLE_API_KEY`
- `GROQ_API_KEY`
- `ENCRYPTION_KEY`

### 3. Deploy

```bash
# Deploy to Vercel
vercel --prod
```

### 4. Database Migration

After deployment, run database migrations:

```bash
# Connect to your production database
npx prisma db push --preview-feature
```

## 📱 Mobile Optimization

The application is fully optimized for mobile devices:

- **Touch-First Design**: Large touch targets (44px minimum)
- **Responsive Layout**: Adapts to all screen sizes
- **Mobile Navigation**: Bottom navigation bar for mobile
- **Gesture Support**: Swipe and touch gestures
- **Performance Optimized**: Lazy loading and code splitting

## 🔒 Security Features

- **Role-Based Access Control**: Fine-grained permissions
- **Encrypted API Keys**: Secure storage of sensitive data
- **Session Management**: Secure authentication with NextAuth.js
- **Input Validation**: Comprehensive validation with Zod
- **CSRF Protection**: Built-in CSRF protection
- **Rate Limiting**: API rate limiting and abuse prevention

## 🎯 API Endpoints

### Authentication
- `POST /api/auth/signin` - User login
- `POST /api/auth/signout` - User logout
- `GET /api/auth/session` - Get current session

### Voice Sessions
- `GET /api/sessions` - List voice sessions
- `POST /api/sessions` - Create new session
- `PUT /api/sessions/:id` - Update session
- `DELETE /api/sessions/:id` - Delete session

### Voice Commands
- `GET /api/commands` - List commands
- `POST /api/commands` - Create command
- `GET /api/commands/:id` - Get command details

### Admin
- `GET /api/admin/users` - List users
- `POST /api/admin/users` - Create user
- `PUT /api/admin/users/:id` - Update user
- `DELETE /api/admin/users/:id` - Delete user

### AI Providers
- `GET /api/providers` - List AI providers
- `POST /api/providers` - Create provider
- `PUT /api/providers/:id` - Update provider
- `DELETE /api/providers/:id` - Delete provider

## 🧪 Testing

```bash
# Run type checking
npm run type-check

# Run linting
npm run lint

# Run tests (when implemented)
npm run test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

1. Check the documentation
2. Search existing issues
3. Create a new issue with detailed information
4. Contact support at admin@voiceagent.com

## 🚧 Roadmap

- [ ] Multi-language support
- [ ] Plugin system for extensions
- [ ] Advanced automation workflows
- [ ] Integration with external services
- [ ] Mobile app companion
- [ ] Voice training and customization
- [ ] Advanced analytics and reporting
- [ ] Team collaboration features

---

Built with ❤️ using Next.js, TypeScript, and modern web technologies.
