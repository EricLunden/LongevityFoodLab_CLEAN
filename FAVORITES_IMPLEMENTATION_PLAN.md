# Favorites Implementation Plan

## Overview
Populate the Favorites screen with favorited recipes, meals, and groceries. Add empty heart icons in discreet places throughout the app to allow users to favorite items. Use the grid/list view from the Recipes page as a model for the Favorites screen.

## Current State
- ✅ `Recipe` model already has `isFavorite: Bool` property
- ✅ `RecipeManager` has `getFavoriteRecipes()` method
- ✅ Recipes screen shows filled heart icon for favorited recipes
- ✅ Favorites screen UI structure exists (top box, navigation bar, logo)
- ❌ No heart icons to toggle favorites in Recipes screen
- ❌ No favorite functionality for meals
- ❌ No favorite functionality for groceries
- ❌ Favorites screen shows "Coming soon" placeholder

---

## Phase 1: Recipes Screen - Add Heart Toggle (LOWEST RISK)
**Goal:** Enable users to favorite/unfavorite recipes from the Recipes screen

### Tasks:
1. **Add empty heart icon to recipe cards**
   - **List View (`RecipeRowView`)**: Add heart icon overlay at **top-left corner** of recipe image
   - **Grid View (`RecipeGridCard`)**: Add heart icon overlay at **top-left corner** of recipe image
   - **Detail View (`RecipeDetailView`)**: Add heart icon overlay at **top-right corner** of recipe image
   - Show `heart.fill` (red) when `recipe.isFavorite == true`
   - Show `heart` (empty) when `recipe.isFavorite == false`
   - Add semi-transparent white background circle for visibility
   - Size: 12-14pt font, 24-28pt circle

2. **Implement toggle functionality**
   - Add tap gesture to heart icon
   - Toggle `recipe.isFavorite` property
   - Call `RecipeManager.shared.updateRecipe()` to persist changes
   - Update UI immediately (no API call needed)

3. **Test thoroughly**
   - Test favoriting/unfavoriting in list view
   - Test favoriting/unfavoriting in grid view
   - Verify persistence across app restarts
   - Verify heart state updates immediately

### Risk Level: LOW
- Only affects Recipes screen
- Uses existing `isFavorite` property
- No new data models needed
- Can be easily reverted if issues arise

---

## Phase 2: Favorites Screen - Display Recipes (LOW-MEDIUM RISK)
**Goal:** Populate Favorites screen with favorited recipes using grid/list view

### Tasks:
1. **Create FavoritesViewModel**
   - Similar to RecipesView's view model
   - Filter recipes by `isFavorite == true`
   - Support grid/list view toggle
   - Handle empty state (no favorites)

2. **Implement grid/list display**
   - Reuse `RecipeGridCardView` and `RecipeListView` components
   - Filter recipes: `RecipeManager.shared.getFavoriteRecipes()`
   - Add view toggle (list/grid icons) matching Recipes screen
   - Add empty state message: "No favorites yet. Tap the heart icon on recipes to add them here."

3. **Add navigation**
   - Tapping a favorite recipe opens recipe detail view
   - Heart icon in detail view also toggles favorite status

### Risk Level: LOW-MEDIUM
- Reuses existing components
- Depends on Phase 1 completion
- May need to handle empty state gracefully

---

## Phase 3: Meals - Add Favorite Support (MEDIUM RISK)
**Goal:** Enable favoriting meals from the Tracker screen

### Tasks:
1. **Extend TrackedMeal model**
   - Add `isFavorite: Bool` property to `TrackedMeal` struct
   - Update `MealStorageManager` to persist favorite status
   - Update encoding/decoding logic

2. **Add heart icon to meal cards**
   - **List View**: Add heart icon overlay at **top-left corner** of meal image
   - **Grid View**: Add heart icon overlay at **top-left corner** of meal image
   - **Detail View**: Add heart icon overlay at **top-right corner** of meal image
   - Toggle favorite on tap
   - Update `MealStorageManager` to save changes

3. **Update Favorites screen**
   - Add section for favorited meals
   - Display meals in grid/list format
   - Show meal image, name, and health score
   - Allow navigation to meal details

### Risk Level: MEDIUM
- Requires model changes
- Need to handle data migration for existing meals
- Must ensure backward compatibility

---

## Phase 4: Groceries - Add Favorite Support (MEDIUM-HIGH RISK)
**Goal:** Enable favoriting groceries from the Shop/Score screen

### Tasks:
1. **Identify grocery data model**
   - Determine where grocery scan results are stored
   - Check if `FoodAnalysis` or similar model exists
   - May need to create `GroceryItem` model

2. **Add favorite property**
   - Add `isFavorite: Bool` to grocery data model
   - Update storage/persistence logic
   - Handle data migration

3. **Add heart icon to grocery items**
   - **List View**: Add heart icon overlay at **top-left corner** of grocery image
   - **Grid View**: Add heart icon overlay at **top-left corner** of grocery image
   - **Detail View**: Add heart icon overlay at **top-right corner** of grocery image
   - Toggle favorite on tap

4. **Update Favorites screen**
   - Add section for favorited groceries
   - Display groceries with images and scores
   - Allow navigation to grocery details

### Risk Level: MEDIUM-HIGH
- May require new data models
- Grocery data structure may be less defined
- Need to understand grocery storage mechanism

---

## Phase 5: Favorites Screen - Complete Integration (LOW RISK)
**Goal:** Finalize Favorites screen with all item types and filtering

### Tasks:
1. **Add filtering/tabs**
   - Add tabs or filter buttons: "All", "Recipes", "Meals", "Groceries"
   - Filter favorites by type
   - Show counts for each category

2. **Improve empty states**
   - Different messages for each category
   - Suggestions on how to add favorites

3. **Add search functionality**
   - Search across all favorite types
   - Filter results by type

4. **Polish UI**
   - Consistent spacing and styling
   - Smooth animations
   - Loading states

### Risk Level: LOW
- Mostly UI work
- All data models and functionality exist
- Can be refined iteratively

---

## Implementation Order (Recommended)

1. **Phase 1** - Recipes Screen Heart Toggle (Start here - lowest risk)
2. **Phase 2** - Favorites Screen Recipes Display
3. **Phase 3** - Meals Favorite Support
4. **Phase 4** - Groceries Favorite Support
5. **Phase 5** - Complete Integration

---

## Risk Assessment Summary

| Phase | Risk Level | Complexity | Dependencies |
|-------|-----------|------------|--------------|
| Phase 1 | LOW | Low | None |
| Phase 2 | LOW-MEDIUM | Medium | Phase 1 |
| Phase 3 | MEDIUM | Medium-High | Phase 2 |
| Phase 4 | MEDIUM-HIGH | High | Phase 2 |
| Phase 5 | LOW | Low-Medium | Phases 1-4 |

---

## Key Considerations

1. **Data Persistence**
   - Ensure favorites persist across app restarts
   - Handle data migration for existing items
   - Consider iCloud sync if applicable

2. **Performance**
   - Filtering favorites should be fast
   - Consider caching favorite lists
   - Lazy load images in grid view

3. **User Experience**
   - Heart icons should be easily tappable
   - Visual feedback when favoriting/unfavoriting
   - Consistent heart icon styling across all screens

4. **Testing**
   - Test each phase thoroughly before moving to next
   - Test edge cases (empty states, many favorites, etc.)
   - Verify persistence and data integrity

---

## Next Steps

**Recommended:** Start with Phase 1 (Recipes Screen Heart Toggle)
- Lowest risk
- Immediate user value
- Foundation for other phases
- Can be tested independently

Would you like to proceed with Phase 1, or adjust the plan?

