//
//  HealthierChoicesContainerView.swift
//  LongevityFoodLab
//
//  Container view that loads healthier choices asynchronously
//  Triggers loading only after view appears to avoid blocking initial render
//

import SwiftUI

struct HealthierChoicesContainerView: View {
    let analysis: FoodAnalysis
    @Binding var bestPreparation: String?
    
    @StateObject private var viewModel = HealthierChoicesViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Finding healthier alternatives...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            } else if !viewModel.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Healthier Choices:")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    
                    VStack(spacing: 12) {
                        ForEach(viewModel.suggestions, id: \.productName) { suggestion in
                            suggestionCard(suggestion)
                        }
                    }
                }
            }
            // Don't show anything when empty - loading happens asynchronously after view appears
        }
        .onAppear {
            print("🔍 HealthierChoices: onAppear, bestPreparation = \(bestPreparation ?? "nil")")
            checkAndLoadSuggestions()
        }
        .onChange(of: bestPreparation) { oldValue, newValue in
            print("🔍 HealthierChoices: onChange, old = \(oldValue ?? "nil"), new = \(newValue ?? "nil")")
            if let newValue = newValue, !newValue.isEmpty {
                viewModel.setImmediateSuggestion(from: newValue, analysisScore: analysis.overallScore)
            }
        }
    }
    
    private func checkAndLoadSuggestions() {
        // Check the BINDING, not analysis.bestPreparation
        if let bestPrep = bestPreparation, !bestPrep.isEmpty {
            print("🔍 HealthierChoices: Using bestPreparation from binding")
            viewModel.setImmediateSuggestion(from: bestPrep, analysisScore: analysis.overallScore)
        } else {
            print("🔍 HealthierChoices: No bestPreparation, loading suggestions")
            // Fallback: load from cache/API if bestPreparation is missing
            // Only load if we haven't already loaded (prevents duplicate calls)
            if viewModel.suggestions.isEmpty && !viewModel.isLoading {
                viewModel.loadSuggestions(for: analysis)
            }
        }
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
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Score circle
                Circle()
                    .fill(scoreGradient(suggestion.score))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("\(suggestion.score)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            // Reason
            Text(suggestion.reason)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Key benefits
            if !suggestion.keyBenefits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(suggestion.keyBenefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(benefit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Price and availability
            HStack {
                if !suggestion.priceRange.isEmpty {
                    Label(suggestion.priceRange, systemImage: "dollarsign.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !suggestion.availability.isEmpty {
                    Label(suggestion.availability, systemImage: "cart.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Score Gradient Helper
    private func scoreGradient(_ score: Int) -> LinearGradient {
        if score >= 70 {
            return LinearGradient(
                colors: [Color.green.opacity(0.8), Color.green],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if score < 50 {
            return LinearGradient(
                colors: [Color.red.opacity(0.8), Color.red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

