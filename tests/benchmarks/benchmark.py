#!/usr/bin/env python3
"""
Benchmark script for AWS Lambda Pub/Sub solution.

This script performs various performance tests and generates reports.
"""

import json
import time
import boto3
import statistics
import concurrent.futures
import argparse
import os
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any
import matplotlib.pyplot as plt
import pandas as pd


class PubSubBenchmark:
    """Benchmark suite for AWS Lambda Pub/Sub solution."""
    
    def __init__(self):
        """Initialize benchmark with AWS clients and configuration."""
        self.region = os.environ.get('TEST_AWS_REGION', 'us-east-1')
        self.sns_topic_arn = os.environ.get('TEST_SNS_TOPIC_ARN')
        self.publisher_function_name = os.environ.get('TEST_PUBLISHER_FUNCTION_NAME')
        self.subscriber_function_name = os.environ.get('TEST_SUBSCRIBER_FUNCTION_NAME')
        
        # Initialize AWS clients
        self.lambda_client = boto3.client('lambda', region_name=self.region)
        self.cloudwatch = boto3.client('cloudwatch', region_name=self.region)
        
        # Benchmark results
        self.results = {}
        
        # Verify configuration
        if not all([self.sns_topic_arn, self.publisher_function_name]):
            raise ValueError("Required environment variables not set")

    def benchmark_single_message_latency(self, num_iterations=100) -> Dict[str, float]:
        """Benchmark single message end-to-end latency."""
        print(f"Running single message latency benchmark ({num_iterations} iterations)...")
        
        latencies = []
        
        for i in range(num_iterations):
            correlation_id = str(uuid.uuid4())
            test_message = {
                'message': f'Benchmark message {i} - {correlation_id}',
                'timestamp': datetime.utcnow().isoformat(),
                'benchmarkId': correlation_id
            }
            
            start_time = time.time()
            
            # Invoke publisher function
            try:
                response = self.lambda_client.invoke(
                    FunctionName=self.publisher_function_name,
                    InvocationType='RequestResponse',
                    Payload=json.dumps(test_message)
                )
                
                end_time = time.time()
                
                if response['StatusCode'] == 200:
                    latency = (end_time - start_time) * 1000  # Convert to ms
                    latencies.append(latency)
                else:
                    print(f"Failed invocation {i}: {response['StatusCode']}")
                
            except Exception as e:
                print(f"Error in iteration {i}: {e}")
            
            # Small delay to avoid overwhelming the system
            if i < num_iterations - 1:
                time.sleep(0.1)
        
        if not latencies:
            raise RuntimeError("No successful invocations recorded")
        
        results = {
            'min_latency': min(latencies),
            'max_latency': max(latencies),
            'avg_latency': statistics.mean(latencies),
            'median_latency': statistics.median(latencies),
            'p95_latency': self._percentile(latencies, 0.95),
            'p99_latency': self._percentile(latencies, 0.99),
            'total_requests': len(latencies),
            'success_rate': (len(latencies) / num_iterations) * 100
        }
        
        self.results['single_message_latency'] = results
        return results

    def benchmark_throughput(self, concurrent_requests=10, duration_seconds=60) -> Dict[str, float]:
        """Benchmark message throughput under concurrent load."""
        print(f"Running throughput benchmark ({concurrent_requests} concurrent, {duration_seconds}s)...")
        
        start_time = time.time()
        end_time = start_time + duration_seconds
        
        successful_requests = 0
        failed_requests = 0
        response_times = []
        
        def send_message(message_id: int) -> Dict[str, Any]:
            """Send a single message and measure response time."""
            correlation_id = str(uuid.uuid4())
            test_message = {
                'message': f'Throughput test {message_id} - {correlation_id}',
                'messageId': message_id,
                'benchmarkType': 'throughput'
            }
            
            request_start = time.time()
            
            try:
                response = self.lambda_client.invoke(
                    FunctionName=self.publisher_function_name,
                    InvocationType='RequestResponse',
                    Payload=json.dumps(test_message)
                )
                
                request_end = time.time()
                response_time = (request_end - request_start) * 1000
                
                return {
                    'success': response['StatusCode'] == 200,
                    'response_time': response_time,
                    'timestamp': request_end
                }
                
            except Exception as e:
                return {
                    'success': False,
                    'error': str(e),
                    'response_time': None,
                    'timestamp': time.time()
                }
        
        message_counter = 0
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
            futures = []
            
            while time.time() < end_time:
                # Submit new requests to maintain concurrency level
                while len(futures) < concurrent_requests and time.time() < end_time:
                    future = executor.submit(send_message, message_counter)
                    futures.append(future)
                    message_counter += 1
                
                # Process completed futures
                completed_futures = []
                for future in futures:
                    if future.done():
                        try:
                            result = future.result(timeout=0.1)
                            if result['success']:
                                successful_requests += 1
                                if result['response_time']:
                                    response_times.append(result['response_time'])
                            else:
                                failed_requests += 1
                        except Exception as e:
                            failed_requests += 1
                            print(f"Future exception: {e}")
                        
                        completed_futures.append(future)
                
                # Remove completed futures
                for future in completed_futures:
                    futures.remove(future)
                
                time.sleep(0.01)  # Small delay
            
            # Wait for remaining futures
            for future in futures:
                try:
                    result = future.result(timeout=5)
                    if result['success']:
                        successful_requests += 1
                        if result['response_time']:
                            response_times.append(result['response_time'])
                    else:
                        failed_requests += 1
                except Exception:
                    failed_requests += 1
        
        total_duration = time.time() - start_time
        total_requests = successful_requests + failed_requests
        
        results = {
            'total_requests': total_requests,
            'successful_requests': successful_requests,
            'failed_requests': failed_requests,
            'success_rate': (successful_requests / total_requests * 100) if total_requests > 0 else 0,
            'requests_per_second': successful_requests / total_duration,
            'avg_response_time': statistics.mean(response_times) if response_times else 0,
            'p95_response_time': self._percentile(response_times, 0.95) if response_times else 0,
            'duration_seconds': total_duration
        }
        
        self.results['throughput'] = results
        return results

    def benchmark_cold_start(self, num_iterations=10) -> Dict[str, float]:
        """Benchmark Lambda cold start performance."""
        print(f"Running cold start benchmark ({num_iterations} iterations)...")
        
        cold_start_times = []
        
        for i in range(num_iterations):
            print(f"Cold start test {i+1}/{num_iterations}")
            
            # Wait to ensure function is cold
            time.sleep(300)  # 5 minutes wait
            
            correlation_id = str(uuid.uuid4())
            test_message = {
                'message': f'Cold start test {i} - {correlation_id}',
                'benchmarkType': 'coldStart'
            }
            
            start_time = time.time()
            
            try:
                response = self.lambda_client.invoke(
                    FunctionName=self.publisher_function_name,
                    InvocationType='RequestResponse',
                    Payload=json.dumps(test_message)
                )
                
                end_time = time.time()
                
                if response['StatusCode'] == 200:
                    cold_start_time = (end_time - start_time) * 1000
                    cold_start_times.append(cold_start_time)
                    print(f"  Cold start time: {cold_start_time:.2f}ms")
                
            except Exception as e:
                print(f"Error in cold start test {i}: {e}")
        
        if not cold_start_times:
            raise RuntimeError("No successful cold start measurements")
        
        results = {
            'min_cold_start': min(cold_start_times),
            'max_cold_start': max(cold_start_times),
            'avg_cold_start': statistics.mean(cold_start_times),
            'median_cold_start': statistics.median(cold_start_times),
            'total_tests': len(cold_start_times)
        }
        
        self.results['cold_start'] = results
        return results

    def benchmark_message_sizes(self, sizes_kb=[1, 10, 50, 100, 200]) -> Dict[int, Dict[str, float]]:
        """Benchmark performance with different message sizes."""
        print(f"Running message size benchmark for sizes: {sizes_kb} KB...")
        
        results_by_size = {}
        
        for size_kb in sizes_kb:
            print(f"Testing {size_kb}KB messages...")
            
            # Create message content of specified size
            content = 'x' * (size_kb * 1024 - 100)  # Leave room for JSON overhead
            
            latencies = []
            
            for i in range(20):  # 20 iterations per size
                correlation_id = str(uuid.uuid4())
                test_message = {
                    'message': content,
                    'size_kb': size_kb,
                    'benchmarkType': 'messageSize',
                    'correlationId': correlation_id
                }
                
                start_time = time.time()
                
                try:
                    response = self.lambda_client.invoke(
                        FunctionName=self.publisher_function_name,
                        InvocationType='RequestResponse',
                        Payload=json.dumps(test_message)
                    )
                    
                    end_time = time.time()
                    
                    if response['StatusCode'] == 200:
                        latency = (end_time - start_time) * 1000
                        latencies.append(latency)
                
                except Exception as e:
                    print(f"Error with {size_kb}KB message {i}: {e}")
                
                time.sleep(0.1)
            
            if latencies:
                results_by_size[size_kb] = {
                    'avg_latency': statistics.mean(latencies),
                    'min_latency': min(latencies),
                    'max_latency': max(latencies),
                    'p95_latency': self._percentile(latencies, 0.95),
                    'successful_requests': len(latencies)
                }
        
        self.results['message_sizes'] = results_by_size
        return results_by_size

    def get_cloudwatch_metrics(self, hours_back=1) -> Dict[str, Any]:
        """Retrieve CloudWatch metrics for analysis."""
        print("Retrieving CloudWatch metrics...")
        
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours_back)
        
        metrics = {}
        
        try:
            # Lambda metrics
            for function_name in [self.publisher_function_name, self.subscriber_function_name]:
                function_metrics = {}
                
                # Duration metric
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/Lambda',
                    MetricName='Duration',
                    Dimensions=[
                        {'Name': 'FunctionName', 'Value': function_name}
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,  # 5 minutes
                    Statistics=['Average', 'Maximum', 'Minimum']
                )
                function_metrics['Duration'] = response['Datapoints']
                
                # Invocation count
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/Lambda',
                    MetricName='Invocations',
                    Dimensions=[
                        {'Name': 'FunctionName', 'Value': function_name}
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum']
                )
                function_metrics['Invocations'] = response['Datapoints']
                
                # Errors
                response = self.cloudwatch.get_metric_statistics(
                    Namespace='AWS/Lambda',
                    MetricName='Errors',
                    Dimensions=[
                        {'Name': 'FunctionName', 'Value': function_name}
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum']
                )
                function_metrics['Errors'] = response['Datapoints']
                
                metrics[function_name] = function_metrics
        
        except Exception as e:
            print(f"Error retrieving CloudWatch metrics: {e}")
            metrics = {'error': str(e)}
        
        self.results['cloudwatch_metrics'] = metrics
        return metrics

    def generate_report(self, output_dir='benchmark-results') -> str:
        """Generate comprehensive benchmark report."""
        print(f"Generating benchmark report in {output_dir}...")
        
        os.makedirs(output_dir, exist_ok=True)
        
        # Generate text report
        report_file = os.path.join(output_dir, f'benchmark-report-{datetime.now().strftime("%Y%m%d-%H%M%S")}.txt')
        
        with open(report_file, 'w') as f:
            f.write("AWS Lambda Pub/Sub Solution - Benchmark Report\n")
            f.write("=" * 50 + "\n\n")
            f.write(f"Generated: {datetime.now()}\n")
            f.write(f"Region: {self.region}\n")
            f.write(f"Publisher Function: {self.publisher_function_name}\n")
            f.write(f"Subscriber Function: {self.subscriber_function_name}\n\n")
            
            # Single message latency results
            if 'single_message_latency' in self.results:
                f.write("Single Message Latency Benchmark\n")
                f.write("-" * 30 + "\n")
                results = self.results['single_message_latency']
                f.write(f"Total Requests: {results['total_requests']}\n")
                f.write(f"Success Rate: {results['success_rate']:.2f}%\n")
                f.write(f"Average Latency: {results['avg_latency']:.2f}ms\n")
                f.write(f"Median Latency: {results['median_latency']:.2f}ms\n")
                f.write(f"95th Percentile: {results['p95_latency']:.2f}ms\n")
                f.write(f"99th Percentile: {results['p99_latency']:.2f}ms\n")
                f.write(f"Min Latency: {results['min_latency']:.2f}ms\n")
                f.write(f"Max Latency: {results['max_latency']:.2f}ms\n\n")
            
            # Throughput results
            if 'throughput' in self.results:
                f.write("Throughput Benchmark\n")
                f.write("-" * 20 + "\n")
                results = self.results['throughput']
                f.write(f"Total Requests: {results['total_requests']}\n")
                f.write(f"Successful Requests: {results['successful_requests']}\n")
                f.write(f"Failed Requests: {results['failed_requests']}\n")
                f.write(f"Success Rate: {results['success_rate']:.2f}%\n")
                f.write(f"Requests/Second: {results['requests_per_second']:.2f}\n")
                f.write(f"Avg Response Time: {results['avg_response_time']:.2f}ms\n")
                f.write(f"95th Percentile: {results['p95_response_time']:.2f}ms\n\n")
            
            # Cold start results
            if 'cold_start' in self.results:
                f.write("Cold Start Benchmark\n")
                f.write("-" * 20 + "\n")
                results = self.results['cold_start']
                f.write(f"Total Tests: {results['total_tests']}\n")
                f.write(f"Average Cold Start: {results['avg_cold_start']:.2f}ms\n")
                f.write(f"Median Cold Start: {results['median_cold_start']:.2f}ms\n")
                f.write(f"Min Cold Start: {results['min_cold_start']:.2f}ms\n")
                f.write(f"Max Cold Start: {results['max_cold_start']:.2f}ms\n\n")
            
            # Message size results
            if 'message_sizes' in self.results:
                f.write("Message Size Benchmark\n")
                f.write("-" * 25 + "\n")
                for size_kb, results in self.results['message_sizes'].items():
                    f.write(f"{size_kb}KB Messages:\n")
                    f.write(f"  Average Latency: {results['avg_latency']:.2f}ms\n")
                    f.write(f"  95th Percentile: {results['p95_latency']:.2f}ms\n")
                    f.write(f"  Successful Requests: {results['successful_requests']}\n")
        
        # Generate charts if matplotlib is available
        try:
            self._generate_charts(output_dir)
        except Exception as e:
            print(f"Could not generate charts: {e}")
        
        print(f"Report saved to: {report_file}")
        return report_file

    def _generate_charts(self, output_dir: str):
        """Generate performance charts."""
        # Latency distribution chart
        if 'single_message_latency' in self.results:
            plt.figure(figsize=(10, 6))
            
            # Create sample data for demonstration
            # In a real implementation, you'd store individual measurements
            results = self.results['single_message_latency']
            metrics = ['Min', 'Median', 'Avg', 'P95', 'P99', 'Max']
            values = [
                results['min_latency'],
                results['median_latency'],
                results['avg_latency'],
                results['p95_latency'],
                results['p99_latency'],
                results['max_latency']
            ]
            
            plt.bar(metrics, values)
            plt.title('Lambda Function Latency Distribution')
            plt.ylabel('Latency (ms)')
            plt.xticks(rotation=45)
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, 'latency_distribution.png'))
            plt.close()
        
        # Message size performance chart
        if 'message_sizes' in self.results:
            sizes = list(self.results['message_sizes'].keys())
            avg_latencies = [results['avg_latency'] for results in self.results['message_sizes'].values()]
            
            plt.figure(figsize=(10, 6))
            plt.plot(sizes, avg_latencies, marker='o')
            plt.title('Performance vs Message Size')
            plt.xlabel('Message Size (KB)')
            plt.ylabel('Average Latency (ms)')
            plt.grid(True)
            plt.tight_layout()
            plt.savefig(os.path.join(output_dir, 'message_size_performance.png'))
            plt.close()

    @staticmethod
    def _percentile(data: List[float], percentile: float) -> float:
        """Calculate percentile of data."""
        if not data:
            return 0
        sorted_data = sorted(data)
        index = int(percentile * len(sorted_data))
        return sorted_data[min(index, len(sorted_data) - 1)]


def main():
    """Main benchmark execution."""
    parser = argparse.ArgumentParser(description='AWS Lambda Pub/Sub Benchmark')
    parser.add_argument('--latency', action='store_true', help='Run latency benchmark')
    parser.add_argument('--throughput', action='store_true', help='Run throughput benchmark')
    parser.add_argument('--cold-start', action='store_true', help='Run cold start benchmark')
    parser.add_argument('--message-sizes', action='store_true', help='Run message size benchmark')
    parser.add_argument('--all', action='store_true', help='Run all benchmarks')
    parser.add_argument('--output-dir', default='benchmark-results', help='Output directory for results')
    
    args = parser.parse_args()
    
    if not any([args.latency, args.throughput, args.cold_start, args.message_sizes, args.all]):
        args.all = True  # Default to all tests
    
    benchmark = PubSubBenchmark()
    
    try:
        if args.latency or args.all:
            benchmark.benchmark_single_message_latency()
        
        if args.throughput or args.all:
            benchmark.benchmark_throughput()
        
        if args.message_sizes or args.all:
            benchmark.benchmark_message_sizes()
        
        # Skip cold start test by default as it takes a long time
        if args.cold_start:
            benchmark.benchmark_cold_start()
        
        # Get CloudWatch metrics
        benchmark.get_cloudwatch_metrics()
        
        # Generate report
        report_file = benchmark.generate_report(args.output_dir)
        
        print("\nBenchmark completed successfully!")
        print(f"Results saved to: {report_file}")
        
    except Exception as e:
        print(f"Benchmark failed: {e}")
        return 1
    
    return 0


if __name__ == '__main__':
    exit(main())