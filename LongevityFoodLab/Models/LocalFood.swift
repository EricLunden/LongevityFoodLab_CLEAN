//
//  LocalFood.swift
//  LongevityFoodLab
//
//  Models for local nutrition database
//

import Foundation

struct LocalFood: Identifiable {
    let id: Int
    let fdcId: Int
    let name: String
    let description: String
    let category: String
    let dataSource: String
    let popularityScore: Int
}

struct LocalServing: Identifiable {
    let id: Int
    let foodId: Int
    let description: String
    let grams: Double
    let isDefault: Bool
}

struct LocalNutrition {
    let foodId: Int
    let calories: Double?
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let sodium: Double?
    let saturatedFat: Double?
    let cholesterol: Double?
    let potassium: Double?
    let calcium: Double?
    let iron: Double?
    let magnesium: Double?
    let phosphorus: Double?
    let zinc: Double?
    let copper: Double?
    let manganese: Double?
    let selenium: Double?
    let iodine: Double?
    let vitaminA: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let vitaminE: Double?
    let vitaminK: Double?
    let vitaminB1: Double?
    let vitaminB2: Double?
    let vitaminB3: Double?
    let vitaminB5: Double?
    let vitaminB6: Double?
    let vitaminB12: Double?
    let folate: Double?
    let choline: Double?
    let omega3: Double?
    let omega6: Double?
    
    /// Scale nutrition to a specific gram amount
    func scaled(to grams: Double) -> LocalNutrition {
        let scaleFactor = grams / 100.0
        return LocalNutrition(
            foodId: foodId,
            calories: calories.map { $0 * scaleFactor },
            protein: protein.map { $0 * scaleFactor },
            carbohydrates: carbohydrates.map { $0 * scaleFactor },
            fat: fat.map { $0 * scaleFactor },
            fiber: fiber.map { $0 * scaleFactor },
            sugar: sugar.map { $0 * scaleFactor },
            sodium: sodium.map { $0 * scaleFactor },
            saturatedFat: saturatedFat.map { $0 * scaleFactor },
            cholesterol: cholesterol.map { $0 * scaleFactor },
            potassium: potassium.map { $0 * scaleFactor },
            calcium: calcium.map { $0 * scaleFactor },
            iron: iron.map { $0 * scaleFactor },
            magnesium: magnesium.map { $0 * scaleFactor },
            phosphorus: phosphorus.map { $0 * scaleFactor },
            zinc: zinc.map { $0 * scaleFactor },
            copper: copper.map { $0 * scaleFactor },
            manganese: manganese.map { $0 * scaleFactor },
            selenium: selenium.map { $0 * scaleFactor },
            iodine: iodine.map { $0 * scaleFactor },
            vitaminA: vitaminA.map { $0 * scaleFactor },
            vitaminC: vitaminC.map { $0 * scaleFactor },
            vitaminD: vitaminD.map { $0 * scaleFactor },
            vitaminE: vitaminE.map { $0 * scaleFactor },
            vitaminK: vitaminK.map { $0 * scaleFactor },
            vitaminB1: vitaminB1.map { $0 * scaleFactor },
            vitaminB2: vitaminB2.map { $0 * scaleFactor },
            vitaminB3: vitaminB3.map { $0 * scaleFactor },
            vitaminB5: vitaminB5.map { $0 * scaleFactor },
            vitaminB6: vitaminB6.map { $0 * scaleFactor },
            vitaminB12: vitaminB12.map { $0 * scaleFactor },
            folate: folate.map { $0 * scaleFactor },
            choline: choline.map { $0 * scaleFactor },
            omega3: omega3.map { $0 * scaleFactor },
            omega6: omega6.map { $0 * scaleFactor }
        )
    }
    
    /// CRITICAL: Convert to NutritionInfo format for compatibility with existing code
    func toNutritionInfo() -> NutritionInfo {
        func formatValue(_ value: Double?, unit: String, isInteger: Bool = false) -> String {
            guard let val = value, val > 0 else {
                return isInteger ? "0" : "0\(unit)"
            }
            if isInteger {
                return "\(Int(round(val)))"
            }
            return String(format: "%.1f\(unit)", val)
        }
        
        return NutritionInfo(
            calories: formatValue(calories, unit: "", isInteger: true),
            protein: formatValue(protein, unit: "g"),
            carbohydrates: formatValue(carbohydrates, unit: "g"),
            fat: formatValue(fat, unit: "g"),
            sugar: formatValue(sugar, unit: "g"),
            fiber: formatValue(fiber, unit: "g"),
            sodium: formatValue(sodium, unit: "mg", isInteger: true),
            saturatedFat: saturatedFat != nil && saturatedFat! > 0 ? formatValue(saturatedFat, unit: "g") : nil,
            vitaminD: formatValue(vitaminD, unit: "mcg"),
            vitaminE: formatValue(vitaminE, unit: "mg"),
            potassium: formatValue(potassium, unit: "mg", isInteger: true),
            vitaminK: formatValue(vitaminK, unit: "mcg"),
            magnesium: formatValue(magnesium, unit: "mg", isInteger: true),
            vitaminA: formatValue(vitaminA, unit: "mcg"),
            calcium: formatValue(calcium, unit: "mg", isInteger: true),
            vitaminC: formatValue(vitaminC, unit: "mg", isInteger: true),
            choline: formatValue(choline, unit: "mg", isInteger: true),
            iron: formatValue(iron, unit: "mg"),
            iodine: formatValue(iodine, unit: "mcg"),
            zinc: formatValue(zinc, unit: "mg"),
            folate: formatValue(folate, unit: "mcg"),
            vitaminB12: formatValue(vitaminB12, unit: "mcg"),
            vitaminB6: formatValue(vitaminB6, unit: "mg"),
            selenium: formatValue(selenium, unit: "mcg"),
            copper: formatValue(copper, unit: "mg"),
            manganese: formatValue(manganese, unit: "mg"),
            thiamin: formatValue(vitaminB1, unit: "mg")
        )
    }
}

