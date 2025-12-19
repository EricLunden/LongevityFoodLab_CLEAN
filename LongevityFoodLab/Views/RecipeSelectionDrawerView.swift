import SwiftUI

struct RecipeSelectionDrawerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var spoonacularService = SpoonacularService.shared
    
    let mealType: MealType
    let scheduledDate: Date
    let preferences: Set<String>?
    let healthGoals: Set<String>?
    let onRecipeSelected: (Recipe) -> Void
    
    init(
        mealType: MealType,
        scheduledDate: Date,
        preferences: Set<String>? = nil,
        healthGoals: Set<String>? = nil,
        onRecipeSelected: @escaping (Recipe) -> Void
    ) {
        self.mealType = mealType
        self.scheduledDate = scheduledDate
        self.preferences = preferences
        self.healthGoals = healthGoals
        self.onRecipeSelected = onRecipeSelected
    }
    
    @State private var savedRecipes: [Recipe] = []
    @State private var suggestedRecipes: [Recipe] = []
    @State private var isLoadingSuggestions = false
    @State private var showingSuggestions = false
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 20) {
                    // Section 1: Your Saved Recipes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Saved Recipes")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        if savedRecipes.isEmpty {
                            Text("No saved recipes found")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(savedRecipes, id: \.id) { recipe in
                                    recipeCard(recipe: recipe, isSuggested: false)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Section 2: Suggested for This Plan (only if needed)
                    if showingSuggestions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested for This Plan")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                            
                            if isLoadingSuggestions {
                                ProgressView()
                                    .padding(.horizontal, 20)
                            } else if suggestedRecipes.isEmpty {
                                Text("No suggestions available")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(suggestedRecipes, id: \.id) { recipe in
                                        recipeCard(recipe: recipe, isSuggested: true)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                }
            }
            .navigationTitle("Select Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            Task {
                // Load recipes from disk first
                await recipeManager.loadRecipes()
                // Then filter and display them
                loadSavedRecipes()
                checkIfSuggestionsNeeded()
            }
        }
    }
    
    // MARK: - Recipe Card (List Card style)
    private func recipeCard(recipe: Recipe, isSuggested: Bool) -> some View {
        Button(action: {
            onRecipeSelected(recipe)
            dismiss()
        }) {
            HStack(spacing: 12) {
                // Recipe image (60x60)
                Group {
                    if let imageURL = recipe.image, !imageURL.isEmpty {
                        AsyncImage(url: URL(string: imageURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                    } else if !recipe.photos.isEmpty {
                        // Use first photo if available
                        Image(recipe.photos[0])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                // Title and info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if recipe.prepTime > 0 {
                            Text("\(recipe.prepTime) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if isSuggested {
                            Text("Suggested recipe")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // LFI score badge (if available)
                // Using effective LFI (full or fast-pass) to display Spoonacular recipe scores
                if let score = recipe.longevityScore ?? recipe.estimatedLongevityScore {
                    VStack(spacing: 2) {
                        Text("\(score)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Score")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(width: 60, height: 60)
                    .background(scoreColor(score))
                    .cornerRadius(30)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(colorScheme == .dark ? Color.black : Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Score Color Helper
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
        }
    }
    
    // MARK: - Data Loading
    private func loadSavedRecipes() {
        // Filter recipes by meal type using silent classification (mealTypeHints)
        // Falls back to categories if hints not available
        
        savedRecipes = recipeManager.recipes.filter { recipe in
            // MARK: - Meal Type Filtering (Using Silent Classification)
            // Ensure recipe has meal type hints (classify lazily if needed)
            var recipeWithHints = recipe
            if recipeWithHints.mealTypeHints == nil {
                recipeWithHints.mealTypeHints = LFIEngine.classifyMealTypes(recipe: recipeWithHints)
            }
            
            // Check if recipe's mealTypeHints contain the selected meal type
            let recipeMealTypes = Set(recipeWithHints.mealTypeHints ?? [])
            let matchesMealTypeHint = recipeMealTypes.contains(mealType)
            
            // Fallback: Check categories if mealTypeHints don't match
            let mealTypeCategory: RecipeCategory? = {
                switch mealType {
                case .breakfast: return .breakfast
                case .lunch: return .lunch
                case .dinner: return .dinner
                case .snack: return .snack
                case .dessert: return .dessert
                }
            }()
            
            var matchesMealTypeCategory = true
            if let category = mealTypeCategory {
                matchesMealTypeCategory = recipe.categories.contains(category) || 
                                         recipe.categories.contains(.main) || 
                                         recipe.categories.contains(.soup) || 
                                         recipe.categories.contains(.salad)
            }
            
            // Include if matches mealTypeHints OR matches category (fallback)
            let matchesMealType = matchesMealTypeHint || matchesMealTypeCategory
            
            // Filter by dietary preferences if provided
            var matchesPreferences = true
            if let prefs = preferences, !prefs.isEmpty {
                matchesPreferences = matchesDietaryPreferences(recipe: recipe, preferences: prefs)
            }
            
            // Filter by health goals if provided
            var matchesGoals = true
            if let goals = healthGoals, !goals.isEmpty {
                matchesGoals = matchesHealthGoals(recipe: recipe, goals: goals)
            }
            
            return matchesMealType && matchesPreferences && matchesGoals
        }
    }
    
    // MARK: - Filtering Helpers
    private func matchesDietaryPreferences(recipe: Recipe, preferences: Set<String>) -> Bool {
        // Check if recipe categories match any selected dietary preference
        for pref in preferences {
            let prefLower = pref.lowercased()
            
            // Map preference strings to RecipeCategory
            if prefLower.contains("vegan") && recipe.categories.contains(.vegan) {
                return true
            }
            if prefLower.contains("vegetarian") && recipe.categories.contains(.vegetarian) {
                return true
            }
            if prefLower.contains("keto") && recipe.categories.contains(.keto) {
                return true
            }
            if prefLower.contains("paleo") && recipe.categories.contains(.paleo) {
                return true
            }
            if prefLower.contains("mediterranean") && recipe.categories.contains(.mediterranean) {
                return true
            }
            if prefLower.contains("classic") || prefLower.contains("everything") {
                // Classic accepts all recipes
                return true
            }
            // Add more preference mappings as needed
        }
        
        // If no specific matches, return true (don't filter out)
        // This allows recipes without specific dietary categories to show
        return true
    }
    
    private func matchesHealthGoals(recipe: Recipe, goals: Set<String>) -> Bool {
        // For v1, we check if recipe has a longevity score
        // Higher scores are more likely to match health goals
        // This is a simple heuristic - in future, could analyze recipe ingredients
        
        // PART 2: Score filtering rule - use effective score or assign provisional score
        // longevityScore → use if present
        // else estimatedLongevityScore → use if present
        // else → assign a neutral provisional score (e.g. 50)
        // A recipe with missing score MUST NOT be rejected. Empty is worse than imperfect.
        let effectiveLongevityScore: Int = {
            if let score = recipe.longevityScore {
                return score
            } else if let score = recipe.estimatedLongevityScore {
                return score
            } else {
                // Assign neutral provisional score - recipe must not be rejected
                return 50
            }
        }()
        
        // Recipes with scores >= 60 are more likely to match health goals
        return effectiveLongevityScore >= 60
    }
    
    private func checkIfSuggestionsNeeded() {
        // Show suggested recipes ONLY if user has fewer than 3 saved recipes matching meal type
        if savedRecipes.count < 3 {
            showingSuggestions = true
            loadSuggestedRecipes()
        } else {
            showingSuggestions = false
        }
    }
    
    private func loadSuggestedRecipes() {
        isLoadingSuggestions = true
        
        // COMMENT: Recipe source priority:
        // 1. User saved recipes (already loaded)
        // 2. Cached recipes from Supabase (conceptual - check recipes_cache table by source URL)
        // 3. Spoonacular fallback (search with filters, convert to Recipe format)
        // 4. Once a Spoonacular recipe is used, cache it to Supabase for future use
        
        // COMMENT: Ingredient overlap logic:
        // - Compare ingredients from already-planned meals
        // - Prioritize recipes with overlapping ingredients
        // - Avoid one-off ingredients when building plans
        // - Group ingredients by base name (e.g., "chicken breast" and "chicken thighs" count as overlap)
        
        // COMMENT: Favor higher longevity scores when suggesting recipes
        
        Task {
            do {
                // Convert meal type to Spoonacular type parameter
                let spoonacularType: String = {
                    switch mealType {
                    case .breakfast: return "breakfast"
                    case .lunch: return "lunch"
                    case .dinner: return "dinner"
                    case .snack: return "snack"
                    case .dessert: return "dessert"
                    }
                }()
                
                // Search Spoonacular for recipes matching meal type
                let searchResponse = try await spoonacularService.searchRecipes(
                    query: "",
                    type: spoonacularType,
                    number: 5
                )
                
                // Convert Spoonacular recipes to app's Recipe format
                // PART 3: Handle invalid recipes by discarding them
                var convertedRecipes: [Recipe] = []
                for spoonacularRecipe in searchResponse.results {
                    do {
                        let recipe = try spoonacularService.convertToRecipe(spoonacularRecipe)
                        convertedRecipes.append(recipe)
                    } catch {
                        print("⚠️ Failed to convert recipe \(spoonacularRecipe.id): \(error)")
                        // Discard invalid recipe and continue
                        // Discard recipe on other errors too
                    }
                }
                
                await MainActor.run {
                    suggestedRecipes = convertedRecipes
                    isLoadingSuggestions = false
                }
                
                // COMMENT: Once a Spoonacular recipe is selected, it should be cached to Supabase
                // This would involve saving to recipes_cache table with tier_used: "spoonacular"
                // Future searches check Supabase cache before calling Spoonacular API
                
            } catch {
                print("⚠️ RecipeSelectionDrawerView: Failed to load suggestions: \(error)")
                await MainActor.run {
                    isLoadingSuggestions = false
                }
            }
        }
    }
}

