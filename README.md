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

## Development

### Local Development
```bash
./gradlew bootRun
```

### Run Tests
```bash
./gradlew test
```

### Build JAR
```bash
./gradlew build
```

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview
- [AWS-ECR-SETUP.md](AWS-ECR-SETUP.md) - ECR configuration
- [AWS-OIDC-SETUP.md](AWS-OIDC-SETUP.md) - GitHub Actions OIDC setup
- [LAMBDA-PERFORMANCE.md](LAMBDA-PERFORMANCE.md) - Lambda optimization guide
- [LAMBDA-QUICKSTART.md](LAMBDA-QUICKSTART.md) - Lambda quick deploy

## License

MIT
