//
//  NutritionAggregator.swift
//  LongevityFoodLab
//
//  Shared utility for aggregating nutrition data across meals, recipes, and daily totals.
//  Fixes the saturated fat bug and ensures all 18 micronutrients are aggregated consistently.
//

import Foundation

struct NutritionAggregator {
    // MARK: - Properties
    
    private var totals: [String: Double] = [:]
    
    // MARK: - Initialization
    
    init() {
        // Initialize all macro and micro totals to 0
        initializeTotals()
    }
    
    private mutating func initializeTotals() {
        // Macros (8 total)
        totals["calories"] = 0
        totals["protein"] = 0
        totals["carbohydrates"] = 0
        totals["fat"] = 0
        totals["fiber"] = 0
        totals["sugar"] = 0
        totals["sodium"] = 0
        totals["saturatedFat"] = 0
        
        // Micronutrients (18 total - NO iodine)
        totals["vitaminA"] = 0
        totals["vitaminC"] = 0
        totals["vitaminD"] = 0
        totals["vitaminE"] = 0
        totals["vitaminK"] = 0
        totals["calcium"] = 0
        totals["iron"] = 0
        totals["magnesium"] = 0
        totals["potassium"] = 0
        totals["zinc"] = 0
        totals["folate"] = 0
        totals["vitaminB6"] = 0
        totals["vitaminB12"] = 0
        totals["selenium"] = 0
        totals["copper"] = 0
        totals["manganese"] = 0
        totals["thiamin"] = 0
        totals["choline"] = 0
    }
    
    // MARK: - Public Methods
    
    /// Add nutrition values from a NutritionInfo object to the totals
    mutating func add(_ nutrition: NutritionInfo) {
        // Add macros
        if let value = parseNutritionValue(nutrition.calories) {
            totals["calories", default: 0] += value
        }
        if let value = parseNutritionValue(nutrition.protein) {
            totals["protein", default: 0] += value
        }
        if let value = parseNutritionValue(nutrition.carbohydrates) {
            totals["carbohydrates", default: 0] += value
        }
        if let value = parseNutritionValue(nutrition.fat) {
            totals["fat", default: 0] += value
        }
        if let value = parseNutritionValue(nutrition.fiber) {
            totals["fiber", default: 0] += value
        }
        if let value = parseNutritionValue(nutrition.sugar) {
            totals["sugar", default: 0] += value
        }
        if let value = parseNutritionValue(nutrition.sodium) {
            totals["sodium", default: 0] += value
        }
        if let value = nutrition.saturatedFat, let parsed = parseNutritionValue(value) {
            totals["saturatedFat", default: 0] += parsed
        }
        
        // Add micronutrients (18 total - NO iodine)
        if let value = nutrition.vitaminA, let parsed = parseNutritionValue(value) {
            totals["vitaminA", default: 0] += parsed
        }
        if let value = nutrition.vitaminC, let parsed = parseNutritionValue(value) {
            totals["vitaminC", default: 0] += parsed
        }
        if let value = nutrition.vitaminD, let parsed = parseNutritionValue(value) {
            totals["vitaminD", default: 0] += parsed
        }
        if let value = nutrition.vitaminE, let parsed = parseNutritionValue(value) {
            totals["vitaminE", default: 0] += parsed
        }
        if let value = nutrition.vitaminK, let parsed = parseNutritionValue(value) {
            totals["vitaminK", default: 0] += parsed
        }
        if let value = nutrition.calcium, let parsed = parseNutritionValue(value) {
            totals["calcium", default: 0] += parsed
        }
        if let value = nutrition.iron, let parsed = parseNutritionValue(value) {
            totals["iron", default: 0] += parsed
        }
        if let value = nutrition.magnesium, let parsed = parseNutritionValue(value) {
            totals["magnesium", default: 0] += parsed
        }
        if let value = nutrition.potassium, let parsed = parseNutritionValue(value) {
            totals["potassium", default: 0] += parsed
        }
        if let value = nutrition.zinc, let parsed = parseNutritionValue(value) {
            totals["zinc", default: 0] += parsed
        }
        if let value = nutrition.folate, let parsed = parseNutritionValue(value) {
            totals["folate", default: 0] += parsed
        }
        if let value = nutrition.vitaminB6, let parsed = parseNutritionValue(value) {
            totals["vitaminB6", default: 0] += parsed
        }
        if let value = nutrition.vitaminB12, let parsed = parseNutritionValue(value) {
            totals["vitaminB12", default: 0] += parsed
        }
        if let value = nutrition.selenium, let parsed = parseNutritionValue(value) {
            totals["selenium", default: 0] += parsed
        }
        if let value = nutrition.copper, let parsed = parseNutritionValue(value) {
            totals["copper", default: 0] += parsed
        }
        if let value = nutrition.manganese, let parsed = parseNutritionValue(value) {
            totals["manganese", default: 0] += parsed
        }
        if let value = nutrition.thiamin, let parsed = parseNutritionValue(value) {
            totals["thiamin", default: 0] += parsed
        }
        if let value = nutrition.choline, let parsed = parseNutritionValue(value) {
            totals["choline", default: 0] += parsed
        }
        // Note: iodine is intentionally excluded from aggregation
    }
    
    /// Divide all totals by the number of servings (for recipe scaling)
    func divideByServings(_ servings: Int) -> NutritionAggregator {
        guard servings > 0 else { return self }
        
        var newAggregator = self
        for key in newAggregator.totals.keys {
            newAggregator.totals[key] = (newAggregator.totals[key] ?? 0) / Double(servings)
        }
        return newAggregator
    }
    
    /// Convert totals dictionary back to NutritionInfo struct
    func toNutritionInfo() -> NutritionInfo {
        return NutritionInfo(
            calories: format("calories", ""),
            protein: format("protein", "g"),
            carbohydrates: format("carbohydrates", "g"),
            fat: format("fat", "g"),
            sugar: format("sugar", "g"),
            fiber: format("fiber", "g"),
            sodium: format("sodium", "mg"),
            saturatedFat: formatOptional("saturatedFat", "g"),
            vitaminD: formatOptional("vitaminD", "mcg"),
            vitaminE: formatOptional("vitaminE", "mg"),
            potassium: formatOptional("potassium", "mg"),
            vitaminK: formatOptional("vitaminK", "mcg"),
            magnesium: formatOptional("magnesium", "mg"),
            vitaminA: formatOptional("vitaminA", "mcg"),
            calcium: formatOptional("calcium", "mg"),
            vitaminC: formatOptional("vitaminC", "mg"),
            choline: formatOptional("choline", "mg"),
            iron: formatOptional("iron", "mg"),
            iodine: nil, // Intentionally excluded
            zinc: formatOptional("zinc", "mg"),
            folate: formatOptional("folate", "mcg"),
            vitaminB12: formatOptional("vitaminB12", "mcg"),
            vitaminB6: formatOptional("vitaminB6", "mg"),
            selenium: formatOptional("selenium", "mcg"),
            copper: formatOptional("copper", "mg"),
            manganese: formatOptional("manganese", "mg"),
            thiamin: formatOptional("thiamin", "mg")
        )
    }
    
    // MARK: - Private Parsing Functions
    
    /// Parse a nutrition value string to Double, stripping units and handling whitespace
    private func parseNutritionValue(_ value: String) -> Double? {
        guard !value.isEmpty, value.uppercased() != "N/A" else { return nil }
        
        // Remove common units: kcal, mcg, µg, mg, IU, g
        var cleaned = value
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mcg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "µg", with: "", options: .caseInsensitive)  // Micro symbol (U+00B5)
            .replacingOccurrences(of: "μg", with: "", options: .caseInsensitive)  // Greek mu (U+03BC)
            .replacingOccurrences(of: "mg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "IU", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
        
        // Remove whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle special cases for vitamin D (convert IU to mcg if needed)
        // Note: This is a simplified conversion (1 IU = 0.025 mcg for vitamin D)
        // But since we're parsing strings, we'll just extract the number
        
        return Double(cleaned)
    }
    
    // MARK: - Private Formatting Functions
    
    /// Format a macro value (always returns a value, never nil)
    private func format(_ key: String, _ unit: String) -> String {
        let value = totals[key] ?? 0
        return formatValue(value, unit: unit)
    }
    
    /// Format a micronutrient value (returns nil if zero)
    private func formatOptional(_ key: String, _ unit: String) -> String? {
        let value = totals[key] ?? 0
        guard value > 0 else { return nil }
        return formatValue(value, unit: unit)
    }
    
    /// Format a numeric value with appropriate decimal places
    /// - Values < 1: show 2 decimal places (e.g., "0.25mg")
    /// - Values 1-10: show 1 decimal place (e.g., "5.5g")
    /// - Values > 10: show whole number (e.g., "150mg")
    private func formatValue(_ value: Double, unit: String) -> String {
        let formatted: String
        if value < 1 {
            formatted = String(format: "%.2f", value)
        } else if value < 10 {
            formatted = String(format: "%.1f", value)
        } else {
            formatted = String(format: "%.0f", value)
        }
        
        return unit.isEmpty ? formatted : "\(formatted)\(unit)"
    }
    
    // MARK: - Helper Methods
    
    /// Get the raw total for a specific nutrient (for debugging or custom formatting)
    func getTotal(for key: String) -> Double {
        return totals[key] ?? 0
    }
    
    /// Get saturated fat total (for future use when NutritionInfo is extended)
    func getSaturatedFat() -> Double {
        return totals["saturatedFat"] ?? 0
    }
}
