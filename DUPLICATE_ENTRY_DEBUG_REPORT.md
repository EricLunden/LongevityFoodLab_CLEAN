# Duplicate Entry Bug - Technical Debug Report
**Date:** 2026-01-01  
**Issue:** Type It and Say It entries are creating duplicate meals in the tracker  
**Status:** Debug logging added, root cause investigation in progress

---

## Problem Summary

### Symptoms
1. **Type It entries:** Creating two identical entries (e.g., "Scrambled eggs" appears twice)
2. **Say It entries:** Creating two entries with different icons (keyboard vs microphone), suggesting different `inputMethod` values are being stored

### User Observations
- One "Type It" entry for "Scrambled eggs" → Two entries appear in tracker
- One "Say It" entry for "Two slices of sourdough bread" → Two entries appear (one with keyboard icon, one with mic icon)
- Both entries have identical scores and names
- Issue appears to be specific to text/voice entries (no imageHash)

---

## Code Flow Analysis

### Entry Point: SearchView (Type It / Say It)

**File:** `LongevityFoodLab/SearchView.swift`

**Lines 995-1035:** `analyzeFood()` function
- Called when user submits text/voice input
- Creates `FoodAnalysis` via `AIService.shared.analyzeFoodWithProfile()`
- Calls `onFoodDetected(analysis, nil, nil, inputMethod)` where:
  - `image = nil` (no image)
  - `imageHash = nil` (no image hash)
  - `inputMethod = "text"` or `"voice"` (line 1021, 1029)

**Key Code:**
```swift
let inputMethod = self.isVoiceInput ? "voice" : "text"
self.isVoiceInput = false // Reset after use
onFoodDetected(analysis, nil, nil, inputMethod)
```

---

### Step 1: ContentView Receives Callback

**File:** `LongevityFoodLab/ContentView.swift`

**Lines 41-60:** `onFoodDetected` closure
- Receives analysis with `image = nil`, `imageHash = nil`, `inputMethod = "text"/"voice"`
- Caches analysis to `FoodCacheManager`:
  ```swift
  else if image == nil && imageHash == nil {
      // New analysis without image (text input, voice, etc.) - save it
      print("🔍 ContentView: Saving new analysis without image, inputMethod: \(inputMethod ?? "unknown")")
      foodCacheManager.cacheAnalysis(analysis, inputMethod: inputMethod)
  }
  ```
- Sets `showingResults = true` to display `ResultsView`

**Key Point:** Analysis is cached ONCE here with the correct `inputMethod`.

---

### Step 2: ResultsView Displayed

**File:** `LongevityFoodLab/ResultsView.swift`

**Lines 179-192:** `ResultsView` is created in ContentView sheet
- Receives `analysis: FoodAnalysis`
- Has `onMealAdded` callback that switches to tracker tab

**Lines 621-637:** `AddToMealTrackerSheet` sheet presentation
- Sheet is shown when user taps "Add to Meal Tracker" button
- `onSave` callback (lines 626-631):
  ```swift
  onSave: { savedMeal in
      showingAddToMealTracker = false
      // Switch to meal tracker tab after adding meal
      onMealAdded?()
      // Dismiss the analysis screen
      dismiss()
  }
  ```
- **IMPORTANT:** This callback does NOT save the meal again - it only dismisses views

---

### Step 3: AddToMealTrackerSheet.saveMeal()

**File:** `LongevityFoodLab/ResultsView.swift`

**Lines 6086-6206:** `saveMeal()` function

**Current Implementation:**

1. **Debug Logging Added (Lines 6087-6091):**
   ```swift
   print("🔴 SAVEMEAL CALLED")
   print("🔴 Call stack:")
   for symbol in Thread.callStackSymbols.prefix(10) {
       print(symbol)
   }
   ```

2. **Cache Lookup (Lines 6094-6116):**
   - Attempts to find cached entry by matching:
     - `foodName == analysis.foodName`
     - `overallScore == analysis.overallScore`
     - `summary == analysis.summary` (exact match)
   - Falls back to name+score match if exact match fails
   - Retrieves `imageHash` and `inputMethod` from cache entry

3. **Duplicate Detection (Lines 6120-6175):**
   - For text/voice entries (`imageHash == nil`):
     ```swift
     let isTextVoiceEntry = imageHash == nil
     if isTextVoiceEntry {
         existingMeal = mealStorageManager.trackedMeals.first { meal in
             let nameMatch = meal.name == mealNameToUse
             let scoreMatch = abs(meal.healthScore - Double(analysis.overallScore)) < 1.0
             let isTextVoiceMeal = meal.imageHash == nil
             let analysisMatch = meal.originalAnalysis?.foodName == analysis.foodName &&
                                meal.originalAnalysis?.overallScore == analysis.overallScore
             let isMatch = (nameMatch && scoreMatch && isTextVoiceMeal) || analysisMatch
             return isMatch
         }
     }
     ```

4. **Save Logic (Lines 6177-6205):**
   - If duplicate found: calls `onSave(existing)` and returns early
   - If no duplicate: creates `TrackedMeal` and calls `mealStorageManager.addMeal(trackedMeal)`
   - Then calls `onSave(trackedMeal)`

**Potential Issues:**
- Duplicate detection relies on `mealStorageManager.trackedMeals` being up-to-date
- If `saveMeal()` is called twice rapidly, second call might not see first meal yet
- Cache lookup might fail if multiple cache entries exist with same name+score but different `inputMethod`

---

### Step 4: MealStorageManager.addMeal()

**File:** `LongevityFoodLab/MealStorageManager.swift`

**Lines 18-22:** `addMeal()` function
```swift
func addMeal(_ meal: TrackedMeal) {
    print("🍽️ MealStorageManager: Adding meal: \(meal.name)")
    trackedMeals.append(meal)
    saveMeals()
}
```

**Key Finding:** 
- **NO duplicate checking** - simply appends meal to array
- Relies entirely on caller (`saveMeal()`) to prevent duplicates
- Saves immediately to `UserDefaults`

**Potential Issue:**
- If `saveMeal()` is called twice before first save completes, both meals could be added

---

## Potential Root Causes

### Hypothesis 1: Double Call to saveMeal()
**Likelihood:** HIGH

**Evidence:**
- User reports seeing exactly 2 entries for each Type It/Say It entry
- Debug logging added to detect multiple calls

**Possible Causes:**
1. Button double-tap (user taps "Add to Meal Tracker" twice quickly)
2. SwiftUI sheet/button state issue causing double invocation
3. Multiple event handlers attached to same button

**Investigation Needed:**
- Check console output for `🔴 SAVEMEAL CALLED` - should appear exactly once per save
- Review call stack to identify what triggers the call

---

### Hypothesis 2: Duplicate Detection Logic Failure
**Likelihood:** MEDIUM

**Evidence:**
- Duplicate detection exists but may have timing issues
- Cache lookup might return wrong entry or fail entirely

**Possible Causes:**
1. **Timing Issue:** `saveMeal()` called twice before first meal appears in `trackedMeals` array
   - First call: `trackedMeals` is empty → no duplicate found → saves meal
   - Second call: `trackedMeals` still empty (not updated yet) → no duplicate found → saves meal again

2. **Cache Lookup Failure:** Multiple cache entries with same name+score but different `inputMethod`
   - First call: Finds cache entry with `inputMethod = "text"` → saves meal
   - Second call: Finds different cache entry with `inputMethod = "voice"` → saves meal again
   - This would explain why Say It entries show different icons

3. **Analysis Object Comparison Failure:**
   - `originalAnalysis` comparison might fail if objects are not identical references
   - `analysisMatch` check might not work correctly

**Investigation Needed:**
- Check if `mealStorageManager.trackedMeals` is updated synchronously or asynchronously
- Verify cache lookup returns consistent results
- Check if multiple cache entries exist for same food

---

### Hypothesis 3: Multiple Save Paths
**Likelihood:** LOW (but possible)

**Evidence:**
- `SelectMealsView.handleAnalysisResult()` automatically saves meals for image entries
- Could there be a similar automatic save for text/voice entries?

**Investigation Needed:**
- Search for all places where `mealStorageManager.addMeal()` is called
- Verify no automatic save happens for text/voice entries

---

## Code Locations Reference

### Key Files

1. **SearchView.swift**
   - Lines 995-1035: `analyzeFood()` - Creates analysis and calls `onFoodDetected`

2. **ContentView.swift**
   - Lines 41-60: `onFoodDetected` closure - Caches analysis and shows ResultsView
   - Lines 179-192: `ResultsView` creation with `onMealAdded` callback

3. **ResultsView.swift**
   - Lines 621-637: `AddToMealTrackerSheet` sheet with `onSave` callback
   - Lines 5950-6206: `AddToMealTrackerSheet` struct and `saveMeal()` function
   - Lines 6086-6206: `saveMeal()` implementation with duplicate detection

4. **MealStorageManager.swift**
   - Lines 18-22: `addMeal()` - No duplicate checking, just appends

5. **FoodCacheManager.swift**
   - Lines 28-56: `cacheAnalysis()` - Stores analysis with `inputMethod`

---

## Debugging Steps Taken

### Step 1: Added Call Stack Logging
**Location:** `ResultsView.swift`, line 6087-6091

**Purpose:** Detect if `saveMeal()` is being called multiple times

**Code Added:**
```swift
print("🔴 SAVEMEAL CALLED")
print("🔴 Call stack:")
for symbol in Thread.callStackSymbols.prefix(10) {
    print(symbol)
}
```

**Next Steps:**
- Run app and create Type It entry
- Check console for number of `🔴 SAVEMEAL CALLED` messages
- Review call stack to identify trigger source

---

## Recommended Fixes

### Fix 1: Add Guard Against Double-Tap (If Double Call Confirmed)

**Location:** `ResultsView.swift`, `AddToMealTrackerSheet` struct

**Solution:** Add `@State` flag to prevent multiple simultaneous saves

```swift
@State private var isSaving = false

private func saveMeal() {
    guard !isSaving else {
        print("⚠️ AddToMealTrackerSheet: Save already in progress, ignoring duplicate call")
        return
    }
    isSaving = true
    defer { isSaving = false }
    
    // ... existing save logic ...
}
```

---

### Fix 2: Improve Duplicate Detection Timing (If Timing Issue Confirmed)

**Location:** `ResultsView.swift`, `saveMeal()` function

**Solution:** Check `trackedMeals` after ensuring it's up-to-date, or add synchronous save

**Option A:** Force synchronous update
```swift
// Before duplicate check, ensure trackedMeals is current
mealStorageManager.objectWillChange.send()
```

**Option B:** Use more robust duplicate check
```swift
// Check by ID if available, or use stricter matching
let existingMeal = mealStorageManager.trackedMeals.first { meal in
    // Match by originalAnalysis object reference if possible
    if let original = meal.originalAnalysis,
       let current = analysis as? FoodAnalysis,
       original === current {
        return true
    }
    // Fallback to name+score+timestamp check
    return meal.name == mealNameToUse &&
           abs(meal.healthScore - Double(analysis.overallScore)) < 1.0 &&
           meal.imageHash == nil &&
           abs(meal.timestamp.timeIntervalSinceNow) < 5.0 // Within 5 seconds
}
```

---

### Fix 3: Add Duplicate Check in MealStorageManager (Defense in Depth)

**Location:** `MealStorageManager.swift`, `addMeal()` function

**Solution:** Add duplicate check as final safeguard

```swift
func addMeal(_ meal: TrackedMeal) {
    // Check for duplicate before adding
    let isDuplicate = trackedMeals.contains { existing in
        // For text/voice entries (no imageHash), match by name+score+recent timestamp
        if meal.imageHash == nil && existing.imageHash == nil {
            return existing.name == meal.name &&
                   abs(existing.healthScore - meal.healthScore) < 1.0 &&
                   abs(existing.timestamp.timeIntervalSince(meal.timestamp)) < 5.0
        }
        // For image entries, match by imageHash
        if let mealHash = meal.imageHash, let existingHash = existing.imageHash {
            return mealHash == existingHash
        }
        // Fallback: match by ID (shouldn't happen)
        return existing.id == meal.id
    }
    
    if isDuplicate {
        print("⚠️ MealStorageManager: Duplicate meal detected, skipping: \(meal.name)")
        return
    }
    
    print("🍽️ MealStorageManager: Adding meal: \(meal.name)")
    trackedMeals.append(meal)
    saveMeals()
}
```

---

### Fix 4: Fix Cache Lookup for Text/Voice Entries (If Cache Issue Confirmed)

**Location:** `ResultsView.swift`, `saveMeal()` function, cache lookup section

**Solution:** Ensure cache lookup finds the correct entry with matching `inputMethod`

```swift
// First, try to find by matching the analysis object directly AND inputMethod
if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
    entry.foodName == analysis.foodName &&
    entry.fullAnalysis.overallScore == analysis.overallScore &&
    entry.fullAnalysis.summary == analysis.summary &&
    entry.inputMethod == inputMethod // Add inputMethod match for text/voice entries
}) {
    imageHash = cachedEntry.imageHash
    inputMethod = cachedEntry.inputMethod
}
```

---

## Testing Plan

### Test 1: Verify Double Call
1. Run app with debug logging
2. Create Type It entry: "test food"
3. Tap "Add to Meal Tracker" once
4. Check console:
   - Count `🔴 SAVEMEAL CALLED` messages
   - If 2+ messages → Double call confirmed
   - Review call stack to identify source

### Test 2: Verify Duplicate Detection
1. Add logging to duplicate detection logic
2. Create Type It entry
3. Check logs:
   - Does duplicate check run?
   - Does it find existing meal?
   - What values are being compared?

### Test 3: Verify Cache Lookup
1. Add logging to cache lookup
2. Create Type It entry
3. Check logs:
   - How many cache entries match name+score?
   - What `inputMethod` values do they have?
   - Which entry is selected?

### Test 4: Verify MealStorageManager State
1. Add logging before/after `addMeal()` call
2. Create Type It entry
3. Check logs:
   - What is `trackedMeals.count` before save?
   - What is `trackedMeals.count` after save?
   - Are meals added synchronously?

---

## Additional Notes

### TrackedMeal Structure
- **No `inputMethod` property** (was removed in recent revert)
- Only `imageHash` distinguishes text/voice entries (nil = text/voice, non-nil = image)
- `originalAnalysis` stores the full `FoodAnalysis` object

### FoodCacheEntry Structure
- **Has `inputMethod` property** (stored in cache)
- Used to display correct icon (keyboard vs mic) in UI
- Not stored in `TrackedMeal` (only `imageHash` is stored)

### Icon Display Logic
- Icons are determined by looking up `inputMethod` from `FoodCacheManager` cache
- If `inputMethod == "text"` → keyboard icon
- If `inputMethod == "voice"` → microphone icon
- Otherwise → fork/knife or image

### Why Say It Shows Different Icons
- If two entries are saved with different `inputMethod` values from cache
- One might get `inputMethod = "text"` (keyboard icon)
- Other might get `inputMethod = "voice"` (mic icon)
- This suggests cache lookup is inconsistent or multiple cache entries exist

---

## Next Steps

1. **Run Test 1** - Verify if `saveMeal()` is called multiple times
2. **Review Console Output** - Check call stack and timing
3. **Apply Appropriate Fix** - Based on test results:
   - If double call → Fix 1 (guard against double-tap)
   - If timing issue → Fix 2 (improve duplicate detection)
   - If cache issue → Fix 4 (fix cache lookup)
4. **Add Defense in Depth** → Fix 3 (add duplicate check in MealStorageManager)
5. **Test Thoroughly** - Verify fix resolves issue for both Type It and Say It

---

## Files Modified for Debugging

1. **ResultsView.swift**
   - Lines 6087-6091: Added debug logging to `saveMeal()`

---

## Git Status

**Last Commit:** `dd0e103` - "CHECKPOINT: before duplicate entry debugging"

**Current State:** Debug logging added, ready for testing

---

**End of Report**
