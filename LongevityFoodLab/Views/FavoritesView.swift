//
//  FavoritesView.swift
//  LongevityFoodLab
//
//  Favorites Screen - Phase 2 Implementation
//

import SwiftUI

// MARK: - Sort and Filter Enums
enum FavoriteSortOption: String, CaseIterable {
    case recency = "Most Recent"
    case scoreHighLow = "Score: High to Low"
    case scoreLowHigh = "Score: Low to High"
}

enum FavoriteFilterOption: String, CaseIterable {
    case all = "All"
    case recipes = "Recipes"
    case meals = "Meals"
    case groceries = "Groceries"
}

enum FavoriteViewMode {
    case list
    case grid
}

// MARK: - Unified Favorite Item Type
enum FavoriteItem: Identifiable {
    case recipe(Recipe)
    case meal(TrackedMeal)
    case grocery(FoodCacheEntry)
    
    var id: String {
        switch self {
        case .recipe(let recipe):
            return "recipe-\(recipe.id.uuidString)"
        case .meal(let meal):
            if let imageHash = meal.imageHash {
                return "meal-\(imageHash)"
            }
            return "meal-\(meal.id.uuidString)"
        case .grocery(let entry):
            if let imageHash = entry.imageHash {
                return "grocery-\(imageHash)"
            }
            return "grocery-\(entry.cacheKey)"
        }
    }
    
    var date: Date {
        switch self {
        case .recipe(let recipe):
            return recipe.dateAdded
        case .meal(let meal):
            return meal.timestamp
        case .grocery(let entry):
            return entry.analysisDate
        }
    }
    
    var score: Int {
        switch self {
        case .recipe(let recipe):
            return recipe.longevityScore ?? 0
        case .meal(let meal):
            return Int(meal.healthScore)
        case .grocery(let entry):
            return entry.fullAnalysis.overallScore
        }
    }
    
    var title: String {
        switch self {
        case .recipe(let recipe):
            return recipe.title
        case .meal(let meal):
            return meal.name
        case .grocery(let entry):
            return entry.foodName
        }
    }
    
    var imageHash: String? {
        switch self {
        case .recipe:
            return nil
        case .meal(let meal):
            return meal.imageHash
        case .grocery(let entry):
            return entry.imageHash
        }
    }
    
    var imageUrl: String? {
        switch self {
        case .recipe(let recipe):
            return recipe.image
        case .meal, .grocery:
            return nil
        }
    }
}

struct FavoritesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @StateObject private var mealStorageManager = MealStorageManager.shared
    @State private var showingSideMenu = false
    @State private var viewMode: FavoriteViewMode = .list
    @State private var sortOption: FavoriteSortOption = .recency
    @State private var filterOption: FavoriteFilterOption = .all
    @State private var isEditing = false
    @State private var selectedItemIDs: Set<String> = []
    @State private var showingDeleteConfirmation = false
    @State private var displayedFavoriteCount = 6
    @State private var selectedRecipe: Recipe?
    @State private var selectedMeal: TrackedMeal?
    @State private var selectedGrocery: FoodCacheEntry?
    @State private var refreshID = UUID() // Force view refresh when favorites change
    
    var body: some View {
        mainNavigationView
            .onChange(of: recipeManager.recipes) { _ in
                refreshID = UUID()
            }
            .onChange(of: foodCacheManager.cachedAnalyses) { _ in
                refreshID = UUID()
            }
            .onChange(of: mealStorageManager.trackedMeals) { _ in
                refreshID = UUID()
            }
    }
    
    private var mainNavigationView: some View {
        NavigationView {
            mainContent
        }
    }
    
    private var mainContent: some View {
        scrollContentView
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSideMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title3)
                            .fontWeight(.light)
                            .foregroundColor(.primary)
                            .padding(.leading, 8)
                    }
                }
            }
            .id(refreshID)
            .overlay(sideMenuOverlay)
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailsView(meal: meal)
        }
        .sheet(item: Binding(
            get: { selectedGrocery.map { GroceryWrapper(entry: $0) } },
            set: { selectedGrocery = $0?.entry }
        )) { wrapper in
            ResultsView(
                analysis: wrapper.entry.fullAnalysis,
                onNewSearch: {}
            )
        }
        .confirmationDialog("Delete Items", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
            Button("Cancel", role: .cancel) {
                // Deselect all items and exit edit mode
                selectedItemIDs.removeAll()
                isEditing = false
            }
        } message: {
            Text("Are you sure you want to delete \(selectedItemIDs.count) item\(selectedItemIDs.count == 1 ? "" : "s")?")
        }
    }
    
    private var scrollContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                logoHeaderSection
                favoritesTopBox
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                viewToggleSection
                favoritesContentSection
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var sideMenuOverlay: some View {
        Group {
            if showingSideMenu {
                SideMenuView(isPresented: $showingSideMenu)
                    .transition(.move(edge: .leading))
                    .animation(.easeInOut(duration: 0.3), value: showingSideMenu)
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
    
    // MARK: - Favorites Top Box
    private var favoritesTopBox: some View {
        VStack(spacing: 10) {
            // Title with Icon (centered)
            HStack(spacing: 16) {
                // Heart Icon with Gradient (left of title)
                Image(systemName: "heart.fill")
                    .font(.system(size: 43, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 64/255.0, green: 56/255.0, blue: 213/255.0),  // Blue-purple #4038D5
                                Color(red: 12/255.0, green: 97/255.0, blue: 255/255.0)   // Bright blue #0C61FF
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 43, height: 43)
                
                Text("My Favorites")
                    .font(.system(size: colorScheme == .dark ? 36 : 31, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                    .foregroundColor(colorScheme == .dark ? .white : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            
            // Hairline separator
            Divider()
                .background(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                .padding(.horizontal, -10)
            
            // Edit and Filter Row (inside box)
            HStack {
                if viewMode == .grid {
                    // Edit/Cancel/Delete Button (left) - only show in grid view
                    Button(action: {
                        if !selectedItemIDs.isEmpty {
                            showingDeleteConfirmation = true
                        } else {
                            isEditing.toggle()
                            if !isEditing {
                                selectedItemIDs.removeAll()
                            }
                        }
                    }) {
                        Text(editButtonText)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                } else {
                    // List view: center the Filter
                    Spacer()
                }
                
                // Filter Dropdown (centered in list view, right-aligned in grid view)
                HStack(spacing: 4) {
                    Text("Filter:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Filter", selection: $filterOption) {
                        ForEach(FavoriteFilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.subheadline)
                }
                
                if viewMode == .grid {
                    // Spacer already added above
                } else {
                    // List view: center the Filter
                    Spacer()
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 15)
        .padding(.bottom, 15)
        .padding(.horizontal, 30)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(16)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
    
    // MARK: - View Toggle Section
    private var viewToggleSection: some View {
        HStack {
            // List Icon (flush left)
            Button(action: {
                viewMode = .list
            }) {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundColor(viewMode == .list ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 20)
            
            Spacer()
            
            // Sort Dropdown (center) - moved from top box
            Menu {
                ForEach(FavoriteSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        sortOption = option
                    }) {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sortOption.rawValue)
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            // Grid Icon (flush right)
            Button(action: {
                viewMode = .grid
            }) {
                Image(systemName: "square.grid.3x3")
                    .font(.title3)
                    .foregroundColor(viewMode == .grid ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 20)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .background(Color(UIColor.systemGroupedBackground))
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Favorites Content Section
    private var favoritesContentSection: some View {
        VStack(spacing: 0) {
            let filteredAndSortedItems = getFilteredAndSortedItems()
            
            if filteredAndSortedItems.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Text("No favorites yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Tap the heart icon on recipes, meals, or groceries to add them here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 20)
            } else {
                let displayCount = min(displayedFavoriteCount, filteredAndSortedItems.count)
                let itemsToShow = Array(filteredAndSortedItems.prefix(displayCount))
                
                Group {
                    if viewMode == .list {
                        favoritesListView(items: itemsToShow)
                            .id("list-\(itemsToShow.count)")
                    } else {
                        favoritesGridView(items: itemsToShow)
                            .id("grid-\(itemsToShow.count)")
                    }
                }
                .transition(.opacity)
                
                // View More/Show Less Buttons
                if filteredAndSortedItems.count > 6 {
                    HStack(spacing: 12) {
                        // Show Less button (only if showing more than 6)
                        if displayedFavoriteCount > 6 {
                            Button(action: {
                                displayedFavoriteCount = max(6, displayedFavoriteCount - 6)
                            }) {
                                Text("Show Less")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                                Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(8)
                            }
                        }
                        
                        // View More button (only if more items available)
                        if filteredAndSortedItems.count > displayedFavoriteCount {
                            Button(action: {
                                displayedFavoriteCount = min(displayedFavoriteCount + 6, filteredAndSortedItems.count)
                            }) {
                                Text("View More")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                                Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)  // Reduced padding from view toggle
    }
    
    // MARK: - List View
    @ViewBuilder
    private func favoritesListView(items: [FavoriteItem]) -> some View {
        LazyVStack(spacing: 12) {
            ForEach(items, id: \.id) { item in
                switch item {
                case .recipe(let recipe):
                    RecipeRowView(
                        recipe: recipe,
                        onTap: { tappedRecipe in
                            selectedRecipe = tappedRecipe
                        },
                        onDelete: { recipeToDelete in
                            Task {
                                try? await recipeManager.deleteRecipe(recipeToDelete)
                            }
                        }
                    )
                case .meal(let meal):
                    MealListRowView(
                        meal: meal,
                        onTap: {
                            selectedMeal = meal
                        },
                        onDelete: {
                            // Check if meal exists in MealStorageManager by imageHash or ID
                            if let imageHash = meal.imageHash,
                               mealStorageManager.trackedMeals.contains(where: { $0.imageHash == imageHash }) {
                                // Find the actual meal in MealStorageManager
                                if let actualMeal = mealStorageManager.trackedMeals.first(where: { $0.imageHash == imageHash }) {
                                    mealStorageManager.deleteMeal(actualMeal)
                                }
                            } else if mealStorageManager.trackedMeals.contains(where: { $0.id == meal.id }) {
                                mealStorageManager.deleteMeal(meal)
                            } else if let imageHash = meal.imageHash {
                                // Meal came from FoodCacheManager - unfavorite it instead of deleting
                                foodCacheManager.updateEntryFavorite(imageHash: imageHash, isFavorite: false)
                            }
                        }
                    )
                case .grocery(let entry):
                    GroceryScanRowView(
                        entry: entry,
                        onTap: { analysis in
                            selectedGrocery = entry
                        },
                        onDelete: { cacheKey in
                            foodCacheManager.deleteAnalysis(withCacheKey: cacheKey)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 0) // Padding handled by parent
    }
    
    // MARK: - Grid View
    @ViewBuilder
    private func favoritesGridView(items: [FavoriteItem]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items, id: \.id) { item in
                Group {
                    switch item {
                    case .recipe(let recipe):
                        RecipeGridCard(
                            recipe: recipe,
                            isEditing: isEditing,
                            isSelected: selectedItemIDs.contains(item.id),
                            onTap: {
                                selectedRecipe = recipe
                            },
                            onToggleSelection: {
                                if selectedItemIDs.contains(item.id) {
                                    selectedItemIDs.remove(item.id)
                                } else {
                                    selectedItemIDs.insert(item.id)
                                }
                            },
                            scoreCircleSize: 56
                        )
                    case .meal(let meal):
                        MealGridCardView(
                            meal: meal,
                            isEditing: isEditing,
                            isSelected: selectedItemIDs.contains(item.id),
                            onTap: {
                                selectedMeal = meal
                            },
                            onToggleSelection: {
                                if selectedItemIDs.contains(item.id) {
                                    selectedItemIDs.remove(item.id)
                                } else {
                                    selectedItemIDs.insert(item.id)
                                }
                            },
                            scoreCircleSize: 56
                        )
                    case .grocery(let entry):
                        GroceryScanGridCard(
                            entry: entry,
                            isEditing: isEditing,
                            isSelected: selectedItemIDs.contains(item.id),
                            onTap: {
                                selectedGrocery = entry
                            },
                            onToggleSelection: {
                                if selectedItemIDs.contains(item.id) {
                                    selectedItemIDs.remove(item.id)
                                } else {
                                    selectedItemIDs.insert(item.id)
                                }
                            },
                            scoreCircleSize: 56
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func getAllFavoriteItems() -> [FavoriteItem] {
        var items: [FavoriteItem] = []
        
        // Add favorited recipes
        let favoriteRecipes = recipeManager.getFavoriteRecipes()
        for recipe in favoriteRecipes {
            items.append(.recipe(recipe))
        }
        
        // Add favorited meals from Tracker
        let favoriteMealsFromTracker = mealStorageManager.trackedMeals.filter { $0.isFavorite }
        for meal in favoriteMealsFromTracker {
            items.append(.meal(meal))
        }
        
        // Add favorited meals from FoodCacheManager (scanned from Score screen)
        // Skip meals that already exist in MealStorageManager to avoid duplicates
        let favoriteMealEntries = foodCacheManager.cachedAnalyses.filter { entry in
            guard entry.isFavorite && (entry.scanType == "meal") else { return false }
            // Skip if this meal already exists in MealStorageManager with the same imageHash
            if let imageHash = entry.imageHash {
                return !mealStorageManager.trackedMeals.contains(where: { $0.imageHash == imageHash && $0.isFavorite })
            }
            return true
        }
        for entry in favoriteMealEntries {
            // Convert FoodCacheEntry to TrackedMeal
            let trackedMeal = convertFoodCacheEntryToTrackedMeal(entry)
            items.append(.meal(trackedMeal))
        }
        
        // Add favorited groceries (FoodCacheEntry with isFavorite = true, excluding meals)
        let favoriteGroceries = foodCacheManager.cachedAnalyses.filter { entry in
            entry.isFavorite && (entry.scanType != "meal")
        }
        for grocery in favoriteGroceries {
            items.append(.grocery(grocery))
        }
        
        return items
    }
    
    // Helper function to convert FoodCacheEntry to TrackedMeal
    private func convertFoodCacheEntryToTrackedMeal(_ entry: FoodCacheEntry) -> TrackedMeal {
        let analysis = entry.fullAnalysis
        let foodNames = analysis.foodNames ?? [analysis.foodName]
        
        return TrackedMeal(
            id: UUID(), // Generate new UUID for display purposes
            name: entry.foodName,
            foods: foodNames,
            healthScore: Double(analysis.overallScore),
            goalsMet: [], // Goals met can be empty for cached entries
            timestamp: entry.analysisDate,
            notes: nil,
            originalAnalysis: analysis,
            imageHash: entry.imageHash,
            isFavorite: entry.isFavorite
        )
    }
    
    private func getFilteredAndSortedItems() -> [FavoriteItem] {
        var items = getAllFavoriteItems()
        
        // Apply filter
        if filterOption != .all {
            items = items.filter { item in
                switch (item, filterOption) {
                case (.recipe, .recipes):
                    return true
                case (.meal, .meals):
                    return true
                case (.grocery, .groceries):
                    return true
                default:
                    return false
                }
            }
        }
        
        // Apply sort
        switch sortOption {
        case .recency:
            items.sort { $0.date > $1.date }
        case .scoreHighLow:
            items.sort { $0.score > $1.score }
        case .scoreLowHigh:
            items.sort { $0.score < $1.score }
        }
        
        return items
    }
    
    private var editButtonText: String {
        if !selectedItemIDs.isEmpty {
            return "Delete"
        } else if isEditing {
            return "Cancel"
        } else {
            return "Edit"
        }
    }
    
    private func deleteSelectedItems() {
        let items = getAllFavoriteItems().filter { selectedItemIDs.contains($0.id) }
        
        for item in items {
            switch item {
            case .recipe(let recipe):
                Task {
                    try? await recipeManager.deleteRecipe(recipe)
                }
            case .meal(let meal):
                // Check if meal exists in MealStorageManager by imageHash or ID
                if let imageHash = meal.imageHash,
                   mealStorageManager.trackedMeals.contains(where: { $0.imageHash == imageHash }) {
                    // Find the actual meal in MealStorageManager
                    if let actualMeal = mealStorageManager.trackedMeals.first(where: { $0.imageHash == imageHash }) {
                        mealStorageManager.deleteMeal(actualMeal)
                    }
                } else if mealStorageManager.trackedMeals.contains(where: { $0.id == meal.id }) {
                    mealStorageManager.deleteMeal(meal)
                } else if let imageHash = meal.imageHash {
                    // Meal came from FoodCacheManager - unfavorite it instead of deleting
                    foodCacheManager.updateEntryFavorite(imageHash: imageHash, isFavorite: false)
                }
            case .grocery(let entry):
                foodCacheManager.deleteAnalysis(withCacheKey: entry.cacheKey)
            }
        }
        
        selectedItemIDs.removeAll()
        // Stay in edit mode after deletion
        isEditing = true
    }
}

// MARK: - Helper Wrappers for Sheet Presentation
struct GroceryWrapper: Identifiable {
    let id: String
    let entry: FoodCacheEntry
    
    init(entry: FoodCacheEntry) {
        self.entry = entry
        self.id = entry.cacheKey
    }
}

struct MealWrapper: Identifiable {
    let id: UUID
    let meal: TrackedMeal
    
    init(meal: TrackedMeal) {
        self.meal = meal
        self.id = meal.id
    }
}
