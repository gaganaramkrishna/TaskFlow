#!/bin/bash

set -e

# Configuration
APP_NAME="taskflow"
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🚀 Starting TaskFlow deployment..."

# Build and push backend
echo "📦 Building backend..."
cd backend
docker build -t $APP_NAME-backend .
docker tag $APP_NAME-backend:latest $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME-backend:latest

echo "📤 Pushing backend to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME-backend:latest

# Build and push frontend
echo "📦 Building frontend..."
cd ../frontend
docker build -t $APP_NAME-frontend .
docker tag $APP_NAME-frontend:latest $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME-frontend:latest

echo "📤 Pushing frontend to ECR..."
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME-frontend:latest

cd ..

# Deploy infrastructure
echo "🛠 Deploying infrastructure with Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

echo "✅ Deployment complete!"
echo "🌐 Application URL: $(terraform output application_url)"