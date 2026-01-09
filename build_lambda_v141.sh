#!/bin/bash
set -e

echo "🚀 Building Lambda v141 with recipe-scrapers Tier-0..."

# HARD FAIL: Source file must exist
if [ ! -f "lambda-package-v141/lambda_function.py" ]; then
  echo "ERROR: lambda-package-v141/lambda_function.py not found. Build aborted."
  exit 1
fi

# Preserve lambda_function.py while cleaning build directory
if [ -f "lambda-package-v141/lambda_function.py" ]; then
  echo "📋 Preserving lambda_function.py..."
  cp lambda-package-v141/lambda_function.py /tmp/lambda_function.py.backup
fi

# Clean up any existing build directory (dependencies only)
rm -rf lambda-package-v141
mkdir -p lambda-package-v141

# Restore preserved lambda_function.py
if [ -f "/tmp/lambda_function.py.backup" ]; then
  cp /tmp/lambda_function.py.backup lambda-package-v141/lambda_function.py
  rm /tmp/lambda_function.py.backup
  echo "✅ Restored lambda_function.py"
fi

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install -r requirements-lambda-v141.txt -t lambda-package-v141/ --no-deps

# Install dependencies with their sub-dependencies
echo "📦 Installing dependencies with sub-dependencies..."
pip3 install recipe-scrapers==15.0.0 -t lambda-package-v141/
pip3 install beautifulsoup4==4.12.2 -t lambda-package-v141/
pip3 install requests==2.31.0 -t lambda-package-v141/
pip3 install lxml -t lambda-package-v141/
pip3 install extruct -t lambda-package-v141/
pip3 install html-text -t lambda-package-v141/
pip3 install html5lib -t lambda-package-v141/
pip3 install mf2py -t lambda-package-v141/
pip3 install pyRdfa3 -t lambda-package-v141/
pip3 install rdflib -t lambda-package-v141/
pip3 install isodate -t lambda-package-v141/
pip3 install w3lib -t lambda-package-v141/
pip3 install google-api-python-client -t lambda-package-v141/
pip3 install google-auth-httplib2 -t lambda-package-v141/
pip3 install google-auth-oauthlib -t lambda-package-v141/
pip3 install google-auth -t lambda-package-v141/
pip3 install cachetools -t lambda-package-v141/
pip3 install pyasn1 -t lambda-package-v141/
pip3 install pyasn1-modules -t lambda-package-v141/
pip3 install rsa -t lambda-package-v141/
pip3 install uritemplate -t lambda-package-v141/
pip3 install openai -t lambda-package-v141/

# Lambda function already in place (preserved above)
echo "✅ Lambda function source verified"

# Remove unnecessary files to reduce size
echo "🧹 Cleaning up unnecessary files..."
find lambda-package-v141 -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v141 -type d -name "*.dist-info" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v141 -type d -name "tests" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v141 -type d -name "test" -exec rm -r {} + 2>/dev/null || true
find lambda-package-v141 -name "*.pyc" -delete 2>/dev/null || true
find lambda-package-v141 -name "*.pyo" -delete 2>/dev/null || true

# VERIFICATION: Ensure expected code is present
echo "🔍 Verifying lambda_function.py contains expected code..."
grep -q "parse_sally_baking_addiction\|LAMBDA_FINGERPRINT" lambda-package-v141/lambda_function.py || {
  echo "ERROR: Expected code not found in lambda_function.py"
  exit 1
}
echo "✅ Verification passed"

# Create ZIP
echo "📦 Creating ZIP archive..."
cd lambda-package-v141
zip -r ../lambda-function-v141.zip . -q
cd ..

# Get file size
FILE_SIZE=$(du -h lambda-function-v141.zip | cut -f1)
echo ""
echo "✅ Lambda package created: lambda-function-v141.zip"
echo "📏 Size: $FILE_SIZE"
echo ""
echo "📋 Next steps:"
echo "1. Upload lambda-function-v141.zip to AWS Lambda"
echo "2. Set handler to: lambda_function.lambda_handler"
echo "3. Set timeout to at least 30 seconds"
echo "4. Set memory to at least 512 MB (recommended: 1024 MB)"
echo "5. Test with an AllRecipes URL"
echo ""



