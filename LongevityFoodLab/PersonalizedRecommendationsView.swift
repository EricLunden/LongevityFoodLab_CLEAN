import SwiftUI

struct PersonalizedRecommendationsView: View {
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    private let aiService = AIService.shared
    @State private var recommendations: [PersonalizedRecommendation] = []
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedCategory: RecommendationCategory = .foods
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Picker
                categoryPicker
                
                // Content
                if isLoading {
                    loadingView
                } else if recommendations.isEmpty {
                    emptyStateView
                } else {
                    recommendationsList
                }
            }
            .navigationTitle("Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadRecommendations()
            }
            .onChange(of: selectedCategory) {
                loadRecommendations()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(RecommendationCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Generating personalized recommendations...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No recommendations available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Complete your health profile to get personalized recommendations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Update Profile") {
                // Navigate to profile settings
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var recommendationsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(recommendations) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
            .padding()
        }
    }
    
    private func loadRecommendations() {
        guard let profile = healthProfileManager.currentProfile else {
            recommendations = []
            return
        }
        
        isLoading = true
        
        // Simulate API call - in real implementation, this would call the AI service
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            recommendations = generateMockRecommendations(for: selectedCategory, profile: profile)
            isLoading = false
        }
    }
    
    private func generateMockRecommendations(for category: RecommendationCategory, profile: UserHealthProfile) -> [PersonalizedRecommendation] {
        switch category {
        case .foods:
            return generateFoodRecommendations(profile: profile)
        case .recipes:
            return generateRecipeRecommendations(profile: profile)
        case .tips:
            return generateHealthTips(profile: profile)
        case .supplements:
            return generateSupplementRecommendations(profile: profile)
        }
    }
    
    private func generateFoodRecommendations(profile: UserHealthProfile) -> [PersonalizedRecommendation] {
        let foods = [
            PersonalizedRecommendation(
                id: UUID(),
                title: "Salmon",
                subtitle: "Rich in Omega-3 fatty acids",
                description: "Excellent for heart health and brain function. Contains high-quality protein and essential nutrients.",
                category: .foods,
                healthScore: 9.2,
                goalsMet: ["Heart health", "Brain health"],
                imageName: "fish.fill",
                color: .blue
            ),
            PersonalizedRecommendation(
                id: UUID(),
                title: "Blueberries",
                subtitle: "Antioxidant powerhouse",
                description: "Packed with antioxidants that support brain health and may help with memory and cognitive function.",
                category: .foods,
                healthScore: 8.8,
                goalsMet: ["Brain health", "Immune support"],
                imageName: "leaf.fill",
                color: .purple
            ),
            PersonalizedRecommendation(
                id: UUID(),
                title: "Quinoa",
                subtitle: "Complete protein grain",
                description: "A complete protein with all essential amino acids. Great for muscle health and energy.",
                category: .foods,
                healthScore: 8.5,
                goalsMet: ["Bone/muscle health", "Energy"],
                imageName: "grain.fill",
                color: .orange
            )
        ]
        
        return foods
    }
    
    private func generateRecipeRecommendations(profile: UserHealthProfile) -> [PersonalizedRecommendation] {
        let recipes = [
            PersonalizedRecommendation(
                id: UUID(),
                title: "Mediterranean Bowl",
                subtitle: "Heart-healthy combination",
                description: "Quinoa, salmon, avocado, and mixed greens with olive oil dressing. Perfect for your heart health goals.",
                category: .recipes,
                healthScore: 9.0,
                goalsMet: ["Heart health", "Weight management"],
                imageName: "bowl.fill",
                color: .green
            ),
            PersonalizedRecommendation(
                id: UUID(),
                title: "Brain-Boosting Smoothie",
                subtitle: "Blueberry and walnut blend",
                description: "Blueberries, walnuts, spinach, and Greek yogurt. Designed to support cognitive function.",
                category: .recipes,
                healthScore: 8.7,
                goalsMet: ["Brain health", "Energy"],
                imageName: "cup.and.saucer.fill",
                color: .purple
            )
        ]
        
        return recipes
    }
    
    private func generateHealthTips(profile: UserHealthProfile) -> [PersonalizedRecommendation] {
        let tips = [
            PersonalizedRecommendation(
                id: UUID(),
                title: "Hydration Timing",
                subtitle: "Optimize your water intake",
                description: "Drink a glass of water 30 minutes before meals to improve digestion and help with portion control.",
                category: .tips,
                healthScore: 8.0,
                goalsMet: ["Digestive health", "Weight management"],
                imageName: "drop.fill",
                color: .blue
            ),
            PersonalizedRecommendation(
                id: UUID(),
                title: "Meal Timing",
                subtitle: "Eat for better sleep",
                description: "Finish your last meal 3 hours before bedtime to improve sleep quality and digestion.",
                category: .tips,
                healthScore: 7.5,
                goalsMet: ["Sleep quality", "Digestive health"],
                imageName: "moon.fill",
                color: .indigo
            )
        ]
        
        return tips
    }
    
    private func generateSupplementRecommendations(profile: UserHealthProfile) -> [PersonalizedRecommendation] {
        let supplements = [
            PersonalizedRecommendation(
                id: UUID(),
                title: "Omega-3 Supplement",
                subtitle: "Support heart and brain health",
                description: "High-quality fish oil supplement to support cardiovascular health and cognitive function.",
                category: .supplements,
                healthScore: 8.5,
                goalsMet: ["Heart health", "Brain health"],
                imageName: "pills.fill",
                color: .blue
            ),
            PersonalizedRecommendation(
                id: UUID(),
                title: "Vitamin D3",
                subtitle: "Essential for bone health",
                description: "Supports bone density, immune function, and may help with mood regulation.",
                category: .supplements,
                healthScore: 8.0,
                goalsMet: ["Bone/muscle health", "Immune support"],
                imageName: "sun.max.fill",
                color: .yellow
            )
        ]
        
        return supplements
    }
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let category: RecommendationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? 
                    Color.green : 
                    Color(.systemBackground)
                )
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
}

struct RecommendationCard: View {
    let recommendation: PersonalizedRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: recommendation.imageName)
                    .foregroundColor(recommendation.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(recommendation.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Health Score
                VStack {
                    Text(String(format: "%.1f", recommendation.healthScore))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Description
            Text(recommendation.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            // Health Goals
            if !recommendation.goalsMet.isEmpty {
                HStack {
                    Text("Supports:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(recommendation.goalsMet.prefix(2), id: \.self) { goal in
                        Text(goal)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                    
                    if recommendation.goalsMet.count > 2 {
                        Text("+\(recommendation.goalsMet.count - 2)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Data Models

struct PersonalizedRecommendation: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let description: String
    let category: RecommendationCategory
    let healthScore: Double
    let goalsMet: [String]
    let imageName: String
    let color: Color
}

enum RecommendationCategory: CaseIterable {
    case foods
    case recipes
    case tips
    case supplements
    
    var displayName: String {
        switch self {
        case .foods: return "Foods"
        case .recipes: return "Recipes"
        case .tips: return "Tips"
        case .supplements: return "Supplements"
        }
    }
}

#Preview {
    PersonalizedRecommendationsView()
}
