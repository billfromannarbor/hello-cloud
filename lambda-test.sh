#!/bin/bash

# Test AWS Lambda function

set -e

FUNCTION_NAME="${FUNCTION_NAME:-hello-cloud-lambda}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Testing Lambda function: $FUNCTION_NAME"
echo "Region: $AWS_REGION"
echo ""

# Test payload
TEST_PAYLOAD='{
  "rawPath": "/api/hello",
  "requestContext": {
    "http": {
      "method": "GET"
    }
  }
}'

echo "Invoking Lambda function..."
echo "Payload: $TEST_PAYLOAD"
echo ""

# Invoke the function
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --payload "$TEST_PAYLOAD" \
  --cli-read-timeout 60 \
  --cli-connect-timeout 60 \
  response.json

echo ""
echo "Response:"
cat response.json | jq '.'

echo ""
echo "Function logs:"
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  --query 'logGroups[0].logGroupName' \
  --output text | xargs -I {} aws logs tail {} --region "$AWS_REGION" --since 5m

