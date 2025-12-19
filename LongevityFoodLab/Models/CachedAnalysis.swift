import Foundation

// MARK: - Cached Analysis Model
struct CachedAnalysis: Codable, Identifiable, Equatable {
    let id = UUID()
    let fingerprint: String
    let ingredients: [String: String] // ingredient name -> amount
    let longevityScore: Int
    let analysisReport: String
    let improvements: [String]
    let analyzedDate: Date
    let apiVersion: String
    
    init(
        fingerprint: String,
        ingredients: [String: String],
        longevityScore: Int,
        analysisReport: String,
        improvements: [String] = [],
        analyzedDate: Date = Date(),
        apiVersion: String = "v1.0"
    ) {
        self.fingerprint = fingerprint
        self.ingredients = ingredients
        self.longevityScore = longevityScore
        self.analysisReport = analysisReport
        self.improvements = improvements
        self.analyzedDate = analyzedDate
        self.apiVersion = apiVersion
    }
    
    // MARK: - Computed Properties
    var isExpired: Bool {
        let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: analyzedDate) ?? analyzedDate
        return Date() > expirationDate
    }
    
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: analyzedDate, to: Date()).day ?? 0
    }
    
    var ageDescription: String {
        let days = ageInDays
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "\(days) days ago"
        case 7...13: return "1 week ago"
        case 14...20: return "2 weeks ago"
        case 21...27: return "3 weeks ago"
        case 28...30: return "4 weeks ago"
        default: return "Over a month ago"
        }
    }
}

// MARK: - Recipe Analysis Result
struct RecipeAnalysisResult: Codable, Identifiable, Equatable {
    let id = UUID()
    let recipeId: UUID
    let longevityScore: Int
    let analysisReport: String
    let improvements: [String]
    let analyzedDate: Date
    let analysisType: AnalysisType
    let ingredientsAnalyzed: [String]
    let healthScores: RecipeHealthScores?
    let nutritionInfo: RecipeNutritionInfo?
    
    init(
        recipeId: UUID,
        longevityScore: Int,
        analysisReport: String,
        improvements: [String] = [],
        analyzedDate: Date = Date(),
        analysisType: AnalysisType = .full,
        ingredientsAnalyzed: [String] = [],
        healthScores: RecipeHealthScores? = nil,
        nutritionInfo: RecipeNutritionInfo? = nil
    ) {
        self.recipeId = recipeId
        self.longevityScore = longevityScore
        self.analysisReport = analysisReport
        self.improvements = improvements
        self.analyzedDate = analyzedDate
        self.analysisType = analysisType
        self.ingredientsAnalyzed = ingredientsAnalyzed
        self.healthScores = healthScores
        self.nutritionInfo = nutritionInfo
    }
}

// MARK: - Recipe Health Scores
struct RecipeHealthScores: Codable, Equatable {
    let allergies: Int
    let antiInflammation: Int
    let bloodSugar: Int
    let brainHealth: Int
    let detoxLiver: Int
    let energy: Int
    let eyeHealth: Int
    let heartHealth: Int
    let immune: Int
    let jointHealth: Int
    let kidneys: Int
    let mood: Int
    let skin: Int
    let sleep: Int
    let stress: Int
    let weightManagement: Int
    
    init(
        allergies: Int = 0,
        antiInflammation: Int = 0,
        bloodSugar: Int = 0,
        brainHealth: Int = 0,
        detoxLiver: Int = 0,
        energy: Int = 0,
        eyeHealth: Int = 0,
        heartHealth: Int = 0,
        immune: Int = 0,
        jointHealth: Int = 0,
        kidneys: Int = 0,
        mood: Int = 0,
        skin: Int = 0,
        sleep: Int = 0,
        stress: Int = 0,
        weightManagement: Int = 0
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
        allergies = try container.decodeIfPresent(Int.self, forKey: .allergies) ?? 0
        detoxLiver = try container.decodeIfPresent(Int.self, forKey: .detoxLiver) ?? (try container.decodeIfPresent(Int.self, forKey: .longevity) ?? 0) // Support both old and new field names
        kidneys = try container.decodeIfPresent(Int.self, forKey: .kidneys) ?? 0
        mood = try container.decodeIfPresent(Int.self, forKey: .mood) ?? 0
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
    
    var averageScore: Int {
        let scores = [allergies, antiInflammation, bloodSugar, brainHealth, detoxLiver, energy, eyeHealth, heartHealth, immune, jointHealth, kidneys, mood, skin, sleep, stress, weightManagement]
        return scores.reduce(0, +) / scores.count
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

// MARK: - Recipe Nutrition Info
struct RecipeNutritionInfo: Codable, Equatable {
    let calories: Int
    let protein: Double // in grams
    let carbohydrates: Double // in grams
    let fat: Double // in grams
    let fiber: Double // in grams
    let sugar: Double // in grams
    let sodium: Double // in milligrams
    let cholesterol: Double // in milligrams
    let saturatedFat: Double // in grams
    let transFat: Double // in grams
    let servingSize: String
    
    init(
        calories: Int = 0,
        protein: Double = 0.0,
        carbohydrates: Double = 0.0,
        fat: Double = 0.0,
        fiber: Double = 0.0,
        sugar: Double = 0.0,
        sodium: Double = 0.0,
        cholesterol: Double = 0.0,
        saturatedFat: Double = 0.0,
        transFat: Double = 0.0,
        servingSize: String = "1 serving"
    ) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.cholesterol = cholesterol
        self.saturatedFat = saturatedFat
        self.transFat = transFat
        self.servingSize = servingSize
    }
    
    var proteinFormatted: String {
        String(format: "%.1fg", protein)
    }
    
    var carbohydratesFormatted: String {
        String(format: "%.1fg", carbohydrates)
    }
    
    var fatFormatted: String {
        String(format: "%.1fg", fat)
    }
    
    var fiberFormatted: String {
        String(format: "%.1fg", fiber)
    }
    
    var sugarFormatted: String {
        String(format: "%.1fg", sugar)
    }
    
    var sodiumFormatted: String {
        String(format: "%.0fmg", sodium)
    }
    
    var cholesterolFormatted: String {
        String(format: "%.0fmg", cholesterol)
    }
    
    var saturatedFatFormatted: String {
        String(format: "%.1fg", saturatedFat)
    }
    
    var transFatFormatted: String {
        String(format: "%.1fg", transFat)
    }
}

// MARK: - Recipe Search Filters
struct RecipeSearchFilters: Codable, Equatable {
    var categories: Set<RecipeCategory> = []
    var maxPrepTime: Int?
    var maxCookTime: Int?
    var maxTotalTime: Int?
    var minRating: Double?
    var maxRating: Double?
    var minServings: Int?
    var maxServings: Int?
    var hasAnalysis: Bool?
    var isFavorite: Bool?
    var searchText: String = ""
    var sortBy: RecipeSortOption = .dateAdded
    var sortOrder: SortOrder = .descending
    
    enum RecipeSortOption: String, Codable, CaseIterable {
        case dateAdded = "date_added"
        case lastModified = "last_modified"
        case title = "title"
        case rating = "rating"
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case totalTime = "total_time"
        case longevityScore = "longevity_score"
        case servings = "servings"
        
        var displayName: String {
            switch self {
            case .dateAdded: return "Date Added"
            case .lastModified: return "Last Modified"
            case .title: return "Title"
            case .rating: return "Rating"
            case .prepTime: return "Prep Time"
            case .cookTime: return "Cook Time"
            case .totalTime: return "Total Time"
            case .longevityScore: return "Longevity Score"
            case .servings: return "Servings"
            }
        }
    }
    
    enum SortOrder: String, Codable, CaseIterable {
        case ascending = "asc"
        case descending = "desc"
        
        var displayName: String {
            switch self {
            case .ascending: return "Ascending"
            case .descending: return "Descending"
            }
        }
    }
}
