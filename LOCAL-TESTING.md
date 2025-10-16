# Local Development & Testing Guide

## Quick Answer: Yes! Everything still works locally.

The Lambda Web Adapter changes don't affect local development. You have multiple ways to build and test.

---

## Option 1: Standard Spring Boot Development (Fastest)

### Run Directly with Gradle
```bash
# Standard Spring Boot development mode
./gradlew bootRun

# Or with specific profile
./gradlew bootRun --args='--spring.profiles.active=aws'
```

**Access your app:**
```bash
curl http://localhost:8080/api/hello
curl http://localhost:8080/api/health
curl http://localhost:8080/actuator/health
```

**Hot reload with continuous build:**
```bash
# Terminal 1: Watch for changes
./gradlew build --continuous

# Terminal 2: Run app
./gradlew bootRun
```

---

## Option 2: Build JAR and Run Locally

### Build the JAR
```bash
./gradlew clean build

# JAR will be at: build/libs/hello-cloud-1.0.0.jar
```

### Run the JAR
```bash
# Default profile
java -jar build/libs/hello-cloud-1.0.0.jar

# With AWS profile
java -jar build/libs/hello-cloud-1.0.0.jar --spring.profiles.active=aws

# With Lambda profile (will run locally)
java -jar build/libs/hello-cloud-1.0.0.jar --spring.profiles.active=lambda
```

---

## Option 3: Docker Container (Production-like)

### Build Docker Image
```bash
docker build -t hello-cloud .
```

### Run Container Locally
```bash
# Run with default (Lambda) profile
docker run -p 8080:8080 hello-cloud

# Or override with AWS profile
docker run -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=aws \
  hello-cloud

# Run in background
docker run -d -p 8080:8080 --name hello-cloud hello-cloud

# View logs
docker logs -f hello-cloud

# Stop
docker stop hello-cloud
docker rm hello-cloud
```

### Test the Container
```bash
# Wait for startup (check logs)
docker logs -f hello-cloud

# Once you see "Started HelloCloudApplication"
curl http://localhost:8080/api/hello
curl http://localhost:8080/actuator/health
```

---

## Option 4: Test Lambda Container Locally (Most Accurate)

The Lambda Web Adapter works locally too! This simulates the exact Lambda environment.

### Run Lambda Container
```bash
docker run -p 9000:8080 hello-cloud
```

**Note:** The Lambda Web Adapter will start, wait for Spring Boot to be ready, then forward requests.

### Test with Lambda Event Format
```bash
# Create a test event
cat > lambda-local-test.json <<'EOF'
{
  "rawPath": "/api/hello",
  "requestContext": {
    "http": {
      "method": "GET"
    }
  },
  "headers": {
    "content-type": "application/json"
  }
}
EOF

# Invoke using Lambda Runtime Interface
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d @lambda-local-test.json
```

### Test with HTTP (simpler)
```bash
# The Lambda Web Adapter also accepts HTTP directly
curl http://localhost:9000/api/hello
curl http://localhost:9000/actuator/health
```

---

## Option 5: Docker Compose (Multi-service)

If you want to test with databases, Redis, etc.

### docker-compose.yml (already exists)
```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=aws
```

### Run with Docker Compose
```bash
docker-compose up

# Or in background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

---

## Testing Different Profiles Locally

### Test AWS Profile
```bash
# Gradle
./gradlew bootRun --args='--spring.profiles.active=aws'

# JAR
java -jar build/libs/hello-cloud-1.0.0.jar --spring.profiles.active=aws

# Docker
docker run -p 8080:8080 -e SPRING_PROFILES_ACTIVE=aws hello-cloud
```

### Test Lambda Profile (with optimizations)
```bash
# This uses lazy initialization and minimal resources
./gradlew bootRun --args='--spring.profiles.active=lambda'

# Or
java -jar build/libs/hello-cloud-1.0.0.jar --spring.profiles.active=lambda

# Expected: Faster startup, fewer threads, minimal logging
```

### Test GCP Profile
```bash
./gradlew bootRun --args='--spring.profiles.active=gcp'
```

---

## Running Tests

### Run All Tests
```bash
./gradlew test

# View report
open build/reports/tests/test/index.html
```

### Run Specific Test
```bash
./gradlew test --tests "com.hellocloud.controller.HealthControllerTest"
```

### Run Tests with Coverage
```bash
./gradlew test jacocoTestReport

# View coverage report
open build/reports/jacoco/test/html/index.html
```

### Continuous Testing
```bash
./gradlew test --continuous
```

---

## Debugging Locally

### Debug with Gradle
```bash
./gradlew bootRun --debug-jvm

# Then attach your IDE debugger to port 5005
```

### Debug with JAR
```bash
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 \
  -jar build/libs/hello-cloud-1.0.0.jar
```

### Debug in IntelliJ IDEA
1. Create a new "Spring Boot" run configuration
2. Set main class: `com.hellocloud.HelloCloudApplicationKt`
3. Set VM options: `-Dspring.profiles.active=lambda`
4. Run in debug mode

### Debug in VS Code
Add to `.vscode/launch.json`:
```json
{
  "type": "kotlin",
  "request": "launch",
  "name": "Spring Boot",
  "mainClass": "com.hellocloud.HelloCloudApplicationKt",
  "args": "--spring.profiles.active=lambda"
}
```

---

## Testing Lambda Web Adapter Locally

### Verify LWA is Working
```bash
# Run container
docker run -p 8080:8080 hello-cloud

# In another terminal, watch logs
docker logs -f <container-id>

# You should see:
# 1. Lambda Web Adapter starts
# 2. Spring Boot initializes
# 3. Health check polling (GET /actuator/health)
# 4. "Application is ready" message
```

### Test Health Check
```bash
# This is what Lambda Web Adapter polls
curl http://localhost:8080/actuator/health

# Expected:
# {"status":"UP"}
```

---

## Performance Testing Locally

### Test Cold Start Simulation
```bash
# Start fresh container
docker run --rm -p 8080:8080 hello-cloud

# Time how long until ready
time curl --retry 30 --retry-delay 1 http://localhost:8080/actuator/health

# Should show ~15-20 seconds for local (faster than Lambda)
```

### Test Warm Performance
```bash
# Once app is running
for i in {1..10}; do
  curl -w "Time: %{time_total}s\n" -o /dev/null -s http://localhost:8080/api/hello
done

# Should show ~0.05-0.2 seconds per request
```

### Load Testing
```bash
# Install hey (HTTP load generator)
# macOS: brew install hey
# Linux: go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 10 http://localhost:8080/api/hello

# Results will show:
# - Requests per second
# - Response time distribution
# - Success rate
```

---

## Building for Different Platforms

### Build for Local Testing
```bash
# Standard build
docker build -t hello-cloud:local .

# Run
docker run -p 8080:8080 hello-cloud:local
```

### Build for Lambda (x86_64)
```bash
# Specify platform (important for M1/M2 Macs)
docker build --platform linux/amd64 -t hello-cloud:lambda .
```

### Build for ARM (if using ARM Lambda)
```bash
docker build --platform linux/arm64 -t hello-cloud:lambda-arm .
```

### Multi-platform Build
```bash
# Setup buildx (one-time)
docker buildx create --use

# Build for both platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t hello-cloud:multi \
  --load .
```

---

## Common Local Testing Workflows

### Workflow 1: Quick Iteration (Development)
```bash
# Use Gradle for fastest feedback
./gradlew bootRun

# Edit code, Spring DevTools will auto-reload
# Or restart manually with Ctrl+C
```

### Workflow 2: Test Before Commit
```bash
# 1. Run tests
./gradlew test

# 2. Build JAR
./gradlew build

# 3. Run JAR locally
java -jar build/libs/hello-cloud-1.0.0.jar --spring.profiles.active=lambda

# 4. Quick smoke test
curl http://localhost:8080/api/hello
curl http://localhost:8080/actuator/health

# 5. If all good, commit
git add .
git commit -m "Your changes"
```

### Workflow 3: Full Integration Test
```bash
# 1. Build Docker image
docker build -t hello-cloud:test .

# 2. Run container
docker run -d -p 8080:8080 --name test-container hello-cloud:test

# 3. Wait for startup
sleep 20

# 4. Run integration tests
./test-integration.sh  # or your test script

# 5. Clean up
docker stop test-container
docker rm test-container
```

### Workflow 4: Test Lambda Deployment Locally
```bash
# 1. Build exact Lambda image
docker build --platform linux/amd64 -t hello-cloud:lambda .

# 2. Run with Lambda Runtime Interface Emulator
docker run -p 9000:8080 hello-cloud:lambda

# 3. Test with Lambda event format
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d '{"rawPath":"/api/hello","requestContext":{"http":{"method":"GET"}}}'

# 4. Verify response matches expected Lambda format
```

---

## Troubleshooting Local Development

### Port Already in Use
```bash
# Find what's using port 8080
lsof -i :8080

# Kill it
kill -9 <PID>

# Or run on different port
./gradlew bootRun --args='--server.port=8081'
```

### Docker Build Fails
```bash
# Clear Docker cache
docker builder prune

# Build without cache
docker build --no-cache -t hello-cloud .
```

### Gradle Build Fails
```bash
# Clean everything
./gradlew clean

# Clear Gradle cache
rm -rf ~/.gradle/caches/

# Rebuild
./gradlew build
```

### Application Won't Start
```bash
# Check Java version
java -version  # Should be 17+

# Check logs for errors
./gradlew bootRun --debug

# Check if health endpoint works
curl http://localhost:8080/actuator/health
```

---

## IDE Setup

### IntelliJ IDEA
```bash
# Import as Gradle project
File → Open → Select build.gradle.kts

# Enable annotation processing (for Spring)
Settings → Build → Compiler → Annotation Processors → Enable

# Run configuration will auto-create
# Or create manually: Run → Edit Configurations → + → Spring Boot
```

### VS Code
```bash
# Install extensions:
# - Kotlin Language
# - Spring Boot Extension Pack
# - Gradle for Java

# Open folder
code .

# VS Code will detect Gradle and offer to import
```

---

## Environment-specific Testing

### Test with Environment Variables
```bash
# Set env vars
export DB_HOST=localhost
export DB_PORT=5432

# Run
./gradlew bootRun

# Or inline
DB_HOST=localhost ./gradlew bootRun
```

### Test with application.properties Override
```bash
# Create local override (not committed)
cat > src/main/resources/application-local.yml <<EOF
server:
  port: 8081
logging:
  level:
    com.hellocloud: DEBUG
EOF

# Run with local profile
./gradlew bootRun --args='--spring.profiles.active=local'
```

---

## Quick Reference

### Start Development Server
```bash
./gradlew bootRun
```

### Run Tests
```bash
./gradlew test
```

### Build Docker Image
```bash
docker build -t hello-cloud .
```

### Run Docker Container
```bash
docker run -p 8080:8080 hello-cloud
```

### Test Endpoint
```bash
curl http://localhost:8080/api/hello
```

### View Logs
```bash
# Gradle: shows in terminal
# Docker: docker logs -f <container-id>
# JAR: shows in terminal
```

---

## Summary

✅ **Standard development unchanged** - Use `./gradlew bootRun` as always  
✅ **Docker works locally** - Lambda Web Adapter is transparent  
✅ **All profiles testable** - AWS, GCP, Lambda configurations  
✅ **Tests work normally** - `./gradlew test`  
✅ **Debugging supported** - IDE, remote debugger, etc.  

**The Lambda Web Adapter doesn't interfere with local development at all!**

When running locally:
- Spring Boot starts normally on port 8080
- Lambda Web Adapter (if in container) just forwards HTTP requests
- You can test with regular HTTP requests (no Lambda event format needed)
- Everything behaves like a normal web application

The magic only happens when deployed to AWS Lambda! 🚀

