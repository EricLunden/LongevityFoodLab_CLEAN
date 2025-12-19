import Foundation

// MARK: - Spoonacular Service
class SpoonacularService: ObservableObject {
    static let shared = SpoonacularService()
    
    private let apiKey: String
    private let baseURL = "https://api.spoonacular.com/recipes"
    private let foodBaseURL = "https://api.spoonacular.com/food/ingredients"
    private let session = URLSession.shared
    
    private init() {
        // Get API key from Config or environment
        self.apiKey = Config.spoonacularAPIKey
        print("🔑 SpoonacularService: Initialized with API key: \(apiKey.prefix(8))...")
        print("🌐 SpoonacularService: Base URL: \(baseURL)")
    }
    
    // MARK: - Recipe Search
    
    /// Search for recipes with complex queries
    func searchRecipes(
        query: String,
        cuisine: String? = nil,
        diet: String? = nil,
        intolerances: String? = nil,
        type: String? = nil,
        maxReadyTime: Int? = nil,
        minCalories: Int? = nil,
        maxCalories: Int? = nil,
        number: Int = 10,
        offset: Int = 0
    ) async throws -> SpoonacularSearchResponse {
        var components = URLComponents(string: "\(baseURL)/complexSearch")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "number", value: "\(number)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "addRecipeInformation", value: "true"),
            URLQueryItem(name: "fillIngredients", value: "true"),
            URLQueryItem(name: "addRecipeNutrition", value: "true")
        ]
        
        if let cuisine = cuisine {
            queryItems.append(URLQueryItem(name: "cuisine", value: cuisine))
        }
        if let diet = diet {
            queryItems.append(URLQueryItem(name: "diet", value: diet))
        }
        if let intolerances = intolerances {
            queryItems.append(URLQueryItem(name: "intolerances", value: intolerances))
        }
        if let type = type {
            queryItems.append(URLQueryItem(name: "type", value: type))
        }
        if let maxReadyTime = maxReadyTime {
            queryItems.append(URLQueryItem(name: "maxReadyTime", value: "\(maxReadyTime)"))
        }
        if let minCalories = minCalories {
            queryItems.append(URLQueryItem(name: "minCalories", value: "\(minCalories)"))
        }
        if let maxCalories = maxCalories {
            queryItems.append(URLQueryItem(name: "maxCalories", value: "\(maxCalories)"))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw SpoonacularError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpoonacularError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SpoonacularError.httpError(httpResponse.statusCode)
        }
        
        let searchResponse = try JSONDecoder().decode(SpoonacularSearchResponse.self, from: data)
        return searchResponse
    }
    
    /// Get detailed recipe information by ID
    func getRecipeDetails(id: Int) async throws -> SpoonacularRecipe {
        let url = URL(string: "\(baseURL)/\(id)/information?apiKey=\(apiKey)&includeNutrition=true")!
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpoonacularError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SpoonacularError.httpError(httpResponse.statusCode)
        }
        
        let recipe = try JSONDecoder().decode(SpoonacularRecipe.self, from: data)
        return recipe
    }
    
    /// Get random recipes
    func getRandomRecipes(
        number: Int = 10,
        tags: String? = nil
    ) async throws -> SpoonacularRandomResponse {
        var components = URLComponents(string: "\(baseURL)/random")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "number", value: "\(number)")
        ]
        
        if let tags = tags {
            queryItems.append(URLQueryItem(name: "tags", value: tags))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw SpoonacularError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpoonacularError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SpoonacularError.httpError(httpResponse.statusCode)
        }
        
        let randomResponse = try JSONDecoder().decode(SpoonacularRandomResponse.self, from: data)
        return randomResponse
    }
    
    // MARK: - Recipe Import
    
    /// Extract recipe from URL using Spoonacular's extract endpoint
    func extractRecipe(from url: String) async throws -> ImportedRecipe {
        print("🔍 SpoonacularService: Starting recipe extraction for URL: \(url)")
        print("🔑 SpoonacularService: Using API key: \(apiKey.prefix(8))...")
        
        var components = URLComponents(string: "\(baseURL)/extract")!
        
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "url", value: url),
            URLQueryItem(name: "forceExtraction", value: "true"),
            URLQueryItem(name: "includeNutrition", value: "false"),
            URLQueryItem(name: "includeTaste", value: "false")
        ]
        
        components.queryItems = queryItems
        
        guard let requestURL = components.url else {
            print("❌ SpoonacularService: Failed to create URL from components")
            throw SpoonacularError.invalidURL
        }
        
        print("🌐 SpoonacularService: Making request to: \(requestURL)")
        
        do {
            let (data, response) = try await session.data(from: requestURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ SpoonacularService: Invalid response type")
                throw SpoonacularError.invalidResponse
            }
            
            print("📡 SpoonacularService: HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ SpoonacularService: HTTP Error \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 SpoonacularService: Response body: \(responseString)")
                }
                throw SpoonacularError.httpError(httpResponse.statusCode)
            }
            
                   print("✅ SpoonacularService: Successfully received data (\(data.count) bytes)")
                   
                   // Log raw response for debugging
                   if let responseString = String(data: data, encoding: .utf8) {
                       print("📄 SpoonacularService: Raw API response:")
                       print(responseString)
                   }
                   
                   let extractedRecipe = try JSONDecoder().decode(SpoonacularExtractedRecipe.self, from: data)
                   print("✅ SpoonacularService: Successfully decoded recipe: \(extractedRecipe.title)")
                   print("🔍 SpoonacularService: Decoded recipe details:")
                   print("   Title: \(extractedRecipe.title)")
                   print("   Servings: \(extractedRecipe.servings ?? 0)")
                   print("   Ready in minutes: \(extractedRecipe.readyInMinutes ?? 0)")
                   print("   Image: \(extractedRecipe.image ?? "none")")
                   print("   Extended ingredients count: \(extractedRecipe.extendedIngredients?.count ?? 0)")
                   print("   Instructions: \(extractedRecipe.instructions ?? "none")")
                   print("   Analyzed instructions count: \(extractedRecipe.analyzedInstructions?.count ?? 0)")
                   
                   // Debug recipe data
        print("📋 Recipe decoded:")
        print("  Title: \(extractedRecipe.title)")
        print("  Image: \(extractedRecipe.image ?? "nil")")
        if let imageUrl = extractedRecipe.image {
            print("  Image URL details:")
            print("    - Starts with http: \(imageUrl.hasPrefix("http"))")
            print("    - Starts with https: \(imageUrl.hasPrefix("https"))")
            print("    - Length: \(imageUrl.count)")
            print("    - Full URL: \(imageUrl)")
        }
        print("  Ingredients: \(extractedRecipe.extendedIngredients?.count ?? 0)")
        print("  Instructions: \(extractedRecipe.instructions != nil ? "Yes" : "No")")
        
        // Debug ingredients specifically
        print("🔴 API: \(extractedRecipe.extendedIngredients?.count ?? 0) ingredients")
        if let first = extractedRecipe.extendedIngredients?.first {
            print("🔴 First ingredient: \(first.original ?? "No original text")")
        }
                   
                   // Debug ingredients
                   print("📋 Ingredients found: \(extractedRecipe.extendedIngredients?.count ?? 0)")
                   if let ingredients = extractedRecipe.extendedIngredients {
                       for (index, ingredient) in ingredients.prefix(3).enumerated() {
                           print("  \(index + 1). \(ingredient.original ?? "No original text")")
                       }
                   }
                   print("📝 Instructions: \(extractedRecipe.instructions?.prefix(100) ?? "None")")
                   print("📝 Analyzed: \(extractedRecipe.analyzedInstructions?.first?.steps?.count ?? 0) steps")
                   
                   return convertToImportedRecipe(extractedRecipe, sourceUrl: url)
        } catch {
            print("❌ SpoonacularService: Network error: \(error)")
            throw error
        }
    }
    
    /// Convert Spoonacular extracted recipe to ImportedRecipe
    private func convertToImportedRecipe(_ extractedRecipe: SpoonacularExtractedRecipe, sourceUrl: String) -> ImportedRecipe {
        print("🔍 SpoonacularService: Converting extracted recipe:")
        print("   Title: \(extractedRecipe.title)")
        print("   Servings: \(extractedRecipe.servings ?? 0)")
        print("   Ready in minutes: \(extractedRecipe.readyInMinutes ?? 0)")
        print("   Image: \(extractedRecipe.image ?? "none")")
        print("   Extended ingredients count: \(extractedRecipe.extendedIngredients?.count ?? 0)")
        print("   Instructions: \(extractedRecipe.instructions ?? "none")")
        print("   Analyzed instructions count: \(extractedRecipe.analyzedInstructions?.count ?? 0)")
        
        // Convert ingredients
        let ingredients: [String] = extractedRecipe.extendedIngredients?.map { ingredient in
            // Try original first, then construct from parts
            let ingredientText: String
            if let original = ingredient.original, !original.isEmpty {
                ingredientText = original
            } else {
                // Construct from individual parts
                let amount = ingredient.amount?.description ?? ""
                let unit = ingredient.unit ?? ""
                let name = ingredient.name
                
                if !amount.isEmpty && !unit.isEmpty {
                    ingredientText = "\(amount) \(unit) \(name)"
                } else if !amount.isEmpty {
                    ingredientText = "\(amount) \(name)"
                } else {
                    ingredientText = name
                }
            }
            print("   Ingredient: \(ingredientText)")
            return ingredientText
        } ?? []
        
        // Convert instructions
        let instructions: String
        if let analyzedInstructions = extractedRecipe.analyzedInstructions,
           let firstInstruction = analyzedInstructions.first,
           let steps = firstInstruction.steps {
            print("   Using analyzed instructions with \(steps.count) steps")
            instructions = steps.map { "\($0.number). \($0.step)" }.joined(separator: "\n\n")
        } else if let rawInstructions = extractedRecipe.instructions {
            print("   Using raw instructions")
            instructions = rawInstructions
        } else {
            print("   No instructions found, using fallback")
            instructions = "No instructions available"
        }
        
        print("   Final instructions: \(instructions)")
        print("🔴 API: \(extractedRecipe.extendedIngredients?.count ?? 0) ingredients")
        if let first = extractedRecipe.extendedIngredients?.first {
            print("🔴 First ingredient: \(first.original ?? "No original text")")
        }
        print("🔴 Converted ingredients count: \(ingredients.count)")
        if let first = ingredients.first {
            print("🔴 First converted ingredient: \(first)")
        }
        
        return ImportedRecipe(
            title: extractedRecipe.title,
            sourceUrl: sourceUrl,
            ingredients: ingredients,
            instructions: instructions,
            servings: extractedRecipe.servings ?? 1,
            prepTimeMinutes: extractedRecipe.readyInMinutes ?? 0,
            imageUrl: extractedRecipe.image,
            rawIngredients: ingredients, // Store the processed ingredients as raw
            rawInstructions: instructions // Store the processed instructions as raw
        )
    }
    
    /// Convert Spoonacular recipe to our Recipe model
    func convertToRecipe(_ spoonacularRecipe: SpoonacularRecipe) -> Recipe {
        // Convert ingredients
        let ingredientGroups = [RecipeIngredientGroup(
            name: "Ingredients",
            ingredients: spoonacularRecipe.extendedIngredients?.map { ingredient in
                RecipeIngredient(
                    name: ingredient.name,
                    amount: ingredient.amount?.description ?? "1",
                    unit: ingredient.unit,
                    notes: ingredient.original
                )
            } ?? []
        )]
        
        // Convert instructions
        let directions = spoonacularRecipe.analyzedInstructions?.first?.steps?.map { step in
            RecipeDirection(
                stepNumber: step.number,
                instruction: step.step,
                timeMinutes: nil,
                temperature: nil,
                notes: nil
            )
        } ?? []
        
        // Determine categories based on Spoonacular data
        var categories: [RecipeCategory] = []
        
        // Add meal type categories
        if let dishTypes = spoonacularRecipe.dishTypes {
            for dishType in dishTypes {
                switch dishType.lowercased() {
                case "breakfast": categories.append(.breakfast)
                case "lunch": categories.append(.lunch)
                case "dinner": categories.append(.dinner)
                case "dessert": categories.append(.dessert)
                case "appetizer": categories.append(.appetizer)
                case "side dish": categories.append(.side)
                case "main course": categories.append(.main)
                case "salad": categories.append(.salad)
                case "soup": categories.append(.soup)
                case "beverage": categories.append(.beverage)
                case "smoothie": categories.append(.smoothie)
                default: break
                }
            }
        }
        
        // Add dietary categories
        if let diets = spoonacularRecipe.diets {
            for diet in diets {
                switch diet.lowercased() {
                case "vegetarian": categories.append(.vegetarian)
                case "vegan": categories.append(.vegan)
                case "gluten free": categories.append(.glutenFree)
                case "dairy free": categories.append(.dairyFree)
                case "ketogenic": categories.append(.keto)
                case "paleo": categories.append(.paleo)
                case "mediterranean": categories.append(.mediterranean)
                default: break
                }
            }
        }
        
        // Add cuisine categories
        if let cuisines = spoonacularRecipe.cuisines {
            for cuisine in cuisines {
                switch cuisine.lowercased() {
                case "asian": categories.append(.asian)
                case "mexican": categories.append(.mexican)
                case "italian": categories.append(.italian)
                case "american": categories.append(.american)
                default: break
                }
            }
        }
        
        // Add cooking method categories
        if let cookingMethods = spoonacularRecipe.cookingMethods {
            for method in cookingMethods {
                switch method.lowercased() {
                case "grilled": categories.append(.grill)
                case "baked": categories.append(.bake)
                case "slow cooker": categories.append(.slowCooker)
                case "instant pot": categories.append(.instantPot)
                case "one pot": categories.append(.onePot)
                default: break
                }
            }
        }
        
        // Add quick category if ready time is under 30 minutes
        if let readyInMinutes = spoonacularRecipe.readyInMinutes, readyInMinutes <= 30 {
            categories.append(.quick)
        }
        
        // Remove duplicates
        categories = Array(Set(categories))
        
        return Recipe(
            title: spoonacularRecipe.title,
            photos: spoonacularRecipe.image != nil ? [spoonacularRecipe.image!] : [],
            rating: Double(spoonacularRecipe.aggregateLikes ?? 0) / 100.0, // Convert to 0-5 scale
            prepTime: spoonacularRecipe.preparationMinutes ?? 0,
            cookTime: spoonacularRecipe.cookingMinutes ?? 0,
            servings: spoonacularRecipe.servings ?? 1,
            categories: categories,
            description: spoonacularRecipe.summary?.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) ?? "",
            ingredients: ingredientGroups,
            directions: directions,
            sourceURL: spoonacularRecipe.sourceUrl,
            longevityScore: nil, // Will be calculated by AI analysis
            analysisReport: nil,
            improvementSuggestions: [],
            isFavorite: false,
            analysisType: .cached,
            isOriginal: false
        )
    }
    
    // MARK: - Nutrition Lookup
    
    /// Search for an ingredient by name
    func searchIngredient(query: String) async throws -> SpoonacularIngredientSearchResult {
        var components = URLComponents(string: "\(foodBaseURL)/search")!
        
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "number", value: "5"), // Get top 5 matches for better results
            URLQueryItem(name: "addChildren", value: "false")
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            print("❌ SpoonacularService: Invalid URL for search")
            throw SpoonacularError.invalidURL
        }
        
        print("🌐 SpoonacularService: Searching ingredients: \(url.absoluteString.replacingOccurrences(of: apiKey, with: "***"))")
        
        // Add timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 second timeout
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ SpoonacularService: Invalid response type")
            throw SpoonacularError.invalidResponse
        }
        
        print("📡 SpoonacularService: HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ SpoonacularService: Error response: \(errorString)")
            }
            throw SpoonacularError.httpError(httpResponse.statusCode)
        }
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 SpoonacularService: Search response (first 500 chars): \(String(responseString.prefix(500)))")
        }
        
        let searchResult = try JSONDecoder().decode(SpoonacularIngredientSearchResult.self, from: data)
        print("✅ SpoonacularService: Decoded \(searchResult.results.count) results")
        return searchResult
    }
    
    /// Get nutrition information for an ingredient by ID
    func getIngredientNutrition(id: Int, amount: Double = 100, unit: String = "g") async throws -> SpoonacularIngredientNutrition {
        var components = URLComponents(string: "\(foodBaseURL)/\(id)/information")!
        
        let queryItems: [URLQueryItem] = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "amount", value: "\(amount)"),
            URLQueryItem(name: "unit", value: unit)
        ]
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            print("❌ SpoonacularService: Invalid URL for nutrition info")
            throw SpoonacularError.invalidURL
        }
        
        print("🌐 SpoonacularService: Getting nutrition for ingredient ID \(id)")
        
        // Add timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // 5 second timeout
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ SpoonacularService: Invalid response type for nutrition")
            throw SpoonacularError.invalidResponse
        }
        
        print("📡 SpoonacularService: Nutrition HTTP Status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ SpoonacularService: Nutrition error response: \(errorString)")
            }
            throw SpoonacularError.httpError(httpResponse.statusCode)
        }
        
        // Log raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 SpoonacularService: Nutrition response (first 1000 chars): \(String(responseString.prefix(1000)))")
        }
        
        do {
            let nutrition = try JSONDecoder().decode(SpoonacularIngredientNutrition.self, from: data)
            print("✅ SpoonacularService: Successfully decoded nutrition data")
            return nutrition
        } catch {
            print("❌ SpoonacularService: Failed to decode nutrition: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 SpoonacularService: Full response: \(responseString)")
            }
            throw SpoonacularError.decodingError(error)
        }
    }
    
    /// Get nutrition for a food name (searches first, then gets nutrition)
    func getNutritionForFood(_ foodName: String, amount: Double = 100, unit: String = "g") async throws -> SpoonacularIngredientNutrition? {
        print("🔍 SpoonacularService: Looking up nutrition for '\(foodName)'")
        
        // Normalize food name for better matching
        let normalizedName = normalizeFoodName(foodName)
        print("🔍 SpoonacularService: Normalized to '\(normalizedName)'")
        
        // Try original name first
        var searchResult: SpoonacularIngredientSearchResult
        do {
            searchResult = try await searchIngredient(query: foodName)
            print("✅ SpoonacularService: Search successful for '\(foodName)', found \(searchResult.results.count) results")
        } catch {
            print("⚠️ SpoonacularService: Search failed for '\(foodName)': \(error.localizedDescription)")
            // Try normalized name if original fails
            if normalizedName != foodName {
                print("🔍 SpoonacularService: Retrying with normalized name '\(normalizedName)'")
                do {
                    searchResult = try await searchIngredient(query: normalizedName)
                    print("✅ SpoonacularService: Search successful for normalized '\(normalizedName)', found \(searchResult.results.count) results")
                } catch {
                    print("❌ SpoonacularService: Search also failed for normalized name: \(error.localizedDescription)")
                    throw error
                }
            } else {
                throw error
            }
        }
        
        guard let firstResult = searchResult.results.first else {
            print("⚠️ SpoonacularService: No results found for '\(foodName)' (normalized: '\(normalizedName)')")
            return nil
        }
        
        print("✅ SpoonacularService: Found ingredient: \(firstResult.name) (ID: \(firstResult.id))")
        
        // Get nutrition for the found ingredient
        do {
            let nutrition = try await getIngredientNutrition(id: firstResult.id, amount: amount, unit: unit)
            print("✅ SpoonacularService: Retrieved nutrition data for \(firstResult.name)")
            print("📊 SpoonacularService: Nutrition has \(nutrition.nutrition.nutrients.count) nutrients")
            return nutrition
        } catch {
            print("❌ SpoonacularService: Failed to get nutrition for ID \(firstResult.id): \(error.localizedDescription)")
            throw error
        }
    }
    
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
            print("⚠️ SpoonacularService: Unknown unit '\(unit)', assuming grams")
            return amount
        }
    }
    
    /// Normalize food name for better Spoonacular matching
    private func normalizeFoodName(_ name: String) -> String {
        var normalized = name.lowercased()
        
        // Remove common cooking methods/descriptors
        let descriptors = ["grilled", "roasted", "baked", "fried", "steamed", "boiled", "raw", "cooked", "fresh", "frozen"]
        for descriptor in descriptors {
            normalized = normalized.replacingOccurrences(of: "\(descriptor) ", with: "")
            normalized = normalized.replacingOccurrences(of: " \(descriptor)", with: "")
        }
        
        // Remove plural/singular variations (basic)
        if normalized.hasSuffix("s") && normalized.count > 3 {
            normalized = String(normalized.dropLast())
        }
        
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Spoonacular Data Models

struct SpoonacularSearchResponse: Codable {
    let results: [SpoonacularRecipe]
    let totalResults: Int
    let offset: Int
    let number: Int
}

struct SpoonacularRandomResponse: Codable {
    let recipes: [SpoonacularRecipe]
}

struct SpoonacularExtractedRecipe: Codable {
    let title: String
    let sourceUrl: String?
    let servings: Int?
    let readyInMinutes: Int?
    let image: String?
    let extendedIngredients: [SpoonacularIngredient]?
    let instructions: String?
    let analyzedInstructions: [SpoonacularAnalyzedInstruction]?
}

struct SpoonacularRecipe: Codable, Identifiable {
    let id: Int
    let title: String
    let image: String?
    let imageType: String?
    let summary: String?
    let instructions: String?
    let analyzedInstructions: [SpoonacularAnalyzedInstruction]?
    let extendedIngredients: [SpoonacularIngredient]?
    let readyInMinutes: Int?
    let preparationMinutes: Int?
    let cookingMinutes: Int?
    let servings: Int?
    let aggregateLikes: Int?
    let healthScore: Int?
    let spoonacularScore: Double?
    let pricePerServing: Double?
    let sourceUrl: String?
    let spoonacularSourceUrl: String?
    let dishTypes: [String]?
    let diets: [String]?
    let cuisines: [String]?
    let cookingMethods: [String]?
    let nutrition: SpoonacularNutrition?
    let winePairing: SpoonacularWinePairing?
}

struct SpoonacularAnalyzedInstruction: Codable {
    let name: String
    let steps: [SpoonacularInstructionStep]?
}

struct SpoonacularInstructionStep: Codable {
    let number: Int
    let step: String
    let ingredients: [SpoonacularStepIngredient]?
    let equipment: [SpoonacularStepEquipment]?
    let length: SpoonacularStepLength?
}

struct SpoonacularStepIngredient: Codable {
    let id: Int
    let name: String
    let localizedName: String
    let image: String
}

struct SpoonacularStepEquipment: Codable {
    let id: Int
    let name: String
    let localizedName: String
    let image: String
}

struct SpoonacularStepLength: Codable {
    let number: Int
    let unit: String
}

struct SpoonacularIngredient: Codable {
    let id: Int
    let name: String
    let amount: Double?
    let unit: String?
    let original: String?
    let image: String?
    let meta: [String]?
    let measures: SpoonacularIngredientMeasures?
}

struct SpoonacularIngredientMeasures: Codable {
    let us: SpoonacularMeasure?
    let metric: SpoonacularMeasure?
}

struct SpoonacularMeasure: Codable {
    let amount: Double
    let unitShort: String
    let unitLong: String
}

struct SpoonacularNutrition: Codable {
    let nutrients: [SpoonacularNutrient]?
    let properties: [SpoonacularNutritionProperty]?
    let flavonoids: [SpoonacularFlavonoid]?
    let caloricBreakdown: SpoonacularCaloricBreakdown?
    let weightPerServing: SpoonacularWeightPerServing?
}

struct SpoonacularNutrient: Codable {
    let name: String
    let amount: Double
    let unit: String
    let percentOfDailyNeeds: Double?
}

struct SpoonacularNutritionProperty: Codable {
    let name: String
    let amount: Double
    let unit: String
}

struct SpoonacularFlavonoid: Codable {
    let name: String
    let amount: Double
    let unit: String
}

struct SpoonacularCaloricBreakdown: Codable {
    let percentProtein: Double?
    let percentFat: Double?
    let percentCarbs: Double?
}

struct SpoonacularWeightPerServing: Codable {
    let amount: Int
    let unit: String
}

struct SpoonacularWinePairing: Codable {
    let pairedWines: [String]?
    let pairingText: String?
    let productMatches: [SpoonacularWineProduct]?
}

struct SpoonacularWineProduct: Codable {
    let id: Int
    let title: String
    let description: String
    let price: String
    let imageUrl: String
    let averageRating: Double
    let ratingCount: Int
    let score: Double
    let link: String
}

// MARK: - Ingredient Search Models

struct SpoonacularIngredientSearchResult: Codable {
    let results: [SpoonacularIngredientSearchItem]
    let offset: Int
    let number: Int
    let totalResults: Int
}

struct SpoonacularIngredientSearchItem: Codable {
    let id: Int
    let name: String
    let image: String?
}

// MARK: - Ingredient Nutrition Models

struct SpoonacularIngredientNutrition: Codable {
    let id: Int
    let original: String
    let originalName: String
    let name: String
    let amount: Double
    let unit: String
    let nutrition: SpoonacularIngredientNutritionDetails
}

struct SpoonacularIngredientNutritionDetails: Codable {
    let nutrients: [SpoonacularIngredientNutrient]
    let properties: [SpoonacularIngredientProperty]?
    let flavonoids: [SpoonacularIngredientFlavonoid]?
    let caloricBreakdown: SpoonacularIngredientCaloricBreakdown?
    let weightPerServing: SpoonacularIngredientWeightPerServing?
}

struct SpoonacularIngredientNutrient: Codable {
    let name: String
    let amount: Double
    let unit: String
    let percentOfDailyNeeds: Double?
}

struct SpoonacularIngredientProperty: Codable {
    let name: String
    let amount: Double
    let unit: String
}

struct SpoonacularIngredientFlavonoid: Codable {
    let name: String
    let amount: Double
    let unit: String
}

struct SpoonacularIngredientCaloricBreakdown: Codable {
    let percentProtein: Double?
    let percentFat: Double?
    let percentCarbs: Double?
}

struct SpoonacularIngredientWeightPerServing: Codable {
    let amount: Int
    let unit: String
}

// MARK: - Error Types

enum SpoonacularError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noData
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
