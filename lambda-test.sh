#!/bin/bash

# Test AWS Lambda function

set -e

FUNCTION_NAME="${FUNCTION_NAME:-hello-cloud-lambda}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "🧪 Testing Lambda function: $FUNCTION_NAME"
echo "📍 Region: $AWS_REGION"
echo ""

# Test payload (Lambda Web Adapter format)
TEST_PAYLOAD='{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}'

echo "📤 Invoking Lambda function..."
echo ""

# Invoke the function (AWS CLI v2 format)
# Note: --cli-binary-format is required for AWS CLI v2
echo "⏱️  Cold start expected: ~20-30 seconds"
echo "⏱️  Warm start expected: <100 milliseconds"
echo ""

time aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --cli-binary-format raw-in-base64-out \
  --payload "$TEST_PAYLOAD" \
  --cli-read-timeout 90 \
  response.json

echo ""
echo "📄 Response:"
if command -v jq &> /dev/null; then
  cat response.json | jq '.'
else
  cat response.json
fi

echo ""
echo "📊 Recent Lambda logs:"
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$AWS_REGION" --query 'logGroups[0]' &> /dev/null; then
  aws logs tail "$LOG_GROUP" --region "$AWS_REGION" --since 5m --format short 2>/dev/null | tail -20
else
  echo "⚠️  Log group not found: $LOG_GROUP"
fi

echo ""
echo "✅ Test complete!"
echo ""
echo "💡 Tip: Run this script twice in succession to see the difference between cold and warm starts!"

