# Supabase Edge Function Setup Guide

## Step 1: Install Supabase CLI

You need the Supabase CLI to deploy Edge Functions.

**Install via Homebrew (Mac):**
```bash
brew install supabase/tap/supabase
```

**Or download from:** https://github.com/supabase/cli/releases

**Verify installation:**
```bash
supabase --version
```

---

## Step 2: Login to Supabase

```bash
supabase login
```

This will open your browser to authenticate. After logging in, you're ready to deploy.

---

## Step 3: Link Your Project

```bash
cd "/Users/sheribetuel/Desktop/LFL Success 10-28 5PM/LFLversion43!!! 10-28/LFL V43"
supabase link --project-ref YOUR_PROJECT_REF
```

**To find your Project Ref:**
1. Go to Supabase Dashboard
2. Click **Settings** → **General**
3. Look for **"Reference ID"** (it's a short string like `pkiwadwqpygpikrvuvgx`)
4. Copy it and use it in the command above

---

## Step 4: Set Environment Variables

You need to set your Lambda URL and Supabase credentials:

```bash
supabase secrets set LAMBDA_URL=https://75gu2r32syfuqogbcn7nugmfm40oywqn.lambda-url.us-east-2.on.aws/
```

**To get your Supabase Service Role Key:**
1. Go to Supabase Dashboard
2. Click **Settings** → **API**
3. Find **"service_role key"** (keep this SECRET!)
4. Copy it

Then set it as a secret:
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

**Note:** The `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available in Edge Functions, but you can also set them explicitly if needed.

---

## Step 5: Deploy the Edge Function

```bash
supabase functions deploy extract-recipe
```

This will:
- Upload the function code
- Set up the function endpoint
- Make it available at: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/extract-recipe`

---

## Step 6: Test the Function

You can test it from the Supabase Dashboard:

1. Go to **Edge Functions** in the left sidebar
2. Click on **extract-recipe**
3. Click **"Invoke"** tab
4. Paste this test payload:
```json
{
  "url": "https://www.youtube.com/watch?v=MB_FFYq_mr0",
  "html": ""
}
```
5. Click **"Invoke"**
6. You should see a recipe response!

---

## Step 7: Get Your Function URL

After deployment, your function will be available at:

```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/extract-recipe
```

**To call it from your iOS app, you'll need:**
- Function URL (above)
- Your `anon public` API key (from Settings → API)

---

## Troubleshooting

**If deployment fails:**
- Make sure you're logged in: `supabase login`
- Make sure project is linked: `supabase link --project-ref YOUR_REF`
- Check secrets are set: `supabase secrets list`

**If function returns errors:**
- Check Edge Function logs in Supabase Dashboard
- Go to **Edge Functions** → **extract-recipe** → **Logs** tab

---

## Next Steps

After the Edge Function is deployed, we'll update your iOS app to call Supabase instead of Lambda directly. This will enable caching and reduce costs!





