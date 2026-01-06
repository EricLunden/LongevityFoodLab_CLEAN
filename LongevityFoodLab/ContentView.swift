import SwiftUI
import Foundation

struct ContentView: View {
    @State private var showingResults = false
    @State private var showingMealResults = false
    @State private var showingCompareResults = false
    @State private var showingCompareView = false
    @State private var foodAnalysis: FoodAnalysis?
    @State private var mealAnalyses: [FoodAnalysis] = []
    @State private var compareAnalyses: [FoodAnalysis] = []
    @State private var currentTab = 0  // Start with Food tab (tag 0)
    @State private var shouldClearSearchInput = false
    @State private var searchViewRef: SearchView?
    @State private var showingSideMenu = false
    @State private var showingRecipeBanner = false
    @State private var recipeURL: String?
    @State private var selectedRecipe: Recipe?
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    
    // Scanner state
    @State private var showingScanner = false
    @State private var showingScanResult = false
    @State private var capturedImage: UIImage? // Barcode scan image (for analysis)
    @State private var frontLabelImage: UIImage? // Front label image (for grid display)
    @State private var scanResultAnalysis: FoodAnalysis?
    @State private var scanType: ScanType = .food
    @State private var needsBackScan = false
    @State private var currentImageHash: String? // Hash for barcode image (analysis)
    @State private var frontLabelImageHash: String? // Hash for front label image (grid)
    @State private var detectedBarcode: String?
    @State private var currentOpenFoodFactsProduct: OpenFoodFactsProduct? // Store OpenFoodFacts product for OCR
    
    var body: some View {
        TabView(selection: $currentTab) {
            // Food Tab (leftmost, default)
            NavigationView {
                SearchView(
                    onFoodDetected: { analysis, image, imageHash, inputMethod in
                        foodAnalysis = analysis
                        // Only save if this is a new analysis (has image) or doesn't exist in cache
                        // If imageHash is provided but image is nil, it means we're viewing a cached item - don't save again
                        if let image = image, let imageHash = imageHash {
                            // New analysis with image - save it
                            print("🔍 ContentView: Saving new analysis with image, hash: \(imageHash)")
                            foodCacheManager.saveImage(image, forHash: imageHash)
                            // Use scanType from analysis, default to "meal" for backward compatibility
                            let scanType = analysis.scanType ?? "meal"
                            foodCacheManager.cacheAnalysis(analysis, imageHash: imageHash, scanType: scanType, inputMethod: nil) // Image entries have nil inputMethod
                        } else if image == nil && imageHash == nil {
                            // New analysis without image (text input, voice, etc.) - save it
                            print("🔍 ContentView: Saving new analysis without image, inputMethod: \(inputMethod ?? "unknown")")
                            foodCacheManager.cacheAnalysis(analysis, inputMethod: inputMethod)
                        } else {
                            // Viewing cached analysis (imageHash provided but no image) - don't save again
                            print("🔍 ContentView: Viewing cached analysis, not saving again")
                        }
                        showingResults = true
                    },
                    onFoodsCompared: { analyses in
                        compareAnalyses = analyses
                        // The sheet will automatically show when compareAnalyses changes
                    },
                    onShowCompareView: {
                        showingCompareView = true
                    },
                    onRecipeTapped: { recipe in
                        selectedRecipe = recipe
                    }
                )
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
                .overlay(
                    Group {
                        if showingSideMenu {
                            SideMenuView(isPresented: $showingSideMenu)
                                .transition(.move(edge: .leading))
                                .animation(.easeInOut(duration: 0.3), value: showingSideMenu)
                        }
                    }
                )
            }
            .tabItem {
                Image(systemName: "scope")
                Text("Score")
            }
            .tag(0)
            
            // Recipes Tab
            RecipesView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Recipes")
                }
                .tag(1)
            
            // Groceries Tab (formerly Scan)
            NavigationView {
                ScannerTabView(
                    onScanTapped: {
                        showingScanner = true
                    },
                    showingSideMenu: $showingSideMenu
                )
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
                .overlay(
                    Group {
                        if showingSideMenu {
                            SideMenuView(isPresented: $showingSideMenu)
                                .transition(.move(edge: .leading))
                                .animation(.easeInOut(duration: 0.3), value: showingSideMenu)
                        }
                    }
                )
            }
            .tabItem {
                Image(systemName: "cart.fill")
                Text("Shop")
            }
            .tag(2)
            
            // Favorites Tab
            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Favorites")
                }
                .tag(3)
            
            // Meal Tracking Tab (Tracker - far right)
            MealTrackingView(selectedTab: $currentTab)
                .tabItem {
                    Image(systemName: "fork.knife")
                    Text("Tracker")
                }
                .tag(4)
        }
        .sheet(isPresented: $showingResults) {
            let _ = print("ContentView: Presenting ResultsView with foodAnalysis: \(foodAnalysis?.foodName ?? "nil")")
            let _ = print("ContentView: showingResults is \(showingResults)")
            if let analysis = foodAnalysis {
                ResultsView(
                    analysis: analysis, 
                    onNewSearch: {
                        print("ContentView: ResultsView onNewSearch called")
                        showingResults = false
                        foodAnalysis = nil
                        shouldClearSearchInput = true
                    },
                    onMealAdded: {
                        // Switch to meal tracker tab after adding meal
                        currentTab = 4 // Tracker tab is now tag 4
                        showingResults = false
                    }
                )
            } else {
                let _ = print("ContentView: foodAnalysis is nil!")
                Text("Error: No analysis data")
            }
        }
        .sheet(isPresented: $showingMealResults) {
            let _ = print("ContentView: Presenting MealResultsView with \(mealAnalyses.count) analyses")
            let _ = mealAnalyses.enumerated().forEach { index, analysis in
                print("ContentView: Presenting analysis \(index + 1): \(analysis.foodName) - Score: \(analysis.overallScore)")
            }
            MealResultsView(analyses: mealAnalyses, onNewMeal: {
                print("ContentView: Clearing meal analyses")
                showingMealResults = false
                mealAnalyses = []
                shouldClearSearchInput = true
            })
        }
        .sheet(isPresented: $showingCompareResults) {
            CompareResultsView(analyses: compareAnalyses, onNewCompare: {
                showingCompareResults = false
                compareAnalyses = []
            })
        }
        .sheet(isPresented: $showingCompareView) {
            CompareView { analyses in
                compareAnalyses = analyses
                showingCompareView = false
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ScannerViewController(
                isPresented: $showingScanner,
                onBarcodeCaptured: { image, barcode in
                    print("ContentView: Barcode image captured, barcode: \(barcode ?? "none")")
                    
                    // Store barcode image and barcode for analysis
                    capturedImage = image
                    detectedBarcode = barcode
                    
                    // Generate hash for barcode image
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        currentImageHash = FoodCacheManager.hashImage(imageData)
                    }
                    
                    // Start analysis immediately (don't wait for front label)
                    analyzeScannedImage(image, barcode: barcode)
                },
                onFrontLabelCaptured: { image in
                    print("ContentView: Front label image captured")
                    
                    // Store front label image for grid display
                    frontLabelImage = image
                    
                    // Generate hash for front label image
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        frontLabelImageHash = FoodCacheManager.hashImage(imageData)
                    }
                    
                    // Extract product name from front label using OCR
                    // This will update the analysis if a better name is found
                    extractProductNameFromFrontLabel(image: image)
                    
                    // Dismiss camera
                    showingScanner = false
                    
                    // Show results sheet after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingScanResult = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingScanResult) {
            // Show loading state if analysis is nil, or results if analysis exists
            ScanResultView(
                scanType: scanType,
                analysis: scanResultAnalysis,
                image: frontLabelImage ?? capturedImage, // Show front label if available, otherwise barcode image
                isAnalyzing: scanResultAnalysis == nil,
                needsBackScan: needsBackScan,
                onTrack: {
                    // Track food/meal - add to Meal Tracker immediately
                    // Only save if front label image was captured (required for grid display)
                    if let analysis = scanResultAnalysis, let frontLabel = frontLabelImage, let frontLabelHash = frontLabelImageHash {
                        // Store front label image (this is what appears in the grid)
                        foodCacheManager.saveImage(frontLabel, forHash: frontLabelHash)
                        // Cache analysis with front label image hash for grid display
                        foodCacheManager.cacheAnalysis(analysis, imageHash: frontLabelHash, scanType: scanType.rawValue, inputMethod: nil)
                        print("ContentView: Saved analysis with front label image to grid")
                    } else {
                        print("ContentView: Cannot save - front label image not captured yet")
                    }
                    showingScanResult = false
                    currentImageHash = nil
                    frontLabelImageHash = nil
                    capturedImage = nil
                    frontLabelImage = nil
                    currentTab = 3 // Switch to Meals tab (now tag 3)
                },
                onSave: {
                    // Save product/supplement - save to Recently Analyzed
                    // Only save if front label image was captured (required for grid display)
                    if let analysis = scanResultAnalysis, let frontLabel = frontLabelImage, let frontLabelHash = frontLabelImageHash {
                        // Store front label image (this is what appears in the grid)
                        foodCacheManager.saveImage(frontLabel, forHash: frontLabelHash)
                        // Cache analysis with front label image hash for grid display
                        foodCacheManager.cacheAnalysis(analysis, imageHash: frontLabelHash, scanType: scanType.rawValue, inputMethod: nil)
                        print("ContentView: Saved analysis with front label image to grid")
                    } else {
                        print("ContentView: Cannot save - front label image not captured yet")
                    }
                    showingScanResult = false
                    currentImageHash = nil
                    frontLabelImageHash = nil
                    capturedImage = nil
                    frontLabelImage = nil
                },
                onScanAgain: {
                    // Scan again - reopen camera immediately
                    showingScanResult = false
                    scanResultAnalysis = nil
                    capturedImage = nil
                    frontLabelImage = nil
                    currentImageHash = nil
                    frontLabelImageHash = nil
                    currentOpenFoodFactsProduct = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingScanner = true
                    }
                },
                onDismiss: {
                    showingScanResult = false
                    scanResultAnalysis = nil
                    capturedImage = nil
                    currentImageHash = nil
                }
            )
            .presentationBackground(.clear) // Make sheet background transparent so photo shows through
        }
        .overlay(
            // Recipe URL Banner
            VStack {
                if showingRecipeBanner {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.white)
                        Text("Recipe URL received - parsing will come in Stage 3")
                            .foregroundColor(.white)
                            .font(.caption)
                        Spacer()
                        Button("Dismiss") {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showingRecipeBanner = false
                            }
                        }
                        .foregroundColor(.white)
                        .font(.caption)
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: showingRecipeBanner)
        )
        .onReceive(NotificationCenter.default.publisher(for: .recipeImportRequested)) { notification in
            print("ContentView: Received recipe import notification")
            
            if let userInfo = notification.userInfo,
               let url = userInfo["url"] as? URL {
                print("ContentView: Recipe URL received: \(url.absoluteString)")
                recipeURL = url.absoluteString
                withAnimation(.easeIn(duration: 0.3)) {
                    showingRecipeBanner = true
                }
                
                // Auto-dismiss banner after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingRecipeBanner = false
                    }
                }
            }
        }
        .onChange(of: shouldClearSearchInput) { oldValue, newValue in
            if newValue {
                // Reset the flag after a short delay to allow the SearchView to process it
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    shouldClearSearchInput = false
                }
            }
        }
        .onChange(of: mealAnalyses) { oldValue, newValue in
            print("ContentView: mealAnalyses changed from \(oldValue.count) to \(newValue.count) items")
        }
        .onChange(of: compareAnalyses) { oldValue, newValue in
            print("ContentView: compareAnalyses changed from \(oldValue.count) to \(newValue.count) items")
            if newValue.count > 0 && !showingCompareResults {
                print("ContentView: Auto-showing CompareResults sheet with \(newValue.count) analyses")
                showingCompareResults = true
            }
        }
        .onChange(of: showingResults) { oldValue, newValue in
            print("ContentView: showingResults changed from \(oldValue) to \(newValue)")
            if newValue {
                print("ContentView: showingResults is now true, foodAnalysis is \(foodAnalysis?.foodName ?? "nil")")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToRecipesTab)) { notification in
            print("ContentView: Received navigateToRecipesTab notification")
            // Navigate to Recipes tab (tag 1)
            currentTab = 1
        }
    }
    
    // MARK: - Scanner Functions
    
    private func analyzeScannedImage(_ image: UIImage, barcode: String? = nil) {
        print("Scanner: Starting image analysis, barcode: \(barcode ?? "none")")
        
        // Reset state
        scanResultAnalysis = nil
        needsBackScan = false
        scanType = .food
        
        // Phase 1: Barcode detection complete - barcode is now available
        // Phase 2: Will use barcode for OpenFoodFacts lookup
        
        // Optimize image (resize + compress) for faster API uploads
        guard let imageData = image.optimizedForAPI() else {
            print("Scanner: Failed to optimize image")
            showingScanResult = false
            return
        }
        
        // Generate image hash for caching (barcode image - used for analysis only, not saved to grid)
        let imageHash = FoodCacheManager.hashImage(imageData)
        currentImageHash = imageHash
        print("Scanner: Image hash: \(imageHash)")
        
        // Check cache first (using barcode image hash for lookup)
        if let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
            print("Scanner: Found cached analysis, score: \(cachedAnalysis.overallScore)")
            scanResultAnalysis = cachedAnalysis
            determineScanTypeAndBackScanNeeded(analysis: cachedAnalysis)
            return
        }
        
        // Note: We do NOT save the barcode image here - it's only used for analysis
        // The front label image will be saved when user taps Save/Track
        
        // TIERED BACKUP SYSTEM (Phase 3)
        // Tier 1: OpenFoodFacts API (if barcode available)
        // Tier 2: AI Vision API (fallback)
        
        if let barcode = barcode, !barcode.isEmpty {
            print("Scanner: Barcode detected, attempting Tier 1: OpenFoodFacts lookup")
            
            Task {
                do {
                    // Tier 1: Try OpenFoodFacts API
                    if let product = try await OpenFoodFactsService.shared.getProduct(barcode: barcode) {
                        // Store OpenFoodFacts product for OCR name extraction
                        await MainActor.run {
                            self.currentOpenFoodFactsProduct = product
                        }
                        
                        // Check if product has meaningful nutrition data before using it
                        if OpenFoodFactsService.shared.hasMeaningfulNutritionData(product) {
                            print("Scanner: Tier 1 SUCCESS - Product found in OpenFoodFacts with nutrition data, sending to AI Vision for scoring")
                            
                            // Use AI Vision for scoring, but pass OpenFoodFacts data for authoritative nutrition facts
                            await performTier2Analysis(image: image, imageHash: imageHash, openFoodFactsProduct: product)
                            return // Success - exit early
                        } else {
                            print("Scanner: Tier 1 - Product found but missing nutrition data, falling back to Tier 2")
                            // Fall through to Tier 2
                        }
                    } else {
                        print("Scanner: Tier 1 FAILED - Product not found in OpenFoodFacts, falling back to Tier 2")
                        // Fall through to Tier 2
                    }
                } catch {
                    print("Scanner: Tier 1 ERROR - \(error.localizedDescription), falling back to Tier 2")
                    // Fall through to Tier 2
                }
                
                // Tier 2: Fallback to AI Vision API (no OpenFoodFacts data)
                await performTier2Analysis(image: image, imageHash: imageHash, openFoodFactsProduct: nil)
            }
        } else {
            print("Scanner: No barcode detected, using Tier 2: AI Vision API")
            
            // Tier 2: AI Vision API (no barcode available)
            Task {
                await performTier2Analysis(image: image, imageHash: imageHash, openFoodFactsProduct: nil)
            }
        }
    }
    
    // MARK: - Tier 2: AI Vision API Fallback
    
    private func performTier2Analysis(image: UIImage, imageHash: String, openFoodFactsProduct: OpenFoodFactsProduct?) async {
        // Optimize image (resize + compress) for faster API uploads
        guard let imageData = image.optimizedForAPI() else {
            print("Scanner: Failed to optimize image")
            await MainActor.run {
                showingScanResult = false
            }
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        print("Scanner: Tier 2 - Calling OpenAI Vision API\(openFoodFactsProduct != nil ? " with OpenFoodFacts data" : "")")
        
        do {
            let analysis = try await analyzeImageWithOpenAI(base64Image: base64Image, imageHash: imageHash, openFoodFactsProduct: openFoodFactsProduct)
            
            await MainActor.run {
                print("Scanner: Tier 2 - Analysis received, score: \(analysis.overallScore)")
                scanResultAnalysis = analysis
                determineScanTypeAndBackScanNeeded(analysis: analysis)
                
                // Note: Do NOT cache analysis here - wait for front label image to be captured
                // Analysis will be cached when user taps Save/Track with front label image hash
            }
        } catch {
            print("Scanner: Tier 2 - Analysis failed: \(error.localizedDescription)")
            await MainActor.run {
                showingScanResult = false
            }
        }
    }
    
    private func analyzeImageWithOpenAI(base64Image: String, imageHash: String, openFoodFactsProduct: OpenFoodFactsProduct?) async throws -> FoodAnalysis {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Get user health profile for personalization
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let top3Goals = Array(healthGoals.prefix(3))
        let healthGoalsText = top3Goals.isEmpty ? "general health and longevity" : top3Goals.joined(separator: ", ")
        
        // Determine meal timing based on current time
        let hour = Calendar.current.component(.hour, from: Date())
        let mealTiming: String
        switch hour {
        case 5..<11: mealTiming = "breakfast"
        case 11..<15: mealTiming = "lunch"
        case 15..<20: mealTiming = "dinner"
        default: mealTiming = "meal"
        }
        
        // Build OpenFoodFacts data section if available
        var openFoodFactsSection = ""
        if let product = openFoodFactsProduct {
            // Use the same clean name building logic as OpenFoodFactsService
            let productName = buildCleanProductNameForPrompt(
                brand: product.brands,
                productNameEnImported: product.productNameEnImported,
                productNameEn: product.productNameEn,
                productName: product.productName
            )
            let ingredients = product.ingredientsText ?? ""
            let novaGroup = product.novaGroup.map { String($0) } ?? "unknown"
            
            // Format nutrition data
            var nutritionData = ""
            if let nutriments = product.nutriments {
                if let calories = nutriments.energyKcalServing ?? nutriments.energyKcal100g {
                    nutritionData += "Calories: \(Int(calories)) kcal\n"
                }
                if let protein = nutriments.proteinsServing ?? nutriments.proteins100g {
                    nutritionData += "Protein: \(String(format: "%.1f", protein))g\n"
                }
                if let carbs = nutriments.carbohydratesServing ?? nutriments.carbohydrates100g {
                    nutritionData += "Carbohydrates: \(String(format: "%.1f", carbs))g\n"
                }
                if let fat = nutriments.fatServing ?? nutriments.fat100g {
                    nutritionData += "Fat: \(String(format: "%.1f", fat))g\n"
                }
                if let sugar = nutriments.sugarsServing ?? nutriments.sugars100g {
                    nutritionData += "Sugar: \(String(format: "%.1f", sugar))g\n"
                }
                if let fiber = nutriments.fiberServing ?? nutriments.fiber100g {
                    nutritionData += "Fiber: \(String(format: "%.1f", fiber))g\n"
                }
                if let sodium = nutriments.sodiumServing ?? nutriments.sodium100g {
                    let sodiumMg = sodium * 1000
                    nutritionData += "Sodium: \(Int(sodiumMg))mg\n"
                }
            }
            
            openFoodFactsSection = """
            
            ════════════════════════════════════════════════════════════════════════════
            AUTHORITATIVE PRODUCT DATA FROM OPENFOODFACTS DATABASE:
            ════════════════════════════════════════════════════════════════════════════
            
            Product Name: \(productName)
            NOVA Group (Processing Level): \(novaGroup) (1=unprocessed, 2=minimally processed, 3=processed, 4=ultra-processed)
            
            NUTRITION FACTS (per serving or per 100g):
            \(nutritionData.isEmpty ? "Not available" : nutritionData)
            
            INGREDIENTS:
            \(ingredients.isEmpty ? "Not available" : ingredients)
            
            CRITICAL INSTRUCTIONS FOR USING THIS DATA:
            - Use the nutrition facts above as AUTHORITATIVE - they are from the product database
            - Use the product name and brand from above (don't guess from image)
            - Use NOVA group to help determine processing level for scoring
            - Still analyze the image for visual context, but prioritize the data above
            - Score based on the complete product information (name, ingredients, nutrition, NOVA group)
            
            ════════════════════════════════════════════════════════════════════════════
            
            """
        }
        
        let prompt = """
        You are a precision nutrition analysis system. Analyze this image and return ONLY valid JSON.
        \(openFoodFactsSection)
        🚫 CRITICAL PROHIBITION - READ THIS FIRST:
        NEVER mention age, gender, or demographics in the summary. Examples of FORBIDDEN phrases:
        - "young male", "young female", "adult", "elderly"
        - "men", "women", "males", "females"
        - "under 30", "over 50", any age reference
        - "particularly beneficial for a [demographic]"
        - "especially for [demographic]"
        
        If you see these terms in your response, DELETE THEM. Use ONLY "your", "you", "your body", "your goals" - never demographic terms.

        STEP 1: Identify the scan type (CRITICAL - determines how item is stored):
        - "meal" = prepared dishes eaten as meals (plated food with multiple components, sandwiches, salads with toppings, pizza, breakfast/lunch/dinner combinations, anything that looks like it's being eaten as a meal)
        - "food" = individual ready-to-eat items (single fruits like apple/banana/orange, individual snacks like cookie or handful of nuts, single beverages like glass of juice or cup of coffee, ready-to-eat single items)
        - "product" = packaged products requiring preparation (boxed/packaged items like box of pasta or cereal box, canned goods like can of beans or tomato sauce, raw ingredients like raw meat or bag of flour, anything in store packaging not yet prepared)
        - "supplement" = supplement bottle/package
        - "nutrition_label" = nutrition facts panel only
        - "supplement_facts" = supplement facts panel only
        
        CLASSIFICATION RULES:
        - If image shows a complete meal on a plate with multiple components → "meal"
        - If image shows a single ready-to-eat item (apple, cookie, glass of juice) → "food"
        - If image shows packaged/unprepared items (box, can, raw ingredients) → "product"
        - Default to "food" if classification is unclear

        STEP 2: Analyze the image and prioritize main ingredients:
        - Focus on ingredients with LARGER PORTIONS first (main proteins, starches, vegetables)
        - IGNORE small garnishes (lemon wedges, parsley sprigs, decorative herbs, small condiments)
        - Prioritize by visual size/portion: largest components → medium components → ignore tiny garnishes
        - Example: For a salmon bowl with rice, vegetables, and a lemon wedge → focus on salmon, rice, vegetables. Ignore the lemon wedge unless it's a main component.
        - Only mention garnishes if they significantly impact nutrition (e.g., large amounts of sauce, cheese, etc.)

        Extract nutritional data:
        \(openFoodFactsProduct != nil ? """
        - AUTHORITATIVE DATA PROVIDED: Use the nutrition facts from OpenFoodFacts database above (they are accurate and complete)
        - Still analyze the image for visual context and product appearance
        - Use the product name and ingredients from OpenFoodFacts data above
        """ : """
        - For products/supplements: Read ALL values from visible nutrition labels
        - For foods/meals: Estimate based on standard serving sizes of MAIN INGREDIENTS
        - Use exact values from labels when visible, estimates when not
        """)

        STEP 3: Score using these EXACT ranges:
        - Whole foods (apple, salmon, broccoli): 70-95
        - Minimally processed (whole grain bread, plain yogurt): 60-75
        - Processed foods (white bread, crackers): 40-60
        - Desserts/sweets (cake, cookies, pie): 30-50 (penalize sugar/flour heavily)
        - Fast food/highly processed: 20-40

        SCORING RULES:
        - Use precise integers (42, 73, 87) NOT rounded (45, 75, 85)
        - Penalize added sugars: -15 to -25 points
        - Penalize refined flour: -10 to -15 points
        - Penalize processed ingredients: -5 to -15 points
        - For desserts: Healthy ingredients (fruit) do NOT offset sugar/flour penalties

        INDIVIDUAL HEALTH SCORES CALCULATION (CRITICAL):
        Each individual health score (heartHealth, brainHealth, antiInflammation, etc.) MUST reflect the COMPLETE food/recipe composition, NOT just the positive ingredients.
        
        SCORING RULES FOR INDIVIDUAL HEALTH SCORES:
        - Start with the base score from positive ingredients (e.g., apples provide fiber → good for heart)
        - Then APPLY THE SAME PENALTIES as the overallScore:
          * Added sugars: Reduce heartHealth by 15-20 points, bloodSugar by 20-25 points, weightManagement by 15-20 points
          * Refined flour: Reduce heartHealth by 10-15 points, bloodSugar by 10-15 points, energy by 8-12 points
          * Unhealthy fats: Reduce heartHealth by 8-12 points, antiInflammation by 10-15 points
          * Processed ingredients: Reduce immune by 5-10 points, skin by 5-10 points
        
        EXAMPLES FOR DESSERTS:
        - Apple Pie (overallScore: 42):
          * heartHealth: Start with apples (fiber benefits) = 75, but subtract 15 for sugar + 12 for refined flour = 48
          * brainHealth: Start with apples (antioxidants) = 70, but subtract 10 for sugar + 8 for refined flour = 52
          * bloodSugar: Start with apples (fiber helps) = 60, but subtract 25 for sugar + 15 for refined flour = 20
          * weightManagement: Start with apples (fiber) = 65, but subtract 20 for sugar + 12 for refined flour = 33
          * antiInflammation: Start with apples (antioxidants) = 75, but subtract 12 for unhealthy fats + 8 for processed ingredients = 55
        
        - For complex meals (lasagna, pizza, etc.): Apply the same logic - consider ALL ingredients, not just the healthy ones
        
        CRITICAL: The individual health scores should be CONSISTENT with the overallScore. If overallScore is 42 (FAIR), individual scores should generally be in the 30-60 range, NOT 70-80. Only whole, unprocessed foods should have individual scores in the 70-90 range.

        CRITICAL: For complex foods (pie, lasagna, pizza), you MUST:
        1. List ALL major ingredients in the ingredients array (prioritize by portion size)
        2. Score based on COMPLETE composition, not just main ingredient
        3. Focus on ingredients that make up the largest portions of the meal
        4. Example: "Peach pie" = peaches + crust + sugar + butter + flour (score ~41, not 80)
        5. Example: "Grilled salmon with rice and lemon wedge" → focus on salmon and rice, ignore lemon wedge unless it's a significant portion

        FOR SUPPLEMENTS (scanType = "supplement" or "supplement_facts"):
        - The "summary" field must be exactly 3 sentences:
          1. First sentence: Strengths and benefits for common health concerns
          2. Second sentence: Weaknesses, limitations, or concerns for health
          3. Third sentence: Any recalls, safety warnings, or hazards (if none, state "No known recalls or safety hazards")
        - Example: "This supplement provides strong antioxidant support and may benefit heart health. However, it may interact with blood-thinning medications and is not recommended during pregnancy. No known recalls or safety hazards have been reported."

        FOR PRODUCTS (scanType = "product" or "nutrition_label"):
        - For "bestPreparation": Leave as "TBD" - this will be generated separately
        - Focus on extracting accurate product name, nutrition data, and scoring

        ════════════════════════════════════════════════════════════════════════════
        SUMMARY GUIDELINES (CRITICAL - READ THIS FIRST BEFORE WRITING SUMMARY):
        ════════════════════════════════════════════════════════════════════════════

        You are writing a 1-2 sentence meal analysis for a longevity app. Be brutally honest, specific, and SHORT.

        RULES:

        1. MAX 40 words total

        2. Lead with the most shocking/specific fact about MAIN INGREDIENTS (largest portions)

        3. Focus on MAIN INGREDIENTS ONLY (largest portions on the plate). Ignore small garnishes, decorative elements, or tiny side items unless they significantly impact the meal's nutrition.

        4. Never lecture or use "should"

        5. Include ONE specific number (grams, calories, glucose spike, etc.) from the MAIN INGREDIENTS

        6. End with impact on their personal goal: \(healthGoalsText)

        BAD (mushy/preachy):
        "Apple pie with ice cream is a traditional dessert that provides enjoyment but should be consumed in moderation, especially for individuals focusing on blood sugar control."

        GOOD EXAMPLES:

        Apple Pie + Ice Cream (Score: 44):
        "This dessert packs 65g of sugar—triggering a glucose spike 3x higher than your body can efficiently process. Save it for special occasions if weight loss is your goal."

        Salmon Bowl (Score: 92):
        "Wild salmon's 3g omega-3s combined with kale's sulforaphane activate cellular repair pathways that peak 4 hours after eating—perfect timing for your \(healthGoalsText) goals."

        McDonald's Big Mac (Score: 38):
        "With 563 calories and only 2g of fiber, this meal will leave you hungry again in 90 minutes while the 33g of processed fat disrupts your metabolic health targets."

        Green Smoothie (Score: 81):
        "Your smoothie's 8g of fiber slows sugar absorption by 40%, while spinach's folate boosts cellular energy production—directly supporting your \(healthGoalsText) goals."

        Pizza Slice (Score: 52):
        "Each slice delivers 285 calories but zero longevity nutrients, plus refined flour that ages your cells faster than whole grains would."

        FORMAT:
        [Specific fact with number about MAIN INGREDIENTS] + [Direct biological impact] + [Connection to their goal if relevant]

        PRIORITIZATION RULE:
        - Always focus on the largest/most substantial components of the meal
        - Ignore decorative elements, small garnishes, or tiny side items
        - If unsure, prioritize by visual size/portion in the image

        NEVER USE:
        - "Should be consumed"
        - "In moderation"
        - "Traditional"
        - "Provides enjoyment"
        - "It's important to"
        - "Individuals focusing on"
        - Generic health words (wholesome, nutritious, beneficial)
        - "the user's", "users", "people", "individuals", "adults", "young males", "women", "men" → ALWAYS use "your" or "you"
        - "particularly beneficial for a [demographic]" or "especially for [demographic]" → NEVER mention demographics
        - Age references: "under 30", "over 50", "young", "elderly" → NEVER mention age

        Keep it conversational but authoritative. Make them feel the immediate impact of their food choice.

        IMPORTANT NOTES:
        - For meals (scanType="meal"), you MUST include a "foodNames" array listing all visible food items (e.g., ["Grilled Chicken", "Avocado", "Mixed Greens", "Tomatoes"]). This is required for the app to show multiple foods in the detection popup.
        - For single foods (scanType="food"), "foodNames" can be omitted or contain just the single food name.
        - Do NOT include keyBenefits, ingredients, nutritionInfo, or bestPreparation in the initial response. These will be loaded on demand.

        ════════════════════════════════════════════════════════════════════════════
        Return ONLY this JSON structure (no markdown, no explanation):
        ════════════════════════════════════════════════════════════════════════════
        {
            "scanType": "food|meal|product|supplement|nutrition_label|supplement_facts",
            "foodName": "Exact name from image or standard name",
            "foodNames": ["Food 1", "Food 2", "Food 3"],
            "needsBackScan": true|false,
            "overallScore": 0-100,
            "summary": "Write 1-2 sentences, MAX 40 words. Lead with shocking/specific fact. Include ONE specific number. End with impact on: \(healthGoalsText). NO 'should', 'in moderation', 'traditional', 'provides enjoyment'. Use 'your' not 'the user's'. (For supplements: 3 sentences: strengths, weaknesses, recalls/hazards)",
            "healthScores": {
                "allergies": 0-100,
                "antiInflammation": 0-100,
                "bloodSugar": 0-100,
                "brainHealth": 0-100,
                "detoxLiver": 0-100,
                "energy": 0-100,
                "eyeHealth": 0-100,
                "heartHealth": 0-100,
                "immune": 0-100,
                "jointHealth": 0-100,
                "kidneys": 0-100,
                "mood": 0-100,
                "skin": 0-100,
                "sleep": 0-100,
                "stress": 0-100,
                "weightManagement": 0-100
            },
            "servingSize": "Standard serving"
        }
        """
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 500,
            "temperature": 0.1,
            "response_format": [
                "type": "json_object"
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: nil)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw NSError(domain: "Invalid response format", code: 0, userInfo: nil)
        }
        
        // Strip markdown code blocks if present
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```") {
            let lines = cleanedText.components(separatedBy: .newlines)
            var jsonLines = lines
            if let firstLine = jsonLines.first, firstLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                jsonLines.removeFirst()
            }
            if let lastLine = jsonLines.last, lastLine.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                jsonLines.removeLast()
            }
            cleanedText = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let analysisData = cleanedText.data(using: .utf8) else {
            throw NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)
        }
        
        // Parse scan type from response and decode analysis
        let responseDict = try JSONSerialization.jsonObject(with: analysisData) as? [String: Any]
        let scanTypeString = responseDict?["scanType"] as? String
        let parsedNeedsBackScan = responseDict?["needsBackScan"] as? Bool ?? false
        
        print("Scanner: Step 1 complete - scanType: \(scanTypeString ?? "nil"), productName: \(responseDict?["foodName"] as? String ?? "unknown")")
        
        // Decode analysis with scanType
        var analysis = try JSONDecoder().decode(FoodAnalysis.self, from: analysisData)
        
        // If scanType wasn't in the decoded struct, add it manually
        if analysis.scanType == nil, let scanTypeString = scanTypeString {
            analysis = FoodAnalysis(
                foodName: analysis.foodName,
                overallScore: analysis.overallScore,
                summary: analysis.summary,
                healthScores: analysis.healthScores,
                keyBenefits: analysis.keyBenefits ?? [],
                ingredients: analysis.ingredients ?? [],
                bestPreparation: analysis.bestPreparation ?? "",
                servingSize: analysis.servingSize,
                nutritionInfo: analysis.nutritionInfo,
                scanType: scanTypeString,
                foodNames: analysis.foodNames,
                suggestions: analysis.suggestions
            )
        }
        
        // Merge OpenFoodFacts nutrition data if available (authoritative source)
        if let product = openFoodFactsProduct, let nutriments = product.nutriments {
            let nutritionInfo = OpenFoodFactsService.shared.mapNutritionInfo(from: nutriments)
            let servingSize = product.nutriments?.servingSize ?? analysis.servingSize
            
            // Use OpenFoodFacts product name (with brand) as authoritative source
            // The AI might return generic names like "Yogurt" but OpenFoodFacts has the exact product name
            let openFoodFactsProductName = buildCleanProductNameForPrompt(
                brand: product.brands,
                productNameEnImported: product.productNameEnImported,
                productNameEn: product.productNameEn,
                productName: product.productName
            )
            
            // Always prefer OpenFoodFacts name when available (it's authoritative from barcode lookup)
            // This ensures we get "Fage Total 2% Yogurt" instead of just "Yogurt"
            let finalProductName = (!openFoodFactsProductName.isEmpty && 
                                   openFoodFactsProductName.lowercased() != "unknown product") 
                                   ? openFoodFactsProductName 
                                   : analysis.foodName
            
            analysis = FoodAnalysis(
                foodName: finalProductName,
                overallScore: analysis.overallScore,
                summary: analysis.summary,
                healthScores: analysis.healthScores,
                keyBenefits: analysis.keyBenefits ?? [],
                ingredients: analysis.ingredients ?? [],
                bestPreparation: analysis.bestPreparation ?? "",
                servingSize: servingSize,
                nutritionInfo: nutritionInfo,
                scanType: analysis.scanType,
                foodNames: analysis.foodNames,
                suggestions: analysis.suggestions
            )
            
            print("Scanner: Merged OpenFoodFacts nutrition data into analysis")
            print("Scanner: Using product name: '\(finalProductName)' (OpenFoodFacts: '\(openFoodFactsProductName)', AI: '\(analysis.foodName)')")
        }
        
        print("Scanner: Decoded analysis - scanType: '\(analysis.scanType ?? "nil")', bestPreparation: '\(analysis.bestPreparation)'")
        
        // Step 2: Generate healthier choice recommendation for products (separate text-only call)
        if scanTypeString == "product" || scanTypeString == "nutrition_label" {
            print("Scanner: Step 2 triggered - generating healthier choice recommendation for product")
            do {
                print("Scanner: Calling generateHealthierChoiceRecommendation for: \(analysis.foodName), score: \(analysis.overallScore)")
                let healthierChoice = try await generateHealthierChoiceRecommendation(
                    productName: analysis.foodName,
                    currentScore: analysis.overallScore,
                    nutritionInfo: analysis.nutritionInfoOrDefault
                )
                
                print("Scanner: Step 2 complete - received recommendation: '\(healthierChoice)'")
                
                // Create updated analysis with new bestPreparation
                analysis = FoodAnalysis(
                    foodName: analysis.foodName,
                    overallScore: analysis.overallScore,
                    summary: analysis.summary,
                    healthScores: analysis.healthScores,
                    keyBenefits: analysis.keyBenefits ?? [],
                    ingredients: analysis.ingredients ?? [],
                    bestPreparation: healthierChoice,  // ← ONLY THIS CHANGES
                    servingSize: analysis.servingSize,
                    nutritionInfo: analysis.nutritionInfo,
                    scanType: analysis.scanType,
                    foodNames: analysis.foodNames,
                    suggestions: analysis.suggestions
                )
                
                print("Scanner: Updated analysis with new bestPreparation")
            } catch {
                // If Step 2 fails, keep original analysis with "TBD" or empty bestPreparation
                print("Scanner: Healthier choice generation failed: \(error.localizedDescription)")
                print("Scanner: Using original analysis with bestPreparation: '\(analysis.bestPreparation)'")
                // Continue with original analysis
            }
        } else {
            print("Scanner: Step 2 skipped - scanType is '\(scanTypeString ?? "nil")' (not product or nutrition_label)")
        }
        
        // Update scan type on main actor
        await MainActor.run {
            if let scanTypeString = scanTypeString {
                scanType = ScanType(rawValue: scanTypeString) ?? .food
            }
            needsBackScan = parsedNeedsBackScan
        }
        
        return analysis
    }
    
    // Step 2: Generate healthier choice recommendation (text-only, structured like pet foods)
    private func generateHealthierChoiceRecommendation(
        productName: String,
        currentScore: Int,
        nutritionInfo: NutritionInfo
    ) async throws -> String {
        print("Scanner: Step 2 - Starting generateHealthierChoiceRecommendation")
        
        // Get user preferences
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let dietaryPreference = healthProfileManager.currentProfile?.dietaryPreference ?? ""
        let healthGoalsText = healthGoals.isEmpty ? "general health" : healthGoals.joined(separator: ", ")
        let dietaryPreferenceText = dietaryPreference.isEmpty ? "None" : dietaryPreference
        
        print("Scanner: Step 2 - User health goals: \(healthGoalsText), dietary preference: \(dietaryPreferenceText)")
        
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Structured prompt similar to pet foods - text-only, focused on brand recommendations
        let prompt = """
        You are a nutrition expert. Find 1-2 healthier alternative products for this grocery item.
        
        Current Product: \(productName)
        Current Score: \(currentScore)/100
        User's Health Goals: \(healthGoalsText)
        User's Dietary Preference: \(dietaryPreferenceText)
        
        Find healthier alternatives that:
        1. Are in the same product category
        2. Would score 10-30 points higher than the current product
        3. Are widely available in US stores
        4. Have better ingredient quality and nutritional profiles
        
        Respond in this exact JSON format:
        {
          "recommendation": "[Brand Name 1] or [Brand Name 2]: [Specific benefit with exact numbers]. [How it specifically helps the user's primary health goal]. [Additional measurable benefit with numbers]."
        }
        
        REQUIREMENTS:
        - MUST include 1-3 REAL brand names (e.g., "Kerrygold", "Organic Valley", "Dave's Killer Bread", "Rao's", "Simple Mills", "Siete", "Ezekiel", "Amy's", "Annie's", "Applegate", "Muir Glen", "Fage", "Siggi's", "365 Whole Foods")
        - MUST include specific numbers (mg, g, %, etc.) - e.g., "50% more omega-3s (500mg)", "5g fiber per slice", "180mg sodium"
        - MUST reference the user's health goals directly
        - MUST be 2-4 sentences (3-4 lines)
        - NEVER use generic phrases like "Try:", "Higher nutritional value", "Better health impact", "Source of energy", "More nutritious", "Convenient source of carbohydrates", "Rich in"
        - Focus on POSITIVE, measurable benefits with specific numbers
        
        Base your recommendation on real brands and products available in the US market. Focus on products that genuinely offer better nutrition and ingredient quality.
        """
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 200,
            "temperature": 0.3,
            "response_format": [
                "type": "json_object"
            ],
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("Scanner: Step 2 - Making API request for healthier choice recommendation")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("Scanner: Step 2 - API request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: nil)
        }
        
        print("Scanner: Step 2 - API request successful, parsing response")
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            print("Scanner: Step 2 - Failed to parse response JSON")
            throw NSError(domain: "Invalid response format", code: 0, userInfo: nil)
        }
        
        print("Scanner: Step 2 - Received raw response text: '\(String(text.prefix(200)))...'")
        
        // Strip markdown code blocks if present
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```") {
            let lines = cleanedText.components(separatedBy: .newlines)
            var jsonLines = lines
            if let firstLine = jsonLines.first, firstLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                jsonLines.removeFirst()
            }
            if let lastLine = jsonLines.last, lastLine.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                jsonLines.removeLast()
            }
            cleanedText = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let recommendationData = cleanedText.data(using: .utf8) else {
            throw NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)
        }
        
        // Parse JSON response
        print("Scanner: Step 2 - Parsing JSON recommendation")
        guard let recommendationDict = try JSONSerialization.jsonObject(with: recommendationData) as? [String: Any] else {
            print("Scanner: Step 2 - ERROR: Failed to parse JSON as dictionary")
            throw NSError(domain: "Invalid JSON format", code: 0, userInfo: nil)
        }
        print("Scanner: Step 2 - Parsed JSON keys: \(recommendationDict.keys)")
        
        guard let recommendation = recommendationDict["recommendation"] as? String else {
            print("Scanner: Step 2 - ERROR: Missing 'recommendation' field in JSON. Available keys: \(recommendationDict.keys)")
            throw NSError(domain: "Missing recommendation field", code: 0, userInfo: nil)
        }
        
        print("Scanner: Step 2 - Successfully extracted recommendation: '\(recommendation)'")
        return recommendation.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Build a clean product name by removing duplicates and redundant information (same logic as OpenFoodFactsService)
    private func buildCleanProductNameForPrompt(
        brand: String?,
        productNameEnImported: String?,
        productNameEn: String?,
        productName: String?
    ) -> String {
        // Priority order: imported name > English name > product name
        var nameToUse: String?
        var isImportedName = false
        
        if let imported = productNameEnImported, !imported.isEmpty {
            nameToUse = imported
            isImportedName = true
        } else if let enName = productNameEn, !enName.isEmpty {
            nameToUse = enName
        } else if let name = productName, !name.isEmpty {
            nameToUse = name
        }
        
        // Handle imported names specially - they often have format "Brand, product name"
        if let name = nameToUse, isImportedName {
            let parts = name.components(separatedBy: ",")
            if parts.count > 1 {
                // Combine all parts (brand + product name) and clean
                let combined = parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
                nameToUse = removeDuplicateWords(from: combined)
            } else {
                // Single part, just clean it
                nameToUse = removeDuplicateWords(from: name)
            }
        } else if let name = nameToUse {
            // For non-imported names, clean normally
            nameToUse = removeDuplicateWords(from: name)
        }
        
        // Combine with brand if available and not already included
        if let brand = brand, !brand.isEmpty, let name = nameToUse {
            let brandLower = brand.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let nameLower = name.lowercased()
            
            // Check if brand (or significant parts of it) is already in the name
            let brandWords = brandLower.components(separatedBy: .whitespaces).filter { $0.count > 2 }
            let brandAlreadyInName = brandWords.contains { nameLower.contains($0) } || nameLower.contains(brandLower)
            
            if !brandAlreadyInName {
                // Combine brand + name, removing duplicate words
                let combined = "\(brand) \(name)"
                return removeDuplicateWords(from: combined)
            } else {
                // Brand already in name, just return cleaned name
                return name
            }
        } else if let name = nameToUse {
            return name
        } else if let brand = brand, !brand.isEmpty {
            return brand
        } else {
            return "Unknown Product"
        }
    }
    
    /// Remove duplicate words from a string (case-insensitive)
    private func removeDuplicateWords(from text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        var seenWords = Set<String>()
        var result: [String] = []
        
        for word in words {
            let wordLower = word.lowercased()
            // Skip empty strings and very short words (like "a", "an", "the")
            if word.isEmpty || (word.count <= 2 && wordLower != "hp") {
                continue
            }
            
            // Check if we've seen this word (case-insensitive)
            if !seenWords.contains(wordLower) {
                seenWords.insert(wordLower)
                result.append(word)
            }
        }
        
        return result.joined(separator: " ")
    }
    
    /// Extract product name from front label image using OCR and update analysis if better name found
    private func extractProductNameFromFrontLabel(image: UIImage) {
        // Get brand from OpenFoodFacts if available (helps OCR identify product name)
        let brand = currentOpenFoodFactsProduct?.brands
        
        ProductNameOCRService.shared.extractProductName(from: image, brand: brand) { ocrProductName in
            guard let ocrName = ocrProductName, !ocrName.isEmpty else {
                print("ContentView: OCR did not extract product name, keeping existing name")
                return
            }
            
            // Update analysis with OCR-extracted name if it's better
            // Note: Using MainActor to ensure thread-safe access to @State properties
            Task { @MainActor in
                guard let currentAnalysis = self.scanResultAnalysis else { return }
                // OCR name is better if it's longer/more descriptive than current name
                let currentName = currentAnalysis.foodName
                if ocrName.count > currentName.count || 
                   (ocrName.lowercased().contains("total") && !currentName.lowercased().contains("total")) ||
                   (ocrName.lowercased().contains("%") && !currentName.lowercased().contains("%")) {
                    
                print("ContentView: Updating product name from '\(currentName)' to OCR-extracted '\(ocrName)'")
                
                // Create updated analysis with OCR name
                let updatedAnalysis = FoodAnalysis(
                    foodName: ocrName,
                    overallScore: currentAnalysis.overallScore,
                    summary: currentAnalysis.summary,
                    healthScores: currentAnalysis.healthScores,
                    keyBenefits: currentAnalysis.keyBenefits ?? [],
                    ingredients: currentAnalysis.ingredients ?? [],
                    bestPreparation: currentAnalysis.bestPreparation ?? "",
                    servingSize: currentAnalysis.servingSize,
                    nutritionInfo: currentAnalysis.nutritionInfo,
                    scanType: currentAnalysis.scanType,
                    foodNames: currentAnalysis.foodNames,
                    suggestions: currentAnalysis.suggestions
                )
                
                self.scanResultAnalysis = updatedAnalysis
            } else {
                print("ContentView: OCR name '\(ocrName)' not better than current '\(currentName)', keeping current")
            }
            }
        }
    }
    
    private func determineScanTypeAndBackScanNeeded(analysis: FoodAnalysis) {
        // Determine if back scan is needed based on scan type and analysis
        if scanType == .product || scanType == .supplement {
            // Check if we have complete nutrition info
            let nutrition = analysis.nutritionInfoOrDefault
            let hasCompleteInfo = !nutrition.calories.isEmpty &&
                                 !nutrition.protein.isEmpty &&
                                 !nutrition.carbohydrates.isEmpty
            needsBackScan = !hasCompleteInfo
        } else {
            needsBackScan = false
        }
    }
}

// MARK: - Scanner Tab View

// MARK: - Grocery Sort Option Enum
enum GrocerySortOption: String, CaseIterable {
    case allGroceries = "All Groceries"
    case mostRecent = "Most Recent"
    case highestScore = "Highest Score"
    case lowestScore = "Lowest Score"
    case alphabetical = "Alphabetical"
}

// MARK: - Grocery View Mode Enum
enum GroceryViewMode {
    case list
    case grid
}

struct ScannerTabView: View {
    let onScanTapped: () -> Void
    @Binding var showingSideMenu: Bool
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var viewMode: GroceryViewMode = .list
    @State private var sortOption: GrocerySortOption = .allGroceries
    @State private var isEditing = false
    @State private var selectedScanIDs: Set<String> = []
    @State private var showingDeleteConfirmation = false
    @State private var displayedScanCount = 6
    @State private var selectedAnalysisItem: AnalysisItem?
    @Environment(\.colorScheme) var colorScheme
    
    // Wrapper for sheet presentation
    private struct AnalysisItem: Identifiable {
        let id = UUID()
        let analysis: FoodAnalysis
    }
    
    // Filter grocery scans (product or nutrition_label)
    private var groceryScans: [FoodCacheEntry] {
        foodCacheManager.cachedAnalyses.filter { entry in
            entry.scanType == "product" || entry.scanType == "nutrition_label"
        }
    }
    
    // Sorted grocery scans
    private var sortedGroceryScans: [FoodCacheEntry] {
        let scans = groceryScans
        switch sortOption {
        case .allGroceries, .mostRecent:
            return scans.sorted { $0.analysisDate > $1.analysisDate }
        case .highestScore:
            return scans.sorted { $0.fullAnalysis.overallScore > $1.fullAnalysis.overallScore }
        case .lowestScore:
            return scans.sorted { $0.fullAnalysis.overallScore < $1.fullAnalysis.overallScore }
        case .alphabetical:
            return scans.sorted { $0.foodName < $1.foodName }
        }
    }
    
    // Scans to display
    private var scansToDisplay: [FoodCacheEntry] {
        let sorted = sortedGroceryScans
        if viewMode == .grid {
            return sorted
        } else {
            return Array(sorted.prefix(displayedScanCount))
        }
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header - Horizontal Logo (centered)
                    Image("LogoHorizontal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 37)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.top, -8)
                    
                    // Grocery Scoring Box
                    VStack(spacing: 16) {
                        // Title with Icon (centered) - Button for scanning
                        Button(action: onScanTapped) {
                            VStack(spacing: 8) {
                                // Title with Icon (centered)
                                HStack(spacing: 16) {
                                    // Groceries Icon with Gradient (left of title) - matching Upload It gradient
                                    Image(systemName: "cart.fill")
                                        .font(.system(size: 60, weight: .medium))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 60, height: 60)
                                    
                                    Text("Score It")
                                        .font(.system(size: 50, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                        .foregroundColor(colorScheme == .dark ? .white : .secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Subtitle
                                Text("Tap here to scan your groceries while shopping to make healthier choices")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Hairline separator
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                            .padding(.horizontal, -30) // Extend to box edges
                        
                        // Edit and All Groceries Dropdown (inside box at bottom)
                        HStack {
                            // Edit/Cancel/Delete Button (left) - only show in grid view
                            if viewMode == .grid {
                                Button(action: {
                                    if !selectedScanIDs.isEmpty {
                                        showingDeleteConfirmation = true
                                    } else {
                                        isEditing.toggle()
                                        if !isEditing {
                                            selectedScanIDs.removeAll()
                                        }
                                    }
                                }) {
                                    Text(editButtonText)
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            // All Groceries Dropdown (right)
                            Menu {
                                ForEach(GrocerySortOption.allCases, id: \.self) { option in
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
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal, 10) // Padding for buttons within the box
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 30)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Recent Grocery Scans Section
                    if !groceryScans.isEmpty {
                        recentGroceryScansSection
                    }
                }
            }
        }
        .onAppear {
            // Set default view mode based on count
            if groceryScans.count > 6 {
                viewMode = .grid
            } else {
                viewMode = .list
            }
        }
        .sheet(item: $selectedAnalysisItem) { item in
            ResultsView(
                analysis: item.analysis,
                onNewSearch: {
                    selectedAnalysisItem = nil
                },
                onMealAdded: {
                    selectedAnalysisItem = nil
                }
            )
        }
    }
    
    // MARK: - Recent Grocery Scans Section
    private var recentGroceryScansSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title with Toggle Icons
            HStack {
                // List Icon (flush left)
                Button(action: {
                    viewMode = .list
                }) {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .foregroundColor(viewMode == .list ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Grid Icon (flush right)
                Button(action: {
                    viewMode = .grid
                }) {
                    Image(systemName: "square.grid.3x3")
                        .font(.title3)
                        .foregroundColor(viewMode == .grid ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 16)  // Increased padding above for easier tapping
            .padding(.bottom, 16)  // Increased padding below for easier tapping
            
            // Content: List or Grid
            if viewMode == .list {
                groceryScansListView
            } else {
                groceryScansGridView
            }
        }
        .padding(.horizontal, 0)
        .confirmationDialog("Delete Grocery Scans", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedScans()
            }
            Button("Cancel", role: .cancel) {
                // Deselect all items and exit edit mode
                selectedScanIDs.removeAll()
                isEditing = false
            }
        } message: {
            Text("Are you sure you want to delete \(selectedScanIDs.count) scan\(selectedScanIDs.count == 1 ? "" : "s")?")
        }
    }
    
    // MARK: - List View
    private var groceryScansListView: some View {
        VStack(spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(scansToDisplay, id: \.cacheKey) { entry in
                    GroceryScanRowView(entry: entry, onTap: { analysis in
                        selectedAnalysisItem = AnalysisItem(analysis: analysis)
                    }, onDelete: { cacheKey in
                        foodCacheManager.deleteAnalysis(withCacheKey: cacheKey)
                    })
                }
            }
            .padding(.horizontal, 20)
            
            // View More/Show Less Buttons (only in list view)
            if groceryScans.count > 6 {
                HStack(spacing: 12) {
                    // Show Less button (only if showing more than 6)
                    if displayedScanCount > 6 {
                        Button(action: {
                            displayedScanCount = max(6, displayedScanCount - 6)
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
                    if groceryScans.count > displayedScanCount {
                        Button(action: {
                            displayedScanCount = min(displayedScanCount + 6, groceryScans.count)
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
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
    
    // MARK: - Grid View
    private var groceryScansGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(scansToDisplay, id: \.cacheKey) { entry in
                GroceryScanGridCard(
                    entry: entry,
                    isEditing: isEditing,
                    isSelected: selectedScanIDs.contains(entry.cacheKey),
                    onTap: {
                        selectedAnalysisItem = AnalysisItem(analysis: entry.fullAnalysis)
                    },
                    onToggleSelection: {
                        if selectedScanIDs.contains(entry.cacheKey) {
                            selectedScanIDs.remove(entry.cacheKey)
                        } else {
                            selectedScanIDs.insert(entry.cacheKey)
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
    
    // MARK: - Edit Button Text
    private var editButtonText: String {
        if !selectedScanIDs.isEmpty {
            return "Delete"
        } else if isEditing {
            return "Cancel"
        } else {
            return "Edit"
        }
    }
    
    // MARK: - Delete Selected Scans
    private func deleteSelectedScans() {
        for cacheKey in selectedScanIDs {
            foodCacheManager.deleteAnalysis(withCacheKey: cacheKey)
        }
        selectedScanIDs.removeAll()
        // Stay in edit mode after deletion
        isEditing = true
    }
}

#Preview {
    ContentView()
}

