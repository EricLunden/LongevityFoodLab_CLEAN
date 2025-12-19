import Foundation

struct PetFoodAnalysis: Codable, Identifiable {
    var id: String { "\(petType.rawValue)_\(brandName)_\(productName)" }
    let petType: PetType
    let brandName: String
    let productName: String
    let overallScore: Int
    let summary: String
    let healthScores: PetHealthScores
    let keyBenefits: [String]
    let ingredients: [PetFoodIngredient]
    let fillersAndConcerns: PetFoodFillersAndConcerns
    let bestPractices: PetFoodBestPractices
    let nutritionInfo: PetNutritionInfo
    let analysisDate: Date?
    let cacheKey: String?
    let cacheVersion: String?
    let suggestions: [PetFoodSuggestion]?
    
    enum PetType: String, Codable, CaseIterable {
        case dog = "dog"
        case cat = "cat"
        
        var displayName: String {
            switch self {
            case .dog: return "Dog"
            case .cat: return "Cat"
            }
        }
        
        var emoji: String {
            switch self {
            case .dog: return "🐕"
            case .cat: return "🐱"
            }
        }
    }
}

struct PetHealthScores: Codable {
    let digestiveHealth: Int
    let coatHealth: Int
    let jointHealth: Int
    let immuneHealth: Int
    let energyLevel: Int
    let weightManagement: Int
    let dentalHealth: Int
    let skinHealth: Int
}

struct PetFoodIngredient: Codable {
    let name: String
    let impact: String
    let explanation: String
    let isBeneficial: Bool
}

struct PetFoodFillersAndConcerns: Codable {
    let fillers: [PetFoodFiller]
    let potentialConcerns: [PetFoodConcern]
    let overallRisk: String
    let recommendations: String
}

struct PetFoodFiller: Codable {
    let name: String
    let description: String
    let whyUsed: String
    let impact: String
    let isConcerning: Bool
}

struct PetFoodConcern: Codable {
    let ingredient: String
    let concern: String
    let explanation: String
    let severity: String
    let alternatives: String
}

struct PetFoodBestPractices: Codable {
    let feedingGuidelines: String
    let portionSize: String
    let frequency: String
    let specialConsiderations: String
    let transitionTips: String
}

struct PetNutritionInfo: Codable {
    let protein: String
    let fat: String
    let carbohydrates: String
    let fiber: String
    let moisture: String
    let calories: String
    let omega3: String
    let omega6: String
}

// MARK: - Cache Management
struct PetFoodCacheEntry: Codable, Equatable, Identifiable {
    var id: String { cacheKey }
    let cacheKey: String
    let petType: PetFoodAnalysis.PetType
    let brandName: String
    let productName: String
    let analysisDate: Date
    let cacheVersion: String
    let fullAnalysis: PetFoodAnalysis
    
    var isExpired: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return analysisDate < thirtyDaysAgo
    }
    
    var daysSinceAnalysis: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: analysisDate, to: Date())
        return components.day ?? 0
    }
    
    var ageDescription: String {
        if daysSinceAnalysis == 0 {
            return "Today"
        } else if daysSinceAnalysis == 1 {
            return "Yesterday"
        } else if daysSinceAnalysis < 7 {
            return "\(daysSinceAnalysis) days ago"
        } else if daysSinceAnalysis < 30 {
            let weeks = daysSinceAnalysis / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        } else {
            return "Over 30 days ago"
        }
    }
    
    // MARK: - Equatable
    static func == (lhs: PetFoodCacheEntry, rhs: PetFoodCacheEntry) -> Bool {
        return lhs.cacheKey == rhs.cacheKey
    }
}

// MARK: - Cache Key Generation
extension PetFoodAnalysis {
    static func generateCacheKey(petType: PetType, productName: String) -> String {
        let normalizedProduct = productName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        
        return "\(petType.rawValue)_unknown_\(normalizedProduct)"
    }
    
    static func normalizeInput(_ input: String) -> String {
        return input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

// MARK: - Pet Food Suggestions
struct PetFoodSuggestion: Codable {
    let brandName: String
    let productName: String
    let score: Int
    let reason: String
    let keyBenefits: [String]
    let priceRange: String
    let availability: String
}
