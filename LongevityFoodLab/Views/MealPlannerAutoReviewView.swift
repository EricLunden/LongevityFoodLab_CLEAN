import SwiftUI
import Foundation

struct MealPlannerAutoReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealPlan: MealPlan
    let preferences: Set<String>?
    let healthGoals: Set<String>?
    let longevityScoreFilter: Int
    
    // Local in-memory copy of meal plan for swipe replacements (only persisted on approval)
    @State private var localMealPlan: MealPlan
    @State private var showingCalendar = false
    @State private var selectedRecipe: Recipe? = nil
    @State private var recipesLoaded = false
    @State private var isEditMode = false // Edit mode for swipe-to-replace
    @State private var showingEditInstructions = false // Popup for edit mode instructions
    @State private var refreshID = UUID() // Force UI refresh when plan changes
    @StateObject private var mealPlanManager = MealPlanManager.shared
    @StateObject private var recipeManager = RecipeManager.shared
    private let spoonacularService = SpoonacularService.shared
    
    init(mealPlan: MealPlan, preferences: Set<String>? = nil, healthGoals: Set<String>? = nil, longevityScoreFilter: Int = 0) {
        self.mealPlan = mealPlan
        self.preferences = preferences
        self.healthGoals = healthGoals
        self.longevityScoreFilter = longevityScoreFilter
        // Initialize local copy for in-memory modifications
        self._localMealPlan = State(initialValue: mealPlan)
    }
    
    private var startDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: mealPlan.startDate)
    }
    
    // Group meals by day (use localMealPlan for swipe replacements)
    private var mealsByDay: [Date: [PlannedMeal]] {
        let calendar = Calendar.current
        return Dictionary(grouping: localMealPlan.plannedMeals) { meal in
            calendar.startOfDay(for: meal.scheduledDate)
        }
    }
    
    private var sortedDays: [Date] {
        mealsByDay.keys.sorted()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Title section (fixed at top)
                    VStack(spacing: 8) {
                        Text("Review Your Meal Plan")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Week starting \(startDateFormatted)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    
                    // List for meals (enables swipeActions)
                    if localMealPlan.plannedMeals.isEmpty {
                        VStack(spacing: 12) {
                            Text("No meals found")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Text("Try adjusting your preferences or add meals manually")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        if recipesLoaded {
                            List {
                                ForEach(sortedDays, id: \.self) { date in
                                    Section {
                                        ForEach(mealsByDay[date]?.sorted(by: { $0.scheduledDate < $1.scheduledDate }) ?? [], id: \.id) { meal in
                                            recipeCard(meal: meal)
                                                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                                                .listRowBackground(Color.clear)
                                        }
                                    } header: {
                                        dayHeader(date: date)
                                    }
                                }
                            }
                            .id(refreshID) // Force refresh when plan changes
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                        } else {
                            // Show loading state while recipes are being loaded
                            ProgressView()
                                .padding(.top, 40)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    
                    Spacer()
                        .frame(height: 100) // Space for bottom buttons
                }
                
                // Bottom buttons
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Primary: Approve & Add to Calendar
                        // CRITICAL: Only save plan to MealPlanManager when approved
                        Button(action: {
                            // Activate this plan (use localMealPlan which includes any swipe replacements)
                            var approvedPlan = localMealPlan
                            approvedPlan.isActive = true
                            
                            // Deactivate all other plans
                            for var plan in mealPlanManager.mealPlans {
                                if plan.id != approvedPlan.id {
                                    plan.isActive = false
                                    mealPlanManager.updateMealPlan(plan)
                                }
                            }
                            
                            // Check if plan already exists in manager (shouldn't, but handle it)
                            if let existingIndex = mealPlanManager.mealPlans.firstIndex(where: { $0.id == approvedPlan.id }) {
                                // Update existing plan
                                mealPlanManager.mealPlans[existingIndex] = approvedPlan
                            } else {
                                // Add new plan to manager (first time saving)
                                mealPlanManager.mealPlans.append(approvedPlan)
                            }
                            
                            // Save to disk
                            mealPlanManager.saveMealPlans()
                            print("✅ Approved and saved meal plan '\(approvedPlan.id)' with \(approvedPlan.plannedMeals.count) meals")
                            
                            // Navigate to calendar view with the approved plan
                            showingCalendar = true
                        }) {
                            HStack(spacing: 8) {
                                Text("Approve & Add to Calendar")
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if isEditMode {
                            // Done: exit edit mode
                            isEditMode = false
                        } else {
                            // Edit: show instructions popup first
                            showingEditInstructions = true
                        }
                    }) {
                        Text(isEditMode ? "Done" : "Edit")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            Task {
                // Check if recipes are already loaded (they should be after auto plan generation)
                let planRecipeIDs = Set(localMealPlan.plannedMeals.compactMap { $0.recipeID })
                let availableRecipeIDs = Set(recipeManager.recipes.map { $0.id })
                let missingRecipes = planRecipeIDs.subtracting(availableRecipeIDs)
                
                // Only reload if we're missing recipes for this plan
                if !missingRecipes.isEmpty {
                    print("⚠️ MealPlannerAutoReviewView: Missing \(missingRecipes.count) recipes, reloading...")
                    print("   Missing IDs: \(missingRecipes)")
                    await recipeManager.loadRecipes()
                    
                    // Check again after reload
                    let updatedAvailableIDs = Set(recipeManager.recipes.map { $0.id })
                    let stillMissing = planRecipeIDs.subtracting(updatedAvailableIDs)
                    if !stillMissing.isEmpty {
                        print("⚠️ MealPlannerAutoReviewView: Still missing recipes after reload: \(stillMissing)")
                    } else {
                        print("✅ MealPlannerAutoReviewView: All recipes loaded successfully")
                    }
                } else {
                    print("✅ MealPlannerAutoReviewView: All recipes already available")
                }
                
                await MainActor.run {
                    recipesLoaded = true
                }
            }
        }
        .onChange(of: recipeManager.recipes) { _ in
            // Update when recipes change (e.g., after async save completes)
            // This ensures images appear even if recipes are loaded after view appears
            recipesLoaded = true
        }
        .onDisappear {
            // If user dismissed without approving, delete the unapproved plan
            // Plans should only be persisted when "Approve & Add to Calendar" is tapped
            // Check if we're navigating to calendar (approved) or going back (dismissed)
            if !showingCalendar {
                // User went back without approving - remove the plan from manager if it exists
                // This handles edge cases where plan might have been added before our fix
                if let existingPlan = mealPlanManager.mealPlans.first(where: { $0.id == mealPlan.id }) {
                    // Only delete if it's not active (not approved)
                    if !existingPlan.isActive {
                        mealPlanManager.deleteMealPlan(existingPlan)
                        print("🗑️ Deleted unapproved meal plan '\(mealPlan.id)'")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCalendar) {
            MealPlannerCalendarView(
                isAutoMode: true,
                preferences: preferences,
                healthGoals: healthGoals,
                existingMealPlan: localMealPlan
            )
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .alert("Edit Your Meal Plan", isPresented: $showingEditInstructions) {
            Button("Continue") {
                // Activate edit mode after user confirms
                isEditMode = true
            }
            Button("Cancel", role: .cancel) {
                // Do nothing, stay in view mode
            }
        } message: {
            Text("Swipe left on any meal to see another option.")
        }
    }
    
    // MARK: - Meal List Content (for List with swipeActions support)
    private var mealListContent: some View {
        List {
            ForEach(sortedDays, id: \.self) { date in
                Section {
                    let mealsForDay = mealsByDay[date]?.sorted(by: { $0.scheduledDate < $1.scheduledDate }) ?? []
                    ForEach(mealsForDay, id: \.id) { meal in
                        recipeCard(meal: meal)
                            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    dayHeader(date: date)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
    }
    
    // MARK: - Day Header (for List sections)
    private func dayHeader(date: Date) -> some View {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        
        return Text(dateFormatter.string(from: date))
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
    
    // MARK: - Recipe Card with Swipe-to-Replace
    private func recipeCard(meal: PlannedMeal) -> some View {
        // Look up the recipe by ID first
        var recipe = meal.recipeID.flatMap { id in
            recipeManager.recipes.first { $0.id == id }
        }
        
        // Fallback: If recipe not found by ID (e.g., due to UUID mismatch from deduplication),
        // try to find by normalized title
        if recipe == nil {
            let normalizedMealTitle = meal.displayTitle.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            recipe = recipeManager.recipes.first { recipe in
                let normalizedRecipeTitle = recipe.title.lowercased()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                return normalizedRecipeTitle == normalizedMealTitle
            }
            
            if recipe != nil {
                print("✅ Found recipe by title fallback: '\(meal.displayTitle)'")
            }
        }
        
        // Debug: Log if recipe still not found
        if let recipeID = meal.recipeID, recipe == nil {
            print("⚠️ MealPlannerAutoReviewView: Recipe not found for ID: \(recipeID), title: \(meal.displayTitle)")
        }
        
        return Button(action: {
            // Only show recipe detail if NOT in edit mode
            // In edit mode, tapping does nothing (swipe is used for replacement)
            if !isEditMode {
                if let recipe = recipe {
                    selectedRecipe = recipe
                } else {
                    print("⚠️ Cannot open recipe - recipe not found for meal: \(meal.displayTitle)")
                }
            }
        }) {
            HStack(spacing: 12) {
            // Recipe Image (60x60) - use actual recipe image if available
            Group {
                if let recipe = recipe {
                    // Use recipe image URL if available
                    if let imageUrl = recipe.image, !imageUrl.isEmpty {
                        let fixedImageUrl = imageUrl.hasPrefix("//") ? "https:" + imageUrl : imageUrl
                        
                        CachedRecipeImageView(
                            urlString: fixedImageUrl,
                            placeholder: AnyView(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.secondary)
                                    )
                            )
                        )
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .clipped()
                    } else if !recipe.photos.isEmpty {
                        // Check if photos[0] is a URL (from Spoonacular) or a local filename
                        let firstPhoto = recipe.photos[0]
                        if firstPhoto.hasPrefix("http://") || firstPhoto.hasPrefix("https://") || firstPhoto.hasPrefix("//") {
                            // It's a URL - use CachedRecipeImageView (for Spoonacular recipes)
                            let fixedImageUrl = firstPhoto.hasPrefix("//") ? "https:" + firstPhoto : firstPhoto
                            
                            CachedRecipeImageView(
                                urlString: fixedImageUrl,
                                placeholder: AnyView(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.secondary)
                                        )
                                )
                            )
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .clipped()
                        } else {
                            // It's a local filename - use Image
                            Image(firstPhoto)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()
                        }
                    } else {
                        // Placeholder if no image
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                } else {
                    // Placeholder if recipe not found
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        )
                }
            }
            
            // Title and meal type
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(meal.mealType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Score badge - matching horizontal recipe cards on score screen
            if let score = meal.estimatedLongevityScore {
                Circle()
                    .fill(scoreGradient(Int(score)))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text("\(Int(score))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Swipe left on meal card to replace with alternative recipe
            // Always show swipe action button, but only functional when in edit mode
            Button(action: {
                print("🔘 Swipe action button tapped for meal: \(meal.displayTitle), isEditMode: \(isEditMode)")
                // Only replace if in edit mode
                if isEditMode {
                    replaceMeal(meal: meal)
                } else {
                    print("⚠️ Swipe action triggered but edit mode is OFF - user needs to tap Edit button first")
                }
            }) {
                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
            }
            .tint(isEditMode ? .blue : .gray) // Visual indicator: blue when active, gray when inactive
        }
    }
    
    // MARK: - Swipe Replacement Logic
    /// Replace a single meal with an alternative recipe
    /// Keeps same meal slot (day + meal type), excludes current recipe, respects filters
    private func replaceMeal(meal: PlannedMeal) {
        print("🔄 Attempting to replace meal: \(meal.displayTitle) (ID: \(meal.id), RecipeID: \(meal.recipeID?.uuidString ?? "nil"))")
        print("   Current plan has \(localMealPlan.plannedMeals.count) meals")
        print("   RecipeManager has \(recipeManager.recipes.count) recipes")
        
        // Debug: Check recipe types
        let userRecipes = recipeManager.recipes.filter { $0.isOriginal }
        let spoonacularRecipes = recipeManager.recipes.filter { !$0.isOriginal }
        print("   User recipes: \(userRecipes.count), Spoonacular recipes: \(spoonacularRecipes.count)")
        
        // Get eligible replacement recipes from RecipeManager first
        var eligibleRecipes = getEligibleReplacementRecipes(for: meal)
        
        // Debug: Check what types of recipes are eligible
        let eligibleUserRecipes = eligibleRecipes.filter { $0.isOriginal }
        let eligibleSpoonacularRecipes = eligibleRecipes.filter { !$0.isOriginal }
        print("   Eligible user recipes: \(eligibleUserRecipes.count), Eligible Spoonacular: \(eligibleSpoonacularRecipes.count)")
        
        // If no alternatives exist, try Spoonacular fallback
        if eligibleRecipes.isEmpty {
            print("⚠️ No eligible replacement recipes found in RecipeManager, trying Spoonacular fallback...")
            Task {
                do {
                    let spoonacularRecipes = try await fetchSpoonacularReplacementRecipes(for: meal)
                    
                    // Filter Spoonacular recipes using lenient criteria (same as getEligibleReplacementRecipes)
                    let filteredSpoonacular = spoonacularRecipes.filter { recipe in
                        // Check meal type (STRICT - must match)
                        let recipeMealTypes = Set(recipe.mealTypeHints ?? [])
                        let categoryMatchesMealType: Bool = {
                            switch meal.mealType {
                            case .breakfast: return recipe.categories.contains(.breakfast)
                            case .lunch: return recipe.categories.contains(.lunch) || recipe.categories.contains(.salad) || recipe.categories.contains(.soup)
                            case .dinner: return recipe.categories.contains(.dinner) || recipe.categories.contains(.main)
                            case .snack: return recipe.categories.contains(.snack)
                            case .dessert: return recipe.categories.contains(.dessert)
                            }
                        }()
                        guard recipeMealTypes.contains(meal.mealType) || categoryMatchesMealType else { return false }
                        
                        // Check dietary preferences (STRICT - must match)
                        if let prefs = preferences, !prefs.isEmpty {
                            if !matchesDietaryPreferences(recipe: recipe, preferences: prefs) {
                                return false
                            }
                        }
                        
                        // For replacements, be more lenient with health goals
                        // If health goals are set, check if recipe meets at least ONE goal OR has decent score
                        if let goals = healthGoals, !goals.isEmpty {
                            let effectiveScore = recipe.longevityScore ?? recipe.estimatedLongevityScore ?? 50
                            
                            // Apply longevity score filter if set (but be more lenient - allow 10 points below)
                            if longevityScoreFilter > 0 {
                                let relaxedThreshold = max(50, longevityScoreFilter - 10) // Allow 10 points below filter
                                if effectiveScore < relaxedThreshold {
                                    return false
                                }
                            } else {
                                // No score filter, but check if recipe meets at least one health goal
                                // OR has a decent score (>= 50)
                                let meetsAtLeastOneGoal = matchesHealthGoals(recipe: recipe, goals: goals)
                                if !meetsAtLeastOneGoal && effectiveScore < 50 {
                                    return false
                                }
                            }
                        }
                        
                        return true
                    }
                    
                    if !filteredSpoonacular.isEmpty {
                        // Save Spoonacular recipes to RecipeManager (with deduplication)
                        for recipe in filteredSpoonacular {
                            do {
                                try await recipeManager.saveRecipe(recipe)
                            } catch {
                                print("⚠️ Failed to save Spoonacular recipe \(recipe.title): \(error)")
                                // Continue with other recipes even if one fails
                            }
                        }
                        
                        print("✅ Found \(filteredSpoonacular.count) Spoonacular replacement recipes")
                        
                        // Select a random alternative and apply replacement on main actor
                        await MainActor.run {
                            let replacementRecipe = filteredSpoonacular.randomElement() ?? filteredSpoonacular[0]
                            applyReplacement(meal: meal, replacementRecipe: replacementRecipe)
                        }
                    } else {
                        print("⚠️ Spoonacular fallback returned recipes but none passed filters")
                    }
                } catch {
                    print("❌ Spoonacular fallback failed: \(error)")
                }
            }
            return // Exit early, replacement will happen in Task
        }
        
        // Select a random alternative (or first one)
        let replacementRecipe = eligibleRecipes.randomElement() ?? eligibleRecipes[0]
        applyReplacement(meal: meal, replacementRecipe: replacementRecipe)
    }
    
    /// Apply the replacement to the meal plan
    private func applyReplacement(meal: PlannedMeal, replacementRecipe: Recipe) {
        // Create new PlannedMeal with replacement recipe
        let replacementMeal = PlannedMeal(
            id: meal.id, // Keep same ID to replace in place
            recipeID: replacementRecipe.id,
            mealType: meal.mealType,
            scheduledDate: meal.scheduledDate,
            displayTitle: replacementRecipe.title,
            estimatedLongevityScore: Double(replacementRecipe.longevityScore ?? replacementRecipe.estimatedLongevityScore ?? 0)
        )
        
        // Update local meal plan (in-memory only, not persisted until approval)
        // Since MealPlan is a struct, we need to create a new instance to trigger SwiftUI updates
        if let mealIndex = localMealPlan.plannedMeals.firstIndex(where: { $0.id == meal.id }) {
            var updatedMeals = localMealPlan.plannedMeals
            updatedMeals[mealIndex] = replacementMeal
            
            // Create new MealPlan instance with updated meals to trigger SwiftUI change detection
            localMealPlan = MealPlan(
                id: localMealPlan.id, // Keep same ID
                startDate: localMealPlan.startDate,
                endDate: localMealPlan.endDate,
                plannedMeals: updatedMeals,
                createdAt: localMealPlan.createdAt,
                isActive: localMealPlan.isActive
            )
            
            // Force UI refresh by updating refreshID
            refreshID = UUID()
            
            print("✅ Replaced meal '\(meal.displayTitle)' with '\(replacementRecipe.title)'")
            print("   Updated plan now has \(localMealPlan.plannedMeals.count) meals")
        } else {
            print("⚠️ Could not find meal to replace in plan")
        }
    }
    
    /// Fetch Spoonacular recipes for replacement (fallback when no user recipes available)
    private func fetchSpoonacularReplacementRecipes(for meal: PlannedMeal) async throws -> [Recipe] {
        // Convert meal type to Spoonacular type parameter
        let spoonacularType: String = {
            switch meal.mealType {
            case .breakfast: return "breakfast"
            case .lunch: return "lunch"
            case .dinner: return "dinner"
            case .snack: return "snack"
            case .dessert: return "dessert"
            }
        }()
        
        // Convert dietary preferences to Spoonacular diet parameter
        let spoonacularDiet: String? = {
            guard let prefs = preferences else { return nil }
            for pref in prefs {
                let prefLower = pref.lowercased()
                if prefLower.contains("vegan") {
                    return "vegan"
                } else if prefLower.contains("vegetarian") {
                    return "vegetarian"
                } else if prefLower.contains("keto") {
                    return "ketogenic"
                } else if prefLower.contains("paleo") {
                    return "paleo"
                } else if prefLower.contains("mediterranean") {
                    return "mediterranean"
                }
            }
            return nil
        }()
        
        print("🍽️ Fetching Spoonacular replacement recipes (type: \(spoonacularType), diet: \(spoonacularDiet ?? "none"))")
        
        let searchResponse = try await spoonacularService.searchRecipes(
            query: "",
            diet: spoonacularDiet,
            type: spoonacularType,
            number: 10,
            offset: 0
        )
        
        // Convert and filter Spoonacular recipes
        // For replacement, we need to fetch full recipe details to get instructions
        // But that's too slow, so we'll use a workaround: fetch details for a few recipes
        var convertedRecipes: [Recipe] = []
        
        // Try to convert recipes from search results first (fast but may lack instructions)
        for spoonacularRecipe in searchResponse.results.prefix(5) {
            do {
                // Try to get full recipe details for instructions
                let fullRecipe = try await spoonacularService.getRecipeDetails(id: spoonacularRecipe.id)
                let recipe = try spoonacularService.convertToRecipe(fullRecipe)
                
                // Exclude recipes already in plan
                let usedRecipeIDs = Set(localMealPlan.plannedMeals.compactMap { $0.recipeID })
                if usedRecipeIDs.contains(recipe.id) {
                    continue
                }
                
                // Exclude current recipe
                if let currentRecipeID = meal.recipeID, recipe.id == currentRecipeID {
                    continue
                }
                
                convertedRecipes.append(recipe)
            } catch {
                print("⚠️ Failed to convert recipe \(spoonacularRecipe.id): \(error)")
                continue
            }
        }
        
        print("✅ Converted \(convertedRecipes.count) Spoonacular recipes for replacement")
        return convertedRecipes
    }
    
    /// Get eligible replacement recipes for a meal slot
    /// Filters by meal type, excludes current recipe AND all recipes already in the plan
    /// For replacements, we're more lenient: match meal type + dietary preference, but allow some flexibility on health goals
    private func getEligibleReplacementRecipes(for meal: PlannedMeal) -> [Recipe] {
        // Helper function to normalize recipe title for comparison
        func normalizeTitle(_ title: String) -> String {
            return title.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }
        
        // Get all recipe IDs and titles already used in the current plan
        // EXCLUDE the current meal being replaced from the "used" list so we can swap it
        let usedRecipeIDs = Set(localMealPlan.plannedMeals
            .filter { $0.id != meal.id } // Exclude current meal from used list
            .compactMap { $0.recipeID })
        let usedRecipeTitles = Set(localMealPlan.plannedMeals
            .filter { $0.id != meal.id } // Exclude current meal from used list
            .map { normalizeTitle($0.displayTitle) })
        
        // Ensure recipes are loaded
        guard !recipeManager.recipes.isEmpty else {
            print("⚠️ No recipes available in RecipeManager for replacement")
            return []
        }
        
        class DebugStats {
            var total = 0
            var excludedCurrent = 0
            var excludedUsed = 0
            var excludedMealType = 0
            var excludedPreferences = 0
            var excludedHealthGoals = 0
            var passed = 0
        }
        let debugStats = DebugStats()
        
        let eligibleRecipes = recipeManager.recipes.filter { recipe in
            debugStats.total += 1
            
            // Exclude current recipe
            if let currentRecipeID = meal.recipeID, recipe.id == currentRecipeID {
                debugStats.excludedCurrent += 1
                return false
            }
            
            // Exclude recipes already in the plan (by ID) - but NOT the current meal
            if usedRecipeIDs.contains(recipe.id) {
                debugStats.excludedUsed += 1
                return false
            }
            
            // Exclude recipes already in the plan (by normalized title) - but NOT the current meal
            let normalizedTitle = normalizeTitle(recipe.title)
            if usedRecipeTitles.contains(normalizedTitle) {
                debugStats.excludedUsed += 1
                return false
            }
            
            // Filter by meal type using mealTypeHints
            // First, ensure recipe has mealTypeHints (classify if needed)
            var recipeWithHints = recipe
            if recipeWithHints.mealTypeHints == nil {
                recipeWithHints.mealTypeHints = LFIEngine.classifyMealTypes(recipe: recipeWithHints)
                // Save classification back to recipe (but don't persist to disk yet)
                // This ensures subsequent checks use the same classification
            }
            let recipeMealTypes = Set(recipeWithHints.mealTypeHints ?? [])
            
            // Also check categories as fallback (for user recipes that might not be classified yet)
            let categoryMatchesMealType: Bool = {
                switch meal.mealType {
                case .breakfast:
                    return recipe.categories.contains(.breakfast)
                case .lunch:
                    return recipe.categories.contains(.lunch) || 
                           recipe.categories.contains(.salad) || 
                           recipe.categories.contains(.soup)
                case .dinner:
                    return recipe.categories.contains(.dinner) || 
                           recipe.categories.contains(.main)
                case .snack:
                    return recipe.categories.contains(.snack)
                case .dessert:
                    return recipe.categories.contains(.dessert)
                }
            }()
            
            // Accept recipe if mealTypeHints match OR categories match
            // This ensures user recipes with categories but no hints still work
            guard recipeMealTypes.contains(meal.mealType) || categoryMatchesMealType else {
                debugStats.excludedMealType += 1
                return false
            }
            
            // Filter by dietary preferences if provided (STRICT - must match)
            if let prefs = preferences, !prefs.isEmpty {
                if !matchesDietaryPreferences(recipe: recipe, preferences: prefs) {
                    debugStats.excludedPreferences += 1
                    return false
                }
            }
            
            // For replacements, be more lenient with health goals
            // If health goals are set, check if recipe meets at least ONE goal OR has decent score
            if let goals = healthGoals, !goals.isEmpty {
                let effectiveScore = recipe.longevityScore ?? recipe.estimatedLongevityScore ?? 50
                
                // Apply longevity score filter if set (but be more lenient - allow 10 points below)
                if longevityScoreFilter > 0 {
                    let relaxedThreshold = max(50, longevityScoreFilter - 10) // Allow 10 points below filter
                    if effectiveScore < relaxedThreshold {
                        debugStats.excludedHealthGoals += 1
                        return false
                    }
                } else {
                    // No score filter, but check if recipe meets at least one health goal
                    // OR has a decent score (>= 50)
                    let meetsAtLeastOneGoal = matchesHealthGoals(recipe: recipe, goals: goals)
                    if !meetsAtLeastOneGoal && effectiveScore < 50 {
                        debugStats.excludedHealthGoals += 1
                        return false
                    }
                }
            }
            
            debugStats.passed += 1
            return true
        }
        
        print("🔍 Replacement filter stats for \(meal.mealType.displayName):")
        print("   Total recipes: \(debugStats.total)")
        print("   Excluded (current): \(debugStats.excludedCurrent)")
        print("   Excluded (already used): \(debugStats.excludedUsed)")
        print("   Excluded (meal type): \(debugStats.excludedMealType)")
        print("   Excluded (preferences): \(debugStats.excludedPreferences)")
        print("   Excluded (health goals): \(debugStats.excludedHealthGoals)")
        print("   Passed all filters: \(debugStats.passed)")
        
        print("🔍 Found \(eligibleRecipes.count) eligible replacement recipes for \(meal.mealType.displayName) (out of \(recipeManager.recipes.count) total recipes)")
        return eligibleRecipes
    }
    
    // MARK: - Ingredient Matching Helpers (Word Boundary Matching)
    
    /// Check if text contains ingredient as a whole word (not substring)
    /// Prevents false positives like "chicken stock" matching "chicken"
    private func containsIngredient(_ text: String, _ ingredient: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: ingredient))\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    /// Count how many ingredients from a list appear in the text
    private func countIngredients(_ text: String, from ingredients: [String]) -> Int {
        return ingredients.filter { containsIngredient(text, $0) }.count
    }
    
    /// Check if any ingredient from a list appears in the text
    private func hasAnyIngredient(_ text: String, from ingredients: [String]) -> Bool {
        return ingredients.contains { containsIngredient(text, $0) }
    }
    
    /// Check if recipe matches dietary preferences (same logic as MealPlannerSetupView)
    /// V2: Enhanced with ingredient-based fallback for better matching accuracy
    private func matchesDietaryPreferences(recipe: Recipe, preferences: Set<String>) -> Bool {
        if preferences.isEmpty { return true }
        
        let prefLower = preferences.map { $0.lowercased() }
        
        // Classic, Flexitarian, Intermittent Fasting = accept all
        if prefLower.contains(where: { $0.contains("classic") || $0.contains("flexitarian") || $0.contains("intermittent") }) {
            return true
        }
        
        // Prepare ingredient text for analysis
        let ingredientsText = (recipe.ingredientsText ?? "").lowercased()
        let ingredientNames = recipe.allIngredients.map { $0.name.lowercased() }.joined(separator: " ")
        let titleText = recipe.title.lowercased()
        let combinedText = ingredientsText + " " + ingredientNames + " " + titleText
        
        // Check each preference
        for pref in prefLower {
            
            // ═══════════════════════════════════════════════════════════════
            // MEDITERRANEAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("mediterranean") {
                // Check category first
                if recipe.categories.contains(.mediterranean) {
                    return true
                }
                // Ingredient-based fallback (using word boundary matching)
                let mediterraneanIngredients = [
                    "olive oil", "tomato", "garlic", "basil", "oregano", "feta",
                    "chickpea", "lentil", "hummus", "tahini", "eggplant", "zucchini",
                    "salmon", "sardine", "anchovy", "shrimp", "greek yogurt",
                    "couscous", "bulgur", "farro", "pita", "za'atar"
                ]
                if countIngredients(combinedText, from: mediterraneanIngredients) >= 3 {
                    return true
                }
                // Title-based fallback
                let titleIndicators = ["mediterranean", "greek", "italian", "spanish", "moroccan", "turkish", "lebanese"]
                if hasAnyIngredient(titleText, from: titleIndicators) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // VEGAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("vegan") {
                if recipe.categories.contains(.vegan) {
                    return true
                }
                // Check for animal products (using word boundary matching)
                let animalProducts = [
                    "chicken", "beef", "pork", "lamb", "turkey", "bacon", "sausage",
                    "fish", "salmon", "shrimp", "crab", "tuna",
                    "milk", "cheese", "butter", "cream", "yogurt", "egg", "eggs",
                    "honey", "gelatin"
                ]
                if !hasAnyIngredient(combinedText, from: animalProducts) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // VEGETARIAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("vegetarian") {
                if recipe.categories.contains(.vegetarian) || recipe.categories.contains(.vegan) {
                    return true
                }
                // Check for meat (using word boundary matching)
                let meat = [
                    "chicken", "beef", "pork", "lamb", "turkey", "bacon", "sausage", "ham",
                    "fish", "salmon", "shrimp", "crab", "tuna", "lobster", "anchovy"
                ]
                if !hasAnyIngredient(combinedText, from: meat) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // KETO
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("keto") {
                if recipe.categories.contains(.keto) {
                    return true
                }
                // Check ingredients (using word boundary matching)
                let ketoFriendly = ["avocado", "bacon", "egg", "cheese", "butter", "cream", "coconut oil", "olive oil"]
                let highCarb = ["rice", "pasta", "bread", "flour", "potato", "sugar", "corn", "oat"]
                let ketoCount = countIngredients(combinedText, from: ketoFriendly)
                let carbCount = countIngredients(combinedText, from: highCarb)
                if ketoCount >= 2 && carbCount == 0 {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // PALEO
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("paleo") {
                if recipe.categories.contains(.paleo) {
                    return true
                }
                // Check for non-paleo ingredients (using word boundary matching)
                let nonPaleo = ["bread", "pasta", "rice", "oat", "wheat", "milk", "cheese", "yogurt", "bean", "lentil", "peanut", "soy", "tofu"]
                if !hasAnyIngredient(combinedText, from: nonPaleo) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // PESCATARIAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("pescatarian") {
                // Pescatarian: accept vegetarian/vegan recipes (pescatarian category doesn't exist)
                if recipe.categories.contains(.vegetarian) || recipe.categories.contains(.vegan) {
                    return true
                }
                // Allow seafood, no land meat (using word boundary matching)
                let landMeat = ["chicken", "beef", "pork", "lamb", "turkey", "bacon", "sausage", "ham"]
                if !hasAnyIngredient(combinedText, from: landMeat) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // LOW CARB
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("low carb") || pref.contains("lowcarb") {
                if recipe.categories.contains(.keto) {
                    return true
                }
                // Check for high carb ingredients (using word boundary matching)
                let highCarb = ["rice", "pasta", "bread", "flour", "potato", "sugar", "corn", "oat", "noodle", "tortilla"]
                if countIngredients(combinedText, from: highCarb) == 0 {
                    return true
                }
            }
        }
        
        // No match found
        return false
    }
    
    /// Check if recipe matches health goals (same logic as MealPlannerSetupView)
    /// Uses OUR proprietary LFI logic (longevityScore for user recipes, estimatedLongevityScore for Spoonacular)
    private func matchesHealthGoals(recipe: Recipe, goals: Set<String>) -> Bool {
        // If no goals selected, accept all recipes
        if goals.isEmpty {
            return true
        }
        
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
        
        // Apply longevity score filter (if set)
        if longevityScoreFilter > 0 && effectiveLongevityScore < longevityScoreFilter {
            return false
        }
        
        // Goal-specific logic with ingredient-based matching
        // Prepare ingredient text for goal-specific matching
        let ingredientsText = (recipe.ingredientsText ?? "").lowercased()
        let ingredientNames = recipe.allIngredients.map { $0.name.lowercased() }.joined(separator: " ")
        let combinedText = ingredientsText + " " + ingredientNames
        
        // Check each goal with goal-specific logic
        for goal in goals {
            let goalLower = goal.lowercased()
            
            switch goalLower {
            case "heart health":
                // Omega-3, fiber, low saturated fat
                let heartHealthy = ["salmon", "sardine", "mackerel", "olive oil", "avocado", "walnut", "almond", "oat", "flaxseed", "chia"]
                let heartUnhealthy = ["bacon", "sausage", "fried", "butter", "cream"]
                let healthyCount = countIngredients(combinedText, from: heartHealthy)
                let unhealthyCount = countIngredients(combinedText, from: heartUnhealthy)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (healthyCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 65 && unhealthyCount == 0 && meetsScoreFilter) {
                    return true
                }
                
            case "brain health":
                // Omega-3, antioxidants, leafy greens
                let brainHealthy = ["salmon", "blueberry", "walnut", "spinach", "kale", "broccoli", "turmeric", "egg", "avocado", "dark chocolate"]
                let brainCount = countIngredients(combinedText, from: brainHealthy)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (brainCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 70 && meetsScoreFilter) {
                    return true
                }
                
            case "weight management":
                // High protein, high fiber, low calorie
                let weightFriendly = ["chicken breast", "fish", "egg white", "greek yogurt", "legume", "vegetable", "salad", "lean"]
                let weightUnfriendly = ["fried", "cream", "sugar", "pastry", "cake", "cookie"]
                let friendlyCount = countIngredients(combinedText, from: weightFriendly)
                let unfriendlyCount = countIngredients(combinedText, from: weightUnfriendly)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if ((friendlyCount >= 2 && unfriendlyCount == 0) && meetsScoreFilter) || (effectiveLongevityScore >= 65 && meetsScoreFilter) {
                    return true
                }
                
            case "digestive health":
                // Fiber, probiotics, fermented foods
                let digestiveHealthy = ["yogurt", "kefir", "sauerkraut", "kimchi", "fiber", "oat", "legume", "vegetable", "fruit", "ginger"]
                let digestiveCount = countIngredients(combinedText, from: digestiveHealthy)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (digestiveCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 60 && meetsScoreFilter) {
                    return true
                }
                
            case "energy & vitality", "energy and vitality":
                // Complex carbs, B vitamins, iron
                let energyFoods = ["oat", "quinoa", "banana", "spinach", "egg", "almond", "sweet potato", "brown rice"]
                let energyCount = countIngredients(combinedText, from: energyFoods)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (energyCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 60 && meetsScoreFilter) {
                    return true
                }
                
            default:
                // Generic: use score threshold
                let threshold = longevityScoreFilter > 0 ? longevityScoreFilter : 60
                if effectiveLongevityScore >= threshold {
                    return true
                }
            }
        }
        
        // If we get here, no goal matched - but if score is high enough, allow it
        let threshold = longevityScoreFilter > 0 ? longevityScoreFilter : 50
        return effectiveLongevityScore >= threshold
    }
    
    // MARK: - Score Gradient Helper (matching horizontal recipe cards)
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

