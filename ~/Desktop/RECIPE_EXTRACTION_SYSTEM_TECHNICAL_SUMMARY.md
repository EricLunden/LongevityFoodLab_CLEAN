# Recipe Extraction System - Complete Technical Summary

## Overview

This document provides a comprehensive technical overview of the AWS Lambda recipe extraction system, including architecture, site-specific parsers, extraction strategies, and current issues. This is intended for another AI to understand the system and recommend fixes, particularly for Love and Lemons extraction.

## System Architecture

### Main Entry Point: `extract_recipe_data(soup, url)`

The extraction flow follows this hierarchy:

1. **Domain Detection** - Identifies the recipe site from URL
2. **JSON-LD Extraction** (for most sites) - Primary extraction method using schema.org structured data
3. **Site-Specific Parsers** (for problematic sites) - Custom extraction logic
4. **Generic HTML Parsing** (fallback) - Pattern-based extraction from HTML
5. **Nutrition Extraction** - Separate extraction path for nutrition facts

### Extraction Flow Diagram

```
extract_recipe_data(soup, url)
│
├─→ Domain Detection (Food Network, Barefoot Contessa, Food & Wine, Love and Lemons)
│
├─→ JSON-LD Extraction (lines 1078-1302)
│   ├─→ Parse schema.org Recipe JSON-LD
│   ├─→ Extract: title, ingredients, instructions, servings, prep_time, cook_time, total_time, image
│   ├─→ Love and Lemons: Clean ingredient descriptions (remove text after dashes/colons)
│   ├─→ Check completeness (title + ingredients + >=3 substantial instructions)
│   └─→ If complete: Extract nutrition, return result
│   └─→ If incomplete: Fall through to site-specific or generic extraction
│
├─→ Site-Specific Parsers (if domain matches)
│   ├─→ Barefoot Contessa: extract_barefootcontessa()
│   ├─→ Food Network: extract_foodnetwork()
│   ├─→ Food & Wine: extract_foodandwine()
│   └─→ Love and Lemons: extract_loveandlemons() [CURRENTLY NOT CALLED IN MAIN FLOW]
│
├─→ Generic HTML Extraction (fallback)
│   ├─→ extract_title()
│   ├─→ extract_ingredients()
│   ├─→ extract_instructions()
│   ├─→ extract_servings()
│   ├─→ extract_prep_time()
│   └─→ extract_image()
│
└─→ Nutrition Extraction (always runs)
    ├─→ extract_nutrition_from_html()
    │   ├─→ Priority 1: extract_from_schema() (schema.org nutrition)
    │   ├─→ Priority 2: find_nutrition_section() + parse_nutrition_section() (HTML parsing)
    │   └─→ Merge schema.org + HTML data (fill missing micronutrients)
    └─→ Per-serving vs per-recipe division logic
```

## JSON-LD Extraction (Main Path)

### Location: Lines 1078-1302

**Process:**
1. Searches for `<script type="application/ld+json">` tags
2. Parses JSON-LD Recipe schema
3. Extracts fields:
   - `name` → title
   - `recipeIngredient` → ingredients (array)
   - `recipeInstructions` → instructions (array of strings or objects with `text` field)
   - `recipeYield` → servings
   - `prepTime`, `cookTime`, `totalTime` → time fields (ISO 8601 format)
   - `image` → image URL (can be string, array, or object)

**Completeness Check:**
- Requires: title + ingredients + >=3 instructions (each >20 chars)
- If complete: Extracts nutrition, returns early
- If incomplete: Falls through to site-specific or generic extraction

**Love and Lemons Special Handling:**
- Lines 1113-1128: Cleans ingredient descriptions
- Removes text after dashes (`-`) and colons (`:`)
- Handles em-dash variants (`–`, `—`)
- Example: "Extra-virgin olive oil - For richness." → "Extra-virgin olive oil"

**Current Issue:** Love and Lemons is NOT skipped from JSON-LD extraction (line 1077), so it uses the main JSON-LD path. However, when JSON-LD instructions are incomplete, it falls back to generic HTML extraction, which picks up navigation items and tips.

## Site-Specific Parsers

### 1. Food Network (`extract_foodnetwork`) - Lines 1721-1902

**Why:** Food Network has complex class structures that generic extraction misses.

**Strategy:**
- Uses specific CSS selectors (`.o-Ingredients__a-ListItemText`, `.o-Method__m-StepText`)
- Filters out navigation items ("Deselect All", "Select All")
- Removes step numbers from ingredients
- Extracts servings from `.o-RecipeInfo__m-Yield`
- Filters image URLs (skips promo/advertisement images)

**Success Criteria:** Returns result if >=2 ingredients found, otherwise returns None (falls back to generic).

**Integration:** Called BEFORE JSON-LD extraction (line 1077 skips JSON-LD for Food Network).

### 2. Barefoot Contessa (`extract_barefootcontessa`) - Lines 1904-2165

**Why:** Navigation items appear in ingredient lists, copyright text in instructions.

**Strategy:**
- Filters navigation items from ingredients (Recipes, Books, Cookbook Index, etc.)
- Removes copyright text from instructions
- Uses multiple ingredient selectors with heavy filtering
- Filters out common navigation patterns

**Success Criteria:** Returns result if >=2 ingredients found, otherwise returns None (falls back to generic).

**Integration:** Called BEFORE JSON-LD extraction (line 1077 skips JSON-LD for Barefoot Contessa).

### 3. Food & Wine (`extract_foodandwine`) - Lines 2166-2340

**Why:** Complex HTML structure requires specific selectors.

**Strategy:**
- Uses specific selectors for ingredients and instructions
- Handles nested structures
- Extracts image from meta tags or specific image containers

**Success Criteria:** Returns result if ingredients found, otherwise returns None (falls back to generic).

**Integration:** Called BEFORE JSON-LD extraction (line 1077 skips JSON-LD for Food & Wine).

### 4. Love and Lemons (`extract_loveandlemons`) - Lines 2341-2596

**Current Status:** **DEFINED BUT NOT CALLED IN MAIN EXTRACTION FLOW**

**Why:** Love and Lemons schema.org includes ingredient descriptions that need cleaning, and HTML fallback picks up navigation items.

**Current Implementation:**
1. Extracts from schema.org first (with ingredient cleaning)
2. Falls back to HTML parsing if schema.org doesn't provide enough ingredients
3. Falls back to generic extraction if HTML parsing fails
4. Cleans ingredient descriptions (removes text after dashes/colons)

**Problem:** This function exists but is **never called** in the main extraction flow (line 1407 goes directly to generic extraction for "all other sites").

**What Should Happen:**
- Love and Lemons should be detected (line 1072: `is_loveandlemons = 'loveandlemons.com' in domain`)
- Should call `extract_loveandlemons()` similar to other site-specific parsers
- Currently falls through to generic extraction, which picks up navigation items

## Generic HTML Extraction (Fallback)

### `extract_ingredients(soup)` - Lines 1544-1611

**Strategy:**
1. Tries multiple CSS selectors (in order):
   - `[class*="ingredient"] li`
   - `[class*="ingredient"] p`
   - `.ingredients li`
   - `.recipe-ingredients li`
   - `[itemprop="ingredients"]`
2. Filters using skip_words list (navigation items, categories, etc.)
3. Validates ingredient-like text (contains measurements, ingredient words, or short phrases)
4. If no ingredients found, tries all `<li>` tags with strict filtering
5. Limits to 20 ingredients

**Current Issue:** For Love and Lemons, when JSON-LD instructions are incomplete, this function is called and picks up:
- Navigation menu items (RECIPES, NEWSLETTER, COOKBOOK, etc.)
- Tips and substitutions ("Substitute chopped fennel for the celery")
- Recipe suggestions ("Butternut Squash Soup", "Tortellini Soup")
- Ingredient descriptions ("Diced tomatoes - For sweet, tangy flavor")

**Why It Fails for Love and Lemons:**
- Love and Lemons HTML structure doesn't match the generic selectors well
- Navigation items appear in `<li>` tags that match ingredient patterns
- The skip_words list doesn't include Love and Lemons-specific navigation items

### `extract_instructions(soup, existing_instructions=None)` - Lines 1613-1720

**Strategy:**
1. Deduplicates against existing instructions (from JSON-LD)
2. Tries multiple CSS selectors
3. Filters out non-instruction content
4. Removes step numbers
5. Validates instruction length (>10 chars)

**Current Issue:** For Love and Lemons, picks up ingredient descriptions as instructions.

## Nutrition Extraction

### `extract_nutrition_from_html(soup)` - Lines 970-1023

**Priority Order:**
1. **Schema.org** (`extract_from_schema`) - Most reliable
2. **HTML Nutrition Section** (`find_nutrition_section` + `parse_nutrition_section`)
3. **Merge Logic** - Fills missing micronutrients from HTML into schema.org data

**Nutrition Merging:**
- If schema.org provides calories but missing micronutrients, merges from HTML
- Comprehensive merge list includes: macros, minerals, vitamins, fiber, sugar, cholesterol, etc.
- Only merges if schema.org value is empty/0 and HTML has a value

**Per-Serving vs Per-Recipe Logic:**
- If calories >1000, assumes per-recipe and divides by servings
- Otherwise, assumes per-serving (most recipe sites show per-serving)

## Jump-to Strategy

**Current Status:** **NOT IMPLEMENTED**

**What It Would Do:**
- Find "Jump to Recipe" links or anchors
- Navigate to the recipe card section
- Parse only that isolated section (avoiding navigation, ads, related content)

**Why It Was Considered:**
- Love and Lemons has navigation items and tips scattered throughout the page
- Isolating the recipe card would avoid picking up non-recipe content

**Why It Was Removed:**
- Previous implementation broke extraction (returned empty results)
- The isolated section sometimes didn't contain ingredients/instructions
- Schema.org data is in `<head>`, so jump-to doesn't help with JSON-LD extraction

**Current Approach:**
- Use schema.org for ingredients (with cleaning)
- Use HTML parsing with better filtering (not implemented yet)

## Current Love and Lemons Issues

### Problem 1: Random Text in Ingredients

**Symptoms:**
- Navigation items: "RECIPES", "NEWSLETTER", "COOKBOOK", "SAVED RECIPES"
- Tips: "Substitute chopped fennel for the celery"
- Recipe suggestions: "Butternut Squash Soup", "Tortellini Soup"
- Ingredient descriptions: "Diced tomatoes - For sweet, tangy flavor"

**Root Cause:**
1. Love and Lemons uses main JSON-LD path (not skipped)
2. JSON-LD provides ingredients but instructions are incomplete (<3 steps or too short)
3. Falls back to generic HTML extraction (`extract_ingredients()`)
4. Generic extraction picks up navigation items from `<li>` tags

**Why Generic Extraction Fails:**
- Love and Lemons navigation items match ingredient patterns (short text, no skip_words match)
- The skip_words list doesn't include Love and Lemons-specific items
- No filtering for tips, substitutions, or recipe suggestions

### Problem 2: Missing Prep Time, Cook Time, Servings

**Symptoms:**
- Prep time, cook time, and servings not extracted from nutrition section
- These fields exist in schema.org but may not be extracted correctly

**Root Cause:**
- When JSON-LD instructions are incomplete, the early return (line 1288) doesn't happen
- Falls through to generic extraction, which may not extract time fields correctly
- Nutrition section extraction happens separately and may not update recipe fields

### Problem 3: Duplicate Instructions

**Symptoms:**
- Instructions appear twice in the extracted recipe

**Root Cause:**
- JSON-LD provides some instructions
- Generic HTML extraction also finds instructions
- Deduplication logic may not be working correctly

## Recommended Fixes

### Fix 1: Call Love and Lemons Site-Specific Parser

**Location:** Around line 1406-1407

**Current Code:**
```python
# Check if this is Love and Lemons - use site-specific parser with jump-to strategy
else:
    # Generic extraction for all other sites
```

**Recommended Change:**
```python
# Check if this is Love and Lemons - use site-specific parser
elif is_loveandlemons:
    print(f"LAMBDA/PARSE: detected Love and Lemons domain={domain}, using site-specific parser")
    loveandlemons_result = extract_loveandlemons(soup, url)
    if loveandlemons_result and len(loveandlemons_result.get('ingredients', [])) >= 2:
        # Site-specific parser found data, use it
        ing_count = len(loveandlemons_result.get('ingredients', []))
        inst_count = len(loveandlemons_result.get('instructions', []))
        print(f"LAMBDA/PARSE: Love and Lemons parser SUCCESS - found {ing_count} ingredients, {inst_count} instructions")
        title = loveandlemons_result.get('title') or extract_title(soup)
        ingredients = loveandlemons_result.get('ingredients', [])
        instructions = loveandlemons_result.get('instructions', [])
        servings = loveandlemons_result.get('servings') or extract_servings(soup)
        prep_time = loveandlemons_result.get('prep_time') or extract_prep_time(soup)
        cook_time = loveandlemons_result.get('cook_time')
        total_time = loveandlemons_result.get('total_time')
        image = loveandlemons_result.get('image') or extract_image(soup, url)
        source_url = loveandlemons_result.get('source_url') or url
    else:
        # Parser didn't find enough data, fall back to generic
        if loveandlemons_result:
            ing_count = len(loveandlemons_result.get('ingredients', []))
            print(f"LAMBDA/PARSE: Love and Lemons parser found only {ing_count} ingredients (< 2 required), falling back to generic")
        else:
            print("LAMBDA/PARSE: Love and Lemons parser returned None, falling back to generic extraction")
        title = extract_title(soup)
        ingredients = extract_ingredients(soup)
        instructions = extract_instructions(soup, existing_instructions=json_ld_instructions_for_dedup if json_ld_instructions_for_dedup else None)
        servings = extract_servings(soup)
        prep_time = extract_prep_time(soup)
        image = extract_image(soup, url)
        source_url = url
else:
    # Generic extraction for all other sites
```

### Fix 2: Enhance Love and Lemons Parser Filtering

**Location:** `extract_loveandlemons()` function, around lines 2384-2395 and 2483-2489

**Current Cleaning:**
- Only removes text after dashes/colons
- No filtering for navigation items, tips, or recipe suggestions

**Recommended Enhancement:**
Add comprehensive filtering in `extract_loveandlemons()`:

1. **After schema.org ingredient extraction (line 2386-2395):**
   - Filter out navigation items (recipes, newsletter, cookbook, saved recipes, about us, contact, social media links)
   - Filter out tips and substitutions (starts with "Substitute", "Instead", "Use", "Add", "Garnish", "Optional")
   - Filter out recipe suggestions (common soup names, recipe titles)
   - Filter out all-caps short items (likely navigation)

2. **After HTML ingredient extraction (line 2483-2489):**
   - Apply same filtering as schema.org extraction
   - Filter out items that match navigation patterns

**Filtering Logic:**
```python
# Navigation items to skip
navigation_items = [
    'recipes', 'newsletter', 'cookbook', 'saved recipes', 'about us',
    'my saved recipes', 'contact', 'instagram', 'facebook', 'pinterest',
    'twitter', 'best brunch recipes', 'best salad recipes', 'best soup recipes',
    'easy appetizer recipes', 'avocado', 'brussels sprouts'
]

# Skip patterns
skip_patterns = [
    r'^(recipes|newsletter|cookbook|saved recipes|about|contact|instagram|facebook|pinterest|twitter)',
    r'^(substitute|instead of|use|add|garnish|optional|for)',
    r'^(butternut squash soup|tortellini soup|cabbage soup|many veggie vegetable soup)',
]

# Filter logic
for ing in ingredients:
    cleaned_lower = cleaned.lower()
    
    # Skip navigation items
    if any(nav in cleaned_lower for nav in navigation_items):
        continue
    
    # Skip if matches skip patterns
    if any(re.match(pattern, cleaned_lower) for pattern in skip_patterns):
        continue
    
    # Skip all-caps short items (navigation)
    if cleaned.isupper() and len(cleaned.split()) <= 3:
        continue
    
    # Skip tips/substitutions
    if cleaned_lower.startswith(('substitute', 'instead', 'use ', 'add ', 'garnish', 'optional')):
        continue
    
    # Skip recipe suggestions
    if any(soup_name in cleaned_lower for soup_name in ['butternut squash soup', 'tortellini soup', 'cabbage soup', 'vegetable soup']):
        continue
```

### Fix 3: Preserve JSON-LD Ingredients When Falling Back

**Location:** Around line 1290-1298 (where JSON-LD falls back to HTML parsing)

**Current Behavior:**
- When JSON-LD instructions are incomplete, `result = None` is set
- Falls through to generic extraction, which re-extracts ingredients from HTML
- Loses the cleaned JSON-LD ingredients

**Recommended Change:**
Preserve JSON-LD ingredients for Love and Lemons even when falling back:

```python
else:
    # JSON-LD exists but instructions are incomplete - fall through to HTML parsing
    json_ld_instructions_for_dedup = json_ld_instructions.copy() if json_ld_instructions else []
    
    # For Love and Lemons, preserve JSON-LD ingredients even if instructions are incomplete
    json_ld_ingredients_for_loveandlemons = None
    try:
        from urllib.parse import urlparse as _urlp
        host = (_urlp(url).netloc.lower() if url else '')
        if 'loveandlemons.com' in host and result and result.get('ingredients'):
            json_ld_ingredients_for_loveandlemons = result['ingredients'].copy()
            print(f"LAMBDA/PARSE: Preserving {len(json_ld_ingredients_for_loveandlemons)} JSON-LD ingredients for Love and Lemons")
    except Exception:
        pass
    
    # Clear result so we don't use incomplete JSON-LD data
    result = None
```

Then in the Love and Lemons parser or generic extraction:
```python
# For Love and Lemons, prefer preserved JSON-LD ingredients over HTML parsing
if json_ld_ingredients_for_loveandlemons:
    ingredients = json_ld_ingredients_for_loveandlemons
    print(f"LAMBDA/PARSE: Using preserved JSON-LD ingredients for Love and Lemons ({len(ingredients)} items)")
else:
    ingredients = extract_ingredients(soup)
```

### Fix 4: Skip Love and Lemons from JSON-LD Path (Alternative)

**Location:** Line 1077

**Alternative Approach:**
Skip Love and Lemons from JSON-LD extraction entirely, always use site-specific parser:

```python
# Try JSON-LD first (but skip for Food Network, Barefoot Contessa, Food & Wine, and Love and Lemons)
if not is_foodnetwork and not is_barefootcontessa and not is_foodandwine and not is_loveandlemons:
```

**Pros:**
- Ensures Love and Lemons always uses site-specific parser
- Avoids fallback to generic extraction

**Cons:**
- Loses JSON-LD benefits (structured data, time fields, etc.)
- Requires site-specific parser to handle all fields

**Recommendation:** Prefer Fix 1 + Fix 2 + Fix 3 (use site-specific parser but preserve JSON-LD data when available).

## Testing Recommendations

### Test URLs for Love and Lemons

1. **Christmas Sugar Cookies** - Has navigation items in ingredients
2. **Minestrone Soup** - Has tips and substitutions in ingredients
3. **Any recipe with "Jump to Recipe" link** - Test jump-to strategy if implemented

### Expected Behavior After Fixes

1. **Ingredients:**
   - Only actual ingredients (e.g., "Diced tomatoes", "Vegetable broth")
   - No navigation items
   - No tips or substitutions
   - No recipe suggestions
   - No ingredient descriptions (text after dashes/colons removed)

2. **Instructions:**
   - Only cooking steps
   - No ingredient descriptions
   - No duplicate instructions

3. **Metadata:**
   - Prep time, cook time, total time extracted correctly
   - Servings extracted correctly
   - Image extracted correctly

## Summary

**Current State:**
- Love and Lemons uses main JSON-LD path with ingredient cleaning
- When JSON-LD instructions are incomplete, falls back to generic HTML extraction
- Generic extraction picks up navigation items, tips, and recipe suggestions
- Site-specific parser exists but is never called

**Recommended Solution:**
1. Call `extract_loveandlemons()` in main extraction flow (similar to other site-specific parsers)
2. Enhance filtering in `extract_loveandlemons()` to exclude navigation items, tips, and recipe suggestions
3. Preserve JSON-LD ingredients when falling back to HTML parsing for instructions
4. Ensure proper extraction of prep time, cook time, and servings from schema.org

**Priority:**
- **High:** Fix 1 (call site-specific parser) - This is the main issue
- **High:** Fix 2 (enhance filtering) - Required to fix the random text problem
- **Medium:** Fix 3 (preserve JSON-LD ingredients) - Improves quality
- **Low:** Fix 4 (skip JSON-LD) - Alternative approach, less preferred

