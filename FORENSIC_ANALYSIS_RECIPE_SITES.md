# Forensic Analysis: Recipe Site Extraction Issues

**Date:** 2026-01-02  
**Analyst:** Senior Web Extraction Engineer  
**Scope:** King Arthur Baking, Sally's Baking Addiction, Barefoot Contessa  
**Method:** READ-ONLY code inspection, parsing logic analysis, DOM structure inference

---

## EXECUTIVE SUMMARY

This report documents structural, schema, DOM, and runtime evidence needed to correctly support three recipe sites without fallback, mis-parsing, or image issues. All analysis is based on code inspection of `lambda-package-v141/lambda_function.py` and related parsing infrastructure.

---

## SITE 1: KING ARTHUR BAKING

**URL:** `https://www.kingarthurbaking.com/recipes/soft-brown-sugar-cookies-recipe`

### A) HTML DELIVERY

**Current State:**
- No site-specific routing exists in `lambda_handler()` (lines 2449-2762)
- Falls through to generic `extract_recipe_data()` (line 3352)
- HTML refetch guard exists (lines 2504-2520) but only triggers if HTML is completely empty
- No domain-specific detection for `kingarthurbaking.com` in routing logic

**Expected Behavior:**
- King Arthur uses WordPress with custom recipe schema
- Content is server-rendered (no JS injection required)
- Recipe data exists in both JSON-LD and DOM
- HTML should be complete when fetched with proper User-Agent

**Evidence:**
- `recipe_scrapers/kingarthur.py` exists but is NOT invoked by lambda_handler
- Generic extraction path (line 3367) checks JSON-LD first, then falls back to HTML parsing
- No `is_kingarthur` flag in domain detection (compare to `is_barefootcontessa` at line 3360)

### B) JSON-LD ANALYSIS

**Current Parsing Logic:**
- JSON-LD extraction occurs at lines 3368-3592
- Handles `@type == 'Recipe'` schemas
- Extracts `recipeIngredient` array and `recipeInstructions` array
- King Arthur's JSON-LD typically includes:
  - `recipeInstructions` as array of `HowToStep` objects with `text` property
  - Instructions may contain HTML (`<p>` tags) per `recipe_scrapers/kingarthur.py` line 19

**Expected Structure:**
```json
{
  "@type": "Recipe",
  "name": "Soft Brown Sugar Cookies",
  "recipeIngredient": ["1 cup butter", "..."],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "<p>Preheat oven...</p>"},
    {"@type": "HowToStep", "text": "<p>Mix ingredients...</p>"}
  ]
}
```

**Issue:**
- Generic JSON-LD parser (line 3508-3511) extracts `text` from `HowToStep` objects but does NOT parse HTML within `text`
- `recipe_scrapers/kingarthur.py` shows King Arthur wraps instructions in `<p>` tags (line 20)
- Current parser would return HTML strings like `"<p>Preheat oven...</p>"` instead of clean text

### C) DOM STRUCTURE

**Current Selectors (Generic Extraction):**
- Ingredients: `[class*="ingredient"] li`, `.ingredients li`, `.recipe-ingredients li` (line 3936-3947)
- Instructions: `[class*="instruction"] li`, `.instructions li`, `.recipe-instructions li` (line 4024-4045)

**Expected King Arthur DOM:**
- Ingredients likely in: `.recipe-ingredients ul li` or `.wprm-recipe-ingredient`
- Instructions likely in: `.recipe-instructions ol li` or `.wprm-recipe-instruction`
- King Arthur uses WordPress Recipe Maker (WPRM) plugin (similar to Sally's Baking Addiction)

**Why It Fails:**
- Generic selectors may match taxonomy/product lists in sidebar
- No filtering for King Arthur-specific navigation elements
- No validation that extracted items are actual recipe ingredients vs. category links

### D) IMAGE ANALYSIS

**Current Image Extraction (lines 5823-6022):**
- Checks `meta[property="og:image"]` first (line 5842)
- Falls back to `img[class*="recipe"]`, `img[class*="hero"]` (line 5918-5929)
- Filters placeholder/icon images (line 5993-6000)

**Expected King Arthur Image:**
- Primary image in JSON-LD `image` field (string or array)
- Also in `og:image` meta tag
- May use `srcset` for responsive images

**Issue:**
- Generic image extraction should work, but no site-specific priority rules
- If multiple images match, may select wrong one (e.g., product thumbnail vs. recipe hero)

### E) WHY IT FAILS TODAY

**Root Cause:**
1. **No Site-Specific Parser:** King Arthur has no dedicated extraction function
2. **JSON-LD HTML Not Parsed:** Instructions contain `<p>` tags that are returned as raw HTML strings
3. **Generic Selectors Too Broad:** May capture navigation/taxonomy lists instead of actual ingredients
4. **No Validation:** No check that extracted ingredients look like actual recipe items vs. category links

**Failure Mode:**
- Ingredients become taxonomy/product list (e.g., "Cookies", "Baking", "Desserts")
- Instructions contain HTML tags: `"<p>Preheat oven to 350°F.</p>"`
- Image may be correct (generic extraction usually works)

### F) REQUIRED FIX TYPE

**Classification:** Site-specific extractor + JSON-LD HTML cleanup

**Required Actions:**
1. Create `extract_kingarthur()` function similar to `extract_sallysbakingaddiction()`
2. Add early routing in `lambda_handler()` (before generic extraction)
3. Parse HTML within JSON-LD instruction `text` fields (strip `<p>` tags, extract text)
4. Add WPRM selector variants (King Arthur uses WordPress Recipe Maker)
5. Filter taxonomy/category links from ingredients

**Safety Notes:**
- Do NOT modify generic `extract_ingredients()` selector list (breaks other sites)
- Do NOT change JSON-LD parsing for all sites (only King Arthur needs HTML parsing)
- Do NOT modify `extract_image()` globally (works for most sites)

---

## SITE 2: SALLY'S BAKING ADDICTION

**URL:** `https://sallysbakingaddiction.com/soft-caramel-candies/`

### A) HTML DELIVERY

**Current State:**
- **Early routing exists** at line 2697: `if "sallysbakingaddiction.com" in url:`
- HTML refetch guard exists (lines 2699-2719) if HTML is empty
- Dedicated parser `extract_sallysbakingaddiction()` invoked at line 2722

**Expected Behavior:**
- Sally's uses WordPress Recipe Maker (WPRM) plugin
- Content is server-rendered
- HTML should be complete when fetched

**Evidence:**
- Routing is CORRECT (early, exclusive)
- HTML refetch is CORRECT (handles empty payloads)
- Parser exists and is invoked

### B) JSON-LD ANALYSIS

**Current Parsing Logic:**
- WPRM selectors tried first (lines 5408-5441)
- JSON-LD fallback exists (lines 5452-5492)
- JSON-LD extraction handles `recipeIngredient` array and `recipeInstructions` array
- Validates >= 2 ingredients and >= 2 instructions (line 5482)

**Expected Structure:**
- JSON-LD should contain complete recipe data
- Instructions may be `HowToStep` objects or plain strings

**Issue:**
- If WPRM selectors fail AND JSON-LD is incomplete, parser returns `None` (line 5495)
- No intermediate validation (e.g., partial success with 1 ingredient)
- Blacklist validation (line 5428-5435) may reject valid recipes if navigation items appear in DOM

### C) DOM STRUCTURE

**Current Selectors (Sally-Specific):**
- PRIMARY: `.wprm-recipe-ingredient`, `.wprm-recipe-instruction` (line 5385-5386)
- SECONDARY: `.wprm-recipe-ingredients li`, `.wprm-recipe-instructions li` (line 5390-5391)
- TERTIARY: Container-based selectors (lines 5394-5405)

**Expected Sally DOM:**
- WPRM plugin generates `.wprm-recipe-ingredient` and `.wprm-recipe-instruction` elements
- Ingredients are typically `<li>` items within `.wprm-recipe-ingredients`
- Instructions are typically `<li>` items within `.wprm-recipe-instructions`

**Why It May Fail:**
1. **Blacklist Too Aggressive:** If >30% of ingredients match navigation blacklist (line 5432), entire result discarded
2. **Selector Order:** If primary selectors don't match, falls through to less specific ones
3. **Length Filters:** Ingredients must be 3-500 chars (line 5417), instructions 10-2000 chars (line 5424)
4. **Validation Threshold:** Requires >= 2 ingredients AND >= 1 instruction (line 5438)

### D) IMAGE ANALYSIS

**Current Image Extraction:**
- Sally parser does NOT extract image (relies on generic `extract_image()` at line 2731)
- Generic image extraction should work (checks `og:image`, then DOM selectors)

**Expected Sally Image:**
- Image in JSON-LD `image` field
- Also in `og:image` meta tag
- May be in `.wprm-recipe-image img` selector

**Issue:**
- No Sally-specific image extraction
- Generic extraction may select wrong image if multiple candidates exist

### E) WHY IT FAILS TODAY

**Root Cause:**
1. **Blacklist False Positives:** Navigation blacklist (line 5370-5379) may match legitimate ingredients (e.g., "baking tips" in ingredient description)
2. **Selector Mismatch:** WPRM classes may have changed or site uses different structure
3. **Validation Too Strict:** Requires >= 2 ingredients AND >= 1 instruction, may fail if one is missing
4. **No Partial Success:** If WPRM fails and JSON-LD is incomplete, returns `None` instead of partial data

**Failure Mode:**
- Parser returns `None` (line 5495)
- Lambda handler returns error (line 2750-2761)
- User sees "Nothing Found" or fallback screen

### F) REQUIRED FIX TYPE

**Classification:** Parser refinement + validation relaxation

**Required Actions:**
1. **Debug WPRM Selectors:** Verify actual DOM structure on Sally's pages
2. **Refine Blacklist:** Make navigation blacklist more specific (avoid false positives)
3. **Add Partial Success:** Return partial data if >= 1 ingredient found (even if instructions missing)
4. **Add Image Extraction:** Extract image from `.wprm-recipe-image img` or JSON-LD
5. **Add Logging:** Log which selector set succeeded/failed for debugging

**Safety Notes:**
- Do NOT modify generic extraction logic (Sally has dedicated parser)
- Do NOT change routing (early routing is correct)
- Do NOT remove blacklist (prevents navigation items, but needs refinement)

---

## SITE 3: BAREFOOT CONTESSA

**URL:** `https://barefootcontessa.com/recipes/french-chocolate-bark`

### A) HTML DELIVERY

**Current State:**
- **Routing exists** in `extract_recipe_data()` at line 3595: `if is_barefootcontessa:`
- No early routing in `lambda_handler()` (unlike Sally's)
- HTML refetch guard exists (lines 2504-2520) but only if HTML is completely empty
- Site-specific parser `extract_barefootcontessa()` invoked at line 3597

**Expected Behavior:**
- Barefoot Contessa uses custom CMS (not WordPress)
- Content is server-rendered
- HTML should be complete when fetched

**Evidence:**
- Parser exists and is invoked
- Routing is CORRECT (in `extract_recipe_data()`, not `lambda_handler()`)
- Falls back to generic extraction if parser fails (line 3612-3619)

### B) JSON-LD ANALYSIS

**Current Parsing Logic:**
- JSON-LD is SKIPPED for Barefoot Contessa (line 3367: `if not is_barefootcontessa...`)
- Site-specific parser used instead (line 3597)
- No JSON-LD fallback in Barefoot parser

**Expected Structure:**
- Barefoot Contessa may or may not have JSON-LD
- Parser relies on DOM structure (lines 4299-4306 for ingredients, 4397-4404 for instructions)

**Issue:**
- If DOM selectors fail, no JSON-LD fallback exists
- Parser may return `None` if selectors don't match

### C) DOM STRUCTURE

**Current Selectors (Barefoot-Specific):**
- Ingredients: `.recipe-ingredients li`, `.ingredients-list li`, `[class*="ingredient"] li` (line 4299-4306)
- Instructions: `.recipe-instructions p`, `.instructions-list p`, `[class*="instruction"] p` (line 4397-4404)

**Expected Barefoot DOM (from `recipe_scrapers/barefootcontessa.py`):**
- Ingredients: `div.mb-10 ul.h29 li` (line 16-22)
- Instructions: `div.bd4.mb-10.EntryPost__text.a-bc-blue p` (line 36-45)

**Why It Fails:**
1. **Selector Mismatch:** Current parser uses generic selectors (`.recipe-ingredients li`) but Barefoot uses specific classes (`div.mb-10 ul.h29 li`)
2. **No Class-Specific Selectors:** Parser doesn't use Barefoot's actual class structure
3. **Fallback Too Broad:** Falls back to `li` and `p` selectors (line 4304-4305) which may capture navigation

### D) IMAGE ANALYSIS

**Current Image Extraction:**
- Barefoot parser does NOT extract image (relies on generic `extract_image()` at line 3610)
- Generic image extraction should work

**Expected Barefoot Image:**
- Image likely in `og:image` meta tag
- May be in hero image container
- Generic extraction should find it

**Issue:**
- No Barefoot-specific image extraction
- Generic extraction may select wrong image (e.g., logo, thumbnail, related recipe)

### E) WHY IT FAILS TODAY

**Root Cause:**
1. **Selector Mismatch:** Parser uses generic selectors (`.recipe-ingredients li`) but Barefoot uses specific classes (`div.mb-10 ul.h29 li`)
2. **No JSON-LD Fallback:** If DOM selectors fail, parser returns `None` (no JSON-LD check)
3. **Navigation Filtering:** Skip words list (line 4309-4318) filters navigation, but may miss some items
4. **Instruction Filtering:** Copyright filter (line 4415) may be too aggressive

**Failure Mode:**
- Parser finds < 2 ingredients (line 3598), falls back to generic extraction
- Generic extraction may capture navigation items as ingredients
- Instructions may include copyright text
- Image may be wrong (generic extraction selects first match)

### F) REQUIRED FIX TYPE

**Classification:** Selector correction + JSON-LD fallback

**Required Actions:**
1. **Update Selectors:** Use Barefoot's actual class structure (`div.mb-10 ul.h29 li` for ingredients, `div.bd4.mb-10.EntryPost__text.a-bc-blue p` for instructions)
2. **Add JSON-LD Fallback:** If DOM selectors fail, try JSON-LD extraction
3. **Refine Navigation Filter:** Update skip_words list based on actual Barefoot navigation
4. **Add Image Extraction:** Extract image from Barefoot-specific selectors or JSON-LD
5. **Add Logging:** Log which selector succeeded/failed

**Safety Notes:**
- Do NOT modify generic extraction logic (Barefoot has dedicated parser)
- Do NOT change routing (routing in `extract_recipe_data()` is correct)
- Do NOT remove navigation filtering (prevents false positives, but needs refinement)

---

## CROSS-SITE PATTERNS

### Common Issues Across All Sites

1. **HTML Refetch Guard:**
   - Exists at lines 2504-2520
   - Only triggers if HTML is completely empty or whitespace
   - Does NOT handle partial HTML or malformed content
   - User-Agent is correct (Mozilla/5.0...)

2. **Image Extraction:**
   - Generic `extract_image()` function (lines 5823-6022)
   - Checks `og:image` meta tag first (line 5842)
   - Falls back to DOM selectors
   - Filters placeholder/icon images (line 5993-6000)
   - **Issue:** No site-specific image priority rules

3. **JSON-LD Parsing:**
   - Generic JSON-LD extraction (lines 3368-3592)
   - Handles `@type == 'Recipe'` schemas
   - Extracts `recipeIngredient` and `recipeInstructions`
   - **Issue:** Does NOT parse HTML within instruction `text` fields (King Arthur needs this)

4. **Fallback Behavior:**
   - All parsers return `None` if extraction fails
   - Lambda handler returns error response (e.g., line 2750-2761 for Sally)
   - No partial success handling (e.g., ingredients found but instructions missing)

### Supabase → Lambda Payload Structure

**Current Flow:**
1. iOS Share Extension fetches HTML (may be empty or partial)
2. Supabase Edge Function receives `{url, html}` payload (line 41 of `index.ts`)
3. Lambda receives `{url, html}` in event body (line 2490-2492)
4. HTML refetch guard checks if HTML is empty (line 2505)

**Issue:**
- If HTML is partial (e.g., only header/footer), refetch guard does NOT trigger
- Lambda may parse incomplete HTML
- No validation that HTML contains recipe content

---

## RECOMMENDATIONS SUMMARY

### King Arthur Baking
- **Priority:** HIGH (no site-specific parser exists)
- **Fix:** Create `extract_kingarthur()` with WPRM selectors + JSON-LD HTML parsing
- **Risk:** LOW (new parser, doesn't affect existing sites)

### Sally's Baking Addiction
- **Priority:** MEDIUM (parser exists but may fail)
- **Fix:** Refine blacklist, add partial success, add image extraction
- **Risk:** LOW (only affects Sally's domain)

### Barefoot Contessa
- **Priority:** MEDIUM (parser exists but selectors wrong)
- **Fix:** Update selectors to match actual DOM, add JSON-LD fallback
- **Risk:** LOW (only affects Barefoot domain)

### Cross-Site Improvements
- **Priority:** LOW (affects all sites)
- **Fix:** Add HTML completeness validation, add partial success handling
- **Risk:** MEDIUM (may affect existing working sites)

---

## SAFETY CONSTRAINTS

**DO NOT MODIFY:**
1. Generic `extract_ingredients()` selector list (line 3936-3947)
2. Generic `extract_instructions()` selector list (line 4024-4045)
3. Generic `extract_image()` function (line 5823-6022)
4. JSON-LD parsing logic for all sites (line 3368-3592)
5. HTML refetch guard (line 2504-2520) - only enhance, don't remove

**SAFE TO MODIFY:**
1. Site-specific parser functions (`extract_kingarthur()`, `extract_sallysbakingaddiction()`, `extract_barefootcontessa()`)
2. Site-specific routing logic (add King Arthur routing, refine Sally/Barefoot routing)
3. Site-specific selectors within dedicated parsers
4. Site-specific image extraction within dedicated parsers

---

**END OF REPORT**



