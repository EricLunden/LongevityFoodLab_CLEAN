# YouTube & TikTok Extraction Logic Comparison Report
## Version 16 (Oct 22, 2024) vs Current Version (Dec 29, 2025)

### File Size Comparison
- Version 16: 899 lines
- Current Version: 6,376 lines
- Difference: +5,477 lines (608% increase)

### YouTube Extraction

#### Version 16
- ❌ **NO YouTube extraction functionality**
- Only handles web recipe URLs
- No YouTube URL detection
- No YouTube API integration
- No video metadata fetching
- No transcript extraction

#### Current Version
- ✅ **Full YouTube extraction with 6-tier system**
- YouTube URL detection: `is_youtube_url()`
- Video ID extraction: `extract_youtube_video_id()`
- Metadata fetching: `fetch_youtube_metadata()` (YouTube API)
- Transcript fetching: `fetch_youtube_transcript()`
- **Tier 1:** Deterministic parsing from description
- **Tier 2:** OpenAI GPT-4 description parsing
- **Tier 2.5:** Instruction generation from ingredients
- **Tier 2.6:** Title-based recipe generation
- **Tier 3:** OpenAI GPT-4 transcript parsing
- **Tier 4:** Instruction generation from transcript
- **Hybrid merging:** Combines Tier 2 ingredients + Tier 3 instructions
- **Final fallback:** Uses best partial result

### TikTok Extraction

#### Version 16
- ❌ **NO TikTok extraction functionality**
- No TikTok URL detection
- No Apify integration
- No TikTok metadata fetching

#### Current Version
- ✅ **Full TikTok extraction with multi-tier system**
- TikTok URL detection: `is_tiktok_url()`
- Video ID extraction: `extract_tiktok_video_id()`
- Metadata fetching: `fetch_tiktok_metadata()` (Apify API)
- **Tier 1:** Deterministic parsing (reuses YouTube function)
- **Tier 2:** OpenAI GPT-4 description parsing (reuses YouTube function)
- **Tier 2.5:** Instruction generation (reuses YouTube function)
- **Tier 2.6:** Title-based generation (reuses YouTube function)
- **Final fallback:** Uses best partial result

### Lambda Handler Routing

#### Version 16
- Processes ALL URLs as web recipes
- No special routing for YouTube/TikTok
- Flow: URL → HTML fetch → BeautifulSoup parsing → Spoonacular → AI fallback

#### Current Version
- **YouTube URL routing:** Detects YouTube URLs FIRST, before web processing
- **TikTok URL routing:** Detects TikTok URLs SECOND, before web processing
- **Web URL routing:** Falls through to web recipe extraction
- Flow: URL → Check YouTube → Check TikTok → Web extraction

### Key Functions Added in Current Version

**YouTube Functions:**
- `is_youtube_url(url: str) -> bool`
- `extract_youtube_video_id(url: str) -> str`
- `fetch_youtube_metadata(video_id: str) -> Dict[str, Any]`
- `fetch_youtube_transcript(video_id: str) -> str`
- `parse_youtube_recipe_deterministic(title, description) -> Dict`
- `parse_youtube_recipe_ai_description(title, description, thumbnail) -> Dict`
- `parse_youtube_recipe_ai_transcript(title, transcript, thumbnail) -> Dict`
- `generate_instructions_from_ingredients(title, ingredients) -> List[str]`
- `generate_instructions_from_transcript(title, transcript, ingredients) -> List[str]`
- `generate_recipe_from_title(title) -> Dict`
- `validate_youtube_result(result, tier_name, strict) -> Tuple[bool, str]`
- `extract_youtube_recipe(video_id, video_url) -> Dict[str, Any]`

**TikTok Functions:**
- `is_tiktok_url(url: str) -> bool`
- `extract_tiktok_video_id(url: str) -> str`
- `fetch_tiktok_metadata(video_id, url) -> Dict[str, Any]`
- `extract_tiktok_recipe(video_id, video_url) -> Dict[str, Any]`

### Dependencies Added

**Version 16:**
- `requests`
- `beautifulsoup4`
- Standard library only

**Current Version:**
- All Version 16 dependencies PLUS:
- `openai` (for GPT-4 API calls)
- YouTube API integration (via `requests`)
- Apify API integration (for TikTok)
- More complex error handling and retry logic

### Summary

**Version 16:** Web-only recipe extraction
- Simple 3-tier system: Deterministic → Spoonacular → AI fallback
- No video platform support
- No YouTube/TikTok capabilities

**Current Version:** Full video platform support
- Web recipe extraction (same as V16)
- YouTube extraction with 6-tier system
- TikTok extraction with multi-tier system
- Extensive error handling and fallback logic
- Hybrid merging capabilities
- Instruction generation from multiple sources

### Conclusion

Version 16 does NOT have YouTube or TikTok extraction. The current version added ALL video platform functionality. If YouTube/TikTok were working before, it means:
1. A different Lambda function was being used, OR
2. The functionality was added between Version 16 and the current version, OR
3. The code exists elsewhere (not in Version 16)

**Recommendation:** To restore YouTube/TikTok functionality, you need to use the current version (or a version between V16 and current that has the video extraction code), NOT Version 16.
