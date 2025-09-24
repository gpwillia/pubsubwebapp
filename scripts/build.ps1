# AWS Lambda Pub/Sub SNS - Build Script
# This script builds and packages Lambda functions for deployment

param(
    [Parameter()]
    [string]$Environment = "dev",
    
    [Parameter()]
    [switch]$Clean,
    
    [Parameter()]
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script variables
$ScriptRoot = Split-Path -Parent $PSScriptRoot
$SrcPath = Join-Path $ScriptRoot "src"
$PackagesPath = Join-Path $ScriptRoot "lambda-packages"

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
    
    # Check if Python is installed
    try {
        $pythonVersion = python --version 2>&1
        Write-Log "Python version: $pythonVersion"
    }
    catch {
        Write-Log "Python is not installed or not in PATH" "ERROR"
        exit 1
    }
    
    # Check if pip is available
    try {
        pip --version | Out-Null
        Write-Log "pip is available"
    }
    catch {
        Write-Log "pip is not available" "ERROR"
        exit 1
    }
    
    # Check if AWS CLI is installed (optional but recommended)
    try {
        aws --version | Out-Null
        Write-Log "AWS CLI is available"
    }
    catch {
        Write-Log "AWS CLI is not installed - this is optional but recommended" "WARN"
    }
}

function Initialize-Build {
    Write-Log "Initializing build environment..."
    
    # Create packages directory
    if (-not (Test-Path $PackagesPath)) {
        New-Item -ItemType Directory -Path $PackagesPath | Out-Null
        Write-Log "Created packages directory: $PackagesPath"
    }
    
    # Clean packages directory if requested
    if ($Clean) {
        Write-Log "Cleaning packages directory..."
        Get-ChildItem $PackagesPath -Name "*.zip" | ForEach-Object {
            Remove-Item (Join-Path $PackagesPath $_) -Force
            Write-Log "Removed: $_"
        }
    }
}

function Build-LambdaFunction {
    param(
        [string]$FunctionName,
        [string]$SourcePath,
        [string]$OutputPath
    )
    
    Write-Log "Building Lambda function: $FunctionName"
    
    # Create temporary build directory
    $BuildDir = Join-Path $env:TEMP "lambda-build-$FunctionName-$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
    
    try {
        # Copy source files
        Write-Log "Copying source files from $SourcePath to $BuildDir"
        Copy-Item -Path "$SourcePath\*" -Destination $BuildDir -Recurse -Force
        
        # Install dependencies if requirements.txt exists
        $RequirementsFile = Join-Path $BuildDir "requirements.txt"
        if (Test-Path $RequirementsFile) {
            Write-Log "Installing dependencies for $FunctionName"
            
            # Create virtual environment
            $VenvPath = Join-Path $BuildDir ".venv"
            python -m venv $VenvPath
            
            # Activate virtual environment and install dependencies
            $ActivateScript = Join-Path $VenvPath "Scripts\Activate.ps1"
            if (Test-Path $ActivateScript) {
                & $ActivateScript
                pip install -r $RequirementsFile -t $BuildDir --no-deps
                deactivate
            }
            else {
                # Fallback for systems without proper venv support
                pip install -r $RequirementsFile -t $BuildDir --no-deps
            }
            
            # Remove unnecessary files
            $FilesToRemove = @("requirements.txt", ".venv", "__pycache__", "*.pyc", ".pytest_cache", "tests")
            foreach ($Pattern in $FilesToRemove) {
                Get-ChildItem $BuildDir -Name $Pattern -Recurse | ForEach-Object {
                    $FullPath = Join-Path $BuildDir $_
                    if (Test-Path $FullPath) {
                        Remove-Item $FullPath -Force -Recurse
                        if ($Verbose) {
                            Write-Log "Removed: $FullPath"
                        }
                    }
                }
            }
        }
        
        # Create deployment package
        Write-Log "Creating deployment package: $OutputPath"
        
        # Use PowerShell's Compress-Archive
        $ZipFiles = Get-ChildItem $BuildDir -Recurse | Where-Object { -not $_.PSIsContainer }
        Compress-Archive -Path "$BuildDir\*" -DestinationPath $OutputPath -Force
        
        # Verify the package
        if (Test-Path $OutputPath) {
            $Size = (Get-Item $OutputPath).Length
            $SizeMB = [math]::Round($Size / 1MB, 2)
            Write-Log "Package created successfully: $OutputPath ($SizeMB MB)"
            
            # Check size limits
            if ($Size -gt 50MB) {
                Write-Log "Warning: Package size ($SizeMB MB) exceeds 50MB limit for direct upload" "WARN"
                Write-Log "Consider using S3 for deployment or optimizing dependencies" "WARN"
            }
        }
        else {
            throw "Failed to create deployment package"
        }
    }
    catch {
        Write-Log "Error building $FunctionName : $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        # Cleanup build directory
        if (Test-Path $BuildDir) {
            Remove-Item $BuildDir -Force -Recurse
            if ($Verbose) {
                Write-Log "Cleaned up build directory: $BuildDir"
            }
        }
    }
}

function Build-CommonLayer {
    Write-Log "Building common dependencies layer..."
    
    # Create requirements file for common dependencies
    $CommonRequirements = @(
        "boto3>=1.26.0",
        "botocore>=1.29.0",
        "requests>=2.28.0",
        "pydantic>=1.10.0"
    )
    
    $LayerBuildDir = Join-Path $env:TEMP "lambda-layer-build-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $PythonPath = Join-Path $LayerBuildDir "python"
    
    New-Item -ItemType Directory -Path $PythonPath -Force | Out-Null
    
    try {
        # Create requirements file
        $CommonRequirements | Set-Content -Path (Join-Path $LayerBuildDir "requirements.txt")
        
        # Install dependencies
        pip install -r (Join-Path $LayerBuildDir "requirements.txt") -t $PythonPath
        
        # Create layer package
        $LayerPackage = Join-Path $PackagesPath "common-layer.zip"
        Compress-Archive -Path "$LayerBuildDir\*" -DestinationPath $LayerPackage -Force
        
        $Size = (Get-Item $LayerPackage).Length
        $SizeMB = [math]::Round($Size / 1MB, 2)
        Write-Log "Common layer created: $LayerPackage ($SizeMB MB)"
    }
    catch {
        Write-Log "Error building common layer: $($_.Exception.Message)" "ERROR"
        throw
    }
    finally {
        if (Test-Path $LayerBuildDir) {
            Remove-Item $LayerBuildDir -Force -Recurse
        }
    }
}

# Main execution
Write-Log "Starting build process for environment: $Environment"
Write-Log "Build script started at: $(Get-Date)"

try {
    Test-Prerequisites
    Initialize-Build
    
    # Build Publisher Lambda
    $PublisherSource = Join-Path $SrcPath "publisher"
    $PublisherPackage = Join-Path $PackagesPath "publisher.zip"
    Build-LambdaFunction -FunctionName "Publisher" -SourcePath $PublisherSource -OutputPath $PublisherPackage
    
    # Build Subscriber Lambda
    $SubscriberSource = Join-Path $SrcPath "subscriber"
    $SubscriberPackage = Join-Path $PackagesPath "subscriber.zip"
    Build-LambdaFunction -FunctionName "Subscriber" -SourcePath $SubscriberSource -OutputPath $SubscriberPackage
    
    # Optionally build common layer
    if ($Environment -eq "production") {
        Build-CommonLayer
    }
    
    Write-Log "Build completed successfully!" "INFO"
    Write-Log "Deployment packages created in: $PackagesPath"
    
    # List created packages
    Get-ChildItem $PackagesPath -Name "*.zip" | ForEach-Object {
        $Size = (Get-Item (Join-Path $PackagesPath $_)).Length
        $SizeMB = [math]::Round($Size / 1MB, 2)
        Write-Log "  - $_ ($SizeMB MB)"
    }
}
catch {
    Write-Log "Build failed: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-Log "Build script completed at: $(Get-Date)"