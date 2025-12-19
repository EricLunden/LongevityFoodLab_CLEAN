import Foundation

// Minimal NutritionInfo struct for ShareExtension
// This matches the main app's NutritionInfo structure
struct NutritionInfo: Codable, Equatable {
    let calories: String
    let protein: String
    let carbohydrates: String
    let fat: String
    let sugar: String
    let fiber: String
    let sodium: String
    // Micronutrients (optional for backward compatibility)
    let vitaminD: String?
    let vitaminE: String?
    let potassium: String?
    let vitaminK: String?
    let magnesium: String?
    let vitaminA: String?
    let calcium: String?
    let vitaminC: String?
    let choline: String?
    let iron: String?
    let iodine: String?
    let zinc: String?
    let folate: String?
    let vitaminB12: String?
    let vitaminB6: String?
    let selenium: String?
    let copper: String?
    let manganese: String?
    let thiamin: String?
    
    init(calories: String, protein: String, carbohydrates: String, fat: String, sugar: String, fiber: String, sodium: String,
         vitaminD: String? = nil, vitaminE: String? = nil, potassium: String? = nil, vitaminK: String? = nil,
         magnesium: String? = nil, vitaminA: String? = nil, calcium: String? = nil, vitaminC: String? = nil,
         choline: String? = nil, iron: String? = nil, iodine: String? = nil, zinc: String? = nil,
         folate: String? = nil, vitaminB12: String? = nil, vitaminB6: String? = nil, selenium: String? = nil,
         copper: String? = nil, manganese: String? = nil, thiamin: String? = nil) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.sugar = sugar
        self.fiber = fiber
        self.sodium = sodium
        self.vitaminD = vitaminD
        self.vitaminE = vitaminE
        self.potassium = potassium
        self.vitaminK = vitaminK
        self.magnesium = magnesium
        self.vitaminA = vitaminA
        self.calcium = calcium
        self.vitaminC = vitaminC
        self.choline = choline
        self.iron = iron
        self.iodine = iodine
        self.zinc = zinc
        self.folate = folate
        self.vitaminB12 = vitaminB12
        self.vitaminB6 = vitaminB6
        self.selenium = selenium
        self.copper = copper
        self.manganese = manganese
        self.thiamin = thiamin
    }
}

