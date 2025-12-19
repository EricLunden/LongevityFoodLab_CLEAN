# Supabase Setup Guide - Step by Step

## Step 1: Sign Up for Supabase

1. Go to **https://supabase.com**
2. Click **"Start your project"** or **"Sign Up"** (top right)
3. Choose one of these sign-up options:
   - **GitHub** (easiest - uses your GitHub account)
   - **Email** (create account with email/password)
   - **Google** (uses Google account)
4. Complete the sign-up process

---

## Step 2: Create Your First Project

1. After signing in, you'll see the Supabase dashboard
2. Click **"New Project"** button (green button, usually top right)
3. Fill in the project details:
   - **Name:** `LongevityFoodLabBackend` (or any name you prefer)
   - **Database Password:** Create a strong password (save this somewhere safe - you'll need it)
   - **Region:** Choose closest to you (e.g., **US East (N. Virginia)** for US users)
   - **Pricing Plan:** Select **"Free"** (generous free tier)
4. Click **"Create new project"**
5. Wait 2-3 minutes for Supabase to set up your project (you'll see a progress screen)

---

## Step 3: Get Your API Keys

Once your project is ready:

1. In the left sidebar, click **"Settings"** (gear icon at bottom)
2. Click **"API"** in the settings menu
3. You'll see important information - **save these somewhere safe:**

   **Project URL:**
   ```
   https://xxxxxxxxxxxxx.supabase.co
   ```
   (Copy this - you'll need it for your app)

   **anon public key:**
   ```
   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4eHh4eHh4eHh4eHh4eHh4eCIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1OTk5OTk5LCJleHAiOjE5NjE1NzU5OTl9.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   (This is your public API key - safe to use in iOS app)

   **service_role key:**
   ```
   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4eHh4eHh4eHh4eHh4eHh4eCIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDU5OTk5OTksImV4cCI6MTk2MTU3NTk5OX0.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   (Keep this SECRET - only use in server-side code, never in iOS app)

---

## Step 4: Verify Your Project is Working

1. In the left sidebar, click **"Table Editor"**
2. You should see an empty list (no tables yet - that's normal)
3. If you see this screen, you're all set!

---

## Step 5: Save Your Credentials

Create a text file or note with:

```
Supabase Project Name: LongevityFoodLabBackend
Project URL: https://xxxxxxxxxxxxx.supabase.co
anon public key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
service_role key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... (KEEP SECRET)
Database Password: [your password]
```

**Important:** Keep the service_role key secret - never commit it to git or put it in your iOS app.

---

## ✅ You're Done with Basic Setup!

Your Supabase project is ready. Next steps will be:
1. Creating the database tables (I'll provide SQL scripts)
2. Setting up Edge Functions (for caching logic)
3. Integrating into your iOS app

**Ready for the next step?** Let me know when you've completed signup and I'll help you create the database tables.





