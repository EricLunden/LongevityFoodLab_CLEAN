import Foundation

// MARK: - Imported Recipe Model
struct ImportedRecipe: Codable, Identifiable {
    let id: UUID
    let title: String
    let sourceUrl: String
    let ingredients: [String]
    let instructions: String
    let servings: Int
    let prepTimeMinutes: Int
    let imageUrl: String?
    
    // Raw Spoonacular data for better conversion
    let rawIngredients: [String]
    let rawInstructions: String
    
    // Extracted nutrition from recipe page
    let extractedNutrition: NutritionInfo?
    let nutritionSource: String?  // "extracted" or nil
    
    // AI enhancement flag (from metadata.ai_enhanced)
    let aiEnhanced: Bool
    
    init(title: String, sourceUrl: String, ingredients: [String], instructions: String, servings: Int, prepTimeMinutes: Int, imageUrl: String? = nil, rawIngredients: [String] = [], rawInstructions: String = "", extractedNutrition: NutritionInfo? = nil, nutritionSource: String? = nil, aiEnhanced: Bool = false) {
        self.id = UUID()
        self.title = title
        self.sourceUrl = sourceUrl
        self.ingredients = ingredients
        self.instructions = instructions
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.imageUrl = imageUrl
        self.rawIngredients = rawIngredients
        self.rawInstructions = rawInstructions
        self.extractedNutrition = extractedNutrition
        self.nutritionSource = nutritionSource
        self.aiEnhanced = aiEnhanced
    }
    
    // Custom decoding to handle Lambda's metadata.ai_enhanced flag
    enum CodingKeys: String, CodingKey {
        case id, title, sourceUrl, ingredients, instructions, servings, prepTimeMinutes, imageUrl, rawIngredients, rawInstructions, extractedNutrition, nutritionSource, metadata
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        title = try container.decode(String.self, forKey: .title)
        sourceUrl = try container.decode(String.self, forKey: .sourceUrl)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        instructions = try container.decode(String.self, forKey: .instructions)
        servings = try container.decode(Int.self, forKey: .servings)
        prepTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .prepTimeMinutes) ?? 0
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        rawIngredients = try container.decodeIfPresent([String].self, forKey: .rawIngredients) ?? []
        rawInstructions = try container.decodeIfPresent(String.self, forKey: .rawInstructions) ?? ""
        extractedNutrition = try container.decodeIfPresent(NutritionInfo.self, forKey: .extractedNutrition)
        nutritionSource = try container.decodeIfPresent(String.self, forKey: .nutritionSource)
        
        // Parse metadata.ai_enhanced flag
        var aiEnhancedFlag = false
        if let metadataContainer = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .metadata) {
            if let aiEnhancedKey = DynamicCodingKey(stringValue: "ai_enhanced"),
               let enhanced = try? metadataContainer.decode(Bool.self, forKey: aiEnhancedKey) {
                aiEnhancedFlag = enhanced
            }
        }
        aiEnhanced = aiEnhancedFlag
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(sourceUrl, forKey: .sourceUrl)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(instructions, forKey: .instructions)
        try container.encode(servings, forKey: .servings)
        try container.encode(prepTimeMinutes, forKey: .prepTimeMinutes)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(rawIngredients, forKey: .rawIngredients)
        try container.encode(rawInstructions, forKey: .rawInstructions)
        try container.encodeIfPresent(extractedNutrition, forKey: .extractedNutrition)
        try container.encodeIfPresent(nutritionSource, forKey: .nutritionSource)
        // Note: aiEnhanced is not encoded as it's derived from metadata
    }
}

// Helper for dynamic coding keys
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
