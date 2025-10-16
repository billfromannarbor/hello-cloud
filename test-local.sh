#!/bin/bash

# Local Testing Script
# Tests the application in different modes

set -e

echo "🧪 Hello Cloud - Local Testing Script"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local url=$1
    local name=$2
    echo -n "Testing ${name}... "
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${YELLOW}✗ FAILED${NC}"
        return 1
    fi
}

# Parse arguments
MODE=${1:-gradle}

case $MODE in
    gradle)
        echo -e "${BLUE}Mode: Gradle (Development)${NC}"
        echo ""
        echo "Starting Spring Boot with Gradle..."
        echo "Press Ctrl+C to stop"
        echo ""
        ./gradlew bootRun
        ;;
    
    jar)
        echo -e "${BLUE}Mode: JAR (Production)${NC}"
        echo ""
        
        # Build if needed
        if [ ! -f "build/libs/hello-cloud-1.0.0.jar" ]; then
            echo "Building JAR..."
            ./gradlew build -x test
        fi
        
        echo "Starting JAR..."
        echo "Press Ctrl+C to stop"
        echo ""
        java -jar build/libs/hello-cloud-1.0.0.jar --spring.profiles.active=lambda
        ;;
    
    docker)
        echo -e "${BLUE}Mode: Docker (Container)${NC}"
        echo ""
        
        # Check if Docker is running
        if ! docker info > /dev/null 2>&1; then
            echo "❌ Docker is not running. Please start Docker Desktop."
            exit 1
        fi
        
        # Build image
        echo "Building Docker image..."
        docker build -t hello-cloud-test .
        
        # Stop any existing container
        docker rm -f hello-cloud-test-container 2>/dev/null || true
        
        # Run container
        echo ""
        echo "Starting container..."
        docker run -d \
            --name hello-cloud-test-container \
            -p 8080:8080 \
            hello-cloud-test
        
        echo ""
        echo "Waiting for application to start (this takes ~15-20 seconds)..."
        sleep 5
        
        # Wait for health check
        for i in {1..30}; do
            if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Application started!${NC}"
                break
            fi
            echo -n "."
            sleep 1
        done
        echo ""
        
        # Run tests
        echo ""
        echo "Running tests..."
        test_endpoint "http://localhost:8080/api/hello" "Hello endpoint"
        test_endpoint "http://localhost:8080/api/health" "Health endpoint"
        test_endpoint "http://localhost:8080/actuator/health" "Actuator health"
        
        echo ""
        echo "Container is running. You can:"
        echo "  - Test endpoints: curl http://localhost:8080/api/hello"
        echo "  - View logs: docker logs -f hello-cloud-test-container"
        echo "  - Stop container: docker stop hello-cloud-test-container"
        echo ""
        echo "Press Enter to stop the container and clean up..."
        read
        
        echo "Stopping container..."
        docker stop hello-cloud-test-container
        docker rm hello-cloud-test-container
        
        echo -e "${GREEN}✓ Cleanup complete${NC}"
        ;;
    
    test)
        echo -e "${BLUE}Mode: Test Suite${NC}"
        echo ""
        ./gradlew test
        echo ""
        echo -e "${GREEN}✓ Tests complete${NC}"
        echo ""
        echo "View test report:"
        echo "  open build/reports/tests/test/index.html"
        ;;
    
    quick)
        echo -e "${BLUE}Mode: Quick Smoke Test${NC}"
        echo ""
        
        # Check if already running
        if curl -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
            echo "Application is already running on port 8080"
        else
            echo "❌ No application running on port 8080"
            echo ""
            echo "Start the application first:"
            echo "  ./test-local.sh gradle"
            echo "  ./test-local.sh jar"
            echo "  ./test-local.sh docker"
            exit 1
        fi
        
        echo ""
        echo "Running smoke tests..."
        test_endpoint "http://localhost:8080/api/hello" "Hello endpoint"
        test_endpoint "http://localhost:8080/api/health" "Health endpoint"
        test_endpoint "http://localhost:8080/actuator/health" "Actuator health"
        
        echo ""
        echo -e "${GREEN}✓ All smoke tests passed!${NC}"
        ;;
    
    *)
        echo "Usage: $0 [mode]"
        echo ""
        echo "Modes:"
        echo "  gradle   - Run with Gradle (fastest for development)"
        echo "  jar      - Build and run JAR (production-like)"
        echo "  docker   - Build and run Docker container (most accurate)"
        echo "  test     - Run test suite"
        echo "  quick    - Quick smoke test (requires app already running)"
        echo ""
        echo "Examples:"
        echo "  ./test-local.sh gradle"
        echo "  ./test-local.sh docker"
        echo "  ./test-local.sh test"
        exit 1
        ;;
esac

