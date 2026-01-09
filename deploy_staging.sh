#!/bin/bash
set -e

ZIP_FILE="dist/lambda-linux-ea21498.zip"
FUNCTION_NAME="longevity-recipe-parser"

if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ ZIP file not found: $ZIP_FILE"
    exit 1
fi

echo "🚀 Deploying to Lambda: $FUNCTION_NAME"
echo ""

# Upload ZIP
echo "📤 Uploading ZIP to Lambda..."
aws lambda update-function-code \
  --function-name "$FUNCTION_NAME" \
  --zip-file "fileb://$ZIP_FILE" \
  --output json | grep -E '"CodeSize"|"LastModified"|"FunctionName"'

# Wait for update to complete
echo ""
echo "⏳ Waiting for function update to complete..."
aws lambda wait function-updated --function-name "$FUNCTION_NAME"

# Publish new version
echo ""
echo "📝 Publishing new version..."
VERSION_OUTPUT=$(aws lambda publish-version \
  --function-name "$FUNCTION_NAME" \
  --description "v144 - Linux build of ea21498 (Dec 23 baseline + AI safety)" \
  --output json)

NEW_VERSION=$(echo "$VERSION_OUTPUT" | grep -o '"Version": "[^"]*"' | cut -d'"' -f4)
echo "✅ Published version: $NEW_VERSION"

# Check if staging alias exists
echo ""
echo "🔍 Checking staging alias..."
STAGING_CHECK=$(aws lambda get-alias \
  --function-name "$FUNCTION_NAME" \
  --name staging 2>&1 || echo "NOT_FOUND")

if echo "$STAGING_CHECK" | grep -q "NOT_FOUND"; then
    echo "📝 Creating staging alias..."
    aws lambda create-alias \
      --function-name "$FUNCTION_NAME" \
      --name staging \
      --function-version "$NEW_VERSION" \
      --description "Staging environment for testing"
else
    echo "📝 Updating staging alias to version $NEW_VERSION..."
    aws lambda update-alias \
      --function-name "$FUNCTION_NAME" \
      --name staging \
      --function-version "$NEW_VERSION"
fi

echo ""
echo "✅ Staging alias now points to version: $NEW_VERSION"
echo ""
echo "⚠️  IMPORTANT: Prod alias unchanged (still on v141)"
echo "📋 Next: Test staging (Step F)"

