#!/bin/bash
set -e

echo "🔒 Building Lambda ZIP - GOLD BASELINE RESTORE (Dec 23)"
echo "📋 Using AWS Lambda Python 3.11 x86_64 base image"
echo "📋 Pinned versions: recipe-scrapers==14.55.0, lxml==4.9.3"
echo ""

# Clean up any existing build artifacts
rm -f lambda-gold-linux-fixed.zip
rm -rf build

# Build inside Docker using AWS Lambda Python x86_64 base image
echo "🐳 Building inside Docker container (linux/amd64 platform)..."
docker run --rm \
  --platform linux/amd64 \
  --entrypoint /bin/bash \
  -v "$PWD":/var/task \
  public.ecr.aws/lambda/python:3.11-x86_64 \
  -c "
    set -e
    echo '📦 Upgrading pip...'
    python -m pip install --upgrade pip
    echo '📦 Installing dependencies from requirements-lambda-gold.txt (GOLD PINNED VERSIONS)...'
    pip install --no-cache-dir -r requirements-lambda-gold.txt -t build/
    echo '📋 Copying Lambda function...'
    cp LongevityFoodLab/lambda_function_aws_pandas.py build/lambda_function.py
    echo '🧹 Cleaning up unnecessary files (PRESERVING *.dist-info for metadata)...'
    find build -type d -name '__pycache__' -exec rm -r {} + 2>/dev/null || true
    # DO NOT DELETE *.dist-info or *.egg-info - required for importlib.metadata
    find build -type d -name 'tests' -exec rm -r {} + 2>/dev/null || true
    find build -type d -name 'test' -exec rm -r {} + 2>/dev/null || true
    find build -name '*.pyc' -delete 2>/dev/null || true
    find build -name '*.pyo' -delete 2>/dev/null || true
    echo '🧪 STEP 3: Verifying ZIP contents before packaging...'
    cd build
    
    # Verify required files/directories exist
    if [ ! -f lambda_function.py ]; then
        echo '❌ ERROR: lambda_function.py not found'
        exit 1
    fi
    if [ ! -d recipe_scrapers ]; then
        echo '❌ ERROR: recipe_scrapers/ directory not found'
        exit 1
    fi
    # Check for lxml binary (version 4.9.3)
    if [ -d lxml ]; then
        if find lxml -name '*.so' 2>/dev/null | head -1 | grep -q .; then
            echo '✅ lxml .so binary found'
        elif [ -f lxml/etree.py ] || [ -f lxml/__init__.py ]; then
            echo '✅ lxml package found'
        else
            echo '❌ ERROR: lxml package not found'
            exit 1
        fi
    else
        echo '❌ ERROR: lxml directory not found'
        exit 1
    fi
    # Check for mf2py metadata
    if find . -type d -name 'mf2py-*.dist-info' 2>/dev/null | grep -q .; then
        echo '✅ mf2py metadata found'
    else
        echo '❌ ERROR: mf2py-*.dist-info directory not found'
        exit 1
    fi
    echo '✅ All required files/directories found'
    
    echo '🧪 STEP 4: Verifying imports inside container (GOLD BASELINE)...'
    python3 << 'VERIFY_SCRIPT'
import sys
import os
# Add current directory to path for imports
sys.path.insert(0, os.getcwd())
try:
    import lxml.etree
    from lxml import etree as et
    print('✅ lxml.etree imported successfully')
except Exception as e:
    print(f'❌ lxml.etree IMPORT FAILED: {e}')
    sys.exit(1)
try:
    import mf2py
    print('✅ mf2py imported successfully')
except Exception as e:
    print(f'❌ mf2py IMPORT FAILED: {e}')
    sys.exit(1)
try:
    # GOLD BASELINE: recipe-scrapers v14.55.0 API - uses scrape_me (not scrape_url)
    from recipe_scrapers import scrape_me
    print('✅ from recipe_scrapers import scrape_me - SUCCESS (GOLD API v14.55.0)')
except Exception as e:
    print(f'❌ recipe_scrapers.scrape_me import FAILED: {e}')
    sys.exit(1)
print('✅ IMPORTS OK - All critical imports successful (GOLD BASELINE)')
VERIFY_SCRIPT
    echo '📦 Creating ZIP archive...'
    python3 << 'PYTHON_SCRIPT'
import os
import zipfile

def zipdir(path, ziph):
    for root, dirs, files in os.walk(path):
        for file in files:
            file_path = os.path.join(root, file)
            arcname = os.path.relpath(file_path, path)
            ziph.write(file_path, arcname)

with zipfile.ZipFile('../lambda-gold-linux-fixed.zip', 'w', zipfile.ZIP_DEFLATED) as zipf:
    zipdir('.', zipf)
PYTHON_SCRIPT
    echo '✅ Build complete inside container'
  "

# Verify ZIP was created
if [ ! -f lambda-gold-linux-fixed.zip ]; then
    echo "❌ ERROR: ZIP file was not created"
    exit 1
fi

# Get file size
FILE_SIZE=$(du -h lambda-gold-linux-fixed.zip | cut -f1)
echo ""
echo "✅ Lambda package created: lambda-gold-linux-fixed.zip"
echo "📏 Size: $FILE_SIZE"
echo ""

# Verify mf2py metadata exists
echo "📋 Verifying mf2py metadata exists..."
MF2PY_META=$(unzip -l lambda-gold-linux-fixed.zip | grep -c "mf2py.*dist-info" || echo "0")
if [ "$MF2PY_META" -gt 0 ]; then
    echo "✅ mf2py metadata found ($MF2PY_META entries)"
else
    echo "❌ ERROR: mf2py metadata NOT found - build failed metadata check"
    exit 1
fi

# Verify no aarch64 binaries exist
echo ""
echo "🔍 Verifying no aarch64 binaries exist..."
AARCH64_COUNT=$(unzip -l lambda-gold-baseline.zip | grep -c "aarch64" || echo "0")
if [ "$AARCH64_COUNT" -gt 0 ]; then
    echo "❌ ERROR: Found $AARCH64_COUNT aarch64 binaries - build failed architecture check"
    exit 1
else
    echo "✅ No aarch64 binaries found - architecture check passed"
fi

# Check for x86_64 binaries
X86_64_COUNT=$(unzip -l lambda-gold-linux-fixed.zip | grep -c "x86_64-linux-gnu\|linux_gnu" || echo "0")
if [ "$X86_64_COUNT" -gt 0 ]; then
    echo "✅ Found $X86_64_COUNT x86_64-linux-gnu binaries"
else
    echo "⚠️  Note: Binary naming may differ for lxml 4.9.3"
fi

echo ""
echo "📋 Build Summary:"
echo "  - ZIP file: lambda-gold-linux-fixed.zip"
echo "  - Size: $FILE_SIZE"
echo "  - Architecture: x86_64 (linux/amd64)"
echo "  - Base image: public.ecr.aws/lambda/python:3.11-x86_64"
echo "  - Metadata preserved: YES (*.dist-info directories included)"
echo "  - GOLD BASELINE: recipe-scrapers==14.55.0, lxml==4.9.3"
echo "  - Import fixed: from recipe_scrapers import scrape_me (v14.55.0 API)"
echo ""

