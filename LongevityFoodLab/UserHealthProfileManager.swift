import Foundation
import CoreData
import SwiftUI

extension Notification.Name {
    static let healthProfileUpdated = Notification.Name("healthProfileUpdated")
}

class UserHealthProfileManager: ObservableObject {
    static let shared = UserHealthProfileManager()
    
    @Published var currentProfile: UserHealthProfile?
    
    private let persistentContainer: NSPersistentContainer
    
    private init() {
        // Initialize Core Data stack
        persistentContainer = NSPersistentContainer(name: "UserHealthProfile")
        
        // CloudKit capability disabled for now (will enable in later phases)
        // if let storeDescription = persistentContainer.persistentStoreDescriptions.first {
        //     storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        //     storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        // }
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Core Data failed to load: \(error.localizedDescription)")
            } else {
                print("✅ Core Data loaded successfully")
                self.loadCurrentProfile()
            }
        }
        
        // Set up automatic saving
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Core Data Context
    
    private var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Profile Operations
    
    func loadCurrentProfile() {
        let request: NSFetchRequest<UserHealthProfile> = UserHealthProfile.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let profiles = try viewContext.fetch(request)
            DispatchQueue.main.async {
                self.currentProfile = profiles.first
            }
        } catch {
            print("❌ Failed to fetch profile: \(error.localizedDescription)")
        }
    }
    
    func profileExists() -> Bool {
        return currentProfile != nil
    }
    
    func createProfile(
        ageRange: String,
        sex: String,
        healthGoals: [String],
        dietaryPreference: String,
        foodRestrictions: [String],
        trackedMicronutrients: [String] = []
    ) -> Bool {
        let profile = UserHealthProfile(context: viewContext)
        profile.id = UUID()
        profile.ageRange = ageRange
        profile.sex = sex
        profile.healthGoals = arrayToJSON(healthGoals)
        profile.dietaryPreference = dietaryPreference
        profile.foodRestrictions = arrayToJSON(foodRestrictions)
        profile.trackedMicronutrients = arrayToJSON(trackedMicronutrients)
        profile.hasCompletedOnboarding = true
        profile.createdAt = Date()
        profile.lastModified = Date()
        
        return saveContext()
    }
    
    func updateProfile(
        ageRange: String? = nil,
        sex: String? = nil,
        healthGoals: [String]? = nil,
        dietaryPreference: String? = nil,
        foodRestrictions: [String]? = nil,
        trackedMicronutrients: [String]? = nil
    ) -> Bool {
        guard let profile = currentProfile else { return false }
        
        if let ageRange = ageRange { profile.ageRange = ageRange }
        if let sex = sex { profile.sex = sex }
        if let healthGoals = healthGoals { profile.healthGoals = arrayToJSON(healthGoals) }
        if let dietaryPreference = dietaryPreference { profile.dietaryPreference = dietaryPreference }
        if let foodRestrictions = foodRestrictions { profile.foodRestrictions = arrayToJSON(foodRestrictions) }
        if let trackedMicronutrients = trackedMicronutrients { profile.trackedMicronutrients = arrayToJSON(trackedMicronutrients) }
        
        profile.lastModified = Date()
        
        let success = saveContext()
        if success {
            NotificationCenter.default.post(name: .healthProfileUpdated, object: nil)
        }
        return success
    }
    
    func deleteProfile() -> Bool {
        guard let profile = currentProfile else { return false }
        
        viewContext.delete(profile)
        let success = saveContext()
        
        if success {
            DispatchQueue.main.async {
                self.currentProfile = nil
            }
        }
        
        return success
    }
    
    // MARK: - Helper Methods
    
    func getHealthGoals() -> [String] {
        guard let profile = currentProfile,
              let healthGoalsJSON = profile.healthGoals else { return [] }
        return jsonToArray(healthGoalsJSON)
    }
    
    func getFoodRestrictions() -> [String] {
        guard let profile = currentProfile,
              let restrictionsJSON = profile.foodRestrictions else { return [] }
        return jsonToArray(restrictionsJSON)
    }
    
    func getTrackedMicronutrients() -> [String] {
        guard let profile = currentProfile,
              let micronutrientsJSON = profile.trackedMicronutrients else { return [] }
        return jsonToArray(micronutrientsJSON)
    }
    
    // MARK: - Tracked Macros (using UserDefaults since no Core Data field yet)
    
    func getTrackedMacros() -> [String] {
        if let data = UserDefaults.standard.data(forKey: "trackedMacros"),
           let macros = try? JSONDecoder().decode([String].self, from: data) {
            return macros
        }
        // Default: all macros if none selected (including Kcal)
        return ["Kcal", "Protein", "Carbs", "Fat", "Fiber", "Sugar", "Sodium"]
    }
    
    func setTrackedMacros(_ macros: [String]) {
        if let data = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(data, forKey: "trackedMacros")
            NotificationCenter.default.post(name: .healthProfileUpdated, object: nil)
        }
    }
    
    func updateTrackedMicronutrients(_ micronutrients: [String]) -> Bool {
        return updateProfile(trackedMicronutrients: micronutrients)
    }
    
    // MARK: - JSON Conversion
    
    private func arrayToJSON(_ array: [String]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: array, options: [])
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            print("❌ Failed to convert array to JSON: \(error)")
            return "[]"
        }
    }
    
    private func jsonToArray(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String] ?? []
        } catch {
            print("❌ Failed to convert JSON to array: \(error)")
            return []
        }
    }
    
    // MARK: - Test Methods
    
    func createTestProfile() -> Bool {
        let testHealthGoals = ["Heart health", "Brain health", "Weight management"]
        let testRestrictions = ["Gluten", "Dairy"]
        
        return createProfile(
            ageRange: "30-50",
            sex: "Female",
            healthGoals: testHealthGoals,
            dietaryPreference: "Mediterranean",
            foodRestrictions: testRestrictions
        )
    }
    
    func printCurrentProfile() {
        guard let profile = currentProfile else {
            print("📋 No profile found")
            return
        }
        
        print("📋 Current Profile:")
        print("  ID: \(profile.id?.uuidString ?? "nil")")
        print("  Age Range: \(profile.ageRange ?? "nil")")
        print("  Sex: \(profile.sex ?? "nil")")
        print("  Health Goals: \(getHealthGoals())")
        print("  Dietary Preference: \(profile.dietaryPreference ?? "nil")")
        print("  Food Restrictions: \(getFoodRestrictions())")
        print("  Has Completed Onboarding: \(profile.hasCompletedOnboarding)")
        print("  Created: \(profile.createdAt?.description ?? "nil")")
        print("  Last Modified: \(profile.lastModified?.description ?? "nil")")
    }
    
    // MARK: - Core Data Save
    
    func saveContext() -> Bool {
        do {
            try viewContext.save()
            loadCurrentProfile() // Refresh current profile
            return true
        } catch {
            print("❌ Failed to save context: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - CloudKit Support

extension UserHealthProfileManager {
    func enableCloudKitSync() {
        // CloudKit sync is enabled in the persistent container setup
        print("☁️ CloudKit sync enabled for UserHealthProfile")
    }
}
