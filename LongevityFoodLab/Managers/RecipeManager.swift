import Foundation
import SwiftUI
import CommonCrypto

// MARK: - Recipe Manager
@MainActor
class RecipeManager: ObservableObject, @unchecked Sendable {
    static let shared = RecipeManager()
    
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var lastError: RecipeError?
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var memoryCache: [String: Recipe] = [:]
    private var analysisCache: [String: CachedAnalysis] = [:]
    private let fileCoordinator = NSFileCoordinator()
    private let cacheQueue = DispatchQueue(label: "recipe.cache.queue", attributes: .concurrent)
    
    // Directory paths
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var recipesDirectory: URL {
        documentsDirectory.appendingPathComponent("Recipes")
    }
    
    private var recipeImagesDirectory: URL {
        documentsDirectory.appendingPathComponent("RecipeImages")
    }
    
    private var indexFileURL: URL {
        recipesDirectory.appendingPathComponent("recipe_index.json")
    }
    
    private var analysisCacheFileURL: URL {
        recipesDirectory.appendingPathComponent("analysis_cache.json")
    }
    
    // MARK: - Initialization
    private init() {
        setupDirectories()
        setupMemoryCache()
    }
    
    // MARK: - Setup
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: recipesDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: recipeImagesDirectory, withIntermediateDirectories: true)
        } catch {
            print("❌ RecipeManager: Failed to create directories: \(error)")
        }
    }
    
    private func setupMemoryCache() {
        // Initialize cache with reasonable limits
        // We'll manage cache size manually in the cache operations
    }
    
    // MARK: - Recipe Operations
    
    /// Import recipe from URL using Spoonacular API
    func importRecipeFromURL(_ urlString: String) async throws -> Recipe {
        print("🚀 RecipeManager: Starting import for URL: \(urlString)")
        print("   Current recipes count before import: \(recipes.count)")
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Validate URL
            guard let url = URL(string: urlString), url.scheme != nil else {
                print("❌ RecipeManager: Invalid URL format: \(urlString)")
                throw RecipeError.invalidRecipe
            }
            
            print("✅ RecipeManager: URL validation passed")
            
            // Extract recipe using browser-based extraction
            let browserService = RecipeBrowserService()
            print("🔍 RecipeManager: Calling RecipeBrowserService.extractRecipe")
            let importedRecipe = try await withCheckedThrowingContinuation { continuation in
                browserService.extractRecipe(from: URL(string: urlString)!) { recipe in
                    if let recipe = recipe {
                        continuation.resume(returning: recipe)
                    } else {
                        continuation.resume(throwing: RecipeError.importFailed(NSError(domain: "RecipeBrowserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract recipe data"])))
                    }
                }
            }
            
            print("✅ RecipeManager: Successfully extracted recipe: \(importedRecipe.title)")
            
            // DEBUG: Check if imported recipe has extracted nutrition
            if let nutrition = importedRecipe.extractedNutrition {
                print("✅ RecipeManager: ImportedRecipe HAS extractedNutrition - calories: \(nutrition.calories)")
                print("   Nutrition source: \(importedRecipe.nutritionSource ?? "unknown")")
            } else {
                print("❌ RecipeManager: ImportedRecipe does NOT have extractedNutrition")
            }
            
        // Convert to our Recipe model
        print("🟡 Before conversion: \(importedRecipe.ingredients.count) ingredients")
        let recipe = convertImportedRecipeToRecipe(importedRecipe)
        print("🟡 After conversion: Recipe created")
            
            // Save the recipe
            try await saveRecipe(recipe)
            print("✅ RecipeManager: Recipe saved successfully")
            
            await MainActor.run {
                isLoading = false
            }
            
            print("✅ RecipeManager: Imported recipe '\(recipe.title)' from \(urlString)")
            print("   Final recipes count after import: \(recipes.count)")
            return recipe
            
        } catch {
            print("❌ RecipeManager: Import failed with error: \(error)")
            await MainActor.run {
                isLoading = false
                lastError = .loadFailed(error)
            }
            throw error
        }
    }
    
    /// Convert ImportedRecipe to Recipe
    private func convertImportedRecipeToRecipe(_ importedRecipe: ImportedRecipe) -> Recipe {
        print("🔍 RecipeManager: Converting ImportedRecipe to Recipe")
        print("   Imported ingredients count: \(importedRecipe.ingredients.count)")
        for (index, ingredient) in importedRecipe.ingredients.enumerated() {
            print("   Ingredient \(index): \(ingredient)")
        }
        
        // Convert ingredients from string array to RecipeIngredientGroup
        let ingredientGroups = [RecipeIngredientGroup(
            name: "Ingredients",
            ingredients: importedRecipe.ingredients.map { ingredientString in
                // Parse the ingredient string to extract amount, unit, and name
                let parsed = parseIngredientString(ingredientString)
                return RecipeIngredient(
                    name: parsed.name,
                    amount: parsed.amount,
                    unit: parsed.unit,
                    notes: nil
                )
            }
        )]
        
        print("   Converted ingredient groups count: \(ingredientGroups.count)")
        print("   First group ingredients count: \(ingredientGroups.first?.ingredients.count ?? 0)")
        for (index, ingredient) in ingredientGroups.first?.ingredients.enumerated() ?? [].enumerated() {
            print("   Converted ingredient \(index): \(ingredient.name)")
        }
        
        // Convert instructions from string to RecipeDirection array
        let instructionStrings = importedRecipe.instructions.components(separatedBy: "\n\n")
        let instructions = instructionStrings.enumerated().compactMap { (index, instruction) -> RecipeDirection? in
            var trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedInstruction.isEmpty else { return nil }
            
            // Remove existing step prefixes before processing
            // Remove patterns like "Step 1:", "Step 1.", "1.", "1)", "Step one:", etc.
            let stepPrefixPatterns = [
                "^Step\\s+\\d+[:.]\\s*",  // "Step 1:" or "Step 1."
                "^\\d+[.)]\\s*",          // "1." or "1)"
                "^Step\\s+[Oo]ne[:.]\\s*", // "Step one:" or "Step One:"
                "^Step\\s+[Tt]wo[:.]\\s*", // "Step two:"
                "^Step\\s+[Tt]hree[:.]\\s*", // "Step three:"
                "^Step\\s+[Ff]our[:.]\\s*", // "Step four:"
                "^Step\\s+[Ff]ive[:.]\\s*", // "Step five:"
            ]
            
            for pattern in stepPrefixPatterns {
                trimmedInstruction = trimmedInstruction.replacingOccurrences(
                    of: pattern,
                with: "",
                options: .regularExpression
            )
            }
            
            // Trim any remaining whitespace
            trimmedInstruction = trimmedInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedInstruction.isEmpty else { return nil }
            
            return RecipeDirection(
                stepNumber: index + 1,
                instruction: trimmedInstruction,
                timeMinutes: nil,
                temperature: nil,
                notes: nil
            )
        }
        
        // Convert ingredients to simple text for display
        // Filter and format ingredients - remove random text prefixes, add numbers
        let filteredIngredients = importedRecipe.ingredients.map { ingredient in
            // Remove common prefix patterns: step numbers, bullets, dashes, "or", "plus", etc.
            var cleaned = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove step numbers (e.g., "1.", "Step 1:", etc.)
            cleaned = cleaned.replacingOccurrences(
                of: "^\\d+\\.\\s*",
                with: "",
                options: .regularExpression
            )
            cleaned = cleaned.replacingOccurrences(
                of: "^Step\\s+\\d+:\\s*",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            
            // Remove bullets and dashes at start
            cleaned = cleaned.replacingOccurrences(
                of: "^[•●*·-–—]\\s*",
                with: "",
                options: .regularExpression
            )
            
            // Remove common leading phrases that aren't ingredients
            let unwantedPrefixes = [
                "^Deselect All",
                "^Select All",
                "^Ingredients:",
                "^Ingredient:",
                "^For serving:",
                "^For garnish:",
                "^Optional:",
                "^or\\s+",
                "^plus\\s+more",
                "^plus\\s+",
            ]
            for prefix in unwantedPrefixes {
                cleaned = cleaned.replacingOccurrences(
                    of: prefix,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
            
            return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        
        // Number the ingredients
        let ingredientsText = filteredIngredients.enumerated().map { index, ingredient in
            "\(index + 1). \(ingredient)"
        }.joined(separator: "\n")
        
        // Convert instructions to simple text for display
        // Preserve instructions as-is (they may already be numbered)
        // Just ensure proper spacing between steps
        let instructionsText = importedRecipe.instructions
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n") // Use double newline for spacing
        
        print("🔍 RecipeManager: Converting to text")
        print("   Basic ingredients count: \(importedRecipe.ingredients.count)")
        print("   Basic ingredients: \(importedRecipe.ingredients)")
        print("   Raw ingredients count: \(importedRecipe.rawIngredients.count)")
        print("   Raw ingredients: \(importedRecipe.rawIngredients)")
        print("   Ingredients text length: \(ingredientsText.count)")
        print("   Ingredients text: \(ingredientsText)")
        print("   Instructions text length: \(instructionsText.count)")
        print("   Instructions text: \(instructionsText)")
        
        let finalRecipe = Recipe(
            title: importedRecipe.title,
            photos: [],
            image: (importedRecipe.imageUrl?.isEmpty == false) ? importedRecipe.imageUrl : nil, // Convert empty string to nil for proper image display
            rating: 0.0,
            prepTime: importedRecipe.prepTimeMinutes,
            cookTime: importedRecipe.cookTimeMinutes ?? 0, // Use cook time from import if available
            servings: importedRecipe.servings,
            categories: [], // Will be determined by AI analysis
            description: "", // Don't put image URL in description
            ingredients: ingredientGroups,
            directions: instructions,
            sourceURL: importedRecipe.sourceUrl,
            ingredientsText: ingredientsText,
            instructionsText: instructionsText,
            longevityScore: nil, // Will be calculated by AI analysis
            analysisReport: nil,
            improvementSuggestions: [],
            isFavorite: false,
            analysisType: .cached,
            isOriginal: false,
            extractedNutrition: importedRecipe.extractedNutrition,
            nutritionSource: importedRecipe.nutritionSource,
            aiEnhanced: importedRecipe.aiEnhanced,
            difficulty: importedRecipe.difficulty
        )
        
        // Log if extracted nutrition is available
        if let nutrition = importedRecipe.extractedNutrition {
            print("✅ RecipeManager: Recipe has extracted nutrition - \(nutrition.calories) calories")
        }
        
        // DEBUG: Log servings value when creating Recipe
        print("🍽️ RecipeManager: Creating Recipe '\(importedRecipe.title)' with servings: \(importedRecipe.servings)")
        print("🔍 RecipeManager: Final Recipe created")
        print("   Recipe title: \(finalRecipe.title)")
        print("   Recipe ingredients count: \(finalRecipe.ingredients.count)")
        print("   First ingredient group name: \(finalRecipe.ingredients.first?.name ?? "none")")
        print("   First ingredient group ingredients count: \(finalRecipe.ingredients.first?.ingredients.count ?? 0)")
        for (index, ingredient) in finalRecipe.ingredients.first?.ingredients.enumerated() ?? [].enumerated() {
            print("   Final ingredient \(index): \(ingredient.name)")
        }
        
        return finalRecipe
    }
    
    /// Parse ingredient string to extract amount, unit, and name
    private func parseIngredientString(_ ingredientString: String) -> (amount: String, unit: String?, name: String) {
        let trimmed = ingredientString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common patterns for ingredient parsing
        let patterns = [
            // "2 tablespoons olive oil" -> amount: "2", unit: "tablespoons", name: "olive oil"
            "^([0-9/\\s]+)\\s+([a-zA-Z]+)\\s+(.+)$",
            // "1/2 cup flour" -> amount: "1/2", unit: "cup", name: "flour"
            "^([0-9/\\s]+)\\s+([a-zA-Z]+)\\s+(.+)$",
            // "2 large eggs" -> amount: "2", unit: "large", name: "eggs"
            "^([0-9/\\s]+)\\s+([a-zA-Z]+)\\s+(.+)$"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: trimmed.utf16.count)
                if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                    if let amountRange = Range(match.range(at: 1), in: trimmed),
                       let unitRange = Range(match.range(at: 2), in: trimmed),
                       let nameRange = Range(match.range(at: 3), in: trimmed) {
                        
                        let amount = String(trimmed[amountRange]).trimmingCharacters(in: .whitespaces)
                        let unit = String(trimmed[unitRange]).trimmingCharacters(in: .whitespaces)
                        let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
                        
                        return (amount: amount, unit: unit, name: name)
                    }
                }
            }
        }
        
        // If no pattern matches, try to extract just a number at the beginning
        let numberPattern = "^([0-9/\\s]+)\\s+(.+)$"
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let range = NSRange(location: 0, length: trimmed.utf16.count)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range) {
                if let amountRange = Range(match.range(at: 1), in: trimmed),
                   let nameRange = Range(match.range(at: 2), in: trimmed) {
                    
                    let amount = String(trimmed[amountRange]).trimmingCharacters(in: .whitespaces)
                    let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
                    
                    return (amount: amount, unit: nil, name: name)
                }
            }
        }
        
        // If all else fails, return the whole string as the name
        return (amount: "", unit: nil, name: trimmed)
    }
    
    /// Save a recipe to disk and memory cache
    func saveRecipe(_ recipe: Recipe) async throws {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Update last modified date
            var updatedRecipe = recipe
            updatedRecipe.lastModified = Date()
            
            // Update recipes array first
            await MainActor.run {
                if let index = recipes.firstIndex(where: { $0.id == recipe.id }) {
                    recipes[index] = updatedRecipe
                    print("✅ RecipeManager: Updated existing recipe '\(recipe.title)' at index \(index)")
                } else {
                    recipes.append(updatedRecipe)
                    print("✅ RecipeManager: Added new recipe '\(recipe.title)' to recipes array. Total recipes: \(recipes.count)")
                }
                isLoading = false
            }
            
            // Save to disk
            try await saveRecipeToDisk(updatedRecipe)
            
            // Update memory cache
            cacheQueue.async(flags: .barrier) {
                self.memoryCache[recipe.id.uuidString] = updatedRecipe
            }
            
            print("✅ RecipeManager: Saved recipe '\(recipe.title)'")
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = .saveFailed(error)
            }
            throw error
        }
    }
    
    /// Load a recipe by ID
    func loadRecipe(id: UUID) async throws -> Recipe? {
        // Check memory cache first
        if let cachedRecipe = cacheQueue.sync(execute: { memoryCache[id.uuidString] }) {
            return cachedRecipe
        }
        
        // Load from disk
        let recipeFileURL = recipesDirectory.appendingPathComponent("\(id.uuidString).json")
        
        guard fileManager.fileExists(atPath: recipeFileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: recipeFileURL)
            let recipe = try JSONDecoder().decode(Recipe.self, from: data)
            
            // Cache in memory
            cacheQueue.async(flags: .barrier) {
                self.memoryCache[id.uuidString] = recipe
            }
            
            return recipe
        } catch {
            print("❌ RecipeManager: Failed to load recipe \(id): \(error)")
            throw RecipeError.loadFailed(error)
        }
    }
    
    /// Delete a recipe
    func deleteRecipe(_ recipe: Recipe) async throws {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Remove from disk
            let recipeFileURL = recipesDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
            if fileManager.fileExists(atPath: recipeFileURL.path) {
                try fileManager.removeItem(at: recipeFileURL)
            }
            
            // Remove images
            try await deleteRecipeImages(recipe.id)
            
            // Remove from memory cache
            cacheQueue.async(flags: .barrier) {
                self.memoryCache.removeValue(forKey: recipe.id.uuidString)
            }
            
            // Update recipes array
            await MainActor.run {
                recipes.removeAll { $0.id == recipe.id }
                isLoading = false
            }
            
            // Update index
            try await updateRecipeIndex()
            
            print("✅ RecipeManager: Deleted recipe '\(recipe.title)'")
        } catch {
            await MainActor.run {
                isLoading = false
                lastError = .deleteFailed(error)
            }
            throw error
        }
    }
    
    /// Search recipes with filters
    func searchRecipes(filters: RecipeSearchFilters) -> [Recipe] {
        var filteredRecipes = recipes
        
        // Apply text search
        if !filters.searchText.isEmpty {
            let searchText = filters.searchText.lowercased()
            filteredRecipes = filteredRecipes.filter { recipe in
                recipe.title.lowercased().contains(searchText) ||
                recipe.description.lowercased().contains(searchText) ||
                recipe.allIngredients.contains { $0.name.lowercased().contains(searchText) }
            }
        }
        
        // Apply category filter
        if !filters.categories.isEmpty {
            filteredRecipes = filteredRecipes.filter { recipe in
                !Set(recipe.categories).isDisjoint(with: filters.categories)
            }
        }
        
        // Apply time filters
        if let maxPrepTime = filters.maxPrepTime {
            filteredRecipes = filteredRecipes.filter { $0.prepTime <= maxPrepTime }
        }
        
        if let maxCookTime = filters.maxCookTime {
            filteredRecipes = filteredRecipes.filter { $0.cookTime <= maxCookTime }
        }
        
        if let maxTotalTime = filters.maxTotalTime {
            filteredRecipes = filteredRecipes.filter { $0.totalTime <= maxTotalTime }
        }
        
        // Apply rating filter
        if let minRating = filters.minRating {
            filteredRecipes = filteredRecipes.filter { $0.rating >= minRating }
        }
        
        if let maxRating = filters.maxRating {
            filteredRecipes = filteredRecipes.filter { $0.rating <= maxRating }
        }
        
        // Apply servings filter
        if let minServings = filters.minServings {
            filteredRecipes = filteredRecipes.filter { $0.servings >= minServings }
        }
        
        if let maxServings = filters.maxServings {
            filteredRecipes = filteredRecipes.filter { $0.servings <= maxServings }
        }
        
        // Apply analysis filter
        if let hasAnalysis = filters.hasAnalysis {
            filteredRecipes = filteredRecipes.filter { $0.hasAnalysis == hasAnalysis }
        }
        
        // Apply favorite filter
        if let isFavorite = filters.isFavorite {
            filteredRecipes = filteredRecipes.filter { $0.isFavorite == isFavorite }
        }
        
        // Apply sorting
        filteredRecipes = sortRecipes(filteredRecipes, by: filters.sortBy, order: filters.sortOrder)
        
        return filteredRecipes
    }
    
    /// Get recipes by category
    func getRecipesByCategory(_ category: RecipeCategory) -> [Recipe] {
        return recipes.filter { recipe in
            recipe.categories.contains(category)
        }
    }
    
    /// Get favorite recipes
    func getFavoriteRecipes() -> [Recipe] {
        return recipes.filter { $0.isFavorite }
    }
    
    /// Get recent recipes
    func getRecentRecipes(limit: Int = 10) -> [Recipe] {
        return Array(recipes.sorted { $0.dateAdded > $1.dateAdded }.prefix(limit))
    }
    
    // MARK: - Analysis Operations
    
    /// Get cached analysis for recipe fingerprint
    func getCachedAnalysis(for fingerprint: String) -> CachedAnalysis? {
        if let cached = cacheQueue.sync(execute: { analysisCache[fingerprint] }) {
            return cached.isExpired ? nil : cached
        }
        return nil
    }
    
    /// Cache analysis result
    func cacheAnalysis(_ analysis: CachedAnalysis) {
        cacheQueue.async(flags: .barrier) {
            self.analysisCache[analysis.fingerprint] = analysis
        }
        Task {
            try? await saveAnalysisCacheToDisk()
        }
    }
    
    /// Update recipe with analysis
    func updateRecipeWithAnalysis(_ recipe: Recipe, analysis: RecipeAnalysisResult) async throws {
        var updatedRecipe = recipe
        updatedRecipe.longevityScore = analysis.longevityScore
        updatedRecipe.analysisReport = analysis.analysisReport
        updatedRecipe.improvementSuggestions = analysis.improvements
        updatedRecipe.analysisType = analysis.analysisType
        updatedRecipe.lastModified = Date()
        
        try await saveRecipe(updatedRecipe)
    }
    
    // MARK: - Image Operations
    
    /// Save recipe image
    func saveRecipeImage(_ imageData: Data, for recipeId: UUID, filename: String) async throws -> String {
        let recipeImageDirectory = recipeImagesDirectory.appendingPathComponent(recipeId.uuidString)
        
        // Create recipe-specific directory if it doesn't exist
        if !fileManager.fileExists(atPath: recipeImageDirectory.path) {
            try fileManager.createDirectory(at: recipeImageDirectory, withIntermediateDirectories: true)
        }
        
        let imageURL = recipeImageDirectory.appendingPathComponent(filename)
        try imageData.write(to: imageURL)
        
        return filename
    }
    
    /// Load recipe image
    func loadRecipeImage(for recipeId: UUID, filename: String) -> Data? {
        let imageURL = recipeImagesDirectory
            .appendingPathComponent(recipeId.uuidString)
            .appendingPathComponent(filename)
        
        return try? Data(contentsOf: imageURL)
    }
    
    /// Delete recipe images
    private func deleteRecipeImages(_ recipeId: UUID) async throws {
        let recipeImageDirectory = recipeImagesDirectory.appendingPathComponent(recipeId.uuidString)
        
        if fileManager.fileExists(atPath: recipeImageDirectory.path) {
            try fileManager.removeItem(at: recipeImageDirectory)
        }
    }
    
    // MARK: - Private Methods
    
    func loadRecipes() async {
        print("🔄 RecipeManager: Starting loadRecipes()")
        do {
            try await loadRecipesFromDisk()
            try await loadAnalysisCacheFromDisk()
            print("✅ RecipeManager: loadRecipes() completed successfully. Loaded \(recipes.count) recipes")
        } catch {
            print("❌ RecipeManager: loadRecipes() failed with error: \(error)")
            await MainActor.run {
                lastError = .loadFailed(error)
            }
        }
    }
    
    private func loadRecipesFromDisk() async throws {
        print("🔄 RecipeManager: Starting loadRecipesFromDisk()")
        print("   Index file path: \(indexFileURL.path)")
        print("   Index file exists: \(fileManager.fileExists(atPath: indexFileURL.path))")
        
        // Load from index file first for performance
        if fileManager.fileExists(atPath: indexFileURL.path) {
            print("   Loading from index file...")
            let indexData = try Data(contentsOf: indexFileURL)
            let index = try JSONDecoder().decode(RecipeIndex.self, from: indexData)
            print("   Index contains \(index.recipes.count) recipe entries")
            
            var loadedRecipes: [Recipe] = []
            
            for recipeInfo in index.recipes {
                print("   Loading recipe: \(recipeInfo.title) (ID: \(recipeInfo.id))")
                if let recipe = try await loadRecipe(id: recipeInfo.id) {
                    loadedRecipes.append(recipe)
                    print("   ✅ Successfully loaded recipe: \(recipe.title)")
                } else {
                    print("   ❌ Failed to load recipe: \(recipeInfo.title)")
                }
            }
            
            print("   Total recipes loaded: \(loadedRecipes.count)")
            await MainActor.run {
                self.recipes = loadedRecipes
            }
        } else {
            print("   Index file not found, scanning directory...")
            // Fallback: scan directory for individual recipe files
            try await loadRecipesFromDirectory()
        }
    }
    
    private func loadRecipesFromDirectory() async throws {
        print("🔄 RecipeManager: Starting loadRecipesFromDirectory()")
        print("   Recipes directory: \(recipesDirectory.path)")
        
        let recipeFiles = try fileManager.contentsOfDirectory(at: recipesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent != "recipe_index.json" }
        
        print("   Found \(recipeFiles.count) recipe files")
        
        var loadedRecipes: [Recipe] = []
        
        for fileURL in recipeFiles {
            print("   Loading recipe from: \(fileURL.lastPathComponent)")
            do {
                let data = try Data(contentsOf: fileURL)
                let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                loadedRecipes.append(recipe)
                print("   ✅ Successfully loaded recipe: \(recipe.title)")
            } catch {
                print("❌ RecipeManager: Failed to load recipe from \(fileURL.lastPathComponent): \(error)")
            }
        }
        
        print("   Total recipes loaded from directory: \(loadedRecipes.count)")
        await MainActor.run {
            self.recipes = loadedRecipes.sorted { $0.dateAdded > $1.dateAdded }
        }
    }
    
    private func saveRecipeToDisk(_ recipe: Recipe) async throws {
        print("🔄 RecipeManager: Starting saveRecipeToDisk() for recipe: \(recipe.title)")
        let recipeFileURL = recipesDirectory.appendingPathComponent("\(recipe.id.uuidString).json")
        print("   Recipe file path: \(recipeFileURL.path)")
        
        let data = try JSONEncoder().encode(recipe)
        try data.write(to: recipeFileURL)
        print("   ✅ Recipe file written successfully")
        
        // Update index
        print("   Updating recipe index...")
        try await updateRecipeIndex()
        print("   ✅ Recipe index updated")
    }
    
    private func updateRecipeIndex() async throws {
        print("🔄 RecipeManager: Starting updateRecipeIndex()")
        print("   Current recipes count: \(recipes.count)")
        
        let recipeInfos = recipes.map { recipe in
            RecipeIndex.RecipeInfo(
                id: recipe.id,
                title: recipe.title,
                dateAdded: recipe.dateAdded,
                lastModified: recipe.lastModified,
                categories: recipe.categories,
                isFavorite: recipe.isFavorite,
                hasAnalysis: recipe.hasAnalysis
            )
        }
        
        print("   Recipe infos count: \(recipeInfos.count)")
        for (index, info) in recipeInfos.enumerated() {
            print("   Recipe \(index): \(info.title) (ID: \(info.id))")
        }
        
        let index = RecipeIndex(recipes: recipeInfos, lastUpdated: Date())
        let data = try JSONEncoder().encode(index)
        try data.write(to: indexFileURL)
        print("   ✅ Recipe index updated successfully")
    }
    
    private func loadAnalysisCacheFromDisk() async throws {
        guard fileManager.fileExists(atPath: analysisCacheFileURL.path) else { return }
        
        let data = try Data(contentsOf: analysisCacheFileURL)
        let cachedAnalyses = try JSONDecoder().decode([CachedAnalysis].self, from: data)
        
        cacheQueue.async(flags: .barrier) {
            for analysis in cachedAnalyses {
                if !analysis.isExpired {
                    self.analysisCache[analysis.fingerprint] = analysis
                }
            }
        }
    }
    
    private func saveAnalysisCacheToDisk() async throws {
        let allCachedAnalyses = cacheQueue.sync { Array(analysisCache.values) }
        let data = try JSONEncoder().encode(allCachedAnalyses)
        try data.write(to: analysisCacheFileURL)
    }
    
    private func sortRecipes(_ recipes: [Recipe], by sortBy: RecipeSearchFilters.RecipeSortOption, order: RecipeSearchFilters.SortOrder) -> [Recipe] {
        let sortedRecipes: [Recipe]
        
        switch sortBy {
        case .dateAdded:
            sortedRecipes = recipes.sorted { $0.dateAdded < $1.dateAdded }
        case .lastModified:
            sortedRecipes = recipes.sorted { $0.lastModified < $1.lastModified }
        case .title:
            sortedRecipes = recipes.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .rating:
            sortedRecipes = recipes.sorted { $0.rating < $1.rating }
        case .prepTime:
            sortedRecipes = recipes.sorted { $0.prepTime < $1.prepTime }
        case .cookTime:
            sortedRecipes = recipes.sorted { $0.cookTime < $1.cookTime }
        case .totalTime:
            sortedRecipes = recipes.sorted { $0.totalTime < $1.totalTime }
        case .longevityScore:
            sortedRecipes = recipes.sorted { ($0.longevityScore ?? 0) < ($1.longevityScore ?? 0) }
        case .servings:
            sortedRecipes = recipes.sorted { $0.servings < $1.servings }
        }
        
        return order == .descending ? sortedRecipes.reversed() : sortedRecipes
    }
}

// MARK: - Supporting Types
struct RecipeIndex: Codable {
    let recipes: [RecipeInfo]
    let lastUpdated: Date
    
    struct RecipeInfo: Codable, Identifiable {
        let id: UUID
        let title: String
        let dateAdded: Date
        let lastModified: Date
        let categories: [RecipeCategory]
        let isFavorite: Bool
        let hasAnalysis: Bool
    }
}

// MARK: - Error Types
enum RecipeError: Error, LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)
    case deleteFailed(Error)
    case imageSaveFailed(Error)
    case invalidRecipe
    case fileSystemError(Error)
    case importFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save recipe: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load recipe: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete recipe: \(error.localizedDescription)"
        case .imageSaveFailed(let error):
            return "Failed to save recipe image: \(error.localizedDescription)"
        case .invalidRecipe:
            return "Invalid recipe data"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Failed to import recipe: \(error.localizedDescription)"
        }
    }
}
