# 🚀 Production Deployment Guide - Azure

This guide will help you deploy your JustWatched backend to Azure production environment.

## 📋 Prerequisites

### 1. Azure Account & CLI
- [Azure Account](https://azure.microsoft.com/free/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Docker](https://docs.docker.com/get-docker/)

### 2. Required API Keys
- **Azure OpenAI**: API key, endpoint, and deployment name
- **TMDB API**: API key for movie data
- **Firebase**: Service account key (firebase-key.json)
- **JWT Secret**: Secure random string for JWT tokens

## 🔧 Pre-Deployment Setup

### 1. Prepare Environment Variables
```bash
# Copy the template
cp env.production.template .env

# Edit .env with your actual values
nano .env
```

### 2. Ensure Firebase Key is Present
```bash
# Make sure firebase-key.json is in the project root
ls -la firebase-key.json
```

### 3. Test Local Build
```bash
# Test that everything builds correctly
docker-compose -f docker-compose.prod.yml build
```

## 🚀 Automated Deployment

### Option 1: Use the Deployment Script (Recommended)
```bash
# Make script executable (if not already)
chmod +x azure-deploy.sh

# Run the deployment
./azure-deploy.sh
```

### Option 2: Manual Deployment Steps

#### 1. Login to Azure
```bash
az login
```

#### 2. Create Resource Group
```bash
az group create --name justwatched-backend-rg --location eastus
```

#### 3. Create Azure Container Registry
```bash
az acr create --resource-group justwatched-backend-rg --name justwatchedacr --sku Basic --admin-enabled true
```

#### 4. Create Azure Redis Cache
```bash
az redis create --resource-group justwatched-backend-rg --name justwatched-redis --location eastus --sku Basic --vm-size c0
```

#### 5. Create Azure Key Vault
```bash
az keyvault create --name justwatched-kv --resource-group justwatched-backend-rg --location eastus --sku standard
```

#### 6. Create Application Insights
```bash
az monitor app-insights component create --app justwatched-insights --location eastus --resource-group justwatched-backend-rg --application-type web
```

#### 7. Build and Push Images
```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name justwatchedacr --resource-group justwatched-backend-rg --query "loginServer" --output tsv)

# Build and push images
az acr build --registry $ACR_LOGIN_SERVER --image justwatched-backend:latest .
az acr build --registry $ACR_LOGIN_SERVER --image justwatched-celery:latest -f Dockerfile.celery .
```

#### 8. Deploy Container Apps
```bash
# Create Container Apps Environment
az containerapp env create --name justwatched-env --resource-group justwatched-backend-rg --location eastus

# Deploy Backend
az containerapp create \
  --name justwatched-backend \
  --resource-group justwatched-backend-rg \
  --environment justwatched-env \
  --image $ACR_LOGIN_SERVER.azurecr.io/justwatched-backend:latest \
  --target-port 8000 \
  --ingress external \
  --registry-server $ACR_LOGIN_SERVER.azurecr.io \
  --registry-username $(az acr credential show --name justwatchedacr --query "username" --output tsv) \
  --registry-password $(az acr credential show --name justwatchedacr --query "passwords[0].value" --output tsv) \
  --env-vars ENVIRONMENT=production CELERY_BROKER_URL="$REDIS_CONNECTION_STRING" AZURE_OPENAI_KEY="$AZURE_OPENAI_KEY" TMDB_API_KEY="$TMDB_API_KEY"

# Deploy Celery Worker
az containerapp create \
  --name justwatched-celery-worker \
  --resource-group justwatched-backend-rg \
  --environment justwatched-env \
  --image $ACR_LOGIN_SERVER.azurecr.io/justwatched-celery:latest \
  --ingress disabled \
  --registry-server $ACR_LOGIN_SERVER.azurecr.io \
  --registry-username $(az acr credential show --name justwatchedacr --query "username" --output tsv) \
  --registry-password $(az acr credential show --name justwatchedacr --query "passwords[0].value" --output tsv) \
  --env-vars ENVIRONMENT=production CELERY_BROKER_URL="$REDIS_CONNECTION_STRING" AZURE_OPENAI_KEY="$AZURE_OPENAI_KEY" TMDB_API_KEY="$TMDB_API_KEY" \
  --command "celery -A app.celery_worker.celery_app worker --loglevel=info --concurrency=4"

# Deploy Celery Beat
az containerapp create \
  --name justwatched-celery-beat \
  --resource-group justwatched-backend-rg \
  --environment justwatched-env \
  --image $ACR_LOGIN_SERVER.azurecr.io/justwatched-celery:latest \
  --ingress disabled \
  --registry-server $ACR_LOGIN_SERVER.azurecr.io \
  --registry-username $(az acr credential show --name justwatchedacr --query "username" --output tsv) \
  --registry-password $(az acr credential show --name justwatchedacr --query "passwords[0].value" --output tsv) \
  --env-vars ENVIRONMENT=production CELERY_BROKER_URL="$REDIS_CONNECTION_STRING" AZURE_OPENAI_KEY="$AZURE_OPENAI_KEY" TMDB_API_KEY="$TMDB_API_KEY" \
  --command "celery -A app.celery_worker.celery_app beat --loglevel=info"
```

## ✅ Post-Deployment Verification

### 1. Get Your Backend URL
```bash
BACKEND_URL=$(az containerapp show --name justwatched-backend --resource-group justwatched-backend-rg --query "properties.configuration.ingress.fqdn" --output tsv)
echo "Backend URL: https://$BACKEND_URL"
```

### 2. Test Health Endpoint
```bash
curl -X GET "https://$BACKEND_URL/healthcheck"
```

### 3. Test API Documentation
```bash
# Open in browser
open "https://$BACKEND_URL/docs"
```

### 4. Monitor Application
```bash
# View logs
az containerapp logs show --name justwatched-backend --resource-group justwatched-backend-rg

# View Celery logs
az containerapp logs show --name justwatched-celery-worker --resource-group justwatched-backend-rg
```

## 🔧 Configuration Management

### Environment Variables
All sensitive configuration is stored in Azure Key Vault and injected as environment variables:

- `AZURE_OPENAI_KEY` - Azure OpenAI API key
- `AZURE_ENDPOINT` - Azure OpenAI endpoint
- `AZURE_DEPLOYMENT_NAME` - Azure OpenAI deployment name
- `TMDB_API_KEY` - TMDB API key
- `JWT_SECRET_KEY` - JWT signing secret
- `CELERY_BROKER_URL` - Redis connection string
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - Application Insights connection

### Secrets Management
```bash
# Store a secret
az keyvault secret set --vault-name justwatched-kv --name "SECRET-NAME" --value "secret-value"

# Retrieve a secret
az keyvault secret show --vault-name justwatched-kv --name "SECRET-NAME" --query "value" --output tsv
```

## 📊 Monitoring & Logging

### Application Insights
- **Performance Monitoring**: Track response times, throughput
- **Error Tracking**: Automatic error collection and alerting
- **Custom Metrics**: Business metrics and KPIs
- **Log Analytics**: Centralized logging and querying

### Health Checks
- **Endpoint**: `GET /healthcheck`
- **Database**: Firestore connectivity
- **External APIs**: TMDB, Azure OpenAI connectivity

### Scaling
```bash
# Scale backend
az containerapp revision set-mode --name justwatched-backend --resource-group justwatched-backend-rg --mode multiple

# Scale Celery workers
az containerapp update --name justwatched-celery-worker --resource-group justwatched-backend-rg --min-replicas 2 --max-replicas 10
```

## 🔒 Security

### Network Security
- **HTTPS**: Automatic SSL/TLS termination
- **VNET Integration**: Optional for enhanced security
- **Private Endpoints**: For database and Redis access

### Authentication
- **Firebase Auth**: JWT token validation
- **Azure AD**: Optional for admin access
- **API Keys**: For external integrations

## 💰 Cost Optimization

### Resource Sizing
- **Container Apps**: Start with minimal replicas
- **Redis Cache**: Basic tier for development, Standard for production
- **Container Registry**: Basic tier sufficient for most use cases

### Monitoring Costs
```bash
# View resource costs
az consumption usage list --billing-period-name "2024-01"
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Container Won't Start
```bash
# Check logs
az containerapp logs show --name justwatched-backend --resource-group justwatched-backend-rg

# Check environment variables
az containerapp show --name justwatched-backend --resource-group justwatched-backend-rg --query "properties.template.containers[0].env"
```

#### 2. Redis Connection Issues
```bash
# Test Redis connectivity
az redis firewall-rules create --name justwatched-redis --resource-group justwatched-backend-rg --rule-name "allow-all" --start-ip 0.0.0.0 --end-ip 255.255.255.255
```

#### 3. Celery Tasks Not Running
```bash
# Check Celery worker logs
az containerapp logs show --name justwatched-celery-worker --resource-group justwatched-backend-rg

# Check Redis connection
az redis show --name justwatched-redis --resource-group justwatched-backend-rg --query "hostName"
```

### Support Resources
- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure Redis Cache Documentation](https://docs.microsoft.com/en-us/azure/azure-cache-for-redis/)
- [Application Insights Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

## 🔄 Updates & Maintenance

### Updating the Application
```bash
# Build new image
az acr build --registry justwatchedacr --image justwatched-backend:latest .

# Update container app
az containerapp update --name justwatched-backend --resource-group justwatched-backend-rg --image justwatchedacr.azurecr.io/justwatched-backend:latest
```

### Backup Strategy
- **Database**: Firestore automatic backups
- **Configuration**: Azure Key Vault versioning
- **Code**: Git repository with version control

## 📞 Support

For issues with:
- **Azure Services**: Contact Azure Support
- **Application Logic**: Check logs and Application Insights
- **Deployment**: Review this guide and Azure documentation

---

**🎉 Congratulations! Your JustWatched backend is now running in production on Azure!** 