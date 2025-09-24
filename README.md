# AWS Lambda Pub/Sub Solution with SNS

A production-ready Publisher-Subscriber (Pub/Sub) solution using AWS Lambda and Amazon SNS as the message broker. This repository includes infrastructure as code, deployment automation, testing, and monitoring components.

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

- **Production-Ready**: Comprehensive error handling, monitoring, and logging
- **Modular Design**: Clean separation of concerns and reusable components
- **Infrastructure as Code**: Complete Terraform configuration
- **CI/CD Ready**: Automated deployment scripts and GitHub Actions
- **Monitoring**: CloudWatch dashboards, alarms, and custom metrics
- **Testing**: Unit tests, integration tests, and benchmarking tools
- **Security**: Least privilege IAM policies and VPC configuration

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
│   └── monitoring.tf
├── scripts/
│   ├── build.ps1
│   ├── deploy.ps1
│   ├── destroy.ps1
│   └── test.ps1
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

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Python 3.9+
- PowerShell 7+ (for deployment scripts)

### 1. Clone and Setup

```powershell
git clone <repository-url>
cd aws-lambda-pubsub-sns
```

### 2. Configure Variables

Copy and customize the Terraform variables:

```powershell
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your specific configuration
```

### 3. Deploy Infrastructure

```powershell
# Build Lambda packages
.\scripts\build.ps1

# Deploy infrastructure
.\scripts\deploy.ps1
```

### 4. Test the Solution

```powershell
# Run all tests
.\scripts\test.ps1

# Run benchmarks
python tests/benchmarks/benchmark.py
```

## Deployment Options

### Option 1: Using PowerShell Scripts (Recommended)

```powershell
# Full deployment
.\scripts\deploy.ps1

# Deploy specific environment
.\scripts\deploy.ps1 -Environment "production"

# Deploy with custom parameters
.\scripts\deploy.ps1 -Region "us-west-2" -Environment "staging"
```

### Option 2: Manual Terraform

```powershell
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply deployment
terraform apply -var-file="terraform.tfvars"
```

### Option 3: GitHub Actions CI/CD

Push to main branch to trigger automatic deployment via GitHub Actions.

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

### CloudWatch Dashboards

- **Lambda Metrics**: Duration, errors, invocations, throttles
- **SNS Metrics**: Messages published, delivery success/failure
- **Custom Business Metrics**: Message processing rates, latency

### Alarms

- High error rates
- Function timeouts
- SNS delivery failures
- DLQ message accumulation

### Logging

Structured JSON logging with correlation IDs for message tracing across the entire pipeline.

## Security

- **IAM Roles**: Least privilege access for all components
- **VPC Configuration**: Optional VPC deployment for network isolation
- **Encryption**: SNS topics encrypted with KMS
- **Secrets Management**: Integration with AWS Secrets Manager

## Cleanup

```powershell
# Destroy infrastructure
.\scripts\destroy.ps1

# Or manually with Terraform
cd terraform
terraform destroy -var-file="terraform.tfvars"
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

### Comprehensive Guides
- **[Architecture Documentation](docs/architecture.md)**: Detailed system architecture, design decisions, and component interactions
- **[Deployment Guide](docs/deployment.md)**: Step-by-step deployment instructions for all environments  
- **[Troubleshooting Guide](docs/troubleshooting.md)**: Common issues, solutions, and debugging procedures
- **[Benchmark Testing](tests/benchmarks/README.md)**: Performance testing and benchmarking documentation
- **[Monitoring Guide](monitoring/README.md)**: Comprehensive monitoring, alerting, and observability setup

### Quick References
- **API Documentation**: Function interfaces and message formats
- **Configuration Reference**: All available Terraform variables and options
- **Security Best Practices**: IAM policies, encryption, and security guidelines
- **Performance Tuning**: Optimization strategies and best practices

## Troubleshooting

For common issues and solutions, see the [Troubleshooting Guide](docs/troubleshooting.md).

### Quick Diagnostic Commands
```bash
# Check overall health
aws lambda list-functions --query 'Functions[?contains(FunctionName, `pubsub`)].FunctionName'

# View recent logs  
aws logs filter-log-events --log-group-name "/aws/lambda/pubsub-publisher" --start-time $(date -d '1 hour ago' +%s)000

# Check SNS metrics
aws cloudwatch get-metric-statistics --namespace AWS/SNS --metric-name NumberOfMessagesPublished --start-time $(date -d '1 hour ago' --iso-8601) --end-time $(date --iso-8601) --period 300 --statistics Sum --dimensions Name=TopicName,Value=pubsub-topic
```

## License

MIT License - see [LICENSE](LICENSE) file for details.