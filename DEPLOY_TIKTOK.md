# Deploy TikTok Support - Quick Guide

## ✅ What You've Done
- ✅ Added `APIFY_TOKEN` to Lambda environment variables
- ✅ Tested Apify actor (it works!)

## 🚀 Deploy Lambda Function

### Option 1: Use Existing Deploy Script

```bash
cd lambda-final-build
./scripts/deploy_lambda.sh
```

**Note:** The deploy script may need to include Google API libraries. If deployment fails, use Option 2.

### Option 2: Manual Deployment (Recommended)

1. **Navigate to Lambda directory:**
   ```bash
   cd lambda-final-build
   ```

2. **Create deployment package:**
   ```bash
   # Remove old zip
   rm -f lambda.zip
   
   # Create new zip with all dependencies
   zip -r lambda.zip lambda_function.py \
       bs4/ beautifulsoup4-4.12.2.dist-info/ \
       certifi/ certifi-*.dist-info/ \
       charset_normalizer/ charset_normalizer-*.dist-info/ \
       defusedxml/ defusedxml-*.dist-info/ \
       idna/ idna-*.dist-info/ \
       requests/ requests-*.dist-info/ \
       soupsieve/ soupsieve-*.dist-info/ \
       urllib3/ urllib3-*.dist-info/ \
       google/ google_*.dist-info/ googleapiclient/ googleapis_common_protos-*.dist-info/ \
       google_auth*.dist-info/ google_auth_oauthlib/ google_auth_httplib2.py \
       httplib2/ httplib2-*.dist-info/ \
       cachetools/ cachetools-*.dist-info/ \
       pyasn1/ pyasn1-*.dist-info/ pyasn1_modules/ \
       rsa/ rsa-*.dist-info/ \
       uritemplate/ uritemplate-*.dist-info/ \
       oauthlib/ oauthlib-*.dist-info/ \
       proto/ proto_plus-*.dist-info/ protobuf-*.dist-info/ \
       pyparsing/ pyparsing-*.dist-info/ \
       -x "*.pyc" "*/__pycache__/*" "*/tests/*"
   ```

3. **Upload to Lambda:**
   ```bash
   aws lambda update-function-code \
       --function-name longevity-recipe-parser \
       --zip-file fileb://lambda.zip \
       --region us-east-2
   ```

4. **Verify environment variables:**
   - Go to AWS Lambda Console
   - Check that `APIFY_TOKEN` is set
   - (Optional) Add `APIFY_ACTOR_ID` = `clockworks/tiktok-scraper` if you want to override default

## 🔄 Deploy Supabase Edge Function

The Edge Function update is optional (it already detects TikTok), but if you want to deploy:

1. **Go to Supabase Dashboard:**
   - Navigate to your project
   - Go to Edge Functions

2. **Deploy the function:**
   ```bash
   # If you have Supabase CLI installed
   cd supabase/functions/extract-recipe
   supabase functions deploy extract-recipe
   ```

   Or deploy via Supabase Dashboard:
   - Copy contents of `supabase/functions/extract-recipe/index.ts`
   - Paste into Supabase Edge Function editor
   - Deploy

## ✅ Test After Deployment

1. **Test from iOS app:**
   - Share a TikTok recipe URL
   - Verify extraction works

2. **Check CloudWatch logs:**
   - Look for `LAMBDA/TIKTOK:` log entries
   - Verify Apify calls are working
   - Check for any errors

3. **Test caching:**
   - Share same TikTok URL twice
   - Second request should be instant (cached)

## 🐛 Troubleshooting

**"APIFY_TOKEN not set"**
- Verify token is in Lambda environment variables
- Check spelling (must be exactly `APIFY_TOKEN`)

**"Apify actor start failed"**
- Check token is valid
- Verify actor ID is correct (`clockworks/tiktok-scraper`)
- Check Apify account has credits

**"Failed to extract TikTok video ID"**
- Check URL format is supported
- Verify URL is a valid TikTok video

**Deployment fails**
- Check AWS credentials are configured
- Verify Lambda function name is correct
- Check zip file was created successfully

## 📝 Quick Checklist

- [ ] `APIFY_TOKEN` added to Lambda
- [ ] Lambda function deployed
- [ ] Supabase Edge Function deployed (optional)
- [ ] Tested with TikTok recipe URL
- [ ] Verified CloudWatch logs
- [ ] Tested caching (second request)

---

**Ready to deploy?** Run the deployment commands above!


