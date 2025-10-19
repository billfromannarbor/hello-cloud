# hello-cloud Architecture

## Overview

hello-cloud is designed as a cloud-agnostic Spring Boot application that can seamlessly run on multiple cloud platforms (AWS, GCP) or locally without modification.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     Load Balancer                        │
│          (AWS ALB / GCP Load Balancer)                  │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼────────┐       ┌───────▼────────┐
│   Instance 1   │       │   Instance 2   │
│  ┌──────────┐  │       │  ┌──────────┐  │
│  │hello-cloud│  │       │  │hello-cloud│  │
│  │Container │  │       │  │Container │  │
│  └──────────┘  │       │  └──────────┘  │
└────────────────┘       └────────────────┘
        │                         │
        └────────────┬────────────┘
                     │
        ┌────────────▼────────────┐
        │  Metrics Collection     │
        │  (Prometheus/CloudWatch)│
        └─────────────────────────┘
```

## Components

### 1. Application Layer

**hello-cloudApplication**
- Entry point for the Spring Boot application
- Configured for auto-scanning of components
- Supports multiple Spring profiles (local, aws, gcp)

**Controllers**
- `HealthController`: Provides health checks and hello endpoints
  - `/api/health` - Detailed health with cloud metadata
  - `/api/hello` - Simple greeting endpoint
  - Automatically includes cloud provider information

### 2. Service Layer

**CloudMetadataService**
- Detects which cloud platform the app is running on
- Queries cloud-specific metadata services
- Falls back to LOCAL when not on a recognized platform
- Caches results for performance

Detection Logic:
1. Try AWS Instance Metadata Service (IMDSv2)
2. Try GCP Metadata Service
3. Default to LOCAL

### 3. Configuration

**Multi-Profile Configuration**
- `application.yml` - Base configuration
- `application-aws.yml` - AWS-specific overrides
- `application-gcp.yml` - GCP-specific overrides

**Key Features**
- Graceful shutdown support
- Prometheus metrics enabled
- Actuator endpoints exposed
- Configurable port via `PORT` environment variable

### 4. Containerization

**Docker**
- Multi-stage build (build stage + runtime stage)
- Uses Gradle to build JAR
- Runs on Alpine-based JRE for small image size
- Non-root user for security
- Health check configured

## Cloud-Agnostic Design Patterns

### 1. Metadata Abstraction

Instead of hardcoding cloud-specific logic, the application queries metadata services with fallback:

```kotlin
fun detectCloudProvider(): CloudInfo {
    // Try AWS
    val awsInfo = tryAWS()
    if (awsInfo != null) return awsInfo
    
    // Try GCP
    val gcpInfo = tryGCP()
    if (gcpInfo != null) return gcpInfo
    
    // Default to local
    return CloudInfo(provider = "LOCAL", ...)
}
```

### 2. Environment-Based Configuration

Uses Spring profiles and environment variables:
```yaml
server:
  port: ${PORT:8080}  # Configurable via env var
```

### 3. Standard Health Checks

Provides standard endpoints that work with any cloud's load balancer:
- `/api/health` - Custom health check
- `/actuator/health` - Spring Actuator health check

### 4. Containerization

Docker containers work identically on:
- AWS ECS/Fargate
- AWS EKS
- Google Cloud Run
- Google Kubernetes Engine (GKE)
- Local Docker

## Data Flow

### Request Flow

```
Client Request
    │
    ▼
Load Balancer (performs health checks)
    │
    ▼
Container/Instance
    │
    ▼
Spring Boot Application
    │
    ├─→ HealthController (handles /api/health, /api/hello)
    │       │
    │       ▼
    │   CloudMetadataService (detects cloud provider)
    │       │
    │       ▼
    │   Return response with cloud info
    │
    └─→ Actuator Endpoints (/actuator/health, /actuator/prometheus)
```

### Startup Flow

```
Application Start
    │
    ▼
Load Spring Context
    │
    ├─→ Initialize CloudMetadataService
    │       │
    │       ▼
    │   Detect Cloud Provider (one-time check)
    │       │
    │       └─→ Cache result
    │
    ├─→ Initialize Controllers
    │
    └─→ Start Embedded Tomcat
            │
            ▼
        Listen on port 8080
```

## Deployment Architectures

### AWS ECS/Fargate

```
Route 53 (DNS)
    │
    ▼
Application Load Balancer
    │
    ├─→ Target Group 1
    │       └─→ ECS Tasks (Container)
    │
    └─→ Target Group 2
            └─→ ECS Tasks (Container)
```

### Google Cloud Run

```
Cloud DNS
    │
    ▼
Cloud Load Balancer (automatic)
    │
    └─→ Cloud Run Service
            ├─→ Container Instance 1
            ├─→ Container Instance 2
            └─→ Container Instance N (auto-scales)
```

### Google Kubernetes Engine

```
Cloud DNS
    │
    ▼
GCP Load Balancer
    │
    └─→ GKE Service (LoadBalancer)
            │
            └─→ Kubernetes Pods
                    ├─→ Pod 1 (Container)
                    ├─→ Pod 2 (Container)
                    └─→ Pod N (Container)
```

## Security Architecture

### Container Security

1. **Non-root User**: Application runs as `spring` user, not root
2. **Read-only Filesystem**: Only /tmp is writable
3. **Minimal Base Image**: Uses Alpine Linux for smaller attack surface
4. **No Secrets in Image**: All secrets via environment variables

### Network Security

1. **HTTPS Termination**: At load balancer level
2. **Security Groups/Firewall**: Restrict access to necessary ports
3. **Private Subnets**: Application instances in private subnets (recommended)

### Metadata Service Security

1. **AWS IMDSv2**: Uses token-based authentication
2. **GCP Metadata**: Requires specific headers
3. **Timeout Protection**: Short timeouts prevent hanging

## Monitoring Architecture

### Metrics Collection

```
Application (Prometheus Exporter)
    │
    └─→ /actuator/prometheus endpoint
            │
            ├─→ Prometheus Server (scrapes metrics)
            │       │
            │       └─→ Grafana (visualization)
            │
            ├─→ AWS CloudWatch (via agent)
            │
            └─→ GCP Cloud Monitoring (via agent)
```

### Logging

- **Format**: JSON-structured logs (logstash format)
- **Destinations**:
  - AWS: CloudWatch Logs
  - GCP: Cloud Logging
  - Local: Console/File

## Scaling Architecture

### Horizontal Scaling

Application is stateless and scales horizontally:

**AWS**:
- ECS Service Auto Scaling based on CPU/Memory
- Target Tracking or Step Scaling policies

**GCP**:
- Cloud Run: Auto-scales 0 to N instances
- GKE: Horizontal Pod Autoscaler (HPA)

### Vertical Scaling

Adjust resources via configuration:
- ECS Task Definition: CPU/Memory allocation
- Cloud Run: Memory limits in deployment
- GKE: Resource requests/limits in Pod spec

## High Availability

### Multi-AZ Deployment

**AWS**:
```
Region: us-east-1
├─→ AZ 1 (us-east-1a): ECS Tasks
├─→ AZ 2 (us-east-1b): ECS Tasks
└─→ AZ 3 (us-east-1c): ECS Tasks
```

**GCP**:
```
Region: us-central1
├─→ Zone 1 (us-central1-a): Instances
├─→ Zone 2 (us-central1-b): Instances
└─→ Zone 3 (us-central1-c): Instances
```

### Health Checks

Load balancers perform health checks:
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 3 consecutive failures
- **Path**: `/actuator/health`

### Graceful Shutdown

```yaml
server:
  shutdown: graceful
```

- Spring Boot waits for active requests to complete
- New requests are rejected during shutdown
- Configurable timeout period

## Performance Considerations

### Cold Start Optimization

1. **JIT Compilation**: Uses Hotspot JVM
2. **Lazy Initialization**: Components initialized on-demand
3. **Connection Pooling**: Reuses HTTP connections
4. **Metadata Caching**: Cloud info cached after first detection

### Memory Management

- **Heap Size**: Auto-configured by JVM based on container limits
- **GC**: Uses G1GC (default in Java 21)
- **Native Memory**: Monitored via actuator metrics

## Future Enhancements

1. **Database Integration**: Add PostgreSQL with cloud-specific managed services
2. **Caching**: Add Redis for session storage
3. **Service Mesh**: Integrate with Istio (on Kubernetes)
4. **Circuit Breakers**: Add Resilience4j for fault tolerance
5. **Distributed Tracing**: Add OpenTelemetry
6. **API Gateway**: Use AWS API Gateway or GCP API Gateway
7. **Authentication**: Add OAuth2/OIDC support
8. **Multi-region**: Deploy across multiple regions with global load balancing

## Conclusion

hello-cloud demonstrates a truly cloud-agnostic architecture that can run on any major cloud platform without code changes. The design prioritizes portability, observability, and operational excellence.

