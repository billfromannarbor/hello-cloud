# Local Testing vs Lambda Deployment

## TL;DR: Yes! Everything works locally unchanged.

The Lambda Web Adapter changes **only affect AWS Lambda deployment**. Your local development workflow is completely unaffected.

---

## Local Development (Unchanged ✅)

### Development Mode
```bash
./gradlew bootRun
# App starts on http://localhost:8080
# Hot reload with Spring DevTools
# Full debugging support
```

**Startup time:** 10-15 seconds (normal Spring Boot)  
**Test with:** `curl http://localhost:8080/api/hello`

### Docker (Local)
```bash
docker build -t hello-cloud .
docker run -p 8080:8080 hello-cloud
```

**What happens:**
1. Spring Boot starts on port 8080
2. Lambda Web Adapter starts in the container
3. LWA transparently forwards HTTP requests to Spring Boot
4. You can use regular HTTP requests (no Lambda event format needed)

**Startup time:** 15-20 seconds (slightly slower than bare JVM)  
**Test with:** `curl http://localhost:8080/api/hello`

---

## Lambda Deployment (Optimized ⚡)

### Cold Start (First Invocation)
```bash
# AWS Lambda invokes your function
aws lambda invoke --function-name hello-cloud-lambda ...
```

**What happens:**
1. Lambda container starts
2. JVM initializes
3. Lambda Web Adapter starts
4. Spring Boot initializes
5. LWA waits for `/actuator/health` to be UP
6. Request is processed
7. **Container stays running for next request!**

**Startup time:** 20-30 seconds (one-time per container)  
**Test with:** `./lambda-test.sh`

### Warm Start (Subsequent Invocations)
```bash
# Same function, but container is already running
aws lambda invoke --function-name hello-cloud-lambda ...
```

**What happens:**
1. Lambda invokes existing container
2. LWA receives event
3. LWA forwards to Spring Boot (already running!)
4. Response returned

**Startup time:** 50-200ms (100x faster!)  
**Test with:** `./lambda-test.sh` (run twice)

---

## Side-by-Side Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│ Local Development                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ./gradlew bootRun                                               │
│       │                                                           │
│       ↓                                                           │
│  ┌─────────────────────────────────────────────┐                │
│  │ Spring Boot Server                          │                │
│  │ - Starts on port 8080                       │                │
│  │ - Listens for HTTP requests                 │                │
│  │ - Regular Spring Boot behavior              │                │
│  │                                              │                │
│  │ curl http://localhost:8080/api/hello        │                │
│  │   → GET /api/hello → Controller → Response  │                │
│  └─────────────────────────────────────────────┘                │
│                                                                   │
│  Startup: 10-15 seconds                                          │
│  Request: 50-200ms                                               │
│  Behavior: Standard Spring Boot ✅                               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Local Docker                                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  docker run -p 8080:8080 hello-cloud                             │
│       │                                                           │
│       ↓                                                           │
│  ┌─────────────────────────────────────────────┐                │
│  │ Docker Container                            │                │
│  │                                              │                │
│  │  ┌────────────────────────────────────┐    │                │
│  │  │ Lambda Web Adapter (port 8080)     │    │                │
│  │  │ - Transparent HTTP proxy            │    │                │
│  │  └───────────────┬────────────────────┘    │                │
│  │                  ↓                           │                │
│  │  ┌────────────────────────────────────┐    │                │
│  │  │ Spring Boot (also port 8080)       │    │                │
│  │  │ - Receives HTTP from LWA           │    │                │
│  │  └────────────────────────────────────┘    │                │
│  │                                              │                │
│  │ curl http://localhost:8080/api/hello        │                │
│  │   → LWA → Spring Boot → Response            │                │
│  └─────────────────────────────────────────────┘                │
│                                                                   │
│  Startup: 15-20 seconds                                          │
│  Request: 50-200ms                                               │
│  Behavior: Same as production Lambda container ✅                │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ AWS Lambda (Cold Start)                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  aws lambda invoke --function-name hello-cloud-lambda            │
│       │                                                           │
│       ↓                                                           │
│  ┌─────────────────────────────────────────────┐                │
│  │ Lambda Execution Environment                │                │
│  │                                              │                │
│  │  Lambda Event (API Gateway format)          │                │
│  │       │                                      │                │
│  │       ↓                                      │                │
│  │  ┌────────────────────────────────────┐    │                │
│  │  │ Lambda Web Adapter                 │    │                │
│  │  │ - Translates Lambda event → HTTP   │    │                │
│  │  │ - Waits for health check           │    │                │
│  │  └───────────────┬────────────────────┘    │                │
│  │                  ↓                           │                │
│  │  ┌────────────────────────────────────┐    │                │
│  │  │ Spring Boot                        │    │                │
│  │  │ - Initializes (lazy mode)          │    │                │
│  │  │ - Health check passes              │    │                │
│  │  │ - Processes request                │    │                │
│  │  └────────────────────────────────────┘    │                │
│  │                                              │                │
│  │  Container stays running! ⚡                │                │
│  └─────────────────────────────────────────────┘                │
│                                                                   │
│  Startup: 20-30 seconds (one-time)                               │
│  Request: 50-200ms after startup                                 │
│  Behavior: Container persists for next request ✅                │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ AWS Lambda (Warm Start)                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  aws lambda invoke --function-name hello-cloud-lambda            │
│       │                                                           │
│       ↓                                                           │
│  ┌─────────────────────────────────────────────┐                │
│  │ Lambda Execution Environment (REUSED!)      │                │
│  │                                              │                │
│  │  Lambda Event                                │                │
│  │       │                                      │                │
│  │       ↓                                      │                │
│  │  ┌────────────────────────────────────┐    │                │
│  │  │ Lambda Web Adapter (running)       │    │                │
│  │  │ - Instant event translation        │    │                │
│  │  └───────────────┬────────────────────┘    │                │
│  │                  ↓                           │                │
│  │  ┌────────────────────────────────────┐    │                │
│  │  │ Spring Boot (ALREADY RUNNING!) ⚡  │    │                │
│  │  │ - No initialization needed          │    │                │
│  │  │ - Instant response                  │    │                │
│  │  └────────────────────────────────────┘    │                │
│  └─────────────────────────────────────────────┘                │
│                                                                   │
│  Startup: 0ms (container reused)                                 │
│  Request: 50-200ms (100x faster!)                                │
│  Behavior: This is the magic! ✨                                 │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Testing Workflows

### 1. Quick Development (Use this most often)
```bash
# Start dev server
./gradlew bootRun

# Or use the helper script
./test-local.sh gradle

# Edit code, test, repeat
curl http://localhost:8080/api/hello
```

**When to use:** Daily development, quick iterations  
**Speed:** Fastest startup, instant feedback

---

### 2. Pre-Commit Testing
```bash
# Run tests
./gradlew test

# Build to verify no issues
./gradlew build

# Quick smoke test
java -jar build/libs/hello-cloud-1.0.0.jar --spring.profiles.active=lambda
curl http://localhost:8080/api/hello
```

**When to use:** Before committing code  
**Speed:** 2-3 minutes total

---

### 3. Pre-Deploy Testing (Docker)
```bash
# Test exact container that will go to Lambda
./test-local.sh docker

# Or manually:
docker build -t hello-cloud-test .
docker run -p 8080:8080 hello-cloud-test
curl http://localhost:8080/api/hello
```

**When to use:** Before deploying to AWS  
**Speed:** 5 minutes (includes build time)

---

### 4. Lambda Integration Testing
```bash
# Deploy to Lambda
git push origin main  # Triggers GitHub Actions

# Wait for deployment (~2-3 minutes)

# Test Lambda
./lambda-test.sh

# First invocation: ~20-30s (cold start)
# Second invocation: ~200ms (warm start)
```

**When to use:** Final validation in Lambda environment  
**Speed:** 3-5 minutes (includes deployment)

---

## What Changed vs What Didn't

### ✅ Unchanged (Still Works Exactly the Same)

- `./gradlew bootRun` - Standard development
- `./gradlew test` - Test suite
- `./gradlew build` - Build process
- IDE debugging (IntelliJ, VS Code, etc.)
- Hot reload / DevTools
- Running JAR directly
- All Spring Boot features
- HTTP endpoints and APIs
- Configuration profiles (aws, gcp, lambda)

### ⚡ New/Enhanced (Lambda Only)

- Lambda Web Adapter in Docker image (transparent locally)
- Optimized `application-lambda.yml` (faster startup)
- Lambda keeps Spring Boot running between requests
- 100x faster warm starts in Lambda
- Helper scripts: `test-local.sh`, `lambda-test.sh`
- Comprehensive documentation

---

## Common Questions

### Q: Will the Lambda Web Adapter slow down local development?
**A:** No! When running locally (Gradle or Docker), there's no noticeable difference. LWA adds <100ms overhead in Docker, which is negligible.

### Q: Do I need to use Lambda event format locally?
**A:** No! You can use regular HTTP requests:
```bash
# This works locally:
curl http://localhost:8080/api/hello

# Lambda event format also works (if needed):
curl -XPOST http://localhost:9000/2015-03-31/functions/function/invocations \
  -d '{"rawPath":"/api/hello",...}'
```

### Q: Can I debug the Lambda container locally?
**A:** Yes! Run the Docker container and attach a remote debugger:
```bash
docker run -p 8080:8080 -p 5005:5005 \
  -e JAVA_TOOL_OPTIONS='-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005' \
  hello-cloud

# Then attach your IDE to localhost:5005
```

### Q: Which profile should I use for local testing?
**A:** Any profile works:
```bash
# Default (no profile)
./gradlew bootRun

# AWS profile
./gradlew bootRun --args='--spring.profiles.active=aws'

# Lambda profile (optimized settings)
./gradlew bootRun --args='--spring.profiles.active=lambda'

# GCP profile
./gradlew bootRun --args='--spring.profiles.active=gcp'
```

### Q: How do I know if Lambda Web Adapter is working?
**A:** Check Docker logs:
```bash
docker run -p 8080:8080 hello-cloud

# You'll see:
# 1. "AWS Lambda Web Adapter" starting
# 2. Spring Boot initialization
# 3. "Polling for readiness: GET /actuator/health"
# 4. "Application is ready"
```

---

## Quick Reference Card

| Task | Command | Time |
|------|---------|------|
| **Start dev server** | `./gradlew bootRun` | 10-15s |
| **Run tests** | `./gradlew test` | 30s |
| **Build JAR** | `./gradlew build` | 20s |
| **Run JAR** | `java -jar build/libs/hello-cloud-1.0.0.jar` | 10-15s |
| **Build Docker** | `docker build -t hello-cloud .` | 2-3min |
| **Run Docker** | `docker run -p 8080:8080 hello-cloud` | 15-20s |
| **Test endpoint** | `curl http://localhost:8080/api/hello` | <100ms |
| **Test Lambda (cold)** | `./lambda-test.sh` | 20-30s |
| **Test Lambda (warm)** | `./lambda-test.sh` (again) | 50-200ms |

---

## Summary

✅ **Local development is completely unchanged**  
✅ **All tools and workflows work exactly as before**  
✅ **Lambda Web Adapter is transparent in local development**  
✅ **Docker testing gives you production-like environment**  
✅ **Helper scripts make testing even easier**  

**The only difference**: When deployed to AWS Lambda, your app runs 100x faster on warm starts! 🚀

📖 **More details**: [LOCAL-TESTING.md](LOCAL-TESTING.md)

