import SwiftUI

struct RecipeSearchView: View {
    @StateObject private var recipeManager = RecipeManager.shared
    
    @State private var searchText = ""
    @State private var searchResults: [Recipe] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedCuisine = "All"
    @State private var selectedDiet = "All"
    @State private var maxReadyTime = 60
    @State private var showingFilters = false
    
    let cuisines = ["All", "Italian", "Mexican", "Asian", "American", "Mediterranean", "Indian", "French", "Chinese", "Japanese", "Thai", "Greek", "Spanish", "German", "British"]
    let diets = ["All", "Vegetarian", "Vegan", "Gluten Free", "Dairy Free", "Ketogenic", "Paleo", "Mediterranean", "Low Carb", "High Protein"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Logo Header
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 50)
                        .padding(.top, 20)
                    
                    VStack(spacing: 0) {
                        Text("LONGEVITY")
                            .font(.system(size: 20, weight: .light, design: .default))
                            .tracking(6)
                            .foregroundColor(.primary)
                            .dynamicTypeSize(.large)
                        
                        HStack {
                            Rectangle()
                                .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                .frame(width: 25, height: 1)
                            
                            Text("FOOD LAB")
                                .font(.system(size: 10, weight: .light, design: .default))
                                .tracking(4)
                                .foregroundColor(.secondary)
                                .dynamicTypeSize(.large)
                            
                            Rectangle()
                                .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                .frame(width: 25, height: 1)
                        }
                    }
                }
                .padding(.bottom, 20)
                
                // Search Section
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search for recipes...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                Task {
                                    await searchRecipes()
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button("Clear") {
                                searchText = ""
                                searchResults = []
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // Filter Button
                    Button(action: {
                        showingFilters.toggle()
                    }) {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filters")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                        .cornerRadius(8)
                    }
                    
                    // Quick Search Buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            QuickSearchButton(title: "Healthy", query: "healthy", searchText: $searchText)
                            QuickSearchButton(title: "Quick", query: "quick", searchText: $searchText)
                            QuickSearchButton(title: "Mediterranean", query: "mediterranean", searchText: $searchText)
                            QuickSearchButton(title: "Vegetarian", query: "vegetarian", searchText: $searchText)
                            QuickSearchButton(title: "Low Carb", query: "low carb", searchText: $searchText)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                
                // Results Section
                if isLoading {
                    Spacer()
                    ProgressView("Searching recipes...")
                        .font(.headline)
                    Spacer()
                } else if !searchResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(searchResults) { recipe in
                                RecipeSearchCard(recipe: recipe) {
                                    Task {
                                        await saveRecipe(recipe)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if !searchText.isEmpty && !isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No recipes found")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Try adjusting your search terms or filters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("Discover Amazing Recipes")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Search for healthy, longevity-focused recipes from around the world")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingFilters) {
            RecipeFiltersView(
                selectedCuisine: $selectedCuisine,
                selectedDiet: $selectedDiet,
                maxReadyTime: $maxReadyTime,
                cuisines: cuisines,
                diets: diets
            ) {
                Task {
                    await searchRecipes()
                }
            }
        }
    }
    
    private func searchRecipes() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement browser-based recipe search
        // For now, show a placeholder message
        await MainActor.run {
            searchResults = []
            isLoading = false
            errorMessage = "Recipe search will be implemented with browser-based extraction"
        }
    }
    
    private func saveRecipe(_ recipe: Recipe) async {
        do {
            try await recipeManager.saveRecipe(recipe)
            await MainActor.run {
                // Show success feedback
                withAnimation {
                    // You could add a success animation here
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save recipe: \(error.localizedDescription)"
            }
        }
    }
}

struct QuickSearchButton: View {
    let title: String
    let query: String
    @Binding var searchText: String
    
    var body: some View {
        Button(title) {
            searchText = query
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
}

struct RecipeSearchCard: View {
    let recipe: Recipe
    let onSave: () -> Void
    
    @State private var isSaving = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !recipe.description.isEmpty {
                        Text(recipe.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    if let score = recipe.longevityScore {
                        Text("\(score)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 35, height: 35)
                            .background(scoreColor(score))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        isSaving = true
                        onSave()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isSaving = false
                        }
                    }) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                    .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                    .disabled(isSaving)
                }
            }
            
            HStack {
                // Text-based metadata display
                if !recipe.formattedMetadataString().isEmpty {
                    Text(recipe.formattedMetadataString())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if recipe.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(recipe.rating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                }
            }
            
            if !recipe.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recipe.categories.prefix(3)) { category in
                            Text(category.emoji + " " + category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        if recipe.categories.count > 3 {
                            Text("+\(recipe.categories.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color.green
        case 60..<80: return Color.orange
        default: return Color.red
        }
    }
}

struct RecipeFiltersView: View {
    @Binding var selectedCuisine: String
    @Binding var selectedDiet: String
    @Binding var maxReadyTime: Int
    let cuisines: [String]
    let diets: [String]
    let onApply: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Cuisine Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cuisine")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(cuisines, id: \.self) { cuisine in
                            FilterChip(
                                title: cuisine,
                                isSelected: selectedCuisine == cuisine
                            ) {
                                selectedCuisine = cuisine
                            }
                        }
                    }
                }
                
                // Diet Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Diet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(diets, id: \.self) { diet in
                            FilterChip(
                                title: diet,
                                isSelected: selectedDiet == diet
                            ) {
                                selectedDiet = diet
                            }
                        }
                    }
                }
                
                // Max Ready Time
                VStack(alignment: .leading, spacing: 12) {
                    Text("Max Ready Time: \(maxReadyTime) minutes")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Slider(value: Binding(
                        get: { Double(maxReadyTime) },
                        set: { maxReadyTime = Int($0) }
                    ), in: 15...180, step: 15)
                    .accentColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? 
                    Color(red: 0.42, green: 0.557, blue: 0.498) : 
                    Color(UIColor.systemGray6)
                )
                .cornerRadius(20)
        }
    }
}

#Preview {
    RecipeSearchView()
}
