# CloudWatch Alarms Configuration

This directory contains CloudWatch alarm definitions for the AWS Lambda Pub/Sub solution.

## Alarm Categories

### 1. Lambda Function Alarms

#### High Error Rate
- **Threshold**: Error rate > 1% over 5 minutes
- **Action**: Send SNS notification to operations team
- **Severity**: High

#### Function Timeout
- **Threshold**: Duration > 80% of configured timeout
- **Action**: Send SNS notification
- **Severity**: Medium

#### High Latency
- **Threshold**: Average duration > 5000ms over 10 minutes
- **Action**: Send SNS notification
- **Severity**: Medium

#### Throttling
- **Threshold**: Any throttles detected
- **Action**: Immediate SNS notification
- **Severity**: High

### 2. SNS Topic Alarms

#### Message Delivery Failures
- **Threshold**: Failed deliveries > 0 over 5 minutes
- **Action**: Send SNS notification
- **Severity**: High

#### Low Message Volume (Business Hours)
- **Threshold**: < 10 messages/hour during business hours
- **Action**: Send SNS notification
- **Severity**: Low

### 3. DLQ Alarms

#### Messages in DLQ
- **Threshold**: > 0 messages in DLQ
- **Action**: Immediate SNS notification
- **Severity**: Critical

### 4. Custom Business Metric Alarms

#### Message Processing Success Rate
- **Threshold**: Success rate < 99% over 15 minutes
- **Action**: Send SNS notification
- **Severity**: High

## Alarm Actions

All alarms are configured to:
1. Send notifications to the operations SNS topic
2. Create CloudWatch Events for automation
3. Log to CloudWatch Logs for audit trail

## Alarm States

- **OK**: Normal operation
- **ALARM**: Threshold breached
- **INSUFFICIENT_DATA**: Not enough data points

## Configuration

Alarms are automatically created by Terraform when `enable_monitoring = true` in the configuration.

To customize alarm thresholds, modify the variables in `terraform/variables.tf`:

```hcl
variable "alarm_error_rate_threshold" {
  description = "Error rate threshold for alarms (percentage)"
  type        = number
  default     = 1
}

variable "alarm_duration_threshold" {
  description = "Duration threshold for alarms (milliseconds)"
  type        = number
  default     = 5000
}
```

## Testing Alarms

You can test alarm functionality by:

1. **Triggering Errors**: Send malformed messages to test error rate alarms
2. **Load Testing**: Use benchmark tools to trigger latency/throttling alarms
3. **Manual DLQ**: Manually place messages in DLQ to test DLQ alarms

## Alarm Runbooks

### High Error Rate Alarm

1. Check recent Lambda logs for error patterns
2. Verify SNS topic configuration
3. Check IAM permissions
4. Review recent deployments

### Function Timeout Alarm

1. Review function memory configuration
2. Check for external dependency issues
3. Analyze code performance bottlenecks
4. Consider increasing timeout or optimizing code

### SNS Delivery Failure Alarm

1. Verify subscriber Lambda function status
2. Check Lambda permissions for SNS
3. Review SNS topic subscription configuration
4. Check for Lambda throttling

### DLQ Messages Alarm

1. Review messages in DLQ for error patterns
2. Check subscriber function logs
3. Verify business logic handling
4. Process or requeue messages after fixing issues

## Notification Configuration

Configure SNS topic for alarm notifications:

```bash
# Create SNS topic for alerts
aws sns create-topic --name pubsub-alerts

# Subscribe email to topic
aws sns subscribe \
    --topic-arn arn:aws:sns:region:account:pubsub-alerts \
    --protocol email \
    --notification-endpoint your-email@company.com
```

## Integration with PagerDuty/Slack

Alarms can be integrated with external alerting systems:

### PagerDuty Integration
```json
{
  "Type": "AWS::SNS::Subscription",
  "Properties": {
    "Protocol": "https",
    "TopicArn": "arn:aws:sns:region:account:pubsub-alerts",
    "Endpoint": "https://events.pagerduty.com/integration/your-integration-key/enqueue"
  }
}
```

### Slack Integration
Use AWS Chatbot to send CloudWatch alarms to Slack channels.

## Alarm Maintenance

### Regular Tasks

1. **Review Alarm History**: Monthly review of alarm triggers
2. **Threshold Tuning**: Adjust thresholds based on operational experience
3. **False Positive Analysis**: Identify and fix noisy alarms
4. **Coverage Review**: Ensure all critical paths are monitored

### Alarm Lifecycle

1. **Creation**: Alarms created during infrastructure deployment
2. **Validation**: Test alarms during deployment validation
3. **Monitoring**: Continuous monitoring of alarm effectiveness
4. **Tuning**: Regular adjustment based on operational data
5. **Retirement**: Remove obsolete alarms during system changes