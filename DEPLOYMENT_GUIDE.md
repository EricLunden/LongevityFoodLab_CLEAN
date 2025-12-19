# AWS Lambda Recipe Parser - Deployment Guide

## Overview
This guide provides step-by-step instructions for deploying the AWS Lambda recipe parser function to AWS.

## Prerequisites
- AWS CLI configured with appropriate permissions
- Python 3.9+ installed locally
- AWS account with Lambda, IAM, and CloudWatch permissions

## Function Details
- **Function Name**: `longevity-recipe-parser`
- **Runtime**: Python 3.9
- **Memory**: 512 MB (recommended)
- **Timeout**: 30 seconds
- **Handler**: `lambda_function.lambda_handler`

## Step 1: Prepare Deployment Package

### 1.1 Install Dependencies
```bash
# Create a temporary directory for packaging
mkdir lambda-deployment
cd lambda-deployment

# Install dependencies
pip install recipe-scrapers==15.0.0 beautifulsoup4==4.12.3 lxml==4.9.3 -t .

# Copy the Lambda function
cp ../lambda_function.py .
```

### 1.2 Create Deployment Package
```bash
# Create ZIP file
zip -r longevity-recipe-parser.zip .

# Verify package size (should be < 50MB for direct upload)
ls -lh longevity-recipe-parser.zip
```

## Step 2: Create IAM Role

### 2.1 Create Trust Policy
Create `trust-policy.json`:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### 2.2 Create IAM Role
```bash
aws iam create-role \
    --role-name lambda-recipe-parser-role \
    --assume-role-policy-document file://trust-policy.json
```

### 2.3 Attach Basic Execution Policy
```bash
aws iam attach-role-policy \
    --role-name lambda-recipe-parser-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

### 2.4 Get Role ARN
```bash
aws iam get-role --role-name lambda-recipe-parser-role --query 'Role.Arn' --output text
```

## Step 3: Deploy Lambda Function

### 3.1 Create Function
```bash
aws lambda create-function \
    --function-name longevity-recipe-parser \
    --runtime python3.9 \
    --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-recipe-parser-role \
    --handler lambda_function.lambda_handler \
    --zip-file fileb://longevity-recipe-parser.zip \
    --timeout 30 \
    --memory-size 512 \
    --description "Recipe parser for Longevity Food Lab app"
```

### 3.2 Update Function (for subsequent deployments)
```bash
aws lambda update-function-code \
    --function-name longevity-recipe-parser \
    --zip-file fileb://longevity-recipe-parser.zip
```

## Step 4: Test the Function

### 4.1 Create Test Event
Create `test-event.json`:
```json
{
  "url": "https://example.com/recipe",
  "html": "<!DOCTYPE html><html><head><title>Test Recipe</title></head><body><h1>Test Recipe</h1><ul class=\"ingredients\"><li>1 cup flour</li><li>1 egg</li></ul><ol class=\"instructions\"><li>Mix ingredients</li><li>Cook</li></ol></body></html>"
}
```

### 4.2 Invoke Function
```bash
aws lambda invoke \
    --function-name longevity-recipe-parser \
    --payload file://test-event.json \
    response.json

# View response
cat response.json | jq .
```

## Step 5: Set Up API Gateway (Optional)

### 5.1 Create API Gateway
```bash
aws apigateway create-rest-api \
    --name longevity-recipe-parser-api \
    --description "API for recipe parsing service"
```

### 5.2 Get API ID
```bash
aws apigateway get-rest-apis --query 'items[?name==`longevity-recipe-parser-api`].id' --output text
```

### 5.3 Create Resource and Method
```bash
# Get root resource ID
API_ID="your-api-id"
aws apigateway get-resources --rest-api-id $API_ID --query 'items[?path==`/`].id' --output text

# Create /parse resource
aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id ROOT_RESOURCE_ID \
    --path-part parse

# Create POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id PARSE_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE
```

### 5.4 Set Up Lambda Integration
```bash
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id PARSE_RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:YOUR_ACCOUNT_ID:function:longevity-recipe-parser/invocations
```

## Step 6: Monitoring and Logs

### 6.1 View CloudWatch Logs
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/longevity-recipe-parser
```

### 6.2 Monitor Function Metrics
- Go to AWS Lambda Console
- Select `longevity-recipe-parser` function
- View CloudWatch metrics for:
  - Invocations
  - Duration
  - Errors
  - Memory usage

### 6.3 Set Up Alarms (Optional)
```bash
aws cloudwatch put-metric-alarm \
    --alarm-name "RecipeParserHighErrorRate" \
    --alarm-description "High error rate for recipe parser" \
    --metric-name Errors \
    --namespace AWS/Lambda \
    --statistic Sum \
    --period 300 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=FunctionName,Value=longevity-recipe-parser
```

## Step 7: Environment Configuration

### 7.1 Environment Variables (if needed)
```bash
aws lambda update-function-configuration \
    --function-name longevity-recipe-parser \
    --environment Variables='{
        "LOG_LEVEL":"INFO",
        "MAX_HTML_SIZE":"10485760"
    }'
```

### 7.2 VPC Configuration (if needed)
```bash
aws lambda update-function-configuration \
    --function-name longevity-recipe-parser \
    --vpc-config SubnetIds=subnet-12345,subnet-67890,SecurityGroupIds=sg-12345
```

## Step 8: Security Best Practices

### 8.1 Resource-Based Policy
```bash
aws lambda add-permission \
    --function-name longevity-recipe-parser \
    --statement-id allow-api-gateway \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn arn:aws:execute-api:us-east-1:YOUR_ACCOUNT_ID:API_ID/*/*
```

### 8.2 Dead Letter Queue (Optional)
```bash
# Create SQS queue for failed invocations
aws sqs create-queue --queue-name recipe-parser-dlq

# Configure Lambda to use DLQ
aws lambda update-function-configuration \
    --function-name longevity-recipe-parser \
    --dead-letter-config TargetArn=arn:aws:sqs:us-east-1:YOUR_ACCOUNT_ID:recipe-parser-dlq
```

## Step 9: Testing with Real Data

### 9.1 Test with Supported Recipe Sites
```bash
# Test with AllRecipes (if accessible)
curl -X POST https://your-api-gateway-url/parse \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.allrecipes.com/recipe/213742/cheesy-chicken-broccoli-casserole/",
    "html": "<html>...</html>"
  }'
```

### 9.2 Test with Schema.org Data
```bash
# Test with Schema.org structured data
curl -X POST https://your-api-gateway-url/parse \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com/recipe",
    "html": "<!DOCTYPE html><html><head><script type=\"application/ld+json\">{\"@context\":\"https://schema.org\",\"@type\":\"Recipe\",\"name\":\"Test Recipe\",\"recipeIngredient\":[\"1 cup flour\",\"1 egg\"],\"recipeInstructions\":[{\"@type\":\"HowToStep\",\"text\":\"Mix ingredients\"}]}</script></head><body><h1>Test Recipe</h1></body></html>"
  }'
```

## Step 10: Performance Optimization

### 10.1 Memory Optimization
- Start with 512 MB memory
- Monitor CloudWatch metrics
- Adjust based on actual usage patterns

### 10.2 Cold Start Optimization
- Consider provisioned concurrency for high-traffic scenarios
- Use ARM64 architecture for better price/performance

### 10.3 Caching (Future Enhancement)
- Consider adding Redis/ElastiCache for frequently accessed recipes
- Implement response caching based on URL hash

## Troubleshooting

### Common Issues

1. **Import Errors**
   - Ensure all dependencies are included in deployment package
   - Check Python version compatibility

2. **Memory Issues**
   - Increase memory allocation
   - Optimize HTML parsing logic

3. **Timeout Errors**
   - Increase timeout duration
   - Optimize parsing algorithms

4. **Permission Errors**
   - Verify IAM role permissions
   - Check Lambda execution role

### Debug Commands
```bash
# View function logs
aws logs tail /aws/lambda/longevity-recipe-parser --follow

# Get function configuration
aws lambda get-function --function-name longevity-recipe-parser

# Test function locally
python3 lambda_function.py
```

## Cost Estimation

### Lambda Costs (US East 1)
- **Requests**: $0.20 per 1M requests
- **Duration**: $0.0000166667 per GB-second
- **Memory**: 512 MB = $0.0000083333 per GB-second

### Example Monthly Cost (1,000 requests, 1 second average duration)
- Requests: $0.0002
- Duration: $0.000008
- **Total**: ~$0.0002 per month

## Next Steps

1. **Stage 2**: Implement advanced parsing logic and error handling
2. **Stage 3**: Set up API Gateway for HTTP access
3. **Stage 4**: Update iOS app to use Lambda
4. **Stage 5**: Add Redis caching layer

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review function metrics
3. Test with sample data
4. Verify IAM permissions

---

**Deployment completed successfully!** 🎉

The Lambda function is now ready to parse recipes from HTML content and can be integrated with your iOS app.
