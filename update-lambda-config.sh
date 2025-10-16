#!/bin/bash

# Update Lambda function configuration for Spring Boot with Lambda Web Adapter

set -e

FUNCTION_NAME="${FUNCTION_NAME:-hello-cloud-lambda}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Updating Lambda function configuration..."
echo "Function: $FUNCTION_NAME"
echo "Region: $AWS_REGION"
echo ""

# Update function configuration
echo "Configuring Lambda for Spring Boot with Web Adapter..."
aws lambda update-function-configuration \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --memory-size 1024 \
  --timeout 60 \
  --environment "Variables={
    AWS_LWA_PORT=8080,
    AWS_LWA_READINESS_CHECK_PATH=/actuator/health,
    AWS_LWA_READINESS_CHECK_PORT=8080,
    AWS_LWA_READINESS_CHECK_PROTOCOL=http,
    AWS_LWA_INVOKE_MODE=response_stream,
    SPRING_PROFILES_ACTIVE=lambda
  }"

echo ""
echo "✅ Lambda configuration updated!"
echo ""
echo "New settings:"
echo "- Memory: 1024 MB (more memory = faster CPU = faster startup)"
echo "- Timeout: 60 seconds (for cold starts)"
echo "- Lambda Web Adapter configured"
echo ""
echo "How this improves performance:"
echo "1. Lambda Web Adapter keeps Spring Boot running between invocations"
echo "2. Only cold starts pay the ~20-30s initialization cost"
echo "3. Warm invocations are typically <100ms"
echo "4. Higher memory = more CPU power = faster cold starts"

