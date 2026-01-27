## LongevityFoodLab_CLEAN — Current State

### 1) File structure (key areas)
- `LongevityFoodLabApp.swift` — app entry, deep links, environment objects.
- `ContentView.swift` — tab shell (Score, Recipes, Shop, Favorites, Tracker), sheets for results/compare/scan.
- `Services/` — API and data services (see section 4).
- `Managers/` — auth, health profile, recipe manager, deep link manager, meal storage, etc.
- `Models/` — `FoodAnalysis`, `Recipe`, `MealPlan`, `PetProfile`, `NutritionInfo`, caches.
- `Views/` — UI components: scanner views, recipe import/search, meal planner, favorites, shopping, pet header/profile editor, etc.
- `FoodCacheManager.swift` / `PetFoodCacheManager.swift` — caching.
- `ScannerViewController.swift`, `ScanResultView.swift`, `GroceryScanGridCard/RowView.swift` — grocery scan UI.
- `RecipesView.swift`, `RecipeImportView.swift`, `RecipeImportSheet.swift`, `RecipeSelectionDrawerView.swift` — recipes UX.
- `MealTrackingView.swift`, `MealResultsView.swift`, `SelectMealsView.swift` — tracker UX.
- `PetFood*` views — pet comparison and results.
- `SecureConfig.swift`, `SupabaseConfig.swift` — config holders.
- `UserHealthProfileManager.swift`, `UserHealthProfile.xcdatamodeld/` — health profile persistence.

### 2) Current features (working)
- **Score (default tab)**: camera/text/voice search → AI analysis (OpenAI Vision + structured prompt) → 0–100 longevity score, health sub-scores, concise summary; supports compare and multi-meal analysis.
- **Shop (grocery scanner)**: barcode + image capture; Tier 1 OpenFoodFacts lookup, Tier 2 AI vision fallback; merges OFF nutrition; OCR for product names; healthier brand swaps; grid/list history with sorting and delete.
- **Recipes**: import via share extension/deep links/URL; save ingredients/instructions; auto-navigate to Recipes tab after import; background analysis available; recipe detail sheet.
- **Tracker**: add analyzed foods/meals; meal results sheets; navigation from results to tracker tab.
- **Favorites/History**: cached analyses with list/grid, sorting, and re-open; favorites flagging via cache.
- **Pet**: pet profile store and UI; pet food compare/manual entry/results views on `pet_upgrade` branch.

### 3) Pet mode status
- Implemented: pet profile store (`PetProfileStore`), pet header/editor views, pet food input/compare/results views; branch head `pet_upgrade`.
- Pending/verify: end-to-end QA for pet compare flows, pet data persistence/backups, and visibility in main navigation surfaces (tabs/history).

### 4) Key services (one-line descriptions)
- `AuthoritativeReviewValidator.swift` — validates authoritative review content.
- `CitationValidator.swift` — ensures citations are present/valid.
- `CrossrefValidator.swift` — Crossref lookup/validation.
- `LFIEngine.swift` — longevity scoring/analysis engine glue.
- `LocalNutritionService.swift` — local nutrition lookup.
- `NutritionAggregator.swift` — combines nutrition data sources.
- `NutritionNormalizationPipeline.swift` — normalizes nutrition data.
- `NutritionService.swift` — primary nutrition service orchestrator.
- `OpenFoodFactsService.swift` — barcode → OFF product/nutrition fetch.
- `ProductNameOCRService.swift` — OCR to extract product names.
- `PubMedValidator.swift` — PubMed validation for evidence.
- `RDALookupService.swift` — RDA reference lookups.
- `RecipeBrowserService.swift` — recipe browsing/scraping helper.
- `ResearchCitation.swift` / `ResearchEvidenceService.swift` — evidence/citation utilities.
- `SpoonacularService.swift` — Spoonacular recipe API integration.
- `SupabaseConfig.swift` — Supabase configuration holder.
- `USDAService.swift` — USDA nutrition lookups.
- `YouTubeService.swift` — YouTube data helper (Lambda-backed keys).

### 5) Known issues / TODOs
- `HealthQuizView.swift:152` — TODO: show error alert.
- `LongevityFoodLabApp.swift:243` — TODO: replace placeholder API keys (code commented out; keys expected in Keychain).
- `Services/RecipeBrowserService.swift:102` — TODO: implement AI fallback.
- `Views/RecipeSearchView.swift:198` — TODO: implement browser-based recipe search.

### 6) API integrations
- **OpenAI** — vision + text for food/supplement analysis and healthier choice recommendations.
- **OpenFoodFacts** — barcode-based product and nutrition lookup (authoritative merge).
- **USDA** — nutrition data source (via `USDAService`).
- **Spoonacular** — recipe data/scraping support.
- **Crossref/PubMed** — citation and evidence validation.
- **Supabase** — configuration present; verify active usage.
- **YouTube** — service scaffold; keys handled by Lambda.

### 7) Caching (FoodCacheManager)
- Hashes images (SHA256) to identify cached analyses; stores entries in `UserDefaults` with metadata (foodName, analysisDate, imageHash, scanType, inputMethod).
- Deduping: image-backed entries deduped by `imageHash`; text/voice entries deduped by `foodName` + `inputMethod`; also removes matching `cacheKey`.
- Expiry: 30-day TTL check for cached analyses (removes expired on access).
- Persistence: serialized to `UserDefaults` (`cachedFoodAnalyses`), sorted newest-first; supports favorites flag update and cache deletion.
- Pet cache handled separately (`PetFoodCacheManager`) for pet analyses.

### 8) Navigation & deep links
- Tabs in `ContentView`: Score (tag 0), Recipes (1), Shop (2), Favorites (3), Tracker (4); side menu overlay available.
- Sheets: Results, Meal Results, Compare Results, Compare View, Recipe Detail, Scanner full-screen, Scan Result.
- Notifications: `.navigateToRecipesTab` to jump to Recipes after import; `.recipeImportRequested` to handle share-extension imports.
- Deep links: URL schemes `longevityfoodlab://import` and `longevityfood://import-recipe` parsed in `LongevityFoodLabApp`; triggers recipe import and tab navigation.
- Share extension: writes pending recipe data/URL to app group; main app polls and auto-imports, then navigates to Recipes tab.
