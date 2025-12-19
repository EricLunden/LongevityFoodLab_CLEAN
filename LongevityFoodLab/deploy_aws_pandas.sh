#!/bin/bash
echo "🚀 Deploying Lambda function with AWS Pandas layer..."

# Create function package
echo "📦 Creating function package..."
mkdir -p aws-pandas-package

# Install dependencies (excluding lxml - it's in the AWS layer)
pip3 install -r requirements_aws_pandas.txt -t aws-pandas-package/

# Copy function code
cp lambda_function_aws_pandas.py aws-pandas-package/lambda_function.py

# Create deployment zip
cd aws-pandas-package
zip -r ../lambda-function-aws-pandas.zip .
cd ..

# Clean up
rm -rf aws-pandas-package

if [ $? -ne 0 ]; then
    echo "❌ Function package creation failed"
    exit 1
fi

echo "✅ Function package created: lambda-function-aws-pandas.zip"
echo "📏 Size: $(du -h lambda-function-aws-pandas.zip | cut -f1)"
echo ""
echo "📋 Next steps:"
echo "1. Remove any custom layers from your Lambda function"
echo "2. Add AWS layer: AWSSDKPandas-Python311"
echo "3. Upload this function package"
echo "4. Test with a recipe URL"
echo ""
echo "🎯 This should work with recipe-scrapers and lxml from the AWS layer!"
