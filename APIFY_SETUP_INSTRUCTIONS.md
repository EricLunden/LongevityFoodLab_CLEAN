# Apify Setup Instructions - Step by Step

## What is Apify?
Apify is a platform that provides "actors" (pre-built scrapers) for websites like TikTok. We'll use it to get TikTok video metadata (title, description, thumbnail) without building our own scraper.

---

## Step 1: Create Apify Account

1. **Go to Apify website:**
   - Visit: https://apify.com
   - Click **"Sign Up"** (top right)

2. **Choose sign-up method:**
   - **Option A:** Sign up with Google (easiest)
   - **Option B:** Sign up with email/password
   - **Option C:** Sign up with GitHub

3. **Complete registration:**
   - Fill in your details
   - Verify your email if needed
   - You'll land on the Apify dashboard

---

## Step 2: Get Your API Token

1. **Go to Settings:**
   - Click your **profile icon** (top right)
   - Click **"Settings"**

2. **Find API Tokens:**
   - **Option A:** Click your **profile icon** (top right) → **"Settings"** → Look for **"API Tokens"** or **"Integrations"** in sidebar
   - **Option B:** Go directly to: https://console.apify.com/account/integrations
   - **Option C:** If you're on Integrations page, look for **"API Tokens"** tab or link (may be separate from workflows)

3. **Create a new token:**
   - Look for **"Create token"** or **"Generate token"** button
   - Click it
   - Give it a name: `LFL-TikTok-Extraction`
   - **IMPORTANT:** Copy the token immediately (you won't see it again!)
   - It looks like: `apify_api_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

4. **Save the token:**
   - Paste it somewhere safe (Notes app, password manager, etc.)
   - You'll need it for AWS Lambda environment variables

---

## Step 3: Find the TikTok Scraper Actor

1. **Go to Apify Store:**
   - Click **"Store"** in the top navigation
   - Or visit: https://apify.com/store

2. **Search for TikTok scraper:**
   - In the search bar, type: `tiktok scraper`
   - Press Enter

3. **Choose an actor:**
   - **RECOMMENDED:** **"TikTok Scraper"** by `clockworks` 
     - Actor ID: `clockworks/tiktok-scraper`
     - Most popular and well-maintained
     - Perfect for extracting video metadata (title, description, thumbnail)
   
   - **Alternative:** **"TikTok Video Scraper"** by `clockworks`
     - Actor ID: `clockworks/tiktok-video-scraper`
     - Video-specific, may have better video data
   
   - **Avoid:**
     - Profile/Hashtag/Comments scrapers (not for individual videos)
     - Pay-per-result options (can get expensive)
     - Search scraper (not for single video URLs)

4. **Check the actor details (optional):**
   - Click on the actor to see details
   - Look for:
     - ✅ Good reviews
     - ✅ Recent updates (not abandoned)
     - ✅ Free tier available (or reasonable pricing)
     - ✅ Documentation available

5. **Note the actor ID:**
   - **Recommended:** `clockworks/tiktok-scraper`
   - Format: `username/actor-name`
   - **Save this** - you'll need it for Lambda (or it will default to this)

---

## Step 4: Test the Actor (Optional but Recommended)

1. **Open the actor:**
   - Click on the actor you chose
   - Click **"Try it"** or **"Run"** button

2. **Enter a test TikTok URL:**
   - Find a TikTok recipe video URL
   - Example: `https://www.tiktok.com/@username/video/1234567890`
   - Paste it in the input field

3. **Run the actor:**
   - Click **"Start"** or **"Run"**
   - Wait for it to complete (usually 10-30 seconds)

4. **Check the results:**
   - Look at the output dataset
   - Verify you see:
     - Video title
     - Description/text
     - Thumbnail image URL
     - Author name
   - If you see these fields, the actor works!

---

## Step 5: Check Pricing

1. **Go to Pricing page:**
   - Click **"Pricing"** in top navigation
   - Or visit: https://apify.com/pricing

2. **Check free tier:**
   - Apify usually has a free tier
   - Check how many "compute units" you get free
   - Estimate your usage:
     - Each TikTok extraction = ~1 compute unit
     - Free tier usually = 5-10 compute units/month

3. **Check paid pricing:**
   - If you need more, check paid plans
   - Usually $49/month for starter plan
   - Each extraction costs ~$0.01-0.02

---

## Step 6: Save Your Credentials

**You'll need these two things for Lambda:**

1. **API Token:**
   - Format: `apify_api_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Where: Apify Settings → Integrations → Create Token

2. **Actor ID:**
   - Format: `clockworks/tiktok-scraper` (or whatever you chose)
   - Where: Actor page URL or actor details

**Save both in a safe place!**

---

## Step 7: Add to AWS Lambda (After Implementation)

Once we implement the code, you'll add these to Lambda:

1. **Go to AWS Lambda Console:**
   - Find your Lambda function
   - Go to **Configuration** → **Environment variables**

2. **Add two variables:**
   - **Key:** `APIFY_TOKEN`
     - **Value:** Your API token (from Step 2)
   
   - **Key:** `APIFY_ACTOR_ID` (optional)
     - **Value:** Your actor ID (from Step 3)
     - If not set, defaults to `clockworks/tiktok-scraper`

3. **Save and deploy**

---

## Troubleshooting

### "Invalid API token"
- Make sure you copied the full token
- Check for extra spaces
- Try creating a new token

### "Actor not found"
- Check the actor ID format: `username/actor-name`
- Make sure the actor is public (not private)
- Try a different actor

### "Rate limit exceeded"
- You've used your free tier quota
- Wait until next month, or upgrade plan

### "Actor timeout"
- Some TikTok videos take longer
- The code handles this with 30-second timeout
- Try a different video URL

---

## Next Steps

After you have:
- ✅ Apify account created
- ✅ API token saved
- ✅ Actor ID chosen

**Tell me when you're ready**, and I'll implement the TikTok extraction code!

---

## Quick Reference

- **Apify Website:** https://apify.com
- **Sign Up:** https://apify.com/sign-up
- **API Tokens:** https://console.apify.com/account/integrations
- **Actor Store:** https://apify.com/store
- **Popular Actor:** `clockworks/tiktok-scraper`

