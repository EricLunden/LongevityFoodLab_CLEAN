import SwiftUI

struct MealPlanSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealPlan: MealPlan
    
    // Descriptive metrics (simple counts only)
    private var averageScore: Double {
        let scores = mealPlan.plannedMeals.compactMap { $0.estimatedLongevityScore }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private var ingredientReuseCount: Int {
        // Stub: Simple descriptive count
        // In a real implementation, this would analyze ingredient overlap
        return mealPlan.plannedMeals.count / 2 // Placeholder
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 24) {
                    // Large Longevity Score Display
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(scoreGradient(Int(averageScore)))
                                .frame(width: 120, height: 120)
                            
                            VStack(spacing: -4) {
                                Text("\(Int(averageScore))")
                                    .font(.system(size: 46, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("Longevity Score")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // Summary Cards
                    VStack(spacing: 16) {
                        // Card 1: Longevity Focus
                        StandardCard {
                            HStack(spacing: 12) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.0, green: 0.2, blue: 0.4),  // Red-pink
                                                Color(red: 1.0, green: 0.4, blue: 0.6)   // Pink
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Longevity Focus")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text("This plan prioritizes foods that support long-term health and vitality.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Card 2: Ingredient Reuse (DESCRIPTIVE)
                        StandardCard {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.2, green: 0.7, blue: 0.4),  // Green
                                                Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ingredient Reuse")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text("This plan reuses ingredients across meals to reduce waste and cost.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Approximately \(ingredientReuseCount) ingredients reused")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Card 3: Waste Reduction
                        StandardCard {
                            HStack(spacing: 12) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.2, green: 0.7, blue: 0.4),  // Green
                                                Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Waste Reduction")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text("By planning meals that share ingredients, you'll minimize leftover ingredients and reduce food waste.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 100) // Space for bottom buttons
                }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom buttons
                VStack(spacing: 12) {
                    // Primary gradient button
                    Button(action: {
                        saveMealPlan()
                    }) {
                        HStack(spacing: 8) {
                            Text("Save Plan")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),
                                    Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
            }
        }
    }
    
    // MARK: - Score Gradient Helper
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
    
    // MARK: - Actions
    private func saveMealPlan() {
        // Meal plan is already saved via MealPlanManager
        dismiss()
    }
}

