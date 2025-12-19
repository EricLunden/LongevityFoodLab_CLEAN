//
//  LongevityFoodLabApp.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 7/12/25.
//

import SwiftUI
import Foundation

extension Notification.Name {
    static let navigateToRecipesTab = Notification.Name("navigateToRecipesTab")
}

@main
struct LongevityFoodLabApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var recipeManager = RecipeManager.shared
    // @StateObject private var recipeManager = iCloudRecipeManager.shared
    @State private var hasCheckedForPendingRecipe = false
    
    func checkForPendingRecipeImport() {
        print("Main App: Checking for pending recipe imports")
        
        if let sharedDefaults = UserDefaults(suiteName: "group.com.ericbetuel.longevityfoodlab") {
            // Check for complete recipe data first (from Paprika 3-style flow)
            if let recipeDataString = sharedDefaults.string(forKey: "pendingRecipeData") {
                // Found complete recipe data from Share Extension
                
                // Clear the pending data
                sharedDefaults.removeObject(forKey: "pendingRecipeData")
                sharedDefaults.removeObject(forKey: "pendingRecipeTimestamp")
                sharedDefaults.synchronize()
                
                // Parse and import the complete recipe data
                if let recipeData = recipeDataString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: recipeData) as? [String: Any] {
                    importCompleteRecipeData(json)
                }
            }
            // Fallback to URL-based import (legacy)
            else if let pendingURL = sharedDefaults.string(forKey: "pendingRecipeURL") {
                print("Main App: Found pending recipe URL: \(pendingURL)")
                
                // Clear the pending URL
                sharedDefaults.removeObject(forKey: "pendingRecipeURL")
                sharedDefaults.removeObject(forKey: "pendingRecipeTimestamp")
                sharedDefaults.synchronize()
                
                // Auto-import recipe immediately without user confirmation
                Task {
                    do {
                        let recipe = try await recipeManager.importRecipeFromURL(pendingURL)
                        print("Main App: Successfully auto-imported recipe: \(recipe.title)")
                        
                        // Reload recipes to ensure the saved recipe is in the list
                        await recipeManager.loadRecipes()
                        
                        // Auto-navigate to Recipes tab after successful import
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .navigateToRecipesTab,
                                object: nil,
                                userInfo: ["importedRecipeID": recipe.id.uuidString]
                            )
                        }
                    } catch {
                        print("Main App: Failed to auto-import recipe: \(error)")
                    }
                }
            } else {
                print("Main App: No pending recipe data found")
                // If no data found and we haven't checked before, try again in 1 second
                if !hasCheckedForPendingRecipe {
                    hasCheckedForPendingRecipe = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.checkForPendingRecipeImport()
                    }
                }
            }
        } else {
            print("Main App: Failed to access shared container")
        }
    }
    
    private func analyzeRecipeInBackground(_ recipe: Recipe) async {
        // Only analyze if recipe doesn't already have a score
        guard recipe.longevityScore == nil else {
            print("Main App: Recipe '\(recipe.title)' already has analysis, skipping")
            return
        }
        
        print("Main App: Starting background analysis for recipe: \(recipe.title)")
        
        AIService.shared.analyzeRecipe(recipe) { result in
            switch result {
            case .success(let analysis):
                print("Main App: Analysis completed for recipe: \(recipe.title), score: \(analysis.overallScore)")
                
                // Update recipe with analysis results (including full analysis JSON)
                Task {
                    var updatedRecipe = recipe
                    updatedRecipe.longevityScore = analysis.overallScore
                    updatedRecipe.analysisReport = analysis.summary
                    updatedRecipe.analysisType = .full
                    
                    // Encode full FoodAnalysis as JSON and save
                    if let jsonData = try? JSONEncoder().encode(analysis),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        updatedRecipe.fullAnalysisData = jsonString
                    }
                    
                    do {
                        try await recipeManager.saveRecipe(updatedRecipe)
                        print("Main App: Recipe updated with analysis results including full analysis data")
                    } catch {
                        print("Main App: Failed to update recipe with analysis: \(error)")
                    }
                }
                
            case .failure(let error):
                print("Main App: Recipe analysis failed for '\(recipe.title)': \(error)")
                // Fail silently - user can tap circle to retry
            }
        }
    }
    
    private func importCompleteRecipeData(_ data: [String: Any]) {
        // Importing complete recipe data from Share Extension
        
        // Create Recipe object from the complete data
        let title = data["title"] as? String ?? "Imported Recipe"
        let ingredients = data["ingredients"] as? [String] ?? []
        // Handle both string and array formats for instructions
        let instructions: [String]
        if let instructionsString = data["instructions"] as? String {
            // If it's a string, split by newlines to create array
            instructions = instructionsString.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else if let instructionsArray = data["instructions"] as? [String] {
            // If it's already an array, use it directly
            instructions = instructionsArray
        } else {
            instructions = []
        }
        let imageURL = data["imageURL"] as? String
        let prepTime = data["prepTime"] as? Int ?? 0
        let servings = data["servings"] as? Int ?? 1
        let sourceURL = data["sourceURL"] as? String ?? ""
        
        // Parse extracted nutrition if available
        var extractedNutrition: NutritionInfo? = nil
        var nutritionSource: String? = nil
        
        if let nutritionDict = data["extractedNutrition"] as? [String: Any] {
            // Log raw nutrition dict
            print("🔍 Main App: Raw extractedNutrition dict keys: \(nutritionDict.keys.sorted())")
            if let calciumRaw = nutritionDict["calcium"] {
                print("🔍 Main App: Raw calcium value: \(calciumRaw) (type: \(type(of: calciumRaw)))")
            } else {
                print("⚠️ Main App: No 'calcium' key in extractedNutrition dict")
            }
            
            // Decode NutritionInfo from JSON dictionary
            if let nutritionData = try? JSONSerialization.data(withJSONObject: nutritionDict),
               let nutrition = try? JSONDecoder().decode(NutritionInfo.self, from: nutritionData) {
                extractedNutrition = nutrition
                print("✅ Main App: Parsed extractedNutrition from App Groups - calories: \(nutrition.calories), calcium: \(nutrition.calcium ?? "nil")")
            } else {
                print("⚠️ Main App: Failed to decode extractedNutrition from App Groups")
            }
        }
        
        nutritionSource = data["nutritionSource"] as? String
        if nutritionSource != nil {
            print("✅ Main App: Found nutritionSource from App Groups: \(nutritionSource!)")
        }
        
        // Convert string arrays to Recipe model format
        let ingredientsText = ingredients.joined(separator: "\n")
        
        // Format instructions with numbering and proper paragraph spacing
        let instructionsText = instructions.enumerated().map { index, instruction in
            "\(index + 1). \(instruction)"
        }.joined(separator: "\n\n")
        
        // Create a Recipe object using the correct model structure
        // Convert empty string to nil for image URL (ensures proper image display)
        let recipe = Recipe(
            id: UUID(),
            title: title,
            image: (imageURL?.isEmpty == false) ? imageURL : nil,
            prepTime: prepTime,
            servings: servings,
            sourceURL: sourceURL,
            ingredientsText: ingredientsText,
            instructionsText: instructionsText,
            dateAdded: Date(),
            isOriginal: false,  // Mark as imported recipe
            extractedNutrition: extractedNutrition,
            nutritionSource: nutritionSource
        )
        
        // Save to RecipeManager
        Task {
            do {
                try await recipeManager.saveRecipe(recipe)
                print("Main App: Successfully saved complete recipe: \(recipe.title)")
                
                // Reload recipes to ensure the saved recipe is in the list
                await recipeManager.loadRecipes()
                print("Main App: Recipes reloaded, total count: \(recipeManager.recipes.count)")
                
                // Note: Analysis is now triggered only when user taps "TAP to score recipe" circle
                // No automatic background analysis
                
                // Auto-navigate to Recipes tab - pass recipe ID so RecipesView can find it from recipeManager.recipes
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .navigateToRecipesTab,
                        object: nil,
                        userInfo: ["importedRecipeID": recipe.id.uuidString]
                    )
                    print("Main App: Posted navigateToRecipesTab notification with recipe ID: \(recipe.id.uuidString)")
                }
            } catch {
                print("Main App: Failed to save recipe: \(error)")
            }
        }
    }

    init() {
        // AWS configuration removed for now
        
        // Migrate API keys from hardcoded values to Keychain (one-time operation)
        APIKeyConfiguration.shared.migrateFromHardcodedKeys()
        
        // Note: YouTube API keys are handled by Lambda, not needed in iOS app
        
        // TEMPORARY: Configure social media API keys
        // TODO: Replace placeholders with your actual API keys, run app once, then remove this code
        // Keys are now stored in Keychain - this code is commented out for security
        // APIKeyConfiguration.shared.configureKeys(
        //     youtube: "AIzaSyAHRWvcN2V3p76ifu2tDs7FPY72MNcrHRM",
        //     rapidAPI: "9b8395d37bmsh45ab7b891531865p17d2c3jsn4336eb5fb006"
        // )
    }
    
    private func checkForSharedContent() {
        print("Main App: Checking for shared content...")
        
        // Note: Share Extension now uses URL scheme approach, not app groups
        // This function is kept for backward compatibility but should not be called
        // when using the URL scheme approach
        print("Main App: No shared content found (using URL scheme approach)")
    }
    
    private func checkForSharedContentViaUserDefaults() {
        print("Main App: Checking for shared content via UserDefaults...")
        
        let userDefaults = UserDefaults.standard
        print("Main App: Using standard UserDefaults")
        
        if let sharedURLString = userDefaults.string(forKey: "sharedRecipeURL") {
            print("Main App: Found sharedRecipeURL: \(sharedURLString)")
        } else {
            print("Main App: No sharedRecipeURL found")
        }
        
        let timestamp = userDefaults.double(forKey: "sharedRecipeTimestamp")
        if timestamp > 0 {
            print("Main App: Found sharedRecipeTimestamp: \(timestamp)")
        } else {
            print("Main App: No sharedRecipeTimestamp found")
        }
        
        if let sharedURLString = userDefaults.string(forKey: "sharedRecipeURL"),
           timestamp > 0 {
            
            // Check if the data is recent (within last 30 seconds)
            let currentTime = Date().timeIntervalSince1970
            print("Main App: Current time: \(currentTime), Shared timestamp: \(timestamp), Difference: \(currentTime - timestamp)")
            
            if currentTime - timestamp < 30 {
                print("Main App: Found shared URL via UserDefaults: \(sharedURLString)")
                
                // Clear the shared data
                userDefaults.removeObject(forKey: "sharedRecipeURL")
                userDefaults.removeObject(forKey: "sharedRecipeTimestamp")
                userDefaults.synchronize()
                
                // Auto-import recipe immediately
                Task {
                    do {
                        let recipe = try await recipeManager.importRecipeFromURL(sharedURLString)
                        print("Main App: Successfully auto-imported recipe: \(recipe.title)")
                        
                        // Auto-navigate to Recipes tab after successful import
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: .navigateToRecipesTab,
                                object: nil,
                                userInfo: ["importedRecipe": recipe]
                            )
                        }
                    } catch {
                        print("Main App: Failed to auto-import recipe: \(error)")
                    }
                }
            } else {
                print("Main App: Shared data is too old, ignoring")
            }
        } else {
            print("Main App: No shared content found via UserDefaults")
        }
    }

    var body: some Scene {
        WindowGroup {
            if healthProfileManager.profileExists() {
                // User has completed onboarding, show main app
                ContentView()
                    .onAppear {
                        // Ensure user is authenticated for profile features
                        if !authManager.isAuthenticated {
                            Task {
                                try? await authManager.login(email: "demo@example.com", password: "password")
                            }
                        }
                        
                        // Listen for recipe import requests from Share Extension
                        NotificationCenter.default.addObserver(
                            forName: .recipeImportRequested,
                            object: nil,
                            queue: .main
                        ) { notification in
                            // Check if we have URL or text parameters
                            if let userInfo = notification.userInfo {
                                if let url = userInfo["url"] as? URL {
                                    // Received URL from Share Extension
                                    // Auto-import recipe immediately
                                    Task {
                                        do {
                                            let recipe = try await recipeManager.importRecipeFromURL(url.absoluteString)
                                            print("Main App: Successfully auto-imported recipe: \(recipe.title)")
                                            
                                            // Auto-navigate to Recipes tab after successful import
                                            DispatchQueue.main.async {
                                                NotificationCenter.default.post(
                                                    name: .navigateToRecipesTab,
                                                    object: nil,
                                                    userInfo: ["importedRecipe": recipe]
                                                )
                                            }
                                        } catch {
                                            print("Main App: Failed to auto-import recipe: \(error)")
                                        }
                                    }
                                } else if let text = userInfo["text"] as? String {
                                    // Received text from Share Extension
                                    // Handle text sharing if needed
                                }
                            }
                        }
                        
                        // Simple approach - just check when app becomes active
                    }
                    .onOpenURL { url in
                        print("Main App: Received URL: \(url)")
                        NSLog("Main App: Received URL: \(url)")
                        print("Main App: URL scheme: \(url.scheme ?? "nil")")
                        NSLog("Main App: URL scheme: \(url.scheme ?? "nil")")
                        print("Main App: URL host: \(url.host ?? "nil")")
                        NSLog("Main App: URL host: \(url.host ?? "nil")")
                        print("Main App: URL query: \(url.query ?? "nil")")
                        NSLog("Main App: URL query: \(url.query ?? "nil")")
                        print("Main App: Full URL string: \(url.absoluteString)")
                        NSLog("Main App: Full URL string: \(url.absoluteString)")
                        
                               // Handle recipe import URL
                               if (url.scheme == "longevityfoodlab" && url.host == "import") ||
                                  (url.scheme == "longevityfood" && url.host == "import-recipe") {
                                   print("Main App: Recipe import URL detected - scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil")")
                            print("Main App: Processing recipe import URL")
                            
                            // For simple URL scheme, trigger pending recipe import check
                            if url.scheme == "longevityfood" && url.host == "import-recipe" {
                                print("Main App: Simple URL scheme detected, checking for pending recipe")
                                checkForPendingRecipeImport()
                            } else if let query = url.query {
                                print("Main App: Query string: \(query)")
                                let components = query.components(separatedBy: "url=")
                                print("Main App: Query components: \(components)")
                                if components.count > 1 {
                                    let recipeURLString = components[1].removingPercentEncoding ?? components[1]
                                    print("Main App: Recipe URL string: \(recipeURLString)")
                                    if let recipeURL = URL(string: recipeURLString) {
                                        print("Main App: Recipe URL extracted: \(recipeURL)")
                                        
                                        // Auto-import recipe immediately
                                        Task {
                                            do {
                                                let recipe = try await recipeManager.importRecipeFromURL(recipeURL.absoluteString)
                                                print("Main App: Successfully auto-imported recipe: \(recipe.title)")
                                                
                                                // Auto-navigate to Recipes tab after successful import
                                                DispatchQueue.main.async {
                                                    NotificationCenter.default.post(
                                                        name: .navigateToRecipesTab,
                                                        object: nil,
                                                        userInfo: ["importedRecipe": recipe]
                                                    )
                                                }
                                            } catch {
                                                print("Main App: Failed to auto-import recipe: \(error)")
                                            }
                                        }
                                    } else {
                                        print("Main App: Failed to create URL from string: \(recipeURLString)")
                                    }
                                } else {
                                    print("Main App: No url= parameter found in query")
                                }
                            } else {
                                print("Main App: No query string found")
                            }
                        } else {
                            print("Main App: Not a recipe import URL, handling through deep link manager")
                            // Handle other URLs through deep link manager
                            deepLinkManager.handleURL(url)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        print("Main App: App became active")
                        // Check for pending recipe imports when app becomes active
                        checkForPendingRecipeImport()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RecipeURLReceived"))) { notification in
                        print("Main App: Received RecipeURLReceived notification")
                            if let recipeURLString = notification.userInfo?["recipeURL"] as? String {
                                print("Main App: Recipe URL from SceneDelegate: \(recipeURLString)")
                                // Auto-import recipe immediately
                                Task {
                                    do {
                                        let recipe = try await recipeManager.importRecipeFromURL(recipeURLString)
                                        print("Main App: Successfully auto-imported recipe: \(recipe.title)")
                                        
                                        // Auto-navigate to Recipes tab after successful import
                                        DispatchQueue.main.async {
                                            NotificationCenter.default.post(
                                                name: .navigateToRecipesTab,
                                                object: nil,
                                                userInfo: ["importedRecipe": recipe]
                                            )
                                        }
                                    } catch {
                                        print("Main App: Failed to auto-import recipe: \(error)")
                                    }
                                }
                        }
                    }
                    .onAppear {
                        print("Main App: App appeared")
                        
                        // Load recipes on app startup
                        Task {
                            await recipeManager.loadRecipes()
                            print("Main App: Recipes loaded: \(recipeManager.recipes.count)")
                        }
                        
                        // Check for pending recipe imports from Share Extension with a small delay
                        // to ensure Share Extension has time to save the URL
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            checkForPendingRecipeImport()
                        }
                    }
            } else {
                // User hasn't completed onboarding, show welcome/quiz flow
                WelcomeView()
            }
        }
    }
}
