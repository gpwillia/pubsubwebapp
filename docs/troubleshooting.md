# Troubleshooting Guide

This guide covers common issues and solutions for the AWS Lambda Pub/Sub solution.

## Table of Contents

1. [Deployment Issues](#deployment-issues)
2. [Lambda Function Issues](#lambda-function-issues)
3. [SNS Topic Issues](#sns-topic-issues)
4. [Performance Issues](#performance-issues)
5. [Monitoring Issues](#monitoring-issues)
6. [Testing Issues](#testing-issues)
7. [Network and Security Issues](#network-and-security-issues)
8. [Cost Optimization Issues](#cost-optimization-issues)

## Deployment Issues

### Terraform Apply Fails

#### Issue: Insufficient IAM Permissions
```
Error: error creating Lambda function: AccessDenied: User: arn:aws:iam::123456789012:user/username is not authorized to perform: lambda:CreateFunction
```

**Solution:**
1. Verify AWS credentials: `aws sts get-caller-identity`
2. Ensure the user/role has necessary permissions:
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
           "logs:*"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

#### Issue: Resource Already Exists
```
Error: error creating SNS topic: InvalidParameter: Topic already exists
```

**Solution:**
1. Import existing resource:
   ```bash
   terraform import aws_sns_topic.main arn:aws:sns:region:account:topic-name
   ```
2. Or destroy and recreate:
   ```bash
   terraform destroy -target=aws_sns_topic.main
   terraform apply
   ```

### Build Script Fails

#### Issue: Python Dependencies Not Found
```powershell
.\scripts\build.ps1
# Error: pip: command not found
```

**Solution:**
1. Verify Python installation: `python --version`
2. Install pip: `python -m ensurepip --upgrade`
3. Use virtual environment:
   ```powershell
   python -m venv venv
   .\venv\Scripts\Activate.ps1
   .\scripts\build.ps1
   ```

#### Issue: Zip File Too Large
```
Error: Request entity too large (RequestEntityTooLargeException)
```

**Solution:**
1. Check package size: `ls -la dist/`
2. Remove unnecessary dependencies from `requirements.txt`
3. Use Lambda layers for large dependencies:
   ```hcl
   resource "aws_lambda_layer_version" "dependencies" {
     filename         = "dependencies.zip"
     layer_name       = "pubsub-dependencies"
     source_code_hash = filebase64sha256("dependencies.zip")
     
     compatible_runtimes = ["python3.9"]
   }
   ```

## Lambda Function Issues

### Function Timeout Errors

#### Issue: Function Times Out
```
Task timed out after 30.00 seconds
```

**Diagnosis:**
1. Check CloudWatch logs for the function
2. Review function duration metrics
3. Analyze code performance bottlenecks

**Solutions:**
1. Increase timeout in `terraform/variables.tf`:
   ```hcl
   variable "lambda_timeout" {
     default = 60  # Increase from 30
   }
   ```
2. Optimize code performance:
   - Use connection pooling for AWS clients
   - Implement caching where appropriate
   - Reduce external API calls
3. Monitor memory usage and increase if needed

### Permission Denied Errors

#### Issue: Cannot Publish to SNS
```
ClientError: An error occurred (AccessDenied) when calling the Publish operation
```

**Solution:**
1. Check IAM role permissions:
   ```bash
   aws iam get-role-policy --role-name pubsub-publisher-role --policy-name SNSPublishPolicy
   ```
2. Verify SNS topic ARN in environment variables
3. Check resource-based policies on SNS topic

### Memory Issues

#### Issue: Out of Memory Error
```
Runtime exited with error: signal: killed Runtime.ExitError
```

**Solution:**
1. Increase memory allocation:
   ```hcl
   resource "aws_lambda_function" "publisher" {
     memory_size = 512  # Increase from 128
   }
   ```
2. Profile memory usage:
   ```python
   import psutil
   print(f"Memory usage: {psutil.virtual_memory().percent}%")
   ```

## SNS Topic Issues

### Message Delivery Failures

#### Issue: Messages Not Reaching Subscriber
```
NumberOfNotificationsFailed > 0 in CloudWatch
```

**Diagnosis:**
1. Check SNS topic subscriptions:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn arn:aws:sns:region:account:topic
   ```
2. Verify subscriber function status
3. Check DLQ for failed messages

**Solutions:**
1. Verify subscription configuration in Terraform
2. Check subscriber function permissions
3. Review subscriber function logs for errors
4. Test subscriber function independently

### Subscription Issues

#### Issue: Subscription Pending Confirmation
```
SubscriptionArn: PendingConfirmation
```

**Solution:**
Lambda subscriptions should auto-confirm. If not:
1. Check Lambda function permissions
2. Manually confirm if needed:
   ```bash
   aws sns confirm-subscription \
     --topic-arn arn:aws:sns:region:account:topic \
     --token confirmation-token
   ```

## Performance Issues

### High Latency

#### Issue: End-to-End Latency > 5 seconds

**Diagnosis:**
1. Run benchmark tests:
   ```bash
   python tests/benchmarks/benchmark.py --latency
   ```
2. Check CloudWatch metrics for each component
3. Analyze correlation IDs in logs

**Solutions:**
1. **Lambda Cold Starts:**
   - Use provisioned concurrency
   - Implement connection warming
   - Optimize function initialization

2. **Network Issues:**
   - Check VPC configuration
   - Verify security group rules
   - Use VPC endpoints for AWS services

3. **Code Optimization:**
   ```python
   # Initialize clients outside handler
   import boto3
   sns_client = boto3.client('sns')
   
   def lambda_handler(event, context):
       # Handler logic here
       pass
   ```

### Low Throughput

#### Issue: < 10 Messages/Second Processing

**Diagnosis:**
1. Run throughput benchmark:
   ```bash
   python tests/benchmarks/benchmark.py --throughput
   ```
2. Check concurrent executions
3. Review throttling metrics

**Solutions:**
1. **Increase Concurrency:**
   ```hcl
   resource "aws_lambda_function" "subscriber" {
     reserved_concurrent_executions = 100
   }
   ```
2. **Batch Processing:**
   ```python
   # Process multiple messages together
   def process_batch(messages):
       for message in messages:
           process_message(message)
   ```

## Monitoring Issues

### Dashboard Not Loading

#### Issue: CloudWatch Dashboard Shows No Data

**Solutions:**
1. Check IAM permissions for CloudWatch
2. Verify metric names and dimensions
3. Ensure functions are generating metrics:
   ```python
   import boto3
   cloudwatch = boto3.client('cloudwatch')
   
   cloudwatch.put_metric_data(
       Namespace='PubSubSolution',
       MetricData=[{
           'MetricName': 'MessageCount',
           'Value': 1,
           'Unit': 'Count'
       }]
   )
   ```

### Alarms Not Triggering

#### Issue: Expected Alarms Don't Fire

**Diagnosis:**
1. Check alarm state: `aws cloudwatch describe-alarms`
2. Verify alarm thresholds and periods
3. Check metric data availability

**Solutions:**
1. Adjust alarm thresholds
2. Reduce evaluation periods for faster detection
3. Verify alarm actions are configured

## Testing Issues

### Unit Tests Failing

#### Issue: Import Errors in Tests
```python
ImportError: No module named 'src.publisher.lambda_function'
```

**Solution:**
1. Set PYTHONPATH:
   ```bash
   export PYTHONPATH="${PYTHONPATH}:$(pwd)"
   python -m pytest tests/unit/
   ```
2. Use relative imports in tests:
   ```python
   from src.publisher.lambda_function import lambda_handler
   ```

### Integration Tests Failing

#### Issue: AWS Resource Not Found
```
ClientError: The specified queue does not exist
```

**Solution:**
1. Ensure infrastructure is deployed:
   ```bash
   terraform output
   ```
2. Set correct environment variables:
   ```bash
   export TEST_SNS_TOPIC_ARN=$(terraform output sns_topic_arn)
   ```

### Benchmark Tests Slow

#### Issue: Benchmark Takes Too Long

**Solutions:**
1. Reduce test iterations:
   ```bash
   python tests/benchmarks/benchmark.py --latency --iterations 20
   ```
2. Skip cold start tests during development
3. Use smaller message sizes for quick validation

## Network and Security Issues

### VPC Configuration Issues

#### Issue: Lambda Functions Can't Access Internet
```
[ERROR] ConnectTimeoutError: Connect timeout
```

**Solution:**
1. **NAT Gateway Setup:**
   ```hcl
   resource "aws_nat_gateway" "main" {
     allocation_id = aws_eip.nat.id
     subnet_id     = aws_subnet.public.id
   }
   ```

2. **Route Table Configuration:**
   ```hcl
   resource "aws_route" "private_nat" {
     route_table_id         = aws_route_table.private.id
     destination_cidr_block = "0.0.0.0/0"
     nat_gateway_id         = aws_nat_gateway.main.id
   }
   ```

### Security Group Issues

#### Issue: Lambda Can't Access SNS
```
[ERROR] ConnectTimeoutError: HTTPSConnectionPool
```

**Solution:**
1. Allow HTTPS outbound traffic:
   ```hcl
   resource "aws_security_group_rule" "lambda_egress" {
     type              = "egress"
     from_port         = 443
     to_port           = 443
     protocol          = "tcp"
     cidr_blocks       = ["0.0.0.0/0"]
     security_group_id = aws_security_group.lambda.id
   }
   ```

## Cost Optimization Issues

### High CloudWatch Costs

#### Issue: Unexpected CloudWatch Charges

**Diagnosis:**
1. Check log retention settings
2. Review custom metric usage
3. Analyze dashboard query frequency

**Solutions:**
1. **Optimize Log Retention:**
   ```hcl
   resource "aws_cloudwatch_log_group" "lambda" {
     retention_in_days = 7  # Reduce for dev environment
   }
   ```

2. **Reduce Metric Resolution:**
   ```python
   # Use standard resolution instead of high resolution
   cloudwatch.put_metric_data(
       Namespace='PubSubSolution',
       MetricData=[{
           'MetricName': 'MessageCount',
           'Value': 1,
           'Unit': 'Count',
           'Timestamp': datetime.utcnow()  # Standard resolution
       }]
   )
   ```

### High Lambda Costs

#### Issue: Lambda Costs Higher Than Expected

**Solutions:**
1. **Use ARM64 Architecture:**
   ```hcl
   resource "aws_lambda_function" "publisher" {
     architectures = ["arm64"]
   }
   ```

2. **Optimize Memory Allocation:**
   - Monitor actual memory usage
   - Right-size memory settings
   - Use provisioned concurrency only when needed

3. **Implement Caching:**
   ```python
   import functools
   
   @functools.lru_cache(maxsize=128)
   def get_configuration():
       # Expensive operation
       return config
   ```

## Diagnostic Commands

### General Health Check
```bash
# Check AWS connectivity
aws sts get-caller-identity

# List Lambda functions
aws lambda list-functions --query 'Functions[?contains(FunctionName, `pubsub`)].FunctionName'

# Check SNS topics
aws sns list-topics

# Get recent logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/pubsub"
```

### Performance Diagnostics
```bash
# Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Duration \
  --dimensions Name=FunctionName,Value=pubsub-publisher \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average,Maximum

# SNS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/SNS \
  --metric-name NumberOfMessagesPublished \
  --dimensions Name=TopicName,Value=pubsub-topic \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Sum
```

### Error Investigation
```bash
# Recent error logs
aws logs filter-log-events \
  --log-group-name "/aws/lambda/pubsub-publisher" \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "ERROR"

# DLQ messages
aws sqs receive-message --queue-url https://sqs.region.amazonaws.com/account/pubsub-dlq
```

## Getting Help

### Community Resources
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Support Channels
1. **AWS Support**: For AWS service-specific issues
2. **GitHub Issues**: For project-specific problems
3. **Stack Overflow**: For general development questions

### Emergency Escalation
For production issues:
1. Check monitoring dashboard first
2. Review recent deployment changes
3. Check AWS Service Health Dashboard
4. Engage on-call engineer if critical

Remember to always test changes in a non-production environment first!