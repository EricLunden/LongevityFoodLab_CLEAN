# Recipe Parsing System Analysis - LFL Reboot October 20
**Date:** October 27, 2025  
**Target:** Achieve 90%+ investor-grade accuracy from current ~75%  
**Current Build:** LFL Reboot October 20 - GitHub commit `9871a4b`

---

## CURRENT ARCHITECTURE

### User Flow
```
User enters URL → WKWebView loads page → Extract HTML → POST to Lambda → Lambda parses → Returns JSON → Convert to Recipe → Save to disk
```

### Key Components

**iOS App Layer:**
- `RecipeBrowserService.swift` (Main App) - WKWebView-based HTML extraction
  - Location: `LongevityFoodLab/Services/RecipeBrowserService.swift`
  - Extracts HTML via `document.documentElement.outerHTML`
  - Sends to Lambda endpoint
  - Times out after 15 seconds
  - Includes comprehensive error handling

- `RecipeBrowserService.swift` (Share Extension)
  - Location: `LongevityFoodLabShareExtension/RecipeBrowserService.swift`
  - Two extraction methods:
    1. `extractRecipeWithHTML()` - Fetches HTML then sends to Lambda
    2. `extractRecipe()` - URL-only request to Lambda
  - Includes HTML fetching with User-Agent headers
  - Lambda endpoint: `https://75gu2r32syfuqogbcn7nugmfm40oywqn.lambda-url.us-east-2.on.aws/`

**Lambda Backend:**
- **Primary File**: `package/lambda_function.py` (main implementation)
- **Test File**: `lambda_function.py` (simple API key test)
- **HTTP Method**: POST
- **Payload**: `{"url": "...", "html": "..."}`
- **Output**: JSON with recipe data

**Data Models:**
- `ImportedRecipe.swift` - Temporary structure for imported recipes
- `Recipe.swift` (via RecipeManager) - Final stored recipe format
- `SpoonacularService.swift` - Direct Spoonacular API integration (currently unused in extraction flow)

---

## PARSING METHODS IN USE

### Method 1: Spoonacular API (Primary)
- **Implementation**: `extract_via_spoonacular()` in `package/lambda_function.py:913-1043`
- **Success Rate Estimate**: 60-70% (based on API limitations)
- **Works On**: 
  - AllRecipes.com (with ID extraction)
  - FoodNetwork.com (with ID extraction)
  - SeriousEats.com
  - BonAppetit.com
  - Generic sites (with URL analysis)
- **Fails On**: Sites not in Spoonacular database, behind paywalls, or blocked by anti-scraping

**Current Logic:**
1. Tries Spoonacular API first (line 52)
2. If successful and has both ingredients AND instructions, uses Spoonacular data
3. If partial (ingredients but no instructions), uses Spoonacular ingredients, tries HTML for instructions
4. Falls back to HTML parsing if Spoonacular fails

### Method 2: JSON-LD Structured Data
- **Implementation**: `extract_json_ld()` in `package/lambda_function.py:175-218`
- **Success Rate Estimate**: 70% coverage, but unreliable quality
- **Works On**: Sites that include `<script type="application/ld+json">` with Schema.org Recipe format
- **Fails On**: Sites without structured data, invalid JSON, or proprietary formats

### Method 3: AllRecipes-Specific Parser
- **Implementation**: `extract_allrecipes()` in `package/lambda_function.py:328-731`
- **Success Rate Estimate**: 50% (site structure changes frequently)
- **Works On**: Modern AllRecipes pages with `.mntl-structured-ingredients__list` classes
- **Fails On**: Older AllRecipes layouts, mobile-optimized pages, or modified DOM structure

**Key Selectors:**
- Ingredients: `ul.mntl-structured-ingredients__list li`
- Instructions: Aggressive selector list (line 403-433) with ingredient filtering
- Servings: Multiple selectors including `.mntl-recipe-details__value`

### Method 4: FoodNetwork Parser
- **Implementation**: `extract_foodnetwork()` in `package/lambda_function.py:734-758`
- **Success Rate Estimate**: 60% (basic implementation)
- **Works On**: FoodNetwork.com with specific class names
- **Fails On**: Updated FoodNetwork layouts, recipe video pages

### Method 5: Microdata Extraction
- **Implementation**: `extract_microdata()` in `package/lambda_function.py:297-326`
- **Success Rate Estimate**: 40% (rarely used)
- **Works On**: Sites using `itemtype="schema.org/Recipe"` format
- **Fails On**: Most modern sites (JSON-LD is preferred)

### Method 6: Generic Fallback
- **Implementation**: `extract_generic()` in `package/lambda_function.py:770-869`
- **Success Rate Estimate**: 30% (last resort)
- **Works On**: Sites with common Recipe schema patterns
- **Fails On**: Custom layouts, dynamically loaded content, recipe card plugins

---

## KNOWN ISSUES

### Code Comments / TODOs Found:
- **Line 42**: Extensive debug logging for HTML structure analysis
- **Line 395-400**: Debug logging for instruction finding (AllRecipes)
- **Line 451-498**: Ultra-aggressive ingredient filtering (complex regex patterns)

### Problems Identified:

1. **Spoonacular API Dependency**:
   - Hardcoded API key placeholder: `'YOUR_ACTUAL_API_KEY_HERE'` (line 917)
   - No validation that key is actually configured
   - Fails silently if API key is invalid
   - Rate limits not handled

2. **HTML Extraction Timing**:
   - `RecipeBrowserService` waits only 1 second after page load (line 282)
   - Many sites load content dynamically → extraction happens too early
   - No retry mechanism if extraction fails

3. **Instruction Extraction Issues** (AllRecipes):
   - Complex logic to filter out ingredients masquerading as instructions (line 451-498)
   - Still has false positives/negatives
   - Multiple selector attempts (line 403-433) suggests unreliability

4. **No Quality Validation**:
   - No check if extracted recipe has minimum required fields
   - No validation of data quality before returning to user
   - No confidence scoring

5. **Error Recovery**:
   - If Lambda fails, no local fallback extraction attempted
   - No retry logic
   - User sees "Import Failed - Please Enter Manually" with no context

6. **Site-Specific Logic Scattered**:
   - Domain checks throughout main parsing flow (line 77, 91, 99, 101, 103, 105)
   - Site-specific parsers only added for 4 sites
   - New sites require code changes to Lambda

7. **Server-Side Only**:
   - All parsing happens in Lambda
   - iOS app is just a client
   - No offline capability
   - Dependent on external service availability

8. **Missing Capabilities**:
   - No OpenGraph metadata parsing
   - No recipe card plugin detection (e.g., Jetpack Recipe Card, WP Recipe Maker)
   - No support for hRecipe microformat (older standard)
   - No client-side parsing as fallback

---

## MISSING CAPABILITIES

### Not Currently Implemented:

1. **OpenGraph Meta Tags Parser**
   - Many sites embed recipe metadata in `<meta property="og:*">` tags
   - Would provide title, image, description fallbacks

2. **Recipe Card Plugin Detection**
   - WordPress plugins like Jetpack Recipe Card, WP Recipe Maker, etc.
   - Common class/ID patterns that could be added

3. **Client-Side HTML Parsing**
   - Currently relies entirely on Lambda
   - If Lambda is down, entire extraction fails
   - Should have local HTML parsing as backup

4. **URL Pattern Recognition**
   - Could cache successful extraction methods per domain
   - Learn which sites work best with which parsing method

5. **Content Validation**
   - No minimum field requirements before returning recipe
   - No data quality checks
   - No "confidence score" for extracted data

6. **Aggressive Instruction Extraction**
   - Generic fallback tries multiple selectors but only returns first successful result
   - Should try all selectors and combine results

7. **Smart Deduplication**
   - Some sites have duplicate ingredients/instructions
   - Current deduplication is basic (line 229, 248)
   - Should handle near-duplicates (e.g., "1 cup flour" vs "1 cup all-purpose flour")

8. **Handling Complex HTML**
   - Instructions in nested divs/span structures
   - Ingredients in tables or flex layouts
   - No handling of `<br>` tags as line breaks in instructions

9. **Image Extraction**
   - Only basic image extraction (line 680-727)
   - Doesn't prefer high-resolution images
   - No OpenGraph image fallback

10. **Time Parsing**
    - Only ISO 8601 and text format supported (line 881-911)
    - Doesn't handle "1 hr 30 min" mixed formats well
    - No parsing of structured time data from Schema.org

---

## RECOMMENDED STAGED PLAN

### Stage 0: Testing & Preparation (DO NOT SKIP)
**Goal:** Establish baseline success rate and identify problem sites  
**Expected Improvement:** N/A (measuring only)  
**Risk Level:** Low  
**Time Estimate:** 1-2 hours  
**Files to Modify:** None (add testing harness)  
**Testing Approach:**
- Create test suite with 50 URLs from various sites
- Log success/failure for each
- Document which parsing method succeeded
- Create test report with success rate breakdown

**Rollback Plan:** No changes made, safe to skip if already have baseline

---

### Stage 1: Add OpenGraph Parser (High Impact, Low Risk)
**Goal:** Fill in missing titles/images for sites without structured data  
**Expected Improvement:** 75% → 78% (+3%)  
**Risk Level:** Low  
**Time Estimate:** 2-3 hours  
**Files to Modify:** `package/lambda_function.py`

**Implementation:**
- Add new function `extract_opengraph(soup, url)` 
- Extract: `og:title`, `og:image`, `og:description`
- Call after JSON-LD fails, before site-specific parsers
- Insert at line 110 (after microdata, before generic fallback)

**Testing Approach:**
- Test with sites known to have OG tags but no JSON-LD
- Verify images are extracted correctly
- Ensure no breaking changes to existing flows

**Rollback Plan:** Remove function call and delete function (1 line change)

---

### Stage 2: Implement Client-Side Parsing Fallback (Critical for Reliability)
**Goal:** If Lambda fails, try parsing HTML locally in iOS app  
**Expected Improvement:** 78% → 82% (+4%)  
**Risk Level:** Medium  
**Time Estimate:** 6-8 hours  
**Files to Modify:** 
- `LongevityFoodLab/Services/RecipeBrowserService.swift`
- New file: `LongevityFoodLab/Services/LocalRecipeParser.swift`

**Implementation:**
1. Extract HTML parsing logic from Lambda to iOS
2. Add local parser that tries same methods (JSON-LD, generic selectors)
3. In `RecipeBrowserService`, if Lambda fails, try local parsing
4. Use local parser as first attempt for faster response times

**Testing Approach:**
- Disable Lambda temporarily, verify local parsing works
- Compare results: local vs Lambda
- Measure performance difference

**Rollback Plan:** Remove local parser call, restore Lambda-only flow (2 line changes)

---

### Stage 3: Add Quality Scoring & Validation
**Goal:** Only return recipes that meet minimum quality standards  
**Expected Improvement:** 82% → 85% (+3% via better filtering)  
**Risk Level:** Low  
**Time Estimate:** 3-4 hours  
**Files to Modify:** `package/lambda_function.py`

**Implementation:**
1. Add `validate_recipe(recipe_data)` function
2. Requirements:
   - Title: 3+ characters, not empty
   - Ingredients: 3+ items, not placeholder text
   - Instructions: 2+ steps, meaningful content
3. Return confidence score (0-1) with recipe
4. If score < 0.5, trigger additional parsing attempts
5. Only return to iOS if score ≥ 0.6

**Testing Approach:**
- Test with known bad extractions
- Verify they're rejected or improved
- Track quality scores over time

**Rollback Plan:** Remove validation call, return to previous behavior (1 line change)

---

### Stage 4: Enhance Instruction Extraction for AllRecipes
**Goal:** Fix current ~50% success rate on AllRecipes instructions  
**Expected Improvement:** 85% → 87% (+2% overall)  
**Risk Level:** Medium  
**Time Estimate:** 4-6 hours  
**Files to Modify:** `package/lambda_function.py` (`extract_allrecipes`)

**Implementation:**
1. Add more instruction selectors based on current AllRecipes structure
2. Improve ingredient filtering logic (reduce false positives in instructions)
3. Add handling for numbered vs bulleted instruction lists
4. Extract metadata about recipe type (video vs written) and adjust extraction

**Testing Approach:**
- Test with 20 current AllRecipes URLs
- Compare before/after instruction extraction success rate
- Verify no regression in ingredient extraction

**Rollback Plan:** Revert selector changes (restore old selectors list)

---

### Stage 5: Add Recipe Card Plugin Detection
**Goal:** Support WordPress recipe plugins  
**Expected Improvement:** 87% → 89% (+2%)  
**Risk Level:** Low  
**Time Estimate:** 3-4 hours  
**Files to Modify:** `package/lambda_function.py`

**Implementation:**
1. Add new function `extract_recipe_plugins(soup)`
2. Detect patterns for:
   - Jetpack Recipe Card
   - WP Recipe Maker
   - Easy Recipe
   - Recipe Card Plugins
3. Extract from plugin-specific markup
4. Call before generic fallback (line 114)

**Testing Approach:**
- Find sites using these plugins
- Verify extraction succeeds
- Test with various plugin versions

**Rollback Plan:** Remove plugin detection call (1 line change)

---

### Stage 6: Improve Image Extraction & Servings/Time Parsing
**Goal:** Better metadata extraction  
**Expected Improvement:** 89% → 90% (+1%)  
**Risk Level:** Low  
**Time Estimate:** 3-4 hours  
**Files to Modify:** `package/lambda_function.py`

**Implementation:**
1. **Images**: Prefer high-res, OpenGraph images, avoid placeholders
2. **Servings**: Better pattern matching for "Serves 4-6" vs "4-6 servings"
3. **Time**: Parse "1 hr 30 min" mixed formats, better ISO 8601 handling
4. Add to all extraction methods consistently

**Testing Approach:**
- Test with sites providing varied image sizes
- Test with different time formats
- Verify servings extraction across sites

**Rollback Plan:** Revert extraction improvements to previous logic

---

### Stage 7: Add Retry Mechanism & Request Queueing
**Goal:** Improve reliability for transient failures  
**Expected Improvement:** 90% → 91% (+1%)  
**Risk Level:** Low  
**Time Estimate:** 4-5 hours  
**Files to Modify:** 
- `package/lambda_function.py`
- `LongevityFoodLab/Services/RecipeBrowserService.swift`

**Implementation:**
1. If parsing fails but HTML is valid, retry with different methods
2. Queue Lambda requests to avoid timeouts
3. Exponential backoff for Spoonacular API
4. Cache successful extraction methods per domain

**Testing Approach:**
- Simulate network failures
- Verify retries work correctly
- Test with high-load scenarios

**Rollback Plan:** Remove retry logic, restore immediate failure behavior

---

### Stage 8: Add More Site-Specific Parsers
**Goal:** Target top 5 failing sites  
**Expected Improvement:** 91% → 93% (+2%)  
**Risk Level:** Medium  
**Time Estimate:** 6-8 hours per site  
**Files to Modify:** `package/lambda_function.py`

**Implementation:**
Based on failing sites identified in Stage 0:
- Add parsers for top 5 problem sites
- Follow existing `extract_<sitename>()` pattern
- Extract: title, ingredients, instructions, servings, time, image

**Testing Approach:**
- Test with 10 URLs per site
- Verify >90% success rate per site
- Monitor for site layout changes

**Rollback Plan:** Remove site-specific parser, add to generic fallback blacklist

---

## SUMMARY

**Current Success Rate:** ~75%  
**Target Success Rate:** 90%+  
**Gap:** 15 percentage points

**Recommended Approach:**
- **Stages 0-2 (Critical)**: Must do first - establish baseline, add client-side fallback, quality validation
- **Stages 3-6 (High Value)**: Significant improvements for moderate effort
- **Stages 7-8 (Nice to Have)**: Fine-tuning and site-specific optimization

**Total Time Estimate:** 35-50 hours of focused development  
**Expected Final Success Rate:** 91-93% with all stages

**Priority Order:**
1. Stage 0: Testing (establish baseline)
2. Stage 1: OpenGraph parser (+3%)
3. Stage 2: Client-side fallback (+4%)
4. Stage 3: Quality validation (+3%)
5. Stage 4: AllRecipes fix (+2%)
6. Stage 5: Plugin detection (+2%)
7. Stage 6: Image/time parsing (+1%)
8. Stage 7: Retry mechanism (+1%)
9. Stage 8: Site-specific parsers (+2%)

---

## COMPLETION SIGNAL

**Analysis complete - Ready to review staged implementation plan**

---

**Next Steps:**
1. Review this analysis
2. Select which stages to implement
3. Start with Stage 0 (testing) to establish current baseline
4. Proceed stage by stage with approval gates
