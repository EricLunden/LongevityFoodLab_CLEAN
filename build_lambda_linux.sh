#!/bin/bash
set -e

echo "🔒 Building Linux-compatible Lambda ZIP (commit ea21498)"
echo "📋 Using AWS Lambda Python 3.11 base image"
echo ""

# Clean up any existing build artifacts
rm -f lambda-linux.zip
rm -rf build

# Build inside Docker using AWS Lambda Python base image
echo "🐳 Building inside Docker container..."
docker run --rm \
  --entrypoint /bin/bash \
  -v "$PWD":/var/task \
  public.ecr.aws/lambda/python:3.11 \
  -c "
    set -e
    echo '📦 Upgrading pip...'
    python -m pip install --upgrade pip
    echo '📦 Installing dependencies from requirements-lambda.txt...'
    pip install --no-cache-dir -r requirements-lambda.txt -t build/
    echo '📋 Copying Lambda function...'
    cp LongevityFoodLab/lambda_function_aws_pandas.py build/lambda_function.py
    echo '🧹 Cleaning up unnecessary files...'
    find build -type d -name '__pycache__' -exec rm -r {} + 2>/dev/null || true
    find build -type d -name '*.dist-info' -exec rm -r {} + 2>/dev/null || true
    find build -type d -name 'tests' -exec rm -r {} + 2>/dev/null || true
    find build -type d -name 'test' -exec rm -r {} + 2>/dev/null || true
    find build -name '*.pyc' -delete 2>/dev/null || true
    find build -name '*.pyo' -delete 2>/dev/null || true
    echo '📦 Creating ZIP archive...'
    cd build
    python3 << 'PYTHON_SCRIPT'
import os
import zipfile

def zipdir(path, ziph):
    for root, dirs, files in os.walk(path):
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, path)
            ziph.write(file_path, arcname)

with zipfile.ZipFile('../lambda-linux.zip', 'w', zipfile.ZIP_DEFLATED) as zipf:
    zipdir('.', zipf)
PYTHON_SCRIPT
    echo '✅ Build complete inside container'
  "

# Verify ZIP was created
if [ ! -f lambda-linux.zip ]; then
    echo "❌ ERROR: ZIP file was not created"
    exit 1
fi

# Get file size
FILE_SIZE=$(du -h lambda-linux.zip | cut -f1)
echo ""
echo "✅ Lambda package created: lambda-linux.zip"
echo "📏 Size: $FILE_SIZE"
echo ""

# List top-level ZIP entries
echo "📋 Top-level ZIP entries:"
unzip -l lambda-linux.zip | head -30
echo ""

echo "📋 Next steps:"
echo "1. Verify ZIP contents (Step D)"
echo "2. Deploy to Lambda (Step E)"
echo "3. Point staging alias to new version"
echo "4. Test staging (Step F)"
echo ""

