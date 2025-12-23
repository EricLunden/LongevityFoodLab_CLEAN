import Foundation

// Helper for dynamic keys in nested containers
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

// ImportedRecipe model for Share Extension - matches main app's model
struct ImportedRecipe: Codable, Identifiable {
    let id: UUID
    let title: String
    let sourceUrl: String
    let ingredients: [String]
    let instructions: String // This is a single String in the main app
    let servings: Int
    let prepTimeMinutes: Int
    let cookTimeMinutes: Int?  // Optional - may not be available
    let totalTimeMinutes: Int?  // Optional - may not be available
    let difficulty: String?  // Optional - "Easy", "Medium", "Hard", "Expert"
    let yieldDescription: String?  // Optional - "Makes 12 cookies", "2 deep dish pizzas"
    let imageUrl: String?
    
    // Raw Spoonacular data for better conversion
    let rawIngredients: [String]
    let rawInstructions: String
    
    // Extracted nutrition from recipe page
    let extractedNutrition: NutritionInfo?
    let nutritionSource: String?  // "extracted" or nil
    
    // AI enhancement flag (from metadata.ai_enhanced)
    let aiEnhanced: Bool
    
    // Creator/author info (for YouTube and TikTok)
    let author: String?
    let authorUrl: String?
    
    init(title: String, sourceUrl: String, ingredients: [String], instructions: String, servings: Int, prepTimeMinutes: Int, cookTimeMinutes: Int? = nil, totalTimeMinutes: Int? = nil, difficulty: String? = nil, yieldDescription: String? = nil, imageUrl: String? = nil, rawIngredients: [String] = [], rawInstructions: String = "", extractedNutrition: NutritionInfo? = nil, nutritionSource: String? = nil, aiEnhanced: Bool = false, author: String? = nil, authorUrl: String? = nil) {
        self.id = UUID()
        self.title = title
        self.sourceUrl = sourceUrl
        self.ingredients = ingredients
        self.instructions = instructions
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.totalTimeMinutes = totalTimeMinutes
        self.difficulty = difficulty
        self.yieldDescription = yieldDescription
        self.imageUrl = imageUrl
        self.rawIngredients = rawIngredients
        self.rawInstructions = rawInstructions
        self.extractedNutrition = extractedNutrition
        self.nutritionSource = nutritionSource
        self.aiEnhanced = aiEnhanced
        self.author = author
        self.authorUrl = authorUrl
    }
    
    // Custom decoding to handle Lambda's nutrition dictionary format
    enum CodingKeys: String, CodingKey {
        case id, title
        case sourceUrl = "source_url"
        case siteLink = "site_link"
        case ingredients, instructions, servings
        case prepTimeMinutes = "prep_time_minutes"
        case prepTime = "prep_time"
        case cookTimeMinutes = "cook_time_minutes"
        case cookTime = "cook_time"
        case totalTimeMinutes = "total_time_minutes"
        case totalTime = "total_time"
        case difficulty
        case yieldDescription = "yield_description"
        case yields
        case imageUrl = "image_url"
        case image
        case rawIngredients, rawInstructions
        case extractedNutrition, nutritionSource
        case nutrition // Lambda field name
        case nutritionSourceLambda = "nutrition_source" // Lambda field name
        case metadata // Lambda metadata field
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = UUID()
        title = try container.decode(String.self, forKey: .title)
        sourceUrl = (try? container.decode(String.self, forKey: .sourceUrl)) ?? (try? container.decode(String.self, forKey: .siteLink)) ?? ""
        ingredients = try container.decode([String].self, forKey: .ingredients)
        
        // Handle instructions as String or [String]
        if let instructionsStr = try? container.decode(String.self, forKey: .instructions) {
            instructions = instructionsStr
        } else if let instructionsArr = try? container.decode([String].self, forKey: .instructions) {
            instructions = instructionsArr.joined(separator: "\n\n")
        } else {
            instructions = ""
        }
        
        servings = (try? container.decode(Int.self, forKey: .servings)) ?? 1
        if let prepTime = try? container.decode(Int.self, forKey: .prepTimeMinutes) {
            prepTimeMinutes = prepTime
        } else if let prepTime = try? container.decodeIfPresent(Int.self, forKey: .prepTime) {
            prepTimeMinutes = prepTime ?? 0
        } else {
            prepTimeMinutes = 0
        }
        
        // Parse cook time
        if let cookTime = try? container.decode(Int.self, forKey: .cookTimeMinutes) {
            cookTimeMinutes = cookTime
        } else if let cookTime = try? container.decodeIfPresent(Int.self, forKey: .cookTime) {
            cookTimeMinutes = cookTime
        } else {
            cookTimeMinutes = nil
        }
        
        // Parse total time
        if let totalTime = try? container.decode(Int.self, forKey: .totalTimeMinutes) {
            totalTimeMinutes = totalTime
        } else if let totalTime = try? container.decodeIfPresent(Int.self, forKey: .totalTime) {
            totalTimeMinutes = totalTime
        } else {
            totalTimeMinutes = nil
        }
        
        // Parse difficulty
        difficulty = try? container.decodeIfPresent(String.self, forKey: .difficulty)
        
        // Parse yield description - use temporary variable since it's let
        var parsedYieldDescription: String? = try? container.decodeIfPresent(String.self, forKey: .yieldDescription)
        if parsedYieldDescription == nil {
            // Try yields field as fallback
            if let yieldsStr = try? container.decodeIfPresent(String.self, forKey: .yields),
               !yieldsStr.isEmpty,
               yieldsStr.lowercased().contains("makes") || yieldsStr.lowercased().contains("cookies") || yieldsStr.lowercased().contains("pizzas") {
                parsedYieldDescription = yieldsStr
            }
        }
        yieldDescription = parsedYieldDescription
        
        imageUrl = (try? container.decodeIfPresent(String.self, forKey: .imageUrl)) ?? (try? container.decodeIfPresent(String.self, forKey: .image))
        rawIngredients = (try? container.decode([String].self, forKey: .rawIngredients)) ?? []
        rawInstructions = (try? container.decode(String.self, forKey: .rawInstructions)) ?? ""
        
        // Parse metadata.ai_enhanced flag
        var aiEnhancedFlag = false
        if let metadataContainer = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .metadata) {
            if let aiEnhancedKey = DynamicCodingKey(stringValue: "ai_enhanced"),
               let enhanced = try? metadataContainer.decode(Bool.self, forKey: aiEnhancedKey) {
                aiEnhancedFlag = enhanced
            }
        }
        aiEnhanced = aiEnhancedFlag
        
        // Initialize author fields (not decoded from JSON)
        author = nil
        authorUrl = nil
        
        // Parse nutrition from Lambda's dictionary format
        // Lambda returns nutrition as a nested dictionary, need to decode manually
        var nutritionDict: [String: Any]? = nil
        if let nutritionData = try? container.decodeIfPresent(Data.self, forKey: .nutrition) {
            nutritionDict = try? JSONSerialization.jsonObject(with: nutritionData) as? [String: Any]
        } else if container.contains(.nutrition) {
            // Try decoding as nested container
            let nutritionContainer = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .nutrition)
            if let nc = nutritionContainer {
                nutritionDict = [:]
                for key in nc.allKeys {
                    if let str = try? nc.decode(String.self, forKey: key) {
                        nutritionDict?[key.stringValue] = str
                    } else if let int = try? nc.decode(Int.self, forKey: key) {
                        nutritionDict?[key.stringValue] = int
                    }
                }
            }
        }
        
        if let nutritionDict = nutritionDict,
           let caloriesStr = nutritionDict["calories"] as? String, !caloriesStr.isEmpty {
            
            func formatNutritionValue(_ value: Any?, unit: String, isInteger: Bool = false) -> String {
                guard let val = value else { return isInteger ? "0" : "0\(unit)" }
                let str = String(describing: val)
                guard !str.isEmpty, let num = Double(str) else {
                    return isInteger ? "0" : "0\(unit)"
                }
                if isInteger {
                    return "\(Int(num))\(unit)"
                }
                return String(format: "%.1f\(unit)", num)
            }
            
            extractedNutrition = NutritionInfo(
                calories: caloriesStr,
                protein: formatNutritionValue(nutritionDict["protein"], unit: "g"),
                carbohydrates: formatNutritionValue(nutritionDict["carbohydrates"], unit: "g"),
                fat: formatNutritionValue(nutritionDict["fat"], unit: "g"),
                sugar: formatNutritionValue(nutritionDict["sugar"], unit: "g"),
                fiber: formatNutritionValue(nutritionDict["fiber"], unit: "g"),
                sodium: formatNutritionValue(nutritionDict["sodium"], unit: "mg", isInteger: true),
                vitaminD: nil,
                vitaminE: formatNutritionValue(nutritionDict["vitamin_e"], unit: "mg"),
                potassium: formatNutritionValue(nutritionDict["potassium"], unit: "mg", isInteger: true),
                vitaminK: formatNutritionValue(nutritionDict["vitamin_k"], unit: "mcg"),
                magnesium: formatNutritionValue(nutritionDict["magnesium"], unit: "mg", isInteger: true),
                vitaminA: formatNutritionValue(nutritionDict["vitamin_a"], unit: "mcg"),
                calcium: formatNutritionValue(nutritionDict["calcium"], unit: "mg", isInteger: true),
                vitaminC: formatNutritionValue(nutritionDict["vitamin_c"], unit: "mg", isInteger: true),
                choline: nil,
                iron: formatNutritionValue(nutritionDict["iron"], unit: "mg"),
                iodine: nil,
                zinc: nil,
                folate: nil,
                vitaminB12: nil,
                vitaminB6: nil,
                selenium: nil,
                copper: nil,
                manganese: nil,
                thiamin: nil
            )
            nutritionSource = (try? container.decodeIfPresent(String.self, forKey: .nutritionSourceLambda)) ?? "extracted"
            print("✅ ImportedRecipe: Decoded nutrition from Lambda - \(caloriesStr) calories")
        } else {
            extractedNutrition = nil
            nutritionSource = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(sourceUrl, forKey: .sourceUrl)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(servings, forKey: .servings)
        try container.encode(prepTimeMinutes, forKey: .prepTimeMinutes)
        try container.encodeIfPresent(cookTimeMinutes, forKey: .cookTimeMinutes)
        try container.encodeIfPresent(totalTimeMinutes, forKey: .totalTimeMinutes)
        try container.encodeIfPresent(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(yieldDescription, forKey: .yieldDescription)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(rawIngredients, forKey: .rawIngredients)
        try container.encode(rawInstructions, forKey: .rawInstructions)
        try container.encodeIfPresent(extractedNutrition, forKey: .extractedNutrition)
        try container.encodeIfPresent(nutritionSource, forKey: .nutritionSource)
        // Note: aiEnhanced is not encoded as it's derived from metadata
        // Note: author and authorUrl are not encoded (not part of CodingKeys)
    }
}
