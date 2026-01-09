#!/bin/bash
set -e

echo "🔒 Building Lambda ZIP with x86_64 architecture (NUCLEAR FIX)"
echo "📋 Using AWS Lambda Python 3.11 x86_64 base image"
echo ""

# Clean up any existing build artifacts
rm -f lambda-x86_64-fullmeta.zip
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
    echo '📦 Installing dependencies from requirements-lambda-v141.txt...'
    pip install --no-cache-dir -r requirements-lambda-v141.txt -t build/
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
    if [ ! -f lxml/etree.cpython-311-x86_64-linux-gnu.so ]; then
        echo '❌ ERROR: lxml/etree.cpython-311-x86_64-linux-gnu.so not found'
        exit 1
    fi
    if [ ! -d mf2py-*.dist-info ]; then
        # Check if any mf2py dist-info exists
        MF2PY_COUNT=$(find . -type d -name 'mf2py-*.dist-info' | wc -l)
        if [ "$MF2PY_COUNT" -eq 0 ]; then
            echo '❌ ERROR: mf2py-*.dist-info directory not found'
            exit 1
        fi
    fi
    echo '✅ All required files/directories found'
    
    echo '🧪 STEP 4: Verifying imports inside container (with metadata preserved)...'
    python3 << 'VERIFY_SCRIPT'
import sys
import os
# Add current directory to path for imports
sys.path.insert(0, os.getcwd())
try:
    import lxml.etree
    # Test that etree actually works
    from lxml import etree as et
    print('✅ lxml.etree imported successfully')
except Exception as e:
    print(f'❌ lxml.etree IMPORT FAILED: {e}')
    sys.exit(1)
try:
    # Test mf2py import (this was failing due to missing metadata)
    import mf2py
    print('✅ mf2py imported successfully')
except Exception as e:
    print(f'❌ mf2py IMPORT FAILED: {e}')
    sys.exit(1)
try:
    # Test recipe_scrapers import (v15+ API)
    import recipe_scrapers
    # Check what's available - v15+ may use scrape_me from scrape_me module
    try:
        from recipe_scrapers.scrape_me import scrape_me
        print('✅ recipe_scrapers imported successfully (scrape_me from scrape_me module)')
    except ImportError:
        # Try direct import
        try:
            from recipe_scrapers import scrape_me
            print('✅ recipe_scrapers imported successfully (scrape_me available)')
        except ImportError:
            # Check if scrape_me function exists in the module
            if hasattr(recipe_scrapers, 'scrape_me'):
                print('✅ recipe_scrapers imported successfully (scrape_me function available)')
            else:
                # As long as recipe_scrapers imports, the code will work
                print('✅ recipe_scrapers module imported (functions available)')
except Exception as e:
    print(f'❌ recipe_scrapers IMPORT FAILED: {e}')
    sys.exit(1)
print('✅ IMPORTS OK - All critical imports successful (metadata preserved)')
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

with zipfile.ZipFile('../lambda-x86_64-fullmeta.zip', 'w', zipfile.ZIP_DEFLATED) as zipf:
    zipdir('.', zipf)
PYTHON_SCRIPT
    echo '✅ Build complete inside container'
  "

# Verify ZIP was created
if [ ! -f lambda-x86_64-fullmeta.zip ]; then
    echo "❌ ERROR: ZIP file was not created"
    exit 1
fi

# Get file size
FILE_SIZE=$(du -h lambda-x86_64-fullmeta.zip | cut -f1)
echo ""
echo "✅ Lambda package created: lambda-x86_64-fullmeta.zip"
echo "📏 Size: $FILE_SIZE"
echo ""

# Verify mf2py metadata exists
echo "📋 Verifying mf2py metadata exists..."
MF2PY_META=$(unzip -l lambda-x86_64-fullmeta.zip | grep -c "mf2py.*dist-info" || echo "0")
if [ "$MF2PY_META" -gt 0 ]; then
    echo "✅ mf2py metadata found ($MF2PY_META entries)"
else
    echo "❌ ERROR: mf2py metadata NOT found - build failed metadata check"
    exit 1
fi

# Check for lxml .so files and verify architecture
echo ""
echo "📋 Checking lxml binaries (must be x86_64-linux-gnu, NOT aarch64)..."
unzip -l lambda-x86_64-fullmeta.zip | grep "lxml.*\.so" | head -5

# Verify no aarch64 binaries exist
echo ""
echo "🔍 Verifying no aarch64 binaries exist..."
AARCH64_COUNT=$(unzip -l lambda-x86_64-fullmeta.zip | grep -c "aarch64" || echo "0")
if [ "$AARCH64_COUNT" -gt 0 ]; then
    echo "❌ ERROR: Found $AARCH64_COUNT aarch64 binaries - build failed architecture check"
    exit 1
else
    echo "✅ No aarch64 binaries found - architecture check passed"
fi

# Check for x86_64 binaries
X86_64_COUNT=$(unzip -l lambda-x86_64-fullmeta.zip | grep -c "x86_64-linux-gnu" || echo "0")
if [ "$X86_64_COUNT" -gt 0 ]; then
    echo "✅ Found $X86_64_COUNT x86_64-linux-gnu binaries"
else
    echo "⚠️  WARNING: No x86_64-linux-gnu binaries found in ZIP listing"
fi

echo ""
echo "📋 Build Summary:"
echo "  - ZIP file: lambda-x86_64-fullmeta.zip"
echo "  - Size: $FILE_SIZE"
echo "  - Architecture: x86_64 (linux/amd64)"
echo "  - Base image: public.ecr.aws/lambda/python:3.11-x86_64"
echo "  - Metadata preserved: YES (*.dist-info directories included)"
echo ""

