//
//  FoodData.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 7/12/25.
//

import Foundation

// MARK: - Data Completeness & Source Tracking
enum DataCompleteness: String, Codable {
    case complete
    case partial
    case estimated
    case unavailable
    case cached
}

enum DataSource: String, Codable {
    case openAI
    case cached
    case fallback
    case reconstructed
}

struct FoodAnalysis: Codable, Equatable {
    let foodName: String
    let overallScore: Int
    let summary: String
    let healthScores: HealthScores
    let keyBenefits: [String]? // Optional - loaded on demand
    let ingredients: [FoodIngredient]? // Optional - loaded on demand
    let bestPreparation: String? // Optional - loaded on demand
    let servingSize: String
    let nutritionInfo: NutritionInfo? // Optional - loaded on demand
    let scanType: String? // "meal", "food", "product", "supplement", "nutrition_label", "supplement_facts"
    let foodNames: [String]? // For meals: list of individual food items visible in the image (e.g., ["Grilled Chicken", "Avocado", "Lettuce"])
    let suggestions: [GrocerySuggestion]? // Optional - healthier choice suggestions (cached)
    
    // Data completeness and source tracking (optional for backward compatibility)
    let dataCompleteness: DataCompleteness?
    let analysisTimestamp: Date?
    let dataSource: DataSource?
    
    // Computed properties for backward compatibility
    var keyBenefitsOrDefault: [String] {
        return keyBenefits ?? []
    }
    
    var ingredientsOrDefault: [FoodIngredient] {
        return ingredients ?? []
    }
    
    var bestPreparationOrDefault: String {
        return bestPreparation ?? ""
    }
    
    var nutritionInfoOrDefault: NutritionInfo {
        return nutritionInfo ?? NutritionInfo(
            calories: "N/A",
            protein: "N/A",
            carbohydrates: "N/A",
            fat: "N/A",
            sugar: "N/A",
            fiber: "N/A",
            sodium: "N/A"
        )
    }
    
    // Computed property for data completeness (defaults to complete for backward compatibility)
    var dataCompletenessOrDefault: DataCompleteness {
        return dataCompleteness ?? .complete
    }
    
    /// Checks if this analysis qualifies for longevity-population reassurance message
    /// Returns true only if ALL conditions are met: score ≥85, plant-forward/Mediterranean pattern, minimal processing, no refined sugar dominance
    var qualifiesForLongevityReassurance: Bool {
        // Must score ≥85
        guard overallScore >= 85 else { return false }
        
        // Must not be a product/nutrition label (only meals/foods qualify)
        if let scanTypeValue = scanType {
            guard scanTypeValue != "product" && scanTypeValue != "nutrition_label" && scanTypeValue != "supplement" && scanTypeValue != "supplement_facts" else { return false }
        }
        
        // Get ingredients for pattern analysis
        let ingredients = ingredientsOrDefault
        guard !ingredients.isEmpty else { return false }
        
        // Check for plant-forward/Mediterranean pattern indicators
        let ingredientNames = ingredients.map { $0.name.lowercased() }.joined(separator: " ")
        let foodNameLower = foodName.lowercased()
        let combinedText = ingredientNames + " " + foodNameLower
        
        // Mediterranean/plant-forward indicators
        let mediterraneanIngredients = [
            "olive oil", "extra virgin", "evoo", "tomato", "tomatoes", "eggplant", "zucchini",
            "bell pepper", "garlic", "basil", "oregano", "rosemary", "thyme", "parsley",
            "chickpea", "lentil", "white bean", "cannellini", "hummus", "falafel",
            "salmon", "sardine", "anchovy", "shrimp", "couscous", "bulgur", "farro"
        ]
        let mediterraneanCount = mediterraneanIngredients.filter { combinedText.contains($0) }.count
        
        // Plant-forward indicators (vegetables, legumes, whole grains, healthy fats)
        let plantForwardIndicators = [
            "vegetable", "legume", "bean", "lentil", "chickpea", "quinoa", "brown rice",
            "whole grain", "whole wheat", "oats", "barley", "bulgur", "farro",
            "spinach", "kale", "arugula", "broccoli", "cauliflower", "brussels sprouts",
            "avocado", "nuts", "seeds", "walnut", "almond", "chia", "flax"
        ]
        let plantForwardCount = plantForwardIndicators.filter { combinedText.contains($0) }.count
        
        // Must have Mediterranean OR plant-forward pattern (at least 3 indicators)
        let hasPatternAlignment = mediterraneanCount >= 3 || plantForwardCount >= 3
        guard hasPatternAlignment else { return false }
        
        // Check for ultra-processed ingredients (disqualifiers)
        let ultraProcessedIndicators = [
            "high fructose corn syrup", "hydrogenated", "partially hydrogenated",
            "artificial flavor", "artificial color", "artificial sweetener",
            "sodium nitrite", "sodium nitrate", "bha", "bht", "tbhq",
            "monosodium glutamate", "msg", "carrageenan", "polysorbate"
        ]
        let hasUltraProcessed = ultraProcessedIndicators.contains { combinedText.contains($0) }
        guard !hasUltraProcessed else { return false }
        
        // Check for refined sugar dominance (disqualifier)
        let refinedSugarIndicators = ["white sugar", "cane sugar", "brown sugar", "powdered sugar", "corn syrup", "high fructose"]
        let sugarCount = refinedSugarIndicators.filter { combinedText.contains($0) }.count
        
        // Check nutrition info if available
        if let nutrition = nutritionInfo {
            let sugarValue = nutrition.sugar
            if sugarValue != "N/A" && sugarValue != "Unavailable" {
                // Try to parse sugar value
                let sugarStr = sugarValue.lowercased().replacingOccurrences(of: "g", with: "").trimmingCharacters(in: .whitespaces)
                if let sugarGrams = Double(sugarStr), sugarGrams > 20 {
                    // More than 20g sugar per serving suggests refined sugar dominance
                    return false
                }
            }
        }
        
        // If multiple refined sugar indicators AND high sugar count, disqualify
        if sugarCount >= 2 {
            return false
        }
        
        // Check for dessert indicators (disqualifier - no "halo effect")
        let dessertIndicators = ["cake", "cookie", "pie", "pastry", "donut", "muffin", "brownie", "cupcake", "ice cream", "candy"]
        let isDessert = dessertIndicators.contains { foodNameLower.contains($0) }
        guard !isDessert else { return false }
        
        return true
    }
    
    /// Returns a randomly selected longevity-population reassurance phrase
    /// Only call this if qualifiesForLongevityReassurance is true
    var longevityReassurancePhrase: String {
        let phrases = [
            "This way of eating reflects patterns seen in some of the world's longest-lived populations.",
            "Meals like this are common in dietary patterns associated with long-term health and longevity.",
            "This meal fits well within eating patterns observed in long-lived communities.",
            "Foods like these are often part of diets linked with exceptional longevity.",
            "This eating pattern mirrors foods commonly enjoyed in regions known for long life."
        ]
        // Use food name hash for consistent selection per food (not truly random, but varies by food)
        let hash = abs(foodName.hashValue)
        return phrases[hash % phrases.count]
    }
    
    /// Returns a new FoodAnalysis with normalized health scores that are coherent with the overall score
    func withNormalizedHealthScores() -> FoodAnalysis {
        var normalizedScores = healthScores
        normalizedScores.normalize(overallScore: overallScore)
        
        return FoodAnalysis(
            foodName: foodName,
            overallScore: overallScore,
            summary: summary,
            healthScores: normalizedScores,
            keyBenefits: keyBenefits,
            ingredients: ingredients,
            bestPreparation: bestPreparation,
            servingSize: servingSize,
            nutritionInfo: nutritionInfo,
            scanType: scanType,
            foodNames: foodNames,
            suggestions: suggestions,
            dataCompleteness: dataCompleteness,
            analysisTimestamp: analysisTimestamp,
            dataSource: dataSource
        )
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        foodName = try container.decode(String.self, forKey: .foodName)
        overallScore = try container.decode(Int.self, forKey: .overallScore)
        summary = try container.decode(String.self, forKey: .summary)
        healthScores = try container.decode(HealthScores.self, forKey: .healthScores)
        keyBenefits = try container.decodeIfPresent([String].self, forKey: .keyBenefits)
        ingredients = try container.decodeIfPresent([FoodIngredient].self, forKey: .ingredients)
        bestPreparation = try container.decodeIfPresent(String.self, forKey: .bestPreparation)
        servingSize = try container.decode(String.self, forKey: .servingSize)
        nutritionInfo = try container.decodeIfPresent(NutritionInfo.self, forKey: .nutritionInfo)
        scanType = try container.decodeIfPresent(String.self, forKey: .scanType)
        foodNames = try container.decodeIfPresent([String].self, forKey: .foodNames)
        suggestions = try container.decodeIfPresent([GrocerySuggestion].self, forKey: .suggestions)
        
        // New fields with defaults for backward compatibility
        dataCompleteness = try container.decodeIfPresent(DataCompleteness.self, forKey: .dataCompleteness)
        analysisTimestamp = try container.decodeIfPresent(Date.self, forKey: .analysisTimestamp)
        dataSource = try container.decodeIfPresent(DataSource.self, forKey: .dataSource)
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(foodName, forKey: .foodName)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encode(summary, forKey: .summary)
        try container.encode(healthScores, forKey: .healthScores)
        try container.encodeIfPresent(keyBenefits, forKey: .keyBenefits)
        try container.encodeIfPresent(ingredients, forKey: .ingredients)
        try container.encodeIfPresent(bestPreparation, forKey: .bestPreparation)
        try container.encode(servingSize, forKey: .servingSize)
        try container.encodeIfPresent(nutritionInfo, forKey: .nutritionInfo)
        try container.encodeIfPresent(scanType, forKey: .scanType)
        try container.encodeIfPresent(foodNames, forKey: .foodNames)
        try container.encodeIfPresent(suggestions, forKey: .suggestions)
        try container.encodeIfPresent(dataCompleteness, forKey: .dataCompleteness)
        try container.encodeIfPresent(analysisTimestamp, forKey: .analysisTimestamp)
        try container.encodeIfPresent(dataSource, forKey: .dataSource)
    }
    
    enum CodingKeys: String, CodingKey {
        case foodName
        case overallScore
        case summary
        case healthScores
        case keyBenefits
        case ingredients
        case bestPreparation
        case servingSize
        case nutritionInfo
        case scanType
        case foodNames
        case suggestions
        case dataCompleteness
        case analysisTimestamp
        case dataSource
    }
    
    // Regular initializer
    init(
        foodName: String,
        overallScore: Int,
        summary: String,
        healthScores: HealthScores,
        keyBenefits: [String]? = nil,
        ingredients: [FoodIngredient]? = nil,
        bestPreparation: String? = nil,
        servingSize: String,
        nutritionInfo: NutritionInfo? = nil,
        scanType: String? = nil,
        foodNames: [String]? = nil,
        suggestions: [GrocerySuggestion]? = nil,
        dataCompleteness: DataCompleteness? = nil,
        analysisTimestamp: Date? = nil,
        dataSource: DataSource? = nil
    ) {
        self.foodName = foodName
        self.overallScore = overallScore
        self.summary = summary
        self.healthScores = healthScores
        self.keyBenefits = keyBenefits
        self.ingredients = ingredients
        self.bestPreparation = bestPreparation
        self.servingSize = servingSize
        self.nutritionInfo = nutritionInfo
        self.scanType = scanType
        self.foodNames = foodNames
        self.suggestions = suggestions
        self.dataCompleteness = dataCompleteness
        self.analysisTimestamp = analysisTimestamp
        self.dataSource = dataSource
    }
}

struct HealthScores: Codable, Equatable {
    var allergies: Int
    var antiInflammation: Int
    var bloodSugar: Int
    var brainHealth: Int
    var detoxLiver: Int
    var energy: Int
    var eyeHealth: Int
    var heartHealth: Int
    var immune: Int
    var jointHealth: Int
    var kidneys: Int
    var mood: Int
    var skin: Int
    var sleep: Int
    var stress: Int
    var weightManagement: Int
    
    /// Normalizes health scores to ensure coherence with overall score
    /// - Parameter overallScore: The overall longevity score (0-100)
    mutating func normalize(overallScore: Int) {
        // Define the target range: ±15 points from overall score
        let targetMin = max(0, overallScore - 15)
        let targetMax = min(100, overallScore + 15)
        
        // For low-scoring foods (≤50), enforce stricter bounds (30-60 range)
        let strictMin: Int
        let strictMax: Int
        if overallScore <= 50 {
            strictMin = max(0, overallScore - 20)
            strictMax = min(100, overallScore + 20)
        } else {
            strictMin = targetMin
            strictMax = targetMax
        }
        
        // Normalize each score
        allergies = normalizeScore(allergies, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        antiInflammation = normalizeScore(antiInflammation, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: overallScore >= 70) // Can be higher for antioxidant-rich foods if overall is high
        bloodSugar = normalizeScore(bloodSugar, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: true, allowHigher: false) // Can be much lower for high-sugar foods
        brainHealth = normalizeScore(brainHealth, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        detoxLiver = normalizeScore(detoxLiver, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        energy = normalizeScore(energy, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        eyeHealth = normalizeScore(eyeHealth, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        heartHealth = normalizeScore(heartHealth, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: overallScore >= 70) // Can be higher for omega-3 rich foods if overall is high
        immune = normalizeScore(immune, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        jointHealth = normalizeScore(jointHealth, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        kidneys = normalizeScore(kidneys, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        mood = normalizeScore(mood, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        skin = normalizeScore(skin, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        sleep = normalizeScore(sleep, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        stress = normalizeScore(stress, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
        weightManagement = normalizeScore(weightManagement, overallScore: overallScore, strictMin: strictMin, strictMax: strictMax, allowLower: false, allowHigher: false)
    }
    
    /// Helper function to normalize a single score
    private func normalizeScore(_ score: Int, overallScore: Int, strictMin: Int, strictMax: Int, allowLower: Bool, allowHigher: Bool) -> Int {
        // Handle unavailable scores
        if score == -1 {
            return -1
        }
        
        // For bloodSugar, allow it to be much lower for high-sugar foods
        if allowLower && score < strictMin {
            // Allow bloodSugar to be up to 25 points lower than overall score
            let lowerBound = max(0, overallScore - 25)
            // Clamp to lowerBound if score is below it, otherwise keep score
            if score < lowerBound {
                return lowerBound
            }
            return score
        }
        
        // For heartHealth/antiInflammation, allow slightly higher if overall score is high
        if allowHigher && score > strictMax && overallScore >= 70 {
            // Allow up to 15 points higher than strictMax
            let upperBound = min(100, strictMax + 15)
            return min(upperBound, score) // Keep original if it's within extended range
        }
        
        // For all other cases, clamp to strict range
        if score < strictMin {
            return strictMin
        } else if score > strictMax {
            return strictMax
        }
        
        return score
    }
    
    // Regular initializer
    init(
        allergies: Int,
        antiInflammation: Int,
        bloodSugar: Int,
        brainHealth: Int,
        detoxLiver: Int,
        energy: Int,
        eyeHealth: Int,
        heartHealth: Int,
        immune: Int,
        jointHealth: Int,
        kidneys: Int,
        mood: Int,
        skin: Int,
        sleep: Int,
        stress: Int,
        weightManagement: Int
    ) {
        self.allergies = allergies
        self.antiInflammation = antiInflammation
        self.bloodSugar = bloodSugar
        self.brainHealth = brainHealth
        self.detoxLiver = detoxLiver
        self.energy = energy
        self.eyeHealth = eyeHealth
        self.heartHealth = heartHealth
        self.immune = immune
        self.jointHealth = jointHealth
        self.kidneys = kidneys
        self.mood = mood
        self.skin = skin
        self.sleep = sleep
        self.stress = stress
        self.weightManagement = weightManagement
    }
    
    // Custom decoder for backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields (existing)
        heartHealth = try container.decode(Int.self, forKey: .heartHealth)
        brainHealth = try container.decode(Int.self, forKey: .brainHealth)
        antiInflammation = try container.decode(Int.self, forKey: .antiInflammation)
        jointHealth = try container.decode(Int.self, forKey: .jointHealth)
        eyeHealth = try container.decode(Int.self, forKey: .eyeHealth)
        weightManagement = try container.decode(Int.self, forKey: .weightManagement)
        bloodSugar = try container.decode(Int.self, forKey: .bloodSugar)
        energy = try container.decode(Int.self, forKey: .energy)
        immune = try container.decode(Int.self, forKey: .immune)
        sleep = try container.decode(Int.self, forKey: .sleep)
        skin = try container.decode(Int.self, forKey: .skin)
        stress = try container.decode(Int.self, forKey: .stress)
        
        // New fields with defaults for backward compatibility
        allergies = try container.decodeIfPresent(Int.self, forKey: .allergies) ?? 75
        detoxLiver = try container.decodeIfPresent(Int.self, forKey: .detoxLiver) ?? (try container.decodeIfPresent(Int.self, forKey: .longevity) ?? 75) // Support both old and new field names
        kidneys = try container.decodeIfPresent(Int.self, forKey: .kidneys) ?? 75
        mood = try container.decodeIfPresent(Int.self, forKey: .mood) ?? 75
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(allergies, forKey: .allergies)
        try container.encode(antiInflammation, forKey: .antiInflammation)
        try container.encode(bloodSugar, forKey: .bloodSugar)
        try container.encode(brainHealth, forKey: .brainHealth)
        try container.encode(detoxLiver, forKey: .detoxLiver)
        try container.encode(energy, forKey: .energy)
        try container.encode(eyeHealth, forKey: .eyeHealth)
        try container.encode(heartHealth, forKey: .heartHealth)
        try container.encode(immune, forKey: .immune)
        try container.encode(jointHealth, forKey: .jointHealth)
        try container.encode(kidneys, forKey: .kidneys)
        try container.encode(mood, forKey: .mood)
        try container.encode(skin, forKey: .skin)
        try container.encode(sleep, forKey: .sleep)
        try container.encode(stress, forKey: .stress)
        try container.encode(weightManagement, forKey: .weightManagement)
    }
    
    enum CodingKeys: String, CodingKey {
        case allergies
        case antiInflammation
        case bloodSugar
        case brainHealth
        case detoxLiver
        case energy
        case eyeHealth
        case heartHealth
        case immune
        case jointHealth
        case kidneys
        case longevity // Keep for backward compatibility
        case mood
        case skin
        case sleep
        case stress
        case weightManagement
    }
}

struct FoodIngredient: Codable, Equatable {
    let name: String
    let impact: String
    let explanation: String
}

// MARK: - Grocery Suggestions (for Healthier Choices)
struct GrocerySuggestion: Codable, Equatable {
    let brandName: String
    let productName: String
    let score: Int
    let reason: String
    let keyBenefits: [String]
    let priceRange: String
    let availability: String
}

struct GrocerySuggestionsResponse: Codable {
    let suggestions: [GrocerySuggestion]
}

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
