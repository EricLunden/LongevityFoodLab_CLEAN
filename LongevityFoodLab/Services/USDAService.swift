//
//  USDAService.swift
//  LongevityFoodLab
//
//  USDA FoodData Central API Service
//

import Foundation

// MARK: - USDA FoodData Central Service
class USDAService: ObservableObject {
    static let shared = USDAService()
    
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    private let apiKey: String
    private let session = URLSession.shared
    
    // Cache for nutrition lookups
    private var nutritionCache: [String: NutritionInfo] = [:]
    private let cacheQueue = DispatchQueue(label: "usda.cache")
    
    private init() {
        // Get API key from Config (user needs to register at https://fdc.nal.usda.gov/api-guide.html)
        self.apiKey = Config.usdaAPIKey
        print("🔑 USDAService: Initialized with API key: \(apiKey.prefix(8))...")
    }
    
    // MARK: - Search Foods
    
    /// Search for foods in USDA database
    func searchFoods(query: String, pageSize: Int = 25) async throws -> USDASearchResponse {
        guard let url = URL(string: "\(baseURL)/foods/search?api_key=\(apiKey)") else {
            throw USDAError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8.0
        
        let requestBody: [String: Any] = [
            "query": query,
            "pageSize": pageSize,
            "pageNumber": 1,
            "dataType": ["Foundation", "SR Legacy"] // Use verified data types
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔍 USDAService: Searching for '\(query)'")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ USDAService: Error response: \(errorString)")
            }
            throw USDAError.httpError(httpResponse.statusCode)
        }
        
        let searchResponse = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        print("✅ USDAService: Found \(searchResponse.foods.count) results")
        return searchResponse
    }
    
    // MARK: - Get Food Details
    
    /// Get detailed nutrition information for a food by FDC ID
    func getFoodDetails(fdcId: Int) async throws -> USDAFoodDetail {
        guard let url = URL(string: "\(baseURL)/food/\(fdcId)?api_key=\(apiKey)") else {
            throw USDAError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        
        print("🔍 USDAService: Getting details for FDC ID \(fdcId)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ USDAService: Error response: \(errorString)")
            }
            throw USDAError.httpError(httpResponse.statusCode)
        }
        
        let foodDetail = try JSONDecoder().decode(USDAFoodDetail.self, from: data)
        print("✅ USDAService: Retrieved nutrition data for \(foodDetail.description)")
        
        // Log all nutrients returned from USDA
        print("🔍 USDAService: === NUTRIENT DATA FOR \(foodDetail.description.uppercased()) ===")
        print("🔍 USDAService: Total nutrients returned: \(foodDetail.foodNutrients.count)")
        
        var vitaminB12Found = false
        var ironFound = false
        var zincFound = false
        
        // Log all nutrients
        for nutrient in foodDetail.foodNutrients {
            if let nutrientName = nutrient.nutrient?.name,
               let amountValue = nutrient.amount {
                let unit = nutrient.nutrient?.unitName ?? "unknown"
                print("🔍 USDAService:   - \(nutrientName): \(amountValue) \(unit)")
                
                // Check for specific micronutrients
                let normalizedName = nutrientName.lowercased()
                if normalizedName.contains("vitamin b12") || normalizedName.contains("cobalamin") {
                    vitaminB12Found = true
                    print("✅ USDAService:   ✓ VITAMIN B12 FOUND: \(amountValue) \(unit)")
                }
                if normalizedName.contains("iron") && !normalizedName.contains("ferritin") {
                    ironFound = true
                    print("✅ USDAService:   ✓ IRON FOUND: \(amountValue) \(unit)")
                }
                if normalizedName.contains("zinc") {
                    zincFound = true
                    print("✅ USDAService:   ✓ ZINC FOUND: \(amountValue) \(unit)")
                }
            } else {
                print("⚠️ USDAService:   - Nutrient with missing name or amount")
            }
        }
        
        // Summary check for critical micronutrients
        print("🔍 USDAService: === MICRONUTRIENT CHECK SUMMARY ===")
        print("🔍 USDAService: Vitamin B12: \(vitaminB12Found ? "✅ PRESENT" : "❌ MISSING")")
        print("🔍 USDAService: Iron: \(ironFound ? "✅ PRESENT" : "❌ MISSING")")
        print("🔍 USDAService: Zinc: \(zincFound ? "✅ PRESENT" : "❌ MISSING")")
        
        if !vitaminB12Found || !ironFound || !zincFound {
            print("⚠️ USDAService: WARNING - Some critical micronutrients are missing from USDA data")
            print("⚠️ USDAService: This may indicate incomplete data for restaurant/processed items")
        }
        
        return foodDetail
    }
    
    // MARK: - Get Nutrition for Food Name
    
    /// Search and get nutrition for a food name (convenience method)
    func getNutritionForFood(_ foodName: String, amount: Double = 100, unit: String = "g") async throws -> NutritionInfo? {
        print("🔍 USDAService: Looking up nutrition for '\(foodName)' - Amount: \(amount)\(unit)")
        
        // Convert to grams and validate amount
        let amountInGrams = convertToGrams(amount: amount, unit: unit)
        
        // Sanity check: reasonable amounts (10g to 2000g for most foods)
        if amountInGrams < 10 {
            print("⚠️ USDAService: Amount \(amountInGrams)g is too small, using minimum 10g")
            return try await getNutritionForFood(foodName, amount: 10, unit: "g")
        } else if amountInGrams > 2000 {
            print("⚠️ USDAService: Amount \(amountInGrams)g seems unreasonable for '\(foodName)'")
            print("⚠️ USDAService: Original: \(amount)\(unit). Using default 100g instead.")
            return try await getNutritionForFood(foodName, amount: 100, unit: "g")
        }
        
        // Check cache first
        let cacheKey = "\(foodName.lowercased())-\(amount)-\(unit)"
        if let cached = cacheQueue.sync(execute: { nutritionCache[cacheKey] }) {
            print("✅ USDAService: Found in cache for '\(foodName)'")
            // Validate cached result
            if let cachedCalories = Int(cached.calories), cachedCalories > 500 {
                print("⚠️ USDAService: Cached calories (\(cachedCalories)) seems high, re-fetching...")
                // Don't use cached value if it seems wrong
            } else {
                return cached
            }
        }
        
        // Step 1: Search for the food
        let searchResponse = try await searchFoods(query: foodName, pageSize: 3)
        
        guard !searchResponse.foods.isEmpty else {
            print("⚠️ USDAService: No results found for '\(foodName)'")
            return nil
        }
        
        // Step 2: Select the best matching result
        let bestMatch = selectBestMatch(from: searchResponse.foods, for: foodName)
        print("✅ USDAService: Selected best match: \(bestMatch.description) (FDC ID: \(bestMatch.fdcId))")
        
        // Step 3: Get detailed nutrition
        let foodDetail = try await getFoodDetails(fdcId: bestMatch.fdcId)
        
        // Step 4: Convert to NutritionInfo
        let nutrition = convertUSDAFoodDetailToNutritionInfo(foodDetail, amount: amount, unit: unit)
        
        // Final validation: Reject unreasonable results for single foods
        let isSingleFood = !foodName.lowercased().contains(",") && foodName.components(separatedBy: .whitespaces).count <= 2
        if let calories = Int(nutrition.calories), calories > 500 {
            if isSingleFood {
                print("❌ USDAService: REJECTING nutrition - Calories (\(calories)) too high for single food '\(foodName)'")
                print("❌ USDAService: Selected food was '\(foodDetail.description)' - likely wrong match")
                print("❌ USDAService: Returning nil to fallback to Spoonacular")
                return nil // Reject and fallback to next tier
            } else {
                print("⚠️ USDAService: Final nutrition has high calories (\(calories)) for '\(foodName)'")
                print("⚠️ USDAService: Amount used: \(amount)\(unit)")
                print("⚠️ USDAService: Consider reviewing USDA data or amount parameter")
            }
        }
        
        // Cache the result only if it passed validation
        cacheQueue.async {
            self.nutritionCache[cacheKey] = nutrition
        }
        
        return nutrition
    }
    
    /// Select the best matching food from search results
    private func selectBestMatch(from foods: [USDAFoodItem], for query: String) -> USDAFoodItem {
        let normalizedQuery = normalizeFoodName(query)
        let queryWords = normalizedQuery.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Detect if query is a simple, single-word food (like "apple", "banana", "salmon")
        let isSimpleFood = queryWords.count == 1 && normalizedQuery.count < 15
        
        // Score each result
        let scoredResults = foods.map { food -> (food: USDAFoodItem, score: Int) in
            let description = food.description.lowercased()
            var score = 0
            
            // Exact match gets highest score
            if description == normalizedQuery {
                score += 1000
            }
            
            // For simple foods, heavily penalize complex/processed foods
            if isSimpleFood {
                // Penalty for complex foods (contains multiple ingredients separated by commas)
                if description.contains(",") {
                    score -= 200 // Heavy penalty for complex foods when searching simple
                }
                
                // Penalty for processed foods (croissants, pie, cake, etc.)
                let processedKeywords = ["croissant", "pie", "cake", "cookie", "bread", "muffin", "pastry", "doughnut", "donut"]
                for keyword in processedKeywords {
                    if description.contains(keyword) && !description.hasPrefix(keyword) {
                        score -= 300 // Very heavy penalty - processed food when searching for simple food
                    }
                }
            }
            
            // Check if query words appear in description
            for word in queryWords {
                if description.contains(word) {
                    score += 100
                    
                    // Bonus if word appears at the start (main ingredient)
                    if description.hasPrefix(word) || description.hasPrefix("\(word) ") {
                        score += 50
                    }
                    
                    // Penalty if word appears after a comma (likely a modifier)
                    if let commaIndex = description.firstIndex(of: ","),
                       description[commaIndex...].contains(word) {
                        score -= 30
                    }
                }
            }
            
            // Penalty for branded products when searching for generic items
            if food.brandOwner != nil && queryWords.count <= 2 {
                score -= 20
            }
            
            // Prefer Foundation data type (more accurate)
            if food.dataType == "Foundation" {
                score += 10
            }
            
            // Penalty for results that contain the query but as a modifier
            // e.g., "salt" should not match "Butter, salted"
            let queryIsModifier = description.contains(", \(normalizedQuery)") || 
                                  description.contains(" \(normalizedQuery),")
            if queryIsModifier && !description.hasPrefix(normalizedQuery) {
                score -= 50
            }
            
            return (food: food, score: score)
        }
        
        // Return the highest scoring result
        let bestMatch = scoredResults.max(by: { $0.score < $1.score })!
        print("🔍 USDAService: Selected '\(bestMatch.food.description)' with score \(bestMatch.score) (from \(foods.count) results)")
        
        // Additional validation: if score is negative or very low, log warning
        if bestMatch.score < 50 {
            print("⚠️ USDAService: Low match score (\(bestMatch.score)) for query '\(query)' - selected '\(bestMatch.food.description)'")
        }
        
        return bestMatch.food
    }
    
    // MARK: - Unit Conversion Helper
    
    /// Convert amount to grams based on unit
    private func convertToGrams(amount: Double, unit: String) -> Double {
        let unitLower = unit.lowercased()
        switch unitLower {
        case "kg", "kilogram", "kilograms":
            return amount * 1000
        case "g", "gram", "grams":
            return amount
        case "oz", "ounce", "ounces":
            return amount * 28.35
        case "lb", "pound", "pounds":
            return amount * 453.6
        case "mg", "milligram", "milligrams":
            return amount / 1000
        default:
            // Assume grams if unknown unit
            print("⚠️ USDAService: Unknown unit '\(unit)', assuming grams")
            return amount
        }
    }
    
    // MARK: - Conversion
    
    /// Convert USDA food detail to NutritionInfo
    private func convertUSDAFoodDetailToNutritionInfo(_ foodDetail: USDAFoodDetail, amount: Double, unit: String) -> NutritionInfo {
        // Convert amount to grams first
        let amountInGrams = convertToGrams(amount: amount, unit: unit)
        
        // Sanity check: reasonable amounts (10g to 2000g for most foods)
        if amountInGrams < 10 || amountInGrams > 2000 {
            print("⚠️ USDAService: Amount \(amountInGrams)g seems unreasonable for '\(foodDetail.description)'")
            print("⚠️ USDAService: Original amount: \(amount)\(unit)")
            print("⚠️ USDAService: Clamping to reasonable range (10g-2000g)")
        }
        
        // Extract nutrients from foodDetail.foodNutrients
        var nutritionDict: [String: Double] = [:]
        
        for nutrient in foodDetail.foodNutrients {
            guard let nutrientName = nutrient.nutrient?.name,
                  let amountValue = nutrient.amount else {
                continue
            }
            
            // Map USDA nutrient names to our NutritionInfo fields
            let normalizedName = nutrientName.lowercased()
            
            // Macros
            if normalizedName.contains("energy") || normalizedName == "energy" {
                nutritionDict["calories"] = amountValue
            } else if normalizedName.contains("protein") {
                nutritionDict["protein"] = amountValue
            } else if normalizedName.contains("carbohydrate") && !normalizedName.contains("fiber") && !normalizedName.contains("sugar") {
                nutritionDict["carbohydrates"] = amountValue
            } else if normalizedName.contains("total lipid") || normalizedName.contains("fat") {
                nutritionDict["fat"] = amountValue
            } else if normalizedName.contains("fiber") {
                nutritionDict["fiber"] = amountValue
            } else if normalizedName.contains("sugars") || normalizedName.contains("sugar") {
                nutritionDict["sugar"] = amountValue
            } else if normalizedName.contains("sodium") {
                nutritionDict["sodium"] = amountValue
            } else if normalizedName.contains("saturated") && normalizedName.contains("fat") {
                nutritionDict["saturatedFat"] = amountValue
            }
            
            // Micronutrients
            if normalizedName.contains("vitamin d") {
                nutritionDict["vitaminD"] = amountValue
            } else if normalizedName.contains("vitamin e") {
                nutritionDict["vitaminE"] = amountValue
            } else if normalizedName.contains("potassium") {
                nutritionDict["potassium"] = amountValue
            } else if normalizedName.contains("vitamin k") {
                nutritionDict["vitaminK"] = amountValue
            } else if normalizedName.contains("magnesium") {
                nutritionDict["magnesium"] = amountValue
            } else if normalizedName.contains("vitamin a") {
                nutritionDict["vitaminA"] = amountValue
            } else if normalizedName.contains("calcium") {
                nutritionDict["calcium"] = amountValue
            } else if normalizedName.contains("vitamin c") {
                nutritionDict["vitaminC"] = amountValue
            } else if normalizedName.contains("choline") {
                nutritionDict["choline"] = amountValue
            } else if normalizedName.contains("iron") {
                nutritionDict["iron"] = amountValue
            } else if normalizedName.contains("iodine") {
                nutritionDict["iodine"] = amountValue
            } else if normalizedName.contains("zinc") {
                nutritionDict["zinc"] = amountValue
            } else if normalizedName.contains("folate") {
                nutritionDict["folate"] = amountValue
            } else if normalizedName.contains("vitamin b12") {
                nutritionDict["vitaminB12"] = amountValue
            } else if normalizedName.contains("vitamin b6") {
                nutritionDict["vitaminB6"] = amountValue
            } else if normalizedName.contains("selenium") {
                nutritionDict["selenium"] = amountValue
            } else if normalizedName.contains("copper") {
                nutritionDict["copper"] = amountValue
            } else if normalizedName.contains("manganese") {
                nutritionDict["manganese"] = amountValue
            } else if normalizedName.contains("thiamin") {
                nutritionDict["thiamin"] = amountValue
            }
        }
        
        // Sanity check: USDA data validation
        // Check if calories seem wrong (e.g., per 1000g instead of per 100g)
        if let rawCalories = nutritionDict["calories"], rawCalories > 1000 {
            print("⚠️ USDAService: WARNING - Raw calories (\(rawCalories)) per 100g seems very high")
            print("⚠️ USDAService: This might indicate USDA data is per 1000g instead of per 100g")
            print("⚠️ USDAService: Food: \(foodDetail.description), FDC ID: \(foodDetail.fdcId)")
            // Don't auto-correct, but log for investigation
        }
        
        // Clamp amount to reasonable range for scaling
        let clampedAmount = max(10, min(2000, amountInGrams))
        let scaleFactor = clampedAmount / 100.0
        
        print("🔍 USDAService: Converting nutrition - Amount: \(amount)\(unit) = \(amountInGrams)g, Clamped: \(clampedAmount)g, ScaleFactor: \(scaleFactor)")
        if let rawCalories = nutritionDict["calories"] {
            let scaledCalories = rawCalories * scaleFactor
            print("🔍 USDAService: Calories - Raw: \(rawCalories) per 100g, Scaled: \(scaledCalories) for \(clampedAmount)g")
            
            // Final sanity check on scaled calories
            if scaledCalories > 500 {
                print("⚠️ USDAService: WARNING - Scaled calories (\(Int(scaledCalories))) seems high for \(clampedAmount)g")
                print("⚠️ USDAService: Food: \(foodDetail.description), FDC ID: \(foodDetail.fdcId)")
                print("⚠️ USDAService: This might indicate incorrect amount or wrong USDA data")
            }
        }
        
        // Helper to format and scale values with validation
        func formatValue(_ key: String, defaultUnit: String) -> String {
            if let value = nutritionDict[key] {
                let scaled = value * scaleFactor
                
                // Additional sanity checks for specific nutrients
                if key == "calories" {
                    let caloriesInt = Int(round(scaled))
                    if caloriesInt > 500 {
                        print("⚠️ USDAService: WARNING - Final calories (\(caloriesInt)) exceeds 500 for \(clampedAmount)g")
                    }
                    return "\(caloriesInt)"
                } else if key == "sodium" {
                    return "\(Int(round(scaled)))mg"
                } else {
                    return String(format: "%.1f\(defaultUnit)", scaled)
                }
            }
            return "N/A"
        }
        
        return NutritionInfo(
            calories: formatValue("calories", defaultUnit: ""),
            protein: formatValue("protein", defaultUnit: "g"),
            carbohydrates: formatValue("carbohydrates", defaultUnit: "g"),
            fat: formatValue("fat", defaultUnit: "g"),
            sugar: formatValue("sugar", defaultUnit: "g"),
            fiber: formatValue("fiber", defaultUnit: "g"),
            sodium: formatValue("sodium", defaultUnit: ""),
            saturatedFat: nutritionDict["saturatedFat"] != nil ? formatValue("saturatedFat", defaultUnit: "g") : nil,
            vitaminD: nutritionDict["vitaminD"] != nil ? formatValue("vitaminD", defaultUnit: "mcg") : nil,
            vitaminE: nutritionDict["vitaminE"] != nil ? formatValue("vitaminE", defaultUnit: "mg") : nil,
            potassium: nutritionDict["potassium"] != nil ? formatValue("potassium", defaultUnit: "mg") : nil,
            vitaminK: nutritionDict["vitaminK"] != nil ? formatValue("vitaminK", defaultUnit: "mcg") : nil,
            magnesium: nutritionDict["magnesium"] != nil ? formatValue("magnesium", defaultUnit: "mg") : nil,
            vitaminA: nutritionDict["vitaminA"] != nil ? formatValue("vitaminA", defaultUnit: "mcg") : nil,
            calcium: nutritionDict["calcium"] != nil ? formatValue("calcium", defaultUnit: "mg") : nil,
            vitaminC: nutritionDict["vitaminC"] != nil ? formatValue("vitaminC", defaultUnit: "mg") : nil,
            choline: nutritionDict["choline"] != nil ? formatValue("choline", defaultUnit: "mg") : nil,
            iron: nutritionDict["iron"] != nil ? formatValue("iron", defaultUnit: "mg") : nil,
            iodine: nutritionDict["iodine"] != nil ? formatValue("iodine", defaultUnit: "mcg") : nil,
            zinc: nutritionDict["zinc"] != nil ? formatValue("zinc", defaultUnit: "mg") : nil,
            folate: nutritionDict["folate"] != nil ? formatValue("folate", defaultUnit: "mcg") : nil,
            vitaminB12: nutritionDict["vitaminB12"] != nil ? formatValue("vitaminB12", defaultUnit: "mcg") : nil,
            vitaminB6: nutritionDict["vitaminB6"] != nil ? formatValue("vitaminB6", defaultUnit: "mg") : nil,
            selenium: nutritionDict["selenium"] != nil ? formatValue("selenium", defaultUnit: "mcg") : nil,
            copper: nutritionDict["copper"] != nil ? formatValue("copper", defaultUnit: "mg") : nil,
            manganese: nutritionDict["manganese"] != nil ? formatValue("manganese", defaultUnit: "mg") : nil,
            thiamin: nutritionDict["thiamin"] != nil ? formatValue("thiamin", defaultUnit: "mg") : nil
        )
    }
    
    /// Normalize food name for better USDA matching
    private func normalizeFoodName(_ name: String) -> String {
        var normalized = name.lowercased()
        
        // Remove common cooking methods/descriptors
        let descriptors = ["grilled", "roasted", "baked", "fried", "steamed", "boiled", "raw", "cooked", "fresh", "frozen"]
        for descriptor in descriptors {
            normalized = normalized.replacingOccurrences(of: "\(descriptor) ", with: "")
            normalized = normalized.replacingOccurrences(of: " \(descriptor)", with: "")
        }
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - USDA Errors

enum USDAError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid USDA API URL"
        case .invalidResponse:
            return "Invalid response from USDA API"
        case .httpError(let code):
            return "USDA API HTTP error: \(code)"
        case .decodingError:
            return "Failed to decode USDA API response"
        }
    }
}

// MARK: - USDA Data Models

struct USDASearchResponse: Codable {
    let foods: [USDAFoodItem]
    let totalHits: Int
    let currentPage: Int
    let totalPages: Int
}

struct USDAFoodItem: Codable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let brandOwner: String?
    let brandName: String?
    let ingredients: String?
}

struct USDAFoodDetail: Codable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let foodNutrients: [USDAFoodNutrient]
    let foodPortions: [USDAFoodPortion]?
}

struct USDAFoodNutrient: Codable {
    let nutrient: USDANutrient?
    let amount: Double?
    let dataPoints: Int?
}

struct USDANutrient: Codable {
    let id: Int
    let name: String
    let unitName: String?
}

struct USDAFoodPortion: Codable {
    let amount: Double?
    let gramWeight: Double?
    let portionDescription: String?
}

