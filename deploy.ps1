# Multi-Environment Deployment Script
# Usage: .\deploy.ps1 -Environment dev|stage|prod [-Action plan|apply|destroy] [-AutoApprove]

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "stage", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action = "plan",
    
    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Configuration
$TerraformPath = "C:\terraform\terraform.exe"
$ProjectRoot = "C:\AMEX\aws-lambda-pubsub-sns"
$TerraformDir = Join-Path $ProjectRoot "terraform"
$LambdaPackagesDir = Join-Path $ProjectRoot "lambda-packages"

# Color functions for output
function Write-Success($message) {
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Info($message) {
    Write-Host "ℹ️  $message" -ForegroundColor Cyan
}

function Write-Warning($message) {
    Write-Host "⚠️  $message" -ForegroundColor Yellow
}

function Write-Error($message) {
    Write-Host "❌ $message" -ForegroundColor Red
}

function Write-Header($message) {
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Blue
    Write-Host "  $message" -ForegroundColor Blue
    Write-Host "=" * 60 -ForegroundColor Blue
    Write-Host ""
}

# Validation functions
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Terraform
    if (-not (Test-Path $TerraformPath)) {
        Write-Error "Terraform not found at $TerraformPath"
        exit 1
    }
    
    # Check AWS CLI
    try {
        & "C:\Program Files\Amazon\AWSCLIV2\aws.exe" --version | Out-Null
        Write-Success "AWS CLI found"
    } catch {
        Write-Error "AWS CLI not found or not accessible"
        exit 1
    }
    
    # Check configuration file
    $ConfigFile = Join-Path $TerraformDir "terraform.tfvars.$Environment"
    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        exit 1
    }
    
    # Check Lambda packages
    $PublisherZip = Join-Path $LambdaPackagesDir "publisher.zip"
    $SubscriberZip = Join-Path $LambdaPackagesDir "subscriber.zip"
    
    if (-not (Test-Path $PublisherZip)) {
        Write-Warning "Publisher package not found: $PublisherZip"
        Write-Info "Creating Lambda packages..."
        & .\build-lambda-packages.ps1
    }
    
    if (-not (Test-Path $SubscriberZip)) {
        Write-Warning "Subscriber package not found: $SubscriberZip"
        Write-Info "Creating Lambda packages..."
        & .\build-lambda-packages.ps1
    }
    
    Write-Success "All prerequisites validated"
}

function Initialize-Terraform {
    Write-Info "Initializing Terraform..."
    
    Push-Location $TerraformDir
    try {
        & $TerraformPath init
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform init failed"
        }
        Write-Success "Terraform initialized"
    }
    finally {
        Pop-Location
    }
}

function Set-TerraformWorkspace($WorkspaceName) {
    Write-Info "Setting Terraform workspace to '$WorkspaceName'..."
    
    Push-Location $TerraformDir
    try {
        # List workspaces to see if it exists
        $Workspaces = & $TerraformPath workspace list
        
        if ($Workspaces -contains "  $WorkspaceName" -or $Workspaces -contains "* $WorkspaceName") {
            & $TerraformPath workspace select $WorkspaceName
        } else {
            & $TerraformPath workspace new $WorkspaceName
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set workspace"
        }
        
        Write-Success "Workspace set to '$WorkspaceName'"
    }
    finally {
        Pop-Location
    }
}

function Invoke-TerraformAction {
    param($Action, $Environment, $AutoApprove)
    
    $ConfigFile = "terraform.tfvars.$Environment"
    
    Push-Location $TerraformDir
    try {
        switch ($Action) {
            "plan" {
                Write-Info "Running Terraform plan for $Environment..."
                & $TerraformPath plan "-var-file=$ConfigFile" -compact-warnings
            }
            "apply" {
                Write-Info "Applying Terraform configuration for $Environment..."
                if ($AutoApprove) {
                    & $TerraformPath apply "-var-file=$ConfigFile" -auto-approve -compact-warnings
                } else {
                    & $TerraformPath apply "-var-file=$ConfigFile" -compact-warnings
                }
            }
            "destroy" {
                Write-Warning "Destroying infrastructure for $Environment..."
                if ($AutoApprove) {
                    & $TerraformPath destroy "-var-file=$ConfigFile" -auto-approve -compact-warnings
                } else {
                    & $TerraformPath destroy "-var-file=$ConfigFile" -compact-warnings
                }
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform $Action failed"
        }
        
        Write-Success "Terraform $Action completed successfully"
    }
    finally {
        Pop-Location
    }
}

function Show-EnvironmentInfo($Environment) {
    Write-Header "Environment Information"
    Write-Info "Environment: $Environment"
    Write-Info "Terraform Directory: $TerraformDir"
    Write-Info "Configuration File: terraform.tfvars.$Environment"
    Write-Info "Action: $Action"
    
    if ($Environment -eq "prod") {
        Write-Warning "⚠️  PRODUCTION DEPLOYMENT ⚠️"
        Write-Warning "You are about to deploy to PRODUCTION!"
        Write-Warning "Please ensure you have:"
        Write-Warning "  - Tested in dev and stage environments"
        Write-Warning "  - Reviewed all changes"
        Write-Warning "  - Obtained necessary approvals"
        
        if (-not $AutoApprove -and $Action -ne "plan") {
            $confirmation = Read-Host "Type 'DEPLOY-TO-PROD' to continue"
            if ($confirmation -ne "DEPLOY-TO-PROD") {
                Write-Error "Deployment cancelled"
                exit 1
            }
        }
    }
}

# Main execution
try {
    Write-Header "AWS Lambda Pub/Sub Multi-Environment Deployment"
    
    Show-EnvironmentInfo $Environment
    
    Test-Prerequisites
    
    Initialize-Terraform
    
    Set-TerraformWorkspace $Environment
    
    Invoke-TerraformAction $Action $Environment $AutoApprove
    
    if ($Action -eq "apply") {
        Write-Header "Deployment Summary"
        Write-Success "Successfully deployed to $Environment environment!"
        
        # Show outputs
        Push-Location $TerraformDir
        try {
            Write-Info "Terraform outputs:"
            & $TerraformPath output -json | ConvertFrom-Json | Format-Table -AutoSize
        }
        finally {
            Pop-Location
        }
        
        Write-Info "Next steps:"
        Write-Info "  - Test the deployment using the test endpoints"
        Write-Info "  - Monitor CloudWatch logs for any issues"
        Write-Info "  - Update monitoring dashboards if needed"
    }
    
} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}