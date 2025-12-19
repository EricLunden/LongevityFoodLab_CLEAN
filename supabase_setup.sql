-- ============================================================================
-- Supabase Database Schema for Recipe Caching
-- Longevity Food Lab - Recipe Extraction Cache
-- ============================================================================

-- This script creates the tables needed for caching extracted recipes
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor > New Query)

-- ============================================================================
-- Table: recipes_cache
-- Purpose: Cache extracted recipes by source URL to avoid repeat API calls
-- ============================================================================

CREATE TABLE IF NOT EXISTS recipes_cache (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Source identification
    source_url TEXT NOT NULL UNIQUE,  -- The original URL (YouTube, web recipe, etc.)
    platform TEXT,                    -- 'youtube', 'web', 'tiktok', 'instagram', 'pinterest'
    video_id TEXT,                    -- For YouTube videos (optional, for faster lookups)
    
    -- Recipe data (stored as JSONB for flexibility)
    recipe_data JSONB NOT NULL,       -- Full recipe JSON: title, ingredients, instructions, etc.
    
    -- Metadata
    extracted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    cached_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    tier_used TEXT,                   -- Which extraction tier succeeded: 'deterministic', 'ai_description', 'ai_transcript', 'spoonacular', 'json_ld', etc.
    quality_score DOUBLE PRECISION,   -- Recipe quality score (0.0 to 1.0)
    
    -- Cache management
    hit_count INTEGER DEFAULT 0,      -- How many times this cache was used
    last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- Indexes for fast lookups
-- ============================================================================

-- Index for looking up by source URL (most common query)
CREATE INDEX IF NOT EXISTS idx_recipes_cache_source_url ON recipes_cache(source_url);

-- Index for looking up YouTube videos by video ID
CREATE INDEX IF NOT EXISTS idx_recipes_cache_video_id ON recipes_cache(video_id) WHERE video_id IS NOT NULL;

-- Index for platform-based queries
CREATE INDEX IF NOT EXISTS idx_recipes_cache_platform ON recipes_cache(platform);

-- Index for cache cleanup (old entries)
CREATE INDEX IF NOT EXISTS idx_recipes_cache_cached_at ON recipes_cache(cached_at);

-- ============================================================================
-- Table: extraction_logs (Optional - for debugging and analytics)
-- Purpose: Log all extraction attempts (successful and failed)
-- ============================================================================

CREATE TABLE IF NOT EXISTS extraction_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Request info
    source_url TEXT NOT NULL,
    platform TEXT,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Result info
    success BOOLEAN DEFAULT FALSE,
    tier_used TEXT,
    quality_score DOUBLE PRECISION,
    error_message TEXT,
    
    -- Performance
    extraction_time_ms INTEGER,       -- How long extraction took in milliseconds
    
    -- Cache info
    cache_hit BOOLEAN DEFAULT FALSE,  -- Was this served from cache?
    cache_id UUID REFERENCES recipes_cache(id) ON DELETE SET NULL
);

-- Index for analytics queries
CREATE INDEX IF NOT EXISTS idx_extraction_logs_requested_at ON extraction_logs(requested_at);
CREATE INDEX IF NOT EXISTS idx_extraction_logs_platform ON extraction_logs(platform);
CREATE INDEX IF NOT EXISTS idx_extraction_logs_success ON extraction_logs(success);

-- ============================================================================
-- Function: Update cache hit count and last accessed time
-- Purpose: Track cache usage automatically
-- ============================================================================

CREATE OR REPLACE FUNCTION update_cache_access()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE recipes_cache
    SET 
        hit_count = hit_count + 1,
        last_accessed_at = NOW()
    WHERE id = NEW.cache_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Automatically update cache stats when log entry is created
CREATE TRIGGER trigger_update_cache_access
    AFTER INSERT ON extraction_logs
    FOR EACH ROW
    WHEN (NEW.cache_hit = TRUE AND NEW.cache_id IS NOT NULL)
    EXECUTE FUNCTION update_cache_access();

-- ============================================================================
-- Row Level Security (RLS) Policies
-- Purpose: Control who can read/write cached recipes
-- ============================================================================

-- Enable RLS on tables
ALTER TABLE recipes_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE extraction_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read cached recipes (public read access)
CREATE POLICY "Public read access for recipes_cache"
    ON recipes_cache
    FOR SELECT
    USING (true);

-- Policy: Only authenticated users can insert/update (for now, we'll use service_role key)
-- For public access, we'll use service_role key in Edge Functions
CREATE POLICY "Service role can manage recipes_cache"
    ON recipes_cache
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Policy: Public read access for logs (for analytics)
CREATE POLICY "Public read access for extraction_logs"
    ON extraction_logs
    FOR SELECT
    USING (true);

-- Policy: Service role can insert logs
CREATE POLICY "Service role can insert extraction_logs"
    ON extraction_logs
    FOR INSERT
    WITH CHECK (true);

-- ============================================================================
-- Helper Function: Get cached recipe by URL
-- Purpose: Easy lookup function for Edge Functions
-- ============================================================================

CREATE OR REPLACE FUNCTION get_cached_recipe(p_source_url TEXT)
RETURNS TABLE (
    id UUID,
    recipe_data JSONB,
    tier_used TEXT,
    quality_score DOUBLE PRECISION,
    cached_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rc.id,
        rc.recipe_data,
        rc.tier_used,
        rc.quality_score,
        rc.cached_at
    FROM recipes_cache rc
    WHERE rc.source_url = p_source_url
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Helper Function: Save recipe to cache
-- Purpose: Easy insert/update function for Edge Functions
-- ============================================================================

CREATE OR REPLACE FUNCTION save_recipe_to_cache(
    p_source_url TEXT,
    p_platform TEXT,
    p_video_id TEXT,
    p_recipe_data JSONB,
    p_tier_used TEXT,
    p_quality_score DOUBLE PRECISION
)
RETURNS UUID AS $$
DECLARE
    v_cache_id UUID;
BEGIN
    INSERT INTO recipes_cache (
        source_url,
        platform,
        video_id,
        recipe_data,
        tier_used,
        quality_score,
        cached_at
    )
    VALUES (
        p_source_url,
        p_platform,
        p_video_id,
        p_recipe_data,
        p_tier_used,
        p_quality_score,
        NOW()
    )
    ON CONFLICT (source_url) 
    DO UPDATE SET
        recipe_data = EXCLUDED.recipe_data,
        tier_used = EXCLUDED.tier_used,
        quality_score = EXCLUDED.quality_score,
        cached_at = NOW()
    RETURNING id INTO v_cache_id;
    
    RETURN v_cache_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Cleanup: Optional function to remove old cache entries
-- Purpose: Keep database size manageable
-- ============================================================================

CREATE OR REPLACE FUNCTION cleanup_old_cache(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM recipes_cache
    WHERE cached_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND hit_count = 0;  -- Only delete entries that were never used
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Done! Your database is ready for recipe caching.
-- ============================================================================

-- To test, run:
-- SELECT get_cached_recipe('https://www.youtube.com/watch?v=test123');
-- 
-- To save a recipe:
-- SELECT save_recipe_to_cache(
--     'https://www.youtube.com/watch?v=test123',
--     'youtube',
--     'test123',
--     '{"title": "Test Recipe", "ingredients": ["flour", "eggs"]}'::jsonb,
--     'deterministic',
--     0.85
-- );

