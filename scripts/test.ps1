# AWS Lambda Pub/Sub SNS - Test Script
# This script runs tests against the deployed infrastructure

param(
    [Parameter()]
    [string]$Environment = "dev",
    
    [Parameter()]
    [ValidateSet("unit", "integration", "benchmark", "all")]
    [string]$TestType = "all",
    
    [Parameter()]
    [switch]$Coverage,
    
    [Parameter()]
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script variables
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$TestsPath = Join-Path $ScriptRoot "tests"
$TerraformPath = Join-Path $ScriptRoot "terraform"
$SrcPath = Join-Path $ScriptRoot "src"

# Functions
function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $(
        switch ($Level) {
            "INFO" { "Green" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            default { "White" }
        }
    )
}

function Test-Prerequisites {
    Write-Log "Checking test prerequisites..."
    
    # Check if Python is installed
    try {
        python --version | Out-Null
    }
    catch {
        Write-Log "Python is not installed or not in PATH" "ERROR"
        exit 1
    }
    
    # Check if pytest is installed
    try {
        python -m pytest --version | Out-Null
    }
    catch {
        Write-Log "pytest is not installed. Installing..." "WARN"
        pip install pytest pytest-cov
    }
    
    # Check if tests directory exists
    if (-not (Test-Path $TestsPath)) {
        Write-Log "Tests directory not found: $TestsPath" "ERROR"
        Write-Log "Creating basic test structure..."
        New-Item -ItemType Directory -Path $TestsPath -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $TestsPath "unit") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $TestsPath "integration") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $TestsPath "benchmarks") -Force | Out-Null
    }
}

function Get-DeploymentOutputs {
    Write-Log "Retrieving deployment outputs..."
    
    Push-Location $TerraformPath
    try {
        terraform workspace select $Environment
        $outputsJson = terraform output -json
        if ($outputsJson) {
            return $outputsJson | ConvertFrom-Json
        }
        else {
            throw "No terraform outputs found. Is the infrastructure deployed?"
        }
    }
    catch {
        Write-Log "Failed to get deployment outputs: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

function Set-TestEnvironment {
    param($Outputs)
    
    Write-Log "Setting up test environment variables..."
    
    # Set environment variables for tests
    if ($Outputs.sns_topic_arn) {
        $env:TEST_SNS_TOPIC_ARN = $Outputs.sns_topic_arn.value
    }
    
    if ($Outputs.publisher_lambda_function_name) {
        $env:TEST_PUBLISHER_FUNCTION_NAME = $Outputs.publisher_lambda_function_name.value
    }
    
    if ($Outputs.subscriber_lambda_function_name) {
        $env:TEST_SUBSCRIBER_FUNCTION_NAME = $Outputs.subscriber_lambda_function_name.value
    }
    
    if ($Outputs.dlq_url) {
        $env:TEST_DLQ_URL = $Outputs.dlq_url.value
    }
    
    if ($Outputs.api_gateway_url -and $Outputs.api_gateway_url.value) {
        $env:TEST_API_GATEWAY_URL = $Outputs.api_gateway_url.value
    }
    
    $env:TEST_ENVIRONMENT = $Environment
    $env:TEST_AWS_REGION = $Outputs.aws_region.value
    
    Write-Log "Test environment configured for environment: $Environment"
}

function Invoke-UnitTests {
    Write-Log "Running unit tests..."
    
    $unitTestPath = Join-Path $TestsPath "unit"
    if (-not (Test-Path $unitTestPath)) {
        Write-Log "No unit tests found in: $unitTestPath" "WARN"
        return
    }
    
    $pytestArgs = @(
        $unitTestPath,
        "-v"
    )
    
    if ($Coverage) {
        $pytestArgs += @(
            "--cov=$SrcPath",
            "--cov-report=html:coverage-html",
            "--cov-report=term-missing"
        )
    }
    
    if ($Verbose) {
        $pytestArgs += "-s"
    }
    
    python -m pytest @pytestArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Unit tests failed"
    }
    
    Write-Log "Unit tests completed successfully"
}

function Invoke-IntegrationTests {
    param($Outputs)
    
    Write-Log "Running integration tests..."
    
    $integrationTestPath = Join-Path $TestsPath "integration"
    if (-not (Test-Path $integrationTestPath)) {
        Write-Log "No integration tests found in: $integrationTestPath" "WARN"
        return
    }
    
    # Verify deployment is accessible
    if (-not $Outputs.sns_topic_arn) {
        Write-Log "Infrastructure not deployed - skipping integration tests" "WARN"
        return
    }
    
    $pytestArgs = @(
        $integrationTestPath,
        "-v"
    )
    
    if ($Verbose) {
        $pytestArgs += "-s"
    }
    
    python -m pytest @pytestArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Integration tests failed"
    }
    
    Write-Log "Integration tests completed successfully"
}

function Invoke-BenchmarkTests {
    param($Outputs)
    
    Write-Log "Running benchmark tests..."
    
    $benchmarkTestPath = Join-Path $TestsPath "benchmarks"
    if (-not (Test-Path $benchmarkTestPath)) {
        Write-Log "No benchmark tests found in: $benchmarkTestPath" "WARN"
        return
    }
    
    # Verify deployment is accessible
    if (-not $Outputs.sns_topic_arn) {
        Write-Log "Infrastructure not deployed - skipping benchmark tests" "WARN"
        return
    }
    
    $benchmarkScript = Join-Path $benchmarkTestPath "benchmark.py"
    if (Test-Path $benchmarkScript) {
        python $benchmarkScript
        
        if ($LASTEXITCODE -ne 0) {
            throw "Benchmark tests failed"
        }
    }
    
    Write-Log "Benchmark tests completed successfully"
}

function Invoke-LintingAndFormatting {
    Write-Log "Running code linting and formatting checks..."
    
    try {
        # Install linting tools if not present
        python -m pip install black flake8 mypy --quiet
        
        # Run black formatting check
        Write-Log "Checking code formatting with black..."
        python -m black --check $SrcPath
        
        # Run flake8 linting
        Write-Log "Running flake8 linting..."
        python -m flake8 $SrcPath --max-line-length=100 --ignore=E203,W503
        
        # Run mypy type checking
        Write-Log "Running mypy type checking..."
        python -m mypy $SrcPath --ignore-missing-imports
        
        Write-Log "Code quality checks passed"
    }
    catch {
        Write-Log "Code quality checks failed: $($_.Exception.Message)" "WARN"
        # Don't fail the entire test run for linting issues
    }
}

function Generate-TestReport {
    Write-Log "Generating test report..."
    
    $reportPath = Join-Path $ScriptRoot "test-results"
    if (-not (Test-Path $reportPath)) {
        New-Item -ItemType Directory -Path $reportPath | Out-Null
    }
    
    $reportFile = Join-Path $reportPath "test-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    
    $report = @"
AWS Lambda Pub/Sub SNS Test Report
Generated: $(Get-Date)
Environment: $Environment
Test Type: $TestType

Test Results:
- Unit Tests: $(if ($TestType -eq "unit" -or $TestType -eq "all") { "EXECUTED" } else { "SKIPPED" })
- Integration Tests: $(if ($TestType -eq "integration" -or $TestType -eq "all") { "EXECUTED" } else { "SKIPPED" })
- Benchmark Tests: $(if ($TestType -eq "benchmark" -or $TestType -eq "all") { "EXECUTED" } else { "SKIPPED" })

Coverage Report: $(if ($Coverage) { "ENABLED" } else { "DISABLED" })

"@
    
    $report | Out-File $reportFile -Encoding UTF8
    Write-Log "Test report saved to: $reportFile"
}

# Main execution
Write-Log "Starting test execution for environment: $Environment"
Write-Log "Test type: $TestType"

try {
    Test-Prerequisites
    
    $outputs = $null
    if ($TestType -eq "integration" -or $TestType -eq "benchmark" -or $TestType -eq "all") {
        $outputs = Get-DeploymentOutputs
        Set-TestEnvironment $outputs
    }
    
    # Run linting first
    if ($TestType -eq "all") {
        Invoke-LintingAndFormatting
    }
    
    # Run specified tests
    switch ($TestType) {
        "unit" {
            Invoke-UnitTests
        }
        "integration" {
            Invoke-IntegrationTests $outputs
        }
        "benchmark" {
            Invoke-BenchmarkTests $outputs
        }
        "all" {
            Invoke-UnitTests
            Invoke-IntegrationTests $outputs
            Invoke-BenchmarkTests $outputs
        }
    }
    
    Generate-TestReport
    
    Write-Log "All tests completed successfully!" "INFO"
}
catch {
    Write-Log "Tests failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "Test execution completed at: $(Get-Date)"