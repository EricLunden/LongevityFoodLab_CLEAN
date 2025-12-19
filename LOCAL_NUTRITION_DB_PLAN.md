# Local Nutrition Database Experiment - Implementation Plan

## Branch: `experiment/local-nutrition-db`

## Goal
Create a local SQLite database populated with common foods to improve nutrition lookup speed and accuracy. This will serve as **Tier 0** (before USDA API) in the nutrition lookup chain.

## Architecture

### New Tiered Lookup Flow
```
User requests nutrition
    ↓
Tier 0: Local SQLite DB (fastest, offline)
    ✅ Found → Return immediately
    ❌ Not found → Continue
    ↓
Tier 1: USDA API (current Tier 1)
    ✅ Found → Return + Cache to local DB
    ❌ Not found → Continue
    ↓
Tier 2: Spoonacular API (current Tier 2)
    ✅ Found → Return + Cache to local DB
    ❌ Not found → Continue
    ↓
Tier 3: AI Estimation (current Tier 3)
```

## Database Schema

### Table: `foods`
```sql
CREATE TABLE foods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fdc_id INTEGER UNIQUE,              -- USDA FDC ID (if available)
    name TEXT NOT NULL,                 -- Food name (e.g., "Apple, raw")
    search_name TEXT,                   -- Normalized for searching
    calories REAL,                      -- per 100g
    protein REAL,                       -- grams per 100g
    carbohydrates REAL,                -- grams per 100g
    fat REAL,                          -- grams per 100g
    sugar REAL,                        -- grams per 100g
    fiber REAL,                        -- grams per 100g
    sodium REAL,                       -- mg per 100g
    vitamin_d REAL,                    -- mcg per 100g
    vitamin_e REAL,                    -- mg per 100g
    potassium REAL,                    -- mg per 100g
    vitamin_k REAL,                    -- mcg per 100g
    magnesium REAL,                    -- mg per 100g
    vitamin_a REAL,                     -- mcg RAE per 100g
    calcium REAL,                      -- mg per 100g
    vitamin_c REAL,                    -- mg per 100g
    choline REAL,                      -- mg per 100g
    iron REAL,                         -- mg per 100g
    iodine REAL,                       -- mcg per 100g
    zinc REAL,                         -- mg per 100g
    folate REAL,                       -- mcg per 100g
    vitamin_b12 REAL,                   -- mcg per 100g
    vitamin_b6 REAL,                    -- mg per 100g
    selenium REAL,                      -- mcg per 100g
    copper REAL,                        -- mg per 100g
    manganese REAL,                    -- mg per 100g
    thiamin REAL,                      -- mg per 100g
    data_source TEXT,                  -- "USDA", "Spoonacular", etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_search_name ON foods(search_name);
CREATE INDEX idx_fdc_id ON foods(fdc_id);
```

## Implementation Steps

### Phase 1: Database Infrastructure
1. ✅ Create `LocalNutritionDatabase` service class
2. ✅ Set up SQLite database file in app documents directory
3. ✅ Create database schema (migration system)
4. ✅ Add database initialization and connection management

### Phase 2: Data Population
1. Create data population script/tool
2. Fetch top 10,000 foods from USDA API
3. Store in SQLite database
4. Bundle pre-populated database with app (or download on first launch)

### Phase 3: Integration
1. Add `LocalNutritionDatabase` as Tier 0 in `NutritionService`
2. Implement fuzzy search/matching for food names
3. Add caching logic (write USDA/Spoonacular results to local DB)
4. Update `USDAService` to cache successful lookups

### Phase 4: Testing & Optimization
1. Test lookup speed (should be <10ms for local DB)
2. Test accuracy (compare with USDA API results)
3. Optimize search queries
4. Add database size management (limit to top foods)

## Files to Create/Modify

### New Files
- `LongevityFoodLab/Services/LocalNutritionDatabase.swift` - SQLite database manager
- `LongevityFoodLab/Models/LocalFood.swift` - Database model
- `scripts/populate_nutrition_db.py` - Data population script (optional)

### Modified Files
- `LongevityFoodLab/Services/NutritionService.swift` - Add Tier 0 lookup
- `LongevityFoodLab/Services/USDAService.swift` - Add caching to local DB

## Database Population Strategy

### Option 1: Pre-populated Bundle (Recommended)
- Create database file with top 10,000 foods
- Bundle with app (adds ~5-10MB to app size)
- Fastest, works offline immediately

### Option 2: First Launch Download
- Download database file on first app launch
- Store in documents directory
- Requires internet on first launch

### Option 3: Incremental Population
- Start with top 1,000 foods bundled
- Populate more as USDA API calls succeed
- Grows over time

## Success Metrics
- **Speed**: Local DB lookup <10ms (vs 200-500ms for API)
- **Accuracy**: 95%+ match rate for common foods
- **Coverage**: Top 10,000 foods covers 80%+ of user queries
- **Offline**: Works completely offline for cached foods

## Rollback Plan
If experiment fails:
```bash
git checkout main
git branch -D experiment/local-nutrition-db
```

