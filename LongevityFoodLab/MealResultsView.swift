//
//  MealResultsView.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 7/12/25.
//

import SwiftUI
import Foundation
// Import ResultsView for HealthDetailView

struct MealResultsView: View {
    let analyses: [FoodAnalysis]
    let onNewMeal: () -> Void
    
    var body: some View {
        let _ = print("MealResultsView: Received \(analyses.count) analyses")
        let _ = analyses.enumerated().forEach { index, analysis in
            print("MealResultsView: Analysis \(index + 1): \(analysis.foodName) - Score: \(analysis.overallScore)")
        }
        
        return ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Overall Meal Score
                    overallScoreCard
                    
                    // Individual Food Analyses
                    ForEach(analyses, id: \.foodName) { analysis in
                        FoodAnalysisCard(analysis: analysis)
                    }
                    
                    // Action Buttons
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // Clear button overlay at top right
            VStack {
                HStack {
                    Spacer()
                    Button(action: onNewMeal) {
                        Text("Clear")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(UIColor.systemBackground).opacity(0.9))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
    
    private var headerView: some View {
        VStack(spacing: 10) {
            Text("🍽️")
                .font(.system(size: 48))
            
            Text("Analysis Complete")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("\(analyses.count) foods analyzed")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    private var overallScoreCard: some View {
        let averageScore: Int
        if analyses.isEmpty {
            averageScore = 0
        } else {
            let totalScore = analyses.map { $0.overallScore }.reduce(0, +)
            averageScore = totalScore / analyses.count
        }
        
        return VStack(spacing: 20) {
            Text("Overall Meal Score")
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 15)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .trim(from: 0, to: CGFloat(averageScore) / 100)
                    .stroke(
                        scoreColor(averageScore),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(averageScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor(averageScore))
                    
                    Text(scoreLabel(averageScore))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("This meal has \(scoreLabel(averageScore).lowercased()) longevity benefits")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 15) {
            Button("Analyze Another Meal") {
                onNewMeal()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.42, green: 0.557, blue: 0.498))
            .cornerRadius(12)
            
            Button("Back to Search") {
                onNewMeal()
            }
            .font(.headline)
            .foregroundColor(.primary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Functions
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
        }
    }
    
    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 90...100: return "Exceptional"
        case 80...89: return "Excellent"
        case 70...79: return "Very Good"
        case 60...69: return "Good"
        case 50...59: return "Moderate"
        case 40...49: return "Fair"
        default: return "Limited"
        }
    }
}

struct FoodAnalysisCard: View {
    let analysis: FoodAnalysis
    @State private var isExpanded = false
    @State private var healthDetailItem: HealthDetailItem? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(analysis.foodName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Score: \(analysis.overallScore)/100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            // Summary
            Text(analysis.summary)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded ? nil : 2)
            
            // Health Scores (if expanded)
            if isExpanded {
                healthScoresGrid
                
                // Key Benefits
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 8) {
                        Text("🏆")
                            .foregroundColor(Color(red: 0.608, green: 0.827, blue: 0.835))
                        Text("Key Benefits")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(analysis.keyBenefitsOrDefault, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 10) {
                                Text("✓")
                                    .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                                    .fontWeight(.bold)
                                
                                Text(benefit)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .sheet(item: $healthDetailItem) { item in
            HealthDetailView(
                category: item.category,
                score: item.score,
                foodName: analysis.foodName,
                longevityScore: analysis.overallScore,
                isMealAnalysis: true,
                scanType: analysis.scanType,
                ingredients: analysis.ingredientsOrDefault
            )
        }
    }
    
    private var healthScoresGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Health Benefits")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                healthScoreButton("🤧", "Allergies", analysis.healthScores.allergies)
                healthScoreButton("🛡️", "Anti-Inflam", analysis.healthScores.antiInflammation)
                healthScoreButton("🩸", "Blood Sugar", analysis.healthScores.bloodSugar)
                healthScoreButton("🧠", "Brain", analysis.healthScores.brainHealth)
                healthScoreButton("🧪", "Detox/Liver", analysis.healthScores.detoxLiver)
                healthScoreButton("⚡", "Energy", analysis.healthScores.energy)
                healthScoreButton("👁️", "Vision", analysis.healthScores.eyeHealth)
                healthScoreButton("❤️", "Heart", analysis.healthScores.heartHealth)
                healthScoreButton("🛡️", "Immune", analysis.healthScores.immune)
                healthScoreButton("🦴", "Bones & Joints", analysis.healthScores.jointHealth)
                healthScoreButton("🫘", "Kidneys", analysis.healthScores.kidneys)
                healthScoreButton("😊", "Mood", analysis.healthScores.mood)
                healthScoreButton("✨", "Skin", analysis.healthScores.skin)
                healthScoreButton("😴", "Sleep", analysis.healthScores.sleep)
                healthScoreButton("🧘", "Stress", analysis.healthScores.stress)
                healthScoreButton("⚖️", "Weight", analysis.healthScores.weightManagement)
            }
        }
    }
    
    private func healthScoreButton(_ icon: String, _ label: String, _ score: Int) -> some View {
        Button(action: {
            healthDetailItem = HealthDetailItem(category: label, score: score)
        }) {
            VStack(spacing: 5) {
                Text(icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(score)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(score))
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
        }
    }
}

#Preview {
    MealResultsView(
        analyses: [
            FoodAnalysis(
                foodName: "Sample Meal",
                overallScore: 85,
                summary: "This meal provides excellent health benefits.",
                healthScores: HealthScores(
                    allergies: 75,
                    antiInflammation: 80,
                    bloodSugar: 80,
                    brainHealth: 85,
                    detoxLiver: 85,
                    energy: 90,
                    eyeHealth: 70,
                    heartHealth: 90,
                    immune: 85,
                    jointHealth: 75,
                    kidneys: 75,
                    mood: 80,
                    skin: 80,
                    sleep: 75,
                    stress: 85,
                    weightManagement: 85
                ),
                keyBenefits: ["High in antioxidants", "Supports heart health", "Boosts energy"],
                ingredients: [
                    FoodIngredient(name: "Sample Ingredient", impact: "Positive", explanation: "Good for health")
                ],
                bestPreparation: "Steam or bake",
                servingSize: "1 cup",
                nutritionInfo: NutritionInfo(
                    calories: "150",
                    protein: "8g",
                    carbohydrates: "25g",
                    fat: "3g",
                    sugar: "5g",
                    fiber: "4g",
                    sodium: "200mg"
                ),
                scanType: "meal",
                foodNames: nil,
                suggestions: nil
            )
        ],
        onNewMeal: {}
    )
} 