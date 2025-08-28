#!/bin/bash

# Voice Agent Pro - Development Setup Script
# This script sets up the development environment

set -e

echo "🚀 Setting up Voice Agent Pro development environment..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi

echo "✅ Node.js $(node -v) detected"

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Check if .env.local exists
if [ ! -f .env.local ]; then
    echo "📝 Creating .env.local from .env.example..."
    cp .env.example .env.local
    echo "⚠️  Please update .env.local with your actual configuration values"
else
    echo "✅ .env.local already exists"
fi

# Generate Prisma client
echo "🔧 Generating Prisma client..."
npx prisma generate

# Check if DATABASE_URL is set
if grep -q "your-postgresql-connection-string" .env.local; then
    echo "⚠️  DATABASE_URL is not configured in .env.local"
    echo "   Please update it with your PostgreSQL connection string"
    echo "   For development, you can use a local PostgreSQL instance or cloud provider"
else
    echo "✅ DATABASE_URL is configured"
    
    # Try to push database schema
    echo "🗄️  Setting up database schema..."
    if npx prisma db push; then
        echo "✅ Database schema created successfully"
        
        # Seed database
        echo "🌱 Seeding database with initial data..."
        if npm run db:seed 2>/dev/null || npx prisma db seed; then
            echo "✅ Database seeded successfully"
        else
            echo "⚠️  Database seeding failed. You can run 'npx prisma db seed' manually later"
        fi
    else
        echo "⚠️  Database setup failed. Please check your DATABASE_URL and try again"
    fi
fi

# Check if AI API keys are configured
echo "🤖 Checking AI provider configuration..."
if grep -q "your-openai-api-key" .env.local; then
    echo "⚠️  AI provider API keys are not configured"
    echo "   Please update .env.local with your API keys:"
    echo "   - OPENAI_API_KEY"
    echo "   - ANTHROPIC_API_KEY"
    echo "   - GOOGLE_API_KEY"
    echo "   - GROQ_API_KEY"
else
    echo "✅ AI provider API keys are configured"
fi

# Generate NEXTAUTH_SECRET if needed
if grep -q "your-nextauth-secret-here" .env.local; then
    echo "🔐 Generating NEXTAUTH_SECRET..."
    SECRET=$(openssl rand -base64 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('base64'))")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/your-nextauth-secret-here/$SECRET/" .env.local
    else
        sed -i "s/your-nextauth-secret-here/$SECRET/" .env.local
    fi
    echo "✅ NEXTAUTH_SECRET generated"
fi

# Generate ENCRYPTION_KEY if needed
if grep -q "your-32-character-encryption-key" .env.local; then
    echo "🔐 Generating ENCRYPTION_KEY..."
    ENCRYPTION_KEY=$(openssl rand -hex 32 2>/dev/null || node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/your-32-character-encryption-key/$ENCRYPTION_KEY/" .env.local
    else
        sed -i "s/your-32-character-encryption-key/$ENCRYPTION_KEY/" .env.local
    fi
    echo "✅ ENCRYPTION_KEY generated"
fi

echo ""
echo "�� Setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Update .env.local with your database URL and API keys"
echo "2. Run 'npm run dev' to start the development server"
echo "3. Open http://localhost:3000 in your browser"
echo "4. Login with admin@voiceagent.com / SuperAdmin123!"
echo ""
echo "📚 Useful commands:"
echo "  npm run dev          - Start development server"
echo "  npm run build        - Build for production"
echo "  npm run type-check   - Run TypeScript type checking"
echo "  npm run lint         - Run ESLint"
echo "  npx prisma studio    - Open Prisma database browser"
echo "  npx prisma db seed   - Seed database with initial data"
echo ""
echo "🆘 Need help? Check README.md or DEPLOYMENT.md"
