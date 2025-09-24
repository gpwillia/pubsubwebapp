# Architecture Documentation

This document provides a comprehensive overview of the AWS Lambda Pub/Sub solution architecture, design decisions, and implementation details.

## Table of Contents

1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow](#data-flow)
4. [Security Model](#security-model)
5. [Scalability and Performance](#scalability-and-performance)
6. [Monitoring and Observability](#monitoring-and-observability)
7. [Disaster Recovery](#disaster-recovery)
8. [Design Decisions](#design-decisions)

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                 AWS Cloud                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐              │
│  │   API Gateway   │    │   Publisher     │    │   Amazon SNS    │              │
│  │   (Optional)    │───▶│   Lambda        │───▶│     Topic       │────┐         │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘    │         │
│           │                        │                        │          │         │
│           ▼                        ▼                        ▼          ▼         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    │         │
│  │  CloudWatch     │    │  CloudWatch     │    │  CloudWatch     │    │         │
│  │  Logs & Metrics │    │  Logs & Metrics │    │  Logs & Metrics │    │         │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘    │         │
│                                                                         │         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    │         │
│  │   Subscriber    │◀───│   Subscriber    │◀───┤   Amazon SNS    │◀───┘         │
│  │   Lambda 1      │    │   Lambda N      │    │   Subscription  │              │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘              │
│           │                        │                        │                    │
│           ▼                        ▼                        ▼                    │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐              │
│  │   DynamoDB      │    │   Amazon SQS    │    │   CloudWatch    │              │
│  │  Audit Trail    │    │  Dead Letter    │    │   Alarms &      │              │
│  │  (Optional)     │    │    Queue        │    │   Dashboard     │              │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘              │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Core Components

1. **Publisher Lambda Function**: Receives messages and publishes them to SNS topic
2. **SNS Topic**: Message broker that distributes messages to all subscribers
3. **Subscriber Lambda Function(s)**: Processes messages from SNS topic
4. **Dead Letter Queue (DLQ)**: Captures failed message processing attempts
5. **CloudWatch**: Comprehensive monitoring, logging, and alerting
6. **Optional Components**: API Gateway, DynamoDB audit trail, VPC configuration

## Component Architecture

### Publisher Lambda Function

#### Responsibilities
- Input validation and sanitization
- Message enrichment (correlation IDs, timestamps)
- SNS message publishing with retry logic
- Error handling and logging
- Custom metrics publication

#### Technical Details
```python
# Key architectural patterns in publisher
class MessagePublisher:
    def __init__(self):
        self.sns_client = boto3.client('sns')  # Connection reuse
        self.cloudwatch = boto3.client('cloudwatch')
        
    def publish_message(self, message, correlation_id):
        # Validation, enrichment, publishing, monitoring
        pass
```

#### Configuration
- **Runtime**: Python 3.9 on ARM64 architecture
- **Memory**: 256MB (configurable)
- **Timeout**: 30 seconds (configurable)
- **Concurrency**: Reserved concurrency limits
- **Environment**: VPC-enabled (optional)

### SNS Topic

#### Configuration
- **Message Retention**: 14 days
- **Delivery Retry Policy**: Exponential backoff with jitter
- **Encryption**: KMS encryption at rest
- **Access Policy**: Least privilege access

#### Message Attributes
```json
{
  "MessageId": "sns-generated-id",
  "Message": "actual-message-content",
  "MessageAttributes": {
    "CorrelationId": "uuid-v4",
    "Environment": "production",
    "MessageType": "business-event",
    "Timestamp": "ISO-8601-datetime"
  }
}
```

### Subscriber Lambda Function

#### Responsibilities
- Message processing and business logic execution
- Audit trail logging (optional)
- Error handling with DLQ integration
- Custom metrics and monitoring
- Idempotency handling

#### Processing Patterns
```python
# Idempotent message processing
def process_message(record, context):
    message_id = record['Sns']['MessageId']
    
    # Check for duplicate processing
    if is_already_processed(message_id):
        return
    
    # Business logic
    result = execute_business_logic(record)
    
    # Mark as processed
    mark_as_processed(message_id, result)
```

### Dead Letter Queue (SQS)

#### Purpose
- Capture messages that fail processing after all retry attempts
- Enable investigation and manual reprocessing
- Maintain system reliability

#### Configuration
- **Message Retention**: 14 days
- **Visibility Timeout**: 30 seconds
- **Max Receive Count**: 3 attempts
- **Encryption**: KMS encryption

## Data Flow

### Message Publishing Flow

```
1. External System/API Gateway
   ↓ (HTTP Request)
2. Publisher Lambda Function
   ├── Input Validation
   ├── Message Enrichment
   ├── Correlation ID Generation
   └── SNS Publishing
   ↓ (SNS Message)
3. Amazon SNS Topic
   ├── Message Persistence
   ├── Fan-out to Subscribers
   └── Delivery Retry Logic
   ↓ (Async Invocation)
4. Subscriber Lambda Function(s)
   ├── Message Processing
   ├── Business Logic Execution
   ├── Audit Trail (Optional)
   └── Success/Failure Response
```

### Error Handling Flow

```
Message Processing Error
   ↓
Lambda Automatic Retry
   ├── Success → Normal Flow
   └── Failure (3 attempts)
       ↓
Dead Letter Queue
   ├── Message Stored for Investigation
   ├── CloudWatch Alert Triggered
   └── Manual Investigation Required
```

### Monitoring Data Flow

```
Lambda Functions
   ├── Built-in AWS Metrics (Duration, Errors, Invocations)
   ├── Custom Business Metrics
   └── Structured Logs with Correlation IDs
   ↓
CloudWatch
   ├── Metrics Aggregation
   ├── Dashboard Visualization
   ├── Alarm Evaluation
   └── Log Analysis
   ↓
Notifications (SNS)
   ├── Email Alerts
   ├── Slack Integration
   └── PagerDuty Escalation
```

## Security Model

### Identity and Access Management (IAM)

#### Publisher Function Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:region:account:pubsub-topic"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:region:account:log-group:/aws/lambda/pubsub-publisher*"
    }
  ]
}
```

#### Subscriber Function Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource": "arn:aws:dynamodb:region:account:table/pubsub-audit*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "arn:aws:sqs:region:account:pubsub-dlq"
    }
  ]
}
```

### Network Security

#### VPC Configuration (Optional)
- Private subnets for Lambda functions
- NAT Gateway for internet access
- VPC endpoints for AWS services
- Security groups with minimal required access

#### Encryption
- **In Transit**: HTTPS/TLS for all communications
- **At Rest**: KMS encryption for SNS, SQS, and DynamoDB
- **Logs**: CloudWatch Logs encryption

### Data Protection

#### Message Sanitization
```python
def sanitize_input(message):
    # Remove sensitive data
    # Validate input format
    # Apply size limits
    return clean_message
```

#### Audit Trail
- All message processing events logged
- Correlation IDs for end-to-end tracing
- Retention policies aligned with compliance requirements

## Scalability and Performance

### Horizontal Scalability

#### Lambda Concurrency
- **Publisher**: Handles burst traffic with automatic scaling
- **Subscriber**: Processes messages in parallel across multiple instances
- **Limits**: Account-level and function-level concurrency limits

#### SNS Throughput
- **Standard Topics**: Unlimited throughput
- **Message Size**: Up to 256KB per message
- **Subscriptions**: Up to 12.5M per topic

### Performance Characteristics

#### Latency Targets
- **Publisher Processing**: < 200ms (P95)
- **SNS Delivery**: < 100ms (P95)
- **Subscriber Processing**: < 500ms (P95)
- **End-to-End**: < 1000ms (P95)

#### Throughput Targets
- **Single Publisher**: 1000+ messages/second
- **Multiple Subscribers**: 10,000+ messages/second
- **Burst Capacity**: 100,000+ messages/second (with proper concurrency)

### Performance Optimizations

#### Cold Start Mitigation
```python
# Initialize clients outside handler
import boto3
sns_client = boto3.client('sns')
cloudwatch = boto3.client('cloudwatch')

def lambda_handler(event, context):
    # Handler uses pre-initialized clients
    pass
```

#### Connection Pooling
```python
import boto3
from botocore.config import Config

# Configure connection pooling
config = Config(
    max_pool_connections=50,
    retries={'max_attempts': 3}
)
sns_client = boto3.client('sns', config=config)
```

#### Batch Processing
```python
def process_sns_records(event, context):
    # Process multiple records efficiently
    for record in event['Records']:
        process_single_record(record)
```

## Monitoring and Observability

### Three Pillars of Observability

#### 1. Metrics
- **AWS Lambda Metrics**: Duration, errors, invocations, throttles
- **SNS Metrics**: Messages published, delivered, failed
- **Custom Business Metrics**: Success rates, processing times
- **Infrastructure Metrics**: CPU, memory, network utilization

#### 2. Logs
- **Structured Logging**: JSON format with consistent fields
- **Correlation IDs**: End-to-end message tracing
- **Log Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Centralized Collection**: CloudWatch Logs with retention policies

#### 3. Traces
- **AWS X-Ray Integration**: Distributed tracing across services
- **Custom Segments**: Business logic performance analysis
- **Service Map**: Visual representation of request flow

### Alerting Strategy

#### Alert Severity Levels
1. **Critical**: Immediate response required (P1)
   - DLQ messages > 0
   - Complete service failure
   - Security incidents

2. **High**: Response within 15 minutes (P2)
   - Error rate > 5%
   - Significant latency increase
   - Partial service degradation

3. **Medium**: Response within 1 hour (P3)
   - Error rate > 1%
   - Performance degradation
   - Capacity warnings

4. **Low**: Response within 4 hours (P4)
   - Information alerts
   - Trend notifications
   - Maintenance reminders

### Monitoring Runbook

#### Daily Health Checks
1. Review dashboard for anomalies
2. Check alarm status
3. Verify DLQ is empty
4. Review error logs

#### Weekly Performance Review
1. Analyze performance trends
2. Review capacity utilization
3. Update alert thresholds if needed
4. Performance optimization planning

## Disaster Recovery

### Backup and Recovery

#### Data Backup
- **SNS Topics**: Configuration backed up via Terraform state
- **Lambda Functions**: Code stored in version control
- **DynamoDB**: Point-in-time recovery enabled
- **CloudWatch Logs**: Exported to S3 for long-term retention

#### Recovery Procedures
1. **Infrastructure Recovery**: Redeploy via Terraform
2. **Data Recovery**: Restore from backups
3. **Configuration Recovery**: Apply from version control

### Business Continuity

#### Multi-Region Deployment
```hcl
# Primary region deployment
module "pubsub_primary" {
  source = "./modules/pubsub"
  region = "us-east-1"
}

# Secondary region deployment
module "pubsub_secondary" {
  source = "./modules/pubsub"
  region = "us-west-2"
}
```

#### Failover Strategies
1. **DNS Failover**: Route traffic to healthy region
2. **Message Replay**: Reprocess messages from backup
3. **State Synchronization**: Ensure data consistency

### Recovery Time Objectives (RTO)

| Component | RTO Target | Recovery Method |
|-----------|------------|-----------------|
| Lambda Functions | < 15 minutes | Terraform redeploy |
| SNS Topics | < 5 minutes | Terraform redeploy |
| DynamoDB Tables | < 30 minutes | Point-in-time recovery |
| CloudWatch Dashboards | < 10 minutes | Terraform redeploy |
| Complete System | < 1 hour | Full infrastructure redeploy |

## Design Decisions

### Technology Choices

#### Why AWS Lambda?
- **Serverless**: No infrastructure management
- **Auto-scaling**: Handles variable workloads
- **Cost-effective**: Pay per execution
- **Integration**: Native AWS service integration

#### Why Amazon SNS?
- **Fan-out**: One-to-many message distribution
- **Reliability**: Built-in retry and DLQ support
- **Scalability**: Handles high-throughput workloads
- **Managed Service**: No operational overhead

#### Why Python 3.9?
- **Ecosystem**: Rich library ecosystem
- **Performance**: Good balance of performance and development speed
- **AWS Support**: Excellent AWS SDK support
- **Team Expertise**: Existing team knowledge

### Architectural Patterns

#### Event-Driven Architecture
- **Loose Coupling**: Components communicate via events
- **Scalability**: Independent scaling of components
- **Resilience**: Failure isolation between components

#### Microservices Pattern
- **Single Responsibility**: Each function has one purpose
- **Independent Deployment**: Components deployed separately
- **Technology Diversity**: Different components can use different technologies

#### Circuit Breaker Pattern
```python
class CircuitBreaker:
    def __init__(self, failure_threshold, recovery_timeout):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.state = 'CLOSED'
        self.last_failure_time = None
```

### Operational Considerations

#### Deployment Strategy
- **Blue-Green Deployment**: Zero-downtime deployments
- **Canary Releases**: Gradual rollout with monitoring
- **Rollback Capability**: Quick revert to previous version

#### Configuration Management
- **Infrastructure as Code**: All resources defined in Terraform
- **Environment Separation**: Dev, staging, production isolation
- **Secret Management**: AWS Secrets Manager integration

#### Cost Optimization
- **ARM64 Architecture**: Better price/performance ratio
- **Right-sizing**: Appropriate memory allocation
- **Reserved Concurrency**: Control costs and performance
- **Log Retention**: Optimized retention policies

## Future Enhancements

### Planned Improvements
1. **Enhanced Monitoring**: Custom dashboards and alerts
2. **Performance Optimization**: Advanced caching strategies
3. **Security Enhancements**: Additional encryption options
4. **Multi-Region Support**: Cross-region replication
5. **Advanced Analytics**: Message pattern analysis

### Scalability Roadmap
1. **Phase 1**: Optimize current architecture
2. **Phase 2**: Implement advanced monitoring
3. **Phase 3**: Add multi-region support
4. **Phase 4**: Implement advanced analytics

This architecture provides a robust, scalable, and maintainable foundation for pub/sub messaging patterns in AWS, with comprehensive monitoring, security, and operational considerations built-in.