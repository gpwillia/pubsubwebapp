# Benchmark Testing

This directory contains comprehensive benchmark testing tools for the AWS Lambda Pub/Sub solution.

## Overview

The benchmark suite measures various performance aspects of the Pub/Sub system:

- **Latency Testing**: End-to-end message latency measurements
- **Throughput Testing**: Concurrent load testing with multiple publishers
- **Cold Start Analysis**: Lambda cold start performance measurement
- **Message Size Impact**: Performance variation with different message sizes
- **CloudWatch Integration**: Real-time metrics collection and analysis

## Prerequisites

1. **Deployed Infrastructure**: Ensure the Terraform infrastructure is deployed
2. **Environment Variables**: Set the required environment variables
3. **AWS Credentials**: Configure AWS CLI or use IAM roles
4. **Python Dependencies**: Install benchmark-specific requirements

## Environment Variables

```bash
# Required
export TEST_AWS_REGION="us-east-1"
export TEST_SNS_TOPIC_ARN="arn:aws:sns:us-east-1:123456789012:pubsub-topic"
export TEST_PUBLISHER_FUNCTION_NAME="pubsub-publisher"
export TEST_SUBSCRIBER_FUNCTION_NAME="pubsub-subscriber"

# Optional
export TEST_DLQ_URL="https://sqs.us-east-1.amazonaws.com/123456789012/pubsub-dlq"
export TEST_AUDIT_TABLE_NAME="pubsub-audit-trail"
```

## Installation

```bash
# Install benchmark dependencies
pip install -r tests/benchmarks/requirements.txt

# Or use the main project requirements
pip install -r requirements.txt
```

## Running Benchmarks

### Quick Start

```bash
# Run all benchmark tests
python tests/benchmarks/benchmark.py --all

# Run specific tests
python tests/benchmarks/benchmark.py --latency
python tests/benchmarks/benchmark.py --throughput
python tests/benchmarks/benchmark.py --message-sizes

# Run with custom output directory
python tests/benchmarks/benchmark.py --all --output-dir ./my-results
```

### PowerShell Automation

```powershell
# Run benchmarks using the test script
.\scripts\test.ps1 -BenchmarkOnly

# Or run specific benchmark types
.\scripts\test.ps1 -BenchmarkType "latency,throughput"
```

### Individual Benchmark Types

#### 1. Latency Benchmark

Measures end-to-end message processing latency:

```bash
python tests/benchmarks/benchmark.py --latency
```

**Metrics Collected:**
- Average, median, min, max latency
- 95th and 99th percentile response times
- Success rate and error count

#### 2. Throughput Benchmark

Tests system performance under concurrent load:

```bash
python tests/benchmarks/benchmark.py --throughput
```

**Configuration:**
- Default: 10 concurrent requests for 60 seconds
- Measures requests/second and response time distribution
- Tracks success/failure rates under load

#### 3. Cold Start Benchmark

Analyzes Lambda cold start performance:

```bash
python tests/benchmarks/benchmark.py --cold-start
```

**Note:** This test takes ~50 minutes (10 iterations × 5-minute waits)
- Measures initial invocation latency after idle periods
- Useful for understanding real-world performance

#### 4. Message Size Benchmark

Tests performance with varying message sizes:

```bash
python tests/benchmarks/benchmark.py --message-sizes
```

**Test Sizes:** 1KB, 10KB, 50KB, 100KB, 200KB
- Identifies performance degradation with larger payloads
- Helps optimize message structure

## Output and Reports

### Report Structure

Benchmark results are saved to the `benchmark-results/` directory:

```
benchmark-results/
├── benchmark-report-20241201-143022.txt    # Detailed text report
├── latency_distribution.png                # Latency metrics chart
├── message_size_performance.png            # Size vs performance
└── raw_results.json                        # Machine-readable data
```

### Sample Report Content

```
AWS Lambda Pub/Sub Solution - Benchmark Report
==================================================

Generated: 2024-12-01 14:30:22
Region: us-east-1
Publisher Function: pubsub-publisher
Subscriber Function: pubsub-subscriber

Single Message Latency Benchmark
--------------------------------
Total Requests: 100
Success Rate: 100.00%
Average Latency: 245.67ms
Median Latency: 198.45ms
95th Percentile: 456.23ms
99th Percentile: 678.90ms
Min Latency: 123.45ms
Max Latency: 789.01ms

Throughput Benchmark
--------------------
Total Requests: 1247
Successful Requests: 1245
Failed Requests: 2
Success Rate: 99.84%
Requests/Second: 20.75
Avg Response Time: 287.34ms
95th Percentile: 567.89ms
```

## Performance Baseline

### Expected Performance Ranges

**Latency (ARM64, 512MB memory):**
- Cold start: 1000-3000ms
- Warm execution: 100-500ms
- P95 latency: <800ms

**Throughput:**
- Single function: 20-50 req/sec
- With concurrency: 100-1000 req/sec
- Success rate: >99%

**Message Sizes:**
- 1-10KB: Minimal impact
- 50KB: 10-20% latency increase
- 100KB+: 30-50% latency increase

## Integration with CI/CD

### GitHub Actions Integration

The benchmark can be integrated into CI/CD pipelines:

```yaml
# .github/workflows/benchmark.yml
- name: Run Performance Benchmarks
  run: |
    python tests/benchmarks/benchmark.py --latency --throughput
    
- name: Upload Benchmark Results
  uses: actions/upload-artifact@v3
  with:
    name: benchmark-results
    path: benchmark-results/
```

### Performance Regression Detection

Compare results against baseline metrics:

```bash
# Set performance thresholds
export MAX_P95_LATENCY=800  # milliseconds
export MIN_SUCCESS_RATE=99  # percentage

# Run benchmarks with threshold checking
python tests/benchmarks/benchmark.py --all --check-thresholds
```

## Troubleshooting

### Common Issues

1. **Missing Environment Variables**
   ```bash
   # Verify all required variables are set
   env | grep TEST_
   ```

2. **AWS Permission Errors**
   ```bash
   # Check IAM permissions
   aws lambda list-functions
   aws sns list-topics
   ```

3. **High Latency Results**
   - Check Lambda memory configuration
   - Verify VPC configuration (if using)
   - Review CloudWatch metrics for throttling

4. **Low Throughput**
   - Increase Lambda concurrency limits
   - Check for account-level throttling
   - Monitor SNS throttling metrics

### Debugging Options

Enable verbose logging:

```bash
export AWS_CLI_FILE_ENCODING=UTF-8
export BOTO3_LOG_LEVEL=DEBUG
python tests/benchmarks/benchmark.py --latency
```

## Advanced Configuration

### Custom Benchmark Parameters

Modify `benchmark.py` for specific testing needs:

```python
# Custom latency test parameters
benchmark.benchmark_single_message_latency(num_iterations=200)

# Custom throughput test parameters
benchmark.benchmark_throughput(
    concurrent_requests=20,
    duration_seconds=120
)

# Custom message sizes
benchmark.benchmark_message_sizes(
    sizes_kb=[5, 25, 75, 150, 250]
)
```

### CloudWatch Metrics Integration

The benchmark automatically collects CloudWatch metrics:
- Lambda duration and invocation counts
- Error rates and throttling
- SNS message delivery metrics

## Best Practices

1. **Baseline Establishment**: Run benchmarks immediately after deployment to establish baseline performance
2. **Regular Testing**: Include benchmark tests in CI/CD for performance regression detection
3. **Environment Consistency**: Use consistent test environments and data for comparable results
4. **Monitoring Integration**: Correlate benchmark results with CloudWatch metrics
5. **Documentation**: Document performance requirements and acceptable thresholds

## Contributing

When adding new benchmark tests:

1. Follow the existing class structure
2. Include comprehensive error handling
3. Add appropriate logging and progress indicators
4. Update this documentation with new test descriptions
5. Include sample output in reports

For questions or issues, please refer to the main project README or create an issue in the repository.