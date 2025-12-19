import Foundation
import SwiftUI

class MealStorageManager: ObservableObject {
    static let shared = MealStorageManager()
    
    @Published var trackedMeals: [TrackedMeal] = []
    
    private let userDefaults = UserDefaults.standard
    private let mealsKey = "trackedMeals"
    
    private init() {
        loadMeals()
    }
    
    // MARK: - Meal Operations
    
    func addMeal(_ meal: TrackedMeal) {
        print("🍽️ MealStorageManager: Adding meal: \(meal.name)")
        trackedMeals.append(meal)
        saveMeals()
    }
    
    func deleteMeal(_ meal: TrackedMeal) {
        print("🍽️ MealStorageManager: Deleting meal: \(meal.name)")
        trackedMeals.removeAll { $0.id == meal.id }
        saveMeals()
    }
    
    func getMealsForDate(_ date: Date) -> [TrackedMeal] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return trackedMeals.filter { meal in
            meal.timestamp >= startOfDay && meal.timestamp < endOfDay
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    func getAllMeals() -> [TrackedMeal] {
        return trackedMeals.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Persistence
    
    func saveMeals() {
        do {
            let data = try JSONEncoder().encode(trackedMeals)
            userDefaults.set(data, forKey: mealsKey)
            print("🍽️ MealStorageManager: Saved \(trackedMeals.count) meals")
        } catch {
            print("🍽️ MealStorageManager: Error saving meals: \(error)")
        }
    }
    
    func updateMeal(_ meal: TrackedMeal) {
        if let index = trackedMeals.firstIndex(where: { $0.id == meal.id }) {
            trackedMeals[index] = meal
            saveMeals()
        }
    }
    
    private func loadMeals() {
        guard let data = userDefaults.data(forKey: mealsKey) else {
            print("🍽️ MealStorageManager: No saved meals found")
            return
        }
        
        do {
            trackedMeals = try JSONDecoder().decode([TrackedMeal].self, from: data)
            print("🍽️ MealStorageManager: Loaded \(trackedMeals.count) meals")
        } catch {
            print("🍽️ MealStorageManager: Error loading meals: \(error)")
            trackedMeals = []
        }
    }
}

// MARK: - TrackedMeal Codable Extension

extension TrackedMeal: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, foods, healthScore, goalsMet, timestamp, notes, originalAnalysis, imageHash, isFavorite
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        foods = try container.decode([String].self, forKey: .foods)
        healthScore = try container.decode(Double.self, forKey: .healthScore)
        goalsMet = try container.decode([String].self, forKey: .goalsMet)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        originalAnalysis = try container.decodeIfPresent(FoodAnalysis.self, forKey: .originalAnalysis)
        // imageHash is optional for backward compatibility with existing meals
        imageHash = try container.decodeIfPresent(String.self, forKey: .imageHash)
        // isFavorite is optional for backward compatibility with existing meals
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(foods, forKey: .foods)
        try container.encode(healthScore, forKey: .healthScore)
        try container.encode(goalsMet, forKey: .goalsMet)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(originalAnalysis, forKey: .originalAnalysis)
        try container.encodeIfPresent(imageHash, forKey: .imageHash)
        try container.encode(isFavorite, forKey: .isFavorite)
    }
}
