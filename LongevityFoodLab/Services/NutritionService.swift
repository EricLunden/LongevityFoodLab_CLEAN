//
//  NutritionService.swift
//  LongevityFoodLab
//
//  Unified Nutrition Service with Tiered Lookup (USDA → Spoonacular → AI)
//

import Foundation

// MARK: - Unified Nutrition Service (Tiered Lookup)
class NutritionService {
    static let shared = NutritionService()
    
    private let localNutritionService = LocalNutritionService.shared
    private let usdaService = USDAService.shared
    private let spoonacularService = SpoonacularService.shared
    
    private init() {}
    
    /// Get nutrition for a food using tiered lookup: Local DB → USDA → Spoonacular → AI
    func getNutritionForFood(_ foodName: String,
                             amount: Double = 100,
                             unit: String = "g",
                             context: NutritionNormalizationContext? = nil) async throws -> NutritionInfo? {
        return try await NutritionNormalizationPipeline.shared.getNutritionForFood(foodName, amount: amount, unit: unit, context: context)
    }
    
    /// Convert Spoonacular nutrition to NutritionInfo (shared conversion logic)
    private func convertSpoonacularToNutritionInfo(_ spoonNutrition: SpoonacularIngredientNutrition) -> NutritionInfo {
        return NutritionNormalizationPipeline.shared.convertSpoonacularToNutritionInfo(spoonNutrition, context: nil)
    }
    
    /// Format nutrition value for display
    private func formatNutritionValue(_ amount: Double, unit: String) -> String {
        // Round to whole numbers for display
        return "\(Int(round(amount)))\(unit)"
    }
}

