import Foundation
import SwiftUI
import CryptoKit
import UIKit

class FoodCacheManager: ObservableObject {
    static let shared = FoodCacheManager()
    
    @Published var cachedAnalyses: [FoodCacheEntry] = []
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cachedFoodAnalyses"
    private let lastUpdateKey = "lastFoodCacheUpdate"
    
    private init() {
        loadFromPersistentStorage()
    }
    
    // MARK: - Image Hash Utilities
    
    static func hashImage(_ imageData: Data) -> String {
        let hash = SHA256.hash(data: imageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Cache Operations
    
    func cacheAnalysis(_ analysis: FoodAnalysis, imageHash: String? = nil, scanType: String? = nil, inputMethod: String? = nil) {
        print("🔍 FoodCacheManager: Caching analysis for \(analysis.foodName)")
        
        // Use scanType from parameter if provided, otherwise use scanType from analysis object
        let finalScanType = scanType ?? analysis.scanType
        
        let analysisDate = Date()
        let entry = FoodCacheEntry(
            cacheKey: generateUniqueCacheKey(foodName: analysis.foodName, analysisDate: analysisDate),
            foodName: analysis.foodName,
            analysisDate: analysisDate,
            cacheVersion: "v1.0",
            fullAnalysis: analysis,
            imageHash: imageHash,
            scanType: finalScanType,
            inputMethod: inputMethod
        )
        
        print("🔍 FoodCacheManager: Created cache entry with key: \(entry.cacheKey), imageHash: \(imageHash ?? "none")")
        
        // Remove existing entry if it exists
        if let imageHash = imageHash {
            // Image entries: match by imageHash
            cachedAnalyses.removeAll { $0.imageHash == imageHash }
        } else if inputMethod != nil {
            // Text/voice entries: match by foodName + inputMethod (no imageHash)
            // This prevents duplicates when updating nutrition for text/voice entries
            cachedAnalyses.removeAll { 
                $0.foodName == analysis.foodName && 
                $0.inputMethod == inputMethod &&
                $0.imageHash == nil
            }
        }
        cachedAnalyses.removeAll { $0.cacheKey == entry.cacheKey }
        
        // Add new entry
        cachedAnalyses.append(entry)
        
        // Sort by analysis date (newest first)
        cachedAnalyses.sort { $0.analysisDate > $1.analysisDate }
        
        // Save to persistent storage
        saveToPersistentStorage()
        
        print("🔍 FoodCacheManager: Cache now contains \(cachedAnalyses.count) analyses")
    }
    
    func updateEntryFavorite(cacheKey: String, isFavorite: Bool) {
        if let index = cachedAnalyses.firstIndex(where: { $0.cacheKey == cacheKey }) {
            cachedAnalyses[index].isFavorite = isFavorite
            saveToPersistentStorage()
        }
    }
    
    func updateEntryFavorite(imageHash: String, isFavorite: Bool) {
        if let index = cachedAnalyses.firstIndex(where: { $0.imageHash == imageHash }) {
            cachedAnalyses[index].isFavorite = isFavorite
            saveToPersistentStorage()
        }
    }
    
    func getCachedAnalysis(forImageHash imageHash: String) -> FoodAnalysis? {
        print("🔍 FoodCacheManager: Looking for cached analysis with imageHash: \(imageHash)")
        
        // Find entry with matching image hash
        guard let entry = cachedAnalyses.first(where: { $0.imageHash == imageHash }) else {
            print("🔍 FoodCacheManager: No cached analysis found for image hash")
            return nil
        }
        
        // Check if analysis is expired (30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        if entry.analysisDate < thirtyDaysAgo {
            print("🔍 FoodCacheManager: Cached analysis expired, removing")
            cachedAnalyses.removeAll { $0.cacheKey == entry.cacheKey }
            saveToPersistentStorage()
            return nil
        }
        
        print("🔍 FoodCacheManager: Found cached analysis for image hash")
        return entry.fullAnalysis
    }
    
    func getCachedAnalysis(for foodName: String) -> FoodAnalysis? {
        let normalizedName = FoodAnalysis.normalizeInput(foodName)
        
        // Find the most recent analysis for this food name
        let matchingEntries = cachedAnalyses.filter { entry in
            let entryNormalizedName = FoodAnalysis.normalizeInput(entry.foodName)
            return entryNormalizedName == normalizedName
        }
        
        guard let entry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first else {
            return nil
        }
        
        // Check if analysis is expired (30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        if entry.analysisDate < thirtyDaysAgo {
            // Remove expired entry
            cachedAnalyses.removeAll { $0.cacheKey == entry.cacheKey }
            saveToPersistentStorage()
            return nil
        }
        
        return entry.fullAnalysis
    }
    
    func removeAnalysis(_ analysis: FoodAnalysis) {
        let normalizedName = FoodAnalysis.normalizeInput(analysis.foodName)
        
        // Remove all analyses for this food name
        cachedAnalyses.removeAll { entry in
            let entryNormalizedName = FoodAnalysis.normalizeInput(entry.foodName)
            return entryNormalizedName == normalizedName
        }
        saveToPersistentStorage()
    }
    
    func deleteAnalysis(withCacheKey cacheKey: String) {
        print("🔍 FoodCacheManager: Deleting analysis with cache key: \(cacheKey)")
        cachedAnalyses.removeAll { $0.cacheKey == cacheKey }
        saveToPersistentStorage()
        print("🔍 FoodCacheManager: Analysis deleted. Cache now contains \(cachedAnalyses.count) analyses")
    }
    
    /// Removes a cached analysis by its image hash
    /// Used when replacing an entry with a different image hash (e.g., supplement save)
    func removeCachedAnalysis(byImageHash hash: String) {
        guard !hash.isEmpty else { return }
        
        let countBefore = cachedAnalyses.count
        
        // Remove from in-memory cache
        cachedAnalyses.removeAll { $0.imageHash == hash }
        
        // Delete associated image from disk
        deleteImage(forHash: hash)
        
        let countAfter = cachedAnalyses.count
        
        if countBefore != countAfter {
            // Save updated cache to disk
            saveToPersistentStorage()
            print("🔍 FoodCacheManager: Removed entry with imageHash: \(hash.prefix(16))..., cache now contains \(countAfter) analyses")
        }
    }
    
    func clearAllAnalyses() {
        cachedAnalyses.removeAll()
        saveToPersistentStorage()
    }
    
    // MARK: - Update Suggestions in Cache
    
    func updateSuggestions(forImageHash imageHash: String?, suggestions: [GrocerySuggestion]) {
        guard let imageHash = imageHash else { return }
        
        if let index = cachedAnalyses.firstIndex(where: { $0.imageHash == imageHash }) {
            let entry = cachedAnalyses[index]
            let updatedAnalysis = FoodAnalysis(
                foodName: entry.fullAnalysis.foodName,
                overallScore: entry.fullAnalysis.overallScore,
                summary: entry.fullAnalysis.summary,
                healthScores: entry.fullAnalysis.healthScores,
                keyBenefits: entry.fullAnalysis.keyBenefits,
                ingredients: entry.fullAnalysis.ingredients,
                bestPreparation: entry.fullAnalysis.bestPreparation,
                servingSize: entry.fullAnalysis.servingSize,
                nutritionInfo: entry.fullAnalysis.nutritionInfo,
                scanType: entry.fullAnalysis.scanType,
                foodNames: entry.fullAnalysis.foodNames,
                suggestions: suggestions
            )
            
            let updatedEntry = FoodCacheEntry(
                cacheKey: entry.cacheKey,
                foodName: entry.foodName,
                analysisDate: entry.analysisDate,
                cacheVersion: entry.cacheVersion,
                fullAnalysis: updatedAnalysis,
                imageHash: entry.imageHash,
                scanType: entry.scanType,
                isFavorite: entry.isFavorite
            )
            
            cachedAnalyses[index] = updatedEntry
            saveToPersistentStorage()
            print("🔍 FoodCacheManager: Updated suggestions for \(entry.foodName)")
        }
    }
    
    func updateSuggestions(forCacheKey cacheKey: String, suggestions: [GrocerySuggestion]) {
        if let index = cachedAnalyses.firstIndex(where: { $0.cacheKey == cacheKey }) {
            let entry = cachedAnalyses[index]
            let updatedAnalysis = FoodAnalysis(
                foodName: entry.fullAnalysis.foodName,
                overallScore: entry.fullAnalysis.overallScore,
                summary: entry.fullAnalysis.summary,
                healthScores: entry.fullAnalysis.healthScores,
                keyBenefits: entry.fullAnalysis.keyBenefits,
                ingredients: entry.fullAnalysis.ingredients,
                bestPreparation: entry.fullAnalysis.bestPreparation,
                servingSize: entry.fullAnalysis.servingSize,
                nutritionInfo: entry.fullAnalysis.nutritionInfo,
                scanType: entry.fullAnalysis.scanType,
                foodNames: entry.fullAnalysis.foodNames,
                suggestions: suggestions
            )
            
            let updatedEntry = FoodCacheEntry(
                cacheKey: entry.cacheKey,
                foodName: entry.foodName,
                analysisDate: entry.analysisDate,
                cacheVersion: entry.cacheVersion,
                fullAnalysis: updatedAnalysis,
                imageHash: entry.imageHash,
                scanType: entry.scanType,
                isFavorite: entry.isFavorite
            )
            
            cachedAnalyses[index] = updatedEntry
            saveToPersistentStorage()
            print("🔍 FoodCacheManager: Updated suggestions for \(entry.foodName)")
        }
    }
    
    // MARK: - Image Storage
    
    func saveImage(_ image: UIImage, forHash imageHash: String) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("🔍 FoodCacheManager: Failed to convert image to JPEG data for hash: \(imageHash.prefix(16))...")
            return
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesPath = documentsPath.appendingPathComponent("GroceryScanImages")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true)
        
        let imageURL = imagesPath.appendingPathComponent("\(imageHash).jpg")
        do {
            try imageData.write(to: imageURL)
            print("🔍 FoodCacheManager: Saved image file for hash: \(imageHash.prefix(16))..., size: \(imageData.count) bytes")
        } catch {
            print("🔍 FoodCacheManager: ERROR saving image file for hash: \(imageHash.prefix(16))...: \(error)")
        }
    }
    
    func loadImage(forHash imageHash: String?) -> UIImage? {
        guard let imageHash = imageHash else { return nil }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent("GroceryScanImages/\(imageHash).jpg")
        
        guard let imageData = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: imageData)
    }
    
    func deleteImage(forHash imageHash: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent("GroceryScanImages/\(imageHash).jpg")
        
        try? FileManager.default.removeItem(at: imageURL)
        print("🔍 FoodCacheManager: Deleted image file for hash: \(imageHash.prefix(16))...")
    }
    
    // MARK: - Cache Key Generation
    
    private func generateCacheKey(foodName: String) -> String {
        let normalizedName = FoodAnalysis.normalizeInput(foodName)
        return "food_\(normalizedName)"
    }
    
    private func generateUniqueCacheKey(foodName: String, analysisDate: Date) -> String {
        let normalizedName = FoodAnalysis.normalizeInput(foodName)
        let timestamp = Int(analysisDate.timeIntervalSince1970)
        return "food_\(normalizedName)_\(timestamp)"
    }
    
    // MARK: - Persistent Storage
    
    private func saveToPersistentStorage() {
        do {
            let data = try JSONEncoder().encode(cachedAnalyses)
            userDefaults.set(data, forKey: cacheKey)
            userDefaults.set(Date(), forKey: lastUpdateKey)
            print("🔍 FoodCacheManager: Saved \(cachedAnalyses.count) analyses to persistent storage")
        } catch {
            print("🔍 FoodCacheManager: Error saving to persistent storage: \(error)")
        }
    }
    
    private func loadFromPersistentStorage() {
        print("🔍 FoodCacheManager: Loading cache from persistent storage...")
        
        guard let data = userDefaults.data(forKey: cacheKey) else {
            print("🔍 FoodCacheManager: No cache data found.")
            return
        }
        
        do {
            let entries = try JSONDecoder().decode([FoodCacheEntry].self, from: data)
            cachedAnalyses = entries
            
            // Sort by analysis date (newest first)
            cachedAnalyses.sort { $0.analysisDate > $1.analysisDate }
            
            // Check last update
            if let lastUpdate = userDefaults.object(forKey: lastUpdateKey) as? Date {
                print("🔍 FoodCacheManager: Cache last updated: \(lastUpdate)")
            } else {
                print("🔍 FoodCacheManager: Cache last update not found, setting to current date.")
                userDefaults.set(Date(), forKey: lastUpdateKey)
            }
            
            print("🔍 FoodCacheManager: Cache loaded. Total analyses: \(cachedAnalyses.count), Expired: \(cachedAnalyses.filter { $0.isExpired }.count)")
        } catch {
            print("🔍 FoodCacheManager: Error loading from persistent storage: \(error)")
            cachedAnalyses = []
        }
    }
}

// MARK: - Cache Entry Model

struct FoodCacheEntry: Codable, Equatable, Identifiable {
    var id: String { cacheKey }
    let cacheKey: String
    let foodName: String
    let analysisDate: Date
    let cacheVersion: String
    let fullAnalysis: FoodAnalysis
    let imageHash: String?
    let scanType: String?
    let inputMethod: String? // "text", "voice", or nil (for image entries)
    var isFavorite: Bool
    
    init(cacheKey: String, foodName: String, analysisDate: Date, cacheVersion: String, fullAnalysis: FoodAnalysis, imageHash: String? = nil, scanType: String? = nil, inputMethod: String? = nil, isFavorite: Bool = false) {
        self.cacheKey = cacheKey
        self.foodName = foodName
        self.analysisDate = analysisDate
        self.cacheVersion = cacheVersion
        self.fullAnalysis = fullAnalysis
        self.imageHash = imageHash
        self.scanType = scanType
        self.inputMethod = inputMethod
        self.isFavorite = isFavorite
    }
    
    enum CodingKeys: String, CodingKey {
        case cacheKey, foodName, analysisDate, cacheVersion, fullAnalysis, imageHash, scanType, inputMethod, isFavorite
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cacheKey = try container.decode(String.self, forKey: .cacheKey)
        foodName = try container.decode(String.self, forKey: .foodName)
        analysisDate = try container.decode(Date.self, forKey: .analysisDate)
        cacheVersion = try container.decode(String.self, forKey: .cacheVersion)
        fullAnalysis = try container.decode(FoodAnalysis.self, forKey: .fullAnalysis)
        imageHash = try container.decodeIfPresent(String.self, forKey: .imageHash)
        scanType = try container.decodeIfPresent(String.self, forKey: .scanType)
        inputMethod = try container.decodeIfPresent(String.self, forKey: .inputMethod) // Backward compatible - defaults to nil
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
    
    var isExpired: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return analysisDate < thirtyDaysAgo
    }
    
    var daysSinceAnalysis: Int {
        let calendar = Calendar.current
        
        // Normalize both dates to start of day for accurate day calculation
        let startOfAnalysisDate = calendar.startOfDay(for: analysisDate)
        let startOfToday = calendar.startOfDay(for: Date())
        
        let components = calendar.dateComponents([.day], from: startOfAnalysisDate, to: startOfToday)
        return components.day ?? 0
    }
}

// MARK: - FoodAnalysis Extension

extension FoodAnalysis {
    static func normalizeInput(_ input: String) -> String {
        return input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
    }
}
