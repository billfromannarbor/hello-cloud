#!/bin/bash

# Build single-architecture Docker image for AWS Lambda

set -e

AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-test/hello-cloud}"

echo "Building single-architecture Docker image for AWS Lambda..."
echo "Region: $AWS_REGION"
echo "Repository: $ECR_REPOSITORY"
echo ""

# Get ECR login token
echo "Logging into ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com

# Get ECR registry URI
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$AWS_REGION.amazonaws.com

echo ""
echo "Building image for linux/amd64 only (no multi-arch)..."
docker build \
  --platform linux/amd64 \
  --tag $ECR_REGISTRY/$ECR_REPOSITORY:lambda-latest \
  --tag $ECR_REGISTRY/$ECR_REPOSITORY:latest \
  .

echo ""
echo "Pushing to ECR..."
docker push $ECR_REGISTRY/$ECR_REPOSITORY:lambda-latest
docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

echo ""
echo "✅ Success! Single-architecture images pushed to ECR:"
echo "Lambda image: $ECR_REGISTRY/$ECR_REPOSITORY:lambda-latest"
echo "Latest image:  $ECR_REGISTRY/$ECR_REPOSITORY:latest"
echo ""
echo "Use this URI in Lambda: $ECR_REGISTRY/$ECR_REPOSITORY:lambda-latest"

