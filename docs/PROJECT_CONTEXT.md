# Longevity Food Lab - Project Context

## Core Mission & Guiding Principles

**Mission:** Build trust that healthy food is both good for you AND delicious. The system must reduce food fear, discourage perfectionism, and encourage confidence in eating whole, enjoyable foods.

**Internal Guiding Principle (DO NOT EXPOSE TO USERS):**
> When in doubt, choose clarity over completeness, encouragement over fear, and honesty over certainty.

---

## Critical Guardrails (Non-Negotiable)

**DO NOT:**
- Refactor architecture
- Rename public APIs
- Change data flow between services
- Modify recipe extraction (Web / YouTube / TikTok / Pinterest)
- Remove caching
- Change models or endpoints
- Modify unrelated UI
- If a change requires touching files outside the allowed list, STOP and ask

**Files You May Modify (ONLY):**
- FoodAnalysis / FoodData models
- Longevity Food Index (LFI) scoring logic
- Summary generation logic
- Health score normalization logic
- Fallback / error handling logic
- UI logic ONLY for:
  - score display
  - nutrition display
  - research display
  - loading / error indicators

---

## Scoring System Rules

### Scoring Fairness & Encouragement
- Introduce dietary-pattern bonus for clean Mediterranean / plant-forward meals (+5 points)
- Apply minimum score floor (high-80s) for meals that are:
  - primarily whole foods
  - minimal processing
  - no refined flour
  - no added sugar
- Ensure small amounts of cheese, olive oil, or grains do NOT overly penalize otherwise healthy meals
- Scores should reward progress, not perfection

### Score Coherence
- Normalize individual health goal scores so they generally cluster near the overall score
- For overall scores ≤50: enforce ±20 point range (stricter for low-scoring foods)
- For overall scores >50: enforce ±15 point range
- Allow large deviations ONLY when biologically justified:
  - `bloodSugar` can be up to 25 points lower (for high-sugar foods)
  - `heartHealth` and `antiInflammation` can be up to 15 points higher (only if overall score ≥70)
- Prevent random or confusing score patterns

### Score Calculation Rules
- Each food MUST receive a UNIQUE score based on its specific composition
- Never copy example values or use the same score for different foods
- Scores must be precise integers from 0-100
- For complex foods/meals: MUST analyze ALL major ingredients/components
- Individual health scores MUST reflect the COMPLETE food composition, NOT just positive ingredients
- For desserts: Healthy ingredients (e.g., fruit) should NOT offset penalties from sugar, refined flour, and unhealthy fats

### Meal Planner Scoring
- Spoonacular recipes use fast-pass heuristic scoring (`LFIEngine.fastScore()`) initially
- Full AI analysis with normalization is only applied when:
  - User manually taps "TAP to score" in RecipeDetailView
  - `AIService.shared.analyzeRecipe()` is explicitly called
  - Background analysis runs (if enabled)
- Score resolution priority:
  1. `recipe.longevityScore` (full AI analysis)
  2. `recipe.estimatedLongevityScore` (fast-pass or cached)
  3. Fallback: `LFIEngine.fastScore()` (heuristic-based)

---

## AI Prompt Guidelines

### Summary Generation Rules
- **CRITICAL PROHIBITION:** NEVER mention age, gender, or demographics
- Use ONLY "your", "you", "your body", "your goals" - never demographic terms
- Never lecture or use "should"
- Lead with shocking/specific fact
- Include ONE specific number
- MAX 40 words, 1-2 sentences
- End with impact on user's health goals
- For scores ≥85: Include at least ONE experiential benefit (satiety, flavor satisfaction, ease of eating, enjoyment)

### Tone & Language
- Never frame whole or minimally processed foods as "dangerous"
- Tradeoffs must be framed as optimization opportunities, not warnings
- Avoid alarmist or judgmental language
- For foods scoring ≥80:
  - Emphasize what's working
  - Reinforce confidence
  - Avoid scare framing
- Prioritize dietary patterns over isolated nutrient fear

### Serving Size Accuracy
- All nutrition estimates and summaries must be per realistic serving size
- Never extrapolate ingredient quantities beyond what is visible or standard
- Avoid exaggerated or fear-inducing quantity language

### Scientific Credibility
- Maintain strict reliance on:
  - PubMed
  - USDA FoodData Central
  - Blue Zones research
  - Mediterranean diet trials (e.g., PREDIMED)
  - High-impact journals
  - Systematic reviews (Cochrane, NESR)
- NEVER fabricate sources
- If research is unavailable, show none and explain why
- Remove all fake or generic research citations

### Data Completeness
- NEVER display numeric scores when analysis is unavailable
- Replace placeholder scores with clear states:
  - Unavailable
  - Estimated
  - Partial analysis
- Replace ambiguous "N/A" values with explicit states:
  - Loading
  - Unavailable
  - Not applicable
  - Verified zero
- NEVER fail silently

---

## Data Model Decisions

### FoodAnalysis Enhancements
- Added `DataCompleteness` enum: `complete`, `partial`, `estimated`, `unavailable`, `cached`
- Added `DataSource` enum: `openAI`, `cached`, `fallback`, `reconstructed`
- Added optional fields: `dataCompleteness`, `analysisTimestamp`, `dataSource`
- Unavailable scores use `-1` instead of placeholder values
- All new fields are optional with defaults for backward compatibility

### Health Scores Normalization
- `HealthScores` properties changed from `let` to `var` to allow mutation
- Added `normalize(overallScore:)` method to enforce score coherence
- Normalization applied after AI analysis in `AIService.performAnalysis()`

### Longevity Reassurance Feature
- Added `qualifiesForLongevityReassurance` computed property to `FoodAnalysis`
- Eligibility criteria:
  - Score ≥85
  - Plant-forward/Mediterranean pattern (≥3 indicators)
  - Excludes ultra-processed ingredients
  - Excludes refined sugar dominance (>20g sugar or ≥2 refined sugar indicators)
  - Excludes desserts
  - Only applies to meals/foods (not products/supplements)
- Uses 5-phrase pool with hash-based selection for consistency

---

## Meal Planner Architecture

### Core Components
- **MealPlannerSetupView**: Primary entry point for meal plan generation
- **MealPlannerAutoReviewView**: Review interface with swipe-to-replace
- **MealPlannerCalendarView**: Manual meal planning interface
- **MealPlanManager**: Persistent storage via UserDefaults
- **RecipeManager**: User recipe storage and management
- **SpoonacularService**: External API integration
- **LFIEngine**: Fast-pass heuristic scoring

### Recipe Selection Flow
1. **User Preference Collection**: Days, meals, dietary preferences, health goals, score filter
2. **Recipe Filtering**: Meal type matching, dietary preference matching, health goal matching, longevity score filtering
3. **Recipe Sufficiency Check**: Calculates `varietyTarget = requiredMeals * 1.3` (30% buffer)
4. **Spoonacular Integration** (if needed): Fetches recipes to fill gap, converts to Recipe format
5. **Meal Plan Building**: Variety enforcement, distribution logic, score assignment

### Variety Enforcement
- Tracks all recipes used across entire plan (not just per meal type)
- Prevents duplicate recipes by UUID
- Prevents duplicate recipes by normalized title
- Tracks Spoonacular IDs to prevent duplicates
- Avoids consecutive same primary protein

### Plan Modes
- `auto`: Automated plan generation
- `manual`: User-selected recipes via calendar interface

---

## Implementation Rules

- Make the smallest possible changes to achieve each objective
- Prefer additive flags, labels, and normalization over rewrites
- Preserve existing behavior unless it directly violates trust
- When uncertain, label the uncertainty rather than guessing
- After completion, list EXACTLY which files were changed and why

---

## UI Display Rules

### Score Display
- Unavailable scores (`-1`) display as "—" instead of "-1"
- Score colors: Gray for unavailable, color-coded for available scores
- Score circles show "—" for unavailable scores

### Health Detail Views
- Must reference the category-specific score, NOT the overall longevity score
- Header shows: "Heart Score 70/100"
- Summary must say: "Scoring 70/100 for heart..." (not "Scoring 44/100 for longevity...")

### Supplement Suggestions
- Display format matches pet food analysis format
- Shows: Brand name, Product name, Score badge, Reason text, Key benefits, Price range, Availability
- Only shows when `isSupplement == true`
- Automatically loads suggestions when section appears

---

## Known Issues & Limitations

### Meal Planner Scoring Inconsistency
- Spoonacular recipes use fast-pass heuristic scoring, not full AI analysis
- Meal planner scores may differ from manual analysis scores
- New scoring features (normalization, coherence) are not applied to meal planner recipes by default
- Background analysis exists but may not be triggered for Spoonacular recipes

### Timeout Handling
- When health info request times out, fallback content is shown silently
- Error state UI exists but may not appear if fallback always sets a value
- Recommendation: Show alert/popup on timeout instead of silent fallback

---

## Branch Management

- `main`: Primary branch (ahead of origin by many commits)
- `meal-planner`: Feature branch (merged into main)
- `ai-enhancements`: Feature branch for scoring improvements
- DerivedData build artifacts should NOT be committed

---

## Key Files Reference

### Scoring & Analysis
- `LongevityFoodLab/FoodData.swift`: Data models, normalization logic
- `LongevityFoodLab/Views/AIService.swift`: AI analysis, scoring prompts
- `LongevityFoodLab/Services/LFIEngine.swift`: Fast-pass heuristic scoring

### Meal Planner
- `LongevityFoodLab/Views/MealPlannerSetupView.swift`: Plan generation
- `LongevityFoodLab/Managers/MealPlanManager.swift`: Persistence
- `LongevityFoodLab/Services/SpoonacularService.swift`: API integration

### UI Display
- `LongevityFoodLab/ResultsView.swift`: Score display, health detail views
- `LongevityFoodLab/RecipeAnalysisView.swift`: Recipe analysis display
- `LongevityFoodLab/MealDetailsView.swift`: Meal details display

