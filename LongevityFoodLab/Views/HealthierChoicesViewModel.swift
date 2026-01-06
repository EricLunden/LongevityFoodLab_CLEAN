//
//  HealthierChoicesViewModel.swift
//  LongevityFoodLab
//
//  ViewModel for loading healthier choice suggestions asynchronously
//  Ensures cache lookup runs off main thread to prevent blocking initial view render
//

import Foundation
import SwiftUI

@MainActor
class HealthierChoicesViewModel: ObservableObject {
    @Published var suggestions: [GrocerySuggestion] = []
    @Published var isLoading: Bool = false
    
    private var hasLoaded: Bool = false // Prevents duplicate loading
    private let foodCacheManager = FoodCacheManager.shared
    
    /// Set immediate suggestion from bestPreparation text (scanner-generated recommendation)
    /// Converts text into a minimal GrocerySuggestion and displays immediately
    func setImmediateSuggestion(from text: String, analysisScore: Int) {
        guard !hasLoaded else {
            print("🔍 HealthierChoicesViewModel: Already loaded, skipping immediate suggestion")
            return
        }
        
        print("🔍 HealthierChoicesViewModel: Setting immediate suggestion from bestPreparation")
        
        // Convert bestPreparation text into a minimal GrocerySuggestion
        // Use analysis score + 5 to indicate it's a better choice
        let suggestion = GrocerySuggestion(
            brandName: "",
            productName: "Recommended Alternative",
            score: min(analysisScore + 5, 100), // Show as better, but cap at 100
            reason: text,
            keyBenefits: [],
            priceRange: "",
            availability: ""
        )
        
        suggestions = [suggestion]
        isLoading = false
        hasLoaded = true
    }
    
    /// Load suggestions for the given analysis (fallback when bestPreparation is missing)
    /// Cache lookup runs off main thread, state updates happen on MainActor
    func loadSuggestions(for analysis: FoodAnalysis) {
        // Prevent duplicate loads
        guard !hasLoaded && suggestions.isEmpty && !isLoading else {
            print("🔍 HealthierChoicesViewModel: Skipping load - already have suggestions or loading")
            return
        }
        
        print("🔍 HealthierChoicesViewModel: Starting async load for \(analysis.foodName)")
        
        // Perform cache lookup off main thread to avoid blocking view render
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            
            // Check analysis.suggestions first (fast, synchronous)
            if let cachedSuggestions = analysis.suggestions, !cachedSuggestions.isEmpty {
                print("🔍 HealthierChoicesViewModel: Found \(cachedSuggestions.count) suggestions in analysis.suggestions")
                let uniqueSuggestions = Self.removeDuplicates(cachedSuggestions)
                await MainActor.run {
                    self.suggestions = uniqueSuggestions
                    self.hasLoaded = true
                }
                return
            }
            
            // Check cache entry directly (runs off main thread)
            if let cachedSuggestions = Self.getCachedSuggestions(for: analysis, cacheManager: self.foodCacheManager), !cachedSuggestions.isEmpty {
                print("🔍 HealthierChoicesViewModel: Found \(cachedSuggestions.count) suggestions in cache")
                let uniqueSuggestions = Self.removeDuplicates(cachedSuggestions)
                await MainActor.run {
                    self.suggestions = uniqueSuggestions
                    self.hasLoaded = true
                }
                return
            }
            
            // Cache miss - make API call (runs off main thread, updates on MainActor)
            print("🔍 HealthierChoicesViewModel: No cached suggestions, calling API")
            await MainActor.run {
                self.isLoading = true
            }
            
            Self.loadFromAPI(for: analysis, viewModel: self)
        }
    }
    
    /// Get cached suggestions (runs off main thread) - nonisolated static method
    private nonisolated static func getCachedSuggestions(for analysis: FoodAnalysis, cacheManager: FoodCacheManager) -> [GrocerySuggestion]? {
        // Find cache entry by foodName (most recent)
        let normalizedName = FoodAnalysis.normalizeInput(analysis.foodName)
        let matchingEntries = cacheManager.cachedAnalyses.filter { entry in
            let entryNormalizedName = FoodAnalysis.normalizeInput(entry.foodName)
            return entryNormalizedName == normalizedName
        }
        
        // Get the most recent entry that matches the score (to ensure it's the same product)
        if let entry = matchingEntries
            .filter({ $0.fullAnalysis.overallScore == analysis.overallScore })
            .sorted(by: { $0.analysisDate > $1.analysisDate })
            .first {
            return entry.fullAnalysis.suggestions
        }
        
        // Fallback: just get the most recent entry
        if let entry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
            return entry.fullAnalysis.suggestions
        }
        
        return nil
    }
    
    /// Load suggestions from API (runs off main thread, updates on MainActor) - nonisolated static method
    private nonisolated static func loadFromAPI(for analysis: FoodAnalysis, viewModel: HealthierChoicesViewModel) {
        let nutritionInfo = analysis.nutritionInfoOrDefault
        
        AIService.shared.findSimilarGroceryProducts(
            currentProduct: analysis.foodName,
            currentScore: analysis.overallScore,
            nutritionInfo: nutritionInfo
        ) { result in
            Task { @MainActor in
                viewModel.isLoading = false
                
                switch result {
                case .success(let apiSuggestions):
                    // Remove duplicates and limit to 2 suggestions
                    let uniqueSuggestions = Self.removeDuplicates(apiSuggestions)
                    viewModel.suggestions = Array(uniqueSuggestions.prefix(2))
                    viewModel.hasLoaded = true
                    
                    // Save to cache (runs async, doesn't block)
                    Task {
                        await Self.saveSuggestionsToCache(viewModel.suggestions, for: analysis, cacheManager: viewModel.foodCacheManager)
                    }
                case .failure(let error):
                    print("HealthierChoicesViewModel: Failed to load suggestions: \(error)")
                    viewModel.suggestions = []
                    viewModel.hasLoaded = true
                }
            }
        }
    }
    
    /// Save suggestions to cache - nonisolated static method
    private nonisolated static func saveSuggestionsToCache(_ suggestions: [GrocerySuggestion], for analysis: FoodAnalysis, cacheManager: FoodCacheManager) async {
        guard !suggestions.isEmpty else { return }
        
        // Find cache entry by foodName (most recent)
        let normalizedName = FoodAnalysis.normalizeInput(analysis.foodName)
        let matchingEntries = cacheManager.cachedAnalyses.filter { entry in
            let entryNormalizedName = FoodAnalysis.normalizeInput(entry.foodName)
            return entryNormalizedName == normalizedName
        }
        
        if let entry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
            // Update by imageHash if available, otherwise by cacheKey
            await MainActor.run {
                if let imageHash = entry.imageHash {
                    cacheManager.updateSuggestions(forImageHash: imageHash, suggestions: suggestions)
                } else {
                    cacheManager.updateSuggestions(forCacheKey: entry.cacheKey, suggestions: suggestions)
                }
            }
        }
    }
    
    /// Remove duplicate suggestions - nonisolated static method
    private nonisolated static func removeDuplicates(_ suggestions: [GrocerySuggestion]) -> [GrocerySuggestion] {
        var seen = Set<String>()
        var unique: [GrocerySuggestion] = []
        
        for suggestion in suggestions {
            let key = "\(suggestion.brandName)_\(suggestion.productName)".lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(suggestion)
            }
        }
        
        // If only 1 suggestion, return it (don't duplicate)
        return unique
    }
}

