#!/usr/bin/env python3
"""
Get YouTube OAuth 2.0 Refresh Token

This script helps you get a refresh token for YouTube Data API v3.
Run this ONCE on your local machine to generate a refresh token.

Requirements:
    pip install google-auth-oauthlib

Usage:
    1. Get OAuth credentials from Google Cloud Console:
       - Go to: https://console.cloud.google.com/apis/credentials
       - Create OAuth 2.0 Client ID (Web application)
       - Copy Client ID and Client Secret
    
    2. Update CLIENT_ID and CLIENT_SECRET below
    
    3. Run: python get_youtube_refresh_token.py
    
    4. A browser window will open - sign in and grant permissions
    
    5. Copy the refresh token and add it to AWS Lambda environment variables
"""

from google_auth_oauthlib.flow import InstalledAppFlow
import json

# YouTube Data API v3 scope for reading captions
SCOPES = ['https://www.googleapis.com/auth/youtube.force-ssl']

# ============================================
# STEP 1: Add your OAuth credentials here
# ============================================
# Get these from: https://console.cloud.google.com/apis/credentials
# You can also leave these as empty strings and the script will prompt you
CLIENT_ID = ""
CLIENT_SECRET = ""

# ============================================

def main():
    print("=" * 60)
    print("YouTube OAuth 2.0 Refresh Token Generator")
    print("=" * 60)
    print()
    
    # Prompt for credentials if not set
    global CLIENT_ID, CLIENT_SECRET
    
    if not CLIENT_ID or CLIENT_ID == "YOUR_CLIENT_ID.apps.googleusercontent.com":
        CLIENT_ID = input("Enter your Client ID: ").strip()
    
    if not CLIENT_SECRET or CLIENT_SECRET == "YOUR_CLIENT_SECRET":
        CLIENT_SECRET = input("Enter your Client Secret: ").strip()
    
    if not CLIENT_ID or not CLIENT_SECRET:
        print("❌ ERROR: Both Client ID and Client Secret are required!")
        print()
        print("To get credentials:")
        print("1. Go to: https://console.cloud.google.com/apis/credentials")
        print("2. Create OAuth 2.0 Client ID (Web application)")
        print("3. Copy Client ID and Client Secret")
        return
    
    # Build OAuth client config
    client_config = {
        "web": {
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "redirect_uris": ["http://localhost:8080"]
        }
    }
    
    print("Starting OAuth flow...")
    print("A browser window will open - please sign in and grant permissions.")
    print()
    
    try:
        # Create OAuth flow
        flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
        
        # Run local server to handle OAuth callback
        creds = flow.run_local_server(port=8080, open_browser=True)
        
        print()
        print("=" * 60)
        print("✅ SUCCESS! OAuth credentials obtained")
        print("=" * 60)
        print()
        print("Add these to your AWS Lambda environment variables:")
        print()
        print(f"YOUTUBE_CLIENT_ID={CLIENT_ID}")
        print(f"YOUTUBE_CLIENT_SECRET={CLIENT_SECRET}")
        print(f"YOUTUBE_REFRESH_TOKEN={creds.refresh_token}")
        print()
        print("=" * 60)
        print()
        
        # Save to file for reference
        credentials_data = {
            'client_id': CLIENT_ID,
            'client_secret': CLIENT_SECRET,
            'refresh_token': creds.refresh_token,
            'token_uri': 'https://oauth2.googleapis.com/token',
            'scopes': SCOPES
        }
        
        output_file = 'youtube_oauth_credentials.json'
        with open(output_file, 'w') as f:
            json.dump(credentials_data, f, indent=2)
        
        print(f"✅ Credentials saved to: {output_file}")
        print()
        print("⚠️  IMPORTANT: Keep this file secure! Do NOT commit it to git.")
        print("   Add 'youtube_oauth_credentials.json' to your .gitignore file.")
        print()
        
    except Exception as e:
        print()
        print("❌ ERROR: Failed to get refresh token")
        print(f"   Error: {str(e)}")
        print()
        print("Troubleshooting:")
        print("1. Make sure CLIENT_ID and CLIENT_SECRET are correct")
        print("2. Ensure YouTube Data API v3 is enabled in Google Cloud Console")
        print("3. Check that OAuth consent screen is configured")
        print("4. Make sure port 8080 is available")
        return

if __name__ == '__main__':
    main()

