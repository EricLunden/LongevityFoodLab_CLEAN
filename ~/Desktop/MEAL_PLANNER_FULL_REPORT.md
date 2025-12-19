# Meal Planner Feature - Complete Technical Report
**Generated:** December 2024  
**Purpose:** Comprehensive analysis document for AI review and implementation planning

---

## Table of Contents
1. [Feature Overview](#feature-overview)
2. [Architecture & Data Models](#architecture--data-models)
3. [Screen-by-Screen Breakdown](#screen-by-screen-breakdown)
4. [User Flow](#user-flow)
5. [Code Structure](#code-structure)
6. [Integration Points](#integration-points)
7. [Implementation Status](#implementation-status)
8. [Known Issues & Stubs](#known-issues--stubs)
9. [Design System Compliance](#design-system-compliance)

---

## Feature Overview

The Meal Planner is a v1 feature within the Longevity Food Lab iOS app that allows users to create meal plans optimized for longevity and minimal food waste. The feature supports both automatic plan generation (based on user preferences) and manual meal selection.

### Key Features
- **Auto Plan Generation:** AI-assisted meal planning based on dietary preferences, health goals, and meal type selections
- **Manual Plan Building:** User-driven meal selection via calendar interface
- **Intermittent Fasting Support:** Inline configuration for fasting windows and meal timing
- **Recipe Integration:** Uses existing RecipeManager and SpoonacularService for recipe suggestions
- **Shopping List Generation:** Aggregates ingredients from planned meals (stub implementation)
- **Meal Plan Persistence:** Stores plans using UserDefaults via MealPlanManager

### Entry Point
- Accessible via side menu: "Meal Planner" (placed after "Supplements", before "Pet Foods")
- Icon: `fork.knife`
- Navigation: Presented as `.sheet()` modal

---

## Architecture & Data Models

### Core Data Models

#### `MealType` (Enum)
```swift
enum MealType: String, Codable, CaseIterable {
    case breakfast, lunch, dinner, snack, dessert
}
```
- Used throughout the feature to categorize meals
- Has `displayName` computed property for UI display
- When Intermittent Fasting is enabled, "Breakfast" is relabeled as "First Meal"

#### `PlannedMeal` (Struct)
```swift
struct PlannedMeal: Identifiable, Codable {
    let id: UUID
    let recipeID: UUID?           // Optional reference to Recipe
    let mealType: MealType
    let scheduledDate: Date
    let displayTitle: String
    let estimatedLongevityScore: Double?
}
```
- Lightweight model for individual planned meals
- References Recipe via optional `recipeID`
- Stores display title and longevity score for quick access
- No nutrition data stored (v1 constraint)

#### `MealPlan` (Struct)
```swift
struct MealPlan: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    var plannedMeals: [PlannedMeal]
    let createdAt: Date
    var isActive: Bool
}
```
- Container for a collection of planned meals
- Only one plan can be `isActive` at a time
- Date range defines the plan duration

#### `ShoppingList` & `ShoppingListItem` (Structs)
```swift
struct ShoppingList {
    let items: [ShoppingListItem]
}

struct ShoppingListItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: String
    let category: String
    let usedInMeals: Int  // Descriptive count
}
```
- Simple model for shopping list generation
- Currently stub implementation (returns empty list)

### Manager: `MealPlanManager`

**Location:** `LongevityFoodLab/Managers/MealPlanManager.swift`

**Singleton Pattern:** `static let shared = MealPlanManager()`

**Responsibilities:**
- CRUD operations for `MealPlan` objects
- Persistence via `UserDefaults` (key: `"mealPlans"`)
- Query methods: `getPlannedMealsForDate()`, `getPlannedMealsForWeek()`, `getActiveMealPlan()`
- Conversion: `convertPlannedMealToTracked()` (stub)
- Shopping list generation: `generateShoppingList()` (stub)

**Persistence:**
- Saves/loads `[MealPlan]` array as JSON via UserDefaults
- Auto-loads on initialization
- Auto-saves after any modification

**Key Methods:**
- `createMealPlan(startDate:endDate:)` - Creates new plan, deactivates existing active plan
- `addPlannedMeal(_:to:)` - Adds meal to specific plan
- `updateMealPlan(_:)` - Updates entire plan
- `deleteMealPlan(_:)` - Removes plan
- `deletePlannedMeal(_:from:)` - Removes meal from plan

---

## Screen-by-Screen Breakdown

### 1. MealPlannerHomeView
**File:** `LongevityFoodLab/Views/MealPlannerHomeView.swift`  
**Purpose:** Entry screen with two options (Auto Plan vs Manual Plan)

**UI Components:**
- Title: "Meal Planner" with subtitle
- Two `StandardCard` components:
  - **Card A:** "Build My Plan Automatically" (purple-orange gradient icon)
    - Button: "Create Plan" (green gradient)
    - Action: Sets `showingAutoSetup = true`
  - **Card B:** "Build My Plan Manually" (blue-teal gradient icon)
    - Button: "Build Manually" (solid teal)
    - Action: Sets `showingManualCalendar = true`

**Navigation:**
- `.sheet(isPresented: $showingAutoSetup)` → `MealPlannerSetupView()`
- `.sheet(isPresented: $showingManualCalendar)` → `MealPlannerCalendarView(isAutoMode: false)`
- Toolbar: "Done" button dismisses view

**Design:**
- Black background in dark mode
- Uses `StandardCard` reusable component
- Icons have colorful gradients

---

### 2. MealPlannerSetupView
**File:** `LongevityFoodLab/Views/MealPlannerSetupView.swift`  
**Purpose:** Collects user preferences for auto-generated meal plans

**State Variables:**
- `numberOfDays: Int` (default: 7, options: 5 or 7)
- `selectedMeals: Set<MealType>` (default: [.breakfast, .lunch, .dinner])
- `reduceWaste: Bool` (default: true)
- `selectedDietaryPreferences: Set<String>`
- `selectedHealthGoals: Set<String>`
- Intermittent Fasting state (see below)

**Expandable Sections:**
1. **Number of Days**
   - Icon: `calendar` (blue-purple gradient)
   - Options: 5 Days, 7 Days (button selection)
   - Expandable via `expandableSection()` helper

2. **Meals per Day**
   - Icon: `fork.knife` (orange gradient)
   - Toggles for each `MealType`
   - If Intermittent Fasting enabled, "Breakfast" → "First Meal"

3. **Dietary Preferences**
   - Icon: `leaf.fill` (green-teal gradient)
   - Options:
     - Classic (everything, no restrictions)
     - Mediterranean (Top-rated healthy diet)
     - Flexitarian (mostly plant-based with occasional meat)
     - Low Carb
     - Pescatarian (fish and seafood but no other meat)
     - Vegetarian
     - Paleo
     - Keto
     - Vegan (fully plant-based)
     - Intermittent Fasting
   - Uses checkboxes (Toggle components)
   - Pre-loads selections from `UserHealthProfileManager`

4. **Health Goals**
   - Icon: `heart.fill` (red-pink gradient)
   - All 15 health goal options with checkboxes
   - Pre-loads from `UserHealthProfileManager.getHealthGoals()`

5. **Reduce Food Waste Toggle**
   - Standalone toggle (not expandable)
   - Text: "Reduce food waste by reusing ingredients"

**Intermittent Fasting Configuration:**
When "Intermittent Fasting" is selected, reveals inline configuration:

- **Fasting Style Selection** (radio-style):
  - 16:8 (Most common) - Default: 12:00 PM - 8:00 PM
  - 14:10 (Beginner-friendly) - Default: 10:00 AM - 8:00 PM
  - 18:6 (Advanced) - Default: 12:00 PM - 6:00 PM
  - Custom - Default: 12:00 PM - 8:00 PM

- **Eating Window** (shown after style selected):
  - Start Time: `DatePicker` (hour and minute)
  - End Time: `DatePicker` (hour and minute)
  - Auto-populates based on selected style
  - User can override

- **Meal Timing Note:**
  - Read-only text: "Meals will be planned between [start] – [end]."

- **Optional Reminders:**
  - Toggle: "Enable fasting reminders"
  - If enabled, shows:
    - "Reminder when fasting starts" (shows end time)
    - "Reminder when eating window opens" (shows start time)
  - Note: UI only, no notification implementation (v1 constraint)

- **Summary Display:**
  - Shown above "Generate Meal Plan" button
  - Format: "Intermittent Fasting: [style] Eating Window: [start] – [end]"

**Primary Action:**
- Button: "Generate Meal Plan" (green gradient, pinned at bottom)
- Action: `generateMealPlan()`
  - Creates `MealPlan` via `MealPlanManager.shared.createMealPlan()`
  - Sets `showingCalendar = true` (presents calendar sheet)

**Navigation:**
- `.sheet(isPresented: $showingCalendar)` → `MealPlannerCalendarView(isAutoMode: true)`
- Toolbar: "Back" button dismisses

**Profile Integration:**
- `loadProfileSelections()` called in `onAppear`
- Loads dietary preferences and health goals from `UserHealthProfileManager`
- Uses fuzzy matching for preference strings

---

### 3. MealPlannerCalendarView
**File:** `LongevityFoodLab/Views/MealPlannerCalendarView.swift`  
**Purpose:** Weekly calendar view for viewing/editing meal plans

**Props:**
- `isAutoMode: Bool` - Determines if plan was auto-generated or manually created

**State:**
- `selectedWeekStart: Date` - Controls which week is displayed
- `showingRecipeSelection: MealType?` - Controls recipe selection sheet
- `selectedDate: Date` - Date for meal being added/edited
- `currentMealPlan: MealPlan?` - Active plan being edited
- `showingSummary: Bool` - Controls summary sheet

**UI Layout:**
1. **Week Selector:**
   - `DatePicker` with `.graphical` style
   - User selects week start date
   - Horizontal padding: 20pt

2. **Weekly Meal Plan (Vertical Layout):**
   - ScrollView with VStack
   - For each day in week:
     - Day header: "EEEE, MMM d" format
     - Meal slots for each `MealType`
     - Each slot is either:
       - `mealSlotCard()` - Shows planned meal with image placeholder, title, meal type, score badge
       - `emptyMealSlot()` - Dashed border, "+ Add [MealType]" button

**Meal Slot Card:**
- Image placeholder: 60x60 gray rectangle with "photo" icon
- Title: `meal.displayTitle`
- Meal type: `mealType.displayName`
- Score badge: 60x60 circular badge (if `estimatedLongevityScore` exists)
  - Score colors:
    - 80-100: Teal (0.42, 0.557, 0.498)
    - 60-79: Light teal (0.502, 0.706, 0.627)
    - 40-59: Orange
    - <40: Red

**Empty Meal Slot:**
- Dashed border: `StrokeStyle(lineWidth: 1, dash: [5])`
- Text: "+ Add [MealType]"
- Tapping opens `RecipeSelectionDrawerView`

**Actions:**
- Tapping any meal slot (filled or empty) opens recipe selection
- "Next" button in toolbar:
  - If plan exists: Shows summary sheet
  - Else: Calls `saveMealPlan()` and dismisses

**Data Loading:**
- `onAppear` calls `loadOrCreateMealPlan()`
  - If active plan exists: Loads it
  - Else: Creates new plan for selected week

**Recipe Selection Integration:**
- `.sheet(item:)` presents `RecipeSelectionDrawerView`
- Uses `MealTypeWrapper` helper struct for sheet binding
- On recipe selection: `addMealToPlan()` creates `PlannedMeal` and adds to plan

**Navigation:**
- Toolbar: "Back" button dismisses
- Toolbar: "Next" button shows summary or saves
- `.sheet(isPresented: $showingSummary)` → `MealPlanSummaryView(mealPlan:)`

---

### 4. RecipeSelectionDrawerView
**File:** `LongevityFoodLab/Views/RecipeSelectionDrawerView.swift`  
**Purpose:** Bottom sheet for selecting recipes for a meal slot

**Props:**
- `mealType: MealType` - Type of meal being planned
- `scheduledDate: Date` - Date meal is scheduled for
- `onRecipeSelected: (Recipe) -> Void` - Callback when recipe selected

**State:**
- `savedRecipes: [Recipe]` - User's saved recipes (filtered by meal type)
- `suggestedRecipes: [Recipe]` - Spoonacular suggestions (if needed)
- `isLoadingSuggestions: Bool` - Loading state
- `showingSuggestions: Bool` - Whether to show suggestions section

**Dependencies:**
- `@StateObject private var recipeManager = RecipeManager.shared`
- `@StateObject private var spoonacularService = SpoonacularService.shared`

**UI Sections:**

1. **Your Saved Recipes:**
   - Header: "Your Saved Recipes"
   - If empty: Shows "No saved recipes found"
   - Else: `LazyVStack` of `recipeCard()` components
   - Filtered by meal type category (breakfast/lunch/dinner/snack/dessert)

2. **Suggested for This Plan** (conditional):
   - Only shown if `savedRecipes.count < 3`
   - Header: "Suggested for This Plan"
   - Loading state: `ProgressView`
   - Empty state: "No suggestions available"
   - Else: `LazyVStack` of suggested recipe cards

**Recipe Card:**
- Image: 60x60 (AsyncImage from URL, or local photo, or placeholder)
- Title: Recipe title (2-line limit)
- Info: Prep time (if > 0), "Suggested recipe" badge (if suggested)
- Score badge: 60x60 circular (if `longevityScore` exists)
- Tapping: Calls `onRecipeSelected(recipe)` and dismisses

**Data Loading:**
- `onAppear`:
  ```swift
  Task {
      await recipeManager.loadRecipes()  // Loads from disk
      loadSavedRecipes()                  // Filters by meal type
      checkIfSuggestionsNeeded()          // Shows suggestions if < 3 recipes
  }
  ```

**Suggestion Logic:**
- If `savedRecipes.count < 3`:
  - Sets `showingSuggestions = true`
  - Calls `loadSuggestedRecipes()`
- `loadSuggestedRecipes()`:
  - Converts `mealType` to Spoonacular type parameter
  - Calls `spoonacularService.searchRecipes(type:number:5)`
  - Converts results via `spoonacularService.convertToRecipe()`
  - Updates `suggestedRecipes` array

**Comments in Code:**
- Recipe source priority: Saved → Supabase cache → Spoonacular
- Ingredient overlap logic (conceptual, not implemented)
- Favor higher longevity scores (conceptual)
- Cache Spoonacular recipes to Supabase (conceptual)

**Navigation:**
- Toolbar: "Cancel" button dismisses
- Title: "Select Recipe"

---

### 5. MealPlanSummaryView
**File:** `LongevityFoodLab/Views/MealPlanSummaryView.swift`  
**Purpose:** Summary screen shown after plan generation/editing

**Props:**
- `mealPlan: MealPlan` - Plan to summarize

**Computed Properties:**
- `averageScore: Double` - Average of all meal longevity scores
- `ingredientReuseCount: Int` - Stub (returns `mealPlan.plannedMeals.count / 2`)

**UI Components:**

1. **Large Longevity Score Display:**
   - 120x120 circular badge
   - Gradient background based on score (via `scoreGradient()`)
   - Large number: `Int(averageScore)`
   - Label: "Longevity Score"

2. **Summary Cards** (3 cards):

   **Card 1: Longevity Focus**
   - Icon: `heart.circle.fill` (red-pink gradient)
   - Title: "Longevity Focus"
   - Description: "This plan prioritizes foods that support long-term health and vitality."

   **Card 2: Ingredient Reuse**
   - Icon: `arrow.triangle.2.circlepath` (green-teal gradient)
   - Title: "Ingredient Reuse"
   - Description: "This plan reuses ingredients across meals to reduce waste and cost."
   - Caption: "Approximately [count] ingredients reused"

   **Card 3: Waste Reduction**
   - Icon: `leaf.fill` (green-teal gradient)
   - Title: "Waste Reduction"
   - Description: "By planning meals that share ingredients, you'll minimize leftover ingredients and reduce food waste."

3. **Bottom Buttons:**
   - **Save Plan:** Green gradient button
     - Action: `saveMealPlan()` → dismisses
   - **Edit Plan:** Solid teal button
     - Action: Sets `showingCalendar = true`

**Score Gradient Logic:**
- 0-40: Red → Orange
- 40-60: Orange → Yellow
- 60-80: Yellow → Green
- 80-100: Dark green → Darker green

**Navigation:**
- Toolbar: "Back" button dismisses
- `.sheet(isPresented: $showingCalendar)` → `MealPlannerCalendarView(isAutoMode: false)`

---

### 6. ShoppingListView
**File:** `LongevityFoodLab/Views/ShoppingListView.swift`  
**Purpose:** Generates and displays shopping list from meal plan

**Props:**
- `mealPlan: MealPlan` - Plan to generate list from

**Computed Properties:**
- `shoppingList: ShoppingList` - **STUB** (returns empty `ShoppingList()`)
- `groupedItems: [String: [ShoppingListItem]]` - Groups items by category

**Categories:**
- Produce
- Meat & Seafood
- Dairy
- Pantry
- Other

**UI Components:**

1. **Top Callout Card:**
   - Icon: `leaf.fill` (green-teal gradient)
   - Text: "Designed to minimize leftover ingredients"

2. **Grouped Shopping List:**
   - For each category:
     - Category header (headline font)
     - List of items in that category
     - Each item shows:
       - Checkbox (circle icon, not functional)
       - Name and quantity
       - "Used in X meals" caption (if > 1)

**Current Status:**
- Shopping list generation is **stub implementation**
- Returns empty list
- UI is complete but shows no data

**Navigation:**
- Toolbar: "Back" button dismisses
- Title: "Shopping List"

---

## User Flow

### Auto Plan Flow
1. User taps "Meal Planner" in side menu → `MealPlannerHomeView`
2. User taps "Create Plan" → `MealPlannerSetupView`
3. User configures:
   - Number of days (5 or 7)
   - Meals per day (breakfast/lunch/dinner/snack/dessert)
   - Dietary preferences (with optional Intermittent Fasting config)
   - Health goals
   - Reduce waste toggle
4. User taps "Generate Meal Plan" → Creates `MealPlan` → `MealPlannerCalendarView(isAutoMode: true)`
5. User views calendar (initially empty meal slots)
6. User taps "+ Add [MealType]" → `RecipeSelectionDrawerView`
7. User selects recipe → Meal added to plan → Returns to calendar
8. User taps "Next" → `MealPlanSummaryView`
9. User reviews summary → Taps "Save Plan" → Dismisses

### Manual Plan Flow
1. User taps "Meal Planner" in side menu → `MealPlannerHomeView`
2. User taps "Build Manually" → `MealPlannerCalendarView(isAutoMode: false)`
3. User selects week via DatePicker
4. User taps "+ Add [MealType]" → `RecipeSelectionDrawerView`
5. User selects recipe → Meal added to plan → Returns to calendar
6. User repeats steps 4-5 for desired meals
7. User taps "Next" → `MealPlanSummaryView`
8. User reviews summary → Taps "Save Plan" or "Edit Plan"

### Intermittent Fasting Flow (within Auto Plan)
1. User selects "Intermittent Fasting" in Dietary Preferences
2. Inline configuration appears:
   - Select fasting style (16:8, 14:10, 18:6, Custom)
   - Eating window auto-populates based on style
   - User can adjust times
   - Optional reminders toggle
3. Summary displays above "Generate Meal Plan" button
4. "Breakfast" relabeled as "First Meal" in Meals per Day section
5. Plan generation respects eating window (conceptual, not enforced in v1)

---

## Code Structure

### File Organization
```
LongevityFoodLab/
├── Models/
│   └── MealPlan.swift                    # Data models (MealType, PlannedMeal, MealPlan)
├── Managers/
│   └── MealPlanManager.swift              # Singleton manager for CRUD operations
└── Views/
    ├── MealPlannerHomeView.swift          # Entry screen
    ├── MealPlannerSetupView.swift          # Auto plan preferences
    ├── MealPlannerCalendarView.swift       # Weekly calendar view
    ├── RecipeSelectionDrawerView.swift     # Recipe selection sheet
    ├── MealPlanSummaryView.swift          # Plan summary
    └── ShoppingListView.swift             # Shopping list (stub)
```

### Reusable Components
- **StandardCard:** Generic card component with border, shadow, dark mode support
  - Defined in `MealPlannerHomeView.swift`
  - Used across multiple screens

### Helper Functions
- **expandableSection()** (MealPlannerSetupView): Creates expandable UI sections
- **iconGradient()** (MealPlannerSetupView): Returns gradient for icons based on name
- **formatTime()** (MealPlannerSetupView): Formats Date to time string
- **scoreColor()** (MealPlannerCalendarView, RecipeSelectionDrawerView): Returns color for score ranges
- **scoreGradient()** (MealPlanSummaryView): Returns gradient for score badge

---

## Integration Points

### RecipeManager Integration
- **Location:** `LongevityFoodLab/Managers/RecipeManager.swift`
- **Usage:** `RecipeManager.shared` accessed in:
  - `RecipeSelectionDrawerView` - Loads saved recipes
  - `MealPlannerCalendarView` - References for recipe data
- **Key Method:** `await recipeManager.loadRecipes()` - Must be called before accessing `recipes` array
- **Recipe Model:** Uses existing `Recipe` struct with:
  - `id: UUID`
  - `title: String`
  - `longevityScore: Int?`
  - `categories: [RecipeCategory]`
  - `image: String?` (URL)
  - `photos: [String]` (local asset names)
  - `prepTime: Int`

### SpoonacularService Integration
- **Location:** `LongevityFoodLab/Views/SpoonacularService.swift` (assumed)
- **Usage:** `SpoonacularService.shared` accessed in `RecipeSelectionDrawerView`
- **Key Methods:**
  - `searchRecipes(query:type:number:)` - Searches Spoonacular API
  - `convertToRecipe(_:)` - Converts Spoonacular result to app's Recipe format
- **Fallback Logic:** Used when user has < 3 saved recipes matching meal type

### UserHealthProfileManager Integration
- **Location:** `LongevityFoodLab/Managers/UserHealthProfileManager.swift`
- **Usage:** `UserHealthProfileManager.shared` accessed in `MealPlannerSetupView`
- **Key Methods:**
  - `currentProfile?.dietaryPreference` - Gets user's dietary preference
  - `getHealthGoals()` - Gets user's health goals array
- **Pre-population:** `loadProfileSelections()` matches profile data to setup options

### MealStorageManager Integration (Conceptual)
- **Location:** `LongevityFoodLab/MealStorageManager.swift`
- **Usage:** `MealPlanManager.convertPlannedMealToTracked()` creates `TrackedMeal`
- **Purpose:** Convert planned meals to tracked meals when consumed
- **Status:** Stub implementation only

### Navigation Integration
- **Side Menu:** `SearchView.swift` → `SideMenuView`
  - Menu item: "Meal Planner" with `fork.knife` icon
  - Position: After "Supplements", before "Pet Foods"
  - Action: Sets `showingMealPlanner = true`
  - Presentation: `.sheet(isPresented: $showingMealPlanner) { MealPlannerHomeView() }`

---

## Implementation Status

### ✅ Fully Implemented
1. **Data Models:** Complete and functional
2. **MealPlanManager:** CRUD operations, persistence, query methods
3. **MealPlannerHomeView:** Entry screen with two options
4. **MealPlannerSetupView:** All preference collection, Intermittent Fasting config
5. **MealPlannerCalendarView:** Weekly calendar, meal slot display, recipe selection trigger
6. **RecipeSelectionDrawerView:** Recipe loading, filtering, Spoonacular fallback
7. **MealPlanSummaryView:** Summary display with metrics
8. **ShoppingListView:** UI complete (data generation stub)
9. **Navigation Flow:** All screens connected via sheets
10. **Design System:** Black backgrounds in dark mode, gradient icons, StandardCard usage

### ⚠️ Partially Implemented / Stubs
1. **Auto Plan Generation Logic:**
   - `generateMealPlan()` creates empty plan
   - No AI/algorithm to populate meals based on preferences
   - User must manually add meals after generation

2. **Shopping List Generation:**
   - `generateShoppingList()` returns empty list
   - UI is complete but shows no data
   - Comment indicates need to aggregate ingredients from recipes

3. **Ingredient Reuse Logic:**
   - "Reduce waste" toggle exists but not enforced
   - No ingredient overlap analysis
   - No prioritization of recipes with shared ingredients

4. **Recipe Caching:**
   - Spoonacular recipes not cached to Supabase
   - Comments indicate conceptual Supabase integration

5. **Meal-to-Tracked Conversion:**
   - `convertPlannedMealToTracked()` is stub
   - Creates basic TrackedMeal but doesn't integrate with MealStorageManager

6. **Intermittent Fasting Enforcement:**
   - UI configuration complete
   - No enforcement of eating window in meal planning
   - "Breakfast" → "First Meal" relabeling works, but no time-based filtering

### ❌ Not Implemented
1. **AI Meal Plan Generation:** No algorithm to auto-populate meals
2. **Ingredient Analysis:** No parsing/aggregation of recipe ingredients
3. **Supabase Integration:** No actual Supabase calls for recipe caching
4. **Notification System:** Reminder toggles exist but no notification implementation
5. **Meal Plan Editing:** Can add meals, but no delete/edit existing meals in calendar
6. **Plan History:** No view of past meal plans
7. **Plan Sharing:** No export/share functionality

---

## Known Issues & Stubs

### Critical Issues
1. **Recipe Loading:** `RecipeSelectionDrawerView` must call `await recipeManager.loadRecipes()` before accessing recipes (fixed in current code)
2. **Navigation Flow:** `generateMealPlan()` was dismissing before showing calendar (fixed in current code)

### Stub Implementations
1. **Shopping List Generation:**
   ```swift
   func generateShoppingList(from meals: [PlannedMeal]) -> ShoppingList {
       return ShoppingList(items: [])  // Stub
   }
   ```

2. **Meal-to-Tracked Conversion:**
   ```swift
   func convertPlannedMealToTracked(_ plannedMeal: PlannedMeal) -> TrackedMeal {
       // Stub implementation
   }
   ```

3. **Ingredient Reuse Count:**
   ```swift
   private var ingredientReuseCount: Int {
       return mealPlan.plannedMeals.count / 2  // Placeholder
   }
   ```

### Conceptual Comments
Multiple files contain comments indicating future implementation:
- Supabase recipe caching
- Ingredient overlap analysis
- Longevity score prioritization
- Eating window enforcement

---

## Design System Compliance

### Colors
- **Primary Teal:** `Color(red: 0.42, green: 0.557, blue: 0.498)`
- **Light Teal:** `Color(red: 0.502, green: 0.706, blue: 0.627)`
- **Border Teal:** `Color(red: 0.608, green: 0.827, blue: 0.835)`
- **Green Gradient:** `Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0)` → `Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)`

### Typography
- **Large Title:** `.largeTitle`, `.bold`
- **Title:** `.title2`, `.semibold`
- **Headline:** `.headline`, `.semibold`
- **Body:** `.body`
- **Caption:** `.caption`
- **Subheadline:** `.subheadline`

### Spacing
- **Screen Padding:** 20pt horizontal
- **Section Spacing:** 16-20pt vertical
- **Card Padding:** 20pt internal
- **Button Padding:** 12-15pt vertical, 20-24pt horizontal

### Dark Mode
- **Background:** `Color.black` (dark mode), `Color(UIColor.systemBackground)` (light mode)
- **Card Background:** `Color.black` (dark mode), `Color(UIColor.secondarySystemBackground)` (light mode)
- **Border Opacity:** 1.0 (dark mode), 0.6 (light mode)
- **Border Width:** 1.0pt (dark mode), 0.5pt (light mode)

### Icons
- All icons use `LinearGradient` foreground styles
- Icon sizes: 32-40pt for section headers, 60x60pt for badges
- SF Symbols used throughout

### Components
- **StandardCard:** Reusable card with border, shadow, dark mode support
- **Score Badges:** 60x60 circular badges with gradient backgrounds
- **Expandable Sections:** Smooth animations, chevron indicators

---

## Recommendations for Next AI

### High Priority
1. **Implement Auto Plan Generation:**
   - Use preferences from `MealPlannerSetupView`
   - Query `RecipeManager` for recipes matching dietary preferences and health goals
   - Filter by meal type
   - Prioritize recipes with higher longevity scores
   - If "Reduce waste" enabled, analyze ingredient overlap
   - Populate `MealPlan` with `PlannedMeal` objects

2. **Implement Shopping List Generation:**
   - Parse ingredients from recipes referenced in `PlannedMeal.recipeID`
   - Aggregate quantities (handle unit conversions)
   - Group by grocery category
   - Count usage across meals
   - Return populated `ShoppingList`

3. **Add Meal Editing:**
   - Allow deletion of planned meals in calendar view
   - Allow swapping recipes for existing meals
   - Add swipe-to-delete gesture

### Medium Priority
1. **Ingredient Overlap Analysis:**
   - Parse recipe ingredients (may need to extend Recipe model)
   - Compare ingredient lists across planned meals
   - Prioritize recipes with shared ingredients when "Reduce waste" enabled

2. **Intermittent Fasting Enforcement:**
   - Filter meal suggestions by eating window
   - Hide meal slots outside eating window
   - Enforce meal timing in auto generation

3. **Supabase Recipe Caching:**
   - Cache Spoonacular recipes to Supabase `recipes_cache` table
   - Check cache before calling Spoonacular API
   - Update `tier_used` field

### Low Priority
1. **Plan History View:**
   - List of past meal plans
   - Ability to reactivate old plans

2. **Notification System:**
   - Implement local notifications for fasting reminders
   - Schedule based on eating window times

3. **Meal Plan Export:**
   - Share plan as text/image
   - Export shopping list

---

## Technical Notes

### Persistence
- All meal plans stored in `UserDefaults` as JSON
- Key: `"mealPlans"`
- Array of `MealPlan` objects
- Auto-saves on any modification

### Threading
- `MealPlanManager` is `ObservableObject` but not marked `@MainActor`
- Recipe loading uses `Task` and `await` for async operations
- UI updates wrapped in `MainActor.run` where needed

### Error Handling
- Minimal error handling in current implementation
- Recipe loading failures print to console
- No user-facing error messages

### Performance
- Recipe loading happens on-demand in `RecipeSelectionDrawerView`
- No pre-loading or caching of recipe data
- Shopping list generation is synchronous (stub)

---

## Conclusion

The Meal Planner feature is **structurally complete** with all screens, navigation, and data models in place. The UI follows the design system consistently, and the basic CRUD operations work correctly. However, the **core intelligence** (auto plan generation, ingredient analysis, shopping list generation) remains as stub implementations.

The feature is ready for:
- ✅ UI/UX testing
- ✅ Manual meal planning workflow
- ⚠️ Auto plan generation (needs algorithm implementation)
- ❌ Shopping list generation (needs ingredient parsing)

The codebase is well-organized, follows SwiftUI best practices, and includes helpful comments indicating future implementation directions.

---

**End of Report**

