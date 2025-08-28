# Voice Agent Platform

Enterprise-grade voice AI agent platform with real-time conversation capabilities, built with Next.js 14, TypeScript, and PostgreSQL.

## 🚀 Features

- **Complete Authentication System**: JWT-based auth with super admin capabilities
- **Admin Panel**: Full configuration management through intuitive UI
- **Real-time Communication**: WebSocket-powered live conversations
- **Responsive Design**: Mobile-first approach with perfect responsiveness
- **Clean Architecture**: SOLID principles with modular business logic
- **Production Ready**: Error handling, logging, and monitoring
- **Scalable Infrastructure**: Optimized for Vercel deployment

## 📋 Prerequisites

- Node.js 18+ 
- PostgreSQL 14+
- npm or yarn
- Vercel CLI (for deployment)

## 🛠️ Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/voice-agent-platform.git
cd voice-agent-platform
```

2. **Install dependencies**
```bash
npm install
```

3. **Set up environment variables**
```bash
cp .env.example .env.local
```

Edit `.env.local` with your configuration:
- Database credentials
- API keys (OpenAI, SendGrid, etc.)
- JWT secrets
- Other service configurations

4. **Set up the database**
```bash
# Generate Prisma client
npm run db:generate

# Run migrations
npm run db:migrate

# Seed the database with super admin
npm run db:seed
```

## 🔑 Default Credentials

After seeding, you can login with:

**Super Admin:**
- Email: `superadmin@voiceagent.com`
- Password: `SuperAdmin@2024!`

**Admin:**
- Email: `admin@voiceagent.com`
- Password: `Admin@2024!`

⚠️ **Important**: Change these passwords immediately after first login!

## 💻 Development

Run the development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the application.

## 🏗️ Project Structure

```
/workspace/
├── src/
│   ├── app/                 # Next.js app router pages
│   │   ├── (auth)/          # Authentication pages
│   │   ├── admin/           # Admin panel
│   │   ├── api/             # API routes
│   │   └── page.tsx         # Landing page
│   ├── components/          # React components
│   │   ├── ui/              # UI components
│   │   └── providers/       # Context providers
│   ├── lib/                 # Core libraries
│   │   ├── auth/            # Authentication utilities
│   │   ├── prisma.ts        # Database client
│   │   ├── errors.ts        # Error handling
│   │   ├── logger.ts        # Logging system
│   │   └── socket.ts        # WebSocket manager
│   ├── services/            # Business logic services
│   │   ├── user.service.ts  # User management
│   │   └── email.service.ts # Email service
│   └── styles/              # Global styles
├── prisma/
│   ├── schema.prisma        # Database schema
│   └── seed.ts              # Database seeding
├── public/                  # Static assets
├── package.json             # Dependencies
├── next.config.js           # Next.js configuration
├── tailwind.config.ts       # Tailwind CSS configuration
└── vercel.json              # Vercel deployment configuration
```

## 🚀 Deployment to Vercel

1. **Install Vercel CLI**
```bash
npm i -g vercel
```

2. **Configure environment variables in Vercel**

Go to your Vercel dashboard and add all environment variables from `.env.local`.

3. **Deploy**
```bash
vercel --prod
```

Or connect your GitHub repository to Vercel for automatic deployments.

## 📊 Database Management

The platform uses PostgreSQL with Prisma ORM. Key models include:

- **User**: User accounts with role-based access
- **VoiceAgent**: AI voice agents configuration
- **Conversation**: Chat/voice conversations
- **SystemConfig**: Dynamic system configuration
- **AuditLog**: Complete audit trail

### Migrations

Create a new migration:
```bash
npx prisma migrate dev --name your_migration_name
```

Apply migrations in production:
```bash
npx prisma migrate deploy
```

## 🔧 Admin Panel Features

The admin panel (`/admin`) provides:

- **Dashboard**: Real-time statistics and monitoring
- **User Management**: Create, edit, and manage users
- **System Configuration**: 
  - General settings
  - Authentication rules
  - AI provider configuration
  - Email service setup
  - Storage configuration
  - Billing settings
  - Security policies
- **Voice Agents**: Manage AI agents
- **Analytics**: Detailed usage analytics
- **Audit Logs**: Complete activity tracking
- **API Keys**: Manage API access
- **Webhooks**: Configure event webhooks

## 🛡️ Security Features

- **JWT Authentication**: Secure token-based auth
- **Role-Based Access Control**: Super Admin, Admin, Manager, User roles
- **Password Security**: Bcrypt hashing with strength validation
- **Rate Limiting**: API rate limiting per user/IP
- **Account Protection**: Failed login attempt tracking and account locking
- **Audit Logging**: Complete audit trail of all actions
- **CORS Configuration**: Proper CORS headers
- **Input Validation**: Zod schemas for all inputs
- **SQL Injection Prevention**: Prisma ORM with parameterized queries

## 📱 Responsive Design

The platform is fully responsive with:

- Mobile-first approach
- Touch-friendly interfaces
- Adaptive layouts
- Optimized images
- Progressive enhancement
- Offline capability (PWA ready)

## 🔄 Real-time Features

WebSocket-powered features include:

- Live conversations
- Typing indicators
- Online presence
- Real-time notifications
- Voice streaming
- Live agent status updates

## 📈 Monitoring & Logging

- **Structured Logging**: Comprehensive logging system
- **Error Tracking**: Detailed error capture and reporting
- **Performance Monitoring**: Request timing and bottleneck detection
- **Audit Trail**: User action tracking
- **Health Checks**: System health endpoints

## 🧪 Testing

Run tests:
```bash
npm test
```

Run tests in watch mode:
```bash
npm run test:watch
```

## 📦 API Documentation

API endpoints follow RESTful conventions:

- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration
- `GET /api/auth/me` - Get current user
- `GET /api/admin/*` - Admin endpoints (requires admin role)
- `GET /api/agents/*` - Voice agent management
- `GET /api/conversations/*` - Conversation management

All endpoints require authentication except login/register.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support, email support@voiceagent.com or open an issue in the repository.

## 🚦 Status

- ✅ Authentication System
- ✅ Admin Panel
- ✅ Database Schema
- ✅ API Endpoints
- ✅ Responsive UI
- ✅ Business Logic
- ✅ Error Handling
- ✅ WebSocket Support
- ✅ Vercel Deployment Ready

## 🔜 Roadmap

- [ ] AI Provider Integrations
- [ ] Voice Processing
- [ ] Advanced Analytics Dashboard
- [ ] Multi-language Support
- [ ] Mobile Apps
- [ ] Kubernetes Deployment
- [ ] GraphQL API
- [ ] Automated Testing Suite

---

Built with ❤️ using Next.js, TypeScript, and PostgreSQL