# AWS ECR Setup for GitHub Actions

This guide shows you how to automatically push Docker images to AWS ECR using GitHub Actions.

## Prerequisites

- AWS Account
- AWS CLI installed and configured
- GitHub repository with Actions enabled

## Step 1: Create ECR Repository

Run the setup script:

```bash
./setup-ecr.sh
```

Or manually:

```bash
aws ecr create-repository \
  --repository-name hello-cloud \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true
```

## Step 2: Create IAM User for GitHub Actions

1. **Create IAM user:**
   ```bash
   aws iam create-user --user-name github-actions-ecr
   ```

2. **Create and attach policy:**
   ```bash
   cat > ecr-push-policy.json <<EOF
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ecr:GetAuthorizationToken",
           "ecr:BatchCheckLayerAvailability",
           "ecr:GetDownloadUrlForLayer",
           "ecr:BatchGetImage",
           "ecr:PutImage",
           "ecr:InitiateLayerUpload",
           "ecr:UploadLayerPart",
           "ecr:CompleteLayerUpload"
         ],
         "Resource": "*"
       }
     ]
   }
   EOF
   
   aws iam put-user-policy \
     --user-name github-actions-ecr \
     --policy-name ECRPushPolicy \
     --policy-document file://ecr-push-policy.json
   ```

3. **Create access keys:**
   ```bash
   aws iam create-access-key --user-name github-actions-ecr
   ```
   
   Save the output - you'll need the `AccessKeyId` and `SecretAccessKey`!

## Step 3: Add Secrets to GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

   | Name | Value |
   |------|-------|
   | `AWS_ACCESS_KEY_ID` | Your IAM user's access key ID |
   | `AWS_SECRET_ACCESS_KEY` | Your IAM user's secret access key |

## Step 4: Update Workflow Configuration

Edit `.github/workflows/docker-build-lambda.yml` if needed:

```yaml
env:
  AWS_REGION: us-east-1  # Change to your region
  ECR_REPOSITORY: hello-cloud  # Change to your ECR repo name
```

## Step 5: Push and Test

```bash
git add .
git commit -m "Add ECR push to GitHub Actions"
git push
```

GitHub Actions will now:
1. ✅ Build the Docker image (linux/amd64)
2. ✅ Push to GitHub Container Registry (GHCR)
3. ✅ Push to AWS ECR

## Your Images Will Be Available At:

**GitHub Container Registry:**
- `ghcr.io/billfromannarbor/hello-cloud:lambda-latest`
- `ghcr.io/billfromannarbor/hello-cloud:lambda-<commit-sha>`

**AWS ECR:**
- `<account-id>.dkr.ecr.us-east-1.amazonaws.com/hello-cloud:latest`
- `<account-id>.dkr.ecr.us-east-1.amazonaws.com/hello-cloud:lambda-latest`

## Using the ECR Image in Lambda

When creating/updating your Lambda function:

```bash
aws lambda update-function-code \
  --function-name your-function-name \
  --image-uri <account-id>.dkr.ecr.us-east-1.amazonaws.com/hello-cloud:latest
```

Or use the AWS Console and paste the ECR image URI.

## Troubleshooting

### "No basic auth credentials" error
- Ensure AWS credentials are correctly added to GitHub Secrets
- Verify the IAM user has the correct ECR permissions

### "Repository does not exist" error
- Run `./setup-ecr.sh` to create the repository
- Ensure ECR_REPOSITORY name matches in workflow and AWS

### Build fails
- Check the Actions tab in GitHub for detailed logs
- Verify your Dockerfile builds locally with `docker build .`

## Cleanup

To remove the ECR repository:

```bash
aws ecr delete-repository \
  --repository-name hello-cloud \
  --region us-east-1 \
  --force
```

To remove the IAM user:

```bash
aws iam delete-user-policy --user-name github-actions-ecr --policy-name ECRPushPolicy
aws iam delete-access-key --user-name github-actions-ecr --access-key-id <KEY_ID>
aws iam delete-user --user-name github-actions-ecr
```

