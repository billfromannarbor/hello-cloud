# Kotlin/Spring Boot Multi-Cloud Application

A Spring Boot application designed to run across multiple cloud platforms (AWS, GCP) and deployment models (containers, Lambda, Kubernetes).

## Quick Start Guides

- **[QUICKSTART.md](QUICKSTART.md)** - General application setup
- **[LAMBDA-QUICKSTART.md](LAMBDA-QUICKSTART.md)** - ⚡ Deploy to AWS Lambda (with performance fixes)
- **[LAMBDA-PERFORMANCE.md](LAMBDA-PERFORMANCE.md)** - Deep dive into Lambda optimization

## Deployment Options

### 1. AWS Lambda (Serverless)
**Best for**: Event-driven workloads, variable traffic, cost optimization

✅ **Now includes AWS Lambda Web Adapter** for fast warm starts (<200ms)

```bash
# Quick deploy
./build-lambda-single.sh
./update-lambda-config.sh
./lambda-test.sh
```

📖 See [LAMBDA-QUICKSTART.md](LAMBDA-QUICKSTART.md) for details

### 2. ECS/EKS (Containers)
**Best for**: Consistent workloads, always-on services

```bash
docker build -t hello-cloud .
docker run -p 8080:8080 hello-cloud
```

### 3. Google Cloud Run/GKE
**Best for**: Multi-cloud strategy, GCP-native deployments

See `gcp/` directory for Kubernetes and App Engine configs.

## API Endpoints

### Basic health check
```bash
curl http://localhost:8080/api/health
```

### Hello endpoint
```bash
curl http://localhost:8080/api/hello
```

### Actuator health (detailed)
```bash
curl http://localhost:8080/actuator/health
```

### Metrics (Prometheus format)
```bash
curl http://localhost:8080/actuator/prometheus
```

## Configuration Profiles

- `aws` - AWS-specific configuration (ECS, EC2)
- `gcp` - GCP-specific configuration (Cloud Run, GKE)
- `lambda` - AWS Lambda optimized (lazy init, minimal resources)

## Lambda Performance Note

⚠️ **Spring Boot starts on every Lambda cold start!**

This project now uses **AWS Lambda Web Adapter** to keep Spring Boot running between invocations:
- Cold starts: ~20-30 seconds (one-time per container)
- Warm requests: ~50-200ms (100x faster!)

📖 See [LAMBDA-PERFORMANCE.md](LAMBDA-PERFORMANCE.md) for full details on how this works.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Spring Boot App                     │
├─────────────────────────────────────────────────────┤
│                                                       │
│  Deployment Options:                                 │
│                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ AWS Lambda   │  │   ECS/EKS    │  │ GCP Cloud │ │
│  │ (Serverless) │  │ (Containers) │  │ Run/GKE   │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
│                                                       │
└─────────────────────────────────────────────────────┘
```

## CI/CD

GitHub Actions workflows:
- `.github/workflows/docker-build-lambda.yml` - Build and deploy to Lambda
- `.github/workflows/docker-build-lambda-only.yml` - Lambda-only deployment

## Project Structure

```
hello-cloud/
├── src/main/kotlin/          # Application code
├── aws/                       # AWS-specific configs
├── gcp/                       # GCP-specific configs
├── build-lambda-single.sh     # Build Lambda image
├── update-lambda-config.sh    # Configure Lambda
├── lambda-test.sh             # Test Lambda function
└── Dockerfile                 # Multi-cloud container image
```

## Local Development & Testing

**Yes! Everything still works locally.** The Lambda optimizations don't affect local development.

### Quick Start (Development Mode)
```bash
# Standard Spring Boot development
./gradlew bootRun

# Access at http://localhost:8080
curl http://localhost:8080/api/hello
```

### Easy Testing Script
```bash
# Quick test with Gradle
./test-local.sh gradle

# Test with Docker container
./test-local.sh docker

# Run test suite
./test-local.sh test

# Quick smoke test (if app already running)
./test-local.sh quick
```

### Manual Testing

#### Run with Gradle (Fastest)
```bash
./gradlew bootRun
```

#### Build and Run JAR
```bash
./gradlew build
java -jar build/libs/hello-cloud-1.0.0.jar
```

#### Test with Docker
```bash
docker build -t hello-cloud .
docker run -p 8080:8080 hello-cloud
```

#### Run Tests
```bash
./gradlew test
```

📖 **Full guide**: [LOCAL-TESTING.md](LOCAL-TESTING.md) - Comprehensive local testing options

## Documentation

### General
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview
- [QUICKSTART.md](QUICKSTART.md) - General getting started

### Local Development
- [LOCAL-TESTING.md](LOCAL-TESTING.md) - ⭐ Local development & testing guide

### AWS Lambda
- [LAMBDA-QUICKSTART.md](LAMBDA-QUICKSTART.md) - ⚡ Lambda quick deploy
- [LAMBDA-PERFORMANCE.md](LAMBDA-PERFORMANCE.md) - Lambda optimization deep dive
- [LAMBDA-ARCHITECTURE-DIAGRAM.md](LAMBDA-ARCHITECTURE-DIAGRAM.md) - Visual architecture
- [LAMBDA-CHANGES-SUMMARY.md](LAMBDA-CHANGES-SUMMARY.md) - What changed and why

### AWS Setup
- [AWS-ECR-SETUP.md](AWS-ECR-SETUP.md) - ECR configuration
- [AWS-OIDC-SETUP.md](AWS-OIDC-SETUP.md) - GitHub Actions OIDC setup

## License

MIT
