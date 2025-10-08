# hello-cloud Quick Start Guide

Get up and running with hello-cloud in minutes!

## Prerequisites Check

```bash
# Check Java version (need 17+)
java -version

# Check Docker (if using containers)
docker --version
```

## 1. Local Development (Fastest Way to Start)

```bash
cd /Users/bill/dev/hello-cloud

# Build and run
./gradlew bootRun
```

The application will start at `http://localhost:8080`

Test it:
```bash
# Basic health check
curl http://localhost:8080/api/health

# Hello endpoint
curl http://localhost:8080/api/hello

# Actuator health
curl http://localhost:8080/actuator/health

# Metrics
curl http://localhost:8080/actuator/prometheus
```

## 2. Docker (Production-like Environment)

```bash
cd /Users/bill/dev/hello-cloud

# Build and run with Docker Compose
docker-compose up --build
```

Access at `http://localhost:8080`

## 3. Deploy to AWS (Cloud Run)

### Option A: AWS Elastic Beanstalk (Easiest)

```bash
# Install EB CLI if not already installed
pip install awsebcli

# Initialize (one time)
eb init -p "Corretto 17" hello-cloud --region us-east-1

# Create environment and deploy
eb create hello-cloud-production

# Future deployments
./gradlew build
eb deploy
```

### Option B: AWS ECS with Fargate

```bash
# Build JAR
./gradlew build

# Create ECR repository
aws ecr create-repository --repository-name hello-cloud --region us-east-1

# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build and push
docker build -t hello-cloud .
docker tag hello-cloud:latest $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hello-cloud:latest
docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/hello-cloud:latest

# Update task definition with your account ID
sed -i '' "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" aws/task-definition.json
sed -i '' "s/<REGION>/us-east-1/g" aws/task-definition.json

# Create ECS cluster, task definition, and service via AWS Console or CLI
```

## 4. Deploy to Google Cloud (Fastest Cloud Deploy)

### Option A: Cloud Run (Recommended - Easiest)

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Deploy (Cloud Run builds automatically from source)
gcloud run deploy hello-cloud \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars SPRING_PROFILES_ACTIVE=gcp

# Get the URL
gcloud run services describe hello-cloud --region us-central1 --format 'value(status.url)'
```

### Option B: Google App Engine

```bash
# Deploy
gcloud app deploy gcp/app.yaml
```

### Option C: Google Kubernetes Engine (GKE)

```bash
# Create cluster
gcloud container clusters create hello-cloud-cluster \
  --num-nodes=3 \
  --region us-central1

# Build and push to GCR
docker build -t gcr.io/YOUR_PROJECT_ID/hello-cloud .
docker push gcr.io/YOUR_PROJECT_ID/hello-cloud

# Update the deployment YAML
sed -i '' 's/PROJECT_ID/YOUR_PROJECT_ID/g' gcp/kubernetes-deployment.yaml

# Deploy
kubectl apply -f gcp/kubernetes-deployment.yaml

# Get the external IP
kubectl get service hello-cloud-service
```

## Testing Your Deployment

Once deployed, test with:

```bash
# Replace YOUR_URL with your actual deployment URL
curl https://YOUR_URL/api/hello
curl https://YOUR_URL/api/health
```

Expected response from `/api/hello`:
```json
{
  "message": "Hello from AWS!",  // or "GCP!" or "LOCAL!"
  "provider": "AWS",
  "region": "us-east-1",
  "version": "1.0.0"
}
```

## Development Workflow

```bash
# Run tests
./gradlew test

# Build JAR
./gradlew build

# Run locally
./gradlew bootRun

# Build Docker image
docker build -t hello-cloud .

# Run Docker container
docker run -p 8080:8080 hello-cloud
```

## Monitoring

### View Logs

**AWS (ECS):**
```bash
# Via CloudWatch Logs
aws logs tail /ecs/hello-cloud --follow
```

**GCP (Cloud Run):**
```bash
# Via Cloud Logging
gcloud run services logs read hello-cloud --region us-central1 --follow
```

### Metrics

Access Prometheus metrics at:
- Local: `http://localhost:8080/actuator/prometheus`
- AWS: `https://your-aws-url.com/actuator/prometheus`
- GCP: `https://your-gcp-url.com/actuator/prometheus`

## Troubleshooting

### Build fails
```bash
# Clean and rebuild
./gradlew clean build --refresh-dependencies
```

### Tests fail
```bash
# Run with more details
./gradlew test --info
```

### Application won't start
```bash
# Check Java version
java -version  # Should be 17 or higher

# Run with debug logging
./gradlew bootRun --debug
```

### Docker build fails
```bash
# Clean Docker cache
docker system prune -a

# Rebuild
docker-compose build --no-cache
```

### Cloud deployment fails

**AWS:**
- Check IAM permissions
- Verify security groups allow incoming traffic
- Check CloudWatch logs for errors

**GCP:**
- Check that Cloud Build API is enabled
- Verify Cloud Run API is enabled
- Check that your account has necessary permissions

## Next Steps

1. **Add a Database**: Integrate PostgreSQL or MySQL
2. **Add Authentication**: Implement Spring Security
3. **Add CI/CD**: Set up GitHub Actions or Jenkins
4. **Configure Monitoring**: Set up Prometheus + Grafana
5. **Add Caching**: Integrate Redis
6. **API Documentation**: Add Swagger/OpenAPI

## Support

For issues or questions:
1. Check the main [README.md](README.md)
2. Review logs with `--debug` flag
3. Test health endpoints to verify services are running

## Key Files

- `build.gradle.kts` - Build configuration
- `src/main/resources/application.yml` - Main configuration
- `Dockerfile` - Container definition
- `aws/task-definition.json` - AWS ECS configuration
- `gcp/app.yaml` - Google App Engine configuration
- `gcp/kubernetes-deployment.yaml` - GKE configuration

