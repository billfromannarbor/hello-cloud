#!/bin/bash

# Build Docker image specifically for AWS Lambda (x86_64)
echo "Building Docker image for AWS Lambda..."

docker buildx build \
  --platform linux/amd64 \
  -t hello-cloud:lambda \
  -t ghcr.io/billfromannarbor/hello-cloud:lambda \
  --push \
  .

echo "✅ Built and pushed lambda-compatible image!"
echo "Image: ghcr.io/billfromannarbor/hello-cloud:lambda"
echo ""
echo "To deploy to Lambda, use this image URI:"
echo "ghcr.io/billfromannarbor/hello-cloud:lambda"


