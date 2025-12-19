import Foundation

// MARK: - Meal Plan Data Models (v1 - Lightweight)

enum PlanMode: String, Codable {
    case auto
    case manual
}

enum MealType: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case dinner
    case snack
    case dessert
    
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .dessert: return "Dessert"
        }
    }
}

struct PlannedMeal: Identifiable, Codable {
    let id: UUID
    let recipeID: UUID? // Optional reference to Recipe if from recipe
    let mealType: MealType
    let scheduledDate: Date
    let displayTitle: String
    let estimatedLongevityScore: Double?
    
    init(
        id: UUID = UUID(),
        recipeID: UUID? = nil,
        mealType: MealType,
        scheduledDate: Date,
        displayTitle: String,
        estimatedLongevityScore: Double? = nil
    ) {
        self.id = id
        self.recipeID = recipeID
        self.mealType = mealType
        self.scheduledDate = scheduledDate
        self.displayTitle = displayTitle
        self.estimatedLongevityScore = estimatedLongevityScore
    }
}

struct MealPlan: Identifiable, Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    var plannedMeals: [PlannedMeal]
    let createdAt: Date
    var isActive: Bool
    
    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        plannedMeals: [PlannedMeal] = [],
        createdAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.plannedMeals = plannedMeals
        self.createdAt = createdAt
        self.isActive = isActive
    }
}

