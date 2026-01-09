# NutritionAggregator Integration - BEFORE/AFTER

## 1. ResultsView.swift

### BEFORE: `aggregateNutritionForMealWithTieredLookup()`

```swift
private func aggregateNutritionForMealWithTieredLookup(foodNames: [String]) async throws -> NutritionInfo? {
    print("🔍 ResultsView: Aggregating nutrition for meal with \(foodNames.count) ingredients using tiered lookup")
    var totalNutrition: [String: Double] = [:]
    var foundAny = false
    var foundCount = 0
    
    // ... lookup loop ...
    for (index, foodName) in foodNames.enumerated() {
        // ... get nutrition ...
        if let nutrition = try await NutritionService.shared.getNutritionForFood(...) {
            foundAny = true
            foundCount += 1
            addNutritionToTotals(nutrition, to: &totalNutrition)
        }
    }
    
    guard foundAny else { return nil }
    
    let result = createNutritionInfoFromTotals(totalNutrition)
    return result
}

private func addNutritionToTotals(_ nutrition: NutritionInfo, to totals: inout [String: Double]) {
    // 50+ lines of manual parsing and adding...
}

private func createNutritionInfoFromTotals(_ totals: [String: Double]) -> NutritionInfo {
    // 50+ lines of manual formatting...
}
```

### AFTER: Using NutritionAggregator

```swift
private func aggregateNutritionForMealWithTieredLookup(foodNames: [String]) async throws -> NutritionInfo? {
    print("🔍 ResultsView: Aggregating nutrition for meal with \(foodNames.count) ingredients using tiered lookup")
    var aggregator = NutritionAggregator()
    var foundAny = false
    var foundCount = 0
    
    // ... lookup loop ...
    for (index, foodName) in foodNames.enumerated() {
        // ... get nutrition ...
        if let nutrition = try await NutritionService.shared.getNutritionForFood(...) {
            foundAny = true
            foundCount += 1
            aggregator.add(nutrition)
        }
    }
    
    guard foundAny else { return nil }
    
    return aggregator.toNutritionInfo()
}

// REMOVE: addNutritionToTotals() - no longer needed
// REMOVE: createNutritionInfoFromTotals() - no longer needed
```

---

## 2. RecipeAnalysisView.swift

### BEFORE: `aggregateNutritionFromActualQuantities()`

```swift
private func aggregateNutritionFromActualQuantities(ingredients: [(name: String, amount: String, unit: String?)]) async throws -> NutritionInfo? {
    var totalNutrition: [String: Double] = [:]
    var foundAny = false
    var foundCount = 0
    
    // ... parallel lookup loop ...
    for try await (index, name, nutrition) in group {
        if let nutrition = nutrition {
            foundAny = true
            foundCount += 1
            addNutritionToTotals(nutrition, to: &totalNutrition)
        }
    }
    
    guard foundAny else { return nil }
    
    let result = createNutritionInfoFromTotals(totalNutrition)
    return result
}

private func addNutritionToTotals(_ nutrition: NutritionInfo, to totals: inout [String: Double]) {
    // 30+ lines of manual parsing...
}

private func createNutritionInfoFromTotals(_ totals: [String: Double]) -> NutritionInfo {
    // 30+ lines of manual formatting...
}
```

### AFTER: Using NutritionAggregator

```swift
private func aggregateNutritionFromActualQuantities(ingredients: [(name: String, amount: String, unit: String?)]) async throws -> NutritionInfo? {
    var aggregator = NutritionAggregator()
    var foundAny = false
    var foundCount = 0
    
    // ... parallel lookup loop ...
    for try await (index, name, nutrition) in group {
        if let nutrition = nutrition {
            foundAny = true
            foundCount += 1
            aggregator.add(nutrition)
        }
    }
    
    guard foundAny else { return nil }
    
    // For per-serving values (if needed):
    // let perServingAggregator = aggregator.divideByServings(servings)
    // return perServingAggregator.toNutritionInfo()
    
    return aggregator.toNutritionInfo()
}

// REMOVE: addNutritionToTotals() - no longer needed
// REMOVE: createNutritionInfoFromTotals() - no longer needed
```

---

## 3. MealDetailsView.swift

### BEFORE: `aggregateNutritionForMealWithTieredLookup()`

```swift
private func aggregateNutritionForMealWithTieredLookup(foodNames: [String]) async throws -> NutritionInfo? {
    var totalNutrition: [String: Double] = [:]
    var foundAny = false
    
    try await withThrowingTaskGroup(of: (String, NutritionInfo?).self) { group in
        // ... parallel lookups ...
        for try await (foodName, nutrition) in group {
            if let nutrition = nutrition {
                foundAny = true
                addNutritionToTotals(nutrition, to: &totalNutrition)
            }
        }
    }
    
    guard foundAny else { return nil }
    
    return createNutritionInfoFromTotals(totalNutrition)
}

private func addNutritionToTotals(_ nutrition: NutritionInfo, to totals: inout [String: Double]) {
    // 40+ lines of manual parsing for all macros and micros...
}

private func createNutritionInfoFromTotals(_ totals: [String: Double]) -> NutritionInfo {
    // 30+ lines of manual formatting...
}
```

### AFTER: Using NutritionAggregator

```swift
private func aggregateNutritionForMealWithTieredLookup(foodNames: [String]) async throws -> NutritionInfo? {
    var aggregator = NutritionAggregator()
    var foundAny = false
    
    try await withThrowingTaskGroup(of: (String, NutritionInfo?).self) { group in
        // ... parallel lookups ...
        for try await (foodName, nutrition) in group {
            if let nutrition = nutrition {
                foundAny = true
                aggregator.add(nutrition)
            }
        }
    }
    
    guard foundAny else { return nil }
    
    return aggregator.toNutritionInfo()
}

// REMOVE: addNutritionToTotals() - no longer needed
// REMOVE: createNutritionInfoFromTotals() - no longer needed
```

---

## 4. MealTrackingView.swift

### BEFORE: `totalMacros` computed property

```swift
private var totalMacros: (protein: Double, carbs: Double, fat: Double, saturatedFat: Double, fiber: Double, sugar: Double) {
    var totalProtein: Double = 0
    var totalCarbs: Double = 0
    var totalFat: Double = 0
    let totalSaturatedFat: Double = 0  // BUG: Hardcoded to 0!
    var totalFiber: Double = 0
    var totalSugar: Double = 0
    
    for meal in filteredTodayMeals {
        if let analysis = analysis,
           let nutrition = analysis.nutritionInfo {
            let protein = parseNutritionValue(nutrition.protein)
            let carbs = parseNutritionValue(nutrition.carbohydrates)
            let fat = parseNutritionValue(nutrition.fat)
            let fiber = parseNutritionValue(nutrition.fiber)
            let sugar = parseNutritionValue(nutrition.sugar)
            
            totalProtein += protein
            totalCarbs += carbs
            totalFat += fat
            totalFiber += fiber
            totalSugar += sugar
            // BUG: saturatedFat never added!
        }
    }
    
    return (totalProtein, totalCarbs, totalFat, totalSaturatedFat, totalFiber, totalSugar)
}
```

### AFTER: Using NutritionAggregator

```swift
private var totalMacros: (protein: Double, carbs: Double, fat: Double, saturatedFat: Double, fiber: Double, sugar: Double) {
    var aggregator = NutritionAggregator()
    
    for meal in filteredTodayMeals {
        if let analysis = analysis,
           let nutrition = analysis.nutritionInfo {
            aggregator.add(nutrition)
        }
    }
    
    return (
        protein: aggregator.getTotal(for: "protein"),
        carbs: aggregator.getTotal(for: "carbohydrates"),
        fat: aggregator.getTotal(for: "fat"),
        saturatedFat: aggregator.getSaturatedFat(),  // FIXED: Now properly aggregated!
        fiber: aggregator.getTotal(for: "fiber"),
        sugar: aggregator.getTotal(for: "sugar")
    )
}
```

---

## 5. SearchView.swift

### BEFORE: `aggregateNutritionFromDatabase()`

```swift
private func aggregateNutritionFromDatabase(foodNames: [String]) async -> NutritionInfo? {
    var totalNutrition: [String: Double] = [:]
    var foundCount = 0
    
    // ... database lookup loop ...
    for foodName in foodNames {
        if let nutrition = localNutritionService.getNutritionForFood(foodName) {
            foundCount += 1
            addNutritionToTotals(nutrition, to: &totalNutrition)
        }
    }
    
    guard foundCount > 0 else { return nil }
    
    let nutritionInfo = createNutritionInfoFromTotals(totalNutrition)
    return nutritionInfo
}

private func addNutritionToTotals(_ nutrition: NutritionInfo, to totals: inout [String: Double]) {
    // 30+ lines of manual parsing...
}

private func createNutritionInfoFromTotals(_ totals: [String: Double]) -> NutritionInfo {
    // 50+ lines of manual formatting...
}
```

### AFTER: Using NutritionAggregator

```swift
private func aggregateNutritionFromDatabase(foodNames: [String]) async -> NutritionInfo? {
    var aggregator = NutritionAggregator()
    var foundCount = 0
    
    // ... database lookup loop ...
    for foodName in foodNames {
        if let nutrition = localNutritionService.getNutritionForFood(foodName) {
            foundCount += 1
            aggregator.add(nutrition)
        }
    }
    
    guard foundCount > 0 else { return nil }
    
    return aggregator.toNutritionInfo()
}

// REMOVE: addNutritionToTotals() - no longer needed
// REMOVE: createNutritionInfoFromTotals() - no longer needed
```

---

## Summary of Functions to Remove

After integration, these functions can be **DELETED**:

1. **ResultsView.swift**:
   - `addNutritionToTotals(_:to:)` (lines ~2145-2187)
   - `createNutritionInfoFromTotals(_:)` (lines ~2189-2240)

2. **RecipeAnalysisView.swift**:
   - `addNutritionToTotals(_:to:)` (lines ~2788-2824)
   - `createNutritionInfoFromTotals(_:)` (lines ~2827-2857)

3. **MealDetailsView.swift**:
   - `addNutritionToTotals(_:to:)` (lines ~1628-1707)
   - `createNutritionInfoFromTotals(_:)` (lines ~1710-1750)

4. **SearchView.swift**:
   - `addNutritionToTotals(_:to:)` (lines ~1740-1776)
   - `createNutritionInfoFromTotals(_:)` (lines ~1779-1825)

## Benefits

1. **Fixes saturated fat bug** - Now properly aggregated in MealTrackingView
2. **Consistent aggregation** - All 18 micronutrients handled uniformly
3. **Less code** - Removes ~200+ lines of duplicate aggregation logic
4. **Easier maintenance** - Single source of truth for nutrition aggregation
5. **Better formatting** - Consistent decimal places and units across the app
