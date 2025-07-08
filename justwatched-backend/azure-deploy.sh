#!/bin/bash

# Azure Deployment Script for JustWatched Backend
# This script sets up all Azure services and deploys the application

set -e

# Configuration
RESOURCE_GROUP="justwatched-backend-rg-new"
LOCATION="eastus"
ACR_NAME="justwatchedacr"
CONTAINER_APP_ENV="justwatched-env"
REDIS_NAME="justwatched-redis-ay2025"
KEY_VAULT_NAME="justwatched-kv"
APP_INSIGHTS_NAME="justwatched-insights"

echo "🚀 Starting Azure deployment for JustWatched Backend..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Login to Azure
echo "🔐 Logging into Azure..."
az login

# Set subscription (optional - uncomment and modify if needed)
# az account set --subscription "your-subscription-id"

# Create Resource Group
echo "📦 Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Container Registry
echo "🐳 Creating Azure Container Registry..."
az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)

# Create Azure Redis Cache
echo "🔴 Creating Azure Redis Cache..."
az redis create --resource-group $RESOURCE_GROUP --name $REDIS_NAME --location $LOCATION --sku Basic --vm-size c0

# Get Redis connection string
REDIS_CONNECTION_STRING=$(az redis show --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query "hostName" --output tsv)
REDIS_ACCESS_KEY=$(az redis list-keys --name $REDIS_NAME --resource-group $RESOURCE_GROUP --query "primaryKey" --output tsv)
REDIS_FULL_CONNECTION_STRING="redis://:$REDIS_ACCESS_KEY@$REDIS_CONNECTION_STRING:6380/0"

# Create Azure Key Vault
echo "🔐 Creating Azure Key Vault..."
az keyvault create --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku standard

# Create Application Insights
echo "📊 Creating Application Insights..."
az monitor app-insights component create --app $APP_INSIGHTS_NAME --location $LOCATION --resource-group $RESOURCE_GROUP --application-type web

# Get Application Insights connection string
APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show --app $APP_INSIGHTS_NAME --resource-group $RESOURCE_GROUP --query "connectionString" --output tsv)

# Store secrets in Key Vault
echo "🔒 Storing secrets in Key Vault..."
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "AZURE-REDIS-CONNECTION-STRING" --value "$REDIS_FULL_CONNECTION_STRING"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "AZURE-OPENAI-KEY" --value "$AZURE_OPENAI_KEY"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "AZURE-ENDPOINT" --value "$AZURE_ENDPOINT"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "AZURE-DEPLOYMENT-NAME" --value "$AZURE_DEPLOYMENT_NAME"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "TMDB-API-KEY" --value "$TMDB_API_KEY"
az keyvault secret set --vault-name $KEY_VAULT_NAME --name "JWT-SECRET-KEY" --value "$JWT_SECRET_KEY"

# Create Container Apps Environment
echo "🌐 Creating Container Apps Environment..."
az containerapp env create \
  --name $CONTAINER_APP_ENV \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Build and push Docker images
echo "🔨 Building and pushing Docker images..."
az acr build --registry $ACR_LOGIN_SERVER --image justwatched-backend:latest .
az acr build --registry $ACR_LOGIN_SERVER --image justwatched-celery:latest -f Dockerfile.celery .

# Deploy Backend Container App
echo "🚀 Deploying Backend Container App..."
az containerapp create \
  --name justwatched-backend \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --image $ACR_LOGIN_SERVER.azurecr.io/justwatched-backend:latest \
  --target-port 8000 \
  --ingress external \
  --registry-server $ACR_LOGIN_SERVER.azurecr.io \
  --registry-username $(az acr credential show --name $ACR_NAME --query "username" --output tsv) \
  --registry-password $(az acr credential show --name $ACR_NAME --query "passwords[0].value" --output tsv) \
  --env-vars \
    ENVIRONMENT=production \
    CELERY_BROKER_URL="$REDIS_FULL_CONNECTION_STRING" \
    CELERY_RESULT_BACKEND="$REDIS_FULL_CONNECTION_STRING" \
    AZURE_OPENAI_KEY="$AZURE_OPENAI_KEY" \
    AZURE_ENDPOINT="$AZURE_ENDPOINT" \
    AZURE_DEPLOYMENT_NAME="$AZURE_DEPLOYMENT_NAME" \
    TMDB_API_KEY="$TMDB_API_KEY" \
    JWT_SECRET_KEY="$JWT_SECRET_KEY" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$APP_INSIGHTS_CONNECTION_STRING"

# Deploy Celery Worker Container App
echo "🔧 Deploying Celery Worker Container App..."
az containerapp create \
  --name justwatched-celery-worker \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --image $ACR_LOGIN_SERVER.azurecr.io/justwatched-celery:latest \
  --ingress disabled \
  --registry-server $ACR_LOGIN_SERVER.azurecr.io \
  --registry-username $(az acr credential show --name $ACR_NAME --query "username" --output tsv) \
  --registry-password $(az acr credential show --name $ACR_NAME --query "passwords[0].value" --output tsv) \
  --env-vars \
    ENVIRONMENT=production \
    CELERY_BROKER_URL="$REDIS_FULL_CONNECTION_STRING" \
    CELERY_RESULT_BACKEND="$REDIS_FULL_CONNECTION_STRING" \
    AZURE_OPENAI_KEY="$AZURE_OPENAI_KEY" \
    AZURE_ENDPOINT="$AZURE_ENDPOINT" \
    AZURE_DEPLOYMENT_NAME="$AZURE_DEPLOYMENT_NAME" \
    TMDB_API_KEY="$TMDB_API_KEY" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$APP_INSIGHTS_CONNECTION_STRING" \
  --command "celery -A app.celery_worker.celery_app worker --loglevel=info --concurrency=4"

# Deploy Celery Beat Container App
echo "⏰ Deploying Celery Beat Container App..."
az containerapp create \
  --name justwatched-celery-beat \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --image $ACR_LOGIN_SERVER.azurecr.io/justwatched-celery:latest \
  --ingress disabled \
  --registry-server $ACR_LOGIN_SERVER.azurecr.io \
  --registry-username $(az acr credential show --name $ACR_NAME --query "username" --output tsv) \
  --registry-password $(az acr credential show --name $ACR_NAME --query "passwords[0].value" --output tsv) \
  --env-vars \
    ENVIRONMENT=production \
    CELERY_BROKER_URL="$REDIS_FULL_CONNECTION_STRING" \
    CELERY_RESULT_BACKEND="$REDIS_FULL_CONNECTION_STRING" \
    AZURE_OPENAI_KEY="$AZURE_OPENAI_KEY" \
    AZURE_ENDPOINT="$AZURE_ENDPOINT" \
    AZURE_DEPLOYMENT_NAME="$AZURE_DEPLOYMENT_NAME" \
    TMDB_API_KEY="$TMDB_API_KEY" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$APP_INSIGHTS_CONNECTION_STRING" \
  --command "celery -A app.celery_worker.celery_app beat --loglevel=info"

# Get the backend URL
BACKEND_URL=$(az containerapp show --name justwatched-backend --resource-group $RESOURCE_GROUP --query "properties.configuration.ingress.fqdn" --output tsv)

echo "✅ Deployment completed successfully!"
echo ""
echo "🌐 Backend URL: https://$BACKEND_URL"
echo "🔴 Redis Cache: $REDIS_CONNECTION_STRING"
echo "🔐 Key Vault: $KEY_VAULT_NAME"
echo "📊 Application Insights: $APP_INSIGHTS_NAME"
echo ""
echo "📋 Next steps:"
echo "1. Test the health endpoint: https://$BACKEND_URL/healthcheck"
echo "2. Update your iOS app to use the new backend URL"
echo "3. Monitor the application in Azure Portal"
echo "4. Set up custom domain and SSL certificate if needed" 