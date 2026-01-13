import Foundation

// MARK: - Recipe Model
struct Recipe: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var photos: [String] // Array of photo filenames
    var image: String? // Single image URL for imported recipes
    var rating: Double
    var prepTime: Int // in minutes
    var cookTime: Int // in minutes
    var servings: Int
    var categories: [RecipeCategory]
    var customCategories: [String] // User-defined custom categories (multiple allowed)
    var description: String
    var ingredients: [RecipeIngredientGroup]
    var directions: [RecipeDirection]
    var sourceURL: String?
    
    // Simple text fields for imported recipes
    var ingredientsText: String?
    var instructionsText: String?
    
    var longevityScore: Int?
    var estimatedLongevityScore: Int? // Fast-pass LFI score (for Spoonacular recipes, low confidence)
    var analysisReport: String?
    var fullAnalysisData: String? // JSON-encoded complete FoodAnalysis object
    
    /// Silent meal type classification hints for Meal Planner convenience
    /// This is a heuristic classification, not authoritative
    /// Used only for planning convenience - does not affect recipe ownership or editing
    /// Recipes may qualify for multiple meal types
    /// Classification is internal only - not exposed to users, not user-editable
    var mealTypeHints: [MealType]? = nil
    
    // MARK: - Spoonacular Deduplication
    /// Spoonacular recipe ID for source-based deduplication
    /// Only set for recipes imported from Spoonacular API
    /// Used to prevent duplicate saves of the same Spoonacular recipe
    var spoonacularID: Int? = nil
    var improvementSuggestions: [String]
    var dateAdded: Date
    var lastModified: Date
    var isFavorite: Bool
    var recipeFingerprint: String // MD5 hash of ingredients
    var analysisType: AnalysisType
    var isOriginal: Bool
    var improvedVersionID: UUID?
    var scaleFactor: Double = 1.0 // Scale factor for ingredient scaling
    var unitSystem: UnitSystem = .us // Unit system preference (US or Metric)
    
    // Extracted nutrition from recipe page
    var extractedNutrition: NutritionInfo?
    var nutritionSource: String?  // e.g., "page", "calculated", "none", or legacy "extracted"
    
    // Provenance metadata (optional)
    var servingsSource: String?      // e.g., "parsed" | "fallback"
    var ingredientSource: String?    // e.g., "list" | "instructions" | "merged" | "none"
    var imageSource: String?         // e.g., "page" | "og" | "none"
    
    // AI enhancement flag (instructions were AI-generated)
    var aiEnhanced: Bool = false
    
    // Recipe difficulty level (optional)
    var difficulty: String?  // Optional - "Easy", "Medium", "Hard", "Expert"
    
    init(
        id: UUID = UUID(),
        title: String,
        photos: [String] = [],
        image: String? = nil,
        rating: Double = 0.0,
        prepTime: Int = 0,
        cookTime: Int = 0,
        servings: Int = 1,
        categories: [RecipeCategory] = [],
        customCategories: [String] = [],
        description: String = "",
        ingredients: [RecipeIngredientGroup] = [],
        directions: [RecipeDirection] = [],
        sourceURL: String? = nil,
        ingredientsText: String? = nil,
        instructionsText: String? = nil,
        longevityScore: Int? = nil,
        estimatedLongevityScore: Int? = nil,
        analysisReport: String? = nil,
        fullAnalysisData: String? = nil,
        mealTypeHints: [MealType]? = nil,
        spoonacularID: Int? = nil,
        improvementSuggestions: [String] = [],
        dateAdded: Date = Date(),
        lastModified: Date = Date(),
        isFavorite: Bool = false,
        recipeFingerprint: String = "",
        analysisType: AnalysisType = .cached,
        isOriginal: Bool = true,
        improvedVersionID: UUID? = nil,
        scaleFactor: Double = 1.0,
        unitSystem: UnitSystem = .us,
        extractedNutrition: NutritionInfo? = nil,
        nutritionSource: String? = nil,
        servingsSource: String? = nil,
        ingredientSource: String? = nil,
        imageSource: String? = nil,
        aiEnhanced: Bool = false,
        difficulty: String? = nil
    ) {
        self.id = id
        self.title = title
        self.photos = photos
        self.image = image
        self.rating = rating
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
        self.categories = categories
        self.customCategories = customCategories
        self.description = description
        self.ingredients = ingredients
        self.directions = directions
        self.sourceURL = sourceURL
        self.ingredientsText = ingredientsText
        self.instructionsText = instructionsText
        self.longevityScore = longevityScore
        self.estimatedLongevityScore = estimatedLongevityScore
        self.analysisReport = analysisReport
        self.mealTypeHints = mealTypeHints
        self.spoonacularID = spoonacularID
        self.fullAnalysisData = fullAnalysisData
        self.improvementSuggestions = improvementSuggestions
        self.dateAdded = dateAdded
        self.lastModified = lastModified
        self.isFavorite = isFavorite
        self.recipeFingerprint = recipeFingerprint.isEmpty ? Self.generateFingerprint(from: ingredients) : recipeFingerprint
        self.analysisType = analysisType
        self.isOriginal = isOriginal
        self.improvedVersionID = improvedVersionID
        self.scaleFactor = scaleFactor
        self.unitSystem = unitSystem
        self.extractedNutrition = extractedNutrition
        self.nutritionSource = nutritionSource
        self.servingsSource = servingsSource
        self.ingredientSource = ingredientSource
        self.imageSource = imageSource
        self.aiEnhanced = aiEnhanced
        self.difficulty = difficulty
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id, title, photos, image, rating, prepTime, cookTime, servings, categories
        case customCategory // Old key for backward compatibility (decoding only)
        case customCategories // New key for encoding/decoding
        case description, ingredients, directions, sourceURL
        case ingredientsText, instructionsText
        case longevityScore, estimatedLongevityScore, analysisReport, fullAnalysisData, improvementSuggestions
        case mealTypeHints, spoonacularID
        case dateAdded, lastModified, isFavorite, recipeFingerprint
        case analysisType, isOriginal, improvedVersionID, scaleFactor, unitSystem
        case extractedNutrition, nutritionSource, aiEnhanced, difficulty
        case servingsSource, ingredientSource, imageSource
        case nutritionSourceMeta = "nutrition_source"
        case servingsSourceMeta = "servings_source"
        case ingredientSourceMeta = "ingredient_source"
        case imageSourceMeta = "image_source"
    }
    
    // Custom decoder to handle missing scaleFactor and old customCategory in old recipes
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        photos = try container.decode([String].self, forKey: .photos)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        rating = try container.decode(Double.self, forKey: .rating)
        prepTime = try container.decode(Int.self, forKey: .prepTime)
        cookTime = try container.decode(Int.self, forKey: .cookTime)
        servings = try container.decode(Int.self, forKey: .servings)
        categories = try container.decode([RecipeCategory].self, forKey: .categories)
        // Handle backward compatibility: if old customCategory exists, convert to array
        if let oldCustom = try? container.decodeIfPresent(String.self, forKey: .customCategory), !oldCustom.isEmpty {
            customCategories = [oldCustom]
        } else {
            customCategories = try container.decodeIfPresent([String].self, forKey: .customCategories) ?? []
        }
        description = try container.decode(String.self, forKey: .description)
        ingredients = try container.decode([RecipeIngredientGroup].self, forKey: .ingredients)
        directions = try container.decode([RecipeDirection].self, forKey: .directions)
        sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        ingredientsText = try container.decodeIfPresent(String.self, forKey: .ingredientsText)
        instructionsText = try container.decodeIfPresent(String.self, forKey: .instructionsText)
        longevityScore = try container.decodeIfPresent(Int.self, forKey: .longevityScore)
        estimatedLongevityScore = try container.decodeIfPresent(Int.self, forKey: .estimatedLongevityScore)
        mealTypeHints = try container.decodeIfPresent([MealType].self, forKey: .mealTypeHints)
        spoonacularID = try container.decodeIfPresent(Int.self, forKey: .spoonacularID)
        analysisReport = try container.decodeIfPresent(String.self, forKey: .analysisReport)
        fullAnalysisData = try container.decodeIfPresent(String.self, forKey: .fullAnalysisData)
        improvementSuggestions = try container.decode([String].self, forKey: .improvementSuggestions)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        recipeFingerprint = try container.decode(String.self, forKey: .recipeFingerprint)
        analysisType = try container.decode(AnalysisType.self, forKey: .analysisType)
        isOriginal = try container.decode(Bool.self, forKey: .isOriginal)
        improvedVersionID = try container.decodeIfPresent(UUID.self, forKey: .improvedVersionID)
        
        // Handle missing scaleFactor with default value of 1.0 for backward compatibility
        scaleFactor = try container.decodeIfPresent(Double.self, forKey: .scaleFactor) ?? 1.0
        
        // Handle missing unitSystem with default value of .us for backward compatibility
        unitSystem = try container.decodeIfPresent(UnitSystem.self, forKey: .unitSystem) ?? .us
        
        // Handle extracted nutrition (optional, for backward compatibility)
        extractedNutrition = try container.decodeIfPresent(NutritionInfo.self, forKey: .extractedNutrition)
        let nutritionSourcePrimary = try container.decodeIfPresent(String.self, forKey: .nutritionSource)
        let nutritionSourceMeta = try container.decodeIfPresent(String.self, forKey: .nutritionSourceMeta)
        nutritionSource = nutritionSourcePrimary ?? nutritionSourceMeta
        let servingsSourcePrimary = try container.decodeIfPresent(String.self, forKey: .servingsSource)
        let servingsSourceMeta = try container.decodeIfPresent(String.self, forKey: .servingsSourceMeta)
        servingsSource = servingsSourcePrimary ?? servingsSourceMeta
        let ingredientSourcePrimary = try container.decodeIfPresent(String.self, forKey: .ingredientSource)
        let ingredientSourceMeta = try container.decodeIfPresent(String.self, forKey: .ingredientSourceMeta)
        ingredientSource = ingredientSourcePrimary ?? ingredientSourceMeta
        let imageSourcePrimary = try container.decodeIfPresent(String.self, forKey: .imageSource)
        let imageSourceMeta = try container.decodeIfPresent(String.self, forKey: .imageSourceMeta)
        imageSource = imageSourcePrimary ?? imageSourceMeta
        
        // Handle difficulty (optional, for backward compatibility)
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty)
    }
    
    // Custom encoder to only encode customCategories (not the old customCategory key)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(photos, forKey: .photos)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encode(rating, forKey: .rating)
        try container.encode(prepTime, forKey: .prepTime)
        try container.encode(cookTime, forKey: .cookTime)
        try container.encode(servings, forKey: .servings)
        try container.encode(categories, forKey: .categories)
        try container.encode(customCategories, forKey: .customCategories)
        try container.encode(description, forKey: .description)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(directions, forKey: .directions)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encodeIfPresent(ingredientsText, forKey: .ingredientsText)
        try container.encodeIfPresent(instructionsText, forKey: .instructionsText)
        try container.encodeIfPresent(longevityScore, forKey: .longevityScore)
        try container.encodeIfPresent(analysisReport, forKey: .analysisReport)
        try container.encodeIfPresent(fullAnalysisData, forKey: .fullAnalysisData)
        try container.encode(improvementSuggestions, forKey: .improvementSuggestions)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(recipeFingerprint, forKey: .recipeFingerprint)
        try container.encode(analysisType, forKey: .analysisType)
        try container.encode(isOriginal, forKey: .isOriginal)
        try container.encodeIfPresent(improvedVersionID, forKey: .improvedVersionID)
        try container.encode(scaleFactor, forKey: .scaleFactor)
        try container.encode(unitSystem, forKey: .unitSystem)
        try container.encodeIfPresent(extractedNutrition, forKey: .extractedNutrition)
        try container.encodeIfPresent(nutritionSource, forKey: .nutritionSource)
        try container.encodeIfPresent(servingsSource, forKey: .servingsSource)
        try container.encodeIfPresent(ingredientSource, forKey: .ingredientSource)
        try container.encodeIfPresent(imageSource, forKey: .imageSource)
        try container.encodeIfPresent(difficulty, forKey: .difficulty)
    }
    
    // MARK: - Computed Properties
    var totalTime: Int {
        prepTime + cookTime
    }
    
    var totalTimeFormatted: String {
        let hours = totalTime / 60
        let minutes = totalTime % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var prepTimeFormatted: String {
        let hours = prepTime / 60
        let minutes = prepTime % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var cookTimeFormatted: String {
        let hours = cookTime / 60
        let minutes = cookTime % 60
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Formats recipe metadata as text: "Prep 16 min • Cook 16 min • Servings Yield: 4"
    /// Handles missing fields gracefully and uses appropriate time formatting
    func formattedMetadataString() -> String {
        var components: [String] = []
        
        // Format prep time
        if prepTime > 0 && prepTime <= 600 {
            let hours = prepTime / 60
            let minutes = prepTime % 60
            
            if hours > 0 {
                if minutes > 0 {
                    components.append("Prep \(hours) hr \(minutes) min")
                } else {
                    components.append("Prep \(hours) hr")
                }
            } else {
                components.append("Prep \(minutes) min")
            }
        }
        
        // Format cook time
        if cookTime > 0 {
            let hours = cookTime / 60
            let minutes = cookTime % 60
            
            if hours > 0 {
                if minutes > 0 {
                    components.append("Cook \(hours) hr \(minutes) min")
                } else {
                    components.append("Cook \(hours) hr")
                }
            } else {
                components.append("Cook \(minutes) min")
            }
        }
        
        // Format servings
        if servings >= 2 && servings <= 50 {
            // Calculate scaled servings if scale factor is applied
            let scaledServings = Int(round(Double(servings) * scaleFactor))
            if scaleFactor != 1.0 {
                components.append("Servings \(scaledServings) (Scaled)")
            } else {
                components.append("Servings \(servings)")
            }
        }
        
        // Format difficulty
        if let difficulty = difficulty, !difficulty.isEmpty {
            components.append("Difficulty \(difficulty)")
        }
        
        // Join components with bullet separator
        return components.joined(separator: " • ")
    }
    
    var hasAnalysis: Bool {
        longevityScore != nil && analysisReport != nil
    }
    
    var allIngredients: [RecipeIngredient] {
        ingredients.flatMap { $0.ingredients }
    }
    
    // Computed property to get all categories for display
    var allCategoriesDisplay: String {
        var allCategories: [String] = []
        
        // Add predefined categories
        allCategories.append(contentsOf: categories.map { $0.displayName })
        
        // Add custom categories
        allCategories.append(contentsOf: customCategories.filter { !$0.isEmpty })
        
        if allCategories.isEmpty {
            return "Uncategorized"
        } else {
            return allCategories.joined(separator: ", ")
        }
    }
    
    // MARK: - Static Methods
    static func generateFingerprint(from ingredients: [RecipeIngredientGroup]) -> String {
        let allIngredients = ingredients.flatMap { $0.ingredients }
        let ingredientString = allIngredients
            .map { "\($0.name.lowercased()):\($0.amount.lowercased())" }
            .sorted()
            .joined(separator: "|")
        
        return ingredientString.md5Hash
    }
}

// MARK: - Supporting Models
struct RecipeIngredientGroup: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var ingredients: [RecipeIngredient]
    
    init(name: String, ingredients: [RecipeIngredient] = []) {
        self.id = UUID()
        self.name = name
        self.ingredients = ingredients
    }
}

struct RecipeIngredient: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var amount: String
    var unit: String?
    var notes: String?
    
    init(name: String, amount: String, unit: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.unit = unit
        self.notes = notes
    }
    
    var displayText: String {
        var text = amount
        if let unit = unit, !unit.isEmpty {
            text += " \(unit)"
        }
        text += " \(name)"
        if let notes = notes, !notes.isEmpty {
            text += " (\(notes))"
        }
        return text
    }
}

struct RecipeDirection: Codable, Identifiable, Equatable {
    let id: UUID
    var stepNumber: Int
    var instruction: String
    var timeMinutes: Int?
    var temperature: String?
    var notes: String?
    
    init(stepNumber: Int, instruction: String, timeMinutes: Int? = nil, temperature: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.stepNumber = stepNumber
        self.instruction = instruction
        self.timeMinutes = timeMinutes
        self.temperature = temperature
        self.notes = notes
    }
}

enum RecipeCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    case dessert = "dessert"
    case appetizer = "appetizer"
    case side = "side"
    case beverage = "beverage"
    case smoothie = "smoothie"
    case salad = "salad"
    case soup = "soup"
    case main = "main"
    case vegetarian = "vegetarian"
    case vegan = "vegan"
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case keto = "keto"
    case paleo = "paleo"
    case mediterranean = "mediterranean"
    case asian = "asian"
    case mexican = "mexican"
    case italian = "italian"
    case american = "american"
    case quick = "quick"
    case mealPrep = "meal_prep"
    case onePot = "one_pot"
    case slowCooker = "slow_cooker"
    case instantPot = "instant_pot"
    case grill = "grill"
    case bake = "bake"
    case noCook = "no_cook"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .dessert: return "Dessert"
        case .appetizer: return "Appetizer"
        case .side: return "Side Dish"
        case .beverage: return "Beverage"
        case .smoothie: return "Smoothie"
        case .salad: return "Salad"
        case .soup: return "Soup"
        case .main: return "Main Course"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        case .keto: return "Keto"
        case .paleo: return "Paleo"
        case .mediterranean: return "Mediterranean"
        case .asian: return "Asian"
        case .mexican: return "Mexican"
        case .italian: return "Italian"
        case .american: return "American"
        case .quick: return "Quick & Easy"
        case .mealPrep: return "Meal Prep"
        case .onePot: return "One Pot"
        case .slowCooker: return "Slow Cooker"
        case .instantPot: return "Instant Pot"
        case .grill: return "Grilled"
        case .bake: return "Baked"
        case .noCook: return "No Cook"
        }
    }
    
    var emoji: String {
        switch self {
        case .breakfast: return "🥞"
        case .lunch: return "🥗"
        case .dinner: return "🍽️"
        case .snack: return "🍎"
        case .dessert: return "🍰"
        case .appetizer: return "🥨"
        case .side: return "🥕"
        case .beverage: return "🥤"
        case .smoothie: return "🥤"
        case .salad: return "🥗"
        case .soup: return "🍲"
        case .main: return "🍖"
        case .vegetarian: return "🥬"
        case .vegan: return "🌱"
        case .glutenFree: return "🌾"
        case .dairyFree: return "🥛"
        case .keto: return "🥑"
        case .paleo: return "🥩"
        case .mediterranean: return "🫒"
        case .asian: return "🍜"
        case .mexican: return "🌮"
        case .italian: return "🍝"
        case .american: return "🍔"
        case .quick: return "⚡"
        case .mealPrep: return "📦"
        case .onePot: return "🍲"
        case .slowCooker: return "⏰"
        case .instantPot: return "⚡"
        case .grill: return "🔥"
        case .bake: return "🔥"
        case .noCook: return "❄️"
        }
    }
    
    var color: String {
        switch self {
        case .breakfast: return "orange"
        case .lunch: return "green"
        case .dinner: return "blue"
        case .snack: return "yellow"
        case .dessert: return "pink"
        case .appetizer: return "purple"
        case .side: return "teal"
        case .beverage: return "cyan"
        case .smoothie: return "mint"
        case .salad: return "lime"
        case .soup: return "amber"
        case .main: return "red"
        case .vegetarian: return "green"
        case .vegan: return "emerald"
        case .glutenFree: return "yellow"
        case .dairyFree: return "blue"
        case .keto: return "purple"
        case .paleo: return "brown"
        case .mediterranean: return "blue"
        case .asian: return "red"
        case .mexican: return "orange"
        case .italian: return "green"
        case .american: return "blue"
        case .quick: return "yellow"
        case .mealPrep: return "purple"
        case .onePot: return "teal"
        case .slowCooker: return "orange"
        case .instantPot: return "red"
        case .grill: return "red"
        case .bake: return "brown"
        case .noCook: return "blue"
        }
    }
}

enum AnalysisType: String, Codable, CaseIterable {
    case full = "full"
    case composite = "composite"
    case similar = "similar"
    case cached = "cached"
    
    var displayName: String {
        switch self {
        case .full: return "Full Analysis"
        case .composite: return "Composite Analysis"
        case .similar: return "Similar Recipe Analysis"
        case .cached: return "Cached Analysis"
        }
    }
}

enum UnitSystem: String, Codable {
    case us = "us"
    case metric = "metric"
}

// MARK: - Extensions
extension String {
    var md5Hash: String {
        guard let data = self.data(using: .utf8) else { return "" }
        let hash = data.withUnsafeBytes { bytes in
            return bytes.bindMemory(to: UInt8.self)
        }
        
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(hash.baseAddress, CC_LONG(data.count), &digest)
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - Spoonacular Data Models (for imported recipes)
// Note: These are defined in SpoonacularService.swift

// MARK: - CommonCrypto Import
import CommonCrypto
