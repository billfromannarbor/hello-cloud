# Lambda Performance Fix - Quick Start

## Problem Summary
Your Spring Boot app was **starting fresh on every Lambda invocation**, causing 30+ second delays and timeouts.

## Solution Applied
Added **AWS Lambda Web Adapter** which keeps Spring Boot running between invocations.

## Quick Deploy

### 1. Build and Push New Image
```bash
# Build with Lambda Web Adapter
docker build -t hello-cloud-lambda .

# Configure AWS (if not already done)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Tag and push
docker tag hello-cloud-lambda:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/test/hello-cloud:lambda-latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/test/hello-cloud:lambda-latest
```

### 2. Update Lambda Configuration
```bash
chmod +x update-lambda-config.sh
./update-lambda-config.sh
```

### 3. Update Lambda Code
```bash
aws lambda update-function-code \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --image-uri $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/test/hello-cloud:lambda-latest

# Wait for update to complete
aws lambda wait function-updated \
  --function-name hello-cloud-lambda \
  --region us-east-1
```

### 4. Test
```bash
chmod +x lambda-test.sh
./lambda-test.sh
```

## Expected Results

### First Invocation (Cold Start)
```
Duration: 20-30 seconds (one-time initialization)
Status: 200 OK
```

### Second Invocation (Warm)
```
Duration: 50-200 ms (100x faster!)
Status: 200 OK
```

## What Changed

### 1. Dockerfile
- Added AWS Lambda Web Adapter layer
- Configured health check integration
- Set environment variables for LWA

### 2. Lambda Configuration
- Memory: 512 MB → **1024 MB** (more CPU power)
- Timeout: 30s → **60s** (for cold starts)
- Added LWA environment variables

### 3. application-lambda.yml
- Enabled lazy initialization
- Reduced thread pools
- Disabled unnecessary features
- Optimized for fast startup

## Performance Comparison

| Scenario | Before | After |
|----------|--------|-------|
| Cold Start | Timeout ⚠️ | 20-30s ✅ |
| Warm Invocation | Timeout ⚠️ | 50-200ms ✅ |

## How It Works

```
┌─────────────────────────────────────────────┐
│ Lambda Container                             │
│                                              │
│  ┌──────────────────────────────────────┐  │
│  │ Lambda Web Adapter (always running)  │  │
│  └────────────┬─────────────────────────┘  │
│               │                              │
│               ↓                              │
│  ┌──────────────────────────────────────┐  │
│  │ Spring Boot Server (keeps running!)  │  │
│  │ - Started once per container         │  │
│  │ - Handles multiple requests          │  │
│  │ - Only cold starts pay init cost     │  │
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Key Point**: Spring Boot starts once and stays running. The Lambda Web Adapter handles all incoming Lambda events and forwards them to your running server.

## Or Use GitHub Actions

Push your changes to trigger automatic deployment:

```bash
git add .
git commit -m "Add Lambda Web Adapter for performance"
git push origin main
```

The workflow will:
1. Build Docker image with LWA
2. Push to ECR
3. Lambda will automatically use new image on next invocation

## Troubleshooting

### Still timing out?
```bash
# Increase timeout
aws lambda update-function-configuration \
  --function-name hello-cloud-lambda \
  --timeout 90

# Increase memory (more CPU)
aws lambda update-function-configuration \
  --function-name hello-cloud-lambda \
  --memory-size 1536
```

### Check logs
```bash
aws logs tail /aws/lambda/hello-cloud-lambda --follow
```

### Verify health check
```bash
# If running locally
docker run -p 8080:8080 hello-cloud-lambda
curl http://localhost:8080/actuator/health
```

## Cost Impact

### Before (timing out)
- Every invocation: ~30 seconds billed
- 1000 requests/day = 30,000 seconds = 8.3 hours
- **High cost + poor UX**

### After (with LWA)
- Cold start: ~30 seconds (rare)
- Warm requests: ~0.2 seconds (most requests)
- 1000 requests/day ≈ 200-300 seconds total
- **10-15x cost reduction + great UX**

## Keep Function Warm (Optional)

Prevent cold starts entirely by pinging every 5 minutes:

```bash
# Create EventBridge rule
aws events put-rule \
  --name keep-hello-cloud-warm \
  --schedule-expression 'rate(5 minutes)' \
  --region us-east-1

# Add Lambda as target
aws events put-targets \
  --rule keep-hello-cloud-warm \
  --targets '[{
    "Id": "1",
    "Arn": "arn:aws:lambda:us-east-1:'$AWS_ACCOUNT_ID':function:hello-cloud-lambda",
    "Input": "{\"rawPath\":\"/actuator/health\",\"requestContext\":{\"http\":{\"method\":\"GET\"}}}"
  }]' \
  --region us-east-1

# Grant permission
aws lambda add-permission \
  --function-name hello-cloud-lambda \
  --statement-id AllowEventBridgeInvoke \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:$AWS_ACCOUNT_ID:rule/keep-hello-cloud-warm \
  --region us-east-1
```

## Next Steps

1. ✅ Deploy the changes
2. ✅ Test both cold and warm starts
3. ✅ Monitor CloudWatch metrics
4. 📖 Read [LAMBDA-PERFORMANCE.md](LAMBDA-PERFORMANCE.md) for detailed info
5. 🔧 Consider keep-warm strategy for production
6. 📊 Set up CloudWatch alarms for timeouts

## Learn More

- Full details: [LAMBDA-PERFORMANCE.md](LAMBDA-PERFORMANCE.md)
- LWA GitHub: https://github.com/awslabs/aws-lambda-web-adapter
- AWS Lambda optimization: https://docs.aws.amazon.com/lambda/latest/operatorguide/perf-optimize.html

