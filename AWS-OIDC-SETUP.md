# GitHub OIDC Integration with AWS (Recommended)

Using OpenID Connect (OIDC) is more secure than using long-lived AWS access keys. With OIDC, GitHub Actions gets temporary credentials directly from AWS.

## Benefits of OIDC
- ✅ No long-lived credentials stored in GitHub
- ✅ Temporary credentials that auto-expire
- ✅ Fine-grained permissions per repository
- ✅ Follows AWS security best practices
- ✅ No credential rotation needed

## Setup Steps

### Step 1: Create OIDC Identity Provider in AWS

1. **Go to IAM Console** → **Identity Providers** → **Add Provider**

2. **Configure the provider:**
   - Provider type: `OpenID Connect`
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

3. **Click "Add provider"**

Or use AWS CLI:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Step 2: Create IAM Role for GitHub Actions

Create a trust policy file:

```bash
cat > github-oidc-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::174725579849:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:billfromannarbor/hello-cloud:*"
        }
      }
    }
  ]
}
EOF
```

**Replace:**
- `YOUR_ACCOUNT_ID` with your AWS account ID
- `billfromannarbor/hello-cloud` with your GitHub repo path (org/repo)

Create the role:

```bash
aws iam create-role \
  --role-name GitHubActionsECRRole \
  --assume-role-policy-document file://github-oidc-trust-policy.json
```

### Step 3: Attach ECR Permissions to the Role

Create ECR permissions policy:

```bash
cat > ecr-permissions.json <<EOF
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
      "Resource": "arn:aws:ecr:*:174725579849:repository/*"
    }
  ]
}
EOF
```

Attach the policy:

```bash
aws iam put-role-policy \
  --role-name GitHubActionsECRRole \
  --policy-name ECRPushPolicy \
  --policy-document file://ecr-permissions.json
```

### Step 4: Get the Role ARN

```bash
aws iam get-role \
  --role-name GitHubActionsECRRole \
  --query 'Role.Arn' \
  --output text
```

Save the output - it will look like:
```
arn:aws:iam::123456789012:role/GitHubActionsECRRole
```

### Step 5: Add Role ARN to GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add:
   - Name: `AWS_ROLE_ARN`
   - Value: `arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsECRRole`

### Step 6: Update Workflow Configuration

The workflow is already configured to use OIDC! Just update:

In `.github/workflows/docker-build-lambda.yml`:
```yaml
env:
  AWS_REGION: us-east-1  # Change to your region
  ECR_REPOSITORY: hello-cloud  # Change to your ECR repo name
```

### Step 7: Test It!

```bash
git add .
git commit -m "Configure OIDC authentication for ECR"
git push
```

GitHub Actions will now:
1. Request temporary credentials from AWS using OIDC
2. Build the Docker image
3. Push to ECR using temporary credentials

## Verification

Check the GitHub Actions run:
- You should see "Configure AWS credentials via OIDC" step succeed
- No AWS access keys are used
- Credentials are temporary and automatically expire

## Quick Setup Script

```bash
#!/bin/bash
# Replace these values
ACCOUNT_ID="123456789012"
REPO="billfromannarbor/hello-cloud"
ROLE_NAME="GitHubActionsECRRole"

# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
      "StringLike": {"token.actions.githubusercontent.com:sub": "repo:${REPO}:*"}
    }
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json

# Attach ECR policy
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# Get role ARN
aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text
```

## Troubleshooting

### "Not authorized to perform sts:AssumeRoleWithWebIdentity"
- Verify the trust policy has the correct repository path
- Check that `id-token: write` permission is set in workflow
- Ensure OIDC provider is created in the same AWS account

### "AccessDenied" when pushing to ECR
- Verify the role has ECR permissions attached
- Check that the ECR repository exists
- Ensure the resource ARN in the policy matches your ECR repository

### OIDC Provider Already Exists
- This is fine! Multiple repos can share the same OIDC provider
- Just create the role with the appropriate trust policy

## Security Best Practices

1. **Limit to specific repositories:**
   ```json
   "StringLike": {
     "token.actions.githubusercontent.com:sub": "repo:billfromannarbor/hello-cloud:*"
   }
   ```

2. **Limit to specific branches (optional):**
   ```json
   "StringLike": {
     "token.actions.githubusercontent.com:sub": "repo:billfromannarbor/hello-cloud:ref:refs/heads/main"
   }
   ```

3. **Use least privilege:** Only grant ECR permissions needed

4. **Enable CloudTrail:** Monitor AssumeRoleWithWebIdentity calls

## References

- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

