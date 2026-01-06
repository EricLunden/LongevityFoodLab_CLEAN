//
//  OpenFoodFactsService.swift
//  LongevityFoodLab
//
//  OpenFoodFacts API Integration for Product Lookup by Barcode
//

import Foundation

// MARK: - OpenFoodFacts Service

class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    
    private let baseURL = "https://world.openfoodfacts.org/api/v2"
    private let session = URLSession.shared
    
    private init() {
        print("🌐 OpenFoodFactsService: Initialized")
    }
    
    // MARK: - Product Lookup
    
    /// Fetch product data by barcode from OpenFoodFacts API
    /// - Parameter barcode: Product barcode (EAN-13, UPC-A, etc.)
    /// - Returns: OpenFoodFactsProduct if found, nil otherwise
    func getProduct(barcode: String) async throws -> OpenFoodFactsProduct? {
        let url = URL(string: "\(baseURL)/product/\(barcode).json")!
        
        print("🌐 OpenFoodFactsService: Fetching product for barcode: \(barcode)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        request.setValue("LongevityFoodLab/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenFoodFactsError.invalidResponse
            }
            
            print("🌐 OpenFoodFactsService: Response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    print("🌐 OpenFoodFactsService: Product not found (404)")
                    return nil
                }
                throw OpenFoodFactsError.httpError(statusCode: httpResponse.statusCode)
            }
            
            // Debug: Log raw JSON response to see actual field names
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let product = jsonObject["product"] as? [String: Any] {
                // Log product name fields
                let productNameKeys = product.keys.filter { $0.lowercased().contains("name") || $0.lowercased().contains("product") || $0.lowercased() == "brands" }
                print("🌐 OpenFoodFactsService: Product name-related keys: \(productNameKeys.sorted().joined(separator: ", "))")
                for key in productNameKeys.sorted() {
                    if let value = product[key] {
                        print("🌐 OpenFoodFactsService: product['\(key)'] = \(value)")
                    }
                }
                
                // Log nutriments keys (abbreviated)
                if let nutriments = product["nutriments"] as? [String: Any] {
                    print("🌐 OpenFoodFactsService: Raw nutriments keys found: \(nutriments.keys.sorted().joined(separator: ", "))")
                }
            } else {
                print("🌐 OpenFoodFactsService: Could not parse product from raw JSON")
            }
            
            let decoder = JSONDecoder()
            // Use useDefaultKeys since we have explicit CodingKeys for all structs
            // This ensures CodingKeys with hyphens (like "energy-kcal_100g") are handled correctly
            decoder.keyDecodingStrategy = .useDefaultKeys
            
            let apiResponse = try decoder.decode(OpenFoodFactsResponse.self, from: data)
            
            guard apiResponse.status == 1, let product = apiResponse.product else {
                print("🌐 OpenFoodFactsService: Product not found in response")
                return nil
            }
            
            print("🌐 OpenFoodFactsService: Product found: \(product.productName ?? "Unknown")")
            
            // Debug logging: Check what nutrition data we actually received
            if let nutriments = product.nutriments {
                print("🌐 OpenFoodFactsService: Nutriments object exists")
                print("🌐 OpenFoodFactsService: energyKcal100g: \(nutriments.energyKcal100g?.description ?? "nil")")
                print("🌐 OpenFoodFactsService: energyKcalServing: \(nutriments.energyKcalServing?.description ?? "nil")")
                print("🌐 OpenFoodFactsService: proteins100g: \(nutriments.proteins100g?.description ?? "nil")")
                print("🌐 OpenFoodFactsService: proteinsServing: \(nutriments.proteinsServing?.description ?? "nil")")
                print("🌐 OpenFoodFactsService: carbohydrates100g: \(nutriments.carbohydrates100g?.description ?? "nil")")
                print("🌐 OpenFoodFactsService: carbohydratesServing: \(nutriments.carbohydratesServing?.description ?? "nil")")
                print("🌐 OpenFoodFactsService: fat100g: \(nutriments.fat100g?.description ?? "nil")")
                print("🌐 OpenFoodFactsService: fatServing: \(nutriments.fatServing?.description ?? "nil")")
            } else {
                print("🌐 OpenFoodFactsService: Nutriments object is nil")
            }
            
            return product
            
        } catch let error as DecodingError {
            print("🌐 OpenFoodFactsService: Decoding error: \(error)")
            throw OpenFoodFactsError.decodingError(error)
        } catch {
            print("🌐 OpenFoodFactsService: Network error: \(error.localizedDescription)")
            throw OpenFoodFactsError.networkError(error)
        }
    }
    
    // MARK: - Data Mapping
    
    /// Build a clean product name by removing duplicates and redundant information
    private func buildCleanProductName(
        brand: String?,
        productNameEnImported: String?,
        productNameEn: String?,
        productName: String?,
        barcode: String?
    ) -> String {
        // Priority order: imported name > English name > product name
        var nameToUse: String?
        
        if let imported = productNameEnImported, !imported.isEmpty {
            nameToUse = imported
        } else if let enName = productNameEn, !enName.isEmpty {
            nameToUse = enName
        } else if let name = productName, !name.isEmpty {
            nameToUse = name
        }
        
        // Clean the name: remove redundant comma-separated parts
        if let name = nameToUse {
            // Split by comma and take the first meaningful part
            let parts = name.components(separatedBy: ",")
            var cleanedName = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
            
            // Remove duplicate words within the name itself
            cleanedName = removeDuplicateWords(from: cleanedName)
            nameToUse = cleanedName
        }
        
        // Combine with brand if available
        if let brand = brand, !brand.isEmpty, let name = nameToUse {
            let brandLower = brand.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let nameLower = name.lowercased()
            
            // Check if brand (or significant parts of it) is already in the name
            // Split brand into words and check if any significant word is in the name
            let brandWords = brandLower.components(separatedBy: .whitespaces).filter { $0.count > 2 }
            let brandAlreadyInName = brandWords.contains { nameLower.contains($0) } || nameLower.contains(brandLower)
            
            if !brandAlreadyInName {
                // Combine brand + name, removing duplicate words
                let combined = "\(brand) \(name)"
                return removeDuplicateWords(from: combined)
            } else {
                // Brand already in name, just clean it
                return removeDuplicateWords(from: name)
            }
        } else if let name = nameToUse {
            return name
        } else if let brand = brand, !brand.isEmpty {
            return brand
        } else if let barcode = barcode {
            return "Product \(barcode)"
        } else {
            return "Unknown Product"
        }
    }
    
    /// Remove duplicate words from a string (case-insensitive)
    private func removeDuplicateWords(from text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        var seenWords = Set<String>()
        var result: [String] = []
        
        for word in words {
            let wordLower = word.lowercased()
            // Skip empty strings and very short words (like "a", "an", "the")
            if word.isEmpty || (word.count <= 2 && wordLower != "hp") {
                continue
            }
            
            // Check if we've seen this word (case-insensitive)
            if !seenWords.contains(wordLower) {
                seenWords.insert(wordLower)
                result.append(word)
            }
        }
        
        return result.joined(separator: " ")
    }
    
    /// Convert OpenFoodFactsProduct to FoodAnalysis
    /// - Parameter product: OpenFoodFacts product data
    /// - Returns: FoodAnalysis struct ready for display
    func mapToFoodAnalysis(_ product: OpenFoodFactsProduct) -> FoodAnalysis {
        // Map nutrition data
        let nutritionInfo = mapNutritionInfo(from: product.nutriments)
        
        // Calculate scores from authoritative data
        let productNameForCategory = product.productNameEnImported ?? product.productNameEn ?? product.productName ?? ""
        let categories = product.categories ?? ""
        let overallScore = calculateScore(from: product.nutriments, ingredients: product.ingredientsText, novaGroup: product.novaGroup, productName: productNameForCategory, categories: categories)
        let healthScores = calculateHealthScores(from: product.nutriments, ingredients: product.ingredientsText, overallScore: overallScore, novaGroup: product.novaGroup)
        
        // Generate summary from nutrition facts
        let summary = generateSummary(from: product, nutritionInfo: nutritionInfo, score: overallScore)
        
        // Parse ingredients
        let ingredients = parseIngredients(from: product.ingredientsText)
        
        // Better product name handling - prefer imported name, combine with brand if available
        let productName = buildCleanProductName(
            brand: product.brands,
            productNameEnImported: product.productNameEnImported,
            productNameEn: product.productNameEn,
            productName: product.productName,
            barcode: product.barcode
        )
        
        return FoodAnalysis(
            foodName: productName,
            overallScore: overallScore,
            summary: summary,
            healthScores: healthScores,
            keyBenefits: nil,
            ingredients: ingredients.isEmpty ? nil : ingredients,
            bestPreparation: nil, // Will be generated separately in Phase 3
            servingSize: product.nutriments?.servingSize ?? "100g",
            nutritionInfo: nutritionInfo,
            scanType: "product",
            foodNames: nil,
            suggestions: nil,
            dataCompleteness: .complete,
            analysisTimestamp: Date(),
            dataSource: .openAI // Will be updated to .openFoodFacts in future
        )
    }
    
    /// Check if product has meaningful nutrition data
    /// - Parameter product: OpenFoodFacts product data
    /// - Returns: true if product has usable nutrition data
    func hasMeaningfulNutritionData(_ product: OpenFoodFactsProduct) -> Bool {
        guard let nutriments = product.nutriments else {
            print("🌐 OpenFoodFactsService: hasMeaningfulNutritionData - nutriments is nil")
            return false
        }
        
        // Check if we have meaningful nutrition values (per 100g OR per serving)
        let hasCalories = (nutriments.energyKcal100g ?? 0) > 0 || (nutriments.energyKcalServing ?? 0) > 0
        let hasMacros = (nutriments.proteins100g ?? 0) > 0 || 
                        (nutriments.carbohydrates100g ?? 0) > 0 || 
                        (nutriments.fat100g ?? 0) > 0 ||
                        (nutriments.proteinsServing ?? 0) > 0 ||
                        (nutriments.carbohydratesServing ?? 0) > 0 ||
                        (nutriments.fatServing ?? 0) > 0
        
        let result = hasCalories || hasMacros
        print("🌐 OpenFoodFactsService: hasMeaningfulNutritionData - hasCalories: \(hasCalories), hasMacros: \(hasMacros), result: \(result)")
        
        return result
    }
    
    // MARK: - Nutrition Mapping
    
    func mapNutritionInfo(from nutriments: Nutriments?) -> NutritionInfo {
        guard let nutriments = nutriments else {
            return NutritionInfo(
                calories: "N/A",
                protein: "N/A",
                carbohydrates: "N/A",
                fat: "N/A",
                sugar: "N/A",
                fiber: "N/A",
                sodium: "N/A"
            )
        }
        
        // Prefer serving values if available, otherwise use per 100g
        let calories = formatValue(nutriments.energyKcalServing ?? nutriments.energyKcal100g, unit: "kcal")
        let protein = formatValue(nutriments.proteinsServing ?? nutriments.proteins100g, unit: "g")
        let carbohydrates = formatValue(nutriments.carbohydratesServing ?? nutriments.carbohydrates100g, unit: "g")
        let fat = formatValue(nutriments.fatServing ?? nutriments.fat100g, unit: "g")
        let sugar = formatValue(nutriments.sugarsServing ?? nutriments.sugars100g, unit: "g")
        let fiber = formatValue(nutriments.fiberServing ?? nutriments.fiber100g, unit: "g")
        // Sodium is in g per 100g, convert to mg
        let sodiumMg = (nutriments.sodiumServing ?? nutriments.sodium100g ?? 0) * 1000
        let sodium = formatValue(sodiumMg, unit: "mg")
        
        return NutritionInfo(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            sugar: sugar,
            fiber: fiber,
            sodium: sodium
        )
    }
    
    private func formatValue(_ value: Double?, unit: String) -> String {
        guard let value = value, value > 0 else {
            return "0\(unit)"
        }
        
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))\(unit)"
        } else {
            return String(format: "%.1f\(unit)", value)
        }
    }
    
    // MARK: - Score Calculation
    
    // Food category enum matching AI Vision ranges
    private enum FoodCategory {
        case wholeFoods          // 70-95
        case minimallyProcessed  // 60-75
        case processed          // 40-60
        case dessertsSweets     // 30-50
        case fastFoodHighlyProcessed // 20-40
        
        var range: (min: Int, max: Int, midpoint: Int) {
            switch self {
            case .wholeFoods:
                return (70, 95, 82)
            case .minimallyProcessed:
                return (60, 75, 67)
            case .processed:
                return (40, 60, 50)
            case .dessertsSweets:
                return (30, 50, 40)
            case .fastFoodHighlyProcessed:
                return (20, 40, 30)
            }
        }
    }
    
    // Determine food category from NOVA group, product name, and ingredients
    private func determineFoodCategory(novaGroup: Int?, productName: String, categories: String, ingredients: String?) -> FoodCategory {
        let nameLower = productName.lowercased()
        let categoriesLower = categories.lowercased()
        let ingredientsLower = ingredients?.lowercased() ?? ""
        
        // Check for dessert/sweet indicators
        let dessertKeywords = ["cake", "cookie", "pie", "dessert", "candy", "chocolate", "sweet", "sugar", "frosting", "icing", "brownie", "muffin", "donut", "pastry", "tart", "pudding", "custard"]
        let isDessert = dessertKeywords.contains { nameLower.contains($0) || categoriesLower.contains($0) }
        
        if isDessert {
            return .dessertsSweets
        }
        
        // Check for fast food/highly processed indicators
        let fastFoodKeywords = ["fast food", "frozen dinner", "microwave", "instant", "ready meal", "snack", "chips", "crackers", "soda", "soft drink", "energy drink"]
        let isFastFood = fastFoodKeywords.contains { nameLower.contains($0) || categoriesLower.contains($0) }
        
        // Use NOVA group as primary indicator
        if let nova = novaGroup {
            switch nova {
            case 4: // Ultra-processed
                return isFastFood ? .fastFoodHighlyProcessed : .processed
            case 3: // Processed
                return .processed
            case 2: // Processed culinary ingredients
                return .minimallyProcessed
            case 1: // Unprocessed or minimally processed
                return .wholeFoods
            default:
                break
            }
        }
        
        // Fallback: Check ingredients for processing indicators
        if ingredientsLower.contains("preservative") || 
           ingredientsLower.contains("artificial") ||
           ingredientsLower.contains("hydrogenated") ||
           ingredientsLower.contains("high fructose") {
            return .processed
        }
        
        // Default to processed if we can't determine (conservative approach)
        return .processed
    }
    
    private func calculateScore(from nutriments: Nutriments?, ingredients: String?, novaGroup: Int?, productName: String, categories: String) -> Int {
        guard let nutriments = nutriments else {
            return 50 // Default score if no nutrition data
        }
        
        // Check if we have meaningful nutrition values (per 100g OR per serving)
        let hasCalories = (nutriments.energyKcal100g ?? 0) > 0 || (nutriments.energyKcalServing ?? 0) > 0
        let hasMacros = (nutriments.proteins100g ?? 0) > 0 || 
                        (nutriments.carbohydrates100g ?? 0) > 0 || 
                        (nutriments.fat100g ?? 0) > 0 ||
                        (nutriments.proteinsServing ?? 0) > 0 ||
                        (nutriments.carbohydratesServing ?? 0) > 0 ||
                        (nutriments.fatServing ?? 0) > 0
        
        // If no meaningful nutrition data, return default score
        guard hasCalories || hasMacros else {
            print("🌐 OpenFoodFactsService: No meaningful nutrition data, returning default score")
            return 50
        }
        
        // Determine food category (matches AI Vision ranges)
        let category = determineFoodCategory(novaGroup: novaGroup, productName: productName, categories: categories, ingredients: ingredients)
        let categoryRange = category.range
        
        // Start at category midpoint, then apply adjustments
        var score = categoryRange.midpoint
        
        // Get per 100g values (standardized)
        let sugar = nutriments.sugars100g ?? 0
        let saturatedFat = nutriments.saturatedFat100g ?? 0
        let sodium = nutriments.sodium100g ?? 0
        let fiber = nutriments.fiber100g ?? 0
        
        // Penalize high sugar (per 100g) - scaled to category range
        if sugar > 10 {
            let penalty = min(15, Int((sugar - 10) * 1.5))
            score -= penalty
        }
        
        // Penalize high saturated fat (per 100g)
        if saturatedFat > 5 {
            let penalty = min(10, Int((saturatedFat - 5) * 1.5))
            score -= penalty
        }
        
        // Penalize high sodium (per 100g, convert to mg: sodium * 1000)
        let sodiumMg = sodium * 1000
        if sodiumMg > 600 {
            let penalty = min(10, Int((sodiumMg - 600) / 60))
            score -= penalty
        }
        
        // Reward fiber (per 100g) - but cap bonus to stay within category range
        if fiber > 3 {
            let bonus = min(8, Int((fiber - 3) * 1.5))
            score += bonus
        }
        
        // Penalize processed ingredients from ingredients list
        if let ingredientsText = ingredients {
            let processedCount = countProcessedIngredients(in: ingredientsText)
            score -= min(10, processedCount * 2)
        }
        
        // Clamp score to category range (critical for consistency with AI Vision)
        return max(categoryRange.min, min(categoryRange.max, score))
    }
    
    private func calculateHealthScores(from nutriments: Nutriments?, ingredients: String?, overallScore: Int, novaGroup: Int?) -> HealthScores {
        guard let nutriments = nutriments else {
            // Default scores based on overall score
            return HealthScores(
                allergies: overallScore,
                antiInflammation: overallScore,
                bloodSugar: overallScore,
                brainHealth: overallScore,
                detoxLiver: overallScore,
                energy: overallScore,
                eyeHealth: overallScore,
                heartHealth: overallScore,
                immune: overallScore,
                jointHealth: overallScore,
                kidneys: overallScore,
                mood: overallScore,
                skin: overallScore,
                sleep: overallScore,
                stress: overallScore,
                weightManagement: overallScore
            )
        }
        
        let sugar = nutriments.sugars100g ?? 0
        let saturatedFat = nutriments.saturatedFat100g ?? 0
        let sodium = nutriments.sodium100g ?? 0
        let fiber = nutriments.fiber100g ?? 0
        let protein = nutriments.proteins100g ?? 0
        
        // Start with base scores from positive nutrients
        var heartHealth = 70 + min(20, Int(fiber * 2)) + min(10, Int(protein / 2))
        var bloodSugar = 70 + min(25, Int(fiber * 3))
        var weightManagement = 70 + min(20, Int(fiber * 2)) + min(10, Int(protein / 2))
        var antiInflammation = 70 + min(15, Int(fiber * 1.5))
        var brainHealth = 70 + min(15, Int(protein / 2))
        var energy = 70 + min(15, Int(protein / 2))
        var immune = 70 + min(10, Int(protein / 3))
        var skin = 70 + min(10, Int(protein / 3))
        
        // Apply penalties based on negative factors
        // Added sugars
        if sugar > 10 {
            heartHealth -= min(20, Int((sugar - 10) * 1.5))
            bloodSugar -= min(25, Int((sugar - 10) * 2))
            weightManagement -= min(20, Int((sugar - 10) * 1.5))
        }
        
        // Refined flour (detected from ingredients)
        if let ingredientsText = ingredients, ingredientsText.lowercased().contains("flour") && !ingredientsText.lowercased().contains("whole") {
            heartHealth -= 12
            bloodSugar -= 15
            energy -= 10
        }
        
        // Unhealthy fats
        if saturatedFat > 5 {
            heartHealth -= min(12, Int((saturatedFat - 5) * 2))
            antiInflammation -= min(15, Int((saturatedFat - 5) * 2))
        }
        
        // High sodium
        let sodiumMg = sodium * 1000
        if sodiumMg > 600 {
            heartHealth -= min(10, Int((sodiumMg - 600) / 60))
            bloodSugar -= min(8, Int((sodiumMg - 600) / 75))
        }
        
        // Processed ingredients
        if let ingredientsText = ingredients {
            let processedCount = countProcessedIngredients(in: ingredientsText)
            immune -= min(10, processedCount * 2)
            skin -= min(10, processedCount * 2)
        }
        
        // NOVA group penalties
        if let nova = novaGroup {
            switch nova {
            case 4:
                heartHealth -= 15
                bloodSugar -= 15
                antiInflammation -= 15
                immune -= 10
            case 3:
                heartHealth -= 8
                bloodSugar -= 8
                antiInflammation -= 8
            case 2:
                heartHealth -= 4
                bloodSugar -= 4
            default:
                break
            }
        }
        
        // Normalize scores to be consistent with overall score
        let baseScore = overallScore
        let targetMin = max(0, baseScore - 15)
        let targetMax = min(100, baseScore + 15)
        
        // Clamp all scores to reasonable ranges
        heartHealth = max(targetMin, min(targetMax, heartHealth))
        bloodSugar = max(targetMin, min(targetMax, bloodSugar))
        weightManagement = max(targetMin, min(targetMax, weightManagement))
        antiInflammation = max(targetMin, min(targetMax, antiInflammation))
        brainHealth = max(targetMin, min(targetMax, brainHealth))
        energy = max(targetMin, min(targetMax, energy))
        immune = max(targetMin, min(targetMax, immune))
        skin = max(targetMin, min(targetMax, skin))
        
        // Other scores follow overall score more closely
        let otherScores = max(targetMin, min(targetMax, baseScore))
        
        return HealthScores(
            allergies: otherScores,
            antiInflammation: antiInflammation,
            bloodSugar: bloodSugar,
            brainHealth: brainHealth,
            detoxLiver: otherScores,
            energy: energy,
            eyeHealth: otherScores,
            heartHealth: heartHealth,
            immune: immune,
            jointHealth: otherScores,
            kidneys: otherScores,
            mood: otherScores,
            skin: skin,
            sleep: otherScores,
            stress: otherScores,
            weightManagement: weightManagement
        )
    }
    
    private func countProcessedIngredients(in ingredientsText: String) -> Int {
        let processedKeywords = [
            "preservative", "artificial", "flavor", "color", "sweetener",
            "high fructose", "corn syrup", "hydrogenated", "partially hydrogenated",
            "sodium benzoate", "potassium sorbate", "bht", "bha", "msg",
            "monosodium glutamate", "nitrate", "nitrite", "sulfite"
        ]
        
        let lowercased = ingredientsText.lowercased()
        var count = 0
        
        for keyword in processedKeywords {
            if lowercased.contains(keyword) {
                count += 1
            }
        }
        
        return count
    }
    
    // MARK: - Summary Generation
    
    private func generateSummary(from product: OpenFoodFactsProduct, nutritionInfo: NutritionInfo, score: Int) -> String {
        let productName = product.productName ?? "This product"
        var facts: [String] = []
        
        // Add key nutrition facts
        if let calories = Double(nutritionInfo.calories.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) {
            facts.append("\(Int(calories)) calories")
        }
        
        if let sugar = Double(nutritionInfo.sugar.replacingOccurrences(of: "g", with: "").trimmingCharacters(in: .whitespacesAndNewlines)), sugar > 0 {
            facts.append("\(Int(sugar))g sugar")
        }
        
        if let fiber = Double(nutritionInfo.fiber.replacingOccurrences(of: "g", with: "").trimmingCharacters(in: .whitespacesAndNewlines)), fiber > 0 {
            facts.append("\(Int(fiber))g fiber")
        }
        
        // Add NOVA score context
        if let nova = product.novaGroup {
            switch nova {
            case 4:
                facts.append("ultra-processed")
            case 3:
                facts.append("processed")
            case 1, 2:
                facts.append("minimally processed")
            default:
                break
            }
        }
        
        // Build summary
        let factString = facts.prefix(2).joined(separator: ", ")
        let scoreDescription = score >= 70 ? "excellent" : score >= 50 ? "good" : "fair"
        
        return "\(productName) scores \(score)/100 (\(scoreDescription)) with \(factString) per serving."
    }
    
    // MARK: - Ingredient Parsing
    
    private func parseIngredients(from ingredientsText: String?) -> [FoodIngredient] {
        guard let ingredientsText = ingredientsText, !ingredientsText.isEmpty else {
            return []
        }
        
        // Split by common separators (comma, semicolon, etc.)
        let components = ingredientsText
            .replacingOccurrences(of: ",", with: "|")
            .replacingOccurrences(of: ";", with: "|")
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return components.map { component in
            FoodIngredient(
                name: component,
                impact: "", // Will be populated by AI analysis if needed
                explanation: "" // Will be populated by AI analysis if needed
            )
        }
    }
}

// MARK: - OpenFoodFacts Data Models

struct OpenFoodFactsResponse: Codable {
    let status: Int
    let code: String?
    let statusVerbose: String?
    let product: OpenFoodFactsProduct?
    
    enum CodingKeys: String, CodingKey {
        case status
        case code
        case statusVerbose = "status_verbose"
        case product
    }
}

struct OpenFoodFactsProduct: Codable {
    let productName: String?
    let productNameEn: String?
    let productNameEnImported: String?
    let brands: String?
    let barcode: String?
    let nutriments: Nutriments?
    let ingredientsText: String?
    let allergens: String?
    let additivesTags: [String]?
    let nutriscoreGrade: String?
    let novaGroup: Int?
    let ecoscoreGrade: String?
    let categories: String?
    let images: ProductImages?
    let dataQualityTags: [String]?
    let completeness: Double?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case productNameEnImported = "product_name_en_imported"
        case brands
        case barcode
        case nutriments
        case ingredientsText = "ingredients_text"
        case allergens
        case additivesTags = "additives_tags"
        case nutriscoreGrade = "nutriscore_grade"
        case novaGroup = "nova_group"
        case ecoscoreGrade = "ecoscore_grade"
        case categories
        case images
        case dataQualityTags = "data_quality_tags"
        case completeness
    }
}

struct Nutriments: Codable {
    // Per 100g values (primary)
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let fat100g: Double?
    let saturatedFat100g: Double?
    let fiber100g: Double?
    let sodium100g: Double?
    
    // Per serving values (if available)
    let energyKcalServing: Double?
    let proteinsServing: Double?
    let carbohydratesServing: Double?
    let sugarsServing: Double?
    let fatServing: Double?
    let saturatedFatServing: Double?
    let fiberServing: Double?
    let sodiumServing: Double?
    
    // Serving size
    let servingSize: String?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case fiber100g = "fiber_100g"
        case sodium100g = "sodium_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteinsServing = "proteins_serving"
        case carbohydratesServing = "carbohydrates_serving"
        case sugarsServing = "sugars_serving"
        case fatServing = "fat_serving"
        case saturatedFatServing = "saturated-fat_serving"
        case fiberServing = "fiber_serving"
        case sodiumServing = "sodium_serving"
        case servingSize = "serving_size"
    }
}

struct ProductImages: Codable {
    let front: ImageData?
    let nutrition: ImageData?
    let ingredients: ImageData?
}

struct ImageData: Codable {
    let display: [String: String]?
    let small: [String: String]?
    let thumb: [String: String]?
}

// MARK: - OpenFoodFacts Errors

enum OpenFoodFactsError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(DecodingError)
    case networkError(Error)
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenFoodFacts API"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .productNotFound:
            return "Product not found in OpenFoodFacts database"
        }
    }
}

