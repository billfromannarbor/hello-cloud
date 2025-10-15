#!/bin/bash

# Script to create AWS ECR repository for hello-cloud

set -e

AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-hello-cloud}"

echo "Creating ECR repository..."
echo "Region: $AWS_REGION"
echo "Repository: $ECR_REPOSITORY"
echo ""

# Create the ECR repository
aws ecr create-repository \
  --repository-name "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256 \
  2>/dev/null || echo "Repository may already exist"

# Get the repository URI
REPOSITORY_URI=$(aws ecr describe-repositories \
  --repository-names "$ECR_REPOSITORY" \
  --region "$AWS_REGION" \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo ""
echo "✅ ECR Repository ready!"
echo "URI: $REPOSITORY_URI"
echo ""
echo "Next steps:"
echo "1. Add these secrets to your GitHub repository:"
echo "   - AWS_ACCESS_KEY_ID"
echo "   - AWS_SECRET_ACCESS_KEY"
echo ""
echo "2. Update .github/workflows/docker-build-lambda.yml:"
echo "   - Set AWS_REGION to: $AWS_REGION"
echo "   - Set ECR_REPOSITORY to: $ECR_REPOSITORY"
echo ""
echo "3. Push to main branch, and GitHub Actions will push to:"
echo "   - $REPOSITORY_URI:latest"
echo "   - $REPOSITORY_URI:lambda-latest"

