# YouTube & TikTok Extraction Architecture - Technical Summary

## Document Purpose
This document provides a technical overview of the current YouTube recipe extraction system and recommendations for adding TikTok extraction support. It is intended for AI evaluation to understand the architecture and propose implementation strategies.

---

## Current YouTube Extraction Architecture

### 1. System Overview

The YouTube extraction system uses a **multi-tier fallback architecture** that progressively attempts more sophisticated extraction methods when simpler ones fail. The system is designed to maximize success rate while minimizing API costs.

**Key Components:**
- **iOS Share Extension** → Detects YouTube URLs and routes to extraction service
- **Supabase Edge Function** → Provides caching layer and routes to Lambda
- **AWS Lambda Function** → Performs actual recipe extraction using multi-tier system
- **Google YouTube Data API v3** → Provides video metadata and captions
- **OpenAI GPT-4** → AI-powered extraction and generation

### 2. Data Flow

```
iOS Share Extension
    ↓ (detects YouTube URL)
YouTubeExtractor.swift
    ↓ (extracts video ID, calls Supabase Edge Function)
Supabase Edge Function (extract-recipe)
    ↓ (checks cache, if miss → calls Lambda)
AWS Lambda Function
    ↓ (runs multi-tier extraction)
YouTube Data API v3 + OpenAI GPT-4
    ↓ (returns recipe data)
Supabase Cache (stores result)
    ↓ (returns to iOS)
Recipe Preview Display
```

### 3. Multi-Tier Extraction System

The Lambda function implements a **6-tier progressive extraction system**:

#### **Tier 1: Deterministic Parsing**
- **Method:** Regex-based pattern matching on video description
- **Input:** Video title + description (from YouTube Data API)
- **Logic:** Searches for structured sections like "INGREDIENTS:", "METHOD:", numbered lists
- **Success Criteria:** ≥2 ingredients AND ≥2 instructions (strict validation)
- **Cost:** Free (no API calls)
- **Speed:** Fastest (~100-500ms)
- **Quality:** Highest when description is well-formatted

#### **Tier 2: AI Description Parsing**
- **Method:** OpenAI GPT-4 extracts recipe from description text
- **Input:** Video title + description (from YouTube Data API)
- **Model:** GPT-4o-mini with JSON response format
- **Success Criteria:** ≥2 ingredients OR ≥2 instructions (relaxed validation)
- **Cost:** ~$0.001-0.01 per extraction
- **Speed:** Medium (~1-3 seconds)
- **Quality:** High when description contains recipe info

#### **Tier 2.5: AI Instruction Generation (from Ingredients)**
- **Method:** OpenAI GPT-4 generates instructions when Tier 2 extracts ingredients but no instructions
- **Input:** Title + ingredients list (from Tier 2)
- **Purpose:** Fill missing instructions when ingredients are available
- **Success Criteria:** ≥3 generated instructions
- **Cost:** ~$0.001 per extraction
- **Quality:** Good (AI-generated, context-aware)

#### **Tier 2.6: AI Recipe Generation (from Title Only)**
- **Method:** OpenAI GPT-4 generates complete recipe from video title
- **Input:** Video title only
- **Purpose:** Fallback when description is empty or doesn't contain recipe
- **Success Criteria:** ≥3 ingredients AND ≥3 instructions
- **Cost:** ~$0.001-0.002 per extraction
- **Quality:** Moderate (generic recipe based on dish name)

#### **Tier 3: AI Transcript Parsing**
- **Method:** OpenAI GPT-4 extracts recipe from video transcript/captions
- **Input:** Video title + transcript (from YouTube Data API captions)
- **Authentication:** OAuth 2.0 (required for captions.download endpoint)
- **Success Criteria:** ≥2 ingredients OR ≥2 instructions (relaxed validation)
- **Cost:** ~$0.01-0.05 per extraction (longer prompts)
- **Speed:** Slowest (~3-8 seconds, includes transcript fetch)
- **Quality:** Highest when video has spoken instructions

#### **Tier 4: AI Instruction Generation (from Transcript)**
- **Method:** OpenAI GPT-4 generates instructions from transcript when Tier 3 extracts ingredients but no instructions
- **Input:** Title + transcript + ingredients list (from Tier 3)
- **Purpose:** Fill missing instructions using full video transcript context
- **Success Criteria:** ≥2 generated instructions
- **Cost:** ~$0.002-0.01 per extraction
- **Quality:** Excellent (uses full video context)

#### **Hybrid Merging**
- **Method:** Combines best data from Tier 2 and Tier 3
- **Logic:** Merges Tier 2 ingredients + Tier 3 instructions (or vice versa)
- **Purpose:** Maximize data completeness when tiers have complementary data
- **Quality:** High (best of both tiers)

#### **Final Fallback**
- **Method:** Returns best partial result from any tier
- **Logic:** Accepts minimal data (≥1 ingredient OR ≥1 instruction)
- **Purpose:** Provide something rather than complete failure
- **Quality:** Low but functional

### 4. Authentication & APIs

#### **YouTube Data API v3**
- **Endpoints Used:**
  - `videos.list` (part=snippet) → Video metadata (title, description, thumbnail)
  - `captions.list` → List available captions
  - `captions.download` → Download transcript (requires OAuth 2.0)
- **Authentication:**
  - **Metadata:** API Key (simple, quota-limited)
  - **Captions:** OAuth 2.0 with refresh token (required for captions.download)
- **OAuth Setup:**
  - Client ID/Secret from Google Cloud Console
  - Refresh token obtained via OAuth Playground or desktop app flow
  - Stored in Lambda environment variables

#### **OpenAI API**
- **Model:** GPT-4o-mini (cost-effective, fast)
- **Response Format:** JSON object (structured output)
- **Usage:** Multiple calls per extraction (Tier 2, 2.5, 2.6, 3, 4)
- **Authentication:** API key in Lambda environment variables

### 5. Caching Strategy

#### **Supabase Cache Layer**
- **Storage:** PostgreSQL database table (`recipe_cache`)
- **Key:** Source URL (video URL)
- **TTL:** No expiration (manual cache invalidation)
- **Benefits:**
  - Instant response for previously extracted videos
  - Reduces Lambda invocations (cost savings)
  - Reduces API quota usage
- **Cache Check:** First step in Supabase Edge Function
- **Cache Save:** After successful Lambda extraction

### 6. Error Handling

#### **Error Types:**
- **Invalid URL:** Malformed YouTube URL
- **Video Not Found:** Video ID doesn't exist
- **Quota Exceeded:** YouTube API quota limit reached
- **Not a Recipe:** Video doesn't contain recipe content
- **Empty Description:** Description too short (common with Shorts)
- **Transcript Unavailable:** No captions available for video
- **API Errors:** OpenAI/YouTube API failures

#### **Fallback Strategy:**
- Each tier failure is logged but doesn't stop extraction
- System continues to next tier automatically
- Final fallback returns best partial result
- Detailed error messages include tier failure reasons

### 7. Code Structure

#### **iOS Layer (Swift)**
- **`YouTubeExtractor.swift`:** Video ID extraction, Lambda communication
- **`RecipeBrowserService.swift`:** URL detection, routing logic
- **Location:** `LongevityFoodLabShareExtension/`

#### **Lambda Layer (Python)**
- **`lambda_function.py`:** Main extraction logic (5,634 lines)
- **Functions:**
  - `is_youtube_url()` → URL detection
  - `extract_youtube_video_id()` → Video ID extraction
  - `fetch_youtube_metadata()` → Get title/description/thumbnail
  - `fetch_youtube_transcript()` → Get captions (OAuth)
  - `parse_youtube_recipe_deterministic()` → Tier 1
  - `parse_youtube_recipe_ai_description()` → Tier 2
  - `parse_youtube_recipe_ai_transcript()` → Tier 3
  - `generate_instructions_from_ingredients()` → Tier 2.5
  - `generate_recipe_from_title()` → Tier 2.6
  - `generate_instructions_from_transcript()` → Tier 4
  - `extract_youtube_recipe()` → Main orchestrator
- **Location:** `lambda-final-build/lambda_function.py`

#### **Supabase Layer (TypeScript)**
- **`index.ts`:** Edge Function for caching and routing
- **Functions:**
  - `detectPlatform()` → Platform detection (YouTube, TikTok, etc.)
  - `extractVideoId()` → Video ID extraction
  - Cache check/save logic
- **Location:** `supabase/functions/extract-recipe/index.ts`

---

## TikTok Extraction - Recommended Architecture

### 1. Platform Differences

#### **Key Differences from YouTube:**
- **No Official API:** TikTok has no public API for video metadata or transcripts
- **Shorter Videos:** Typically 15-60 seconds (vs YouTube's longer format)
- **Mobile-First:** Content optimized for mobile viewing
- **Limited Metadata:** Descriptions are shorter, less structured
- **No Captions API:** No official way to get transcripts
- **Rate Limiting:** Aggressive anti-scraping measures

### 2. Recommended Extraction Strategy

#### **Tier 1: HTML Scraping (Metadata)**
- **Method:** Scrape TikTok video page HTML for metadata
- **Data Available:**
  - Video title (from `<title>` tag or Open Graph)
  - Video description (from meta tags or page content)
  - Thumbnail image (from Open Graph image)
  - Creator name
- **Challenges:**
  - TikTok uses dynamic JavaScript rendering (requires headless browser)
  - Anti-bot measures (CAPTCHA, rate limiting)
  - HTML structure changes frequently
- **Implementation:**
  - Use headless browser (Puppeteer/Playwright) in Lambda
  - Or use third-party TikTok API services (unofficial)
  - Or scrape via mobile user agent (less likely to trigger bot detection)

#### **Tier 2: AI Description Parsing**
- **Method:** Same as YouTube Tier 2 (OpenAI GPT-4)
- **Input:** Video title + description (from Tier 1)
- **Success Rate:** Lower than YouTube (shorter descriptions)
- **Implementation:** Reuse YouTube Tier 2 logic

#### **Tier 2.5: AI Instruction Generation**
- **Method:** Same as YouTube Tier 2.5
- **Input:** Title + ingredients (from Tier 2)
- **Implementation:** Reuse YouTube Tier 2.5 logic

#### **Tier 2.6: AI Recipe Generation (from Title)**
- **Method:** Same as YouTube Tier 2.6
- **Input:** Video title only
- **Success Rate:** Higher for TikTok (titles often descriptive)
- **Implementation:** Reuse YouTube Tier 2.6 logic

#### **Tier 3: Audio Transcription (NEW)**
- **Method:** Download video, extract audio, transcribe with Whisper
- **Challenges:**
  - Video download requires authentication/API access
  - Audio extraction and transcription adds latency
  - Storage requirements for video files
- **Alternatives:**
  - Use third-party TikTok transcript services
  - Use browser automation to extract captions if available
  - Use Whisper API (OpenAI) for transcription
- **Implementation:**
  - Download video → Extract audio → Transcribe → Parse with GPT-4
  - Or use pre-existing transcript if available via scraping

#### **Tier 4: AI Instruction Generation (from Transcript)**
- **Method:** Same as YouTube Tier 4
- **Input:** Title + transcript + ingredients
- **Implementation:** Reuse YouTube Tier 4 logic

### 3. Recommended Code Structure

#### **Option A: Unified Platform Handler (Recommended)**
Create a unified video platform extraction system that handles both YouTube and TikTok:

```
lambda_function.py
├── Platform Detection
│   ├── is_youtube_url()
│   ├── is_tiktok_url()
│   └── extract_video_id() [platform-aware]
│
├── Metadata Fetching
│   ├── fetch_youtube_metadata() [existing]
│   └── fetch_tiktok_metadata() [NEW - HTML scraping]
│
├── Transcript Fetching
│   ├── fetch_youtube_transcript() [existing - OAuth]
│   └── fetch_tiktok_transcript() [NEW - audio transcription or scraping]
│
├── Extraction Tiers (Platform-Agnostic)
│   ├── Tier 1: Deterministic parsing [reuse]
│   ├── Tier 2: AI description [reuse]
│   ├── Tier 2.5: AI instruction generation [reuse]
│   ├── Tier 2.6: AI recipe generation [reuse]
│   ├── Tier 3: AI transcript parsing [reuse]
│   └── Tier 4: AI instruction generation [reuse]
│
└── Main Orchestrator
    ├── extract_youtube_recipe() [existing]
    └── extract_tiktok_recipe() [NEW - similar structure]
```

#### **Option B: Separate Extractors (Alternative)**
Create separate extractor classes for each platform:

```
lambda_function.py
├── YouTubeExtractor
│   └── extract_recipe() [existing]
│
├── TikTokExtractor
│   ├── fetch_metadata()
│   ├── fetch_transcript()
│   └── extract_recipe()
│
└── UnifiedTierSystem
    └── [Shared tier logic]
```

**Recommendation:** Option A (Unified Handler) - easier to maintain, shared tier logic, consistent error handling.

### 4. Implementation Steps

#### **Phase 1: Basic TikTok Support**
1. **URL Detection:**
   - Add `is_tiktok_url()` function
   - Update `detectPlatform()` in Supabase Edge Function
   - Update iOS `RecipeBrowserService` to detect TikTok URLs

2. **Metadata Fetching:**
   - Implement `fetch_tiktok_metadata()` using HTML scraping
   - Extract title, description, thumbnail from TikTok page
   - Handle anti-bot measures (user agents, delays)

3. **Basic Extraction:**
   - Route TikTok URLs to extraction function
   - Use Tier 2 (AI description) and Tier 2.6 (title generation)
   - Skip transcript tiers initially (Tier 3/4)

#### **Phase 2: Transcript Support**
1. **Transcript Fetching:**
   - Research TikTok transcript availability (on-page captions, API services)
   - Implement `fetch_tiktok_transcript()` using best available method
   - Fallback to audio transcription if needed

2. **Full Tier Support:**
   - Enable Tier 3 (transcript parsing) for TikTok
   - Enable Tier 4 (instruction generation) for TikTok

#### **Phase 3: Optimization**
1. **Caching:**
   - Ensure TikTok URLs are cached in Supabase
   - Add platform-specific cache keys if needed

2. **Error Handling:**
   - Add TikTok-specific error types
   - Handle rate limiting and anti-bot measures

3. **Performance:**
   - Optimize HTML scraping (use headless browser efficiently)
   - Cache metadata when possible
   - Minimize API calls

### 5. Technical Challenges & Solutions

#### **Challenge 1: No Official API**
- **Solution:** HTML scraping with headless browser (Puppeteer/Playwright)
- **Alternative:** Third-party TikTok API services (unofficial, may violate ToS)

#### **Challenge 2: Anti-Bot Measures**
- **Solution:**
  - Use mobile user agent strings
  - Implement delays between requests
  - Rotate IP addresses (if using proxy service)
  - Use CAPTCHA solving services if needed

#### **Challenge 3: Dynamic Content**
- **Solution:** Headless browser with JavaScript execution
- **Tools:** Puppeteer (Chrome), Playwright (multi-browser)

#### **Challenge 4: Video Download/Transcription**
- **Solution Options:**
  1. Scrape on-page captions if available
  2. Use third-party transcript services
  3. Download video → Extract audio → Transcribe with Whisper
  4. Skip transcript tiers for TikTok (use only description/title)

#### **Challenge 5: Rate Limiting**
- **Solution:**
  - Implement exponential backoff
  - Use caching aggressively
  - Consider using multiple accounts/IPs
  - Monitor rate limit headers

### 6. Code Reusability Opportunities

#### **High Reusability (90%+):**
- Tier 2: AI description parsing (identical logic)
- Tier 2.5: AI instruction generation (identical logic)
- Tier 2.6: AI recipe generation (identical logic)
- Tier 3: AI transcript parsing (identical logic, different input)
- Tier 4: AI instruction generation (identical logic)
- Validation functions
- Error handling patterns

#### **Medium Reusability (50-90%):**
- Tier 1: Deterministic parsing (needs TikTok-specific patterns)
- Main orchestrator function (similar structure, different metadata fetch)

#### **New Code Required:**
- TikTok URL detection
- TikTok metadata fetching (HTML scraping)
- TikTok transcript fetching (audio transcription or scraping)
- TikTok-specific error types

### 7. Recommended File Structure

```
lambda-final-build/
├── lambda_function.py
│   ├── Platform Detection (YouTube + TikTok)
│   ├── YouTube Metadata Fetching
│   ├── TikTok Metadata Fetching [NEW]
│   ├── YouTube Transcript Fetching
│   ├── TikTok Transcript Fetching [NEW]
│   ├── Shared Tier Functions (Tier 1-4)
│   ├── extract_youtube_recipe() [existing]
│   └── extract_tiktok_recipe() [NEW]
│
└── requirements-lambda.txt
    ├── [existing dependencies]
    └── playwright or puppeteer [NEW - for HTML scraping]
```

### 8. Performance Considerations

#### **Latency:**
- **YouTube:** 1-8 seconds (depending on tier)
- **TikTok (estimated):**
  - Tier 1-2: 2-5 seconds (HTML scraping adds latency)
  - Tier 3-4: 10-30 seconds (if audio transcription needed)

#### **Cost:**
- **YouTube:** ~$0.001-0.05 per extraction (mostly OpenAI)
- **TikTok (estimated):**
  - Tier 1-2: ~$0.001-0.01 per extraction (OpenAI)
  - Tier 3-4: ~$0.01-0.10 per extraction (if Whisper transcription needed)

#### **Caching Impact:**
- Both platforms benefit significantly from caching
- TikTok may need more aggressive caching due to scraping costs

### 9. Testing Strategy

#### **Test Cases:**
1. **URL Detection:** Various TikTok URL formats
2. **Metadata Fetching:** Successful scrape, anti-bot handling, rate limiting
3. **Tier 1:** TikTok description parsing (if structured)
4. **Tier 2:** AI description extraction
5. **Tier 2.6:** Title-based generation (likely high success rate)
6. **Tier 3:** Transcript extraction/transcription
7. **Error Handling:** Invalid URLs, private videos, deleted videos

### 10. Migration Path

#### **Step 1: Add TikTok Detection**
- Update `is_youtube_url()` → `is_video_platform_url()` (returns platform type)
- Update iOS routing logic
- Update Supabase Edge Function platform detection

#### **Step 2: Implement Basic TikTok Extraction**
- Add `fetch_tiktok_metadata()` (HTML scraping)
- Create `extract_tiktok_recipe()` (use Tiers 2, 2.5, 2.6 initially)
- Test with real TikTok recipe videos

#### **Step 3: Add Transcript Support**
- Implement `fetch_tiktok_transcript()` (choose best method)
- Enable Tiers 3 and 4 for TikTok
- Test full extraction pipeline

#### **Step 4: Optimize & Polish**
- Improve error handling
- Optimize scraping performance
- Add monitoring/logging
- Update documentation

---

## Summary & Recommendations

### **Current System Strengths:**
- ✅ Robust multi-tier fallback system
- ✅ Excellent code reusability for AI tiers
- ✅ Effective caching strategy
- ✅ Comprehensive error handling
- ✅ Proven success with YouTube

### **TikTok Integration Advantages:**
- ✅ Can reuse 80%+ of existing tier logic
- ✅ Similar data structure (title, description, transcript)
- ✅ Same AI models work well for TikTok content
- ✅ Caching strategy applies directly

### **TikTok Integration Challenges:**
- ⚠️ No official API (requires scraping)
- ⚠️ Anti-bot measures (need careful handling)
- ⚠️ Shorter content (may need more AI generation)
- ⚠️ Transcript access more difficult

### **Recommended Approach:**
1. **Start with Unified Platform Handler** (Option A)
2. **Implement Phase 1 first** (basic TikTok support without transcripts)
3. **Add transcript support later** (Phase 2) after validating basic flow
4. **Reuse all AI tier logic** (Tiers 2, 2.5, 2.6, 3, 4)
5. **Focus on metadata fetching** (biggest new code requirement)

### **Estimated Implementation Effort:**
- **Phase 1 (Basic):** 2-3 days
  - URL detection: 1 hour
  - Metadata fetching: 1-2 days (HTML scraping)
  - Integration: 4-6 hours
- **Phase 2 (Transcripts):** 2-3 days
  - Transcript fetching: 1-2 days
  - Full tier integration: 1 day
- **Total:** ~1 week for complete TikTok support

---

## Conclusion

The current YouTube extraction architecture is well-designed and highly reusable. Adding TikTok support requires primarily:
1. New metadata fetching (HTML scraping instead of API)
2. New transcript fetching (audio transcription or scraping)
3. Platform detection and routing updates

The multi-tier AI extraction system can be reused almost entirely, making TikTok integration a relatively straightforward extension of the existing architecture.


