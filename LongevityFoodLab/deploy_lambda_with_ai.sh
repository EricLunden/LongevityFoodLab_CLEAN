#!/bin/bash

# Deployment script for Lambda function with AI multi-part recipe detection
# This script packages and deploys the updated Lambda function

set -e  # Exit on error

FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-longevity-recipe-parser}"
REGION="${AWS_REGION:-us-east-2}"
PACKAGE_DIR="lambda-package-ai"

echo "🚀 Deploying Lambda function '$FUNCTION_NAME' with AI multi-part detection..."
echo "📍 Region: $REGION"
echo ""

# Step 1: Create package directory
echo "📦 Step 1: Creating function package..."
rm -rf $PACKAGE_DIR
mkdir -p $PACKAGE_DIR

# Step 2: Install dependencies
echo "📦 Step 2: Installing dependencies..."
pip3 install -r requirements_no_lxml.txt -t $PACKAGE_DIR/ --no-deps

# Install dependencies one by one to avoid lxml
pip3 install beautifulsoup4==4.12.3 -t $PACKAGE_DIR/
pip3 install requests==2.31.0 -t $PACKAGE_DIR/
pip3 install isodate -t $PACKAGE_DIR/
pip3 install extruct -t $PACKAGE_DIR/
pip3 install typing-extensions -t $PACKAGE_DIR/
pip3 install charset-normalizer -t $PACKAGE_DIR/
pip3 install soupsieve -t $PACKAGE_DIR/
pip3 install six -t $PACKAGE_DIR/
pip3 install pyRdfa3 -t $PACKAGE_DIR/
pip3 install mf2py -t $PACKAGE_DIR/
pip3 install openai>=1.0.0 -t $PACKAGE_DIR/

# Step 3: Copy function code
echo "📦 Step 3: Copying function code..."
# Use the longevity-recipe-parser code (backup file is the current working version)
cp lambda_function_longevity_BACKUP.py $PACKAGE_DIR/lambda_function.py

# Step 4: Create deployment zip
echo "📦 Step 4: Creating deployment package..."
cd $PACKAGE_DIR
zip -r ../lambda-function-ai-deployment.zip . -q
cd ..

# Get package size
PACKAGE_SIZE=$(du -h lambda-function-ai-deployment.zip | cut -f1)
echo "✅ Package created: lambda-function-ai-deployment.zip ($PACKAGE_SIZE)"
echo ""

# Step 5: Deploy to AWS Lambda
echo "🚀 Step 5: Deploying to AWS Lambda..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &>/dev/null; then
    echo "   Function exists - updating code..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://lambda-function-ai-deployment.zip \
        --region $REGION \
        --output json | jq -r '.FunctionName, .LastModified, .CodeSize'
    
    echo ""
    echo "✅ Function code updated successfully!"
    echo ""
    echo "📋 Verification:"
    echo "   - Check CloudWatch logs for 'AI detected' messages"
    echo "   - Test with a multi-part recipe (e.g., cake + frosting)"
    echo "   - Monitor for any errors"
else
    echo "❌ Function '$FUNCTION_NAME' not found in region '$REGION'"
    echo ""
    echo "💡 To create the function, run:"
    echo "   aws lambda create-function \\"
    echo "     --function-name $FUNCTION_NAME \\"
    echo "     --runtime python3.9 \\"
    echo "     --role <YOUR_IAM_ROLE_ARN> \\"
    echo "     --handler lambda_function.lambda_handler \\"
    echo "     --zip-file fileb://lambda-function-ai-deployment.zip \\"
    echo "     --timeout 30 \\"
    echo "     --memory-size 512 \\"
    echo "     --region $REGION"
    echo ""
    echo "   Or upload lambda-function-ai-deployment.zip manually via AWS Console"
fi

# Step 6: Cleanup
echo ""
echo "🧹 Cleaning up..."
rm -rf $PACKAGE_DIR

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Notes:"
echo "   - OPENAI_API_KEY should already be set in Lambda environment variables"
echo "   - If AI detection fails, function will fall back to single-part recipe"
echo "   - Check CloudWatch logs: /aws/lambda/$FUNCTION_NAME"

