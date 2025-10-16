# Spring Boot on AWS Lambda - Performance Guide

## The Problem

Running Spring Boot as-is in AWS Lambda causes **severe cold start issues**:

1. **Every Lambda invocation** (especially cold starts):
   - Starts the JVM (~2-5 seconds)
   - Initializes Spring context (~10-20 seconds)
   - Starts embedded Tomcat server (~2-5 seconds)
   - Loads all beans and dependencies

2. **Result**: 20-30+ second cold starts, leading to:
   - Timeouts (as you experienced)
   - Poor user experience
   - Higher costs (paying for initialization time)

## The Solution: AWS Lambda Web Adapter

### How It Works

The **AWS Lambda Web Adapter** (LWA) acts as a bridge between Lambda and your web application:

```
Lambda Invoke → Lambda Web Adapter → Spring Boot (keeps running!)
```

**Key Benefits:**
- ✅ **Spring Boot starts ONCE per container** (not per invocation)
- ✅ **Warm invocations are fast** (~50-200ms)
- ✅ **Minimal code changes** (just add the adapter to Dockerfile)
- ✅ **Only cold starts pay the initialization cost**

### Performance Comparison

| Scenario | Without Adapter | With Adapter |
|----------|----------------|--------------|
| **Cold Start** | 20-30 seconds | 20-30 seconds (one-time) |
| **Warm Invocation** | 20-30 seconds | 50-200 ms |
| **Timeout Risk** | HIGH ⚠️ | LOW ✅ |

### What We Changed

1. **Dockerfile** - Added Lambda Web Adapter:
   ```dockerfile
   COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter
   ```

2. **Lambda Configuration**:
   - Memory: 1024 MB (more memory = more CPU = faster cold starts)
   - Timeout: 60 seconds (accommodates cold starts)
   - Environment variables for LWA configuration

3. **application-lambda.yml** - Optimized for faster startup:
   - Lazy initialization
   - Reduced thread pools
   - Disabled unnecessary features (JMX, metrics)
   - Minimal connection pools

## Deployment Steps

### 1. Rebuild the Docker Image
```bash
# Build with Lambda Web Adapter
docker build -t hello-cloud-lambda .

# Tag for ECR (replace with your details)
docker tag hello-cloud-lambda:latest <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/test/hello-cloud:lambda-latest

# Push to ECR
aws ecr get-login-password --region <REGION> | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com
docker push <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/test/hello-cloud:lambda-latest
```

### 2. Update Lambda Configuration
```bash
# Run the update script
./update-lambda-config.sh

# Or use GitHub Actions (automatic on push)
```

### 3. Update Lambda Function Code
```bash
aws lambda update-function-code \
  --function-name hello-cloud-lambda \
  --region us-east-1 \
  --image-uri <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/test/hello-cloud:lambda-latest
```

### 4. Test
```bash
./lambda-test.sh
```

## Expected Performance

### Cold Start (first invocation or after idle):
- **Duration**: 20-30 seconds (one-time per container)
- **Billed Duration**: ~30 seconds
- **This is normal** - Spring Boot initialization takes time

### Warm Start (subsequent invocations):
- **Duration**: 50-200 ms
- **Billed Duration**: ~200 ms
- **This is where you win** - 100x faster!

## How Lambda Web Adapter Works

1. **Lambda invokes function** → LWA receives the event
2. **LWA checks if Spring Boot is ready**:
   - Polls `http://localhost:8080/actuator/health`
   - Waits up to 10 seconds for readiness
3. **LWA forwards request** to Spring Boot as HTTP
4. **Spring Boot processes** the request
5. **LWA returns response** to Lambda

**Key Insight**: Spring Boot stays running between invocations in the same container!

## Other Solutions (for Reference)

### Option 2: Spring Cloud Function
**Pros:**
- More Lambda-native approach
- Better integration with Lambda events

**Cons:**
- Requires significant code refactoring
- Still has Spring context initialization overhead
- More complex for web applications

### Option 3: Lambda SnapStart (Java)
**Pros:**
- Snapshots initialized application state
- Reduces cold starts by ~90%
- No code changes

**Cons:**
- Only works with ZIP-based deployments (not containers)
- Not available for container-based Lambda
- Java 11+ only

### Option 4: GraalVM Native Image
**Pros:**
- Sub-second cold starts
- Much smaller memory footprint
- Lower costs

**Cons:**
- Complex build process
- Limited Spring Boot feature support
- Longer build times (5-10 minutes)
- Some libraries don't work with native compilation

### Option 5: Switch to ECS/EKS
**Pros:**
- No cold starts
- Predictable performance
- Better for long-running processes

**Cons:**
- Always running = higher baseline cost
- More complex infrastructure
- Need to manage scaling

## Cost Optimization Tips

### 1. Increase Memory for Faster Cold Starts
- More memory = more CPU = faster initialization
- 1024 MB is a sweet spot for Spring Boot
- Test with 1536-2048 MB if budget allows

### 2. Keep Functions Warm
For production, use EventBridge to ping your function every 5 minutes:
```bash
# CloudWatch Events rule (keep warm)
aws events put-rule \
  --name keep-lambda-warm \
  --schedule-expression 'rate(5 minutes)'

aws events put-targets \
  --rule keep-lambda-warm \
  --targets "Id"="1","Arn"="arn:aws:lambda:region:account:function:hello-cloud-lambda"
```

### 3. Provisioned Concurrency
For critical workloads, use Provisioned Concurrency:
- Keeps N instances always warm
- No cold starts for those instances
- Higher cost but guaranteed performance

### 4. Monitor Cold Start Frequency
```bash
# Check CloudWatch Logs for "INIT_START"
aws logs filter-log-events \
  --log-group-name /aws/lambda/hello-cloud-lambda \
  --filter-pattern "INIT_START" \
  --start-time $(date -u -d '1 hour ago' +%s)000
```

## Monitoring

### Key Metrics to Watch

1. **Cold Start Duration** (Init Duration in logs)
2. **Warm Invocation Duration** (should be <200ms)
3. **Memory Usage** (optimize memory allocation)
4. **Timeout Rate** (should be 0% with proper config)

### CloudWatch Insights Queries

```sql
-- Average cold start time
filter @type = "REPORT"
| filter @message like /INIT_START/
| stats avg(@initDuration) as avgColdStart by bin(5m)

-- Warm invocation performance  
filter @type = "REPORT"
| filter @message not like /INIT_START/
| stats avg(@duration) as avgWarmDuration, max(@duration) as maxDuration by bin(5m)
```

## Troubleshooting

### Issue: Still Timing Out
**Solutions:**
1. Increase timeout to 90-120 seconds
2. Increase memory to 1536+ MB
3. Check application logs for errors during startup
4. Verify health check endpoint is accessible

### Issue: High Memory Usage
**Solutions:**
1. Review application-lambda.yml settings
2. Reduce thread pools further
3. Disable unused Spring Boot features
4. Consider reducing memory (may increase cold start time)

### Issue: Intermittent Failures
**Likely Cause:** Container recycling (cold starts)
**Solutions:**
1. Implement keep-warm strategy
2. Use Provisioned Concurrency
3. Add retry logic in API Gateway

## Best Practices

1. ✅ **Use lazy initialization** (already configured)
2. ✅ **Disable unnecessary features** (JMX, metrics, etc.)
3. ✅ **Minimize dependencies** (only include what you need)
4. ✅ **Use health checks** (LWA needs this to know when ready)
5. ✅ **Monitor cold starts** (set up CloudWatch alarms)
6. ✅ **Test thoroughly** (both cold and warm starts)

## Alternative: If Lambda Isn't Working

If Spring Boot + Lambda continues to be problematic, consider:

1. **AWS App Runner** - Managed container service, no cold starts
2. **ECS Fargate** - Container orchestration, more control
3. **Elastic Beanstalk** - Managed Spring Boot hosting
4. **API Gateway + Lambda** - Refactor to smaller Lambda functions

## References

- [AWS Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter)
- [Spring Boot Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/java-handler.html)
- [Lambda Performance Optimization](https://docs.aws.amazon.com/lambda/latest/operatorguide/perf-optimize.html)

