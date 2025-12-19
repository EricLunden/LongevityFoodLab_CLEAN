import SwiftUI

struct MealPlannerCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var mealPlanManager = MealPlanManager.shared
    @StateObject private var recipeManager = RecipeManager.shared
    
    let isAutoMode: Bool
    let preferences: Set<String>?
    let healthGoals: Set<String>?
    let existingMealPlan: MealPlan?
    
    @State private var selectedWeekStart: Date = Date()
    @State private var showingRecipeSelection: MealType? = nil
    @State private var selectedDate: Date = Date()
    @State private var currentMealPlan: MealPlan?
    @State private var showingSummary = false
    @State private var selectedRecipe: Recipe? = nil
    @State private var dateRangeOption: DateRangeOption = .sevenDays
    @State private var showingEmptySlots = false
    
    init(isAutoMode: Bool, preferences: Set<String>? = nil, healthGoals: Set<String>? = nil, existingMealPlan: MealPlan? = nil) {
        self.isAutoMode = isAutoMode
        self.preferences = preferences
        self.healthGoals = healthGoals
        self.existingMealPlan = existingMealPlan
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Date range selector dropdown
                    HStack {
                        Picker("Date Range", selection: $dateRangeOption) {
                            Text("3 Days").tag(DateRangeOption.threeDays)
                            Text("7 Days").tag(DateRangeOption.sevenDays)
                            Text("14 Days").tag(DateRangeOption.fourteenDays)
                            Text("1 Month").tag(DateRangeOption.oneMonth)
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        Spacer()
                        
                        // "+" button to show/hide empty slots
                        Button(action: {
                            showingEmptySlots.toggle()
                        }) {
                            Image(systemName: showingEmptySlots ? "minus.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                    
                    // Weekly meal plan (vertical layout)
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(weekDays, id: \.self) { date in
                                daySection(for: date)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        if let plan = currentMealPlan {
                            showingSummary = true
                        } else {
                            saveMealPlan()
                        }
                    }
                    .foregroundColor(.blue)
                }
            })
        }
        .sheet(isPresented: Binding(
            get: { showingRecipeSelection != nil },
            set: { if !$0 { showingRecipeSelection = nil } }
        )) {
            if let mealType = showingRecipeSelection {
                RecipeSelectionDrawerView(
                    mealType: mealType,
                    scheduledDate: selectedDate,
                    preferences: preferences,
                    healthGoals: healthGoals,
                    onRecipeSelected: { recipe in
                        addMealToPlan(recipe: recipe, mealType: mealType, date: selectedDate)
                        showingRecipeSelection = nil
                    }
                )
            }
        }
        .onAppear {
            loadOrCreateMealPlan()
            // Load recipes to ensure images can be displayed
            Task {
                await recipeManager.loadRecipes()
            }
        }
        .sheet(isPresented: $showingSummary) {
            if let plan = currentMealPlan {
                MealPlanSummaryView(mealPlan: plan)
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
    }
    
    // MARK: - Week Days
    // Show date range based on selected option (3 days, 7 days, 14 days, or 1 month)
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let startDate: Date
        
        // If we have an existing plan, use its start date
        if let plan = currentMealPlan {
            startDate = calendar.startOfDay(for: plan.startDate)
        } else {
            // Use selected week start
            startDate = calendar.dateInterval(of: .weekOfYear, for: selectedWeekStart)?.start ?? selectedWeekStart
        }
        
        let daysToShow: Int
        switch dateRangeOption {
        case .threeDays:
            daysToShow = 3
        case .sevenDays:
            daysToShow = 7
        case .fourteenDays:
            daysToShow = 14
        case .oneMonth:
            daysToShow = 30
        }
        
        return (0..<daysToShow).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
        }
    }
    
    // MARK: - Day Section
    private func daySection(for date: Date) -> some View {
        let mealsForDay = mealPlanManager.getPlannedMealsForDate(date)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        
        return VStack(alignment: .leading, spacing: 12) {
            // Day header
            Text(dateFormatter.string(from: date))
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            // Meal slots - only show filled slots, or show empty slots if toggle is on
            VStack(spacing: 8) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    if let meal = mealsForDay.first(where: { $0.mealType == mealType }) {
                        mealSlotCard(meal: meal, mealType: mealType, date: date)
                    } else if showingEmptySlots {
                        emptyMealSlot(mealType: mealType, date: date)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color(red: 0.608, green: 0.827, blue: 0.835)
                        .opacity(colorScheme == .dark ? 1.0 : 0.6),
                    lineWidth: colorScheme == .dark ? 1.0 : 0.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Meal Slot Card (List Card style)
    private func mealSlotCard(meal: PlannedMeal, mealType: MealType, date: Date) -> some View {
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
        }
        
        return Button(action: {
            // Show full recipe detail view
            if let recipe = recipe {
                selectedRecipe = recipe
            } else {
                print("⚠️ Cannot open recipe - recipe not found for meal: \(meal.displayTitle)")
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
                        .lineLimit(1)
                    
                    Text(mealType.displayName)
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
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .contextMenu {
            Button(action: {
                // Swap recipe option
                selectedDate = date
                showingRecipeSelection = mealType
            }) {
                Label("Swap Recipe", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }
    
    // MARK: - Empty Meal Slot
    private func emptyMealSlot(mealType: MealType, date: Date) -> some View {
        Button(action: {
            selectedDate = date
            showingRecipeSelection = mealType
        }) {
            HStack {
                Text("+ Add \(mealType.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
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
    
    // MARK: - Actions
    private func loadOrCreateMealPlan() {
        // If existing plan provided (from Auto Review), use it
        if let existingPlan = existingMealPlan {
            currentMealPlan = existingPlan
            // Set selected week to match plan's start date
            selectedWeekStart = existingPlan.startDate
            return
        }
        
        // Otherwise, try to load active plan or create new one
        if let activePlan = mealPlanManager.getActiveMealPlan() {
            currentMealPlan = activePlan
        } else {
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedWeekStart)?.start ?? selectedWeekStart
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? startOfWeek
            
            let newPlan = mealPlanManager.createMealPlan(startDate: startOfWeek, endDate: endOfWeek)
            currentMealPlan = newPlan
        }
    }
    
    private func addMealToPlan(recipe: Recipe, mealType: MealType, date: Date) {
        guard var plan = currentMealPlan else { return }
        
        // If this is a Spoonacular recipe (not already saved), save it to RecipeManager
        // Spoonacular recipes have analysisType == .cached and isOriginal == false
        // This ensures recipe images are available when displaying meal plan cards
        if recipe.analysisType == .cached && !recipe.isOriginal {
            // Check if recipe already exists in RecipeManager
            if !recipeManager.recipes.contains(where: { $0.id == recipe.id }) {
                Task {
                    do {
                        try await recipeManager.saveRecipe(recipe)
                        print("🍽️ Saved Spoonacular recipe '\(recipe.title)' to RecipeManager")
                    } catch {
                        print("⚠️ Failed to save Spoonacular recipe '\(recipe.title)': \(error)")
                        // Continue even if save fails - recipe will still be added to plan
                    }
                }
            }
        }
        
        // Use longevityScore (full LFI) if available, otherwise estimatedLongevityScore (fast-pass LFI)
        let score = recipe.longevityScore ?? recipe.estimatedLongevityScore ?? nil
        
        let plannedMeal = PlannedMeal(
            recipeID: recipe.id,
            mealType: mealType,
            scheduledDate: date,
            displayTitle: recipe.title,
            estimatedLongevityScore: score.map { Double($0) }
        )
        
        mealPlanManager.addPlannedMeal(plannedMeal, to: plan)
        
        if let updatedPlan = mealPlanManager.mealPlans.first(where: { $0.id == plan.id }) {
            currentMealPlan = updatedPlan
        }
    }
    
    private func saveMealPlan() {
        // Meal plan is already saved via MealPlanManager
        dismiss()
    }
}

// MARK: - Date Range Option
enum DateRangeOption: String, CaseIterable {
    case threeDays = "3 Days"
    case sevenDays = "7 Days"
    case fourteenDays = "14 Days"
    case oneMonth = "1 Month"
}

