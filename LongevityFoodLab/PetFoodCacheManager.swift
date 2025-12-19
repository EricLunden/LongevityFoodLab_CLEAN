import Foundation
import CoreData

class PetFoodCacheManager: ObservableObject {
    static let shared = PetFoodCacheManager()
    private init() {}
    
    @Published var cachedAnalyses: [PetFoodCacheEntry] = []
    @Published var cacheSize: Int = 0
    @Published var lastCacheUpdate: Date = Date()
    
    private let maxCacheSize = 50
    private let cacheVersion = "v1.0"
    
    // MARK: - Cache Operations
    
    func getCachedAnalysis(for petType: PetFoodAnalysis.PetType, productName: String) -> PetFoodAnalysis? {
        let cacheKey = PetFoodAnalysis.generateCacheKey(petType: petType, productName: productName)
        
        if let cachedEntry = cachedAnalyses.first(where: { $0.cacheKey == cacheKey && !$0.isExpired }) {
            return cachedEntry.fullAnalysis
        }
        
        return nil
    }
    
    func cacheAnalysis(_ analysis: PetFoodAnalysis) {
        print("🔍 PetFoodCacheManager: Caching analysis for \(analysis.productName)")
        
        let entry = PetFoodCacheEntry(
            cacheKey: analysis.cacheKey ?? PetFoodAnalysis.generateCacheKey(petType: analysis.petType, productName: analysis.productName),
            petType: analysis.petType,
            brandName: analysis.brandName,
            productName: analysis.productName,
            analysisDate: analysis.analysisDate ?? Date(),
            cacheVersion: analysis.cacheVersion ?? "v1.0",
            fullAnalysis: analysis
        )
        
        print("🔍 PetFoodCacheManager: Created cache entry with key: \(entry.cacheKey)")
        
        // Remove existing entry if it exists
        cachedAnalyses.removeAll { $0.cacheKey == analysis.cacheKey }
        
        // Add new entry
        cachedAnalyses.append(entry)
        
        // Sort by most recent first
        cachedAnalyses.sort { $0.analysisDate > $1.analysisDate }
        
        // Enforce cache size limit
        if cachedAnalyses.count > maxCacheSize {
            cachedAnalyses = Array(cachedAnalyses.prefix(maxCacheSize))
        }
        
        // Update cache size
        cacheSize = cachedAnalyses.count
        lastCacheUpdate = Date()
        
        print("🔍 PetFoodCacheManager: Cache now contains \(cachedAnalyses.count) analyses")
        
        // Save to persistent storage
        saveToPersistentStorage()
    }
    
    func removeCachedAnalysis(withKey cacheKey: String) {
        cachedAnalyses.removeAll { $0.cacheKey == cacheKey }
        cacheSize = cachedAnalyses.count
        saveToPersistentStorage()
    }
    
    func deleteAnalysis(withCacheKey cacheKey: String) {
        print("🔍 PetFoodCacheManager: Deleting analysis with cache key: \(cacheKey)")
        cachedAnalyses.removeAll { $0.cacheKey == cacheKey }
        cacheSize = cachedAnalyses.count
        saveToPersistentStorage()
        print("🔍 PetFoodCacheManager: Analysis deleted. Cache now contains \(cachedAnalyses.count) analyses")
    }
    
    func clearAllCachedAnalyses() {
        cachedAnalyses.removeAll()
        cacheSize = 0
        lastCacheUpdate = Date()
        saveToPersistentStorage()
    }
    
    func refreshExpiredAnalyses() {
        let expiredKeys = cachedAnalyses.filter { $0.isExpired }.map { $0.cacheKey }
        expiredKeys.forEach { removeCachedAnalysis(withKey: $0) }
    }
    
    func getAnalysesForPetType(_ petType: PetFoodAnalysis.PetType) -> [PetFoodCacheEntry] {
        return cachedAnalyses.filter { $0.petType == petType }
    }
    
    func searchCachedAnalyses(query: String) -> [PetFoodCacheEntry] {
        let normalizedQuery = PetFoodAnalysis.normalizeInput(query)
        
        return cachedAnalyses.filter { entry in
            let normalizedBrand = PetFoodAnalysis.normalizeInput(entry.brandName)
            let normalizedProduct = PetFoodAnalysis.normalizeInput(entry.productName)
            
            return normalizedBrand.contains(normalizedQuery) || 
                   normalizedProduct.contains(normalizedQuery) ||
                   entry.brandName.lowercased().contains(query.lowercased()) ||
                   entry.productName.lowercased().contains(query.lowercased())
        }
    }
    
    // MARK: - Cache Validation
    
    func validateCacheIntegrity() {
        var validEntries: [PetFoodCacheEntry] = []
        
        for entry in cachedAnalyses {
            if isValidCacheEntry(entry) {
                validEntries.append(entry)
            } else {
                print("PetFoodCache: Invalid cache entry found, removing: \(entry.cacheKey)")
            }
        }
        
        if validEntries.count != cachedAnalyses.count {
            cachedAnalyses = validEntries
            cacheSize = cachedAnalyses.count
            saveToPersistentStorage()
        }
    }
    
    private func isValidCacheEntry(_ entry: PetFoodCacheEntry) -> Bool {
        // Check if all required fields are present
        guard !entry.brandName.isEmpty,
              !entry.productName.isEmpty,
              !entry.cacheKey.isEmpty,
              entry.fullAnalysis.overallScore >= 0 && entry.fullAnalysis.overallScore <= 100 else {
            return false
        }
        
        // Check if analysis date is reasonable (not in future, not too old)
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        
        guard entry.analysisDate <= now && entry.analysisDate >= thirtyDaysAgo else {
            return false
        }
        
        return true
    }
    
    // MARK: - Persistent Storage
    
    private func saveToPersistentStorage() {
        // For now, we'll use UserDefaults for simplicity
        // In production, you might want to use Core Data or SwiftData
        
        do {
            let data = try JSONEncoder().encode(cachedAnalyses)
            UserDefaults.standard.set(data, forKey: "PetFoodCache_v1.0")
            UserDefaults.standard.set(lastCacheUpdate, forKey: "PetFoodCache_LastUpdate")
        } catch {
            print("PetFoodCache: Failed to save cache: \(error)")
        }
    }
    
    func loadFromPersistentStorage() {
        print("🔍 PetFoodCacheManager: Loading cache from persistent storage...")
        guard let data = UserDefaults.standard.data(forKey: "PetFoodCache_v1.0") else {
            print("🔍 PetFoodCacheManager: No cache data found.")
            return
        }
        
        do {
            let loadedAnalyses = try JSONDecoder().decode([PetFoodCacheEntry].self, from: data)
            cachedAnalyses = loadedAnalyses.sorted { $0.analysisDate > $1.analysisDate }
            cacheSize = cachedAnalyses.count
            
            if let lastUpdate = UserDefaults.standard.object(forKey: "PetFoodCache_LastUpdate") as? Date {
                lastCacheUpdate = lastUpdate
                print("🔍 PetFoodCacheManager: Cache last updated: \(lastCacheUpdate)")
            } else {
                print("🔍 PetFoodCacheManager: Cache last update not found, setting to current date.")
                lastCacheUpdate = Date()
            }
            
            // Validate integrity after loading
            validateCacheIntegrity()
            print("🔍 PetFoodCacheManager: Cache loaded. Total analyses: \(cachedAnalyses.count), Expired: \(cachedAnalyses.filter { $0.isExpired }.count)")
            
        } catch {
            print("PetFoodCache: Failed to load cache: \(error)")
            print("PetFoodCache: Attempting to clear corrupted cache...")
            // If loading fails, clear the corrupted cache
            clearAllCachedAnalyses()
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStatistics() -> (total: Int, byPetType: [PetFoodAnalysis.PetType: Int], expired: Int) {
        let byPetType = Dictionary(grouping: cachedAnalyses, by: { $0.petType })
            .mapValues { $0.count }
        
        let expired = cachedAnalyses.filter { $0.isExpired }.count
        
        return (total: cachedAnalyses.count, byPetType: byPetType, expired: expired)
    }
    
    func getCacheSizeInMB() -> Double {
        // Rough estimation: each analysis is approximately 2-5KB
        let estimatedSizePerAnalysis = 3.5 // KB
        let totalKB = Double(cachedAnalyses.count) * estimatedSizePerAnalysis
        return totalKB / 1024.0 // Convert to MB
    }
}

// MARK: - Cache Key Utilities
extension PetFoodCacheManager {
    func generateCacheKey(petType: PetFoodAnalysis.PetType, productName: String) -> String {
        return PetFoodAnalysis.generateCacheKey(petType: petType, productName: productName)
    }
    
    func normalizeInput(_ input: String) -> String {
        return PetFoodAnalysis.normalizeInput(input)
    }
}
