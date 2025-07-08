#!/bin/bash

# JustWatched Backend - VM Deployment Script
echo "🚀 Deploying JustWatched Backend on VM..."

# Check if Docker and Docker Compose are installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed. Please log out and log back in."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Installing..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed."
fi

# Check if environment file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found!"
    echo "📝 Please create .env with your configuration:"
    echo ""
    echo "ENVIRONMENT=production"
    echo "AZURE_OPENAI_KEY=your_key_here"
    echo "AZURE_ENDPOINT=your_endpoint_here"
    echo "AZURE_DEPLOYMENT_NAME=your_deployment_name"
    echo "TMDB_API_KEY=your_tmdb_key"
    echo "JWT_SECRET_KEY=your_secret_key"
    echo ""
    exit 1
fi

# Check if Firebase credentials exist
if [ ! -f "firebase-credentials.json" ]; then
    echo "❌ firebase-credentials.json not found!"
    echo "📝 Please add your Firebase service account key as firebase-credentials.json"
    echo "    This file will be mounted as /app/firebase-key.json in the container"
    exit 1
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.production.yml down

# Pull latest code (if this is a git deployment)
if [ -d ".git" ]; then
    echo "📦 Pulling latest code..."
    git pull origin main
fi

# Build and start containers
echo "🔨 Building and starting containers..."
docker-compose -f docker-compose.production.yml up --build -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check if services are running
echo "🔍 Checking service status..."
docker-compose -f docker-compose.production.yml ps

# Test the health endpoint
echo "🏥 Testing health endpoint..."
curl -f http://localhost:8000/healthcheck || echo "⚠️ Health check failed"

# Show logs
echo "📋 Recent logs:"
docker-compose -f docker-compose.production.yml logs --tail=20

echo ""
echo "✅ Deployment completed!"
echo "🌐 Backend URL: http://localhost:8000"
echo "🔍 Health Check: http://localhost:8000/healthcheck"
echo ""
echo "📋 Useful commands:"
echo "  View logs: docker-compose -f docker-compose.production.yml logs -f"
echo "  Stop: docker-compose -f docker-compose.production.yml down"
echo "  Restart: docker-compose -f docker-compose.production.yml restart"
echo "  Update: ./deploy.sh" 