# Lambda Invocation Methods

## Overview

There are several ways to invoke your Lambda function. This guide covers all methods and their use cases.

---

## Method 1: AWS CLI v2 (Recommended)

### Basic Invocation

```bash
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}' \
  response.json
```

### Key Components

1. **`--cli-binary-format raw-in-base64-out`** ✨ **REQUIRED for AWS CLI v2**
   - Allows raw JSON input (not base64-encoded)
   - Without this, you get: "Could not parse payload into json" error
   
2. **`--payload`** - The JSON event data
   - For Lambda Web Adapter, use API Gateway format
   - Single-line JSON works best
   
3. **`response.json`** - Output file
   - Contains the Lambda response
   - Read with: `cat response.json | jq '.'`

### Why This Method?

✅ Works with AWS CLI v2 (default since 2020)  
✅ Simple and direct  
✅ Good for testing and automation  
✅ Returns response to file for inspection  

---

## Method 2: Using Helper Script

### Quick Test
```bash
./lambda-test.sh
```

### What It Does
```bash
# Runs the CLI command with proper formatting
# Shows timing information
# Displays logs
# Formats output nicely
```

### Advantages
✅ Pre-configured with correct flags  
✅ Shows timing for cold/warm comparison  
✅ Automatically fetches logs  
✅ User-friendly output  

---

## Method 3: AWS CLI v1 (Legacy)

If you have AWS CLI v1, the format is slightly different:

```bash
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --payload '{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}' \
  response.json
```

**Note:** No `--cli-binary-format` flag needed for CLI v1

### Check Your AWS CLI Version
```bash
aws --version

# v2: aws-cli/2.x.x
# v1: aws-cli/1.x.x
```

---

## Method 4: Payload from File

For complex payloads, use a file:

### Create Payload File
```bash
cat > payload.json <<'EOF'
{
  "rawPath": "/api/hello",
  "requestContext": {
    "http": {
      "method": "GET"
    }
  },
  "headers": {
    "user-agent": "test-client"
  }
}
EOF
```

### Invoke with File
```bash
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload file://payload.json \
  response.json
```

**Note:** Use `file://` prefix for file paths

---

## Method 5: Test Different Endpoints

### Health Check Endpoint
```bash
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/api/health","requestContext":{"http":{"method":"GET"}}}' \
  response.json
```

### Actuator Health
```bash
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/actuator/health","requestContext":{"http":{"method":"GET"}}}' \
  response.json
```

### Root Endpoint
```bash
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/","requestContext":{"http":{"method":"GET"}}}' \
  response.json
```

---

## Method 6: With Timing and Logs

### Measure Performance
```bash
time aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}' \
  --log-type Tail \
  response.json

# Shows execution time
# Returns logs in response (base64 encoded)
```

### View Logs
```bash
# Decode log output
aws lambda invoke ... --log-type Tail response.json \
  | jq -r '.LogResult' \
  | base64 -d
```

---

## Method 7: Environment Variables

### Set Variables
```bash
export FUNCTION_NAME=hello-cloud-lambda
export AWS_REGION=us-east-1
```

### Use in Commands
```bash
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}' \
  response.json
```

---

## Method 8: API Gateway Integration

Once connected to API Gateway, use HTTP:

```bash
# Regular HTTP request (no Lambda-specific format needed)
curl https://your-api-id.execute-api.us-east-1.amazonaws.com/api/hello
```

This is the recommended approach for production!

---

## Payload Formats

### Lambda Web Adapter Format (Current)

```json
{
  "rawPath": "/api/hello",
  "requestContext": {
    "http": {
      "method": "GET"
    }
  }
}
```

This is the **API Gateway v2 (HTTP API)** format that Lambda Web Adapter expects.

### With Headers
```json
{
  "rawPath": "/api/hello",
  "requestContext": {
    "http": {
      "method": "GET"
    }
  },
  "headers": {
    "content-type": "application/json",
    "user-agent": "test-client/1.0"
  }
}
```

### With Query Parameters
```json
{
  "rawPath": "/api/hello",
  "rawQueryString": "name=World&version=1",
  "requestContext": {
    "http": {
      "method": "GET"
    }
  }
}
```

### POST Request with Body
```json
{
  "rawPath": "/api/data",
  "requestContext": {
    "http": {
      "method": "POST"
    }
  },
  "headers": {
    "content-type": "application/json"
  },
  "body": "{\"key\":\"value\"}"
}
```

---

## Troubleshooting

### Error: "Could not parse payload into json"

**Problem:** Missing `--cli-binary-format` flag

**Solution:**
```bash
# Add this flag:
--cli-binary-format raw-in-base64-out
```

### Error: "Invalid parameter: Payload"

**Problem:** Payload is too large or malformed

**Solutions:**
1. Check JSON syntax: `echo '$PAYLOAD' | jq '.'`
2. Use file: `--payload file://payload.json`
3. Check size: Lambda limit is 6 MB

### Error: "Task timed out"

**Problem:** Function timeout exceeded

**Solutions:**
1. Increase timeout: `--timeout 120`
2. Check Lambda configuration
3. View logs to see where it's stuck

### Empty Response Body

**Problem:** Response streaming format

**Solution:**
```bash
# Response is in streaming format
# Look for body after the JSON structure
cat response.json

# You'll see: {...}        {"actual":"body"}
```

---

## Quick Reference

### Test Cold Start
```bash
# Wait 15+ minutes, then:
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}' \
  response.json

# Expected: ~20-30 seconds
```

### Test Warm Start
```bash
# Immediately run again:
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}' \
  response.json

# Expected: <100 milliseconds
```

### View Response
```bash
cat response.json | jq '.'
```

### View Logs
```bash
aws logs tail /aws/lambda/hello-cloud-lambda --region us-east-1 --follow
```

### Check Function Config
```bash
aws lambda get-function-configuration \
  --function-name hello-cloud-lambda \
  --region us-east-1
```

---

## Best Practices

### 1. Use Helper Script for Development
```bash
./lambda-test.sh  # Pre-configured, user-friendly
```

### 2. Use Direct CLI for CI/CD
```bash
# More control, better for automation
aws lambda invoke --cli-binary-format raw-in-base64-out ...
```

### 3. Use API Gateway for Production
```bash
# Much simpler for clients
curl https://api.example.com/api/hello
```

### 4. Test Both Cold and Warm Starts
```bash
# First invocation after idle
./lambda-test.sh

# Immediate second invocation
./lambda-test.sh

# Compare timing!
```

### 5. Monitor Logs
```bash
# Keep logs open while testing
aws logs tail /aws/lambda/hello-cloud-lambda --follow
```

---

## Summary

| Method | Use Case | Complexity |
|--------|----------|------------|
| **AWS CLI v2** | Testing, automation | Low |
| **Helper Script** | Quick testing | Very Low |
| **Payload File** | Complex requests | Low |
| **API Gateway** | Production, clients | Very Low |
| **Direct HTTP** | Local testing (Docker) | Very Low |

**Recommended:**
- Development: `./lambda-test.sh`
- CI/CD: Direct AWS CLI
- Production: API Gateway + curl

---

## Example: Complete Test Session

```bash
# 1. Test cold start
echo "Testing cold start..."
time ./lambda-test.sh

# 2. Test warm start immediately
echo "Testing warm start..."
time ./lambda-test.sh

# 3. Test different endpoint
aws lambda invoke \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --cli-binary-format raw-in-base64-out \
  --payload '{"rawPath":"/actuator/health","requestContext":{"http":{"method":"GET"}}}' \
  response-health.json

# 4. View responses
echo "Hello Response:"
cat response.json | jq '.'

echo "Health Response:"
cat response-health.json | jq '.'

# 5. Check logs
aws logs tail /aws/lambda/hello-cloud-lambda --since 5m
```

---

## References

- [AWS Lambda Invoke API](https://docs.aws.amazon.com/lambda/latest/dg/API_Invoke.html)
- [AWS CLI v2 Binary Format](https://docs.aws.amazon.com/cli/latest/userguide/cliv2-migration.html#cliv2-migration-binaryparam)
- [API Gateway Event Format](https://docs.aws.amazon.com/lambda/latest/dg/services-apigateway.html)
- [Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter)

