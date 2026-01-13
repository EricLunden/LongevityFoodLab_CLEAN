//
//  NutritionNormalizationPipeline.swift
//  LongevityFoodLab
//
//  Centralized wrapper that reuses existing nutrition lookup and conversion
//  logic without altering behavior. All public methods delegate to the
//  existing services exactly as before.
//

import Foundation

/// Context passed into the normalization pipeline (scaffolding only; no behavior change).
/// This enables future Phase B.2 corrections without adding new assumptions.
struct NutritionNormalizationContext {
    let canonicalFoodName: String?
    let quantity: Double?
    let unit: String?
    let gramsKnown: Bool?
    let perServingProvided: Bool?
    let per100gProvided: Bool?
    let servings: Int?
    let ingredientNames: [String]?
    let timestamp: Date?
    let imageHash: String?
    let inputMethod: String?
}

/// Image-based deduplication context (image entries only).
/// Mirrors existing image dedup logic (name+score+recent window, optional imageHash/analysis match).
struct ImageDeduplicationContext {
    let existingMeals: [TrackedMeal]
    let mealName: String
    let healthScore: Double
    let imageHash: String?
    let originalAnalysis: FoodAnalysis?
    let includeImageHashMatch: Bool
    let includeAnalysisMatch: Bool
    let windowSeconds: TimeInterval
    let now: Date
}

final class NutritionNormalizationPipeline {
    static let shared = NutritionNormalizationPipeline()
    
    private let localNutritionService = LocalNutritionService.shared
    private let usdaService = USDAService.shared
    private let spoonacularService = SpoonacularService.shared
    
    private init() {}
    
    /// Tiered lookup: Local DB → USDA → Spoonacular → (fallback handled by caller)
    func getNutritionForFood(_ foodName: String,
                             amount: Double = 100,
                             unit: String = "g",
                             context: NutritionNormalizationContext? = nil) async throws -> NutritionInfo? {
        print("🔍 NutritionNormalizationPipeline: Starting tiered lookup for '\(foodName)'")
        if let ctx = context {
            print("🔍 NutritionNormalizationPipeline: Context - qty: \(ctx.quantity ?? amount)\(ctx.unit ?? unit), servings: \(ctx.servings ?? 0), gramsKnown: \(ctx.gramsKnown ?? false)")
        }
        
        // TIER 0: Local DB
        if let localNutrition = localNutritionService.getNutritionForFood(foodName, amount: amount, unit: unit) {
            print("✅ NutritionNormalizationPipeline: Found nutrition via Local DB (Tier 0)")
            return localNutrition
        }
        
        // TIER 1: USDA
        do {
            if let nutrition = try await usdaService.getNutritionForFood(foodName, amount: amount, unit: unit) {
                print("✅ NutritionNormalizationPipeline: Found nutrition via USDA (Tier 1)")
                return nutrition
            }
        } catch {
            print("⚠️ NutritionNormalizationPipeline: USDA lookup failed: \(error.localizedDescription)")
        }
        
        // TIER 2: Spoonacular
        do {
            if let spoonacularNutrition = try await spoonacularService.getNutritionForFood(foodName, amount: amount, unit: unit) {
                print("✅ NutritionNormalizationPipeline: Found nutrition via Spoonacular (Tier 2)")
                return convertSpoonacularToNutritionInfo(spoonacularNutrition)
            }
        } catch {
            print("⚠️ NutritionNormalizationPipeline: Spoonacular lookup failed: \(error.localizedDescription)")
        }
        
        print("⚠️ NutritionNormalizationPipeline: No nutrition found in databases (Tier 1 & 2 failed), falling back to caller")
        return nil
    }
    
    // MARK: - Shared conversion (moved intact from NutritionService)
    
    func convertSpoonacularToNutritionInfo(_ spoonNutrition: SpoonacularIngredientNutrition,
                                           context: NutritionNormalizationContext? = nil) -> NutritionInfo {
        print("🔄 NutritionNormalizationPipeline: Converting Spoonacular nutrition to NutritionInfo")
        print("🔄 NutritionNormalizationPipeline: Processing \(spoonNutrition.nutrition.nutrients.count) nutrients")
        var nutritionDict: [String: String] = [:]
        
        for nutrient in spoonNutrition.nutrition.nutrients {
            let name = nutrient.name.lowercased()
            let amount = nutrient.amount
            let unit = nutrient.unit
            
            switch name {
            case "calories", "energy":
                nutritionDict["calories"] = formatNutritionValue(amount, unit: unit)
            case "protein":
                nutritionDict["protein"] = formatNutritionValue(amount, unit: unit)
            case "carbohydrates", "net carbs":
                nutritionDict["carbohydrates"] = formatNutritionValue(amount, unit: unit)
            case "fat", "total fat":
                nutritionDict["fat"] = formatNutritionValue(amount, unit: unit)
            case "sugar":
                nutritionDict["sugar"] = formatNutritionValue(amount, unit: unit)
            case "fiber", "dietary fiber":
                nutritionDict["fiber"] = formatNutritionValue(amount, unit: unit)
            case "sodium":
                nutritionDict["sodium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin d", "vitamin d (d2 + d3)":
                nutritionDict["vitaminD"] = formatNutritionValue(amount, unit: unit)
            case "vitamin e":
                nutritionDict["vitaminE"] = formatNutritionValue(amount, unit: unit)
            case "potassium":
                nutritionDict["potassium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin k":
                nutritionDict["vitaminK"] = formatNutritionValue(amount, unit: unit)
            case "magnesium":
                nutritionDict["magnesium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin a", "vitamin a, rae":
                if unit.lowercased() == "iu" {
                    let mcgRAE = amount * 0.3
                    nutritionDict["vitaminA"] = formatNutritionValue(mcgRAE, unit: "mcg")
                } else {
                    nutritionDict["vitaminA"] = formatNutritionValue(amount, unit: unit)
                }
            case "calcium":
                nutritionDict["calcium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin c":
                nutritionDict["vitaminC"] = formatNutritionValue(amount, unit: unit)
            case "choline":
                nutritionDict["choline"] = formatNutritionValue(amount, unit: unit)
            case "iron":
                nutritionDict["iron"] = formatNutritionValue(amount, unit: unit)
            case "iodine":
                nutritionDict["iodine"] = formatNutritionValue(amount, unit: unit)
            case "zinc":
                nutritionDict["zinc"] = formatNutritionValue(amount, unit: unit)
            case "folate", "folic acid":
                nutritionDict["folate"] = formatNutritionValue(amount, unit: unit)
            case "vitamin b12", "vitamin b-12":
                nutritionDict["vitaminB12"] = formatNutritionValue(amount, unit: unit)
            case "vitamin b6", "vitamin b-6":
                nutritionDict["vitaminB6"] = formatNutritionValue(amount, unit: unit)
            case "selenium":
                nutritionDict["selenium"] = formatNutritionValue(amount, unit: unit)
            case "copper":
                nutritionDict["copper"] = formatNutritionValue(amount, unit: unit)
            case "manganese":
                nutritionDict["manganese"] = formatNutritionValue(amount, unit: unit)
            case "thiamin", "vitamin b1", "vitamin b-1":
                nutritionDict["thiamin"] = formatNutritionValue(amount, unit: unit)
            default:
                break
            }
        }
        
        let result = NutritionInfo(
            calories: nutritionDict["calories"] ?? "0",
            protein: nutritionDict["protein"] ?? "0g",
            carbohydrates: nutritionDict["carbohydrates"] ?? "0g",
            fat: nutritionDict["fat"] ?? "0g",
            sugar: nutritionDict["sugar"] ?? "0g",
            fiber: nutritionDict["fiber"] ?? "0g",
            sodium: nutritionDict["sodium"] ?? "0mg",
            saturatedFat: nutritionDict["saturatedFat"],
            vitaminD: nutritionDict["vitaminD"],
            vitaminE: nutritionDict["vitaminE"],
            potassium: nutritionDict["potassium"],
            vitaminK: nutritionDict["vitaminK"],
            magnesium: nutritionDict["magnesium"],
            vitaminA: nutritionDict["vitaminA"],
            calcium: nutritionDict["calcium"],
            vitaminC: nutritionDict["vitaminC"],
            choline: nutritionDict["choline"],
            iron: nutritionDict["iron"],
            iodine: nutritionDict["iodine"],
            zinc: nutritionDict["zinc"],
            folate: nutritionDict["folate"],
            vitaminB12: nutritionDict["vitaminB12"],
            vitaminB6: nutritionDict["vitaminB6"],
            selenium: nutritionDict["selenium"],
            copper: nutritionDict["copper"],
            manganese: nutritionDict["manganese"],
            thiamin: nutritionDict["thiamin"]
        )
        
        print("✅ NutritionNormalizationPipeline: Conversion complete - Macros: \(result.calories) cal, \(result.protein) protein")
        let microCount = [result.vitaminD, result.vitaminE, result.potassium, result.vitaminK, result.magnesium, result.vitaminA, result.calcium, result.vitaminC, result.choline, result.iron, result.iodine, result.zinc, result.folate, result.vitaminB12, result.vitaminB6, result.selenium, result.copper, result.manganese, result.thiamin].compactMap { $0 }.count
        print("📊 NutritionNormalizationPipeline: Micros found: \(microCount)/19")
        
        return result
    }
    
    private func formatNutritionValue(_ amount: Double, unit: String) -> String {
        return "\(Int(round(amount)))\(unit)"
    }

    // MARK: - Image Deduplication (image entries only)

    /// Apply existing image-based dedup rules without changing behavior.
    /// Rules (as currently used in views):
    /// - name + score match AND meal timestamp within window
    /// - OR imageHash match (if enabled)
    /// - OR analysis match (if enabled)
    func findDuplicateImageMeal(using context: ImageDeduplicationContext) -> TrackedMeal? {
        let cutoff = context.now.addingTimeInterval(-context.windowSeconds)
        
        return context.existingMeals.first { meal in
            let nameMatch = meal.name == context.mealName
            let scoreMatch = abs(meal.healthScore - context.healthScore) < 1.0
            let recentMatch = meal.timestamp > cutoff
            
            let imageHashMatch = context.includeImageHashMatch &&
                                 context.imageHash != nil &&
                                 meal.imageHash == context.imageHash
            
            let analysisMatch = context.includeAnalysisMatch &&
                context.originalAnalysis != nil &&
                meal.originalAnalysis?.overallScore == context.originalAnalysis?.overallScore &&
                meal.originalAnalysis?.foodName == context.originalAnalysis?.foodName
            
            return (nameMatch && scoreMatch && recentMatch) || imageHashMatch || analysisMatch
        }
    }
}
