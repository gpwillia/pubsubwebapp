# AWS Lambda Pub/Sub Solution with SNS

A production-ready, multi-environment Publisher-Subscriber (Pub/Sub) solution using AWS Lambda and Amazon SNS as the message broker. This repository includes infrastructure as code, automated multi-environment deployment, comprehensive monitoring, and enterprise-grade features for dev, stage, and production environments.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Publisher     │───▶│   Amazon SNS    │───▶│   Subscriber    │
│   Lambda        │    │     Topic       │    │   Lambda        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                        │                        │
        ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  CloudWatch     │    │  CloudWatch     │    │  CloudWatch     │
│  Logs & Metrics │    │  Logs & Metrics │    │  Logs & Metrics │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Features

### 🏗️ **Multi-Environment Support**
- **Dev, Stage, Prod Environments**: Isolated Terraform workspaces with environment-specific configurations
- **Automated Deployment**: PowerShell deployment script with validation and safety checks
- **Environment Isolation**: Separate AWS resources, monitoring, and configuration per environment

### 🚀 **Production-Ready Architecture**
- **High Availability**: ARM64 Lambda architecture with configurable concurrency limits
- **Error Handling**: Dead Letter Queues, retry policies, and circuit breaker patterns
- **Monitoring**: Environment-specific CloudWatch alarms, dashboards, and custom metrics
- **Audit Trail**: DynamoDB-based audit logging for stage and production environments

### 🔒 **Enterprise Security**
- **Least Privilege IAM**: Environment-specific roles with minimal required permissions  
- **Encryption**: Optional encryption at rest and in transit
- **VPC Support**: Optional VPC deployment for network isolation
- **Message Filtering**: SNS message attribute filtering for environment routing

### 📊 **Comprehensive Observability**
- **15+ CloudWatch Alarms**: Performance, error rate, and throttling monitoring per environment
- **Custom Dashboards**: Environment-specific monitoring dashboards
- **X-Ray Tracing**: Distributed tracing enabled for production debugging
- **Query Definitions**: Pre-built CloudWatch Insights queries for troubleshooting

## Project Structure

```
aws-lambda-pubsub-sns/
├── README.md
├── .github/
│   └── workflows/
│       ├── deploy.yml
│       └── test.yml
├── src/
│   ├── publisher/
│   │   ├── lambda_function.py
│   │   ├── requirements.txt
│   │   └── config.py
│   └── subscriber/
│       ├── lambda_function.py
│       ├── requirements.txt
│       └── config.py
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── iam.tf
│   ├── lambda.tf
│   ├── sns.tf
│   ├── monitoring.tf
│   ├── terraform.tfvars.dev      # Dev environment config
│   ├── terraform.tfvars.stage    # Stage environment config
│   └── terraform.tfvars.prod     # Production environment config
├── deploy.ps1                    # Multi-environment deployment script
├── DEPLOYMENT.md                 # Comprehensive deployment guide
├── tests/
│   ├── unit/
│   │   ├── test_publisher.py
│   │   └── test_subscriber.py
│   ├── integration/
│   │   └── test_integration.py
│   └── benchmarks/
│       ├── benchmark.py
│       ├── requirements.txt
│       └── README.md
├── monitoring/
│   ├── dashboards/
│   └── alarms/
└── docs/
    ├── deployment.md
    ├── architecture.md
    └── benchmarks.md
```

## Quick Start

### Prerequisites

- **AWS CLI v2.x** configured with appropriate credentials for your account
- **Terraform >= 1.13** installed at `C:\terraform\terraform.exe` (or update path in deploy script)
- **PowerShell 5.1+** (Windows) or **PowerShell Core 7+** (cross-platform)
- **Python 3.9+** (for Lambda functions)

### 1. Clone and Setup

```powershell
git clone https://github.com/gpwillia/pubsubwebapp.git
cd aws-lambda-pubsub-sns
```

### 2. Deploy to Development Environment

```powershell
# Deploy to dev environment (existing configuration)
.\deploy.ps1 -Environment dev -Action apply -AutoApprove
```

### 3. Deploy to Stage Environment

```powershell
# Plan stage deployment (recommended first)
.\deploy.ps1 -Environment stage -Action plan

# Deploy to stage with enhanced monitoring
.\deploy.ps1 -Environment stage -Action apply
```

### 4. Deploy to Production Environment

```powershell
# Plan production deployment
.\deploy.ps1 -Environment prod -Action plan

# Deploy to production (requires manual confirmation)
.\deploy.ps1 -Environment prod -Action apply
```

### 5. Test the Solution

```powershell
# Test publisher Lambda
aws lambda invoke --function-name aws-lambda-pubsub-sns-dev-publisher --cli-binary-format raw-in-base64-out --payload file://test-payload.json response.json

# Check subscriber logs
aws logs tail /aws/lambda/aws-lambda-pubsub-sns-dev-subscriber --since 5m
```

## Multi-Environment Deployment

### Environment Configurations

| Environment | Resources | Monitoring | Features | Use Case |
|-------------|-----------|------------|----------|----------|
| **dev** | 20 resources | Basic | Simple setup | Development, testing |
| **stage** | 42 resources | Enhanced | Audit trail, 15 alarms | Pre-prod validation |
| **prod** | 45+ resources | Full | API Gateway, enhanced security | Production workloads |

### Deployment Commands

```powershell
# Development Environment
.\deploy.ps1 -Environment dev -Action plan
.\deploy.ps1 -Environment dev -Action apply -AutoApprove

# Stage Environment (with enhanced monitoring)
.\deploy.ps1 -Environment stage -Action plan
.\deploy.ps1 -Environment stage -Action apply

# Production Environment (requires confirmation)
.\deploy.ps1 -Environment prod -Action plan
.\deploy.ps1 -Environment prod -Action apply

# Destroy environment
.\deploy.ps1 -Environment dev -Action destroy
```

### Manual Terraform (Advanced Users)

```powershell
cd terraform

# Initialize and select workspace
terraform init
terraform workspace select dev  # or stage, prod

# Plan and apply
terraform plan -var-file="terraform.tfvars.dev"
terraform apply -var-file="terraform.tfvars.dev"

# Apply deployment
terraform apply -var-file="terraform.tfvars.dev"
```

## Environment-Specific Features

### Development Environment
- **Purpose**: Feature development, unit testing, experimentation
- **Resources**: 20 AWS resources
- **Lambda Memory**: Publisher (256MB), Subscriber (512MB)
- **Monitoring**: Basic CloudWatch logging
- **Cost**: Optimized for minimal cost

### Stage Environment  
- **Purpose**: Integration testing, performance validation, UAT
- **Resources**: 42 AWS resources
- **Lambda Memory**: Publisher (256MB), Subscriber (512MB)
- **Monitoring**: 15 CloudWatch alarms, custom dashboards
- **Features**: DynamoDB audit trail, X-Ray tracing, enhanced monitoring
- **Testing**: Production-like environment for comprehensive testing

### Production Environment
- **Purpose**: Live customer traffic, business-critical operations
- **Resources**: 45+ AWS resources
- **Lambda Memory**: Publisher (512MB), Subscriber (1024MB)
- **Monitoring**: Full observability, enhanced monitoring, backup enabled
- **Features**: API Gateway, extended log retention (30 days), concurrency controls
- **Security**: Enhanced IAM policies, encryption, optional VPC deployment

## Configuration

### Environment Variables

The solution supports multiple deployment environments through Terraform variables:

- `environment`: Environment name (dev, staging, production)
- `region`: AWS region for deployment
- `vpc_id`: VPC ID for Lambda functions (optional)
- `subnet_ids`: Subnet IDs for Lambda functions (optional)
- `enable_monitoring`: Enable CloudWatch dashboards and alarms
- `retention_in_days`: CloudWatch logs retention period

### Lambda Configuration

Both Publisher and Subscriber functions support configuration through environment variables:

- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `SNS_TOPIC_ARN`: SNS topic ARN (auto-configured by Terraform)
- `MAX_RETRIES`: Maximum retry attempts for failed operations
- `TIMEOUT_SECONDS`: Function timeout in seconds

## Testing

### Unit Tests

```powershell
# Run unit tests
python -m pytest tests/unit/ -v

# Run with coverage
python -m pytest tests/unit/ --cov=src --cov-report=html
```

### Integration Tests

```powershell
# Run integration tests (requires deployed infrastructure)
python -m pytest tests/integration/ -v
```

### Benchmarking

Comprehensive performance testing suite for analyzing system behavior under various loads:

```powershell
# Run all benchmark tests
python tests/benchmarks/benchmark.py --all

# Run specific benchmark types
python tests/benchmarks/benchmark.py --latency
python tests/benchmarks/benchmark.py --throughput
python tests/benchmarks/benchmark.py --message-sizes

# Generate detailed reports with charts
python tests/benchmarks/benchmark.py --all --output-dir ./benchmark-results
```

**Benchmark Types:**
- **Latency Testing**: End-to-end message processing latency (avg, p95, p99)
- **Throughput Testing**: Concurrent load testing with multiple publishers
- **Cold Start Analysis**: Lambda cold start performance measurement
- **Message Size Impact**: Performance variation with different payload sizes
- **CloudWatch Integration**: Real-time metrics collection and correlation

See [tests/benchmarks/README.md](tests/benchmarks/README.md) for detailed benchmark documentation.

## Monitoring and Observability

### Environment-Specific Monitoring

#### Development Environment
- **Basic Logging**: CloudWatch logs with 14-day retention
- **X-Ray Tracing**: Enabled for debugging and performance analysis

#### Stage Environment (15 CloudWatch Alarms)
- **Lambda Monitoring**: Duration, errors, throttles for both functions  
- **SNS Monitoring**: Delivery failures, failed notifications
- **Performance Alarms**: High duration, error rate thresholds
- **Custom Dashboards**: Environment-specific performance metrics
- **Query Definitions**: Pre-built CloudWatch Insights queries

#### Production Environment (15+ Alarms + Enhanced)
- **All Stage Features** plus:
- **Extended Retention**: 30-day log retention
- **Enhanced Monitoring**: Additional performance and security metrics
- **Backup Monitoring**: Data backup and recovery verification

### CloudWatch Resources Created

```bash
# Stage/Prod environments create:
- 15 CloudWatch Alarms (duration, errors, throttles)
- 2 CloudWatch Query Definitions  
- 1 Monitoring SNS Topic for alerts
- Custom CloudWatch Dashboard
- DynamoDB audit trail table
```

### Monitoring Examples

```powershell
# Check environment-specific logs
aws logs tail /aws/lambda/aws-lambda-pubsub-sns-stage-publisher --since 1h

# View CloudWatch alarms
aws cloudwatch describe-alarms --alarm-name-prefix "aws-lambda-pubsub-sns-stage"

# Check DynamoDB audit trail
aws dynamodb scan --table-name aws-lambda-pubsub-sns-stage-processing-results
```

## Security

- **IAM Roles**: Least privilege access for all components
- **VPC Configuration**: Optional VPC deployment for network isolation
- **Encryption**: SNS topics encrypted with KMS
- **Secrets Management**: Integration with AWS Secrets Manager

## Environment Management

### Switching Between Environments

```powershell
# List available Terraform workspaces
terraform workspace list

# Switch to specific environment
terraform workspace select stage

# Check current environment
terraform workspace show
```

### Environment Cleanup

```powershell
# Destroy specific environment
.\deploy.ps1 -Environment dev -Action destroy
.\deploy.ps1 -Environment stage -Action destroy  
.\deploy.ps1 -Environment prod -Action destroy

# Manual Terraform destroy
cd terraform
terraform workspace select dev
terraform destroy -var-file="terraform.tfvars.dev"
```

## Testing Across Environments

### End-to-End Testing

Create environment-specific test payload:

```json
{
  "message": "Hello from [environment]!",
  "messageAttributes": {
    "Environment": "dev"  // or "stage", "prod"
  }
}
```

### Testing Commands

```powershell
# Test Development Environment
aws lambda invoke --function-name aws-lambda-pubsub-sns-dev-publisher --cli-binary-format raw-in-base64-out --payload file://test-payload-dev.json response.json

# Test Stage Environment  
aws lambda invoke --function-name aws-lambda-pubsub-sns-stage-publisher --cli-binary-format raw-in-base64-out --payload file://test-payload-stage.json response.json

# Test Production Environment
aws lambda invoke --function-name aws-lambda-pubsub-sns-prod-publisher --cli-binary-format raw-in-base64-out --payload file://test-payload-prod.json response.json
```

### Verify Message Processing

```powershell
# Check subscriber logs for each environment
aws logs tail /aws/lambda/aws-lambda-pubsub-sns-dev-subscriber --since 5m
aws logs tail /aws/lambda/aws-lambda-pubsub-sns-stage-subscriber --since 5m  
aws logs tail /aws/lambda/aws-lambda-pubsub-sns-prod-subscriber --since 5m

# Check DLQ for failed messages (stage/prod)
aws sqs get-queue-attributes --queue-url https://sqs.us-east-1.amazonaws.com/[ACCOUNT]/aws-lambda-pubsub-sns-stage-dlq --attribute-names ApproximateNumberOfMessages
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Cost Optimization

- Lambda functions use ARM64 architecture for better price/performance
- CloudWatch log retention configured to optimize costs
- SNS topic configured with appropriate message retention
- Optional VPC deployment to control data transfer costs

## Documentation

### 📚 Comprehensive Guides
- **[Multi-Environment Deployment Guide](DEPLOYMENT.md)**: Complete guide for deploying across dev, stage, and prod environments
- **[Architecture Documentation](docs/architecture.md)**: Detailed system architecture, design decisions, and component interactions
- **[Troubleshooting Guide](docs/troubleshooting.md)**: Environment-specific issues, solutions, and debugging procedures
- **[Benchmark Testing](tests/benchmarks/README.md)**: Performance testing and benchmarking documentation
- **[Monitoring Guide](monitoring/README.md)**: Environment-specific monitoring, alerting, and observability setup

### 🔧 Configuration Files
- **`terraform.tfvars.dev`**: Development environment configuration (20 resources)
- **`terraform.tfvars.stage`**: Stage environment configuration (42 resources, enhanced monitoring)  
- **`terraform.tfvars.prod`**: Production environment configuration (45+ resources, full features)
- **`deploy.ps1`**: Multi-environment deployment automation script

### 📋 Quick References
- **Environment Comparison**: Feature matrix across dev/stage/prod environments
- **Deployment Commands**: PowerShell commands for each environment
- **Monitoring Resources**: CloudWatch alarms, dashboards, and queries per environment
- **Security Configuration**: Environment-specific IAM policies and encryption settings

## Troubleshooting

For comprehensive troubleshooting across all environments, see the [Multi-Environment Deployment Guide](DEPLOYMENT.md).

### Environment-Specific Diagnostic Commands

```powershell
# List functions by environment
aws lambda list-functions --query 'Functions[?contains(FunctionName, `aws-lambda-pubsub-sns-dev`)].FunctionName'
aws lambda list-functions --query 'Functions[?contains(FunctionName, `aws-lambda-pubsub-sns-stage`)].FunctionName'
aws lambda list-functions --query 'Functions[?contains(FunctionName, `aws-lambda-pubsub-sns-prod`)].FunctionName'

# Check environment-specific logs
aws logs filter-log-events --log-group-name "/aws/lambda/aws-lambda-pubsub-sns-dev-publisher" --since 1h
aws logs filter-log-events --log-group-name "/aws/lambda/aws-lambda-pubsub-sns-stage-subscriber" --since 1h

# Check CloudWatch alarms by environment
aws cloudwatch describe-alarms --alarm-name-prefix "aws-lambda-pubsub-sns-stage"
aws cloudwatch describe-alarms --alarm-name-prefix "aws-lambda-pubsub-sns-prod"

# Validate Terraform workspaces
terraform workspace list
terraform workspace show
```

## License

MIT License - see [LICENSE](LICENSE) file for details.