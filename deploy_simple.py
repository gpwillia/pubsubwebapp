#!/usr/bin/env python3
"""
Simple deployment script that doesn't require PowerShell
Run this after installing AWS CLI and Terraform
"""

import os
import subprocess
import sys
import zipfile
from pathlib import Path

def run_command(command, cwd=None):
    """Run a command and return the result"""
    print(f"Running: {command}")
    result = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        return False
    print(result.stdout)
    return True

def create_lambda_package(source_dir, output_file):
    """Create a Lambda deployment package"""
    print(f"Creating Lambda package: {output_file}")
    
    # Install dependencies
    deps_dir = Path(source_dir) / "deps"
    deps_dir.mkdir(exist_ok=True)
    
    # Install requirements
    run_command(f"pip install -r requirements.txt -t deps", cwd=source_dir)
    
    # Create zip file
    with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as zf:
        # Add source files
        for file in Path(source_dir).glob("*.py"):
            zf.write(file, file.name)
        
        # Add dependencies
        for root, dirs, files in os.walk(deps_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arc_name = os.path.relpath(file_path, deps_dir)
                zf.write(file_path, arc_name)

def main():
    """Main deployment function"""
    print("AWS Lambda Pub/Sub Deployment")
    print("=" * 40)
    
    # Check prerequisites
    if not run_command("aws --version"):
        print("❌ AWS CLI not found. Please install AWS CLI first.")
        return 1
    
    if not run_command("terraform version"):
        print("❌ Terraform not found. Please install Terraform first.")
        return 1
    
    # Create dist directory
    dist_dir = Path("dist")
    dist_dir.mkdir(exist_ok=True)
    
    # Build Lambda packages
    print("\n📦 Building Lambda packages...")
    create_lambda_package("src/publisher", "dist/publisher.zip")
    create_lambda_package("src/subscriber", "dist/subscriber.zip")
    
    # Deploy with Terraform
    print("\n🚀 Deploying infrastructure...")
    os.chdir("terraform")
    
    commands = [
        "terraform init",
        "terraform workspace select dev || terraform workspace new dev",
        "terraform plan -var-file=terraform.tfvars.dev",
        "terraform apply -var-file=terraform.tfvars.dev -auto-approve"
    ]
    
    for command in commands:
        if not run_command(command):
            print(f"❌ Deployment failed at: {command}")
            return 1
    
    print("\n✅ Deployment completed successfully!")
    print("\nTo test your deployment:")
    print("aws lambda invoke --function-name pubsub-dev-publisher --payload '{\"message\":\"test\"}' response.json")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())