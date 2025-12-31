#!/bin/bash
set -e

echo "🚀 Building Lambda v142 (Minimal - Dec 23 baseline + safety)..."

# Clean up any existing build directory
rm -rf lambda-package-v142
mkdir -p lambda-package-v142

# Install dependencies from requirements-lambda.txt (minimal set)
echo "📦 Installing dependencies from requirements-lambda.txt..."
pip3 install -r requirements-lambda.txt -t lambda-package-v142/

# Copy Lambda function
echo "📋 Copying Lambda function..."
cp LongevityFoodLab/lambda_function_aws_pandas.py lambda-package-v142/lambda_function.py

# Remove unnecessary files to reduce size
echo "🧹 Cleaning up unnecessary files..."
find lambda-package-v142 -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v142 -type d -name "*.dist-info" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v142 -type d -name "tests" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v142 -type d -name "test" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v142 -name "*.pyc" -delete 2>/dev/null || true
find lambda-package-v142 -name "*.pyo" -delete 2>/dev/null || true

# Create ZIP
echo "📦 Creating ZIP archive..."
cd lambda-package-v142
zip -r ../lambda-function-minimal-v142.zip . -q
cd ..

# Get file size
FILE_SIZE=$(du -h lambda-function-minimal-v142.zip | cut -f1)
echo ""
echo "✅ Lambda package created: lambda-function-minimal-v142.zip"
echo "📏 Size: $FILE_SIZE"
echo ""
echo "📋 Next steps:"
echo "1. Upload lambda-function-minimal-v142.zip to AWS Lambda"
echo "2. Set handler to: lambda_function.lambda_handler"
echo "3. Set timeout to at least 30 seconds"
echo "4. Set memory to at least 512 MB (recommended: 1024 MB)"
echo "5. Test with an AllRecipes URL"
echo "6. Verify logs show: LAMBDA/TIER0: success — FAST EXIT"
echo ""

