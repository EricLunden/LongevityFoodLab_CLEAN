// Supabase Edge Function: Recipe Extraction with Caching
// This function checks cache first, then calls Lambda if needed

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const LAMBDA_URL = Deno.env.get('LAMBDA_URL') || 'https://75gu2r32syfuqogbcn7nugmfm40oywqn.lambda-url.us-east-2.on.aws/'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // Initialize Supabase client with service role key (bypasses RLS)
    // SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are automatically provided by Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || Deno.env.get('SUPABASE_PROJECT_URL') || ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    
    if (!supabaseUrl || !supabaseKey) {
      console.error('Missing Supabase configuration')
      return new Response(
        JSON.stringify({ error: 'Server configuration error' }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        }
      )
    }
    
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Parse request body
    const { url, html } = await req.json()
    
    if (!url) {
      return new Response(
        JSON.stringify({ error: 'URL is required' }),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
        }
      )
    }

    const startTime = Date.now()

    // Step 1: Check cache first
    console.log(`Checking cache for: ${url}`)
    const { data: cachedRecipe, error: cacheError } = await supabase
      .rpc('get_cached_recipe', { p_source_url: url })

    if (cachedRecipe && cachedRecipe.length > 0) {
      console.log('Cache hit! Returning cached recipe')
      
      // Log cache hit
      await supabase.from('extraction_logs').insert({
        source_url: url,
        platform: detectPlatform(url),
        requested_at: new Date().toISOString(),
        success: true,
        tier_used: cachedRecipe[0].tier_used,
        quality_score: cachedRecipe[0].quality_score,
        extraction_time_ms: Date.now() - startTime,
        cache_hit: true,
        cache_id: cachedRecipe[0].id
      })

      // Return cached recipe
      return new Response(
        JSON.stringify({
          ...cachedRecipe[0].recipe_data,
          cached: true,
          cache_age_ms: Date.now() - new Date(cachedRecipe[0].cached_at).getTime()
        }),
        {
          status: 200,
          headers: { 
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        }
      )
    }

    // Step 2: Cache miss - call Lambda
    console.log('Cache miss. Calling Lambda...')
    // Use AbortController for timeout (Supabase Edge Functions have 60s default timeout)
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 85000) // 85 seconds (less than 90s Lambda timeout)
    
    try {
    const lambdaResponse = await fetch(LAMBDA_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ url, html: html || '' }),
        signal: controller.signal,
    })
      
      clearTimeout(timeoutId)

    if (!lambdaResponse.ok) {
      throw new Error(`Lambda error: ${lambdaResponse.status}`)
    }

    const recipeData = await lambdaResponse.json()

    // Check if Lambda returned an error
    if (recipeData.error) {
      // Log failed extraction
      await supabase.from('extraction_logs').insert({
        source_url: url,
        platform: detectPlatform(url),
        requested_at: new Date().toISOString(),
        success: false,
        error_message: recipeData.error,
        extraction_time_ms: Date.now() - startTime,
        cache_hit: false
      })

      return new Response(
        JSON.stringify(recipeData),
        {
          status: 200, // Lambda returns 200 with error in body
          headers: { 
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        }
      )
    }

    // Step 3: Save to cache
    console.log('Saving recipe to cache...')
    const platform = detectPlatform(url)
    const videoId = extractVideoId(url)
    
    const { data: cacheId, error: saveError } = await supabase
      .rpc('save_recipe_to_cache', {
        p_source_url: url,
        p_platform: platform,
        p_video_id: videoId,
        p_recipe_data: recipeData,
        p_tier_used: recipeData.metadata?.tier_used || 'unknown',
        p_quality_score: recipeData.quality_score || 0.0
      })

    if (saveError) {
      console.error('Error saving to cache:', saveError)
      // Continue anyway - return recipe even if cache save fails
    }

    // Log successful extraction
    await supabase.from('extraction_logs').insert({
      source_url: url,
      platform: platform,
      requested_at: new Date().toISOString(),
      success: true,
      tier_used: recipeData.metadata?.tier_used || 'unknown',
      quality_score: recipeData.quality_score || 0.0,
      extraction_time_ms: Date.now() - startTime,
      cache_hit: false,
      cache_id: cacheId || null
    })

    // Return recipe
    return new Response(
      JSON.stringify({
        ...recipeData,
        cached: false
      }),
      {
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Internal server error',
        cached: false
      }),
      {
        status: 500,
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )
  }
})

// Helper: Detect platform from URL
function detectPlatform(url: string): string {
  if (url.includes('youtube.com') || url.includes('youtu.be')) return 'youtube'
  if (url.includes('tiktok.com')) return 'tiktok'
  if (url.includes('instagram.com')) return 'instagram'
  if (url.includes('pinterest.com')) return 'pinterest'
  return 'web'
}

// Helper: Extract video ID (YouTube or TikTok)
function extractVideoId(url: string): string | null {
  // YouTube patterns
  const youtubePatterns = [
    /youtube\.com\/watch\?v=([a-zA-Z0-9_-]{11})/,
    /youtu\.be\/([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/shorts\/([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/
  ]
  
  for (const pattern of youtubePatterns) {
    const match = url.match(pattern)
    if (match) return match[1]
  }
  
  // TikTok patterns
  const tiktokPatterns = [
    /tiktok\.com\/@[\w.-]+\/video\/(\d+)/,
    /tiktok\.com\/v\/(\d+)/,
    /vm\.tiktok\.com\/(\w+)/,
    /t\.tiktok\.com\/(\w+)/
  ]
  
  for (const pattern of tiktokPatterns) {
    const match = url.match(pattern)
    if (match) return match[1]
  }
  
  return null
}

