import SwiftUI

struct PetFoodResultsView: View {
    @State var analysis: PetFoodAnalysis
    let isFromCache: Bool
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cacheManager = PetFoodCacheManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    init(analysis: PetFoodAnalysis, isFromCache: Bool = false) {
        print("🔍 PetFoodResultsView: Initializing with analysis for \(analysis.brandName)")
        print("🔍 PetFoodResultsView: Analysis details - PetType: \(analysis.petType), Score: \(analysis.overallScore)")
        print("🔍 PetFoodResultsView: isFromCache: \(isFromCache)")
        self.analysis = analysis
        self.isFromCache = isFromCache
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Safety check - if analysis is invalid, show error
                        if analysis.brandName.isEmpty || analysis.productName.isEmpty {
                            VStack(spacing: 16) {
                                Text("⚠️ Invalid Analysis Data")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                
                                Text("The analysis data appears to be corrupted or incomplete.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Brand: \(analysis.brandName.isEmpty ? "EMPTY" : analysis.brandName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Product: \(analysis.productName.isEmpty ? "EMPTY" : analysis.productName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Pet Type: \(analysis.petType.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Score: \(analysis.overallScore)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                        } else {
                            // Logo Header
                            logoHeaderSection
                            
                            // Large Pet Food Analysis Title
                            Text("Pet Food Analysis")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                                .padding(.bottom, 10)
                            
                            // Header with Score
                            headerSection
                            
                            // Cache Status Banner
                            if isFromCache {
                                cacheStatusBanner
                            }
                            
                            // Health Scores Section
                            healthScoresSection
                            
                            // Key Benefits Section
                            keyBenefitsSection
                            
                            // Ingredients Section
                            ingredientsSection
                            
                            // Fillers and Concerns Section
                            fillersAndConcernsSection
                            
                            // Best Practices Section
                            bestPracticesSection
                            
                            // Nutrition Info Section
                            nutritionInfoSection
                            
                            // Similar Food Suggestions Section
                            similarFoodsSection
                            
                            Spacer(minLength: 100)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
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
    
    // MARK: - Logo Header Section
    private var logoHeaderSection: some View {
        Image("LogoHorizontal")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 37)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.top, -8)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Pet Type and Food Info
            VStack(spacing: 8) {
                Text(analysis.petType.emoji)
                    .font(.system(size: 60))
                
                VStack(spacing: 4) {
                    Text(analysis.brandName)
                        .font(.title)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(analysis.productName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Score Circle (matching human food analysis style)
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 15)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .trim(from: 0, to: max(0, min(1, CGFloat(analysis.overallScore) / 100)))
                    .stroke(
                        scoreColor(analysis.overallScore),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(analysis.overallScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor(analysis.overallScore))
                    
                    Text(scoreDescription(analysis.overallScore))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)
            
            // Summary text under the score circle (matching human food analysis)
            Text(analysis.summary)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(30)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Cache Status Banner
    private var cacheStatusBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Analysis from \(analysis.analysisDate ?? Date(), style: .date)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Tap to refresh for latest data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Refresh") {
                // Refresh functionality can be added here
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.557, blue: 0.498),
                        Color(red: 0.502, green: 0.706, blue: 0.627)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    
    // MARK: - Health Scores Section
    private var healthScoresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Scores")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                healthScoreItem("Digestive", analysis.healthScores.digestiveHealth)
                healthScoreItem("Coat", analysis.healthScores.coatHealth)
                healthScoreItem("Joint", analysis.healthScores.jointHealth)
                healthScoreItem("Immune", analysis.healthScores.immuneHealth)
                healthScoreItem("Energy", analysis.healthScores.energyLevel)
                healthScoreItem("Weight", analysis.healthScores.weightManagement)
                healthScoreItem("Dental", analysis.healthScores.dentalHealth)
                healthScoreItem("Skin", analysis.healthScores.skinHealth)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
    }
    
    // MARK: - Health Score Item
    private func healthScoreItem(_ title: String, _ score: Int) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(score)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(scoreColor(score))
            
            // Mini progress bar
            Rectangle()
                .fill(scoreColor(score))
                .frame(height: 4)
                .frame(width: CGFloat(score) / 100.0 * 60)
                .cornerRadius(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Key Benefits Section
    private var keyBenefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Benefits")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(analysis.keyBenefits, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(benefit)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Ingredients")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(analysis.ingredients, id: \.name) { ingredient in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ingredient.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(ingredient.impact)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ingredient.isBeneficial ? .green : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    (ingredient.isBeneficial ? Color.green : Color.red).opacity(0.1)
                                )
                                .cornerRadius(8)
                        }
                        
                        Text(ingredient.explanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    // MARK: - Fillers and Concerns Section
    private var fillersAndConcernsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fillers and Concerns")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Overall Risk Assessment
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Overall Risk: \(analysis.fillersAndConcerns.overallRisk)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Text(analysis.fillersAndConcerns.recommendations)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            // Fillers Section
            if !analysis.fillersAndConcerns.fillers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fillers Found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(analysis.fillersAndConcerns.fillers, id: \.name) { filler in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(filler.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text(filler.isConcerning ? "Concerning" : "Acceptable")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(filler.isConcerning ? .red : .green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        (filler.isConcerning ? Color.red : Color.green).opacity(0.1)
                                    )
                                    .cornerRadius(8)
                            }
                            
                            Text(filler.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Why used: \(filler.whyUsed)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Impact: \(filler.impact)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            
            // Potential Concerns Section
            if !analysis.fillersAndConcerns.potentialConcerns.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Potential Concerns")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ForEach(analysis.fillersAndConcerns.potentialConcerns, id: \.ingredient) { concern in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(concern.ingredient)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Text(concern.severity)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            Text(concern.concern)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Text(concern.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Alternatives: \(concern.alternatives)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
    }
    
    // MARK: - Best Practices Section
    private var bestPracticesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Best Practices")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                practiceItem("Feeding Guidelines", analysis.bestPractices.feedingGuidelines)
                practiceItem("Portion Size", analysis.bestPractices.portionSize)
                practiceItem("Frequency", analysis.bestPractices.frequency)
                practiceItem("Special Considerations", analysis.bestPractices.specialConsiderations)
                practiceItem("Transition Tips", analysis.bestPractices.transitionTips)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
    }
    
    // MARK: - Practice Item
    private func practiceItem(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Nutrition Info Section
    private var nutritionInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                nutritionItem("Protein", analysis.nutritionInfo.protein)
                nutritionItem("Fat", analysis.nutritionInfo.fat)
                nutritionItem("Carbs", analysis.nutritionInfo.carbohydrates)
                nutritionItem("Fiber", analysis.nutritionInfo.fiber)
                nutritionItem("Moisture", analysis.nutritionInfo.moisture)
                nutritionItem("Calories", analysis.nutritionInfo.calories)
                nutritionItem("Omega-3", analysis.nutritionInfo.omega3)
                nutritionItem("Omega-6", analysis.nutritionInfo.omega6)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
    }
    
    // MARK: - Nutrition Item
    private func nutritionItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Similar Foods Section
    private var similarFoodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🐾 Similar Foods with Higher Scores")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let suggestions = analysis.suggestions, !suggestions.isEmpty {
                VStack(spacing: 12) {
                    ForEach(suggestions, id: \.brandName) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("Finding similar pet foods...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                    
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .onAppear {
            if analysis.suggestions == nil {
                loadSimilarFoods()
            }
        }
    }
    
    // MARK: - Suggestion Card
    private func suggestionCard(_ suggestion: PetFoodSuggestion) -> some View {
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
                .background(scoreColor(suggestion.score))
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
    
    // MARK: - Load Similar Foods
    private func loadSimilarFoods() {
        AIService.shared.findSimilarPetFoods(
            currentFood: "\(analysis.brandName) \(analysis.productName)",
            currentScore: analysis.overallScore,
            petType: analysis.petType
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let suggestions):
                    // Create a new analysis with suggestions
                    let updatedAnalysis = PetFoodAnalysis(
                        petType: self.analysis.petType,
                        brandName: self.analysis.brandName,
                        productName: self.analysis.productName,
                        overallScore: self.analysis.overallScore,
                        summary: self.analysis.summary,
                        healthScores: self.analysis.healthScores,
                        keyBenefits: self.analysis.keyBenefits,
                        ingredients: self.analysis.ingredients,
                        fillersAndConcerns: self.analysis.fillersAndConcerns,
                        bestPractices: self.analysis.bestPractices,
                        nutritionInfo: self.analysis.nutritionInfo,
                        analysisDate: self.analysis.analysisDate,
                        cacheKey: self.analysis.cacheKey,
                        cacheVersion: self.analysis.cacheVersion,
                        suggestions: suggestions
                    )
                    self.analysis = updatedAnalysis
                    print("Loaded \(suggestions.count) similar food suggestions")
                case .failure(let error):
                    print("Failed to load similar foods: \(error)")
                }
            }
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
    
    private func scoreDescription(_ score: Int) -> String {
        switch score {
        case 80...100: return "Excellent"
        case 60...79: return "Good"
        case 40...59: return "Fair"
        default: return "Poor"
        }
    }
}
