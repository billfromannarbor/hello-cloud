# Lambda Architecture with Web Adapter

## Before: Spring Boot Restarting on Every Invocation ❌

```
┌─────────────────────────────────────────────────────────────────┐
│ Request 1                                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Lambda Event → Start JVM → Init Spring → Start Tomcat → Response│
│                 (2-5s)      (10-20s)       (2-5s)      (200ms)   │
│                                                                   │
│  Total: ~20-30 seconds → TIMEOUT ⚠️                              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Request 2 (even if immediate!)                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Lambda Event → Start JVM → Init Spring → Start Tomcat → Response│
│                 (2-5s)      (10-20s)       (2-5s)      (200ms)   │
│                                                                   │
│  Total: ~20-30 seconds → TIMEOUT ⚠️                              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

Problem: Spring Boot is destroyed after each invocation!
```

## After: Lambda Web Adapter (Container Reuse) ✅

```
┌─────────────────────────────────────────────────────────────────┐
│ COLD START (First request or after idle timeout)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Lambda Container Starts                                      │
│     ├─ JVM initializes (2-5s)                                   │
│     ├─ Lambda Web Adapter starts (<1s)                          │
│     └─ Spring Boot starts (10-20s)                              │
│         └─ Tomcat listens on port 8080                          │
│                                                                   │
│  2. LWA Health Check                                             │
│     ├─ Polls: http://localhost:8080/actuator/health             │
│     └─ Status: UP ✅                                             │
│                                                                   │
│  3. Request Processing                                           │
│     ├─ Lambda event → LWA                                        │
│     ├─ LWA → Spring Boot (HTTP)                                  │
│     ├─ Spring Boot processes (200ms)                             │
│     └─ Response → LWA → Lambda                                   │
│                                                                   │
│  Total: ~20-30 seconds (one-time cost) ✅                        │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ WARM START (Subsequent requests)                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ⚡ Spring Boot ALREADY RUNNING! ⚡                               │
│                                                                   │
│  1. Request Processing                                           │
│     ├─ Lambda event → LWA (instant)                              │
│     ├─ LWA → Spring Boot (instant)                               │
│     ├─ Spring Boot processes (50-200ms)                          │
│     └─ Response → LWA → Lambda                                   │
│                                                                   │
│  Total: ~50-200ms (100x faster!) ✅                              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Component Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│ AWS Lambda Execution Environment                                   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ Lambda Runtime                                                │ │
│  │ ┌─────────────────────┐                                       │ │
│  │ │ Your Docker Image   │                                       │ │
│  │ │                     │                                       │ │
│  │ │  ┌───────────────────────────────────────────────────────┐ │ │
│  │ │  │ /opt/extensions/lambda-adapter                        │ │ │
│  │ │  │ (AWS Lambda Web Adapter)                              │ │ │
│  │ │  │                                                         │ │ │
│  │ │  │ Responsibilities:                                       │ │ │
│  │ │  │ 1. Receives Lambda events (API Gateway, ALB, etc.)    │ │ │
│  │ │  │ 2. Waits for app readiness (health check)             │ │ │
│  │ │  │ 3. Translates Lambda events → HTTP requests           │ │ │
│  │ │  │ 4. Forwards to localhost:8080                         │ │ │
│  │ │  │ 5. Translates HTTP response → Lambda response         │ │ │
│  │ │  └───────────────────────────────────────────────────────┘ │ │
│  │ │                              │                               │ │
│  │ │                              ↓ HTTP                          │ │
│  │ │  ┌───────────────────────────────────────────────────────┐ │ │
│  │ │  │ Spring Boot Application                               │ │ │
│  │ │  │                                                         │ │ │
│  │ │  │  ┌─────────────────────────────────────────────────┐  │ │ │
│  │ │  │  │ Embedded Tomcat Server                          │  │ │ │
│  │ │  │  │ Port: 8080                                      │  │ │ │
│  │ │  │  │                                                   │  │ │ │
│  │ │  │  │  /actuator/health  ← Health check endpoint      │  │ │ │
│  │ │  │  │  /api/hello        ← Your application endpoints │  │ │ │
│  │ │  │  │  /api/health       ← Your application endpoints │  │ │ │
│  │ │  │  └─────────────────────────────────────────────────┘  │ │ │
│  │ │  │                                                         │ │ │
│  │ │  │  ┌─────────────────────────────────────────────────┐  │ │ │
│  │ │  │  │ Spring Context (Stays Loaded!)                  │  │ │ │
│  │ │  │  │ - Controllers                                   │  │ │ │
│  │ │  │  │ - Services                                      │  │ │ │
│  │ │  │  │ - Beans                                         │  │ │ │
│  │ │  │  │ - Configuration                                 │  │ │ │
│  │ │  │  └─────────────────────────────────────────────────┘  │ │ │
│  │ │  └───────────────────────────────────────────────────────┘ │ │
│  │ └─────────────────────┘                                       │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                      │
└────────────────────────────────────────────────────────────────────┘
```

## Request Flow Sequence

### Cold Start Flow

```
External Request
     │
     ↓
API Gateway / ALB
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Invokes Function                                 │
│ Event: { rawPath: "/api/hello", method: "GET", ... }   │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Runtime: Initialize Container (if cold)         │
│ 1. Start Docker container                              │
│ 2. Load /opt/extensions (Lambda Web Adapter)           │
│ 3. Execute ENTRYPOINT (java -jar app.jar)              │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Web Adapter: Initialize                         │
│ 1. Start listening for Lambda events                   │
│ 2. Start health check polling                          │
│    └─ GET http://localhost:8080/actuator/health        │
│       (retry every 200ms, timeout after 10s)           │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Spring Boot: Initialize (10-20 seconds)                │
│ 1. Load Spring context                                 │
│ 2. Initialize beans (lazy where possible)              │
│ 3. Start Tomcat server on port 8080                    │
│ 4. Register endpoints                                  │
│ 5. Mark application as ready                           │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Web Adapter: Health Check Passes               │
│ Response from /actuator/health: { "status": "UP" }     │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Web Adapter: Process Request                   │
│ 1. Convert Lambda event to HTTP request                │
│    └─ GET /api/hello HTTP/1.1                          │
│       Host: localhost:8080                             │
│ 2. Send to Spring Boot via HTTP                        │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Spring Boot: Handle Request (~50-200ms)                │
│ 1. Route to controller                                 │
│ 2. Execute business logic                              │
│ 3. Return HTTP response                                │
│    └─ 200 OK, JSON body                                │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Web Adapter: Convert Response                  │
│ 1. Read HTTP response from Spring Boot                │
│ 2. Convert to Lambda response format                   │
│    └─ { statusCode: 200, body: "...", headers: {...} } │
└────────────────────────────────────────────────────────┘
     │
     ↓
Lambda Returns Response
     │
     ↓
API Gateway / ALB
     │
     ↓
Client receives response
```

### Warm Start Flow (Much Faster!)

```
External Request
     │
     ↓
API Gateway / ALB
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Invokes Function                                 │
│ Event: { rawPath: "/api/hello", method: "GET", ... }   │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Runtime: Reuse Existing Container ⚡             │
│ (Spring Boot already running!)                         │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Web Adapter: Process Request (instant)         │
│ 1. Convert Lambda event to HTTP request                │
│ 2. Send to Spring Boot (already listening!)            │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Spring Boot: Handle Request (~50-200ms)                │
│ (No initialization needed - already running!)          │
└────────────────────────────────────────────────────────┘
     │
     ↓
┌────────────────────────────────────────────────────────┐
│ Lambda Web Adapter: Convert Response                  │
└────────────────────────────────────────────────────────┘
     │
     ↓
Client receives response

Total time: ~50-200ms (100x faster than cold start!)
```

## Lambda Container Lifecycle

```
┌─────────────────────────────────────────────────────────┐
│ Container State Machine                                  │
└─────────────────────────────────────────────────────────┘

     [Container doesn't exist]
                │
                ↓ (First invocation or after freeze timeout)
     ┌──────────────────────┐
     │   COLD START         │ ← Initialization happens here
     │   (20-30 seconds)    │    - JVM starts
     │                      │    - Spring Boot initializes
     └──────────────────────┘    - Tomcat starts
                │
                ↓
     ┌──────────────────────┐
     │   WARM / READY       │ ← Container is reused
     │   (50-200ms)         │    - Spring Boot stays running
     │                      │    - No initialization needed
     └──────────────────────┘
                │
                │ (Concurrent request while warm)
                ├───────────────────┐
                │                   ↓
                │        ┌──────────────────────┐
                │        │   WARM / READY       │
                │        │   (50-200ms)         │
                │        └──────────────────────┘
                │
                ↓
     [Idle for ~10-15 minutes]
                │
                ↓
     ┌──────────────────────┐
     │   FROZEN             │ ← Container paused but not destroyed
     │                      │    - Can resume quickly
     └──────────────────────┘
                │
                ↓ (Next invocation)
     ┌──────────────────────┐
     │   THAW (~1-2 sec)    │ ← Resume from frozen state
     │                      │    - Faster than cold start
     └──────────────────────┘
                │
                ↓
     [Back to WARM state]

     Or after longer idle period:
                │
                ↓
     [Container destroyed] → Next request = COLD START again
```

## Key Optimizations Applied

### 1. Dockerfile
```dockerfile
# Add Lambda Web Adapter as extension
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 \
     /lambda-adapter /opt/extensions/lambda-adapter

# Configure how LWA interacts with Spring Boot
ENV AWS_LWA_PORT=8080
ENV AWS_LWA_READINESS_CHECK_PATH=/actuator/health
ENV AWS_LWA_INVOKE_MODE=response_stream
```

### 2. application-lambda.yml
```yaml
spring:
  main:
    lazy-initialization: true  # Load beans on-demand
    banner-mode: off           # Skip ASCII banner
  jmx:
    enabled: false             # Disable JMX overhead

server:
  tomcat:
    threads:
      max: 10                  # Fewer threads for Lambda
    max-connections: 50        # Limited connections needed
```

### 3. Lambda Configuration
```bash
Memory: 1024 MB   # More memory = more CPU = faster initialization
Timeout: 60s      # Allow time for cold starts
```

## Performance Metrics

### Cold Start Breakdown
```
┌─────────────────────────────────────────────────────┐
│ Component                 │ Time       │ Cumulative │
├─────────────────────────────────────────────────────┤
│ Container initialization  │ 1-2s       │ 1-2s       │
│ JVM startup               │ 2-5s       │ 3-7s       │
│ Spring context load       │ 10-15s     │ 13-22s     │
│ Tomcat startup            │ 2-3s       │ 15-25s     │
│ LWA health check passes   │ <1s        │ 15-26s     │
│ Request processing        │ 0.05-0.2s  │ 15-26s     │
├─────────────────────────────────────────────────────┤
│ TOTAL COLD START          │            │ 20-30s     │
└─────────────────────────────────────────────────────┘
```

### Warm Start Breakdown
```
┌─────────────────────────────────────────────────────┐
│ Component                 │ Time       │ Cumulative │
├─────────────────────────────────────────────────────┤
│ Lambda invocation         │ 5-10ms     │ 5-10ms     │
│ LWA event conversion      │ 1-5ms      │ 6-15ms     │
│ HTTP request to Spring    │ <1ms       │ 6-16ms     │
│ Spring request processing │ 30-150ms   │ 36-166ms   │
│ LWA response conversion   │ 1-5ms      │ 37-171ms   │
├─────────────────────────────────────────────────────┤
│ TOTAL WARM START          │            │ 50-200ms   │
└─────────────────────────────────────────────────────┘
```

## Comparison with Other Solutions

```
┌──────────────────────────────────────────────────────────────────┐
│ Solution              │ Cold Start │ Warm Start │ Complexity      │
├──────────────────────────────────────────────────────────────────┤
│ No optimization       │ 30s+       │ 30s+       │ Low             │
│ (timeouts!)           │ ❌         │ ❌         │ ✅              │
├──────────────────────────────────────────────────────────────────┤
│ Lambda Web Adapter    │ 20-30s     │ 50-200ms   │ Low             │
│ (current solution)    │ ⚠️         │ ✅         │ ✅              │
├──────────────────────────────────────────────────────────────────┤
│ Spring Cloud Function │ 15-20s     │ 50-100ms   │ Medium          │
│                       │ ⚠️         │ ✅         │ ⚠️              │
├──────────────────────────────────────────────────────────────────┤
│ Lambda SnapStart      │ 2-3s       │ 50-200ms   │ Low             │
│ (ZIP only)            │ ✅         │ ✅         │ ✅              │
├──────────────────────────────────────────────────────────────────┤
│ GraalVM Native        │ 0.5-1s     │ 50-100ms   │ High            │
│                       │ ✅         │ ✅         │ ❌              │
├──────────────────────────────────────────────────────────────────┤
│ ECS Fargate           │ 0ms        │ 50-200ms   │ Medium          │
│ (always on)           │ ✅         │ ✅         │ ⚠️              │
│                       │ (no cold   │            │ (higher         │
│                       │ starts)    │            │ baseline cost)  │
└──────────────────────────────────────────────────────────────────┘
```

## When Does Container Get Recycled?

AWS Lambda recycles containers:
1. **After idle period** (~10-15 minutes of no invocations)
2. **During Lambda scaling** (new containers for concurrent requests)
3. **During deployments** (code or configuration updates)
4. **Infrastructure maintenance** (rare, AWS-initiated)

## Summary

**The Magic**: Lambda Web Adapter keeps Spring Boot running between requests within the same container, avoiding repeated initialization overhead for warm starts.

**The Trade-off**: Cold starts are still slow (~20-30s), but they only happen:
- On first invocation
- After 10-15 minutes of inactivity
- During scaling events

For most workloads with regular traffic, 90%+ of requests will be warm starts (<200ms)!

