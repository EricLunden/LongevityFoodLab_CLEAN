#!/usr/bin/env python3
"""
Deployment script for the AI-enhanced recipe parsing Lambda function.
Creates a deployment package and deploys to AWS Lambda.
"""

import os
import sys
import subprocess
import zipfile
import shutil
from pathlib import Path

def create_deployment_package():
    """Create a deployment package for AWS Lambda."""
    print("Creating deployment package...")
    
    # Create deployment directory
    deploy_dir = Path("deployment")
    if deploy_dir.exists():
        shutil.rmtree(deploy_dir)
    deploy_dir.mkdir()
    
    # Copy main lambda function
    shutil.copy("lambda_function.py", deploy_dir / "lambda_function.py")
    
    # Copy all dependencies (they're already installed in this directory)
    print("Copying dependencies...")
    
    # Copy all the Python packages
    packages_to_copy = [
        'bs4', 'beautifulsoup4-4.12.2.dist-info',
        'certifi', 'certifi-2025.8.3.dist-info',
        'charset_normalizer', 'charset_normalizer-3.4.3.dist-info',
        'idna', 'idna-3.10.dist-info',
        'requests', 'requests-2.31.0.dist-info',
        'soupsieve', 'soupsieve-2.8.dist-info',
        'urllib3', 'urllib3-2.5.0.dist-info'
    ]
    
    for package in packages_to_copy:
        if os.path.exists(package):
            if os.path.isdir(package):
                shutil.copytree(package, deploy_dir / package)
            else:
                shutil.copy2(package, deploy_dir / package)
    
    # Create zip file
    zip_path = "ai_enhanced_recipe_parser.zip"
    if os.path.exists(zip_path):
        os.remove(zip_path)
    
    print(f"Creating {zip_path}...")
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(deploy_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, deploy_dir)
                zipf.write(file_path, arcname)
    
    # Clean up
    shutil.rmtree(deploy_dir)
    
    print(f"Deployment package created: {zip_path}")
    return zip_path

def deploy_to_aws(zip_path, function_name="longevity-recipe-parser"):
    """Deploy the package to AWS Lambda."""
    print(f"Deploying to AWS Lambda function: {function_name}")
    
    try:
        # First, try to update existing function
        print("Attempting to update existing function...")
        subprocess.run([
            "aws", "lambda", "update-function-code",
            "--function-name", function_name,
            "--zip-file", f"fileb://{zip_path}"
        ], check=True)
        
        print("✅ Function updated successfully!")
        
    except subprocess.CalledProcessError:
        print("Function doesn't exist, creating new function...")
        try:
            # Create new function
            subprocess.run([
                "aws", "lambda", "create-function",
                "--function-name", function_name,
                "--runtime", "python3.9",
                "--role", "arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-execution-role",
                "--handler", "lambda_function.lambda_handler",
                "--zip-file", f"fileb://{zip_path}",
                "--timeout", "30",
                "--memory-size", "512",
                "--description", "AI-enhanced recipe parser with Tier-4 fallback"
            ], check=True)
            
            print("✅ Function created successfully!")
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to create function: {e}")
            print("Please ensure you have the correct IAM role ARN and permissions.")
            return False
    
    return True

def set_environment_variables(function_name="longevity-recipe-parser"):
    """Set environment variables for the Lambda function."""
    print("Setting environment variables...")
    
    env_vars = {
        'AI_TIER_ENABLED': 'true',
        'AI_MODEL': 'claude-3-haiku-202410',
        'AI_TIMEOUT_MS': '4000',
        'AI_MIN_TRIGGER_SCORE': '0.60'
    }
    
    try:
        # Convert to AWS CLI format
        env_string = ','.join([f"{k}={v}" for k, v in env_vars.items()])
        
        subprocess.run([
            "aws", "lambda", "update-function-configuration",
            "--function-name", function_name,
            "--environment", f"Variables={{{env_string}}}"
        ], check=True)
        
        print("✅ Environment variables set!")
        print("⚠️  Note: You still need to set ANTHROPIC_API_KEY manually in the AWS Console")
        
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Warning: Could not set environment variables: {e}")
        print("You can set them manually in the AWS Console")

def test_function(function_name="longevity-recipe-parser"):
    """Test the deployed function."""
    print("Testing the deployed function...")
    
    test_payload = {
        "url": "https://www.allrecipes.com/recipe/213742/cheesy-chicken-broccoli-casserole/",
        "html": """
        <html>
        <head><title>Cheesy Chicken Broccoli Casserole</title></head>
        <body>
            <h1>Cheesy Chicken Broccoli Casserole</h1>
            <div class="ingredients">
                <li>2 cups cooked chicken</li>
                <li>1 cup broccoli</li>
                <li>1 cup cheese</li>
            </div>
            <div class="instructions">
                <li>Mix ingredients</li>
                <li>Bake at 350°F</li>
            </div>
        </body>
        </html>
        """
    }
    
    try:
        # Write test payload to file
        with open("test_payload.json", "w") as f:
            import json
            json.dump(test_payload, f)
        
        # Invoke function
        subprocess.run([
            "aws", "lambda", "invoke",
            "--function-name", function_name,
            "--payload", "file://test_payload.json",
            "response.json"
        ], check=True)
        
        # Read and display response
        with open("response.json", "r") as f:
            response = json.load(f)
            print("✅ Function test successful!")
            print(f"Response: {json.dumps(response, indent=2)}")
        
        # Clean up
        os.remove("test_payload.json")
        os.remove("response.json")
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Function test failed: {e}")

def main():
    """Main deployment function."""
    print("AI-Enhanced Recipe Parsing Lambda - Deployment Script")
    print("=" * 60)
    
    # Check if AWS CLI is available
    try:
        subprocess.run(["aws", "--version"], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ Error: AWS CLI not found. Please install AWS CLI first.")
        print("Install: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html")
        return 1
    
    # Create deployment package
    zip_path = create_deployment_package()
    
    # Deploy to AWS
    if deploy_to_aws(zip_path):
        print("\n✅ Deployment completed successfully!")
        
        # Set environment variables
        set_environment_variables()
        
        # Test the function
        test_function()
        
        print(f"\n📦 Package: {zip_path}")
        print("🔧 Function: longevity-recipe-parser")
        print("🌐 URL: https://75gu2r32syfuqogbcn7nugmfm40oywqn.lambda-url.us-east-2.on.aws/")
        print("\n⚠️  Important: Set ANTHROPIC_API_KEY in AWS Console Environment Variables")
        print("📊 Monitor logs: aws logs tail /aws/lambda/longevity-recipe-parser --follow")
        
        return 0
    else:
        print("\n❌ Deployment failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
