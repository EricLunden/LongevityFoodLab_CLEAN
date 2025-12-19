import Foundation
import SwiftUI

// MARK: - Meal Plan Manager (v1 - Simple)
class MealPlanManager: ObservableObject {
    static let shared = MealPlanManager()
    
    @Published var mealPlans: [MealPlan] = []
    
    private let userDefaults = UserDefaults.standard
    private let mealPlansKey = "mealPlans"
    
    private init() {
        loadMealPlans()
    }
    
    // MARK: - CRUD Operations
    
    func createMealPlan(startDate: Date, endDate: Date) -> MealPlan {
        let plan = MealPlan(
            startDate: startDate,
            endDate: endDate,
            plannedMeals: [],
            createdAt: Date(),
            isActive: true
        )
        mealPlans.append(plan)
        saveMealPlans()
        return plan
    }
    
    func addPlannedMeal(_ meal: PlannedMeal, to plan: MealPlan) {
        if let index = mealPlans.firstIndex(where: { $0.id == plan.id }) {
            mealPlans[index].plannedMeals.append(meal)
            saveMealPlans()
        }
    }
    
    func updateMealPlan(_ plan: MealPlan) {
        if let index = mealPlans.firstIndex(where: { $0.id == plan.id }) {
            mealPlans[index] = plan
            saveMealPlans()
        }
    }
    
    func deleteMealPlan(_ plan: MealPlan) {
        mealPlans.removeAll { $0.id == plan.id }
        saveMealPlans()
    }
    
    func deletePlannedMeal(_ meal: PlannedMeal, from plan: MealPlan) {
        if let planIndex = mealPlans.firstIndex(where: { $0.id == plan.id }) {
            mealPlans[planIndex].plannedMeals.removeAll { $0.id == meal.id }
            saveMealPlans()
        }
    }
    
    // MARK: - Query Methods
    
    func getPlannedMealsForDate(_ date: Date) -> [PlannedMeal] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return mealPlans
            .filter { $0.isActive }
            .flatMap { $0.plannedMeals }
            .filter { meal in
                meal.scheduledDate >= startOfDay && meal.scheduledDate < endOfDay
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    func getPlannedMealsForWeek(starting date: Date) -> [PlannedMeal] {
        let calendar = Calendar.current
        let startOfWeek = calendar.startOfDay(for: date)
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return []
        }
        
        return mealPlans
            .filter { $0.isActive }
            .flatMap { $0.plannedMeals }
            .filter { meal in
                meal.scheduledDate >= startOfWeek && meal.scheduledDate < endOfWeek
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    func getActiveMealPlan() -> MealPlan? {
        return mealPlans.first { $0.isActive }
    }
    
    // MARK: - Conversion Methods
    
    func convertPlannedMealToTracked(_ plannedMeal: PlannedMeal) -> TrackedMeal {
        // Stub implementation - convert PlannedMeal to TrackedMeal
        // This would be called when user marks a planned meal as consumed
        return TrackedMeal(
            id: UUID(),
            name: plannedMeal.displayTitle,
            foods: [plannedMeal.displayTitle],
            healthScore: plannedMeal.estimatedLongevityScore ?? 0,
            goalsMet: [],
            timestamp: plannedMeal.scheduledDate,
            notes: nil,
            originalAnalysis: nil,
            imageHash: nil,
            isFavorite: false
        )
    }
    
    func generateShoppingList(from meals: [PlannedMeal]) -> ShoppingList {
        // Stub implementation - generate shopping list from planned meals
        // This would aggregate ingredients from recipes
        return ShoppingList(items: [])
    }
    
    // MARK: - Persistence
    
    func saveMealPlans() {
        do {
            let data = try JSONEncoder().encode(mealPlans)
            userDefaults.set(data, forKey: mealPlansKey)
            print("🍽️ MealPlanManager: Saved \(mealPlans.count) meal plans")
        } catch {
            print("🍽️ MealPlanManager: Error saving meal plans: \(error)")
        }
    }
    
    private func loadMealPlans() {
        guard let data = userDefaults.data(forKey: mealPlansKey) else {
            print("🍽️ MealPlanManager: No saved meal plans found")
            return
        }
        
        do {
            mealPlans = try JSONDecoder().decode([MealPlan].self, from: data)
            print("🍽️ MealPlanManager: Loaded \(mealPlans.count) meal plans")
        } catch {
            print("🍽️ MealPlanManager: Error loading meal plans: \(error)")
            mealPlans = []
        }
    }
}

// MARK: - Shopping List Model (Simple)

struct ShoppingList {
    let items: [ShoppingListItem]
}

struct ShoppingListItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: String
    let category: String
    let usedInMeals: Int // Number of meals using this ingredient
}

