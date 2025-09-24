# AWS Lambda Pub/Sub SNS - Destroy Script
# This script destroys all infrastructure using Terraform

param(
    [Parameter()]
    [string]$Environment = "dev",
    
    [Parameter()]
    [string]$Region = "us-east-1",
    
    [Parameter()]
    [switch]$AutoApprove,
    
    [Parameter()]
    [switch]$Force
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script variables
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$TerraformPath = Join-Path $ScriptRoot "terraform"

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

function Confirm-Destruction {
    if (-not $AutoApprove -and -not $Force) {
        Write-Log "WARNING: This will destroy ALL resources in environment '$Environment'" "WARN"
        Write-Log "This action cannot be undone!" "WARN"
        
        # Show what will be destroyed
        Push-Location $TerraformPath
        try {
            Write-Log "Resources that will be destroyed:"
            terraform plan -destroy -var "environment=$Environment" -var "aws_region=$Region" | Select-String "will be destroyed" | ForEach-Object {
                Write-Log "  - $($_.Line.Trim())" "WARN"
            }
        }
        finally {
            Pop-Location
        }
        
        $confirmation = Read-Host "Type 'DELETE' to confirm destruction"
        if ($confirmation -ne "DELETE") {
            Write-Log "Destruction cancelled by user"
            exit 0
        }
    }
}

function Invoke-Destruction {
    Write-Log "Starting infrastructure destruction..."
    
    Push-Location $TerraformPath
    try {
        # Set workspace
        terraform workspace select $Environment
        
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
        
        if ($AutoApprove -or $Force) {
            $destroyArgs += "-auto-approve"
        }
        
        terraform @destroyArgs
        
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform destroy failed with exit code: $LASTEXITCODE"
        }
        
        Write-Log "Infrastructure destroyed successfully"
    }
    catch {
        Write-Log "Destruction failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        Pop-Location
    }
}

# Main execution
Write-Log "Starting destruction process for environment: $Environment"

try {
    Confirm-Destruction
    Invoke-Destruction
    
    Write-Log "Destruction completed successfully!" "INFO"
    Write-Log "All resources for environment '$Environment' have been destroyed"
}
catch {
    Write-Log "Destruction failed: $($_.Exception.Message)" "ERROR"
    exit 1
}