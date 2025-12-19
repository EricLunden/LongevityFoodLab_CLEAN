# Get Your Supabase Anon Key

## Steps:

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Select your project: **Longevity Food Lab**
3. Click **Settings** (gear icon) in the left sidebar
4. Click **API**
5. Find **"anon public"** key (it's a long string starting with `eyJ...`)
6. Copy it

**The key should look like:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBraXdhZHdxcHlncGlrcnZ1dmd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNTQ3OTYsImV4cCI6MjA4MDgzMDc5Nn0.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Then update these files:**
- `LongevityFoodLab/Services/SupabaseConfig.swift` - Update `anonKey`
- `LongevityFoodLabShareExtension/RecipeBrowserService.swift` - Update `SUPABASE_ANON_KEY`
- `LongevityFoodLabShareExtension/YouTubeExtractor.swift` - Update the anon key there too





