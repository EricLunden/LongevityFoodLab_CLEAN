import Foundation
import SwiftUI

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "currentUser"
    private let authKey = "isAuthenticated"
    
    private init() {
        // Check if user is already logged in
        isAuthenticated = userDefaults.bool(forKey: authKey)
        if isAuthenticated {
            loadUserFromDefaults()
        }
    }
    
    func login(email: String, password: String) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // For demo purposes, accept demo credentials
        if email == "demo@example.com" && password == "password" {
            let user = User(
                id: UUID().uuidString,
                name: "Sarah Johnson",
                email: email,
                joinDate: Date(),
                preferences: UserPreferences()
            )
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.saveUserToDefaults()
            }
            
            return true
        } else {
            throw AuthError.invalidCredentials
        }
    }
    
    func signup(name: String, email: String, password: String) async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // For demo purposes, always succeed
        let user = User(
            id: UUID().uuidString,
            name: name,
            email: email,
            joinDate: Date(),
            preferences: UserPreferences()
        )
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.saveUserToDefaults()
        }
        
        return true
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
        userDefaults.removeObject(forKey: userKey)
        userDefaults.set(false, forKey: authKey)
    }
    
    func updateUserProfile(_ user: User) {
        currentUser = user
        saveUserToDefaults()
    }
    
    func updateProfilePhoto(_ imageData: Data?) {
        guard var user = currentUser else { return }
        user.profilePhotoData = imageData
        currentUser = user
        saveUserToDefaults()
    }
    
    func updateUserName(_ newName: String) {
        guard var user = currentUser else { return }
        user.name = newName
        currentUser = user
        saveUserToDefaults()
    }
    
    private func saveUserToDefaults() {
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: userKey)
            userDefaults.set(true, forKey: authKey)
        }
    }
    
    private func loadUserFromDefaults() {
        if let userData = userDefaults.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
        }
    }
}

// MARK: - Data Models
struct User: Codable, Identifiable {
    let id: String
    var name: String
    let email: String
    let joinDate: Date
    var preferences: UserPreferences
    var profilePhotoData: Data?
    
    var displayName: String {
        name.components(separatedBy: " ").first ?? name
    }
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool = true
    var dailyReminders: Bool = true
    var weeklyReports: Bool = true
    var goalCalories: Int = 2000
    var goalProtein: Int = 75
    var goalCarbs: Int = 225
    var goalFat: Int = 65
}

// MARK: - Error Types
enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case networkError
    case serverError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .serverError:
            return "Server error. Please try again later"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 