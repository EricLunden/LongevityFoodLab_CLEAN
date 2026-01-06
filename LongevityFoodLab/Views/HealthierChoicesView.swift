//
//  HealthierChoicesView.swift
//  LongevityFoodLab
//
//  Healthier Choices Dropdown for Scanned Products
//

import SwiftUI

struct HealthierChoicesView: View {
    let analysis: FoodAnalysis
    @State private var isExpanded = false
    @State private var suggestions: [GrocerySuggestion] = []
    @State private var isLoading = false
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                    // Load suggestions only when expanded for the first time
                    if isExpanded && suggestions.isEmpty && !isLoading {
                        // Always check cache first (most up-to-date) since suggestions may be saved asynchronously
                        if let cachedSuggestions = getCachedSuggestions(), !cachedSuggestions.isEmpty {
                            print("🔍 HealthierChoicesView: Using suggestions from cache lookup")
                            suggestions = removeDuplicates(cachedSuggestions)
                        } else if let cachedSuggestions = analysis.suggestions, !cachedSuggestions.isEmpty {
                            // Fallback to analysis.suggestions
                            print("🔍 HealthierChoicesView: Using suggestions from analysis.suggestions")
                            suggestions = removeDuplicates(cachedSuggestions)
                        } else {
                            print("🔍 HealthierChoicesView: No cached suggestions, calling API")
                            loadHealthierChoices()
                        }
                    }
                }
            }) {
                HStack {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color(red: 0.2, green: 0.8, blue: 0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Text("Healthier Choices")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded Content
            if isExpanded {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Finding healthier alternatives...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                } else if !suggestions.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(suggestions, id: \.productName) { suggestion in
                            suggestionCard(suggestion)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Load Healthier Choices
    private func loadHealthierChoices() {
        isLoading = true
        let nutritionInfo = analysis.nutritionInfoOrDefault
        
        AIService.shared.findSimilarGroceryProducts(
            currentProduct: analysis.foodName,
            currentScore: analysis.overallScore,
            nutritionInfo: nutritionInfo
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let grocerySuggestions):
                    // Remove duplicates and limit to 2 suggestions
                    let uniqueSuggestions = removeDuplicates(grocerySuggestions)
                    suggestions = Array(uniqueSuggestions.prefix(2))
                    
                    // Save to cache
                    saveSuggestionsToCache(suggestions)
                case .failure(let error):
                    print("HealthierChoicesView: Failed to load suggestions: \(error)")
                    // Fallback to empty array - user will see no suggestions
                    suggestions = []
                }
            }
        }
    }
    
    // MARK: - Get Cached Suggestions
    private func getCachedSuggestions() -> [GrocerySuggestion]? {
        print("🔍 HealthierChoicesView: Looking for cached suggestions for '\(analysis.foodName)' score \(analysis.overallScore)")
        print("🔍 HealthierChoicesView: Total cache entries: \(foodCacheManager.cachedAnalyses.count)")
        
        // First try: exact match by foodName and score (most reliable)
        if let entry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == analysis.foodName &&
            entry.fullAnalysis.overallScore == analysis.overallScore
        }) {
            print("🔍 HealthierChoicesView: Found exact match entry, has suggestions: \(entry.fullAnalysis.suggestions != nil), count: \(entry.fullAnalysis.suggestions?.count ?? 0)")
            if let suggestions = entry.fullAnalysis.suggestions, !suggestions.isEmpty {
                print("🔍 HealthierChoicesView: Found cached suggestions via exact match")
                return suggestions
            } else {
                print("🔍 HealthierChoicesView: Exact match entry exists but has no suggestions")
            }
        } else {
            print("🔍 HealthierChoicesView: No exact match found")
        }
        
        // Second try: normalized name match with score
        let normalizedName = FoodAnalysis.normalizeInput(analysis.foodName)
        let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
            let entryNormalizedName = FoodAnalysis.normalizeInput(entry.foodName)
            return entryNormalizedName == normalizedName &&
                   entry.fullAnalysis.overallScore == analysis.overallScore
        }
        
        print("🔍 HealthierChoicesView: Found \(matchingEntries.count) normalized matches")
        
        // Get the most recent entry that matches
        if let entry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
            print("🔍 HealthierChoicesView: Normalized match entry, has suggestions: \(entry.fullAnalysis.suggestions != nil), count: \(entry.fullAnalysis.suggestions?.count ?? 0)")
            if let suggestions = entry.fullAnalysis.suggestions, !suggestions.isEmpty {
                print("🔍 HealthierChoicesView: Found cached suggestions via normalized match")
                return suggestions
            }
        }
        
        print("🔍 HealthierChoicesView: No cached suggestions found after all attempts")
        return nil
    }
    
    // MARK: - Save Suggestions to Cache
    private func saveSuggestionsToCache(_ suggestions: [GrocerySuggestion]) {
        guard !suggestions.isEmpty else { return }
        
        // Find cache entry by foodName (most recent)
        let normalizedName = FoodAnalysis.normalizeInput(analysis.foodName)
        let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
            let entryNormalizedName = FoodAnalysis.normalizeInput(entry.foodName)
            return entryNormalizedName == normalizedName
        }
        
        if let entry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
            // Update by imageHash if available, otherwise by cacheKey
            if let imageHash = entry.imageHash {
                foodCacheManager.updateSuggestions(forImageHash: imageHash, suggestions: suggestions)
            } else {
                foodCacheManager.updateSuggestions(forCacheKey: entry.cacheKey, suggestions: suggestions)
            }
        }
    }
    
    // MARK: - Remove Duplicates
    private func removeDuplicates(_ suggestions: [GrocerySuggestion]) -> [GrocerySuggestion] {
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
    
    // MARK: - Suggestion Card (matching Pet Foods style)
    private func suggestionCard(_ suggestion: GrocerySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with brand, product, and score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.brandName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.productName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Score badge
                VStack(spacing: 2) {
                    Text("\(suggestion.score)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 60, height: 60)
                .background(scoreGradient(suggestion.score))
                .cornerRadius(30)
            }
            
            // Reason for higher score
            Text(suggestion.reason)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Key benefits
            if !suggestion.keyBenefits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Benefits:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(suggestion.keyBenefits, id: \.self) { benefit in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            
                            Text(benefit)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            // Price and availability
            HStack {
                Text(suggestion.priceRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(suggestion.availability)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // Gradient that runs from red to green based on score (matching app standard)
    private func scoreGradient(_ score: Int) -> LinearGradient {
        let progress = CGFloat(score) / 100.0
        
        let startColor: Color
        let endColor: Color
        
        if progress <= 0.4 {
            startColor = Color(red: 0.8, green: 0.1, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.4, blue: 0.1)
        } else if progress <= 0.6 {
            startColor = Color(red: 0.9, green: 0.5, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.7, blue: 0.2)
        } else if progress <= 0.8 {
            startColor = Color(red: 0.8, green: 0.7, blue: 0.2)
            endColor = Color(red: 0.4, green: 0.7, blue: 0.4)
        } else {
            startColor = Color(red: 0.3, green: 0.6, blue: 0.3)
            endColor = Color(red: 0.2, green: 0.5, blue: 0.2)
        }
        
        return LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
}


