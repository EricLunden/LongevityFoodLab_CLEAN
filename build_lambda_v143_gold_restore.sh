#!/bin/bash
set -e

echo "🔒 RESTORING GOLD MASTER LAMBDA (v143)..."
echo "📋 Source: lambda_function_aws_pandas.py (Dec 23 baseline)"
echo ""

# Clean up any existing build directory
rm -rf lambda-package-v143-gold
mkdir -p lambda-package-v143-gold

# Install dependencies from requirements-lambda.txt
echo "📦 Installing dependencies from requirements-lambda.txt..."
pip3 install -r requirements-lambda.txt -t lambda-package-v143-gold/

# CRITICAL: Explicitly install lxml (required by recipe-scrapers)
echo "📦 Installing lxml (required by recipe-scrapers)..."
pip3 install lxml -t lambda-package-v143-gold/

# Copy Lambda function from GOLD MASTER (or current workspace - they're identical)
echo "📋 Copying Lambda function (GOLD MASTER baseline)..."
cp LongevityFoodLab/lambda_function_aws_pandas.py lambda-package-v143-gold/lambda_function.py

# Remove unnecessary files to reduce size
echo "🧹 Cleaning up unnecessary files..."
find lambda-package-v143-gold -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v143-gold -type d -name "*.dist-info" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v143-gold -type d -name "tests" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v143-gold -type d -name "test" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v143-gold -name "*.pyc" -delete 2>/dev/null || true
find lambda-package-v143-gold -name "*.pyo" -delete 2>/dev/null || true

# Create ZIP
echo "📦 Creating ZIP archive..."
cd lambda-package-v143-gold
zip -r ../lambda-function-v143-gold-restore.zip . -q
cd ..

# Get file size
FILE_SIZE=$(du -h lambda-function-v143-gold-restore.zip | cut -f1)
echo ""
echo "✅ Lambda package created: lambda-function-v143-gold-restore.zip"
echo "📏 Size: $FILE_SIZE"
echo ""
echo "📋 Next steps:"
echo "1. Upload lambda-function-v143-gold-restore.zip to AWS Lambda"
echo "2. Set handler to: lambda_function.lambda_handler"
echo "3. Set timeout to at least 30 seconds"
echo "4. Set memory to at least 512 MB (recommended: 1024 MB)"
echo "5. Test with AllRecipes URL before pointing prod"
echo "6. Verify logs show: LAMBDA/TIER0: success — FAST EXIT"
echo ""

