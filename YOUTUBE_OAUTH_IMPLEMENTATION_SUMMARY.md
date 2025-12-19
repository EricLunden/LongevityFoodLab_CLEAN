# YouTube OAuth 2.0 Implementation Summary

## What Was Done

I've implemented OAuth 2.0 support for YouTube Data API v3 caption downloading in your Lambda function. The implementation includes:

### 1. Updated Dependencies
- Added Google API client libraries to `requirements-lambda.txt`:
  - `google-api-python-client>=2.0.0`
  - `google-auth-httplib2>=0.1.0`
  - `google-auth-oauthlib>=1.0.0`
  - `google-auth>=2.0.0`

### 2. OAuth Support in Lambda Function
- Added `get_youtube_service_with_oauth()` function that supports:
  - **Option 1**: OAuth 2.0 with refresh token (via environment variables)
  - **Option 2**: Service Account JSON (via environment variable or Secrets Manager)
  - **Option 3**: AWS Secrets Manager integration for service accounts

### 3. Updated Transcript Function
- Modified `fetch_youtube_transcript()` to:
  - Try OAuth 2.0 first (if configured)
  - Fall back to API key method + HTML parsing (if OAuth not available)
  - Automatically handle authentication errors gracefully

### 4. Helper Scripts and Documentation
- Created `get_youtube_refresh_token.py` - Python script to get refresh token
- Created `YOUTUBE_OAUTH_SETUP.md` - Complete setup guide

## How It Works

### Authentication Flow

```
1. Lambda function receives YouTube video request
2. Checks for OAuth credentials (environment variables)
3. If OAuth available:
   → Uses OAuth 2.0 to authenticate
   → Lists caption tracks via YouTube API
   → Downloads captions using OAuth
   → Returns transcript
4. If OAuth not available:
   → Falls back to API key (for listing captions)
   → Falls back to HTML parsing (for downloading captions)
   → Returns transcript
```

### Priority Order

1. **OAuth 2.0 with Refresh Token** (if `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET`, `YOUTUBE_REFRESH_TOKEN` are set)
2. **Service Account JSON** (if `GOOGLE_SERVICE_ACCOUNT_JSON` is set)
3. **Service Account from Secrets Manager** (if `GOOGLE_SA_SECRET_NAME` is set)
4. **API Key + HTML Fallback** (current default, always works)

## Next Steps

### Quick Start (Recommended)

1. **Get OAuth Credentials:**
   ```bash
   # Install dependency
   pip install google-auth-oauthlib
   
   # Edit get_youtube_refresh_token.py with your Client ID and Secret
   # Run the script
   python get_youtube_refresh_token.py
   ```

2. **Add to Lambda Environment Variables:**
   ```
   YOUTUBE_CLIENT_ID=your_client_id.apps.googleusercontent.com
   YOUTUBE_CLIENT_SECRET=your_client_secret
   YOUTUBE_REFRESH_TOKEN=your_refresh_token
   ```

3. **Redeploy Lambda:**
   - Make sure `requirements-lambda.txt` includes the new Google API packages
   - Deploy Lambda function with updated code and requirements

4. **Test:**
   - Process a YouTube video
   - Check CloudWatch logs for: `LAMBDA/YOUTUBE: transcript fetched successfully via OAuth`

### Detailed Setup

See `YOUTUBE_OAUTH_SETUP.md` for:
- Step-by-step Google Cloud Console setup
- Service Account alternative
- Troubleshooting guide
- Security best practices

## Files Modified

1. `requirements-lambda.txt` - Added Google API dependencies
2. `lambda-final-build/lambda_function.py` - Added OAuth support
3. `get_youtube_refresh_token.py` - New helper script
4. `YOUTUBE_OAUTH_SETUP.md` - New setup guide
5. `YOUTUBE_OAUTH_IMPLEMENTATION_SUMMARY.md` - This file

## Benefits

✅ **Reliable Caption Access** - OAuth 2.0 provides official API access to captions
✅ **No IP Blocking** - Uses official YouTube API instead of HTML scraping
✅ **Automatic Fallback** - Still works if OAuth isn't configured
✅ **Multiple Options** - Supports refresh token, service account, or Secrets Manager
✅ **Backward Compatible** - Existing API key + HTML fallback still works

## Current Status

- ✅ Code implemented and ready
- ⏳ OAuth credentials need to be set up (see setup guide)
- ⏳ Lambda needs to be redeployed with new dependencies
- ⏳ Testing needed after OAuth setup

## Notes

- The HTML fallback will continue to work if OAuth isn't configured
- OAuth setup is optional but recommended for better reliability
- Refresh tokens don't expire (unless revoked)
- Service accounts are simpler but require more Google Cloud setup

