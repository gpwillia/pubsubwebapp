# Monitoring and Observability

This directory contains monitoring and observability configurations for the AWS Lambda Pub/Sub solution.

## Overview

The monitoring solution provides comprehensive visibility into:

- **Lambda Function Performance**: Duration, errors, throttles, concurrent executions
- **SNS Topic Metrics**: Message publishing rates, delivery success/failure
- **Business Metrics**: Custom metrics for message processing success/failure rates
- **Infrastructure Health**: DLQ message accumulation, system errors
- **End-to-End Tracing**: Correlation IDs for message flow tracking

## Components

### 1. CloudWatch Dashboards

Located in `dashboards/`:
- **pubsub-dashboard.json**: Main operational dashboard with key metrics
- Real-time visualization of system health and performance
- Log query widgets for error analysis

### 2. CloudWatch Alarms

Located in `alarms/`:
- Comprehensive alarm definitions for all critical metrics
- Multi-level severity classification (Critical, High, Medium, Low)
- Automated notification and escalation

### 3. Custom Metrics

Business-specific metrics published by Lambda functions:
- `PubSubSolution/MessageProcessingLatency`: End-to-end processing time
- `PubSubSolution/MessageProcessingSuccess`: Successful message count
- `PubSubSolution/MessageProcessingFailure`: Failed message count

## Deployment

Monitoring resources are automatically deployed when `enable_monitoring = true` in Terraform configuration:

```hcl
# terraform/terraform.tfvars
enable_monitoring = true
```

## Dashboard Access

After deployment, access the CloudWatch dashboard:

1. Go to AWS CloudWatch Console
2. Navigate to Dashboards
3. Open "PubSub-{environment}" dashboard

## Key Metrics to Monitor

### Operational Health
- **Lambda Error Rate**: Should be < 1%
- **SNS Delivery Success**: Should be > 99%
- **DLQ Message Count**: Should remain at 0
- **Function Duration**: Monitor for performance degradation

### Performance Metrics
- **Average Latency**: End-to-end message processing time
- **Throughput**: Messages processed per second
- **Concurrent Executions**: Lambda concurrency utilization

### Business Metrics
- **Message Processing Success Rate**: Business logic success percentage
- **Peak Load Handling**: Performance during high-traffic periods
- **Error Patterns**: Analysis of failure modes

## Alerting Strategy

### Critical Alerts (Immediate Response)
- Messages appearing in DLQ
- Function errors > 5% over 5 minutes
- Complete SNS delivery failures

### High Priority Alerts (15-minute Response)
- Error rate > 1% over 10 minutes
- Average latency > 5 seconds
- Function throttling detected

### Medium Priority Alerts (1-hour Response)
- Duration exceeding 80% of timeout
- Unusual traffic patterns
- Performance degradation trends

## Troubleshooting Workflow

### 1. Initial Assessment
```bash
# Check overall system health
aws cloudwatch get-dashboard --dashboard-name "PubSub-production"

# Review recent alarms
aws logs describe-metric-filters --log-group-name "/aws/lambda/pubsub-publisher"
```

### 2. Error Investigation
```bash
# Query recent errors
aws logs filter-log-events \
  --log-group-name "/aws/lambda/pubsub-publisher" \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"
```

### 3. Performance Analysis
```bash
# Get Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=pubsub-publisher \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average,Maximum
```

## Custom Metrics Implementation

Lambda functions publish custom metrics using:

```python
import boto3
cloudwatch = boto3.client('cloudwatch')

# Publish custom metric
cloudwatch.put_metric_data(
    Namespace='PubSubSolution',
    MetricData=[
        {
            'MetricName': 'MessageProcessingLatency',
            'Value': processing_time_ms,
            'Unit': 'Milliseconds',
            'Dimensions': [
                {
                    'Name': 'Environment',
                    'Value': environment
                }
            ]
        }
    ]
)
```

## Log Analysis

### Structured Logging Format
```json
{
  "timestamp": "2024-12-01T14:30:22.123Z",
  "level": "INFO",
  "message": "Message published successfully",
  "correlationId": "abc123-def456-ghi789",
  "messageId": "sns-message-id",
  "duration": 245.67,
  "environment": "production"
}
```

### Log Queries

#### Find Messages by Correlation ID
```
fields @timestamp, @message
| filter correlationId = "abc123-def456-ghi789"
| sort @timestamp asc
```

#### Error Rate Analysis
```
fields @timestamp
| filter level = "ERROR"
| stats count() by bin(5m)
```

#### Performance Analysis
```
fields @timestamp, duration
| filter duration > 1000
| stats avg(duration), max(duration), count() by bin(10m)
```

## Cost Optimization

### Log Retention
- Development: 7 days
- Staging: 30 days
- Production: 90 days (configurable)

### Metrics Resolution
- Standard resolution (1-minute) for most metrics
- High resolution (1-second) only for critical performance metrics

### Dashboard Optimization
- Shared dashboards across environments
- Efficient query patterns to minimize CloudWatch API costs

## Integration with External Systems

### Grafana Integration
```bash
# Configure Grafana CloudWatch data source
# Use IAM role for authentication
{
  "datasource": "CloudWatch",
  "region": "us-east-1",
  "access": "proxy",
  "assumeRoleArn": "arn:aws:iam::account:role/grafana-cloudwatch-role"
}
```

### Prometheus Metrics Export
Custom Lambda layer for Prometheus metrics exposition:
```python
from prometheus_client import Counter, Histogram, push_to_gateway

message_counter = Counter('pubsub_messages_total', 'Total messages processed')
processing_time = Histogram('pubsub_processing_seconds', 'Message processing time')
```

## Compliance and Audit

### Log Retention Policy
- All logs retained according to compliance requirements
- Automated log archival to S3 for long-term storage
- Encrypted logs for sensitive data protection

### Audit Trail
- All administrative actions logged
- Change tracking for dashboard and alarm configurations
- Access logging for monitoring resources

## Best Practices

1. **Correlation IDs**: Always include correlation IDs for end-to-end tracing
2. **Structured Logging**: Use consistent JSON format for all log entries
3. **Metric Naming**: Follow AWS CloudWatch naming conventions
4. **Alarm Hygiene**: Regular review and tuning of alarm thresholds
5. **Dashboard Organization**: Group related metrics logically
6. **Cost Awareness**: Monitor CloudWatch costs and optimize queries

## Emergency Procedures

### Dashboard Not Loading
1. Check AWS service health status
2. Verify IAM permissions for CloudWatch access
3. Check for API rate limiting

### Missing Metrics
1. Verify Lambda function execution
2. Check CloudWatch agent configuration
3. Review IAM permissions for metric publishing

### False Positive Alarms
1. Review alarm threshold settings
2. Check for temporary system issues
3. Adjust alarm period or evaluation criteria

For detailed troubleshooting, see the main project documentation.