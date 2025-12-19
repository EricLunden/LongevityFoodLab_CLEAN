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
    func getNutritionForFood(_ foodName: String, amount: Double = 100, unit: String = "g") async throws -> NutritionInfo? {
        print("🔍 NutritionService: Starting tiered lookup for '\(foodName)'")
        
        // TIER 0: Try Local Database first (instant, offline, most common foods)
        if let localNutrition = localNutritionService.getNutritionForFood(foodName, amount: amount, unit: unit) {
            print("✅ NutritionService: Found nutrition via Local DB (Tier 0)")
            return localNutrition
        }
        
        // TIER 1: Try USDA API (most accurate, free, complete micronutrients)
        do {
            if let nutrition = try await usdaService.getNutritionForFood(foodName, amount: amount, unit: unit) {
                print("✅ NutritionService: Found nutrition via USDA (Tier 1)")
                return nutrition
            }
        } catch {
            print("⚠️ NutritionService: USDA lookup failed: \(error.localizedDescription)")
        }
        
        // TIER 2: Fallback to Spoonacular
        do {
            if let spoonacularNutrition = try await spoonacularService.getNutritionForFood(foodName, amount: amount, unit: unit) {
                print("✅ NutritionService: Found nutrition via Spoonacular (Tier 2)")
                // Convert Spoonacular to NutritionInfo using shared conversion logic
                return convertSpoonacularToNutritionInfo(spoonacularNutrition)
            }
        } catch {
            print("⚠️ NutritionService: Spoonacular lookup failed: \(error.localizedDescription)")
        }
        
        // TIER 3: AI estimation would go here (existing logic in ResultsView/RecipeAnalysisView)
        print("⚠️ NutritionService: No nutrition found in databases (Tier 1 & 2 failed), falling back to AI estimation")
        return nil
    }
    
    /// Convert Spoonacular nutrition to NutritionInfo (shared conversion logic)
    private func convertSpoonacularToNutritionInfo(_ spoonNutrition: SpoonacularIngredientNutrition) -> NutritionInfo {
        print("🔄 NutritionService: Converting Spoonacular nutrition to NutritionInfo")
        print("🔄 NutritionService: Processing \(spoonNutrition.nutrition.nutrients.count) nutrients")
        var nutritionDict: [String: String] = [:]
        
        // Extract nutrients from Spoonacular response
        for nutrient in spoonNutrition.nutrition.nutrients {
            let name = nutrient.name.lowercased()
            let amount = nutrient.amount
            let unit = nutrient.unit
            
            // Map Spoonacular nutrient names to our format
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
                // Spoonacular provides Vitamin A in IU, convert to mcg RAE (1 IU = 0.3 mcg RAE for retinol)
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
        
        print("✅ NutritionService: Conversion complete - Macros: \(result.calories) cal, \(result.protein) protein")
        let microCount = [result.vitaminD, result.vitaminE, result.potassium, result.vitaminK, result.magnesium, result.vitaminA, result.calcium, result.vitaminC, result.choline, result.iron, result.iodine, result.zinc, result.folate, result.vitaminB12, result.vitaminB6, result.selenium, result.copper, result.manganese, result.thiamin].compactMap { $0 }.count
        print("📊 NutritionService: Micros found: \(microCount)/19")
        
        return result
    }
    
    /// Format nutrition value for display
    private func formatNutritionValue(_ amount: Double, unit: String) -> String {
        // Round to whole numbers for display
        return "\(Int(round(amount)))\(unit)"
    }
}

