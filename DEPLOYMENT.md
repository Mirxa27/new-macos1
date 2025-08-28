# Deployment Guide - Voice Agent Pro

This guide provides step-by-step instructions for deploying Voice Agent Pro to Vercel with a PostgreSQL database.

## 🚀 Quick Deployment

### Prerequisites
- Vercel account
- PostgreSQL database (Vercel Postgres recommended)
- AI Provider API keys

### 1. Database Setup

#### Option A: Vercel Postgres (Recommended)
1. Go to your Vercel dashboard
2. Create a new Postgres database
3. Copy the connection string

#### Option B: External PostgreSQL
1. Use any PostgreSQL provider (AWS RDS, DigitalOcean, etc.)
2. Ensure the database is accessible from Vercel
3. Get the connection string

### 2. Environment Variables

Set these environment variables in your Vercel project:

```bash
# Database
DATABASE_URL="postgresql://username:password@host:port/database"
POSTGRES_URL="postgresql://username:password@host:port/database"

# Authentication (generate with: openssl rand -base64 32)
NEXTAUTH_SECRET="your-secure-random-string-32-chars-min"
NEXTAUTH_URL="https://your-domain.vercel.app"

# AI Provider API Keys
OPENAI_API_KEY="sk-..."
ANTHROPIC_API_KEY="sk-ant-..."
GOOGLE_API_KEY="AIza..."
GROQ_API_KEY="gsk_..."

# Security (generate with: openssl rand -hex 32)
ENCRYPTION_KEY="your-32-character-encryption-key"

# Optional
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"
```

### 3. Deploy to Vercel

#### Method 1: GitHub Integration (Recommended)
1. Push code to GitHub repository
2. Connect repository to Vercel
3. Configure environment variables
4. Deploy automatically

#### Method 2: Vercel CLI
```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Deploy
vercel --prod
```

### 4. Database Migration

After deployment, run database migrations:

```bash
# Using Vercel CLI
vercel env pull .env.local
npx prisma generate
npx prisma db push

# Seed initial data
npx prisma db seed
```

### 5. Verify Deployment

1. Visit your deployment URL
2. Check health endpoint: `https://your-domain.vercel.app/api/health`
3. Login with admin credentials:
   - Email: `admin@voiceagent.com`
   - Password: `SuperAdmin123!`

## 🔧 Advanced Configuration

### Custom Domain

1. Go to Vercel project settings
2. Add your domain
3. Configure DNS records
4. Update `NEXTAUTH_URL` environment variable

### SSL/TLS

Vercel provides automatic SSL certificates. For custom domains:
1. Verify domain ownership
2. SSL certificate is automatically provisioned
3. Ensure all traffic uses HTTPS

### Performance Optimization

1. **Edge Functions**: API routes run on Vercel's Edge Network
2. **Static Generation**: Pages are pre-built when possible
3. **Image Optimization**: Automatic image optimization
4. **Caching**: Proper cache headers for static assets

### Monitoring

1. **Vercel Analytics**: Built-in performance monitoring
2. **Health Checks**: Monitor `/api/health` endpoint
3. **Error Tracking**: Set up error monitoring service
4. **Database Monitoring**: Monitor database performance

## 🛠 Environment-Specific Configurations

### Development
```bash
NEXTAUTH_URL="http://localhost:3000"
# Use test API keys or local services
```

### Staging
```bash
NEXTAUTH_URL="https://staging-your-app.vercel.app"
# Use staging databases and limited API quotas
```

### Production
```bash
NEXTAUTH_URL="https://your-domain.com"
# Use production databases and full API quotas
```

## 🔒 Security Checklist

- [ ] All environment variables are set
- [ ] Database has proper access controls
- [ ] API keys are properly secured
- [ ] HTTPS is enforced
- [ ] CSRF protection is enabled
- [ ] Rate limiting is configured
- [ ] Input validation is implemented
- [ ] Error messages don't leak sensitive info

## 📊 Post-Deployment Tasks

### 1. Admin Setup
1. Login as super admin
2. Configure AI providers
3. Set up system configurations
4. Create additional admin users if needed

### 2. User Management
1. Create initial user accounts
2. Set up user roles and permissions
3. Configure user preferences defaults

### 3. System Configuration
1. Configure default AI provider
2. Set session limits and timeouts
3. Configure file upload limits
4. Set up notification preferences

### 4. Testing
1. Test voice recognition functionality
2. Verify AI provider integrations
3. Test admin panel features
4. Verify mobile responsiveness

## 🚨 Troubleshooting

### Common Issues

#### Database Connection Errors
```bash
# Check database URL format
# Ensure database is accessible from Vercel
# Verify connection string has proper encoding
```

#### API Key Issues
```bash
# Verify API keys are correctly set in Vercel
# Check API key permissions and quotas
# Ensure keys are not expired
```

#### Authentication Problems
```bash
# Verify NEXTAUTH_SECRET is set
# Check NEXTAUTH_URL matches deployment URL
# Ensure database schema is up to date
```

#### Build Failures
```bash
# Check TypeScript errors
# Verify all dependencies are listed in package.json
# Ensure environment variables are available during build
```

### Debug Steps

1. **Check Vercel Function Logs**
   ```bash
   vercel logs your-deployment-url
   ```

2. **Test Health Endpoint**
   ```bash
   curl https://your-domain.vercel.app/api/health
   ```

3. **Verify Database Connection**
   ```bash
   npx prisma db pull
   ```

4. **Check Environment Variables**
   ```bash
   vercel env ls
   ```

## 📈 Scaling Considerations

### Database Scaling
- Monitor connection limits
- Consider connection pooling
- Plan for read replicas if needed

### API Rate Limits
- Monitor AI provider usage
- Implement user-based rate limiting
- Consider caching for frequent requests

### Storage Scaling
- Plan for file uploads and storage
- Consider CDN for static assets
- Monitor Vercel function limits

## 🔄 CI/CD Pipeline

### GitHub Actions Example
```yaml
name: Deploy to Vercel
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to Vercel
        uses: vercel/action@v1
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.ORG_ID }}
          vercel-project-id: ${{ secrets.PROJECT_ID }}
```

## 📱 Mobile PWA Setup

The application is PWA-ready. To enable:

1. Ensure manifest.json is properly configured
2. Verify service worker is registered
3. Test offline functionality
4. Add to home screen instructions

## 🌍 Multi-Region Deployment

For global users:
1. Consider Vercel's Edge Network
2. Use appropriate database regions
3. Configure CDN for static assets
4. Monitor latency across regions

---

For additional support, contact: admin@voiceagent.com
