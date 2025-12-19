# YouTube Instruction Generation Enhancement

## Overview

Enhanced YouTube recipe extraction to better handle missing instructions by:
1. Improving Tier 3 transcript parsing to focus more on instruction extraction
2. Adding Tier 4 fallback that generates instructions from transcript when missing

## Changes Made

### 1. Improved Tier 3 Prompt (parse_youtube_recipe_ai_transcript)

**Enhanced instruction extraction focus:**
- Added emphasis on extracting ALL cooking steps
- Expanded instruction detection patterns:
  * Sequential markers ("first", "then", "next", "now", "step 1")
  * Action verbs (heat, add, mix, stir, cook, bake, etc.)
  * Time references ("cook for 5 minutes", "until golden brown")
  * Temperature references ("at 350 degrees", "medium heat")
  * Technique descriptions ("whisk until smooth", "stir constantly")
- Increased max_tokens from 2000 to 2500 for better instruction extraction

### 2. New Tier 4 Function (generate_instructions_from_transcript)

**Purpose:** Generate instructions from transcript when previous tiers failed to extract them

**When it activates:**
- Ingredients are present (≥2) but instructions are missing or insufficient (<2)
- Transcript is available (≥100 characters)
- OPENAI_API_KEY is configured

**Features:**
- Focused prompt specifically for instruction generation
- Uses ingredients list as context
- Extracts chronological cooking steps from transcript
- Returns array of actionable instruction strings

### 3. Updated Extraction Flow

**Tier 3 Success Path:**
- If Tier 3 succeeds but instructions are missing/insufficient, automatically tries Tier 4
- Enhances result with generated instructions
- Updates metadata to indicate Tier 4 enhancement
- Improves quality score when instructions are added

**Final Fallback Path:**
- After all tiers, if best result has ingredients but missing instructions, tries Tier 4
- Fetches transcript if not already available
- Generates instructions and merges into result
- Updates quality score accordingly

## How It Works

### Flow Diagram

```
YouTube Video
    ↓
Tier 1: Deterministic (description)
    ↓ (if fails)
Tier 2: AI Description Parsing
    ↓ (if fails)
Tier 3: AI Transcript Parsing
    ├─→ Success with instructions → Return result
    ├─→ Success but missing instructions → Tier 4 → Return enhanced result
    └─→ Fails → Continue to fallback
        ↓
Final Fallback (Tier 2/3 partial data)
    ├─→ Has ingredients but missing instructions → Tier 4 → Return enhanced result
    └─→ Return partial result
```

### Tier 4 Activation Conditions

1. **Ingredients present:** ≥2 ingredients extracted
2. **Instructions missing:** <2 instructions found
3. **Transcript available:** ≥100 characters
4. **OpenAI configured:** OPENAI_API_KEY set

## Benefits

✅ **Better instruction coverage** - No more missing instructions when transcript is available
✅ **Automatic enhancement** - Seamlessly fills in missing instructions
✅ **Improved quality scores** - Results with generated instructions get better scores
✅ **Backward compatible** - Falls back gracefully if Tier 4 fails

## Testing

To test the enhancement:

1. Find a YouTube video with:
   - Ingredients in description
   - Instructions only in video (not in description)
   - Available transcript

2. Extract recipe and verify:
   - Instructions are generated from transcript
   - CloudWatch logs show "Tier 4" messages
   - Quality score reflects instruction presence

## CloudWatch Log Messages

Look for these log messages:
- `LAMBDA/YOUTUBE: Tier 4 - Generating instructions from transcript (instructions missing)`
- `LAMBDA/YOUTUBE: Tier 4 successfully generated X instructions`
- `LAMBDA/YOUTUBE: Tier 3 succeeded but instructions missing - trying Tier 4`
- `LAMBDA/YOUTUBE: Tier 4 generated X instructions`

## Cost Impact

- Tier 4 adds one additional OpenAI API call when instructions are missing
- Uses `gpt-4o-mini` (cost-efficient model)
- Only activates when needed (instructions missing)
- Estimated cost: ~$0.001-0.002 per Tier 4 call

## Future Improvements

Potential enhancements:
- Cache generated instructions to avoid regenerating
- Use more sophisticated instruction ordering
- Extract timing/temperature details more precisely
- Support multi-language transcripts

