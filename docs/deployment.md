# Deployment Guide

This comprehensive guide covers all deployment scenarios, from local development to production deployment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Local Development](#local-development)
4. [Development Environment Deployment](#development-environment-deployment)
5. [Staging Environment Deployment](#staging-environment-deployment)
6. [Production Environment Deployment](#production-environment-deployment)
7. [CI/CD Pipeline Setup](#cicd-pipeline-setup)
8. [Post-Deployment Verification](#post-deployment-verification)
9. [Rollback Procedures](#rollback-procedures)
10. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

#### Development Machine
- **Operating System**: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 18.04+)
- **Memory**: Minimum 8GB RAM (16GB recommended)
- **Storage**: Minimum 10GB free space

#### Required Software
```powershell
# Check installations
aws --version          # AWS CLI v2.0+
terraform --version    # Terraform v1.0+
python --version       # Python 3.9+
git --version         # Git 2.20+
```

#### Required Tools Installation

**AWS CLI v2:**
```powershell
# Windows (PowerShell)
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "AWSCLIV2.msi"
Start-Process msiexec.exe -ArgumentList '/i AWSCLIV2.msi /quiet' -Wait

# macOS
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Terraform:**
```powershell
# Windows (PowerShell with Chocolatey)
choco install terraform

# macOS (Homebrew)
brew install terraform

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### AWS Account Setup

#### AWS Account Requirements
- AWS Account with appropriate permissions
- IAM User or Role with necessary policies
- Service limits sufficient for deployment

#### Required AWS Services
- AWS Lambda
- Amazon SNS
- Amazon SQS
- Amazon CloudWatch
- AWS IAM
- Amazon DynamoDB (optional)
- Amazon API Gateway (optional)

#### IAM Permissions

**Minimum Required Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "sns:*",
        "sqs:*",
        "iam:*",
        "cloudwatch:*",
        "logs:*",
        "apigateway:*",
        "dynamodb:*",
        "kms:*",
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "*"
    }
  ]
}
```

**Production Deployment Permissions (more restrictive):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:ListFunctions",
        "lambda:TagResource",
        "lambda:UntagResource"
      ],
      "Resource": "arn:aws:lambda:*:*:function:pubsub-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:GetTopicAttributes",
        "sns:SetTopicAttributes",
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:TagResource",
        "sns:UntagResource"
      ],
      "Resource": "arn:aws:sns:*:*:pubsub-*"
    }
  ]
}
```

## Environment Setup

### AWS Credentials Configuration

#### Method 1: AWS CLI Configuration
```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: us-east-1
# Default output format: json
```

#### Method 2: Environment Variables
```powershell
# Windows PowerShell
$env:AWS_ACCESS_KEY_ID = "your-access-key"
$env:AWS_SECRET_ACCESS_KEY = "your-secret-key"
$env:AWS_DEFAULT_REGION = "us-east-1"

# Linux/macOS
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Method 3: IAM Roles (Recommended for EC2/ECS)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Repository Setup

#### Clone Repository
```bash
git clone https://github.com/your-org/aws-lambda-pubsub-sns.git
cd aws-lambda-pubsub-sns
```

#### Verify Project Structure
```bash
ls -la
# Should show:
# - src/
# - terraform/
# - scripts/
# - tests/
# - .github/
# - README.md
```

## Local Development

### Development Environment Setup

#### Python Virtual Environment
```powershell
# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows
.\venv\Scripts\Activate.ps1
# macOS/Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r tests/unit/requirements.txt
```

#### Local Testing Setup

**Install Test Dependencies:**
```bash
pip install pytest pytest-cov moto boto3
```

**Run Unit Tests:**
```powershell
# Run all unit tests
python -m pytest tests/unit/ -v

# Run with coverage
python -m pytest tests/unit/ --cov=src --cov-report=html

# Run specific test file
python -m pytest tests/unit/test_publisher.py -v
```

### Local Lambda Development

#### Using AWS SAM (Optional)
```bash
# Install SAM CLI
pip install aws-sam-cli

# Build local environment
sam build

# Start local API
sam local start-api

# Invoke function locally
sam local invoke PublisherFunction --event events/test-event.json
```

#### Direct Function Testing
```python
# Create test script: test_local.py
import sys
import os
sys.path.append('src/publisher')

from lambda_function import lambda_handler

# Test event
test_event = {
    "message": "Hello from local test",
    "timestamp": "2024-12-01T14:30:22Z"
}

# Test context (mock)
class MockContext:
    aws_request_id = "test-request-id"
    log_group_name = "/aws/lambda/test"
    log_stream_name = "test-stream"
    function_name = "test-function"
    function_version = "1"
    memory_limit_in_mb = "256"

# Run test
result = lambda_handler(test_event, MockContext())
print(f"Result: {result}")
```

## Development Environment Deployment

### Configuration

#### Create Development Configuration
```bash
# Copy example configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars.dev

# Edit configuration
```

**terraform.tfvars.dev:**
```hcl
# Development Environment Configuration
environment = "dev"
aws_region  = "us-east-1"

# Lambda Configuration
lambda_memory_size = 256
lambda_timeout     = 30
lambda_runtime     = "python3.9"

# Monitoring (disabled for cost savings)
enable_monitoring = false

# VPC Configuration (disabled for simplicity)
vpc_config = {
  vpc_id     = null
  subnet_ids = []
}

# Tags
tags = {
  Environment = "development"
  Project     = "pubsub-solution"
  Owner       = "dev-team"
}
```

### Deployment Steps

#### 1. Build Lambda Packages
```powershell
.\scripts\build.ps1
```

#### 2. Initialize Terraform
```bash
cd terraform
terraform init
```

#### 3. Plan Deployment
```bash
terraform plan -var-file="terraform.tfvars.dev" -out="dev.tfplan"
```

#### 4. Apply Deployment
```bash
terraform apply "dev.tfplan"
```

#### 5. Verify Deployment
```bash
# Check outputs
terraform output

# Test Lambda function
aws lambda invoke --function-name pubsub-dev-publisher --payload '{"message":"test"}' response.json
```

### Development Workflow

#### Daily Development Cycle
```powershell
# 1. Pull latest changes
git pull origin main

# 2. Make code changes
# Edit src/publisher/lambda_function.py or src/subscriber/lambda_function.py

# 3. Run local tests
python -m pytest tests/unit/ -v

# 4. Build and deploy
.\scripts\build.ps1
.\scripts\deploy.ps1 -Environment dev

# 5. Run integration tests
.\scripts\test.ps1 -Environment dev

# 6. Commit changes
git add .
git commit -m "feat: add new feature"
git push origin feature-branch
```

## Staging Environment Deployment

### Configuration

**terraform.tfvars.staging:**
```hcl
# Staging Environment Configuration
environment = "staging"
aws_region  = "us-east-1"

# Lambda Configuration
lambda_memory_size = 512
lambda_timeout     = 60
lambda_runtime     = "python3.9"

# Monitoring (enabled for testing)
enable_monitoring = true

# VPC Configuration (optional)
vpc_config = {
  vpc_id     = "vpc-12345678"
  subnet_ids = ["subnet-12345678", "subnet-87654321"]
}

# Performance Settings
reserved_concurrent_executions = 50

# Tags
tags = {
  Environment = "staging"
  Project     = "pubsub-solution"
  Owner       = "dev-team"
}
```

### Deployment Process

#### 1. Prepare Staging Environment
```bash
# Create staging workspace
terraform workspace new staging
terraform workspace select staging
```

#### 2. Deploy Infrastructure
```powershell
# Build packages
.\scripts\build.ps1

# Deploy to staging
.\scripts\deploy.ps1 -Environment staging
```

#### 3. Run Full Test Suite
```powershell
# Run integration tests
.\scripts\test.ps1 -Environment staging -IncludeBenchmarks

# Verify monitoring
# Check CloudWatch dashboard
# Verify alarms are configured
```

#### 4. Performance Validation
```bash
# Run benchmark tests
python tests/benchmarks/benchmark.py --all

# Check results
cat benchmark-results/benchmark-report-*.txt
```

## Production Environment Deployment

### Pre-Production Checklist

#### Security Review
- [ ] IAM roles follow least privilege principle
- [ ] Encryption enabled for all data stores
- [ ] VPC configuration properly secured
- [ ] Secrets stored in AWS Secrets Manager
- [ ] Resource access logging enabled

#### Performance Review
- [ ] Lambda memory and timeout optimized
- [ ] Concurrency limits configured
- [ ] DLQ configuration validated
- [ ] Monitoring and alerting configured
- [ ] Backup and recovery procedures tested

#### Documentation Review
- [ ] Architecture documentation updated
- [ ] Runbook procedures documented
- [ ] Troubleshooting guide complete
- [ ] Monitoring playbooks ready

### Production Configuration

**terraform.tfvars.prod:**
```hcl
# Production Environment Configuration
environment = "prod"
aws_region  = "us-east-1"

# Lambda Configuration (optimized)
lambda_memory_size = 1024
lambda_timeout     = 300
lambda_runtime     = "python3.9"
lambda_architecture = "arm64"

# High Availability
enable_monitoring = true
enable_api_gateway = true

# VPC Configuration (required for production)
vpc_config = {
  vpc_id     = "vpc-prod12345"
  subnet_ids = ["subnet-prod123", "subnet-prod456"]
}

# Performance Settings
reserved_concurrent_executions = 1000

# Monitoring Configuration
alarm_error_rate_threshold = 0.01  # 1% error rate
alarm_duration_threshold   = 5000  # 5 seconds

# Backup Configuration
enable_backup = true
backup_retention_days = 30

# Tags
tags = {
  Environment = "production"
  Project     = "pubsub-solution"
  Owner       = "platform-team"
  CostCenter  = "engineering"
}
```

### Production Deployment Process

#### 1. Blue-Green Deployment Setup

**Create Blue Environment:**
```bash
# Create production workspace
terraform workspace new prod-blue
terraform workspace select prod-blue

# Deploy blue environment
terraform apply -var-file="terraform.tfvars.prod"
```

**Deploy Green Environment:**
```bash
# Create green workspace
terraform workspace new prod-green
terraform workspace select prod-green

# Deploy green environment with new code
terraform apply -var-file="terraform.tfvars.prod"
```

#### 2. Traffic Migration

**DNS/Route 53 Configuration:**
```hcl
resource "aws_route53_record" "api" {
  zone_id = var.hosted_zone_id
  name    = "pubsub-api"
  type    = "CNAME"
  ttl     = "60"
  
  weighted_routing_policy {
    weight = var.traffic_weight  # 0-100
  }
  
  set_identifier = var.environment
  records        = [aws_apigateway_domain_name.main.cloudfront_domain_name]
}
```

**Gradual Traffic Shift:**
```bash
# Start with 10% traffic to green
terraform apply -var="traffic_weight=10"

# Monitor for 15 minutes
# If healthy, increase to 50%
terraform apply -var="traffic_weight=50"

# Monitor for 30 minutes
# If healthy, complete migration
terraform apply -var="traffic_weight=100"
```

#### 3. Production Validation

**Health Checks:**
```bash
# API health check
curl -X GET https://pubsub-api.yourdomain.com/health

# Lambda function test
aws lambda invoke --function-name pubsub-prod-publisher --payload '{"test":"true"}' response.json

# SNS topic validation
aws sns publish --topic-arn arn:aws:sns:us-east-1:account:pubsub-prod-topic --message "Production validation test"
```

**Monitoring Validation:**
```bash
# Check CloudWatch dashboard
aws cloudwatch get-dashboard --dashboard-name "pubsub-prod-dashboard"

# Verify alarms
aws cloudwatch describe-alarms --alarm-name-prefix "pubsub-prod"

# Test alert notifications
aws sns publish --topic-arn arn:aws:sns:us-east-1:account:pubsub-prod-alerts --message "Test alert"
```

#### 4. Post-Deployment Tasks

**Enable Monitoring:**
```bash
# Subscribe to alert notifications
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:account:pubsub-prod-alerts --protocol email --notification-endpoint ops@yourcompany.com

# Configure PagerDuty integration (if applicable)
aws sns subscribe --topic-arn arn:aws:sns:us-east-1:account:pubsub-prod-alerts --protocol https --notification-endpoint https://events.pagerduty.com/integration/YOUR_INTEGRATION_KEY/enqueue
```

**Document Deployment:**
```bash
# Create deployment record
echo "Deployment $(date): Production deployment completed
- Version: $(git rev-parse --short HEAD)
- Environment: production
- Deployed by: $(whoami)
- Traffic: 100% to new version" >> deployment-log.md
```

## CI/CD Pipeline Setup

### GitHub Actions Configuration

#### Repository Secrets Setup
```bash
# Required secrets in GitHub repository settings
AWS_ACCESS_KEY_ID         # AWS access key
AWS_SECRET_ACCESS_KEY     # AWS secret key
TERRAFORM_CLOUD_TOKEN     # Terraform Cloud token (if using)
SLACK_WEBHOOK_URL         # Slack notifications (optional)
```

#### Workflow Configuration

**.github/workflows/deploy.yml:**
```yaml
name: Deploy to AWS

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.6.0

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        pip install -r requirements.txt
        pip install -r tests/unit/requirements.txt
    
    - name: Run unit tests
      run: |
        python -m pytest tests/unit/ -v --cov=src --cov-report=xml
    
    - name: Upload coverage
      uses: codecov/codecov-action@v3

  deploy-staging:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TERRAFORM_VERSION }}
    
    - name: Build Lambda packages
      run: ./scripts/build.ps1
      shell: pwsh
    
    - name: Terraform Init
      run: |
        cd terraform
        terraform init
    
    - name: Terraform Plan
      run: |
        cd terraform
        terraform workspace select staging || terraform workspace new staging
        terraform plan -var-file="terraform.tfvars.staging"
    
    - name: Terraform Apply
      run: |
        cd terraform
        terraform apply -var-file="terraform.tfvars.staging" -auto-approve
    
    - name: Run integration tests
      run: |
        export TEST_AWS_REGION=${{ env.AWS_REGION }}
        export TEST_SNS_TOPIC_ARN=$(cd terraform && terraform output -raw sns_topic_arn)
        export TEST_PUBLISHER_FUNCTION_NAME=$(cd terraform && terraform output -raw publisher_function_name)
        python -m pytest tests/integration/ -v

  deploy-production:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: ${{ env.TERRAFORM_VERSION }}
    
    - name: Build Lambda packages
      run: ./scripts/build.ps1
      shell: pwsh
    
    - name: Terraform Init
      run: |
        cd terraform
        terraform init
    
    - name: Terraform Plan
      run: |
        cd terraform
        terraform workspace select production || terraform workspace new production
        terraform plan -var-file="terraform.tfvars.prod"
    
    - name: Deploy with approval
      uses: trstringer/manual-approval@v1
      with:
        secret: ${{ github.TOKEN }}
        approvers: platform-team
        minimum-approvals: 2
        issue-title: "Production Deployment Approval"
    
    - name: Terraform Apply
      run: |
        cd terraform
        terraform apply -var-file="terraform.tfvars.prod" -auto-approve
    
    - name: Run production smoke tests
      run: |
        export TEST_AWS_REGION=${{ env.AWS_REGION }}
        export TEST_SNS_TOPIC_ARN=$(cd terraform && terraform output -raw sns_topic_arn)
        export TEST_PUBLISHER_FUNCTION_NAME=$(cd terraform && terraform output -raw publisher_function_name)
        python tests/integration/smoke_tests.py
    
    - name: Notify deployment success
      if: success()
      run: |
        curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
          -H 'Content-type: application/json' \
          --data '{"text":"✅ Production deployment successful!"}'
```

### Alternative CI/CD Platforms

#### AWS CodePipeline
```yaml
# buildspec.yml for AWS CodeBuild
version: 0.2

phases:
  install:
    runtime-versions:
      python: 3.9
    commands:
      - pip install --upgrade pip
      - pip install -r requirements.txt
      - pip install -r tests/unit/requirements.txt
  
  pre_build:
    commands:
      - echo "Running unit tests..."
      - python -m pytest tests/unit/ -v
  
  build:
    commands:
      - echo "Building Lambda packages..."
      - ./scripts/build.ps1
      - echo "Deploying infrastructure..."
      - cd terraform
      - terraform init
      - terraform plan -var-file="terraform.tfvars.${ENVIRONMENT}"
      - terraform apply -var-file="terraform.tfvars.${ENVIRONMENT}" -auto-approve
  
  post_build:
    commands:
      - echo "Running integration tests..."
      - python -m pytest tests/integration/ -v
      - echo "Deployment completed successfully"

artifacts:
  files:
    - '**/*'
```

#### Jenkins Pipeline
```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        TERRAFORM_VERSION = '1.6.0'
    }
    
    stages {
        stage('Test') {
            steps {
                sh 'pip install -r requirements.txt'
                sh 'python -m pytest tests/unit/ -v'
            }
        }
        
        stage('Build') {
            steps {
                sh './scripts/build.ps1'
            }
        }
        
        stage('Deploy Staging') {
            when { branch 'main' }
            steps {
                sh '''
                    cd terraform
                    terraform init
                    terraform workspace select staging
                    terraform plan -var-file="terraform.tfvars.staging"
                    terraform apply -var-file="terraform.tfvars.staging" -auto-approve
                '''
            }
        }
        
        stage('Deploy Production') {
            when { branch 'main' }
            steps {
                input message: 'Deploy to production?', ok: 'Deploy'
                sh '''
                    cd terraform
                    terraform workspace select production
                    terraform plan -var-file="terraform.tfvars.prod"
                    terraform apply -var-file="terraform.tfvars.prod" -auto-approve
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'dist/*.zip', fingerprint: true
        }
        failure {
            emailext (
                subject: "Deployment Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "Build failed. Check console output at ${env.BUILD_URL}",
                to: "devops@yourcompany.com"
            )
        }
    }
}
```

## Post-Deployment Verification

### Automated Verification Tests

#### Health Check Script
```python
#!/usr/bin/env python3
"""
Post-deployment health check script
"""
import boto3
import json
import time
import sys

def check_lambda_function(function_name, region):
    """Test Lambda function invocation"""
    lambda_client = boto3.client('lambda', region_name=region)
    
    test_payload = {
        "message": "Health check test",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ")
    }
    
    try:
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(test_payload)
        )
        
        if response['StatusCode'] == 200:
            print(f"✅ {function_name}: OK")
            return True
        else:
            print(f"❌ {function_name}: Failed - Status {response['StatusCode']}")
            return False
            
    except Exception as e:
        print(f"❌ {function_name}: Error - {e}")
        return False

def check_sns_topic(topic_arn, region):
    """Test SNS topic"""
    sns_client = boto3.client('sns', region_name=region)
    
    try:
        response = sns_client.get_topic_attributes(TopicArn=topic_arn)
        print(f"✅ SNS Topic: OK")
        return True
    except Exception as e:
        print(f"❌ SNS Topic: Error - {e}")
        return False

def check_cloudwatch_dashboard(dashboard_name, region):
    """Verify CloudWatch dashboard exists"""
    cloudwatch_client = boto3.client('cloudwatch', region_name=region)
    
    try:
        response = cloudwatch_client.get_dashboard(DashboardName=dashboard_name)
        print(f"✅ CloudWatch Dashboard: OK")
        return True
    except Exception as e:
        print(f"❌ CloudWatch Dashboard: Error - {e}")
        return False

def main():
    region = 'us-east-1'
    environment = sys.argv[1] if len(sys.argv) > 1 else 'dev'
    
    print(f"Running health checks for {environment} environment...")
    
    checks = [
        check_lambda_function(f'pubsub-{environment}-publisher', region),
        check_lambda_function(f'pubsub-{environment}-subscriber', region),
        check_sns_topic(f'arn:aws:sns:{region}:account:pubsub-{environment}-topic', region),
        check_cloudwatch_dashboard(f'pubsub-{environment}-dashboard', region)
    ]
    
    if all(checks):
        print("\n🎉 All health checks passed!")
        sys.exit(0)
    else:
        print("\n💥 Some health checks failed!")
        sys.exit(1)

if __name__ == '__main__':
    main()
```

#### Integration Test Suite
```bash
# Run comprehensive integration tests
python tests/integration/test_integration.py

# Run performance benchmarks
python tests/benchmarks/benchmark.py --latency --throughput

# Verify monitoring
python scripts/verify_monitoring.py
```

### Manual Verification Checklist

#### Infrastructure Verification
- [ ] Lambda functions deployed and configured correctly
- [ ] SNS topic created with proper subscriptions
- [ ] SQS DLQ configured and empty
- [ ] CloudWatch logs groups created
- [ ] IAM roles and policies applied correctly

#### Functional Verification
- [ ] Publisher function accepts and processes messages
- [ ] SNS topic receives and distributes messages
- [ ] Subscriber function processes messages successfully
- [ ] Error handling works (test with invalid message)
- [ ] DLQ captures failed messages

#### Performance Verification
- [ ] End-to-end latency within acceptable limits
- [ ] Throughput meets requirements
- [ ] Concurrent execution works properly
- [ ] Memory and CPU utilization optimal

#### Monitoring Verification
- [ ] CloudWatch dashboard displays metrics
- [ ] Alarms configured and functional
- [ ] Log aggregation working
- [ ] Alert notifications configured

## Rollback Procedures

### Automated Rollback

#### Terraform State Rollback
```bash
# List Terraform state versions
terraform state list

# Show current state
terraform show

# Rollback to previous version
terraform apply -target=aws_lambda_function.publisher \
  -var="lambda_package_hash=previous_hash"
```

#### Git-based Rollback
```bash
# Find previous working commit
git log --oneline -10

# Create rollback branch
git checkout -b rollback-$(date +%Y%m%d-%H%M)

# Reset to previous commit
git reset --hard PREVIOUS_COMMIT_HASH

# Force deploy previous version
./scripts/deploy.ps1 -Environment production -Force
```

### Emergency Rollback

#### Lambda Function Rollback
```bash
# List function versions
aws lambda list-versions-by-function --function-name pubsub-prod-publisher

# Rollback to previous version
aws lambda update-alias \
  --function-name pubsub-prod-publisher \
  --name LIVE \
  --function-version PREVIOUS_VERSION
```

#### DNS Rollback (Blue-Green)
```bash
# Switch traffic back to blue environment
terraform workspace select prod-blue
terraform apply -var="traffic_weight=100"
```

### Rollback Verification

#### Post-Rollback Checks
```bash
# Verify rollback success
python scripts/health_check.py production

# Check error rates
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=pubsub-prod-publisher \
  --start-time $(date -d '10 minutes ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 60 \
  --statistics Sum

# Verify traffic routing
nslookup pubsub-api.yourdomain.com
```

## Troubleshooting

### Common Deployment Issues

#### Terraform State Lock
```bash
# Error: Backend initialization required
terraform init -reconfigure

# Error: State file locked
terraform force-unlock LOCK_ID
```

#### Lambda Package Size
```bash
# Error: Request entity too large
# Solution: Optimize dependencies or use layers
pip install --target ./package -r requirements.txt
zip -r lambda-package.zip . -x "*.git*" "tests/*" "docs/*"
```

#### IAM Permission Issues
```bash
# Error: Access denied
# Check current identity
aws sts get-caller-identity

# Validate permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::account:user/username \
  --action-names lambda:CreateFunction \
  --resource-arns arn:aws:lambda:us-east-1:account:function:test
```

### Monitoring Deployment Issues

#### CloudWatch Dashboard Not Updating
```bash
# Check metric filters
aws logs describe-metric-filters \
  --log-group-name /aws/lambda/pubsub-prod-publisher

# Test metric publication
aws cloudwatch put-metric-data \
  --namespace "PubSubSolution" \
  --metric-data MetricName=TestMetric,Value=1
```

#### Alarms Not Triggering
```bash
# Check alarm state
aws cloudwatch describe-alarms \
  --alarm-names pubsub-prod-publisher-high-error-rate

# Test alarm
aws cloudwatch set-alarm-state \
  --alarm-name pubsub-prod-publisher-high-error-rate \
  --state-value ALARM \
  --state-reason "Testing alarm"
```

For additional troubleshooting, see [docs/troubleshooting.md](troubleshooting.md).

### Support and Escalation

#### Internal Support
1. Check monitoring dashboard
2. Review recent deployment logs
3. Consult troubleshooting guide
4. Engage platform team

#### AWS Support
- For AWS service issues
- Infrastructure problems
- Performance optimization

#### Emergency Contacts
- On-call engineer: [contact info]
- Platform team lead: [contact info]
- AWS TAM: [contact info]

This deployment guide provides comprehensive coverage for all deployment scenarios. Always test in lower environments before production deployment and maintain proper backup and rollback procedures.