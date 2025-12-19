#!/bin/bash
echo "🚀 Deploying Lambda function with recipe-scrapers but NO lxml..."

# Create function package
echo "📦 Creating function package..."
mkdir -p no-lxml-package

# Install dependencies (excluding lxml completely)
pip3 install -r requirements_no_lxml.txt -t no-lxml-package/ --no-deps

# Install dependencies one by one to avoid lxml
pip3 install beautifulsoup4==4.12.3 -t no-lxml-package/
pip3 install requests==2.31.0 -t no-lxml-package/
pip3 install isodate -t no-lxml-package/
pip3 install extruct -t no-lxml-package/
pip3 install typing-extensions -t no-lxml-package/
pip3 install charset-normalizer -t no-lxml-package/
pip3 install soupsieve -t no-lxml-package/
pip3 install six -t no-lxml-package/
pip3 install pyRdfa3 -t no-lxml-package/
pip3 install mf2py -t no-lxml-package/

# Copy function code
cp lambda_function_recipe_scrapers_forced.py no-lxml-package/lambda_function.py

# Create deployment zip
cd no-lxml-package
zip -r ../lambda-function-no-lxml-final.zip .
cd ..

# Clean up
rm -rf no-lxml-package

if [ $? -ne 0 ]; then
    echo "❌ Function package creation failed"
    exit 1
fi

echo "✅ Function package created: lambda-function-no-lxml-final.zip"
echo "📏 Size: $(du -h lambda-function-no-lxml-final.zip | cut -f1)"
echo ""
echo "📋 Next steps:"
echo "1. Upload this function package to Lambda"
echo "2. Keep the AWS Pandas layer (it won't interfere)"
echo "3. Test with a recipe URL"
echo ""
echo "🎯 This should work with recipe-scrapers using html.parser only!"
