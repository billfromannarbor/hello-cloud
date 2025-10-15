#!/bin/bash

# Script to set up GitHub OIDC authentication with AWS for ECR

set -e

echo "GitHub OIDC Setup for AWS ECR"
echo "=============================="
echo ""

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Configuration
GITHUB_REPO="${GITHUB_REPO:-billfromannarbor/hello-cloud}"
ROLE_NAME="${ROLE_NAME:-GitHubActionsECRRole}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "GitHub Repository: $GITHUB_REPO"
echo "IAM Role Name: $ROLE_NAME"
echo "AWS Region: $AWS_REGION"
echo ""

read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Create OIDC Provider (if it doesn't exist)
echo ""
echo "Step 1: Creating OIDC Identity Provider..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  2>/dev/null && echo "✅ OIDC Provider created" || echo "ℹ️  OIDC Provider already exists (this is fine)"

# Step 2: Create Trust Policy
echo ""
echo "Step 2: Creating IAM Role trust policy..."
cat > /tmp/github-oidc-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF

# Step 3: Create IAM Role
echo "Step 3: Creating IAM Role..."
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file:///tmp/github-oidc-trust-policy.json \
  2>/dev/null && echo "✅ Role created" || echo "ℹ️  Role already exists"

# Step 4: Create ECR Permissions Policy
echo ""
echo "Step 4: Attaching ECR permissions..."
cat > /tmp/ecr-permissions.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:*:${ACCOUNT_ID}:repository/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name ECRPushPolicy \
  --policy-document file:///tmp/ecr-permissions.json

echo "✅ ECR permissions attached"

# Step 5: Get Role ARN
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

# Cleanup temp files
rm -f /tmp/github-oidc-trust-policy.json /tmp/ecr-permissions.json

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Role ARN: $ROLE_ARN"
echo ""
echo "Next steps:"
echo ""
echo "1. Add this secret to GitHub:"
echo "   - Go to: https://github.com/${GITHUB_REPO}/settings/secrets/actions"
echo "   - Name: AWS_ROLE_ARN"
echo "   - Value: $ROLE_ARN"
echo ""
echo "2. Update .github/workflows/docker-build-lambda.yml:"
echo "   - AWS_REGION: $AWS_REGION"
echo "   - ECR_REPOSITORY: <your-ecr-repo-name>"
echo ""
echo "3. Push your changes:"
echo "   git add ."
echo "   git commit -m 'Configure OIDC for ECR'"
echo "   git push"
echo ""
echo "No AWS credentials needed in GitHub - OIDC will handle authentication! 🎉"

