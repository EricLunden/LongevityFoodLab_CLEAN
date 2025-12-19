# YouTube OAuth 2.0 Setup Guide

This guide explains how to set up OAuth 2.0 authentication for YouTube Data API v3 to enable caption downloading in your Lambda function.

## Why OAuth 2.0?

The YouTube Data API v3 `captions.download` endpoint requires OAuth 2.0 authentication. API keys alone cannot download captions (they return 401 errors). Your Lambda function now supports OAuth 2.0 and will automatically use it when configured.

## Option 1: OAuth 2.0 with Refresh Token (Recommended for Lambda)

### Step 1: Create OAuth 2.0 Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create a new one)
3. Enable the **YouTube Data API v3**:
   - Go to **APIs & Services** → **Library**
   - Search for "YouTube Data API v3"
   - Click **Enable**

4. Create OAuth 2.0 credentials:
   - Go to **APIs & Services** → **Credentials**
   - Click **Create Credentials** → **OAuth client ID**
   - If prompted, configure the OAuth consent screen:
     - User Type: **External** (unless you have a Google Workspace)
     - App name: Your app name
     - User support email: Your email
     - Developer contact: Your email
     - Click **Save and Continue**
     - Scopes: Add `https://www.googleapis.com/auth/youtube.force-ssl`
     - Click **Save and Continue**
     - Test users: Add your email (for testing)
     - Click **Save and Continue**
   
5. Create OAuth client:
   - Application type: **Web application**
   - Name: "Lambda YouTube OAuth"
   - Authorized redirect URIs: `http://localhost:8080` (or any localhost URL)
   - Click **Create**
   - **Save the Client ID and Client Secret** (you'll need these)

### Step 2: Get Refresh Token (One-Time Setup)

Run this script **once** on your local machine to get a refresh token:

```python
# save_as: get_refresh_token.py
from google_auth_oauthlib.flow import InstalledAppFlow
import json

SCOPES = ['https://www.googleapis.com/auth/youtube.force-ssl']

# Your OAuth client credentials
CLIENT_CONFIG = {
    "web": {
        "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
        "client_secret": "YOUR_CLIENT_SECRET",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "redirect_uris": ["http://localhost:8080"]
    }
}

flow = InstalledAppFlow.from_client_config(CLIENT_CONFIG, SCOPES)
creds = flow.run_local_server(port=8080)

# Save the refresh token
print(f"\n✅ Refresh Token: {creds.refresh_token}\n")
print(f"Client ID: {CLIENT_CONFIG['web']['client_id']}")
print(f"Client Secret: {CLIENT_CONFIG['web']['client_secret']}")

# Save to file for reference
with open('youtube_oauth_credentials.json', 'w') as f:
    json.dump({
        'client_id': CLIENT_CONFIG['web']['client_id'],
        'client_secret': CLIENT_CONFIG['web']['client_secret'],
        'refresh_token': creds.refresh_token
    }, f, indent=2)

print("\n✅ Credentials saved to youtube_oauth_credentials.json")
print("\n⚠️  Keep these credentials secure! Add them to AWS Lambda environment variables.")
```

**To run:**
```bash
pip install google-auth-oauthlib
python get_refresh_token.py
```

This will:
1. Open a browser window
2. Ask you to sign in with your Google account
3. Ask for permission to access YouTube
4. Return a refresh token

### Step 3: Add Credentials to AWS Lambda

Add these environment variables to your Lambda function:

```
YOUTUBE_CLIENT_ID=your_client_id.apps.googleusercontent.com
YOUTUBE_CLIENT_SECRET=your_client_secret
YOUTUBE_REFRESH_TOKEN=your_refresh_token
```

**In AWS Console:**
1. Go to Lambda → Your function → Configuration → Environment variables
2. Add each variable
3. Click **Save**

**Using AWS CLI:**
```bash
aws lambda update-function-configuration \
  --function-name your-function-name \
  --environment Variables="{YOUTUBE_API_KEY=your_key,YOUTUBE_CLIENT_ID=your_id,YOUTUBE_CLIENT_SECRET=your_secret,YOUTUBE_REFRESH_TOKEN=your_token}"
```

---

## Option 2: Service Account (Alternative)

Service accounts are simpler but require more setup in Google Cloud.

### Step 1: Create Service Account

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. **APIs & Services** → **Credentials**
3. Click **Create Credentials** → **Service account**
4. Fill in:
   - Service account name: "lambda-youtube"
   - Click **Create and Continue**
   - Role: **Editor** (or create custom role with YouTube API access)
   - Click **Done**

5. Create and download key:
   - Click on the service account you just created
   - Go to **Keys** tab
   - Click **Add Key** → **Create new key**
   - Choose **JSON**
   - Click **Create**
   - **Save the JSON file** (you'll need this)

### Step 2: Enable YouTube API for Service Account

1. Go to **APIs & Services** → **Library**
2. Enable **YouTube Data API v3**
3. Make sure your service account has access (it should if it has Editor role)

### Step 3: Add to AWS Lambda

**Option A: Environment Variable (JSON string)**
```bash
# Convert JSON file to single line and escape quotes
GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"...","private_key_id":"...","private_key":"...","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}'
```

**Option B: AWS Secrets Manager (Recommended)**
1. Go to AWS Secrets Manager
2. Click **Store a new secret**
3. Choose **Other type of secret**
4. Paste the entire JSON content from your service account file
5. Name it: `youtube-service-account`
6. Click **Store**
7. Add to Lambda environment:
   ```
   GOOGLE_SA_SECRET_NAME=youtube-service-account
   ```

---

## Option 3: Use HTML Fallback (Current Default)

If you don't set up OAuth, the Lambda function will automatically fall back to parsing YouTube watch page HTML to extract captions. This works but:
- ✅ No OAuth setup required
- ✅ No API quotas for captions
- ❌ Less reliable (may fail if YouTube changes HTML structure)
- ❌ Slower (requires fetching and parsing HTML)

The HTML fallback is already implemented and will work automatically.

---

## Testing

After setting up OAuth, test with a YouTube video:

```bash
# Test Lambda function
aws lambda invoke \
  --function-name your-function-name \
  --payload '{"url": "https://www.youtube.com/watch?v=VIDEO_ID"}' \
  response.json

cat response.json
```

Check CloudWatch logs for:
- `LAMBDA/YOUTUBE: Using OAuth 2.0 with refresh token` (OAuth is working)
- `LAMBDA/YOUTUBE: transcript fetched successfully via OAuth` (Success!)

---

## Troubleshooting

### "OAuth setup error"
- Check that environment variables are set correctly
- Verify refresh token is valid (they don't expire, but can be revoked)
- Check CloudWatch logs for specific error messages

### "Google API libraries not installed"
- Make sure `requirements-lambda.txt` includes the Google API packages
- Redeploy Lambda with updated requirements

### "401 Unauthorized"
- OAuth credentials may be invalid
- Check that the refresh token hasn't been revoked
- Verify client ID and secret are correct

### Still using HTML fallback?
- Check CloudWatch logs - if you see "Falling back to watch page HTML parsing", OAuth isn't configured or failed
- Verify environment variables are set in Lambda configuration
- Make sure you've redeployed Lambda after adding environment variables

---

## Security Best Practices

1. **Never commit credentials to git**
   - Add `youtube_oauth_credentials.json` to `.gitignore`
   - Use environment variables or Secrets Manager

2. **Use AWS Secrets Manager** for production
   - More secure than environment variables
   - Easier to rotate credentials

3. **Rotate refresh tokens periodically**
   - Revoke old tokens in Google Cloud Console
   - Generate new ones using the script above

4. **Limit OAuth scope**
   - Only request `youtube.force-ssl` scope (read-only)
   - Don't request write permissions unless needed

---

## Next Steps

1. Choose an OAuth option (Option 1 is recommended)
2. Set up credentials in Google Cloud Console
3. Get refresh token (one-time setup)
4. Add credentials to AWS Lambda environment variables
5. Redeploy Lambda function
6. Test with a YouTube video
7. Check CloudWatch logs to verify OAuth is working

Your Lambda function will automatically use OAuth when available, and fall back to HTML parsing if OAuth fails or isn't configured.

