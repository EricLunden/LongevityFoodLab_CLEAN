import SwiftUI

struct SelectMealsView: View {
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @StateObject private var mealStorageManager = MealStorageManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedMealKeys: Set<String> = []
    @State private var sortOption: SortOption = .recency
    @State private var displayedMealCount = 6
    @State private var isShowingCamera = false
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var currentAnalysisImage: UIImage?
    @State private var analysisResult: FoodAnalysis?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var retryCount = 0
    @State private var lastAnalyzedImage: UIImage?
    
    let onMealsSelected: ([FoodAnalysis]) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if let analysis = analysisResult {
                    // Show ResultsView inline when analysis is complete (same as Score screen)
                    ResultsView(
                        analysis: analysis,
                        onNewSearch: {
                            // Clear analysis and return to meal list
                            analysisResult = nil
                            selectedImage = nil
                            currentAnalysisImage = nil
                        },
                        onMealAdded: {
                            // Dismiss SelectMealsView and return to Tracker
                            dismiss()
                        }
                    )
                } else {
                    // Show meal selection interface
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Take A Photo Box (at the top)
                            takeAPhotoBox
                                .padding(.top, 20)
                                .padding(.horizontal, 20)
                            
                            // Loading indicator if analyzing
                            if isAnalyzing {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    Text("Analyzing your meal...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                            
                            // Sort Picker
                            if !getSortedFoods().isEmpty && !isAnalyzing {
                                HStack {
                                    Text("Sort by:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Sort", selection: $sortOption) {
                                        ForEach(SortOption.allCases, id: \.self) { option in
                                            Text(option.rawValue).tag(option)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .font(.caption)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                            }
                            
                            // Meals List (using list-view cards like Recently Analyzed)
                            if !isAnalyzing {
                                if getSortedFoods().isEmpty {
                                    Text("No recently analyzed foods")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 40)
                                } else {
                                    let sortedFoods = getSortedFoods()
                                    let displayCount = min(displayedMealCount, sortedFoods.count)
                                    let mealsToShow = Array(sortedFoods.prefix(displayCount))
                                    
                                    LazyVStack(spacing: 12) {
                                        ForEach(mealsToShow, id: \.cacheKey) { entry in
                                            SelectMealRowView(
                                                entry: entry,
                                                isSelected: selectedMealKeys.contains(entry.cacheKey),
                                                onTap: {
                                                    toggleSelection(for: entry.cacheKey)
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    // View More/Show Less Buttons (same design as Score screen)
                                    if sortedFoods.count > 6 {
                                        HStack(spacing: 12) {
                                            // Show Less button (only if showing more than 6)
                                            if displayedMealCount > 6 {
                                                Button(action: {
                                                    displayedMealCount = max(6, displayedMealCount - 6)
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
                                            if sortedFoods.count > displayedMealCount {
                                                Button(action: {
                                                    displayedMealCount = min(displayedMealCount + 6, sortedFoods.count)
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
                                
                                // Spacer for floating button
                                Spacer()
                                    .frame(height: 100)
                            }
                        }
                    }
                    
                    // Floating "Add to Tracker" Button
                    if !selectedMealKeys.isEmpty && !isAnalyzing && analysisResult == nil {
                        VStack {
                            Spacer()
                            Button(action: {
                                addSelectedMealsToTracker()
                            }) {
                                Text("Add to Tracker")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
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
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: -2)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) { oldValue, newImage in
            if let image = newImage {
                analyzeImage(image)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("Try Again") {
                if let image = lastAnalyzedImage {
                    analyzeImage(image)
                }
            }
            Button("Cancel", role: .cancel) {
                isAnalyzing = false
                selectedImage = nil
                currentAnalysisImage = nil
                lastAnalyzedImage = nil  // Clear on cancel
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleSelection(for cacheKey: String) {
        if selectedMealKeys.contains(cacheKey) {
            selectedMealKeys.remove(cacheKey)
        } else {
            selectedMealKeys.insert(cacheKey)
        }
    }
    
    private func getSortedFoods() -> [FoodCacheEntry] {
        // Filter out groceries (product and nutrition_label) - only show meals and foods
        let filteredAnalyses = foodCacheManager.cachedAnalyses.filter { entry in
            let scanType = entry.fullAnalysis.scanType ?? "food"
            return scanType != "product" && scanType != "nutrition_label"
        }
        
        switch sortOption {
        case .recency:
            return filteredAnalyses.sorted { $0.analysisDate > $1.analysisDate }
        case .scoreHighLow:
            return filteredAnalyses.sorted { $0.fullAnalysis.overallScore > $1.fullAnalysis.overallScore }
        case .scoreLowHigh:
            return filteredAnalyses.sorted { $0.fullAnalysis.overallScore < $1.fullAnalysis.overallScore }
        }
    }
    
    private func addSelectedMealsToTracker() {
        let selectedAnalyses = foodCacheManager.cachedAnalyses.filter { selectedMealKeys.contains($0.cacheKey) }
            .map { $0.fullAnalysis }
        
        onMealsSelected(selectedAnalyses)
        dismiss()
    }
    
    // MARK: - Take A Photo Box
    private var takeAPhotoBox: some View {
        Button(action: {
            isShowingCamera = true
        }) {
            VStack(spacing: -10) {
                // Camera Icon with Gradient
                Image(systemName: "camera.fill")
                    .font(.system(size: 100, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.478, blue: 1.0), // Blue
                                Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 150, height: 150)
                
                // Text
                VStack(spacing: 2) {
                    Text("Snap Your Meal")
                        .font(.system(size: 40, weight: .bold, design: .default))
                        .foregroundColor(colorScheme == .dark ? .white : .secondary)
                    
                    // Subtitle
                    Text("To Add It To Your Daily Meals")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, -2)
            .padding(.bottom, 23)
            .padding(.horizontal, 30)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .cornerRadius(16)
            .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Image Analysis Functions (matching SearchView exactly)
    private func analyzeImage(_ image: UIImage) {
        print("🔍 SelectMealsView: Starting image analysis with full classification")
        isAnalyzing = true
        showError = false
        lastAnalyzedImage = image // Store image for potential retry
        currentAnalysisImage = image // Store image for display
        
        // Optimize image (resize + compress) for faster API uploads
        guard let imageData = image.optimizedForAPI() else {
            print("🔍 SelectMealsView: Failed to optimize image")
            isAnalyzing = false
            showError(message: "Failed to process image")
            return
        }
        
        // Generate image hash and encode base64
        let imageHash = FoodCacheManager.hashImage(imageData)
        let base64Image = imageData.base64EncodedString()
        
        // Pre-save image to disk cache immediately (before API call)
        foodCacheManager.saveImage(image, forHash: imageHash)
        
        // Check cache first
        if let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
            print("🔍 SelectMealsView: Found cached analysis, scanType: \(cachedAnalysis.scanType ?? "nil")")
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.handleAnalysisResult(cachedAnalysis, image: image, imageHash: imageHash)
            }
            return
        }
        
        // Call OpenAI Vision API for full analysis with classification
        Task {
            do {
                print("🔍 SelectMealsView: Calling OpenAI Vision API for classification")
                let analysis = try await analyzeImageWithOpenAI(base64Image: base64Image, imageHash: imageHash)
                
                await MainActor.run {
                    isAnalyzing = false
                    print("🔍 SelectMealsView: Analysis received, scanType: \(analysis.scanType ?? "nil")")
                    // Clear lastAnalyzedImage on success (no longer needed for retry)
                    lastAnalyzedImage = nil
                    handleAnalysisResult(analysis, image: image, imageHash: imageHash)
                }
            } catch {
                print("🔍 SelectMealsView: Image analysis failed: \(error.localizedDescription)")
                await MainActor.run {
                    isAnalyzing = false
                    
                    // Check if it's a temporary server error (529 Overloaded) and retry
                    if (error.localizedDescription.contains("529") || error.localizedDescription.contains("Overloaded")) && retryCount < 2 {
                        retryCount += 1
                        print("🔍 SelectMealsView: Retrying image analysis (attempt \(retryCount))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if let image = self.lastAnalyzedImage {
                                self.analyzeImage(image)
                            }
                        }
                    } else {
                        if error.localizedDescription.contains("529") || error.localizedDescription.contains("Overloaded") {
                            showError(message: "The analysis service is temporarily busy. Please try again in a moment.")
                        } else {
                            // Check if it's a timeout error
                            let isTimeout = error.localizedDescription.contains("timed out") || 
                                          error.localizedDescription.contains("-1001") ||
                                          (error as NSError).code == -1001
                            
                            if isTimeout {
                                showError(message: "The analysis is taking longer than expected. Please try again.")
                            } else {
                                showError(message: error.localizedDescription)
                            }
                        }
                        // Clear UI state but keep lastAnalyzedImage for retry
                        selectedImage = nil
                        currentAnalysisImage = nil
                        retryCount = 0
                        // Don't clear lastAnalyzedImage - keep it for "Try Again" button
                    }
                }
            }
        }
    }
    
    private func handleAnalysisResult(_ analysis: FoodAnalysis, image: UIImage, imageHash: String) {
        let scanType = analysis.scanType ?? "food" // Default to "food" if not specified
        
        print("🔍 SelectMealsView: Handling analysis result, scanType: \(scanType)")
        
        // For SelectMealsView, we always show ResultsView directly (like Score screen does for "food" type)
        // Save image and cache analysis (Score screen)
        var hashToUse: String? = imageHash
        if hashToUse == nil, let imageData = image.optimizedForAPI() {
            hashToUse = FoodCacheManager.hashImage(imageData)
        }
        
        if let hash = hashToUse {
            foodCacheManager.saveImage(image, forHash: hash)
            foodCacheManager.cacheAnalysis(analysis, imageHash: hash, scanType: scanType, inputMethod: nil) // Image entry
        } else {
            foodCacheManager.cacheAnalysis(analysis, scanType: scanType, inputMethod: nil) // Image entry
        }
        
        // Check for duplicate meal (same name, saved within last 30 minutes, similar score)
        // Extended window to catch duplicates even if user navigates away and comes back
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        let existingMeal = mealStorageManager.trackedMeals.first { meal in
            meal.name == analysis.foodName &&
            meal.timestamp > thirtyMinutesAgo &&
            abs(meal.healthScore - Double(analysis.overallScore)) < 1.0 // Same score (within 1 point)
        }
        
        if let existing = existingMeal {
            let secondsAgo = Int(Date().timeIntervalSince(existing.timestamp))
            print("🍽️ SelectMealsView: Meal '\(analysis.foodName)' already exists in tracker (saved \(secondsAgo) seconds ago), skipping duplicate save")
        } else {
            // AUTOMATICALLY save to Tracker (MealStorageManager) so it appears in "Today's Meals" immediately
            let trackedMeal = TrackedMeal(
                id: UUID(),
                name: analysis.foodName,
                foods: [analysis.foodName],
                healthScore: Double(analysis.overallScore), // Use 0-100 scale
                goalsMet: getGoalsMet(from: analysis),
                timestamp: Date(),
                notes: nil,
                originalAnalysis: analysis, // Store the original analysis for detailed view
                imageHash: hashToUse, // Store image hash for fast direct lookup (like Shop screen)
                isFavorite: false
            )
            
            print("🍽️ SelectMealsView: Automatically saving meal to Tracker - \(trackedMeal.name), score: \(trackedMeal.healthScore), imageHash: \(hashToUse ?? "nil")")
            mealStorageManager.addMeal(trackedMeal)
            print("🍽️ SelectMealsView: Meal saved successfully to MealStorageManager (Tracker)")
        }
        
        // Show results directly (same as Score screen)
        analysisResult = analysis
        currentAnalysisImage = nil // Clear display image
        selectedImage = nil
    }
    
    // Helper function to determine goals met from analysis
    private func getGoalsMet(from analysis: FoodAnalysis) -> [String] {
        var metGoals: [String] = []
        
        // Simple logic to determine goals met based on scores (matches ResultsView logic)
        if analysis.healthScores.heartHealth >= 7 {
            metGoals.append("Heart health")
        }
        if analysis.healthScores.brainHealth >= 7 {
            metGoals.append("Brain health")
        }
        if analysis.healthScores.antiInflammation >= 7 {
            metGoals.append("Anti-inflammation")
        }
        if analysis.healthScores.jointHealth >= 7 {
            metGoals.append("Joint health")
        }
        if analysis.healthScores.eyeHealth >= 7 {
            metGoals.append("Eye health")
        }
        if analysis.healthScores.weightManagement >= 7 {
            metGoals.append("Weight management")
        }
        if analysis.healthScores.bloodSugar >= 7 {
            metGoals.append("Blood sugar")
        }
        if analysis.healthScores.energy >= 7 {
            metGoals.append("Energy")
        }
        if analysis.healthScores.immune >= 7 {
            metGoals.append("Immune")
        }
        if analysis.healthScores.sleep >= 7 {
            metGoals.append("Sleep")
        }
        if analysis.healthScores.skin >= 7 {
            metGoals.append("Skin")
        }
        if analysis.healthScores.stress >= 7 {
            metGoals.append("Stress")
        }
        
        return metGoals
    }
    
    private func analyzeImageWithOpenAI(base64Image: String, imageHash: String) async throws -> FoodAnalysis {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0  // Increased to 60 seconds to prevent premature timeouts
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
        
        let prompt = """
        You are a precision nutrition analysis system. Analyze this image and return ONLY valid JSON.

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

        Extract nutritional data from the image:
        - For products/supplements: Read ALL values from visible nutrition labels
        - For foods/meals: Estimate based on standard serving sizes of MAIN INGREDIENTS
        - Use exact values from labels when visible, estimates when not

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

        CRITICAL: For complex foods (pie, lasagna, pizza), you MUST:
        1. List ALL major ingredients in the ingredients array (prioritize by portion size)
        2. Score based on COMPLETE composition, not just main ingredient
        3. Focus on ingredients that make up the largest portions of the meal
        4. Example: "Peach pie" = peaches + crust + sugar + butter + flour (score ~41, not 80)
        5. Example: "Grilled salmon with rice and lemon wedge" → focus on salmon and rice, ignore lemon wedge unless it's a significant portion

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
            "needsBackScan": false,
            "overallScore": 0-100,
            "summary": "Write 1-2 sentences, MAX 40 words. Lead with shocking/specific fact. Include ONE specific number. End with impact on: \(healthGoalsText). NO 'should', 'in moderation', 'traditional', 'provides enjoyment'. Use 'your' not 'the user's'.",
            "healthScores": {
                "heartHealth": 0-100,
                "brainHealth": 0-100,
                "antiInflammation": 0-100,
                "jointHealth": 0-100,
                "eyeHealth": 0-100,
                "weightManagement": 0-100,
                "bloodSugar": 0-100,
                "energy": 0-100,
                "immune": 0-100,
                "sleep": 0-100,
                "skin": 0-100,
                "stress": 0-100
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
        
        var analysis = try JSONDecoder().decode(FoodAnalysis.self, from: analysisData)
        
        // If scanType wasn't in the decoded struct, add it manually
        if analysis.scanType == nil, let scanTypeString = scanTypeString {
            analysis = FoodAnalysis(
                foodName: analysis.foodName,
                overallScore: analysis.overallScore,
                summary: analysis.summary,
                healthScores: analysis.healthScores,
                keyBenefits: analysis.keyBenefits,
                ingredients: analysis.ingredients,
                bestPreparation: analysis.bestPreparation,
                servingSize: analysis.servingSize,
                nutritionInfo: analysis.nutritionInfo,
                scanType: scanTypeString,
                foodNames: analysis.foodNames,
                suggestions: analysis.suggestions
            )
        }
        
        return analysis
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Select Meal Row View (list-view style like Recently Analyzed)
struct SelectMealRowView: View {
    let entry: FoodCacheEntry
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var cachedImage: UIImage?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Image
                Group {
                    if entry.imageHash != nil {
                        if let image = cachedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                                .onAppear {
                                    loadImage()
                                }
                        }
                    } else {
                        // Text/voice entry - show black box with gradient icon
                        TextVoiceEntryIcon(inputMethod: entry.inputMethod, size: 60)
                    }
                }
                
                // Title and Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.foodName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(entry.daysSinceAnalysis == 0 ? "Today" : entry.daysSinceAnalysis == 1 ? "1 day ago" : "\(entry.daysSinceAnalysis) days ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Score Circle
                GroceryScoreCircleCompact(score: entry.fullAnalysis.overallScore)
                
                // Selection Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .padding(.leading, 8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color(red: 0.42, green: 0.557, blue: 0.498), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadImage() {
        if let imageHash = entry.imageHash {
            DispatchQueue.global(qos: .userInitiated).async {
                if let image = FoodCacheManager.shared.loadImage(forHash: imageHash) {
                    DispatchQueue.main.async {
                        cachedImage = image
                    }
                }
            }
        }
    }
}

