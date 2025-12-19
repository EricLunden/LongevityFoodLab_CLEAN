import SwiftUI

struct PetFoodComparisonResultsView: View {
    let food1: PetFoodCacheEntry
    let food2: PetFoodCacheEntry
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                        
                        // Overall Score Comparison
                        overallScoreComparisonSection
                        
                        // Health Scores Comparison
                        healthScoresComparisonSection
                        
                        // Key Benefits Comparison
                        keyBenefitsComparisonSection
                        
                        // Ingredients Comparison
                        ingredientsComparisonSection
                        
                        // Best Practices Comparison
                        bestPracticesComparisonSection
                        
                        // Nutrition Comparison
                        nutritionComparisonSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Pet Food Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        Image("LogoHorizontal")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 37)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.top, -8)
    }
    
    // MARK: - Overall Score Comparison Section
    private var overallScoreComparisonSection: some View {
        VStack(spacing: 16) {
            Text("Overall Score Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Food 1 Score
                VStack(spacing: 12) {
                    Text(food1.petType.emoji)
                        .font(.title)
                    
                    VStack(spacing: 4) {
                        Text(food1.brandName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text(food1.productName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(food1.fullAnalysis.overallScore) / 100.0)
                            .stroke(scoreColor(food1.fullAnalysis.overallScore), lineWidth: 6)
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(food1.fullAnalysis.overallScore)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor(food1.fullAnalysis.overallScore))
                            
                            Text("/100")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(scoreDescription(food1.fullAnalysis.overallScore))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(scoreColor(food1.fullAnalysis.overallScore))
                }
                .frame(maxWidth: .infinity)
                
                // VS Separator
                VStack {
                    Text("VS")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 100)
                }
                
                // Food 2 Score
                VStack(spacing: 12) {
                    Text(food2.petType.emoji)
                        .font(.title)
                    
                    VStack(spacing: 4) {
                        Text(food2.brandName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text(food2.productName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(food2.fullAnalysis.overallScore) / 100.0)
                            .stroke(scoreColor(food2.fullAnalysis.overallScore), lineWidth: 6)
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text("\(food2.fullAnalysis.overallScore)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor(food2.fullAnalysis.overallScore))
                            
                            Text("/100")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(scoreDescription(food2.fullAnalysis.overallScore))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(scoreColor(food2.fullAnalysis.overallScore))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Health Scores Comparison Section
    private var healthScoresComparisonSection: some View {
        VStack(spacing: 16) {
            Text("Health Scores Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                healthScoreComparisonRow("Digestive", food1.fullAnalysis.healthScores.digestiveHealth, food2.fullAnalysis.healthScores.digestiveHealth)
                healthScoreComparisonRow("Coat", food1.fullAnalysis.healthScores.coatHealth, food2.fullAnalysis.healthScores.coatHealth)
                healthScoreComparisonRow("Joint", food1.fullAnalysis.healthScores.jointHealth, food2.fullAnalysis.healthScores.jointHealth)
                healthScoreComparisonRow("Immune", food1.fullAnalysis.healthScores.immuneHealth, food2.fullAnalysis.healthScores.immuneHealth)
                healthScoreComparisonRow("Energy", food1.fullAnalysis.healthScores.energyLevel, food2.fullAnalysis.healthScores.energyLevel)
                healthScoreComparisonRow("Weight", food1.fullAnalysis.healthScores.weightManagement, food2.fullAnalysis.healthScores.weightManagement)
                healthScoreComparisonRow("Dental", food1.fullAnalysis.healthScores.dentalHealth, food2.fullAnalysis.healthScores.dentalHealth)
                healthScoreComparisonRow("Skin", food1.fullAnalysis.healthScores.skinHealth, food2.fullAnalysis.healthScores.skinHealth)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Health Score Comparison Row
    private func healthScoreComparisonRow(_ title: String, _ score1: Int, _ score2: Int) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // Food 1 Score
            HStack(spacing: 8) {
                Text("\(score1)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor(score1))
                
                Rectangle()
                    .fill(scoreColor(score1))
                    .frame(height: 3)
                    .frame(width: CGFloat(score1) / 100.0 * 40)
                    .cornerRadius(2)
            }
            .frame(maxWidth: .infinity)
            
            // VS Separator
            Text("|")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Food 2 Score
            HStack(spacing: 8) {
                Rectangle()
                    .fill(scoreColor(score2))
                    .frame(height: 3)
                    .frame(width: CGFloat(score2) / 100.0 * 40)
                    .cornerRadius(2)
                
                Text("\(score2)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor(score2))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Key Benefits Comparison Section
    private var keyBenefitsComparisonSection: some View {
        VStack(spacing: 16) {
            Text("Key Benefits Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Food 1 Benefits
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(food1.brandName) Benefits")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(food1.fullAnalysis.keyBenefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption2)
                                
                                Text(benefit)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Food 2 Benefits
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(food2.brandName) Benefits")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(food2.fullAnalysis.keyBenefits, id: \.self) { benefit in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption2)
                                
                                Text(benefit)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Ingredients Comparison Section
    private var ingredientsComparisonSection: some View {
        VStack(spacing: 16) {
            Text("Key Ingredients Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Food 1 Ingredients
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(food1.brandName) Ingredients")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 6) {
                        ForEach(food1.fullAnalysis.ingredients.prefix(3), id: \.name) { ingredient in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(ingredient.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text(ingredient.impact)
                                        .font(.caption2)
                                        .foregroundColor(ingredient.isBeneficial ? .green : .red)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(
                                            (ingredient.isBeneficial ? Color.green : Color.red).opacity(0.1)
                                        )
                                        .cornerRadius(4)
                                }
                                
                                Text(ingredient.explanation)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Food 2 Ingredients
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(food2.brandName) Ingredients")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 6) {
                        ForEach(food2.fullAnalysis.ingredients.prefix(3), id: \.name) { ingredient in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(ingredient.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Spacer()
                                    
                                    Text(ingredient.impact)
                                        .font(.caption2)
                                        .foregroundColor(ingredient.isBeneficial ? .green : .red)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(
                                            (ingredient.isBeneficial ? Color.green : Color.red).opacity(0.1)
                                        )
                                        .cornerRadius(4)
                                }
                                
                                Text(ingredient.explanation)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Best Practices Comparison Section
    private var bestPracticesComparisonSection: some View {
        VStack(spacing: 16) {
            Text("Best Practices Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Food 1 Practices
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(food1.brandName) Practices")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 6) {
                        practiceComparisonItem("Portion", food1.fullAnalysis.bestPractices.portionSize)
                        practiceComparisonItem("Frequency", food1.fullAnalysis.bestPractices.frequency)
                        practiceComparisonItem("Special", food1.fullAnalysis.bestPractices.specialConsiderations)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Food 2 Practices
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(food2.brandName) Practices")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 6) {
                        practiceComparisonItem("Portion", food2.fullAnalysis.bestPractices.portionSize)
                        practiceComparisonItem("Frequency", food2.fullAnalysis.bestPractices.frequency)
                        practiceComparisonItem("Special", food2.fullAnalysis.bestPractices.specialConsiderations)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Practice Comparison Item
    private func practiceComparisonItem(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(6)
    }
    
    // MARK: - Nutrition Comparison Section
    private var nutritionComparisonSection: some View {
        VStack(spacing: 16) {
            Text("Nutrition Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                nutritionComparisonRow("Protein", food1.fullAnalysis.nutritionInfo.protein, food2.fullAnalysis.nutritionInfo.protein)
                nutritionComparisonRow("Fat", food1.fullAnalysis.nutritionInfo.fat, food2.fullAnalysis.nutritionInfo.fat)
                nutritionComparisonRow("Carbs", food1.fullAnalysis.nutritionInfo.carbohydrates, food2.fullAnalysis.nutritionInfo.carbohydrates)
                nutritionComparisonRow("Fiber", food1.fullAnalysis.nutritionInfo.fiber, food2.fullAnalysis.nutritionInfo.fiber)
                nutritionComparisonRow("Calories", food1.fullAnalysis.nutritionInfo.calories, food2.fullAnalysis.nutritionInfo.calories)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Nutrition Comparison Row
    private func nutritionComparisonRow(_ title: String, _ value1: String, _ value2: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value1)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
            
            Text("|")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value2)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(6)
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
    
    private func scoreDescription(_ score: Int) -> String {
        switch score {
        case 80...100: return "Excellent"
        case 60...79: return "Good"
        case 40...59: return "Fair"
        default: return "Poor"
        }
    }
}
