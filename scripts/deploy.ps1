# AWS Lambda Pub/Sub SNS - Deployment Script
# This script deploys the infrastructure using Terraform

param(
    [Parameter()]
    [string]$Environment = "dev",
    
    [Parameter()]
    [string]$Region = "us-east-1",
    
    [Parameter()]
    [switch]$PlanOnly,
    
    [Parameter()]
    [switch]$AutoApprove,
    
    [Parameter()]
    [switch]$Build,
    
    [Parameter()]
    [switch]$Destroy,
    
    [Parameter()]
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script variables
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$TerraformPath = Join-Path $ScriptRoot "terraform"
$ScriptsPath = Join-Path $ScriptRoot "scripts"
$BuildScript = Join-Path $ScriptsPath "build.ps1"

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
    Write-Log "Checking prerequisites..."
    
    # Check if Terraform is installed
    try {
        $terraformVersion = terraform version
        Write-Log "Terraform version: $($terraformVersion[0])"
    }
    catch {
        Write-Log "Terraform is not installed or not in PATH" "ERROR"
        Write-Log "Please install Terraform from: https://www.terraform.io/downloads.html" "ERROR"
        exit 1
    }
    
    # Check if AWS CLI is installed and configured
    try {
        aws --version | Out-Null
        $awsAccount = aws sts get-caller-identity --query Account --output text 2>$null
        if ($awsAccount) {
            Write-Log "AWS CLI configured - Account: $awsAccount"
        }
        else {
            Write-Log "AWS CLI is not configured" "ERROR"
            Write-Log "Please run 'aws configure' to set up your credentials" "ERROR"
            exit 1
        }
    }
    catch {
        Write-Log "AWS CLI is not installed or not in PATH" "ERROR"
        Write-Log "Please install AWS CLI from: https://aws.amazon.com/cli/" "ERROR"
        exit 1
    }
    
    # Check if build script exists
    if (-not (Test-Path $BuildScript)) {
        Write-Log "Build script not found: $BuildScript" "ERROR"
        exit 1
    }
    
    # Check if terraform directory exists
    if (-not (Test-Path $TerraformPath)) {
        Write-Log "Terraform directory not found: $TerraformPath" "ERROR"
        exit 1
    }
}

function Initialize-Terraform {
    Write-Log "Initializing Terraform..."
    
    Push-Location $TerraformPath
    try {
        # Initialize Terraform
        Write-Log "Running terraform init..."
        terraform init -upgrade
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed with exit code: $LASTEXITCODE"
        }
        
        Write-Log "Terraform initialized successfully"
    }
    catch {
        Write-Log "Terraform initialization failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

function Set-TerraformWorkspace {
    param([string]$WorkspaceName)
    
    Write-Log "Setting Terraform workspace to: $WorkspaceName"
    
    Push-Location $TerraformPath
    try {
        # Check if workspace exists
        $workspaces = terraform workspace list
        if ($workspaces -match $WorkspaceName) {
            terraform workspace select $WorkspaceName
        }
        else {
            Write-Log "Creating new workspace: $WorkspaceName"
            terraform workspace new $WorkspaceName
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set workspace: $WorkspaceName"
        }
        
        Write-Log "Active workspace: $WorkspaceName"
    }
    catch {
        Write-Log "Failed to set workspace: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

function Build-LambdaPackages {
    Write-Log "Building Lambda deployment packages..."
    
    try {
        $buildArgs = @(
            "-Environment", $Environment
        )
        
        if ($Verbose) {
            $buildArgs += "-Verbose"
        }
        
        & $BuildScript @buildArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Build script failed with exit code: $LASTEXITCODE"
        }
        
        Write-Log "Lambda packages built successfully"
    }
    catch {
        Write-Log "Build failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Invoke-TerraformPlan {
    Write-Log "Running Terraform plan..."
    
    Push-Location $TerraformPath
    try {
        $planArgs = @(
            "plan",
            "-var", "environment=$Environment",
            "-var", "aws_region=$Region",
            "-out=terraform.tfplan"
        )
        
        # Check if terraform.tfvars exists
        $tfvarsFile = Join-Path $TerraformPath "terraform.tfvars"
        if (Test-Path $tfvarsFile) {
            $planArgs += @("-var-file", "terraform.tfvars")
            Write-Log "Using variables file: terraform.tfvars"
        }
        else {
            Write-Log "No terraform.tfvars file found, using defaults" "WARN"
            Write-Log "Consider copying terraform.tfvars.example to terraform.tfvars" "WARN"
        }
        
        terraform @planArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform plan failed with exit code: $LASTEXITCODE"
        }
        
        Write-Log "Terraform plan completed successfully"
    }
    catch {
        Write-Log "Terraform plan failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

function Invoke-TerraformApply {
    Write-Log "Running Terraform apply..."
    
    Push-Location $TerraformPath
    try {
        $applyArgs = @("apply")
        
        if ($AutoApprove) {
            $applyArgs += "-auto-approve"
        }
        
        $applyArgs += "terraform.tfplan"
        
        terraform @applyArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform apply failed with exit code: $LASTEXITCODE"
        }
        
        Write-Log "Terraform apply completed successfully"
        
        # Show outputs
        Write-Log "Deployment outputs:"
        terraform output -json | ConvertFrom-Json | ConvertTo-Json -Depth 10
        
    }
    catch {
        Write-Log "Terraform apply failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

function Invoke-TerraformDestroy {
    Write-Log "Running Terraform destroy..."
    
    $confirmation = Read-Host "Are you sure you want to destroy all resources in environment '$Environment'? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Log "Destroy cancelled by user"
        return
    }
    
    Push-Location $TerraformPath
    try {
        $destroyArgs = @(
            "destroy",
            "-var", "environment=$Environment",
            "-var", "aws_region=$Region"
        )
        
        # Check if terraform.tfvars exists
        $tfvarsFile = Join-Path $TerraformPath "terraform.tfvars"
        if (Test-Path $tfvarsFile) {
            $destroyArgs += @("-var-file", "terraform.tfvars")
        }
        
        if ($AutoApprove) {
            $destroyArgs += "-auto-approve"
        }
        
        terraform @destroyArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform destroy failed with exit code: $LASTEXITCODE"
        }
        
        Write-Log "Terraform destroy completed successfully"
    }
    catch {
        Write-Log "Terraform destroy failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

function Get-DeploymentInfo {
    Write-Log "Retrieving deployment information..."
    
    Push-Location $TerraformPath
    try {
        $outputs = terraform output -json | ConvertFrom-Json
        
        if ($outputs) {
            Write-Log "=== Deployment Information ===" "INFO"
            Write-Log "Environment: $Environment"
            Write-Log "Region: $Region"
            Write-Log "AWS Account: $(aws sts get-caller-identity --query Account --output text)"
            
            if ($outputs.sns_topic_arn) {
                Write-Log "SNS Topic ARN: $($outputs.sns_topic_arn.value)"
            }
            
            if ($outputs.publisher_lambda_function_name) {
                Write-Log "Publisher Function: $($outputs.publisher_lambda_function_name.value)"
            }
            
            if ($outputs.subscriber_lambda_function_name) {
                Write-Log "Subscriber Function: $($outputs.subscriber_lambda_function_name.value)"
            }
            
            if ($outputs.api_gateway_url -and $outputs.api_gateway_url.value) {
                Write-Log "API Gateway URL: $($outputs.api_gateway_url.value)"
            }
            
            Write-Log "================================" "INFO"
        }
    }
    catch {
        Write-Log "Failed to retrieve deployment info: $($_.Exception.Message)" "WARN"
    }
    finally {
        Pop-Location
    }
}

# Main execution
Write-Log "Starting deployment process for environment: $Environment"
Write-Log "Target region: $Region"
Write-Log "Deployment started at: $(Get-Date)"

try {
    Test-Prerequisites
    Initialize-Terraform
    Set-TerraformWorkspace $Environment
    
    if ($Destroy) {
        Invoke-TerraformDestroy
    }
    else {
        if ($Build) {
            Build-LambdaPackages
        }
        
        Invoke-TerraformPlan
        
        if (-not $PlanOnly) {
            Invoke-TerraformApply
            Get-DeploymentInfo
        }
        else {
            Write-Log "Plan-only mode - deployment not applied"
        }
    }
    
    Write-Log "Deployment process completed successfully!" "INFO"
}
catch {
    Write-Log "Deployment failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "Deployment script completed at: $(Get-Date)"