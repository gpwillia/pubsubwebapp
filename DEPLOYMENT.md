# Multi-Environment Deployment Guide

This guide explains how to deploy the AWS Lambda Pub/Sub solution across different environments (dev, stage, prod).

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** at `C:\terraform\terraform.exe`
3. **PowerShell 5.1 or later**
4. **Appropriate AWS permissions** for each environment

## Environment Configurations

### Development (dev)
- **Purpose**: Development and testing
- **Monitoring**: Basic monitoring
- **Resources**: Minimal configuration
- **Lambda Memory**: Publisher (256MB), Subscriber (512MB)
- **Logs**: 14-day retention

### Stage (stage)
- **Purpose**: Pre-production testing and validation
- **Monitoring**: Enhanced monitoring enabled
- **Resources**: Production-like configuration
- **Lambda Memory**: Publisher (256MB), Subscriber (512MB)
- **Logs**: 14-day retention
- **Features**: Audit trail enabled, detailed monitoring

### Production (prod)
- **Purpose**: Live production workloads
- **Monitoring**: Full monitoring and alerting
- **Resources**: Optimized for performance and reliability
- **Lambda Memory**: Publisher (512MB), Subscriber (1024MB)
- **Logs**: 30-day retention
- **Features**: API Gateway enabled, enhanced security, backup enabled

## Deployment Commands

### Quick Deployment

```powershell
# Deploy to development
.\deploy.ps1 -Environment dev -Action apply -AutoApprove

# Deploy to stage
.\deploy.ps1 -Environment stage -Action apply

# Deploy to production (requires confirmation)
.\deploy.ps1 -Environment prod -Action apply
```

### Step-by-Step Deployment

1. **Plan the deployment** (recommended first step):
```powershell
.\deploy.ps1 -Environment stage -Action plan
```

2. **Apply the deployment**:
```powershell
.\deploy.ps1 -Environment stage -Action apply
```

3. **Destroy resources** (if needed):
```powershell
.\deploy.ps1 -Environment stage -Action destroy
```

### Manual Terraform Commands

If you prefer using Terraform directly:

```powershell
# Navigate to terraform directory
cd C:\AMEX\aws-lambda-pubsub-sns\terraform

# Initialize Terraform
C:\terraform\terraform.exe init

# Select/create workspace
C:\terraform\terraform.exe workspace select stage
# or
C:\terraform\terraform.exe workspace new stage

# Plan deployment
C:\terraform\terraform.exe plan -var-file="terraform.tfvars.stage"

# Apply deployment
C:\terraform\terraform.exe apply -var-file="terraform.tfvars.stage"
```

## Environment-Specific Considerations

### Development Environment
- **Use case**: Feature development, unit testing, experimentation
- **Cost optimization**: ARM64 architecture, minimal monitoring
- **Access**: Developer-friendly, relaxed security

### Stage Environment  
- **Use case**: Integration testing, performance testing, UAT
- **Features**: Production-like setup with enhanced monitoring
- **Testing**: End-to-end testing, load testing, monitoring validation
- **Data**: Use synthetic or anonymized data

### Production Environment
- **Use case**: Live customer traffic
- **Security**: Enhanced security, encryption, VPC (optional)
- **Performance**: Higher memory allocation, concurrency limits
- **Monitoring**: Full observability, alerting, backup enabled
- **Deployment**: Requires confirmation, change management process

## Testing Deployments

### 1. Test Publisher Lambda

Create test payload file:
```json
{
  "message": "Hello from [environment]!",
  "messageAttributes": {
    "Environment": "[environment]"
  }
}
```

Invoke publisher:
```powershell
aws lambda invoke --function-name aws-lambda-pubsub-sns-[env]-publisher --cli-binary-format raw-in-base64-out --payload file://test-payload.json --region us-east-1 response.json
```

### 2. Check Subscriber Logs

```powershell
aws logs tail /aws/lambda/aws-lambda-pubsub-sns-[env]-subscriber --since 5m --region us-east-1
```

### 3. Monitor CloudWatch Metrics

- Lambda function metrics (duration, errors, invocations)
- SNS topic metrics (messages published, failed)
- SQS DLQ metrics (messages received)

## Workspace Management

Each environment uses a separate Terraform workspace:
- **dev**: Default workspace
- **stage**: stage workspace  
- **prod**: prod workspace

List workspaces:
```powershell
C:\terraform\terraform.exe workspace list
```

Switch workspace:
```powershell
C:\terraform\terraform.exe workspace select [environment]
```

## Troubleshooting

### Common Issues

1. **Lambda package not found**
   - Run `.\build-lambda-packages.ps1` to create packages
   - Check `lambda-packages/` directory

2. **AWS permissions error**
   - Verify AWS CLI configuration: `aws sts get-caller-identity`
   - Check IAM permissions for Terraform operations

3. **Workspace conflicts**
   - Delete workspace: `terraform workspace delete [name]`
   - Select correct workspace before deployment

4. **Environment variable conflicts**
   - Verify configuration files exist
   - Check environment-specific settings

### Validation Commands

```powershell
# Validate Terraform configuration
C:\terraform\terraform.exe validate

# Check current workspace
C:\terraform\terraform.exe workspace show

# Show current state
C:\terraform\terraform.exe show

# List resources in current workspace
C:\terraform\terraform.exe state list
```

## Best Practices

### 1. Deployment Process
- Always run `plan` before `apply`
- Test in dev → stage → prod sequence
- Use workspaces to isolate environments
- Review Terraform outputs after deployment

### 2. Configuration Management
- Keep environment-specific settings in `.tfvars` files
- Use consistent naming conventions across environments
- Tag resources appropriately for cost tracking

### 3. Security
- Use least-privilege IAM policies
- Enable encryption for production
- Consider VPC deployment for sensitive workloads
- Rotate credentials regularly

### 4. Monitoring
- Set up CloudWatch alarms for production
- Monitor Lambda performance metrics
- Track cost metrics across environments
- Set up log aggregation for troubleshooting

### 5. Backup and Recovery
- Enable audit trail for compliance
- Regular state backups
- Document recovery procedures
- Test disaster recovery scenarios

## Environment Outputs

After successful deployment, Terraform provides outputs for:
- Lambda function ARNs
- SNS topic ARN
- DLQ URL
- CloudWatch log group names
- Test endpoints

Use these outputs to configure monitoring, testing, and integration with other systems.

## Support

For issues or questions:
1. Check CloudWatch logs for Lambda function errors
2. Review Terraform state for configuration drift  
3. Validate AWS resource permissions
4. Consult this documentation for common solutions