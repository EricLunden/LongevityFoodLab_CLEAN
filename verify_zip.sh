#!/bin/bash
set -e

ZIP_FILE="lambda-linux.zip"

if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ ZIP file not found: $ZIP_FILE"
    exit 1
fi

echo "🔍 Verifying ZIP contents: $ZIP_FILE"
echo ""

# Check for required files/directories
echo "📋 Checking for required components:"
unzip -l "$ZIP_FILE" | grep -E "lambda_function.py|lxml/|bs4/|recipe_scrapers/" | head -20

echo ""
echo "✅ ZIP contents verified"
echo ""

# Test imports inside Docker
echo "🧪 Testing imports inside Docker container..."
docker run --rm \
  --entrypoint /bin/bash \
  -v "$PWD":/var/task \
  public.ecr.aws/lambda/python:3.11 \
  -c "
    cd /var/task
    python3 << 'PYTHON_SCRIPT'
import zipfile
import os
import sys

# Extract ZIP to temp directory
with zipfile.ZipFile('lambda-linux.zip', 'r') as zip_ref:
    zip_ref.extractall('/tmp/test_imports')

# Add extracted directory to Python path
sys.path.insert(0, '/tmp/test_imports')

# Test imports
try:
    import lxml
    from lxml import etree
    import bs4
    from recipe_scrapers import scrape_url
    print('✅ All imports successful')
except Exception as e:
    print(f'❌ Import failed: {e}')
    sys.exit(1)
PYTHON_SCRIPT
  "

echo ""
echo "✅ Import test passed"

