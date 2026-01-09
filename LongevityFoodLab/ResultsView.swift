import SwiftUI

// Struct to hold health detail information for sheet presentation
struct HealthDetailItem: Identifiable {
    let id = UUID()
    let category: String
    let score: Int
}

// Reusable Health Goals disclaimer view (plain text, no background)
struct HealthGoalsDisclaimerView: View {
    var body: some View {
        Text("This information is provided for educational purposes only and reflects general research findings. It is not intended to diagnose, treat, cure, or prevent any disease.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
    }
}

// Health goal research info for supplements (defined before ResultsView for accessibility)
// HealthGoalResearchInfo moved to ResearchCitation.swift

struct ResultsView: View {
    let analysis: FoodAnalysis
    let onNewSearch: () -> Void
    var isSupplement: Bool = false
    var onMealAdded: (() -> Void)? = nil
    @State private var expandedIngredients: Set<Int> = []
    @State private var healthDetailItem: HealthDetailItem? = nil
    @State private var showingAddToMealTracker = false
    @State private var mealName = ""
    @State private var notes = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @StateObject private var spoonacularService = SpoonacularService.shared
    @State private var cachedImage: UIImage? = nil
    @State private var isFavorite: Bool = false
    @State private var cachedEntry: FoodCacheEntry? = nil
    
    // Cache fallback state for unavailable analysis
    @State private var cachedFallbackAnalysis: FoodAnalysis? = nil
    @State private var cachedFallbackDate: Date? = nil
    
    // Progressive loading state
    @State private var loadedKeyBenefits: [String]? = nil
    @State private var loadedIngredients: [FoodIngredient]? = nil
    @State private var loadedNutritionInfo: NutritionInfo? = nil
    @State private var loadedBestPreparation: String? = nil
    
    // Dropdown expansion state
    @State private var isKeyBenefitsExpanded = false
    @State private var isIngredientsExpanded = false
    @State private var isMacrosExpanded = false
    @State private var isMicrosExpanded = false
    @State private var isBestPracticesExpanded = false
    
    // Product dropdown expansion state
    @State private var isProductMacrosExpanded = false
    @State private var isProductMicrosExpanded = false
    
    // Loading states
    @State private var isLoadingKeyBenefits = false
    @State private var isLoadingIngredients = false
    @State private var isLoadingNutritionInfo = false
    
    // Supplement suggestions state
    @State private var supplementSuggestions: [GrocerySuggestion]? = nil
    @State private var isLoadingSupplementSuggestions = false
    
    // Secondary API loading state (for supplements)
    @State private var secondaryLoaded = false
    @State private var isLoadingSecondary = false
    
    // Dropdown expansion state for supplements
    @State private var isSupplementKeyBenefitsExpanded = false
    @State private var isSupplementIngredientsExpanded = false
    @State private var isDrugInteractionsExpanded = false
    @State private var isDosageExpanded = false
    @State private var isSafetyExpanded = false
    @State private var isQualityExpanded = false
    @State private var isSimilarExpanded = false
    
    // Health goal research state
    @State private var expandedHealthGoal: (category: String, score: Int)? = nil
    @State private var healthGoalResearch: HealthGoalResearchInfo? = nil
    @State private var isLoadingHealthGoalResearch = false
    
    // Lazy-loading state for health goals research cards
    @State private var loadedHealthGoalResearch: [String: HealthGoalResearchInfo] = [:]
    @State private var loadingHealthGoalResearch: Set<String> = []
    
    // Computed property to detect supplements
    var isSupplementScan: Bool {
        analysis.scanType == "supplement" || analysis.scanType == "supplement_facts" || isSupplement
    }
    
    // Target mode state (for tracker-style dropdowns)
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @AppStorage("macroTargetMode") private var macroTargetModeRaw: String = TargetMode.standardRDA.rawValue
    @AppStorage("micronutrientTargetMode") private var micronutrientTargetModeRaw: String = TargetMode.standardRDA.rawValue
    @State private var macroTargets: [String: Double] = [:]
    @State private var micronutrientTargets: [String: Double] = [:]
    @State private var showingMacroTargetModeSelection = false
    @State private var showingMicroTargetModeSelection = false
    @State private var showingMacroCustomDisclaimer = false
    @State private var showingMicroCustomDisclaimer = false
    @State private var showingMacroSelection = false
    @State private var showingMicroSelection = false
    @State private var selectedMacros: Set<String> = []
    @State private var selectedMicronutrientsForSelection: Set<String> = []
    @State private var macroCustomDisclaimerAccepted = false
    @State private var microCustomDisclaimerAccepted = false
    @State private var selectedMacroForTarget: String?
    @State private var macroTargetInputValue: String = ""
    @State private var selectedMicronutrientForTarget: String?
    @State private var microTargetInputValue: String = ""
    @State private var showingServingSizeEditor = false
    @State private var servingSizeInput: String = ""
    @State private var currentServingSize: String = ""
    @State private var currentAnalysis: FoodAnalysis
    
    init(analysis: FoodAnalysis, onNewSearch: @escaping () -> Void, isSupplement: Bool = false, onMealAdded: (() -> Void)? = nil) {
        self.analysis = analysis
        self.onNewSearch = onNewSearch
        self.isSupplement = isSupplement
        self.onMealAdded = onMealAdded
        _currentAnalysis = State(initialValue: analysis)
        
        print("🔍 ResultsView init: analysis.nutritionInfo is \(analysis.nutritionInfo != nil ? "SET" : "NIL")")
        if let nutrition = analysis.nutritionInfo {
            print("🔍 ResultsView init: calories = \(nutrition.calories), protein = \(nutrition.protein)")
            print("🔍 ResultsView init: foodNames = \(analysis.foodNames?.joined(separator: ", ") ?? "nil")")
        }
    }
    
    // Check cache for fallback when analysis is unavailable
    private func checkCacheForFallback() {
        // Only check cache if current analysis is unavailable
        guard analysis.overallScore == -1 else { return }
        
        // Try to find cached analysis for the same food
        if let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: analysis.foodName),
           cachedAnalysis.overallScore != -1 {
            // Find the cache entry to get the date
            let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                FoodAnalysis.normalizeInput(entry.foodName) == FoodAnalysis.normalizeInput(analysis.foodName)
            }
            
            if let entry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
                cachedFallbackAnalysis = cachedAnalysis
                cachedFallbackDate = entry.analysisDate
                currentAnalysis = cachedAnalysis
                print("🔍 ResultsView: Using cached fallback analysis for \(analysis.foodName), dated \(entry.analysisDate)")
            }
        }
    }
    
    // Format cache date for display
    private func formatCacheDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Parse serving size to get multiplier (e.g., "2 slices" -> 2.0, "1 cup" -> 1.0, "0.5 cups" -> 0.5)
    private func parseServingSizeMultiplier(_ servingSize: String) -> Double {
        // Extract number from serving size string (e.g., "2 slices" -> 2.0, "1 cup" -> 1.0)
        let cleaned = servingSize.lowercased()
            .replacingOccurrences(of: "slice", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "slices", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "cup", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "cups", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "piece", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "pieces", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "serving", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "servings", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract numeric value
        let numericPart = cleaned.filter { $0.isNumber || $0 == "." || $0 == "/" }
        
        // Handle fractions (e.g., "1/2" -> 0.5)
        if numericPart.contains("/") {
            let parts = numericPart.split(separator: "/")
            if parts.count == 2,
               let numerator = Double(parts[0]),
               let denominator = Double(parts[1]),
               denominator != 0 {
                return numerator / denominator
            }
        }
        
        // Handle decimal numbers
        if let multiplier = Double(numericPart.isEmpty ? "1" : numericPart) {
            return multiplier > 0 ? multiplier : 1.0
        }
        
        // Default to 1.0 if parsing fails
        return 1.0
    }
    
    enum TargetMode: String, Codable {
        case standardRDA = "standardRDA"
        case custom = "custom"
    }
    
    // Computed properties for type-safe access to target modes
    private var macroTargetMode: TargetMode {
        get { TargetMode(rawValue: macroTargetModeRaw) ?? .standardRDA }
        set { macroTargetModeRaw = newValue.rawValue }
    }
    
    private var micronutrientTargetMode: TargetMode {
        get { TargetMode(rawValue: micronutrientTargetModeRaw) ?? .standardRDA }
        set { micronutrientTargetModeRaw = newValue.rawValue }
    }
    
    var body: some View {
        let _ = print("ResultsView: Rendering for \(analysis.foodName) with score \(analysis.overallScore)")
        return NavigationView {
            ZStack {
            // Dark mode: 100% black background, light mode: system grouped background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground)).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // Title (same size/font/weight as recipes)
                    Text(analysis.foodName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    // Image with Score Circle Overlay (same structure as recipes)
                    if let image = cachedImage {
                        VStack(spacing: 8) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .clipped()
                                
                                // Heart Icon - Top Right Corner (matching RecipeDetailView)
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            toggleFavorite()
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.8))
                                                    .frame(width: 28, height: 28)
                                                
                                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(
                                                        isFavorite ?
                                                        LinearGradient(
                                                            colors: [
                                                                Color(red: 64/255.0, green: 56/255.0, blue: 213/255.0),  // Blue-purple #4038D5
                                                                Color(red: 12/255.0, green: 97/255.0, blue: 255/255.0)   // Bright blue #0C61FF
                                                            ],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        ) :
                                                        LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                                                    )
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(8)
                                    }
                                    Spacer()
                                }
                                
                                // Score Circle Overlay (positioned like recipes)
                                scoreCircleOverlay
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 16)
                            }
                        }
                    } else if cachedEntry?.imageHash == nil {
                        // Text/voice entry - show black box (dark mode) or light gray box (light mode) with gradient icon
                        VStack(spacing: 8) {
                            ZStack(alignment: .bottomTrailing) {
                                GeometryReader { geometry in
                                    TextVoiceEntryIcon(
                                        inputMethod: cachedEntry?.inputMethod,
                                        width: geometry.size.width,
                                        height: 200,
                                        cornerRadius: 12
                                    )
                                }
                                .frame(height: 200)
                                .cornerRadius(12)
                                .clipped()
                                
                                // Heart Icon - Top Right Corner (matching RecipeDetailView)
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            toggleFavorite()
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.white.opacity(0.8))
                                                    .frame(width: 28, height: 28)
                                                
                                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(
                                                        isFavorite ?
                                                        LinearGradient(
                                                            colors: [
                                                                Color(red: 64/255.0, green: 56/255.0, blue: 213/255.0),  // Blue-purple #4038D5
                                                                Color(red: 12/255.0, green: 97/255.0, blue: 255/255.0)   // Bright blue #0C61FF
                                                            ],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        ) :
                                                        LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                                                    )
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(8)
                                    }
                                    Spacer()
                                }
                                
                                // Score Circle Overlay (positioned like recipes)
                                scoreCircleOverlay
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 16)
                            }
                        }
                    } else {
                        // Fallback: Show score circle without image (if image not available)
                        scoreCircleRecipeStyle
                    }
                    
                    // Summary text with optional longevity reassurance
                    VStack(spacing: 8) {
                        Text(currentAnalysis.summary)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                        
                        // Show "Last updated" indicator if using cached fallback
                        if cachedFallbackAnalysis != nil, let cacheDate = cachedFallbackDate {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("Last updated: \(formatCacheDate(cacheDate))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        }
                        
                        // Longevity-population reassurance (only for qualifying high-quality meals)
                        if currentAnalysis.qualifiesForLongevityReassurance {
                            HStack(spacing: 6) {
                                Image(systemName: "leaf.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.7))
                                Text(currentAnalysis.longevityReassurancePhrase)
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .italic()
                            }
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        }
                    }
                    
                    // For supplements: Health Goals Grid (always visible) + Dropdowns (load on tap)
                    // For groceries/meals: Existing structure
                    let isGrocery = analysis.scanType == "product" || analysis.scanType == "nutrition_label"
                    
                    if isSupplementScan {
                        // Health Goals Grid (ALWAYS VISIBLE - not a dropdown)
                        supplementHealthGoalsGrid
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Supplement dropdowns (all load via ONE secondary API call)
                        supplementDropdowns
                        
                        // Educational disclaimer - always shown at bottom
                        HealthGoalsDisclaimerView()
                    } else {
                        // Existing structure for groceries/meals
                        // Key Benefits dropdown
                        keyBenefitsDropdown
                        
                        // Longevity Goals grid (existing - only calls API when item tapped)
                        healthScoresGrid
                        
                        // Healthier Choices (only for scanned products) - moved up below Health Goals grid
                        if isGrocery {
                            HealthierChoicesView(analysis: currentAnalysis)
                        }
                        
                        // Ingredients Analysis dropdown (renamed from Nutritional Components Analysis)
                        ingredientsAnalysisDropdown
                        
                        // Product Macronutrients dropdown (only for products)
                        if isGrocery {
                            productMacrosDropdown
                        }
                        
                        // Product Micronutrients dropdown (only for products)
                        if isGrocery {
                            productMicrosDropdown
                        }
                        
                        // Your Macronutrients dropdown (hidden for groceries only)
                        if !isGrocery {
                            macrosDropdownTrackerStyle
                        }
                        
                        // Your Micronutrients dropdown (hidden for groceries only)
                        if !isGrocery {
                            microsDropdownTrackerStyle
                        }
                        
                        // Quality & Source dropdown (hidden for groceries only)
                        if !isGrocery {
                            QualitySourceView(foodName: analysis.foodName)
                        }
                        
                        // Best Practices dropdown (if available)
                        let bestPrep = currentAnalysis.bestPreparationOrDefault
                        if !bestPrep.isEmpty && !isHealthierChoicesText(bestPrep) {
                            bestPracticesDropdown
                        }
                        
                        // Educational disclaimer - always shown at bottom
                        HealthGoalsDisclaimerView()
                    }
                    
                    // Add to Meal Tracker and Evaluate Another Food buttons (hidden for groceries and supplements)
                    if !isGrocery && !isSupplement {
                        // Add to Meal Tracker Button
                        Button(action: {
                            mealName = analysis.foodName
                            showingAddToMealTracker = true
                        }) {
                            HStack(spacing: 8) {
                                Text("🍽️")
                                Text("Add to Meal Tracker")
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
                                        Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                        Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                        }
                        
                        // New Search Button
                        Button(action: onNewSearch) {
                            HStack(spacing: 8) {
                                Text("🔍")
                                Text("Evaluate Another Food")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                            .frame(maxWidth: .infinity)
                            .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            checkCacheForFallback()
            loadImage()
            lazyLoadTopHealthGoals()
            
            // Ensure currentAnalysis has the latest cached data including suggestions
            // Refresh from cache to get the most up-to-date suggestions
            if let entry = foodCacheManager.cachedAnalyses.first(where: { entry in
                entry.foodName == analysis.foodName &&
                entry.fullAnalysis.overallScore == analysis.overallScore
            }) {
                cachedEntry = entry
                currentAnalysis = entry.fullAnalysis
                print("🔍 ResultsView: Refreshed currentAnalysis from cache, has suggestions: \(entry.fullAnalysis.suggestions != nil && !(entry.fullAnalysis.suggestions?.isEmpty ?? true))")
            } else if let entry = cachedEntry {
                // Fallback to already loaded cachedEntry
                currentAnalysis = entry.fullAnalysis
            }
            
            // Load selected macros/micros
            if selectedMacros.isEmpty {
                selectedMacros = Set(healthProfileManager.getTrackedMacros())
            }
            if selectedMicronutrientsForSelection.isEmpty {
                selectedMicronutrientsForSelection = Set(healthProfileManager.getTrackedMicronutrients())
            }
            
            // Auto-load nutrition info for groceries/products if missing
            let isGrocery = analysis.scanType == "product" || analysis.scanType == "nutrition_label"
            if isGrocery {
                let currentNutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                if !isNutritionInfoValid(currentNutrition) {
                    loadNutritionInfo()
                }
            }
        }
        .sheet(isPresented: $showingMacroSelection) {
            MacroSelectionView(selectedMacros: $selectedMacros) {
                healthProfileManager.setTrackedMacros(Array(selectedMacros))
            }
        }
        .sheet(isPresented: $showingMicroSelection) {
            MicronutrientSelectionView(selectedMicronutrients: $selectedMicronutrientsForSelection) {
                healthProfileManager.updateTrackedMicronutrients(Array(selectedMicronutrientsForSelection))
            }
        }
        .sheet(isPresented: $showingServingSizeEditor) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Edit Serving Size")
                        .font(.headline)
                        .padding(.top)
                    
                    TextField("Serving Size", text: $servingSizeInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle("Serving Size")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingServingSizeEditor = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            // Update current serving size (used for calculations)
                            currentServingSize = servingSizeInput.isEmpty ? "1 serving" : servingSizeInput
                            
                            // Update serving size in currentAnalysis
                            currentAnalysis = FoodAnalysis(
                                foodName: currentAnalysis.foodName,
                                overallScore: currentAnalysis.overallScore,
                                summary: currentAnalysis.summary,
                                healthScores: currentAnalysis.healthScores,
                                keyBenefits: currentAnalysis.keyBenefits,
                                ingredients: currentAnalysis.ingredients,
                                bestPreparation: currentAnalysis.bestPreparation,
                                servingSize: currentServingSize,
                                nutritionInfo: currentAnalysis.nutritionInfo,
                                scanType: currentAnalysis.scanType,
                                foodNames: currentAnalysis.foodNames,
                                foodPortions: currentAnalysis.foodPortions,
                                suggestions: currentAnalysis.suggestions
                            )
                            showingServingSizeEditor = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
        }
        .sheet(item: $healthDetailItem) { item in
            HealthDetailView(
                category: item.category,
                score: item.score,
                foodName: analysis.foodName,
                longevityScore: analysis.overallScore,
                isMealAnalysis: false,
                scanType: analysis.scanType,
                ingredients: currentAnalysis.ingredientsOrDefault
            )
        }
        .sheet(isPresented: $showingAddToMealTracker) {
            AddToMealTrackerSheet(
                analysis: analysis,
                mealName: $mealName,
                notes: $notes,
                onSave: { savedMeal in
                    showingAddToMealTracker = false
                    // Switch to meal tracker tab after adding meal
                    onMealAdded?()
                    // Dismiss the analysis screen
                    dismiss()
                },
                onCancel: {
                    showingAddToMealTracker = false
                }
            )
        }
        }
    }
    
    // MARK: - New Progressive Loading Components
    
    // Score circle overlay for image (positioned bottom-right like recipes)
    private var scoreCircleOverlay: some View {
        ZStack {
            // Background circle with gradient fill (recipe style)
            Circle()
                .fill(scoreGradient(analysis.overallScore))
                .frame(width: 90, height: 90)
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            
            // Score number and label (white text - reverse type)
            VStack(spacing: -4) {
                if analysis.overallScore == -1 {
                    Text("—")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(analysis.overallScore)")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text(scoreLabel(analysis.overallScore).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    // Score circle standalone (fallback when no image)
    private var scoreCircleRecipeStyle: some View {
        scoreCircleOverlay
            .padding(.vertical, 10)
    }
    
    private func scoreGradient(_ score: Int) -> LinearGradient {
        // Handle unavailable scores
        if score == -1 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
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
    
    // MARK: - Dropdown Components
    
    private var keyBenefitsDropdown: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isKeyBenefitsExpanded.toggle()
                    if isKeyBenefitsExpanded && loadedKeyBenefits == nil {
                        loadKeyBenefits()
                    }
                }
            }) {
                HStack {
                    HStack(spacing: 12) {
                        Text("🏆")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Key Benefits")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Tap to see health benefits")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isKeyBenefitsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.608, green: 0.827, blue: 0.835).opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isKeyBenefitsExpanded {
                if isLoadingKeyBenefits {
                    ProgressView()
                        .padding()
                } else {
                    let benefits = loadedKeyBenefits ?? currentAnalysis.keyBenefitsOrDefault
                    if !benefits.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("✓")
                                        .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                                        .fontWeight(.bold)
                                    
                                    Text(benefit)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var ingredientsAnalysisDropdown: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    let wasExpanded = isIngredientsExpanded
                    isIngredientsExpanded.toggle()
                    // If expanding and no data loaded yet, start loading immediately
                    if !wasExpanded && isIngredientsExpanded && loadedIngredients == nil {
                        // Set loading state synchronously before async call
                        isLoadingIngredients = true
                        loadIngredients()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.2, green: 0.6, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Text("Ingredients Analysis")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isIngredientsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isIngredientsExpanded {
                // Show loading if actively loading OR if no data exists yet and we're about to load
                if isLoadingIngredients || (loadedIngredients == nil && currentAnalysis.ingredientsOrDefault.isEmpty) {
                    ProgressView()
                        .padding()
                } else {
                    let ingredients = loadedIngredients ?? currentAnalysis.ingredientsOrDefault
                    if !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                                ingredientRow(ingredient, index: index)
                            }
                        }
                        .padding(20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }
    
    // MARK: - Your Macronutrients Dropdown (Tracker Style)
    private var macrosDropdownTrackerStyle: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMacrosExpanded.toggle()
                        if isMacrosExpanded {
                            let currentNutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                            if loadedNutritionInfo == nil || !isNutritionInfoValid(currentNutrition) {
                                loadNutritionInfo()
                            }
                        }
                    }
                }) {
                    HStack {
                        // Icon with bright gradient (purple like tracker)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text("Your Macronutrients")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: isMacrosExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark ?
                                LinearGradient(
                                    colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: colorScheme == .dark ? 1.0 : 0
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if isMacrosExpanded {
                    if isLoadingNutritionInfo {
                        ProgressView()
                            .padding()
                    } else {
                        let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                        macrosViewTrackerStyle(nutrition)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                            .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                            .cornerRadius(12)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                            .sheet(isPresented: $showingMacroTargetModeSelection) {
                                TargetModeSelectionPopup(
                                    currentMode: MealTrackingView.TargetMode(rawValue: macroTargetMode.rawValue) ?? .standardRDA,
                                    onSelectStandardRDA: {
                                        macroTargetModeRaw = TargetMode.standardRDA.rawValue
                                        showingMacroTargetModeSelection = false
                                    },
                                    onSelectCustom: {
                                        if !macroCustomDisclaimerAccepted {
                                            showingMacroTargetModeSelection = false
                                            showingMacroCustomDisclaimer = true
                                        } else {
                                            macroTargetModeRaw = TargetMode.custom.rawValue
                                            showingMacroTargetModeSelection = false
                                        }
                                    }
                                )
                            }
                            .sheet(isPresented: $showingMacroCustomDisclaimer) {
                                CustomTargetDisclaimerPopup(
                                    onAccept: {
                                        macroCustomDisclaimerAccepted = true
                                        saveMacroDisclaimerAcceptance()
                                        macroTargetModeRaw = TargetMode.custom.rawValue
                                        showingMacroCustomDisclaimer = false
                                    },
                                    onUseStandardRDA: {
                                        macroTargetModeRaw = TargetMode.standardRDA.rawValue
                                        showingMacroCustomDisclaimer = false
                                    }
                                )
                            }
                            .sheet(item: Binding(
                                get: { selectedMacroForTarget.map { MacroTargetItem(name: $0) } },
                                set: { selectedMacroForTarget = $0?.name }
                            )) { item in
                                let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                                let currentValue = getMacroCurrentValue(nutrition: nutrition, macroName: item.name)
                                let targetValue = getMacroTargetValue(for: item.name)
                                let rdaValue = getMacroRDAValue(for: item.name)
                                
                                MacroTargetPopup(
                                    macroName: item.name,
                                    currentValue: currentValue,
                                    targetValue: targetValue,
                                    rdaValue: rdaValue,
                                    targetMode: MealTrackingView.TargetMode(rawValue: macroTargetMode.rawValue) ?? .standardRDA,
                                    onSave: { target in
                                        saveMacroTarget(item.name, target: target)
                                        selectedMacroForTarget = nil
                                    },
                                    onCancel: {
                                        selectedMacroForTarget = nil
                                    }
                                )
                            }
                            .sheet(item: Binding(
                                get: { selectedMicronutrientForTarget.map { MicroTargetItem(name: $0) } },
                                set: { selectedMicronutrientForTarget = $0?.name }
                            )) { item in
                                let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                                let currentValue = getMicronutrientValue(nutrition, name: item.name) ?? 0.0
                                let targetValue = getTargetValue(for: item.name)
                                let rdaValue = getRDAValue(for: item.name)
                                let metadata = micronutrientMetadata(for: item.name)
                                
                                MicronutrientTargetPopup(
                                    micronutrient: MealTrackingView.Micronutrient(
                                        name: item.name,
                                        icon: metadata.icon,
                                        iconGradient: metadata.gradient,
                                        placeholderValue: String(Int(round(currentValue))),
                                        unit: metadata.unit
                                    ),
                                    currentValue: currentValue,
                                    targetValue: targetValue,
                                    rdaValue: rdaValue,
                                    targetMode: MealTrackingView.TargetMode(rawValue: micronutrientTargetMode.rawValue) ?? .standardRDA,
                                    onSave: { target in
                                        saveMicronutrientTarget(item.name, target: target)
                                        selectedMicronutrientForTarget = nil
                                    },
                                    onCancel: {
                                        selectedMicronutrientForTarget = nil
                                    }
                                )
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Your Micronutrients Dropdown (Tracker Style)
    private var microsDropdownTrackerStyle: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMicrosExpanded.toggle()
                        if isMicrosExpanded {
                            let currentNutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                            if loadedNutritionInfo == nil || !isNutritionInfoValid(currentNutrition) {
                                loadNutritionInfo()
                            }
                        }
                    }
                }) {
                    HStack {
                        // Icon with bright gradient (vitamin pill icon)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text("Your Micronutrients")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: isMicrosExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark ?
                                LinearGradient(
                                    colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: colorScheme == .dark ? 1.0 : 0
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if isMicrosExpanded {
                    if isLoadingNutritionInfo {
                        ProgressView()
                            .padding()
                    } else {
                        let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                        microsViewTrackerStyle(nutrition)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                            .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                            .cornerRadius(12)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                            .onAppear {
                                loadMacroTargets()
                                loadMicronutrientTargets()
                                macroCustomDisclaimerAccepted = UserDefaults.standard.bool(forKey: "macroCustomDisclaimerAccepted")
                                microCustomDisclaimerAccepted = UserDefaults.standard.bool(forKey: "microCustomDisclaimerAccepted")
                            }
                            .sheet(isPresented: $showingMicroTargetModeSelection) {
                                TargetModeSelectionPopup(
                                    currentMode: MealTrackingView.TargetMode(rawValue: micronutrientTargetMode.rawValue) ?? .standardRDA,
                                    onSelectStandardRDA: {
                                        micronutrientTargetModeRaw = TargetMode.standardRDA.rawValue
                                        showingMicroTargetModeSelection = false
                                    },
                                    onSelectCustom: {
                                        if !microCustomDisclaimerAccepted {
                                            showingMicroTargetModeSelection = false
                                            showingMicroCustomDisclaimer = true
                                        } else {
                                            micronutrientTargetModeRaw = TargetMode.custom.rawValue
                                            showingMicroTargetModeSelection = false
                                        }
                                    }
                                )
                            }
                            .sheet(isPresented: $showingMicroCustomDisclaimer) {
                                CustomTargetDisclaimerPopup(
                                    onAccept: {
                                        microCustomDisclaimerAccepted = true
                                        saveMicroDisclaimerAcceptance()
                                        micronutrientTargetModeRaw = TargetMode.custom.rawValue
                                        showingMicroCustomDisclaimer = false
                                    },
                                    onUseStandardRDA: {
                                        micronutrientTargetModeRaw = TargetMode.standardRDA.rawValue
                                        showingMicroCustomDisclaimer = false
                                    }
                                )
                            }
                            .sheet(item: Binding(
                                get: { selectedMacroForTarget.map { MacroTargetItem(name: $0) } },
                                set: { selectedMacroForTarget = $0?.name }
                            )) { item in
                                let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                                let currentValue = getMacroCurrentValue(nutrition: nutrition, macroName: item.name)
                                let targetValue = getMacroTargetValue(for: item.name)
                                let rdaValue = getMacroRDAValue(for: item.name)
                                
                                MacroTargetPopup(
                                    macroName: item.name,
                                    currentValue: currentValue,
                                    targetValue: targetValue,
                                    rdaValue: rdaValue,
                                    targetMode: MealTrackingView.TargetMode(rawValue: macroTargetMode.rawValue) ?? .standardRDA,
                                    onSave: { target in
                                        saveMacroTarget(item.name, target: target)
                                        selectedMacroForTarget = nil
                                    },
                                    onCancel: {
                                        selectedMacroForTarget = nil
                                    }
                                )
                            }
                            .sheet(item: Binding(
                                get: { selectedMicronutrientForTarget.map { MicroTargetItem(name: $0) } },
                                set: { selectedMicronutrientForTarget = $0?.name }
                            )) { item in
                                let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                                let currentValue = getMicronutrientValue(nutrition, name: item.name) ?? 0.0
                                let targetValue = getTargetValue(for: item.name)
                                let rdaValue = getRDAValue(for: item.name)
                                let metadata = micronutrientMetadata(for: item.name)
                                
                                MicronutrientTargetPopup(
                                    micronutrient: MealTrackingView.Micronutrient(
                                        name: item.name,
                                        icon: metadata.icon,
                                        iconGradient: metadata.gradient,
                                        placeholderValue: String(Int(round(currentValue))),
                                        unit: metadata.unit
                                    ),
                                    currentValue: currentValue,
                                    targetValue: targetValue,
                                    rdaValue: rdaValue,
                                    targetMode: MealTrackingView.TargetMode(rawValue: micronutrientTargetMode.rawValue) ?? .standardRDA,
                                    onSave: { target in
                                        saveMicronutrientTarget(item.name, target: target)
                                        selectedMicronutrientForTarget = nil
                                    },
                                    onCancel: {
                                        selectedMicronutrientForTarget = nil
                                    }
                                )
                            }
                    }
                }
            }
        }
    }
    
    // Helper structs for sheet presentation
    struct MacroTargetItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    struct MicroTargetItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    // MARK: - Product Macronutrients Dropdown (Simple Style)
    private var productMacrosDropdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isProductMacrosExpanded.toggle()
                        if isProductMacrosExpanded {
                            let currentNutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                            if loadedNutritionInfo == nil || !isNutritionInfoValid(currentNutrition) {
                                loadNutritionInfo()
                            }
                        }
                    }
                }) {
                    HStack {
                        // Icon with bright gradient (purple like tracker)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text("Macronutrients")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: isProductMacrosExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark ?
                                LinearGradient(
                                    colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: colorScheme == .dark ? 1.0 : 0
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if isProductMacrosExpanded {
                    if isLoadingNutritionInfo {
                        ProgressView()
                            .padding()
                    } else {
                        let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                        productMacrosView(nutrition)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                            .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                            .cornerRadius(12)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }
                }
            }
        }
    }
    
    // MARK: - Product Micronutrients Dropdown (Simple Style)
    private var productMicrosDropdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isProductMicrosExpanded.toggle()
                        if isProductMicrosExpanded {
                            let currentNutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                            if loadedNutritionInfo == nil || !isNutritionInfoValid(currentNutrition) {
                                loadNutritionInfo()
                            }
                        }
                    }
                }) {
                    HStack {
                        // Icon with bright gradient (vitamin pill icon)
                        Image(systemName: "pills.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text("Micronutrients")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: isProductMicrosExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark ?
                                LinearGradient(
                                    colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) :
                                LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                                lineWidth: colorScheme == .dark ? 1.0 : 0
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if isProductMicrosExpanded {
                    if isLoadingNutritionInfo {
                        ProgressView()
                            .padding()
                    } else {
                        let nutrition = loadedNutritionInfo ?? currentAnalysis.nutritionInfoOrDefault
                        productMicrosView(nutrition)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                            .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                            .cornerRadius(12)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }
                }
            }
        }
    }
    
    // MARK: - Product Macros View (Simple Style)
    private func productMacrosView(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Calories
            let calories = parseNutritionValueDouble(nutrition.calories) ?? 0.0
            productNutritionRow("Calories", "\(Int(round(calories))) kcal")
            
            // Protein
            let protein = parseNutritionValueDouble(nutrition.protein) ?? 0.0
            productNutritionRow("Protein", "\(String(format: "%.1f", protein))g")
            
            // Carbohydrates
            let carbs = parseNutritionValueDouble(nutrition.carbohydrates) ?? 0.0
            productNutritionRow("Carbohydrates", "\(String(format: "%.1f", carbs))g")
            
            // Fat
            let fat = parseNutritionValueDouble(nutrition.fat) ?? 0.0
            productNutritionRow("Fat", "\(String(format: "%.1f", fat))g")
            
            // Saturated Fat
            let saturatedFat = parseNutritionValueDouble(nutrition.saturatedFat) ?? 0.0
            productNutritionRow("Saturated Fat", "\(String(format: "%.1f", saturatedFat))g")
            
            // Fiber
            let fiber = parseNutritionValueDouble(nutrition.fiber) ?? 0.0
            productNutritionRow("Fiber", "\(String(format: "%.1f", fiber))g")
            
            // Sugar
            let sugar = parseNutritionValueDouble(nutrition.sugar) ?? 0.0
            productNutritionRow("Sugar", "\(String(format: "%.1f", sugar))g")
            
            // Sodium
            let sodium = parseNutritionValueDouble(nutrition.sodium) ?? 0.0
            productNutritionRow("Sodium", "\(Int(round(sodium)))mg")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }
    
    // MARK: - Product Micros View (Simple Style)
    private func productMicrosView(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Note at the top
            Text("Packaged foods often don't publish micronutrient content. Available micronutrients are listed below.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)
            
            // All 18 micronutrients (excluding iodine)
            let allMicros = [
                "Vitamin D", "Vitamin E", "Potassium", "Vitamin K", "Magnesium",
                "Vitamin A", "Calcium", "Vitamin C", "Choline", "Iron",
                "Zinc", "Folate (B9)", "Vitamin B12", "Vitamin B6",
                "Selenium", "Copper", "Manganese", "Thiamin (B1)"
            ]
            
            // Only show micros with actual values (> 0)
            ForEach(allMicros, id: \.self) { name in
                if let value = getMicronutrientValue(nutrition, name: name), value > 0 {
                    let metadata = micronutrientMetadata(for: name)
                    productNutritionRow(name, "\(String(format: "%.1f", value))\(metadata.unit)")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }
    
    // MARK: - Product Nutrition Row (Simple Style)
    private func productNutritionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Macros View (Tracker Style)
    private func macrosViewTrackerStyle(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Two separate buttons: Selection and Target Mode
            HStack {
                // Button 1: Tap To Select Your Macros
                Button(action: {
                    showingMacroSelection = true
                }) {
                    Text("Tap To Select Your Macros")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Button 2: (RDA) or (Custom) - for target numbers
                Button(action: {
                    showingMacroTargetModeSelection = true
                }) {
                    Text(macroTargetMode == .standardRDA ? "(RDA)" : "(Custom)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 4)
            
            // Show source attribution in RDA mode
            if macroTargetMode == .standardRDA {
                Text("Based on USDA Dietary Guidelines 2020-2025")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
            
            // Get selected macros from profile
            let trackedMacros = healthProfileManager.getTrackedMacros()
            
            // Kcal progress bar (always show if selected)
            // Nutrition values are already per typical serving (for foods/meals)
            if trackedMacros.contains("Kcal") {
                let calories = parseNutritionValueDouble(nutrition.calories) ?? 0.0
                let dailyCalorieTarget = getDailyCalorieTarget()
                macroProgressBar(macroName: "Kcal", currentValue: calories, gradient: LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), targetValue: dailyCalorieTarget, unit: "Kcal")
            }
            
            // Progress bars for each selected macro
            // Nutrition values are already per typical serving (for foods/meals)
            if trackedMacros.contains("Protein") {
                let protein = parseNutritionValueDouble(nutrition.protein) ?? 0.0
                macroProgressBar(macroName: "Protein", currentValue: protein, gradient: LinearGradient(colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.0, green: 0.8, blue: 0.8)], startPoint: .leading, endPoint: .trailing))
            }
            
            if trackedMacros.contains("Carbs") {
                let carbs = parseNutritionValueDouble(nutrition.carbohydrates) ?? 0.0
                macroProgressBar(macroName: "Carbs", currentValue: carbs, gradient: LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing))
            }
            
            if trackedMacros.contains("Fat") {
                let fat = parseNutritionValueDouble(nutrition.fat) ?? 0.0
                macroProgressBar(macroName: "Fat", currentValue: fat, gradient: LinearGradient(colors: [Color(red: 1.0, green: 0.843, blue: 0.0), Color(red: 0.678, green: 0.847, blue: 0.902)], startPoint: .leading, endPoint: .trailing))
            }
            
            if trackedMacros.contains("Fiber") {
                let fiber = parseNutritionValueDouble(nutrition.fiber) ?? 0.0
                macroProgressBar(macroName: "Fiber", currentValue: fiber, gradient: LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)], startPoint: .leading, endPoint: .trailing))
            }
            
            if trackedMacros.contains("Sugar") {
                let sugar = parseNutritionValueDouble(nutrition.sugar) ?? 0.0
                macroProgressBar(macroName: "Sugar", currentValue: sugar, gradient: LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing))
            }
            
            if trackedMacros.contains("Sodium") {
                let sodium = parseNutritionValueDouble(nutrition.sodium) ?? 0.0
                macroProgressBar(macroName: "Sodium", currentValue: sodium, gradient: LinearGradient(colors: [Color(red: 0.5, green: 0.3, blue: 0.7), Color(red: 0.7, green: 0.5, blue: 0.9)], startPoint: .leading, endPoint: .trailing), unit: "mg")
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }
    
    // MARK: - Micros View (Tracker Style)
    private func microsViewTrackerStyle(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Two separate buttons: Selection and Target Mode
            HStack {
                // Button 1: Tap To Select Your Micros
                Button(action: {
                    showingMicroSelection = true
                }) {
                    Text("Tap To Select Your Micros")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Button 2: (RDA) or (Custom) - for target numbers
                Button(action: {
                    showingMicroTargetModeSelection = true
                }) {
                    Text(micronutrientTargetMode == .standardRDA ? "(RDA)" : "(Custom)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 4)
            
            // Show source attribution in RDA mode
            if micronutrientTargetMode == .standardRDA {
                Text("Based on USDA Dietary Guidelines 2020-2025")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
            
            // Get user's selected micronutrients from profile
            let selectedMicronutrients = healthProfileManager.getTrackedMicronutrients()
            
            // Build micronutrient list with real data - show all selected, including 0 values
            // Nutrition values are already per typical serving (for foods/meals)
            ForEach(selectedMicronutrients, id: \.self) { name in
                let value = getMicronutrientValue(nutrition, name: name) ?? 0.0
                micronutrientRow(name: name, value: value)
            }
        }
    }
    
    private func microsView(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let vitaminD = nutrition.vitaminD, !vitaminD.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Vitamin D", vitaminD)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let vitaminE = nutrition.vitaminE, !vitaminE.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Vitamin E", vitaminE)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let potassium = nutrition.potassium, !potassium.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Potassium", potassium)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let vitaminK = nutrition.vitaminK, !vitaminK.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Vitamin K", vitaminK)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let magnesium = nutrition.magnesium, !magnesium.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Magnesium", magnesium)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let vitaminA = nutrition.vitaminA, !vitaminA.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Vitamin A", vitaminA)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let calcium = nutrition.calcium, !calcium.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Calcium", calcium)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let vitaminC = nutrition.vitaminC, !vitaminC.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Vitamin C", vitaminC)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let choline = nutrition.choline, !choline.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Choline", choline)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let iron = nutrition.iron, !iron.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Iron", iron)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let zinc = nutrition.zinc, !zinc.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Zinc", zinc)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let folate = nutrition.folate, !folate.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Folate (B9)", folate)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let vitaminB12 = nutrition.vitaminB12, !vitaminB12.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Vitamin B12", vitaminB12)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let vitaminB6 = nutrition.vitaminB6, !vitaminB6.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Vitamin B6", vitaminB6)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let selenium = nutrition.selenium, !selenium.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Selenium", selenium)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let copper = nutrition.copper, !copper.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Copper", copper)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let manganese = nutrition.manganese, !manganese.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Manganese", manganese)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
            if let thiamin = nutrition.thiamin, !thiamin.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    nutritionRow("Thiamin (B1)", thiamin)
                    Divider()
                        .background(colorScheme == .dark ? Color.white.opacity(0.4) : Color.gray.opacity(0.5))
                }
            }
        }
    }
    
    private func nutritionRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage() {
        // Look up imageHash from FoodCacheManager (analysis is already cached there)
        if let entry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == analysis.foodName &&
            entry.fullAnalysis.overallScore == analysis.overallScore
        }) {
            cachedEntry = entry
            isFavorite = entry.isFavorite
            // Update currentAnalysis with cached entry's fullAnalysis to include suggestions
            currentAnalysis = entry.fullAnalysis
            
            if let imageHash = entry.imageHash {
                // Direct lookup - instant load from disk
                if let image = foodCacheManager.loadImage(forHash: imageHash) {
                    cachedImage = image
                    print("🔍 ResultsView: Loaded image for hash: \(imageHash)")
                    return
                }
            }
        }
        
        // Fallback: Try to find image using name matching (for old analyses without exact match)
        DispatchQueue.global(qos: .userInitiated).async {
            let foodName = analysis.foodName.lowercased().trimmingCharacters(in: .whitespaces)
            let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
                return entryName == foodName ||
                       entryName.contains(foodName) ||
                       foodName.contains(entryName)
            }
            
            // Get the most recent matching entry
            if let matchingEntry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
                DispatchQueue.main.async {
                    self.cachedEntry = matchingEntry
                    self.isFavorite = matchingEntry.isFavorite
                    // Update currentAnalysis with cached entry's fullAnalysis to include suggestions
                    self.currentAnalysis = matchingEntry.fullAnalysis
                }
                
                if let imageHash = matchingEntry.imageHash {
                    if let image = foodCacheManager.loadImage(forHash: imageHash) {
                        DispatchQueue.main.async {
                            self.cachedImage = image
                            print("🔍 ResultsView: Loaded image from fallback match")
                        }
                    }
                }
            }
        }
    }
    
    private func toggleFavorite() {
        isFavorite.toggle()
        
        // Update the entry in FoodCacheManager
        if let entry = cachedEntry {
            foodCacheManager.updateEntryFavorite(cacheKey: entry.cacheKey, isFavorite: isFavorite)
        } else if let imageHash = cachedEntry?.imageHash {
            foodCacheManager.updateEntryFavorite(imageHash: imageHash, isFavorite: isFavorite)
        }
    }
    
    // MARK: - Loading Functions (Progressive Loading API Calls)
    
    private func loadKeyBenefits() {
        // If already loaded, don't reload
        if loadedKeyBenefits != nil {
            return
        }
        
        isLoadingKeyBenefits = true
        
        Task {
            do {
                let benefits = try await fetchKeyBenefits(foodName: analysis.foodName, summary: analysis.summary, score: analysis.overallScore)
                await MainActor.run {
                    loadedKeyBenefits = benefits
                    isLoadingKeyBenefits = false
                }
            } catch {
                print("❌ ResultsView: Failed to load key benefits: \(error.localizedDescription)")
                await MainActor.run {
                    // Fallback to empty array if API fails
                    loadedKeyBenefits = []
                    isLoadingKeyBenefits = false
                }
            }
        }
    }
    
    private func loadIngredients() {
        // If already loaded, don't reload
        if loadedIngredients != nil {
            return
        }
        
        isLoadingIngredients = true
        
        Task {
            do {
                let ingredients = try await fetchIngredients(foodName: analysis.foodName, summary: analysis.summary, score: analysis.overallScore)
                await MainActor.run {
                    loadedIngredients = ingredients
                    isLoadingIngredients = false
                }
            } catch {
                print("❌ ResultsView: Failed to load ingredients: \(error.localizedDescription)")
                await MainActor.run {
                    // Fallback to empty array if API fails
                    loadedIngredients = []
                    isLoadingIngredients = false
                }
            }
        }
    }
    
    // Check if nutrition info is valid (not all "N/A")
    private func isNutritionInfoValid(_ nutrition: NutritionInfo) -> Bool {
        // Check if any macro has a valid value (not "N/A" or empty)
        let macros = [nutrition.calories, nutrition.protein, nutrition.carbohydrates, nutrition.fat]
        return macros.contains { value in
            !value.isEmpty && value.uppercased() != "N/A" && parseNutritionValueDouble(value) != nil && parseNutritionValueDouble(value) ?? 0 > 0
        }
    }
    
    // Check if nutrition values are reasonable (not obviously wrong)
    private func isNutritionReasonable(_ nutrition: NutritionInfo, isMeal: Bool = false) -> Bool {
        guard let caloriesDouble = parseNutritionValueDouble(nutrition.calories) else { 
            // If calories can't be parsed, it's not reasonable
            return false 
        }
        let calories = Int(round(caloriesDouble))
        
        // For single foods, calories should be reasonable (< 500)
        // For meals/recipes, allow higher calories (up to 2000)
        let maxCalories = isMeal ? 2000 : 500
        
        if calories > maxCalories {
            print("⚠️ ResultsView: Nutrition validation failed - Calories (\(calories)) exceeds reasonable limit (\(maxCalories)) for \(isMeal ? "meal" : "single food")")
            return false
        }
        
        return true
    }
    
    private func loadNutritionInfo() {
        // Step 1: If already loaded with valid data (in-memory cache), don't reload
        if let loaded = loadedNutritionInfo, 
           isNutritionInfoValid(loaded),
           isNutritionReasonable(loaded, isMeal: analysis.foodNames != nil && !analysis.foodNames!.isEmpty) {
            print("ℹ️ ResultsView: Nutrition already loaded and valid (in-memory), skipping")
            return
        } else if let loaded = loadedNutritionInfo, isNutritionInfoValid(loaded) {
            print("⚠️ ResultsView: In-memory nutrition exists but is unreasonable, re-fetching from USDA...")
        }
        
        // Step 2: Check if current analysis has valid nutrition info (from SearchView calculation)
        let isMeal = analysis.foodNames != nil && !analysis.foodNames!.isEmpty
        if let currentNutrition = currentAnalysis.nutritionInfo {
            print("🔍 ResultsView: Found nutrition in currentAnalysis.nutritionInfo")
            print("🔍 ResultsView:   - Is meal: \(isMeal)")
            print("🔍 ResultsView:   - Is valid: \(isNutritionInfoValid(currentNutrition))")
            if isNutritionInfoValid(currentNutrition) {
                let isReasonable = isNutritionReasonable(currentNutrition, isMeal: isMeal)
                print("🔍 ResultsView:   - Is reasonable: \(isReasonable)")
                if isReasonable {
                    print("✅ ResultsView: Using nutrition from SearchView (currentAnalysis.nutritionInfo) - skipping API call")
                    loadedNutritionInfo = currentNutrition
                    return
                } else {
                    print("⚠️ ResultsView: Current analysis nutrition exists but failed reasonableness check, re-fetching...")
                    if let calories = parseNutritionValueDouble(currentNutrition.calories) {
                        print("⚠️ ResultsView:   - Calories: \(Int(round(calories)))")
                    }
                }
            } else {
                print("⚠️ ResultsView: Current analysis nutrition exists but is invalid, re-fetching...")
            }
        } else {
            print("🔍 ResultsView: No nutrition in currentAnalysis.nutritionInfo (will check cache/API)")
        }
        
        // Step 3: Check persistent cache (FoodCacheManager) for cached nutrition info
        // First, try using cachedEntry if already loaded
        if let entry = cachedEntry {
            if let cachedNutrition = entry.fullAnalysis.nutritionInfo, 
               isNutritionInfoValid(cachedNutrition),
               isNutritionReasonable(cachedNutrition, isMeal: entry.fullAnalysis.foodNames != nil && !entry.fullAnalysis.foodNames!.isEmpty) {
                print("✅ ResultsView: Found valid nutrition info in cached entry, using cache (no API call)")
                loadedNutritionInfo = cachedNutrition
                currentAnalysis = entry.fullAnalysis // Update currentAnalysis with cached data
                return
            } else if let cachedNutrition = entry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                print("⚠️ ResultsView: Cached entry nutrition exists but is unreasonable, re-fetching from USDA...")
            }
        }
        
        // Step 4: Search cache by food name and score (same logic as loadImage)
        if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == analysis.foodName &&
            entry.fullAnalysis.overallScore == analysis.overallScore
        }) {
            if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, 
               isNutritionInfoValid(cachedNutrition),
               isNutritionReasonable(cachedNutrition, isMeal: cachedEntry.fullAnalysis.foodNames != nil && !cachedEntry.fullAnalysis.foodNames!.isEmpty) {
                print("✅ ResultsView: Found valid nutrition info in cache by food name, using cache (no API call)")
                loadedNutritionInfo = cachedNutrition
                currentAnalysis = cachedEntry.fullAnalysis // Update currentAnalysis with cached data
                self.cachedEntry = cachedEntry // Store for future use
                return
            } else if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                print("⚠️ ResultsView: Cache nutrition by food name exists but is unreasonable, re-fetching from USDA...")
            }
        }
        
        // Step 5: Fallback to name matching (for old analyses without exact match)
        let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
            let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
            let foodName = analysis.foodName.lowercased().trimmingCharacters(in: .whitespaces)
            return entryName == foodName ||
                   entryName.contains(foodName) ||
                   foodName.contains(entryName)
        }
        
        if let matchingEntry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
            if let cachedNutrition = matchingEntry.fullAnalysis.nutritionInfo, 
               isNutritionInfoValid(cachedNutrition),
               isNutritionReasonable(cachedNutrition, isMeal: matchingEntry.fullAnalysis.foodNames != nil && !matchingEntry.fullAnalysis.foodNames!.isEmpty) {
                print("✅ ResultsView: Found valid nutrition info in cache by name match, using cache (no API call)")
                loadedNutritionInfo = cachedNutrition
                currentAnalysis = matchingEntry.fullAnalysis // Update currentAnalysis with cached data
                self.cachedEntry = matchingEntry // Store for future use
                return
            } else if let cachedNutrition = matchingEntry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                print("⚠️ ResultsView: Cache nutrition by name match exists but is unreasonable, re-fetching from USDA...")
            }
        }
        
        // Step 6: No cache found - make API call
        print("🚀 ResultsView: No cached nutrition found, starting API load for '\(analysis.foodName)'")
        isLoadingNutritionInfo = true
        
        Task {
            let startTime = Date()
            do {
                // Try Spoonacular first (fast, accurate)
                let nutrition: NutritionInfo
                if let spoonacularNutrition = try await fetchNutritionFromSpoonacular() {
                    nutrition = spoonacularNutrition
                    let duration = Date().timeIntervalSince(startTime)
                    print("✅ ResultsView: Loaded nutrition from Spoonacular in \(String(format: "%.2f", duration))s")
                } else {
                    // Fallback to AI if Spoonacular doesn't have the food
                    print("⚠️ ResultsView: Spoonacular lookup returned nil, falling back to AI")
                    nutrition = try await fetchNutritionInfo(foodName: analysis.foodName, summary: analysis.summary, score: analysis.overallScore)
                    let duration = Date().timeIntervalSince(startTime)
                    print("✅ ResultsView: Loaded nutrition from AI fallback in \(String(format: "%.2f", duration))s")
                }
                
                await MainActor.run {
                    loadedNutritionInfo = nutrition
                    isLoadingNutritionInfo = false
                    
                    // Update the cached analysis with the loaded nutrition info
                    updateCachedAnalysisWithNutrition(nutrition)
                    print("✅ ResultsView: Nutrition info displayed and cached")
                }
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                print("❌ ResultsView: Failed to load nutrition info after \(String(format: "%.2f", duration))s")
                print("❌ ResultsView: Error: \(error.localizedDescription)")
                print("❌ ResultsView: Error type: \(type(of: error))")
                if let spoonacularError = error as? SpoonacularError {
                    print("❌ ResultsView: Spoonacular error: \(spoonacularError.localizedDescription)")
                }
                await MainActor.run {
                    // Fallback to default values if API fails
                    loadedNutritionInfo = NutritionInfo(
                        calories: "N/A",
                        protein: "N/A",
                        carbohydrates: "N/A",
                        fat: "N/A",
                        sugar: "N/A",
                        fiber: "N/A",
                        sodium: "N/A"
                    )
                    isLoadingNutritionInfo = false
                    print("⚠️ ResultsView: Using fallback N/A values")
                }
            }
        }
    }
    
    private func fetchNutritionFromSpoonacular() async throws -> NutritionInfo? {
        print("🔍 ResultsView: Starting tiered nutrition lookup")
        print("🔍 ResultsView: Food name: '\(analysis.foodName)'")
        
        // Check if this is a meal (has foodNames array)
        if let foodNames = analysis.foodNames, !foodNames.isEmpty {
            print("🔍 ResultsView: Detected meal with \(foodNames.count) ingredients: \(foodNames.joined(separator: ", "))")
            // Meal: aggregate nutrition from all ingredients using tiered lookup
            return try await aggregateNutritionForMealWithTieredLookup(foodNames: foodNames)
        } else {
            // Single food: Estimate typical serving size first, then get nutrition for that serving
            print("🔍 ResultsView: Estimating typical serving size for single food '\(analysis.foodName)'")
            let servingInfo: (size: String, weightGrams: Double)
            do {
                servingInfo = try await AIService.shared.estimateTypicalServingSize(foodName: analysis.foodName, isRecipe: false)
                print("✅ ResultsView: Estimated serving size: \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
            } catch {
                print("⚠️ ResultsView: Failed to estimate serving size, using default 100g: \(error)")
                servingInfo = (size: "1 serving", weightGrams: 100.0)
            }
            
            // Get nutrition for the estimated serving size (not default 100g)
            if let nutrition = try await NutritionService.shared.getNutritionForFood(analysis.foodName, amount: servingInfo.weightGrams, unit: "g") {
                print("✅ ResultsView: Found nutrition via tiered lookup for \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
                return nutrition
            }
            // Fallback to component extraction (existing logic)
            print("🔍 ResultsView: Tiered lookup failed, falling back to component extraction")
            return try await fetchNutritionForFoodWithComponents()
        }
    }
    
    /// Fetch nutrition for a single food by extracting components with amounts and aggregating
    private func fetchNutritionForFoodWithComponents() async throws -> NutritionInfo? {
        print("🔍 ResultsView: Extracting components with amounts for '\(analysis.foodName)'")
        
        // Step 1: Extract food components with estimated amounts using AI
        let components: [(name: String, amountGrams: Double)]
        do {
            components = try await AIService.shared.extractFoodComponents(
                foodName: analysis.foodName,
                summary: analysis.summary
            )
        } catch {
            print("⚠️ ResultsView: Failed to extract components, falling back to direct lookup")
            return try await getNutritionForSingleFood(foodName: analysis.foodName)
        }
        
        guard !components.isEmpty else {
            print("⚠️ ResultsView: No components extracted, falling back to direct lookup")
            return try await getNutritionForSingleFood(foodName: analysis.foodName)
        }
        
        let componentList = components.map { "\($0.name) (\(Int($0.amountGrams))g)" }.joined(separator: ", ")
        print("✅ ResultsView: Extracted \(components.count) components: \(componentList)")
        
        // Step 2: Aggregate nutrition from components using their specific amounts
        guard let aggregatedNutrition = try await aggregateNutritionForComponentsWithAmounts(components: components) else {
            print("⚠️ ResultsView: Failed to aggregate nutrition from components")
            return nil
        }
        
        print("✅ ResultsView: Using aggregated nutrition with component-specific amounts")
        
        return aggregatedNutrition
    }
    
    /// Aggregate nutrition from components with specific amounts (more accurate than meal method)
    private func aggregateNutritionForComponentsWithAmounts(components: [(name: String, amountGrams: Double)]) async throws -> NutritionInfo? {
        print("🔍 ResultsView: Aggregating nutrition for \(components.count) components with specific amounts")
        var aggregator = NutritionAggregator()
        var foundAny = false
        var foundCount = 0
        
        // Lookup nutrition for each component at its specific amount
        for (index, component) in components.enumerated() {
            print("🔍 ResultsView: Looking up component \(index + 1)/\(components.count): '\(component.name)' at \(Int(component.amountGrams))g")
            do {
                // Get nutrition for the specific amount (not default 100g)
                if let nutrition = try await getNutritionForFoodAtAmount(foodName: component.name, amount: component.amountGrams) {
                    foundAny = true
                    foundCount += 1
                    print("✅ ResultsView: Found nutrition for '\(component.name)' at \(Int(component.amountGrams))g")
                    aggregator.add(nutrition)
                } else {
                    print("⚠️ ResultsView: No nutrition found for '\(component.name)'")
                }
            } catch {
                print("❌ ResultsView: Error looking up '\(component.name)': \(error.localizedDescription)")
                // Continue with other components even if one fails
            }
        }
        
        print("📊 ResultsView: Found nutrition for \(foundCount)/\(components.count) components")
        
        guard foundAny else {
            print("⚠️ ResultsView: No nutrition data found for any component")
            return nil
        }
        
        print("✅ ResultsView: Successfully aggregated nutrition with component-specific amounts")
        return aggregator.toNutritionInfo()
    }
    
    /// Get nutrition for a food at a specific amount (in grams)
    private func getNutritionForFoodAtAmount(foodName: String, amount: Double) async throws -> NutritionInfo? {
        print("🔍 ResultsView: Getting nutrition for '\(foodName)' at \(Int(amount))g")
        
        // Try tiered lookup first (USDA → Spoonacular → AI)
        if let nutrition = try await NutritionService.shared.getNutritionForFood(foodName, amount: amount, unit: "g") {
            print("✅ ResultsView: Found nutrition via tiered lookup at \(Int(amount))g")
            return nutrition
        }
        
        // Fallback to direct Spoonacular lookup
        do {
            guard let nutrition = try await spoonacularService.getNutritionForFood(foodName, amount: amount, unit: "g") else {
                print("⚠️ ResultsView: Spoonacular returned nil for '\(foodName)'")
                return nil
            }
            
            print("✅ ResultsView: Received Spoonacular nutrition data for '\(foodName)' at \(Int(amount))g")
            let converted = convertSpoonacularNutritionToNutritionInfo(nutrition)
            print("✅ ResultsView: Converted nutrition - Calories: \(converted.calories), Protein: \(converted.protein)")
            return converted
        } catch {
            print("❌ ResultsView: Error getting nutrition for '\(foodName)': \(error.localizedDescription)")
            throw error
        }
    }
    
    // REMOVED: scaleNutritionInfo function - no longer scaling nutrition values
    // Using aggregated values directly for accuracy (same as meals)
    
    private func formatNutritionValue(_ amount: Double, unit: String) -> String {
        // Round to whole numbers for display
        return "\(Int(round(amount)))\(unit)"
    }
    
    /// Aggregate nutrition for meal using tiered lookup for each component
    private func aggregateNutritionForMealWithTieredLookup(foodNames: [String]) async throws -> NutritionInfo? {
        print("🔍 ResultsView: Aggregating nutrition for meal with \(foodNames.count) ingredients using tiered lookup")
        var aggregator = NutritionAggregator()
        var foundAny = false
        var foundCount = 0
        
        // Lookup nutrition for each ingredient using tiered lookup and sum them
        // Estimate typical serving size for each ingredient first
        for (index, foodName) in foodNames.enumerated() {
            print("🔍 ResultsView: Looking up ingredient \(index + 1)/\(foodNames.count): '\(foodName)'")
            do {
                // Estimate typical serving size for this ingredient in a meal context
                let servingInfo: (size: String, weightGrams: Double)
                do {
                    servingInfo = try await AIService.shared.estimateTypicalServingSize(foodName: foodName, isRecipe: false)
                    print("✅ ResultsView: Estimated serving size for '\(foodName)': \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
                } catch {
                    print("⚠️ ResultsView: Failed to estimate serving size for '\(foodName)', using default 100g: \(error)")
                    servingInfo = (size: "1 serving", weightGrams: 100.0)
                }
                
                // Use tiered lookup (USDA → Spoonacular → AI) with estimated serving size
                if let nutrition = try await NutritionService.shared.getNutritionForFood(foodName, amount: servingInfo.weightGrams, unit: "g") {
                    foundAny = true
                    foundCount += 1
                    print("✅ ResultsView: Found nutrition for '\(foodName)' via tiered lookup at \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
                    aggregator.add(nutrition)
                } else {
                    print("⚠️ ResultsView: No nutrition found for '\(foodName)'")
                }
            } catch {
                print("❌ ResultsView: Error looking up '\(foodName)': \(error.localizedDescription)")
                // Continue with other ingredients even if one fails
            }
        }
        
        print("📊 ResultsView: Found nutrition for \(foundCount)/\(foodNames.count) ingredients")
        
        guard foundAny else {
            print("⚠️ ResultsView: No nutrition data found for any ingredient")
            return nil
        }
        
        print("✅ ResultsView: Successfully aggregated nutrition with tiered lookup")
        return aggregator.toNutritionInfo()
    }
    
    private func aggregateNutritionForMeal(foodNames: [String]) async throws -> NutritionInfo? {
        print("🔍 ResultsView: Aggregating nutrition for meal with \(foodNames.count) ingredients")
        var aggregator = NutritionAggregator()
        var foundAny = false
        var foundCount = 0
        
        // Lookup nutrition for each ingredient and sum them
        for (index, foodName) in foodNames.enumerated() {
            print("🔍 ResultsView: Looking up ingredient \(index + 1)/\(foodNames.count): '\(foodName)'")
            do {
                if let nutrition = try await getNutritionForSingleFood(foodName: foodName) {
                    foundAny = true
                    foundCount += 1
                    print("✅ ResultsView: Found nutrition for '\(foodName)'")
                    aggregator.add(nutrition)
                } else {
                    print("⚠️ ResultsView: No nutrition found for '\(foodName)'")
                }
            } catch {
                print("❌ ResultsView: Error looking up '\(foodName)': \(error.localizedDescription)")
                // Continue with other ingredients even if one fails
            }
        }
        
        print("📊 ResultsView: Found nutrition for \(foundCount)/\(foodNames.count) ingredients")
        
        guard foundAny else {
            print("⚠️ ResultsView: No nutrition data found for any ingredient")
            return nil
        }
        
        print("✅ ResultsView: Successfully aggregated nutrition for meal")
        return aggregator.toNutritionInfo()
    }
    
    private func getNutritionForSingleFood(foodName: String) async throws -> NutritionInfo? {
        print("🔍 ResultsView: Getting nutrition for '\(foodName)'")
        
        // Estimate typical serving size first
        let servingInfo: (size: String, weightGrams: Double)
        do {
            servingInfo = try await AIService.shared.estimateTypicalServingSize(foodName: foodName, isRecipe: false)
            print("✅ ResultsView: Estimated serving size: \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
        } catch {
            print("⚠️ ResultsView: Failed to estimate serving size, using default 100g: \(error)")
            servingInfo = (size: "1 serving", weightGrams: 100.0)
        }
        
        // Try tiered lookup first (USDA → Spoonacular → AI) with estimated serving size
        if let nutrition = try await NutritionService.shared.getNutritionForFood(foodName, amount: servingInfo.weightGrams, unit: "g") {
            print("✅ ResultsView: Found nutrition via tiered lookup for \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
            return nutrition
        }
        
        // Fallback to direct Spoonacular lookup (for backward compatibility) with estimated serving size
        do {
            guard let nutrition = try await spoonacularService.getNutritionForFood(foodName, amount: servingInfo.weightGrams, unit: "g") else {
                print("⚠️ ResultsView: Spoonacular returned nil for '\(foodName)'")
                return nil
            }
            
            print("✅ ResultsView: Received Spoonacular nutrition data for '\(foodName)' at \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
            let converted = convertSpoonacularNutritionToNutritionInfo(nutrition)
            print("✅ ResultsView: Converted nutrition - Calories: \(converted.calories), Protein: \(converted.protein)")
            return converted
        } catch {
            print("❌ ResultsView: Error getting nutrition for '\(foodName)': \(error.localizedDescription)")
            throw error
        }
    }
    
    private func convertSpoonacularNutritionToNutritionInfo(_ spoonNutrition: SpoonacularIngredientNutrition) -> NutritionInfo {
        print("🔄 ResultsView: Converting Spoonacular nutrition to NutritionInfo")
        print("🔄 ResultsView: Processing \(spoonNutrition.nutrition.nutrients.count) nutrients")
        var nutritionDict: [String: String] = [:]
        
        // Extract nutrients from Spoonacular response
        for nutrient in spoonNutrition.nutrition.nutrients {
            let originalName = nutrient.name
            let name = nutrient.name.lowercased()
            let amount = nutrient.amount
            let unit = nutrient.unit
            
            // Debug: log nutrient names we're seeing (only once)
            if nutritionDict.isEmpty {
                print("📋 ResultsView: Sample nutrients from Spoonacular:")
                for (idx, nut) in spoonNutrition.nutrition.nutrients.prefix(10).enumerated() {
                    print("   \(idx + 1). \(nut.name): \(nut.amount) \(nut.unit)")
                }
            }
            
            // Map Spoonacular nutrient names to our format
            switch name {
            case "calories", "energy":
                nutritionDict["calories"] = formatNutritionValue(amount, unit: unit)
            case "protein":
                nutritionDict["protein"] = formatNutritionValue(amount, unit: unit)
            case "carbohydrates", "net carbs":
                nutritionDict["carbohydrates"] = formatNutritionValue(amount, unit: unit)
            case "fat", "total fat":
                nutritionDict["fat"] = formatNutritionValue(amount, unit: unit)
            case "sugar":
                nutritionDict["sugar"] = formatNutritionValue(amount, unit: unit)
            case "fiber", "dietary fiber":
                nutritionDict["fiber"] = formatNutritionValue(amount, unit: unit)
            case "sodium":
                nutritionDict["sodium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin d", "vitamin d (d2 + d3)":
                nutritionDict["vitaminD"] = formatNutritionValue(amount, unit: unit)
            case "vitamin e":
                nutritionDict["vitaminE"] = formatNutritionValue(amount, unit: unit)
            case "potassium":
                nutritionDict["potassium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin k":
                nutritionDict["vitaminK"] = formatNutritionValue(amount, unit: unit)
            case "magnesium":
                nutritionDict["magnesium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin a", "vitamin a, rae":
                // Spoonacular provides Vitamin A in IU, convert to mcg RAE (1 IU = 0.3 mcg RAE for retinol)
                if unit.lowercased() == "iu" {
                    let mcgRAE = amount * 0.3
                    nutritionDict["vitaminA"] = formatNutritionValue(mcgRAE, unit: "mcg")
                } else {
                    nutritionDict["vitaminA"] = formatNutritionValue(amount, unit: unit)
                }
            case "calcium":
                nutritionDict["calcium"] = formatNutritionValue(amount, unit: unit)
            case "vitamin c":
                nutritionDict["vitaminC"] = formatNutritionValue(amount, unit: unit)
            case "choline":
                nutritionDict["choline"] = formatNutritionValue(amount, unit: unit)
            case "iron":
                nutritionDict["iron"] = formatNutritionValue(amount, unit: unit)
            case "iodine":
                nutritionDict["iodine"] = formatNutritionValue(amount, unit: unit)
            case "zinc":
                nutritionDict["zinc"] = formatNutritionValue(amount, unit: unit)
            case "folate", "folic acid":
                nutritionDict["folate"] = formatNutritionValue(amount, unit: unit)
            case "vitamin b12", "vitamin b-12":
                nutritionDict["vitaminB12"] = formatNutritionValue(amount, unit: unit)
            case "vitamin b6", "vitamin b-6":
                nutritionDict["vitaminB6"] = formatNutritionValue(amount, unit: unit)
            case "selenium":
                nutritionDict["selenium"] = formatNutritionValue(amount, unit: unit)
            case "copper":
                nutritionDict["copper"] = formatNutritionValue(amount, unit: unit)
            case "manganese":
                nutritionDict["manganese"] = formatNutritionValue(amount, unit: unit)
            case "thiamin", "vitamin b1", "vitamin b-1":
                nutritionDict["thiamin"] = formatNutritionValue(amount, unit: unit)
            default:
                break
            }
        }
        
        let result = NutritionInfo(
            calories: nutritionDict["calories"] ?? "0",
            protein: nutritionDict["protein"] ?? "0g",
            carbohydrates: nutritionDict["carbohydrates"] ?? "0g",
            fat: nutritionDict["fat"] ?? "0g",
            sugar: nutritionDict["sugar"] ?? "0g",
            fiber: nutritionDict["fiber"] ?? "0g",
            sodium: nutritionDict["sodium"] ?? "0mg",
            saturatedFat: nutritionDict["saturatedFat"],
            vitaminD: nutritionDict["vitaminD"],
            vitaminE: nutritionDict["vitaminE"],
            potassium: nutritionDict["potassium"],
            vitaminK: nutritionDict["vitaminK"],
            magnesium: nutritionDict["magnesium"],
            vitaminA: nutritionDict["vitaminA"],
            calcium: nutritionDict["calcium"],
            vitaminC: nutritionDict["vitaminC"],
            choline: nutritionDict["choline"],
            iron: nutritionDict["iron"],
            iodine: nutritionDict["iodine"],
            zinc: nutritionDict["zinc"],
            folate: nutritionDict["folate"],
            vitaminB12: nutritionDict["vitaminB12"],
            vitaminB6: nutritionDict["vitaminB6"],
            selenium: nutritionDict["selenium"],
            copper: nutritionDict["copper"],
            manganese: nutritionDict["manganese"],
            thiamin: nutritionDict["thiamin"]
        )
        
        print("✅ ResultsView: Conversion complete - Macros: \(result.calories) cal, \(result.protein) protein")
        let microCount = [result.vitaminD, result.vitaminE, result.potassium, result.vitaminK, result.magnesium, result.vitaminA, result.calcium, result.vitaminC, result.choline, result.iron, result.zinc, result.folate, result.vitaminB12, result.vitaminB6, result.selenium, result.copper, result.manganese, result.thiamin].compactMap { $0 }.count
        print("📊 ResultsView: Micros found: \(microCount)/18")
        
        return result
    }
    
    
    private func parseNutritionValue(_ value: String) -> Double? {
        // Remove common units and parse number
        // Handle both "mcg" and "µg" (Unicode microgram symbol) - Spoonacular uses "µg"
        var cleaned = value.lowercased()
            .replacingOccurrences(of: "kcal", with: "")
            .replacingOccurrences(of: "mg", with: "")  // Must come before "g" to avoid partial matches
            .replacingOccurrences(of: "mcg", with: "")
            .replacingOccurrences(of: "µg", with: "")  // Unicode microgram symbol (U+00B5)
            .replacingOccurrences(of: "μg", with: "")  // Alternative microgram symbol
            .replacingOccurrences(of: "g", with: "")
            .replacingOccurrences(of: "iu", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any remaining non-numeric characters except decimal point and minus sign
        cleaned = cleaned.filter { $0.isNumber || $0 == "." || $0 == "-" }
        
        guard !cleaned.isEmpty else {
            print("❌ ResultsView: parseNutritionValue - cleaned string is empty for '\(value)'")
            return nil
        }
        
        if let result = Double(cleaned) {
            return result
        } else {
            print("❌ ResultsView: parseNutritionValue - failed to convert '\(cleaned)' to Double from '\(value)'")
            return nil
        }
    }
    
    private func updateCachedAnalysisWithNutrition(_ nutrition: NutritionInfo) {
        // Find the cached entry for this analysis
        if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == analysis.foodName &&
            entry.fullAnalysis.overallScore == analysis.overallScore
        }) {
            // Create updated analysis with nutrition info
            let updatedAnalysis = FoodAnalysis(
                foodName: cachedEntry.fullAnalysis.foodName,
                overallScore: cachedEntry.fullAnalysis.overallScore,
                summary: cachedEntry.fullAnalysis.summary,
                healthScores: cachedEntry.fullAnalysis.healthScores,
                keyBenefits: cachedEntry.fullAnalysis.keyBenefits,
                ingredients: cachedEntry.fullAnalysis.ingredients,
                bestPreparation: cachedEntry.fullAnalysis.bestPreparation,
                servingSize: cachedEntry.fullAnalysis.servingSize,
                nutritionInfo: nutrition, // Updated nutrition info
                scanType: cachedEntry.fullAnalysis.scanType,
                foodNames: cachedEntry.fullAnalysis.foodNames,
                foodPortions: cachedEntry.fullAnalysis.foodPortions,
                suggestions: cachedEntry.fullAnalysis.suggestions
            )
            
            // Update the cached entry with the new analysis
            foodCacheManager.cacheAnalysis(updatedAnalysis, imageHash: cachedEntry.imageHash, scanType: cachedEntry.scanType)
            
            // Also update currentAnalysis for this view
            currentAnalysis = updatedAnalysis
            
            print("✅ ResultsView: Updated cached analysis with nutrition info for \(analysis.foodName)")
        } else {
            print("⚠️ ResultsView: Could not find cached entry to update for \(analysis.foodName)")
        }
    }
    
    // MARK: - API Functions for Progressive Loading
    
    private func fetchKeyBenefits(foodName: String, summary: String, score: Int) async throws -> [String] {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Based on this food analysis, provide 3-5 key health benefits.
        
        Food: \(foodName)
        Summary: \(summary)
        Longevity Score: \(score)/100
        
        Return ONLY a JSON array of benefit strings (no markdown, no explanation):
        {
            "keyBenefits": ["Benefit 1", "Benefit 2", "Benefit 3"]
        }
        
        Focus on specific, actionable health benefits. Be concise (one short sentence per benefit).
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
        
        guard let jsonData = cleanedText.data(using: .utf8),
              let responseDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let benefits = responseDict["keyBenefits"] as? [String] else {
            throw NSError(domain: "Invalid JSON format", code: 0, userInfo: nil)
        }
        
        return benefits
    }
    
    private func fetchIngredients(foodName: String, summary: String, score: Int) async throws -> [FoodIngredient] {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Based on this food analysis, provide a detailed breakdown of major ingredients/components and their health impact.
        
        Food: \(foodName)
        Summary: \(summary)
        Longevity Score: \(score)/100
        
        Return ONLY this JSON structure (no markdown, no explanation):
        {
            "ingredients": [
                {
                    "name": "Ingredient name",
                    "impact": "positive|negative|neutral",
                    "explanation": "Brief explanation of health impact"
                }
            ]
        }
        
        List 5-10 major ingredients/components. Be specific about health impacts.
        """
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 400,
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
        
        guard let jsonData = cleanedText.data(using: .utf8),
              let responseDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let ingredientsArray = responseDict["ingredients"] as? [[String: Any]] else {
            throw NSError(domain: "Invalid JSON format", code: 0, userInfo: nil)
        }
        
        let ingredients = try ingredientsArray.map { dict -> FoodIngredient in
            guard let name = dict["name"] as? String,
                  let impact = dict["impact"] as? String,
                  let explanation = dict["explanation"] as? String else {
                throw NSError(domain: "Invalid ingredient format", code: 0, userInfo: nil)
            }
            return FoodIngredient(name: name, impact: impact, explanation: explanation)
        }
        
        return ingredients
    }
    
    private func fetchNutritionInfo(foodName: String, summary: String, score: Int) async throws -> NutritionInfo {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Based on this food analysis, provide estimated nutritional information for a standard serving.
        
        Food: \(foodName)
        Summary: \(summary)
        Longevity Score: \(score)/100
        
        Return ONLY this JSON structure (no markdown, no explanation):
        {
            "nutritionInfo": {
                "calories": "XXX kcal",
                "protein": "XXg",
                "carbohydrates": "XXg",
                "fat": "XXg",
                "sugar": "XXg",
                "fiber": "XXg",
                "sodium": "XXXmg",
                "vitaminD": "XXX IU",
                "vitaminE": "XX mg",
                "potassium": "XXX mg",
                "vitaminK": "XXX mcg",
                "magnesium": "XXX mg",
                "vitaminA": "XXX mcg",
                "calcium": "XXX mg",
                "vitaminC": "XXX mg",
                "choline": "XXX mg",
                "iron": "XX mg",
                "zinc": "XX mg",
                "folate": "XXX mcg",
                "vitaminB12": "X.X mcg",
                "vitaminB6": "X.X mg",
                "selenium": "XXX mcg",
                "copper": "X.X mg",
                "manganese": "X.X mg",
                "thiamin": "X.X mg"
            }
        }
        
        Provide realistic estimates based on the food type and score. Use standard serving sizes.
        For micronutrients, provide estimates based on typical values for this food type. If a micronutrient is not present in significant amounts, use "0" or omit the field.
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
        
        guard let jsonData = cleanedText.data(using: .utf8),
              let responseDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let nutritionDict = responseDict["nutritionInfo"] as? [String: String],
              let calories = nutritionDict["calories"],
              let protein = nutritionDict["protein"],
              let carbohydrates = nutritionDict["carbohydrates"],
              let fat = nutritionDict["fat"],
              let sugar = nutritionDict["sugar"],
              let fiber = nutritionDict["fiber"],
              let sodium = nutritionDict["sodium"] else {
            throw NSError(domain: "Invalid JSON format", code: 0, userInfo: nil)
        }
        
        // Extract saturatedFat (optional)
        let saturatedFat = nutritionDict["saturatedFat"]
        
        // Extract micronutrients (optional - may not all be present)
        let vitaminD = nutritionDict["vitaminD"]
        let vitaminE = nutritionDict["vitaminE"]
        let potassium = nutritionDict["potassium"]
        let vitaminK = nutritionDict["vitaminK"]
        let magnesium = nutritionDict["magnesium"]
        let vitaminA = nutritionDict["vitaminA"]
        let calcium = nutritionDict["calcium"]
        let vitaminC = nutritionDict["vitaminC"]
        let choline = nutritionDict["choline"]
        let iron = nutritionDict["iron"]
        let iodine = nutritionDict["iodine"]
        let zinc = nutritionDict["zinc"]
        let folate = nutritionDict["folate"]
        let vitaminB12 = nutritionDict["vitaminB12"]
        let vitaminB6 = nutritionDict["vitaminB6"]
        let selenium = nutritionDict["selenium"]
        let copper = nutritionDict["copper"]
        let manganese = nutritionDict["manganese"]
        let thiamin = nutritionDict["thiamin"]
        
        return NutritionInfo(
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            sugar: sugar,
            fiber: fiber,
            sodium: sodium,
            saturatedFat: nutritionDict["saturatedFat"],
            vitaminD: vitaminD,
            vitaminE: vitaminE,
            potassium: potassium,
            vitaminK: vitaminK,
            magnesium: magnesium,
            vitaminA: vitaminA,
            calcium: calcium,
            vitaminC: vitaminC,
            choline: choline,
            iron: iron,
            iodine: iodine,
            zinc: zinc,
            folate: folate,
            vitaminB12: vitaminB12,
            vitaminB6: vitaminB6,
            selenium: selenium,
            copper: copper,
            manganese: manganese,
            thiamin: thiamin
        )
    }
    
    private var scoreCard: some View {
        VStack(spacing: 16) {
            Text(analysis.foodName)
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // Score Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 15)
                    .frame(width: 180, height: 180)
                
                if analysis.overallScore != -1 {
                    Circle()
                        .trim(from: 0, to: max(0, min(1, CGFloat(analysis.overallScore) / 100)))
                        .stroke(
                            scoreColor(analysis.overallScore),
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                }
                
                VStack {
                    if analysis.overallScore == -1 {
                        Text("—")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(scoreColor(analysis.overallScore))
                    } else {
                        Text("\(analysis.overallScore)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(scoreColor(analysis.overallScore))
                    }
                    
                    Text(scoreLabel(analysis.overallScore))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)
            
            VStack(spacing: 8) {
                Text(analysis.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                // Longevity-population reassurance (only for qualifying high-quality meals)
                if analysis.qualifiesForLongevityReassurance {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                        Text(analysis.longevityReassurancePhrase)
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                            .italic()
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                }
            }
        }
        .padding(30)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // Normalize profile goal names to canonical identifiers
    private func normalizeHealthGoal(_ goal: String) -> String {
        let goalLower = goal.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Handle Blood Sugar variants
        if goalLower.contains("blood") && goalLower.contains("sugar") {
            return "blood_sugar"
        }
        if goalLower.contains("glycemic") || goalLower.contains("glucose") {
            return "blood_sugar"
        }
        
        // Handle other common variants
        let normalized = goalLower
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
        
        return normalized
    }
    
    // Helper function to map normalized profile goal names to health score category names
    // Returns mapping even if score is -1 (to ensure all selected goals render)
    private func mapProfileGoalToCategory(_ goal: String) -> (category: String, icon: String, label: String, score: Int)? {
        let normalized = normalizeHealthGoal(goal)
        
        switch normalized {
        case "heart health":
            return ("Heart", "❤️", "Heart\nHealth", currentAnalysis.healthScores.heartHealth)
        case "brain health":
            return ("Brain", "🧠", "Brain\nHealth", currentAnalysis.healthScores.brainHealth)
        case "weight management":
            return ("Weight", "⚖️", "Weight", currentAnalysis.healthScores.weightManagement)
        case "immune support":
            return ("Immune", "🛡️", "Immune", currentAnalysis.healthScores.immune)
        case "blood sugar", "blood_sugar":
            return ("Blood Sugar", "🩸", "Blood Sugar", currentAnalysis.healthScores.bloodSugar)
        case "energy":
            return ("Energy", "⚡", "Energy", currentAnalysis.healthScores.energy)
        case "sleep quality", "sleep":
            return ("Sleep", "😴", "Sleep", currentAnalysis.healthScores.sleep)
        case "stress management", "stress":
            return ("Stress", "🧘", "Stress", currentAnalysis.healthScores.stress)
        case "skin health", "skin":
            return ("Skin", "✨", "Skin", currentAnalysis.healthScores.skin)
        case "joint health", "joints":
            return ("Joints", "🦴", "Joint\nHealth", currentAnalysis.healthScores.jointHealth)
        case "bone/muscle health", "bone muscle health", "bones muscle health":
            return ("Joints", "🦴", "Bones &\nJoints", currentAnalysis.healthScores.jointHealth)
        case "digestive health", "digestive":
            return ("Detox/Liver", "🧪", "Detox/\nLiver", currentAnalysis.healthScores.detoxLiver)
        case "hormonal balance", "hormonal":
            return ("Mood", "😊", "Mood", currentAnalysis.healthScores.mood)
        default:
            // Try partial matching for Blood Sugar
            if normalized.contains("blood") && normalized.contains("sugar") {
                return ("Blood Sugar", "🩸", "Blood Sugar", currentAnalysis.healthScores.bloodSugar)
            }
            return nil
        }
    }
    
    @ViewBuilder
    private var healthScoresGrid: some View {
        let userHealthGoals = healthProfileManager.getHealthGoals()
        
        // Map user-selected goals to categories (always returns mapping, even if score is -1)
        let filteredGoals = userHealthGoals.compactMap { mapProfileGoalToCategory($0) }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Research For Your Health Goals")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            
            if filteredGoals.isEmpty {
                // If no user goals selected, show message
                Text("Select health goals in your profile to see personalized research.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // 3-column grid matching Supplements style - reuse TappableHealthScoreBox component
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(filteredGoals, id: \.category) { goal in
                        // Reuse Supplements component but with sheet navigation for Full Analysis
                        TappableHealthScoreBox(
                            icon: goal.icon,
                            label: goal.label,
                            score: goal.score,
                            category: goal.category,
                            analysis: currentAnalysis,
                            isExpanded: false, // Full Analysis uses sheet, not inline expansion
                            onTap: { category, score in
                                // Open HealthDetailView sheet (same as old behavior)
                                if score != -1 {
                                    healthDetailItem = HealthDetailItem(category: goal.label, score: score)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func healthScoreItem(_ icon: String, _ label: String, _ score: Int) -> some View {
        Button(action: {
            // Only allow tap if score is available
            if score != -1 {
                healthDetailItem = HealthDetailItem(category: label, score: score)
            }
        }) {
            VStack(spacing: 8) {
                Text(icon)
                    .font(.largeTitle)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if score == -1 {
                    Text("—")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(score))
                } else {
                    Text("\(score)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(score))
                }
            }
            .padding(10)
        }
        .disabled(score == -1)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .center, spacing: 15) {
            Text("Nutritional Components Analysis")
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Tap to see detailed breakdown")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(Array(analysis.ingredientsOrDefault.enumerated()), id: \.offset) { index, ingredient in
                ingredientRow(ingredient, index: index)
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func ingredientRow(_ ingredient: FoodIngredient, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if expandedIngredients.contains(index) {
                    expandedIngredients.remove(index)
                } else {
                    expandedIngredients.insert(index)
                }
            }) {
                HStack {
                    HStack(spacing: 10) {
                        Text(impactIcon(ingredient.impact))
                            .font(.title3)
                        
                        Text(ingredient.name)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Image(systemName: expandedIngredients.contains(index) ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
            }
            .padding(15)
            .background(impactBackgroundColor(ingredient.impact))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(impactBorderColor(ingredient.impact), lineWidth: 1)
            )
            
            if expandedIngredients.contains(index) {
                Text(ingredient.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(colorScheme == .dark ? Color.black : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Text("🏆")
                    .foregroundColor(Color(red: 0.608, green: 0.827, blue: 0.835))
                Text("Key Benefits")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(analysis.keyBenefitsOrDefault, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 10) {
                        Text("✓")
                            .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                            .fontWeight(.bold)
                        
                        Text(benefit)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private var bestPracticesDropdown: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isBestPracticesExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color(red: 1.0, green: 0.8, blue: 0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Text("Best Practices")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isBestPracticesExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isBestPracticesExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Only show Preparation if it's NOT healthier choices text
                    let bestPrep = currentAnalysis.bestPreparationOrDefault
                    
                    if !bestPrep.isEmpty && !isHealthierChoicesText(bestPrep) {
                        Text(bestPrep)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Serving Size:")
                            .fontWeight(.semibold)
                        Text(analysis.servingSize)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // Helper functions
    private func scoreColor(_ score: Int) -> Color {
        // Handle unavailable scores
        if score == -1 {
            return Color.gray
        }
        
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
        }
    }
    
    private func scoreLabel(_ score: Int) -> String {
        // Handle unavailable scores
        if score == -1 {
            return "Unavailable"
        }
        
        switch score {
        case 90...100: return "Exceptional"
        case 80...89: return "Excellent"
        case 70...79: return "Very Good"
        case 60...69: return "Good"
        case 50...59: return "Moderate"
        case 40...49: return "Fair"
        default: return "Limited"
        }
    }
    
    private func impactIcon(_ impact: String) -> String {
        switch impact {
        case "positive": return "✅"
        case "negative": return "❌"
        default: return "➖"
        }
    }
    
    private func impactBackgroundColor(_ impact: String) -> Color {
        switch impact {
        case "positive": return Color.green.opacity(0.1)
        case "negative": return Color.red.opacity(0.1)
        default: return Color.gray.opacity(0.1)
        }
    }
    
    private func impactBorderColor(_ impact: String) -> Color {
        switch impact {
        case "positive": return Color(red: 0.608, green: 0.827, blue: 0.835)
        case "negative": return Color.red.opacity(0.5)
        default: return Color.gray.opacity(0.3)
        }
    }
    
    private func nutritionRowCompact(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
    
    // MARK: - Helper: Detect Healthier Choices Text
    
    private func isHealthierChoicesText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        // Check for brand name patterns or "or" separator indicating healthier choices
        let brandIndicators = ["kerrygold", "rao's", "dave's", "ezekiel", "siete", "beanfields", "amy's", "organic valley", "muir glen", "simple mills", "lakanto", "annie's", "applegate", "fage", "siggi's"]
        let hasBrand = brandIndicators.contains { lowercased.contains($0) }
        let hasOrSeparator = lowercased.contains(" or ") && lowercased.contains(":")
        return hasBrand || hasOrSeparator
    }
    
    // MARK: - Helper Functions for Tracker-Style Dropdowns
    
    // Parse nutrition value string to Double
    private func parseNutritionValueDouble(_ value: String?) -> Double? {
        guard let value = value, !value.isEmpty else { return nil }
        
        var cleaned = value.replacingOccurrences(of: "µg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mcg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "IU", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "N/A", with: "0")
            .replacingOccurrences(of: "nil", with: "0")
        
        return Double(cleaned)
    }
    
    // Get micronutrient value from NutritionInfo
    private func getMicronutrientValue(_ nutrition: NutritionInfo, name: String) -> Double? {
        switch name {
        case "Vitamin D": return parseNutritionValueDouble(nutrition.vitaminD)
        case "Vitamin E": return parseNutritionValueDouble(nutrition.vitaminE)
        case "Potassium": return parseNutritionValueDouble(nutrition.potassium)
        case "Vitamin K": return parseNutritionValueDouble(nutrition.vitaminK)
        case "Magnesium": return parseNutritionValueDouble(nutrition.magnesium)
        case "Vitamin A": return parseNutritionValueDouble(nutrition.vitaminA)
        case "Calcium": return parseNutritionValueDouble(nutrition.calcium)
        case "Vitamin C": return parseNutritionValueDouble(nutrition.vitaminC)
        case "Choline": return parseNutritionValueDouble(nutrition.choline)
        case "Iron": return parseNutritionValueDouble(nutrition.iron)
        case "Zinc": return parseNutritionValueDouble(nutrition.zinc)
        case "Folate (B9)": return parseNutritionValueDouble(nutrition.folate)
        case "Vitamin B12": return parseNutritionValueDouble(nutrition.vitaminB12)
        case "Vitamin B6": return parseNutritionValueDouble(nutrition.vitaminB6)
        case "Selenium": return parseNutritionValueDouble(nutrition.selenium)
        case "Copper": return parseNutritionValueDouble(nutrition.copper)
        case "Manganese": return parseNutritionValueDouble(nutrition.manganese)
        case "Thiamin (B1)": return parseNutritionValueDouble(nutrition.thiamin)
        default: return nil
        }
    }
    
    // Macro Progress Bar
    private func macroProgressBar(macroName: String, currentValue: Double, gradient: LinearGradient, targetValue: Double? = nil, unit: String = "g") -> some View {
        let targetValue = targetValue ?? getMacroTargetValue(for: macroName)
        
        return VStack(spacing: 12) {
            // Name and Current/Target value row (ABOVE bar)
            HStack(spacing: 8) {
                // Macro name - tappable in Custom mode (except Kcal)
                if macroName == "Kcal" {
                    // Kcal is not editable, always show as plain text
                    Text(macroName)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                } else if macroTargetMode == .custom {
                    Button(action: {
                        selectedMacroForTarget = macroName
                    }) {
                        Text(macroName)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .underline()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                } else {
                    Text(macroName)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
                
                Spacer()
                
                // Current/Target value format "XXX/500g" or "XXX/2000Kcal" (right)
                let exceedsTarget = currentValue > targetValue
                if macroName == "Kcal" {
                    Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(exceedsTarget ? .red : (colorScheme == .dark ? .white : .primary))
                } else if macroTargetMode == .standardRDA {
                    Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(unit) (RDA)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(exceedsTarget ? .red : .secondary)
                } else {
                    Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(exceedsTarget ? .red : (colorScheme == .dark ? .white : .primary))
                }
            }
            
            // Progress Bar row (full width, no icon)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar with gradient (lighter opacity)
                    let backgroundOpacity = colorScheme == .dark ? 0.2 : 0.4
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gradient.opacity(backgroundOpacity))
                        .frame(height: 10)
                    
                    // Filled portion with full gradient
                    let progress = min(currentValue / targetValue, 1.0)
                    let fillWidth = geometry.size.width * CGFloat(progress)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gradient)
                        .frame(width: fillWidth, height: 10)
                }
                .frame(height: 10)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
    
    // Micronutrient Row
    private func micronutrientRow(name: String, value: Double) -> some View {
        let targetValue = getTargetValue(for: name)
        let metadata = micronutrientMetadata(for: name)
        
        return VStack(spacing: 12) {
            // Name and Current/Target value row (ABOVE bar)
            HStack(spacing: 8) {
                // Micronutrient name - tappable in Custom mode
                if micronutrientTargetMode == .custom {
                    Button(action: {
                        selectedMicronutrientForTarget = name
                    }) {
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .underline()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                } else {
                    // In RDA mode, show name but not tappable
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
                
                Spacer()
                
                // Current/Target value format "XXX/500mg" (right)
                let exceedsTarget = value > targetValue
                if micronutrientTargetMode == .standardRDA {
                    Text("\(Int(round(value)))/\(Int(round(targetValue)))\(metadata.unit) (RDA)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(exceedsTarget ? .red : .secondary)
                } else {
                    Text("\(Int(round(value)))/\(Int(round(targetValue)))\(metadata.unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(exceedsTarget ? .red : (colorScheme == .dark ? .white : .primary))
                }
            }
            
            // Progress Bar row (full width, no icon)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar with icon gradient (lighter opacity)
                    let backgroundOpacity = colorScheme == .dark ? 0.2 : 0.4
                    RoundedRectangle(cornerRadius: 4)
                        .fill(metadata.gradient.opacity(backgroundOpacity))
                        .frame(height: 10)
                    
                    // Filled portion with full gradient from icon
                    let progress = min(value / targetValue, 1.0)
                    let fillWidth = geometry.size.width * CGFloat(progress)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(metadata.gradient)
                        .frame(width: fillWidth, height: 10)
                }
                .frame(height: 10)
            }
            
            // Benefit description under progress bar
            Text(getMicronutrientBenefits(for: name))
                .font(.caption)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
    
    // MARK: - Micronutrient Benefits Helper
    private func getMicronutrientBenefits(for name: String) -> String {
        switch name {
        case "Vitamin D":
            return "For bones, immunity, mood"
        case "Vitamin E":
            return "For skin, antioxidant, circulation"
        case "Potassium":
            return "For heart, blood pressure, muscles"
        case "Vitamin K":
            return "For blood clotting, bones, heart"
        case "Magnesium":
            return "For muscles, sleep, energy"
        case "Vitamin A":
            return "For vision, skin, immunity"
        case "Calcium":
            return "For bones, teeth, muscles"
        case "Vitamin C":
            return "For immunity, skin, antioxidant"
        case "Choline":
            return "For brain, memory, liver"
        case "Iron":
            return "For energy, blood, oxygen"
        case "Zinc":
            return "For immunity, healing, growth"
        case "Folate (B9)":
            return "For DNA, red blood cells, pregnancy"
        case "Vitamin B12":
            return "For energy, nerves, red blood cells"
        case "Vitamin B6":
            return "For metabolism, brain, mood"
        case "Selenium":
            return "For antioxidant, thyroid, immunity"
        case "Copper":
            return "For energy, bones, immunity"
        case "Manganese":
            return "For bones, metabolism, antioxidant"
        case "Thiamin (B1)":
            return "For energy, nerves, heart"
        default:
            return ""
        }
    }
    
    // Micronutrient Metadata (icons, gradients, units)
    private func micronutrientMetadata(for name: String) -> (icon: String, gradient: LinearGradient, unit: String) {
        switch name {
        case "Vitamin D":
            return ("sun.max.fill", LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing), "IU")
        case "Vitamin E":
            return ("leaf.fill", LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Potassium":
            return ("bolt.fill", LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Vitamin K":
            return ("drop.fill", LinearGradient(colors: [Color.red, Color.pink], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Magnesium":
            return ("waveform.path", LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Vitamin A":
            return ("eye.fill", LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Calcium":
            return ("figure.stand", LinearGradient(colors: [Color.gray, Color(red: 0.7, green: 0.7, blue: 0.7)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Vitamin C":
            return ("heart.fill", LinearGradient(colors: [Color.red, Color.pink], startPoint: .leading, endPoint: .trailing), "mg")
        case "Choline":
            return ("brain.head.profile", LinearGradient(colors: [Color.blue, Color(red: 0.0, green: 0.478, blue: 1.0)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Iron":
            return ("drop.fill", LinearGradient(colors: [Color.red, Color(red: 0.8, green: 0.2, blue: 0.2)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Zinc":
            return ("shield.fill", LinearGradient(colors: [Color(red: 0.42, green: 0.557, blue: 0.498), Color(red: 0.3, green: 0.7, blue: 0.6)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Folate (B9)":
            return ("heart.circle.fill", LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Vitamin B12":
            return ("bolt.fill", LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Vitamin B6":
            return ("brain.head.profile", LinearGradient(colors: [Color.blue, Color(red: 0.0, green: 0.478, blue: 1.0)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Selenium":
            return ("shield.checkered", LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Copper":
            return ("circle.hexagongrid.fill", LinearGradient(colors: [Color(red: 0.8, green: 0.4, blue: 0.0), Color(red: 0.9, green: 0.6, blue: 0.2)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Manganese":
            return ("sparkles", LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Thiamin (B1)":
            return ("bolt.heart.fill", LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color.red], startPoint: .leading, endPoint: .trailing), "mg")
        default:
            return ("pills.fill", LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing), "")
        }
    }
    
    // Load Macro Targets
    private func loadMacroTargets() {
        if let data = UserDefaults.standard.data(forKey: "macroTargets"),
           let targets = try? JSONDecoder().decode([String: Double].self, from: data) {
            macroTargets = targets
        }
    }
    
    private func saveMacroDisclaimerAcceptance() {
        UserDefaults.standard.set(true, forKey: "macroCustomDisclaimerAccepted")
        macroCustomDisclaimerAccepted = true
    }
    
    // Load Micronutrient Targets
    private func loadMicronutrientTargets() {
        if let data = UserDefaults.standard.data(forKey: "micronutrientTargets"),
           let targets = try? JSONDecoder().decode([String: Double].self, from: data) {
            micronutrientTargets = targets
        }
    }
    
    private func saveMicroDisclaimerAcceptance() {
        UserDefaults.standard.set(true, forKey: "microCustomDisclaimerAccepted")
        microCustomDisclaimerAccepted = true
    }
    
    // Save Macro Target
    private func saveMacroTarget(_ name: String, target: Double) {
        macroTargets[name] = target
        if let data = try? JSONEncoder().encode(macroTargets) {
            UserDefaults.standard.set(data, forKey: "macroTargets")
        }
    }
    
    // Save Micronutrient Target
    private func saveMicronutrientTarget(_ name: String, target: Double) {
        micronutrientTargets[name] = target
        if let data = try? JSONEncoder().encode(micronutrientTargets) {
            UserDefaults.standard.set(data, forKey: "micronutrientTargets")
        }
    }
    
    // Get Macro Current Value
    private func getMacroCurrentValue(nutrition: NutritionInfo, macroName: String) -> Double {
        switch macroName {
        case "Kcal":
            return parseNutritionValueDouble(nutrition.calories) ?? 0.0
        case "Protein":
            return parseNutritionValueDouble(nutrition.protein) ?? 0.0
        case "Carbs":
            return parseNutritionValueDouble(nutrition.carbohydrates) ?? 0.0
        case "Fat":
            return parseNutritionValueDouble(nutrition.fat) ?? 0.0
        case "Fiber":
            return parseNutritionValueDouble(nutrition.fiber) ?? 0.0
        case "Sugar":
            return parseNutritionValueDouble(nutrition.sugar) ?? 0.0
        case "Sodium":
            return parseNutritionValueDouble(nutrition.sodium) ?? 0.0
        default:
            return 0.0
        }
    }
    
    // Get Macro RDA Value
    private func getMacroRDAValue(for macro: String) -> Double {
        let rdaValues: [String: Double] = [
            "Protein": 50.0,
            "Carbs": 250.0,
            "Fat": 65.0,
            "Fiber": 30.0,
            "Sugar": 50.0
        ]
        return rdaValues[macro] ?? 0.0
    }
    
    // Get Macro Target Value (RDA or Custom)
    private func getMacroTargetValue(for macro: String) -> Double {
        if macroTargetMode == .standardRDA {
            return getMacroRDAValue(for: macro)
        } else {
            return macroTargets[macro] ?? getMacroRDAValue(for: macro)
        }
    }
    
    // Get Daily Calorie Target
    private func getDailyCalorieTarget() -> Double {
        if let stored = UserDefaults.standard.object(forKey: "dailyCalorieTarget") as? Double, stored > 0 {
            return stored
        }
        return 2000.0
    }
    
    // Get RDA Value
    private func getRDAValue(for micronutrient: String) -> Double {
        let ageRange = healthProfileManager.currentProfile?.ageRange
        let sex = healthProfileManager.currentProfile?.sex
        return RDALookupService.shared.getRDA(for: micronutrient, ageRange: ageRange, sex: sex) ?? 0.0
    }
    
    // Get Target Value (RDA or Custom)
    private func getTargetValue(for micronutrient: String) -> Double {
        if micronutrientTargetMode == .standardRDA {
            return getRDAValue(for: micronutrient)
        } else {
            return micronutrientTargets[micronutrient] ?? getRDAValue(for: micronutrient)
        }
    }
    
    // MARK: - Similar Supplements Section
    private var similarSupplementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💊 Similar Supplements with Higher Scores")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let suggestions = supplementSuggestions, !suggestions.isEmpty {
                VStack(spacing: 12) {
                    ForEach(suggestions.indices, id: \.self) { index in
                        supplementSuggestionCard(suggestions[index])
                    }
                }
            } else if isLoadingSupplementSuggestions {
                VStack(spacing: 12) {
                    Text("Finding similar supplements...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                    
                    ProgressView()
                        .scaleEffect(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            if supplementSuggestions == nil && !isLoadingSupplementSuggestions {
                loadSimilarSupplements()
            }
        }
    }
    
    // MARK: - Supplement Suggestion Card
    private func supplementSuggestionCard(_ suggestion: GrocerySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with brand, product, and score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.brandName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(suggestion.productName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Score badge
                VStack(spacing: 2) {
                    Text("\(suggestion.score)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Score")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(width: 60, height: 60)
                .background(scoreColor(suggestion.score))
                .cornerRadius(30)
            }
            
            // Reason for higher score
            Text(suggestion.reason)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // Key benefits
            if !suggestion.keyBenefits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Benefits:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(suggestion.keyBenefits, id: \.self) { benefit in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            
                            Text(benefit)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            // Price and availability
            HStack {
                Text(suggestion.priceRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(suggestion.availability)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Load Similar Supplements
    private func loadSimilarSupplements() {
        isLoadingSupplementSuggestions = true
        AIService.shared.findSimilarSupplements(
            currentSupplement: analysis.foodName,
            currentScore: analysis.overallScore
        ) { result in
            DispatchQueue.main.async {
                self.isLoadingSupplementSuggestions = false
                switch result {
                case .success(let suggestions):
                    self.supplementSuggestions = suggestions
                    print("Loaded \(suggestions.count) similar supplement suggestions")
                case .failure(let error):
                    print("Failed to load similar supplements: \(error)")
                    // Don't show error to user, just leave suggestions as nil
                }
            }
        }
    }
    
    // MARK: - Supplement Health Goals Grid (Always Visible)
    
    // Helper function to map profile goal names to health score categories for supplements
    // Returns mapping even if score is -1 (to ensure all selected goals render)
    private func mapProfileGoalToCategoryForSupplements(_ goal: String) -> (category: String, icon: String, label: String, score: Int)? {
        let normalized = normalizeHealthGoal(goal)
        
        switch normalized {
        case "heart health":
            return ("Heart", "❤️", "Heart\nHealth", currentAnalysis.healthScores.heartHealth)
        case "brain health":
            return ("Brain", "🧠", "Brain\nHealth", currentAnalysis.healthScores.brainHealth)
        case "weight management":
            return ("Weight", "⚖️", "Weight", currentAnalysis.healthScores.weightManagement)
        case "immune support":
            return ("Immune", "🛡️", "Immune", currentAnalysis.healthScores.immune)
        case "blood sugar", "blood_sugar":
            return ("Blood Sugar", "🩸", "Blood Sugar", currentAnalysis.healthScores.bloodSugar)
        case "energy":
            return ("Energy", "⚡", "Energy", currentAnalysis.healthScores.energy)
        case "sleep quality", "sleep":
            return ("Sleep", "😴", "Sleep", currentAnalysis.healthScores.sleep)
        case "stress management", "stress":
            return ("Stress", "🧘", "Stress", currentAnalysis.healthScores.stress)
        case "skin health", "skin":
            return ("Skin", "✨", "Skin", currentAnalysis.healthScores.skin)
        case "joint health", "joints":
            return ("Joints", "🦴", "Joint\nHealth", currentAnalysis.healthScores.jointHealth)
        case "bone/muscle health", "bone muscle health", "bones muscle health":
            return ("Joints", "🦴", "Bones &\nJoints", currentAnalysis.healthScores.jointHealth)
        case "digestive health", "digestive":
            return ("Detox/Liver", "🧪", "Detox/\nLiver", currentAnalysis.healthScores.detoxLiver)
        case "hormonal balance", "hormonal":
            return ("Mood", "😊", "Mood", currentAnalysis.healthScores.mood)
        default:
            // Try partial matching for Blood Sugar
            if normalized.contains("blood") && normalized.contains("sugar") {
                return ("Blood Sugar", "🩸", "Blood Sugar", currentAnalysis.healthScores.bloodSugar)
            }
            return nil
        }
    }
    
    @ViewBuilder
    var supplementHealthGoalsGrid: some View {
        let userHealthGoals = healthProfileManager.getHealthGoals()
        
        // Map user-selected goals to categories (always returns mapping, even if score is -1)
        let filteredGoals = userHealthGoals.compactMap { mapProfileGoalToCategoryForSupplements($0) }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("🔬 Research For Your Health Goals")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            
            if filteredGoals.isEmpty {
                // If no user goals selected, show message
                Text("Select health goals in your profile to see personalized research.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // 3-column grid matching Supplements style - use user-selected goals
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(filteredGoals, id: \.category) { goal in
                        TappableHealthScoreBox(
                            icon: goal.icon,
                            label: goal.label,
                            score: goal.score,
                            category: goal.category,
                            analysis: currentAnalysis,
                            isExpanded: expandedHealthGoal?.category == goal.category,
                            onTap: { category, score in
                                if expandedHealthGoal?.category == category {
                                    expandedHealthGoal = nil
                                    healthGoalResearch = nil
                                } else {
                                    expandedHealthGoal = (category, score)
                                    // Use cached research if available, otherwise load
                                    if let cached = loadedHealthGoalResearch[category] {
                                        healthGoalResearch = cached
                                    } else {
                                        loadHealthGoalResearch(for: category, score: score)
                                    }
                                }
                            }
                        )
                    }
                }
            }
            
            // Show research panel if expanded
            if let expanded = expandedHealthGoal, let research = healthGoalResearch {
                HealthGoalResearchPanel(
                    category: expanded.category,
                    score: expanded.score,
                    summary: research.summary,
                    researchEvidence: research.researchEvidence,
                    sources: research.sources,
                    isVerified: research.isVerified,
                    citations: research.citations
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let expanded = expandedHealthGoal, isLoadingHealthGoalResearch {
                VStack {
                    ProgressView()
                    Text("Loading research...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private struct HealthScoreBox: View {
        let icon: String
        let label: String
        let score: Int
        
        var body: some View {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                Text("\(score)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        }
    }
    
    // Tappable version for supplements (reusable component)
    private struct TappableHealthScoreBox: View {
        let icon: String
        let label: String
        let score: Int
        let category: String
        let analysis: FoodAnalysis
        let isExpanded: Bool
        let onTap: (String, Int) -> Void
        
        var body: some View {
            Button(action: {
                onTap(category, score)
            }) {
                VStack(spacing: 4) {
                    Text(icon)
                        .font(.title2)
                    Text(label)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                    if score == -1 {
                        Text("—")
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        Text("\(score)")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isExpanded ? Color.blue.opacity(0.2) : Color(.systemGray5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isExpanded ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
            .disabled(score == -1)
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // Health Goal Research Panel
    private struct HealthGoalResearchPanel: View {
        let category: String
        let score: Int
        let summary: String
        let researchEvidence: [String]
        let sources: [String]
        let isVerified: Bool  // Flag to indicate if research is verified
        let citations: [ResearchCitation]?  // Full citation data for clickable links
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header with icon and score
                HStack {
                    Text(iconForCategory(category))
                        .font(.title2)
                    Text("\(category) — \(score)/100")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                // Summary
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                // Research Evidence - Only display if verified
                if isVerified {
                    // Research Sources Section (clickable citations)
                    if let citations = citations, !citations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Research Sources")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                        ForEach(citations) { citation in
                            HealthGoalCitationRowView(citation: citation)
                        }
                        }
                    } else if !researchEvidence.isEmpty {
                        // Fallback to text display if citations not available
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Research Evidence:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            ForEach(researchEvidence, id: \.self) { evidence in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(evidence)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                } else {
                    // Legacy research suppressed
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No verified human research available.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .onAppear {
                                if !researchEvidence.isEmpty {
                                    print("Legacy research evidence suppressed — verification required")
                                }
                            }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        
        // Citation Row View for clickable citations (within HealthGoalResearchPanel)
        private struct HealthGoalCitationRowView: View {
            let citation: ResearchCitation
            
            var body: some View {
                VStack(alignment: .leading, spacing: 6) {
                    // Tier 1: Clickable (DOI/PMID links)
                    // Tier 2: Non-clickable by default (App Store compliance)
                    if citation.citationTier == .verifiedPrimary, let urlString = citation.displayURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Tier 1: Journal • Year only (UNCHANGED)
                                HStack {
                                    Text(citation.displayJournal)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("\(citation.displayYear)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                
                                // Tier label
                                Text("Primary research (peer-reviewed)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            .padding(.vertical, 2)
                        }
                    } else {
                        // Non-clickable display (Tier 2 or Tier 1 without URL)
                        VStack(alignment: .leading, spacing: 4) {
                            if citation.citationTier == .verifiedPrimary {
                                // Tier 1: Journal • Year only
                                HStack {
                                    Text(citation.displayJournal)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Text("\(citation.displayYear)")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                Text("Primary research (peer-reviewed)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else if citation.citationTier == .authoritativeReview {
                                // Tier 2: Journal • Year only (non-clickable, educational)
                                HStack {
                                    Text(citation.displayJournal)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Text("\(citation.displayYear)")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                                Text("Authoritative review (educational)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                // Other tiers - fallback display
                                Text("\(citation.ingredient)'s \(citation.nutrient) — \(citation.outcome)")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Text("\(citation.displayJournal) (\(citation.displayYear))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                if let tier = citation.citationTier {
                                    Text(tier.displayLabel)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
        }
        
        func iconForCategory(_ category: String) -> String {
            switch category.lowercased() {
            case "heart": return "❤️"
            case "brain": return "🧠"
            case "energy": return "💪"
            case "sleep": return "😴"
            case "immune": return "🛡️"
            case "joints": return "🦴"
            default: return "🔬"
            }
        }
    }
    
    // MARK: - Supplement Dropdowns (Load on Tap)
    
    @ViewBuilder
    var supplementDropdowns: some View {
        VStack(spacing: 16) {
            // Key Benefits
            StyledSupplementDropdown(
                title: "Key Benefits",
                icon: "star.fill",
                borderColor: Color.yellow,
                gradientColors: [Color.yellow, Color.orange],
                isExpanded: $isSupplementKeyBenefitsExpanded,
                isLoading: isLoadingSecondary,
                content: {
                    if let benefits = currentAnalysis.keyBenefits, !benefits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(benefit)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                    } else if !isLoadingSecondary {
                        Text("Tap to load...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            )
            .onChange(of: isSupplementKeyBenefitsExpanded) { expanded in
                if expanded { loadSecondaryIfNeeded() }
            }
            
            // Ingredients Analysis
            StyledSupplementDropdown(
                title: "Ingredients Analysis",
                icon: "flask.fill",
                borderColor: Color.blue,
                gradientColors: [Color.blue, Color.cyan],
                isExpanded: $isSupplementIngredientsExpanded,
                isLoading: isLoadingSecondary,
                content: {
                    if let ingredientAnalyses = currentAnalysis.ingredientAnalyses, !ingredientAnalyses.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(ingredientAnalyses) { ingredient in
                                SupplementIngredientRow(ingredient: ingredient)
                            }
                        }
                        .padding()
                    } else if let ingredients = currentAnalysis.ingredients, !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                                HStack {
                                    Image(systemName: "checkmark.square.fill")
                                        .foregroundColor(.green)
                                    Text(ingredient.name)
                                }
                                .font(.subheadline)
                            }
                            
                            Button(action: { loadSecondaryIfNeeded() }) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Load research ratings")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                    } else if !isLoadingSecondary {
                        Text("Tap to load...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            )
            .onChange(of: isSupplementIngredientsExpanded) { expanded in
                if expanded { loadSecondaryIfNeeded() }
            }
            
            // Drug Interactions
            StyledSupplementDropdown(
                title: "Drug Interactions",
                icon: "pills.fill",
                borderColor: Color.purple,
                gradientColors: [Color.purple, Color.pink],
                isExpanded: $isDrugInteractionsExpanded,
                isLoading: isLoadingSecondary,
                content: {
                    if let interactions = currentAnalysis.drugInteractions, !interactions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(interactions) { interaction in
                                DrugInteractionRow(interaction: interaction)
                            }
                            
                            Text("List is for information only and may not be complete. Always ask your doctor before taking any supplement regularly.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding()
                    } else if secondaryLoaded {
                        Text("No known drug interactions identified.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else if !isLoadingSecondary {
                        Text("Tap to load...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            )
            .onChange(of: isDrugInteractionsExpanded) { expanded in
                if expanded { loadSecondaryIfNeeded() }
            }
            
            // Dosage Analysis
            StyledSupplementDropdown(
                title: "Dosage Analysis",
                icon: "chart.bar.fill",
                borderColor: Color.orange,
                gradientColors: [Color.orange, Color.yellow],
                isExpanded: $isDosageExpanded,
                isLoading: isLoadingSecondary,
                content: {
                    if let details = currentAnalysis.secondaryDetails, !details.dosageAnalyses.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(details.dosageAnalyses) { dosage in
                                DosageAnalysisRow(dosage: dosage)
                            }
                        }
                        .padding()
                    } else if secondaryLoaded {
                        Text("No dosage analysis available.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else if !isLoadingSecondary {
                        Text("Tap to load...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            )
            .onChange(of: isDosageExpanded) { expanded in
                if expanded { loadSecondaryIfNeeded() }
            }
            
            // Safety & Warnings
            StyledSupplementDropdown(
                title: "Safety & Warnings",
                icon: "exclamationmark.triangle.fill",
                borderColor: Color.red,
                gradientColors: [Color.red, Color.orange],
                isExpanded: $isSafetyExpanded,
                isLoading: isLoadingSecondary,
                content: {
                    if let details = currentAnalysis.secondaryDetails, !details.safetyWarnings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(details.safetyWarnings) { warning in
                                SafetyWarningRow(warning: warning)
                            }
                            
                            Text("This is not medical advice. Consult your healthcare provider before starting any supplement.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding()
                    } else if secondaryLoaded {
                        Text("No specific warnings identified.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else if !isLoadingSecondary {
                        Text("Tap to load...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            )
            .onChange(of: isSafetyExpanded) { expanded in
                if expanded { loadSecondaryIfNeeded() }
            }
            
            // Quality Indicators
            StyledSupplementDropdown(
                title: "Quality Indicators",
                icon: "checkmark.seal.fill",
                borderColor: Color.green,
                gradientColors: [Color.green, Color.mint],
                isExpanded: $isQualityExpanded,
                isLoading: isLoadingSecondary,
                content: {
                    if let details = currentAnalysis.secondaryDetails, !details.qualityIndicators.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(details.qualityIndicators) { indicator in
                                QualityIndicatorRow(indicator: indicator)
                            }
                        }
                        .padding()
                    } else if secondaryLoaded {
                        Text("No quality indicators identified.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else if !isLoadingSecondary {
                        Text("Tap to load...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            )
            .onChange(of: isQualityExpanded) { expanded in
                if expanded { loadSecondaryIfNeeded() }
            }
            
            // Higher Scoring Choices (always visible, not a dropdown)
            higherScoringSection
        }
    }
    
    // MARK: - Higher Scoring Choices Section (Always Visible)
    
    @ViewBuilder
    var higherScoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Higher Scoring Choices")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 4)
            
            // Display cached suggestions (not in dropdown)
            if let suggestions = currentAnalysis.suggestions, !suggestions.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                        SupplementSuggestionCard(suggestion: suggestion)
                    }
                }
            } else {
                Text("No higher scoring alternatives found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Supplement Suggestion Card
    
    private struct SupplementSuggestionCard: View {
        let suggestion: GrocerySuggestion
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Brand and score
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.brandName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(suggestion.productName)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    // Score circle
                    ZStack {
                        Circle()
                            .fill(scoreGradient(suggestion.score))
                            .frame(width: 50, height: 50)
                        VStack(spacing: 0) {
                            Text("\(suggestion.score)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Score")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                
                // Summary (with more lines)
                Text(suggestion.reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Key benefits
                if !suggestion.keyBenefits.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Key Benefits:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        ForEach(suggestion.keyBenefits, id: \.self) { benefit in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(benefit)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                
                // Price and availability
                HStack {
                    if !suggestion.priceRange.isEmpty {
                        Text(suggestion.priceRange)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !suggestion.availability.isEmpty {
                        Text(suggestion.availability)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        
        private func scoreGradient(_ score: Int) -> LinearGradient {
            let progress = CGFloat(score) / 100.0
            
            let startColor: Color
            let endColor: Color
            
            if progress <= 0.4 {
                // Red to Orange
                startColor = Color(red: 0.8, green: 0.1, blue: 0.1)
                endColor = Color(red: 0.9, green: 0.4, blue: 0.1)
            } else if progress <= 0.6 {
                // Orange to Yellow
                startColor = Color(red: 0.9, green: 0.4, blue: 0.1)
                endColor = Color(red: 0.95, green: 0.7, blue: 0.1)
            } else if progress <= 0.8 {
                // Yellow to Light Green
                startColor = Color(red: 0.95, green: 0.7, blue: 0.1)
                endColor = Color(red: 0.502, green: 0.706, blue: 0.627)
            } else {
                // Light Green to Dark Green
                startColor = Color(red: 0.502, green: 0.706, blue: 0.627)
                endColor = Color(red: 0.42, green: 0.557, blue: 0.498)
            }
            
            return LinearGradient(colors: [startColor, endColor], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    // Styled dropdown component matching recipe style
    private struct StyledSupplementDropdown<Content: View>: View {
        let title: String
        let icon: String
        let borderColor: Color
        let gradientColors: [Color]
        @Binding var isExpanded: Bool
        let isLoading: Bool
        @ViewBuilder let content: () -> Content
        @Environment(\.colorScheme) private var colorScheme
        
        var body: some View {
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                if isExpanded {
                    if isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else {
                        content()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
    
    // MARK: - Secondary API Loading
    
    private func loadSecondaryIfNeeded() {
        guard !secondaryLoaded && !isLoadingSecondary else { return }
        guard isSupplementScan else { return }
        
        isLoadingSecondary = true
        print("📦 SUPPLEMENT: Loading secondary details...")
        
        Task {
            do {
                let details = try await fetchSecondaryDetails(for: currentAnalysis)
                
                await MainActor.run {
                    // Update currentAnalysis with secondary data
                    currentAnalysis = FoodAnalysis(
                        foodName: currentAnalysis.foodName,
                        overallScore: currentAnalysis.overallScore,
                        summary: currentAnalysis.summary,
                        healthScores: currentAnalysis.healthScores,
                        keyBenefits: details.keyBenefits.isEmpty ? currentAnalysis.keyBenefits : details.keyBenefits,
                        ingredients: currentAnalysis.ingredients,
                        bestPreparation: currentAnalysis.bestPreparation,
                        servingSize: currentAnalysis.servingSize,
                        nutritionInfo: currentAnalysis.nutritionInfo,
                        scanType: currentAnalysis.scanType,
                        foodNames: currentAnalysis.foodNames,
                        foodPortions: currentAnalysis.foodPortions,
                        suggestions: currentAnalysis.suggestions,
                        dataCompleteness: currentAnalysis.dataCompleteness,
                        analysisTimestamp: currentAnalysis.analysisTimestamp,
                        dataSource: currentAnalysis.dataSource,
                        ingredientAnalyses: details.ingredientAnalyses.isEmpty ? currentAnalysis.ingredientAnalyses : details.ingredientAnalyses,
                        drugInteractions: details.drugInteractions.isEmpty ? currentAnalysis.drugInteractions : details.drugInteractions,
                        overallResearchScore: currentAnalysis.overallResearchScore,
                        secondaryDetails: SupplementSecondaryDetails(
                            dosageAnalyses: details.dosageAnalyses,
                            safetyWarnings: details.safetyWarnings,
                            qualityIndicators: details.qualityIndicators
                        ),
                        healthGoalsEvaluation: currentAnalysis.healthGoalsEvaluation
                    )
                    
                    secondaryLoaded = true
                    isLoadingSecondary = false
                    
                    print("📦 SUPPLEMENT: Secondary details loaded")
                    print("📦 SUPPLEMENT: - Key benefits: \(details.keyBenefits.count)")
                    print("📦 SUPPLEMENT: - Ingredients with scores: \(details.ingredientAnalyses.count)")
                    print("📦 SUPPLEMENT: - Drug interactions: \(details.drugInteractions.count)")
                    print("📦 SUPPLEMENT: - Dosage analyses: \(details.dosageAnalyses.count)")
                    print("📦 SUPPLEMENT: - Safety warnings: \(details.safetyWarnings.count)")
                    print("📦 SUPPLEMENT: - Quality indicators: \(details.qualityIndicators.count)")
                }
            } catch {
                print("📦 SUPPLEMENT: Secondary load failed: \(error)")
                await MainActor.run {
                    isLoadingSecondary = false
                }
            }
        }
    }
    
    private func fetchSecondaryDetails(for analysis: FoodAnalysis) async throws -> SecondaryDetailsResponse {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Build ingredients list for context
        let ingredientsList = analysis.ingredients?.map { $0.name }.joined(separator: ", ") ?? ""
        
        let prompt = """
        Analyze this supplement and provide detailed information.
        
        Supplement: \(analysis.foodName)
        Ingredients: \(ingredientsList)
        
        Return ONLY valid JSON with this structure:
        {
            "keyBenefits": ["benefit1", "benefit2", "benefit3", "benefit4"],
            "ingredientAnalyses": [
                {
                    "name": "Full ingredient name with brand",
                    "amount": "100mg",
                    "form": "specific form if applicable",
                    "researchScore": 1-100,
                    "briefSummary": "One sentence about function and research support"
                }
            ],
            "drugInteractions": [
                {
                    "drugCategory": "Drug category name",
                    "interaction": "Description of interaction",
                    "severity": "moderate or serious"
                }
            ],
            "dosageAnalyses": [
                {
                    "ingredient": "Ingredient name",
                    "labelDose": "100mg",
                    "clinicalRange": "100-200mg",
                    "verdict": "optimal, low, or high"
                }
            ],
            "safetyWarnings": [
                {
                    "warning": "Warning text",
                    "category": "pregnancy, nursing, surgery, sideEffect, allergy"
                }
            ],
            "qualityIndicators": [
                {
                    "indicator": "Indicator name",
                    "status": "positive, negative, or neutral",
                    "detail": "Additional detail"
                }
            ]
        }
        
        RESEARCH SCORE CRITERIA (1-100):
        - 90-100 (Gold Standard): Large RCT OR meta-analysis OR 10+ quality studies + long history
        - 75-89 (Strong Evidence): Multiple quality studies OR one excellent RCT OR centuries of traditional use
        - 60-74 (Good Evidence): Several small studies + plausible mechanism
        - 40-59 (Emerging Evidence): 1-2 small studies OR strong animal data
        - 20-39 (Limited Evidence): Animal/cell studies only
        - 1-19 (Insufficient Evidence): Minimal research
        
        Quality factors that INCREASE score:
        - Gold-standard RCT, meta-analysis, long safe use history, well-understood mechanism
        
        Quality factors that DECREASE score:
        - Only animal studies, conflicting results, small samples, industry-funded only
        
        DRUG INTERACTIONS: Only include clinically relevant interactions.
        DOSAGE: Compare to ranges used in clinical research.
        SAFETY: Include pregnancy, nursing, surgery, common side effects.
        QUALITY: Note certifications, branded ingredients, allergens, third-party testing.
        """
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 2000,
            "temperature": 0.1,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw NSError(domain: "Invalid response", code: 0)
        }
        
        let details = try JSONDecoder().decode(SecondaryDetailsResponse.self, from: contentData)
        return details
    }
    
    // MARK: - Health Goal Research Loading
    
    private func loadHealthGoalResearch(for category: String, score: Int, storeInCache: Bool = false) {
        // Skip if already loading or loaded
        if loadingHealthGoalResearch.contains(category) || loadedHealthGoalResearch[category] != nil {
            return
        }
        
        // Mark as loading
        if !storeInCache {
            isLoadingHealthGoalResearch = true
        }
        loadingHealthGoalResearch.insert(category)
        
        Task {
            do {
                let ingredientsList = currentAnalysis.ingredients?.map { $0.name }.joined(separator: ", ") ?? ""
                let categorySpecificPrompt = getCategorySpecificPrompt(category: category, foodName: currentAnalysis.foodName)
                
                let prompt = """
                Analyze this supplement for \(category.lowercased()) health benefits.
                
                Supplement: \(currentAnalysis.foodName)
                Ingredients: \(ingredientsList)
                \(category) Score: \(score)/100
                
                \(categorySpecificPrompt)
                
                Generate research-based analysis:
                
                SUMMARY (40-60 words):
                - Start with the score: "Scoring \(score)/100 for \(category.lowercased())..."
                - Name specific compounds and their effects
                - Use specific numbers (mg, %)
                - Never use "may," "could," "potentially"
                
                RESEARCH EVIDENCE (2-3 bullet points):
                - Each point links SPECIFIC INGREDIENT's SPECIFIC NUTRIENT to \(category.lowercased()) health
                - Only cite REAL peer-reviewed studies from PubMed-indexed journals
                - If no research exists for an ingredient, skip it
                - NEVER mention the supplement name "\(currentAnalysis.foodName)" in research evidence - only ingredient names
                - CRITICAL: Each citation MUST include DOI or PubMed PMID for verification
                - If you cannot provide DOI or PMID, EXCLUDE the study entirely
                - Do NOT guess identifiers - only include studies where you can provide accurate DOI or PMID
                
                Return ONLY this JSON:
                {
                    "summary": "40-60 word paragraph starting with score",
                    "researchEvidence": [
                        {
                            "ingredient": "Ingredient name",
                            "nutrient": "Specific nutrient",
                            "outcome": "Health outcome finding",
                            "authors": "First Author et al.",
                            "year": 2021,
                            "journal": "Journal Name",
                            "doi": "10.xxxx/xxxxx or null",
                            "pmid": "12345678 or null",
                            "title": "Study title or null",
                            "url": "https://doi.org/10.xxxx/xxxxx or https://pubmed.ncbi.nlm.nih.gov/12345678/ or null"
                        }
                    ]
                }
                
                REQUIREMENTS:
                - At least ONE of doi or pmid must be provided (not both null)
                - DOI format: 10.xxxx/xxxxx
                - PMID format: numeric, 6-8 digits
                - If no verified studies exist, return empty researchEvidence array []
                """
                
                let text = try await AIService.shared.makeOpenAIRequestAsync(prompt: prompt)
                
                // Process through ResearchEvidenceService for verification
                let verifiedCitations = await ResearchEvidenceService.shared.processAIResponse(text)
                
                await MainActor.run {
                    loadingHealthGoalResearch.remove(category)
                    if !storeInCache {
                        isLoadingHealthGoalResearch = false
                    }
                    
                    // Convert verified citations to legacy format
                    let researchInfo: HealthGoalResearchInfo
                    if !verifiedCitations.isEmpty {
                        let summary = extractSummary(from: text) ?? "Research supports the health benefits of this supplement for \(category.lowercased())."
                        researchInfo = HealthGoalResearchInfo(summary: summary, verifiedCitations: verifiedCitations)
                    } else {
                        // No verified citations - return empty structure
                        researchInfo = HealthGoalResearchInfo(summary: "No verified human research available for this supplement.", verifiedCitations: [])
                    }
                    
                    // Store in cache if requested
                    if storeInCache {
                        loadedHealthGoalResearch[category] = researchInfo
                    } else {
                        // For tap-based loading, update the expanded state
                        healthGoalResearch = researchInfo
                    }
                }
            } catch {
                print("❌ Error loading health goal research for \(category): \(error)")
                await MainActor.run {
                    loadingHealthGoalResearch.remove(category)
                    if !storeInCache {
                        isLoadingHealthGoalResearch = false
                        healthGoalResearch = nil
                    }
                }
            }
        }
    }
    
    // Lazy-load research for top health goals (called on screen appear)
    private func lazyLoadTopHealthGoals() {
        // Only load for supplements
        guard isSupplementScan else { return }
        
        // Get top 3 health goals by score (highest scores first)
        let healthGoals: [(category: String, score: Int)] = [
            ("Heart", currentAnalysis.healthScores.heartHealth),
            ("Brain", currentAnalysis.healthScores.brainHealth),
            ("Energy", currentAnalysis.healthScores.energy)
        ].sorted(by: { $0.1 > $1.1 })
        .prefix(3)
        .map { ($0.0, $0.1) }
        
        // Load research for top goals with small delays to avoid overwhelming the API
        for (index, goal) in healthGoals.enumerated() {
            if goal.1 > 0 { // Only load if score is valid
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                    self.loadHealthGoalResearch(for: goal.0, score: goal.1, storeInCache: true)
                }
            }
        }
    }
    
    private func extractJSONFromText(_ text: String) -> String {
        // Look for JSON object in the text
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            return String(text[jsonRange])
        }
        return text
    }
    
    /// Extracts summary from AI response JSON
    private func extractSummary(from text: String) -> String? {
        let jsonText = extractJSONFromText(text)
        guard let data = jsonText.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String else {
            return nil
        }
        return summary
    }
    
    // Helper function for health goal research prompts (similar to HealthDetailView)
    // CRITICAL: Use educational language only - no medical claims, no treatment/prevention language
    private func getCategorySpecificPrompt(category: String, foodName: String) -> String {
        switch category {
        case "Heart":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to heart health. Focus on:
            - Nutrients present that are researched for cardiovascular function
            - Dietary patterns associated with heart health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to heart function
            """
            
        case "Brain":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to brain health. Focus on:
            - Nutrients present that are researched for cognitive function
            - Dietary patterns associated with brain health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to brain function
            """
            
        case "Anti-Inflam":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to inflammation. Focus on:
            - Nutrients and compounds present in the food
            - Research associations with inflammatory markers
            - Dietary patterns researched for inflammation
            - Educational context about nutrient presence (do NOT describe mechanisms as outcomes)
            """
            
        case "Joints":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to joint health. Focus on:
            - Nutrients present that are researched for joint function
            - Dietary patterns associated with joint health
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to joint function
            """
            
        case "Eyes", "Vision":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to eye health. Focus on:
            - Nutrients present that are researched for vision function
            - Dietary patterns associated with eye health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to vision
            """
            
        case "Weight":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to weight management. Focus on:
            - Nutrients present that are researched for satiety and metabolism
            - Dietary patterns associated with weight management
            - Research context about nutrient presence (do NOT describe weight loss outcomes)
            - Educational information about nutrients linked to satiety
            """
            
        case "Blood Sugar":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to blood sugar. Focus on:
            - Nutrients present that are researched for glucose metabolism
            - Dietary patterns associated with blood sugar regulation
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to blood sugar function
            """
            
        case "Energy":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to energy. Focus on:
            - Nutrients present that are researched for energy metabolism
            - Dietary patterns associated with energy function
            - Research context about nutrient presence (do NOT describe mechanisms as outcomes)
            - Educational information about nutrients linked to energy
            """
            
        case "Immune":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to immune function. Focus on:
            - Nutrients present that are researched for immune health
            - Dietary patterns associated with immune function
            - Research context about nutrient presence (do NOT describe enhancement or treatment)
            - Educational information about nutrients linked to immune function
            """
            
        case "Sleep":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to sleep. Focus on:
            - Nutrients present that are researched for sleep function
            - Dietary patterns associated with sleep
            - Research context about nutrient presence (do NOT describe improvement or treatment)
            - Educational information about nutrients linked to sleep
            """
            
        case "Skin":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to skin health. Focus on:
            - Nutrients present that are researched for skin function
            - Dietary patterns associated with skin health
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to skin function
            """
            
        case "Stress":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to stress. Focus on:
            - Nutrients present that are researched for stress response
            - Dietary patterns associated with stress management
            - Research context about nutrient presence (do NOT describe treatment or management)
            - Educational information about nutrients linked to stress function
            """
            
        case "Kidneys":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to kidney health. Focus on:
            - Nutrients present that are researched for kidney function
            - Dietary patterns associated with kidney health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to kidney function
            """
            
        case "Detox/Liver":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to liver health. Focus on:
            - Nutrients present that are researched for liver function
            - Dietary patterns associated with liver health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to liver function
            """
            
        case "Mood":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to mood. Focus on:
            - Nutrients present that are researched for mood function
            - Dietary patterns associated with mood
            - Research context about nutrient presence (do NOT describe treatment or management)
            - Educational information about nutrients linked to mood
            """
            
        case "Allergies":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to allergies. Focus on:
            - Nutrients present that are researched for immune response
            - Dietary patterns associated with allergy response
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to immune function
            """
            
        default:
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to \(category.lowercased()). Focus on:
            - Nutrients present that are researched for \(category.lowercased()) function
            - Dietary patterns associated with \(category.lowercased())
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to \(category.lowercased())
            """
        }
    }
}

struct HealthDetailView: View {
    let category: String
    let score: Int
    let foodName: String
    let longevityScore: Int
    let isMealAnalysis: Bool
    let scanType: String?
    let ingredients: [FoodIngredient]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var healthInfo: HealthInfo?
    @State private var isLoading = true
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Score Display (show immediately, not waiting for healthInfo)
                    VStack(spacing: 10) {
                        Text(foodName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("\(category) Score \(score)/100")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(colorScheme == .dark ? Color.black : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    if isLoading {
                        ProgressView("Loading health information...")
                            .padding()
                    } else if let info = healthInfo {
                        healthInfoContent(info)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            Text("Unable to load health information")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                loadHealthInfo()
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                            .cornerRadius(8)
                        }
                        .padding()
                    }
                    
                    // Educational disclaimer - always shown
                    HealthGoalsDisclaimerView()
                }
                .padding()
            }
            .navigationTitle("\(category) Benefits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Oops! Try Again?", isPresented: $showErrorAlert) {
            Button("Yes") {
                loadHealthInfo()
            }
            Button("No") {
                dismiss()
            }
        } message: {
            Text("The analysis is taking longer than expected. Would you like to try again?")
        }
        .onAppear {
            loadHealthInfo()
        }
    }
    
    // Citation Row View for clickable citations
    private struct CitationRowView: View {
        let citation: ResearchCitation
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                // Use tier-aware displayURL (Tier 2 never links to DOI resolvers)
                if let urlString = citation.displayURL, let url = URL(string: urlString) {
                    Link(destination: url) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Tier 1: Display ONLY journal and year (registry-sourced)
                            // Tier 2: Display ONLY journal, year, and tier label (no ingredient/nutrient/outcome)
                            if citation.citationTier == .verifiedPrimary {
                                // Tier 1: Journal • Year only (UNCHANGED)
                                HStack {
                                    Text(citation.displayJournal)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    Text("•")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                    Text("\(citation.displayYear)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                
                                // Tier label
                                Text(citation.citationTier?.displayLabel ?? "Primary research (peer-reviewed)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else if citation.citationTier == .authoritativeReview {
                                // Tier 2: Journal • Year only (no ingredient/nutrient/outcome) - non-clickable
                                HStack {
                                    Text(citation.displayJournal)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text("•")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Text("\(citation.displayYear)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                
                                // Tier label
                                Text("Authoritative review (educational)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                // Other tiers - fallback display
                                Text("\(citation.ingredient)'s \(citation.nutrient) — \(citation.outcome)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .lineLimit(2)
                                
                                HStack {
                                    Text(citation.displayJournal)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(citation.displayYear)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let tier = citation.citationTier {
                                    Text(tier.displayLabel)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    // Non-clickable fallback (acceptable for Tier 2)
                    VStack(alignment: .leading, spacing: 4) {
                        if citation.citationTier == .verifiedPrimary {
                            // Tier 1: Journal • Year only
                            HStack {
                                Text(citation.displayJournal)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("\(citation.displayYear)")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            Text(citation.citationTier?.displayLabel ?? "Primary research (peer-reviewed)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        } else if citation.citationTier == .authoritativeReview {
                            // Tier 2: Journal • Year only (no ingredient/nutrient/outcome)
                            HStack {
                                Text(citation.displayJournal)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("•")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Text("\(citation.displayYear)")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                            Text("Authoritative review (educational)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            // Other tiers - fallback display
                            Text("\(citation.ingredient)'s \(citation.nutrient) — \(citation.outcome)")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("\(citation.displayJournal) (\(citation.displayYear))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let tier = citation.citationTier {
                                Text(tier.displayLabel)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func healthInfoContent(_ info: HealthInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Summary
            VStack(alignment: .leading, spacing: 10) {
                Text("Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(info.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Research Evidence - Only display if verified
            if info.isVerified {
                // Research Sources Section (clickable citations)
                if let citations = info.citations, !citations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Research Sources")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(citations) { citation in
                            CitationRowView(citation: citation)
                        }
                    }
                } else if !info.researchEvidence.isEmpty {
                    // Fallback to text display if citations not available
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Research Evidence")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(info.researchEvidence, id: \.self) { evidence in
                            Text("• \(evidence)")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // Legacy research suppressed
                VStack(alignment: .leading, spacing: 10) {
                    Text("No verified human research available.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .italic()
                        .onAppear {
                            if !info.researchEvidence.isEmpty {
                                print("Legacy research evidence suppressed — verification required")
                            }
                        }
                }
            }
        }
    }
    
    private func loadHealthInfo() {
        loadHealthInfoWithRetry(attempt: 1)
    }
    
    private func loadHealthInfoWithRetry(attempt: Int) {
        isLoading = true
        
        let categorySpecificPrompt = getCategorySpecificPrompt(category: category, foodName: foodName)
        
        // Check if this is a grocery product (not a recipe, food, or meal)
        let isGrocery = scanType == "product" || scanType == "nutrition_label"
        
        // Extract main ingredients for groceries
        var researchInstructions = ""
        if isGrocery && !ingredients.isEmpty {
            // Get main ingredients (prioritize by portion size - focus on first 5-7 ingredients)
            let mainIngredients = Array(ingredients.prefix(7))
            let ingredientNames = mainIngredients.map { $0.name }.joined(separator: ", ")
            
            researchInstructions = """
            
            CRITICAL FOR GROCERY PRODUCTS:
            - This is a packaged grocery product (brand name: \(foodName))
            - DO NOT search for peer-reviewed research on the brand name "\(foodName)" - brand names do not have research studies
            - INSTEAD, search for peer-reviewed research on the MAIN INGREDIENTS: \(ingredientNames)
            - Focus on ingredients with the largest portions first (listed first in the ingredient list)
            - Include both POSITIVE and NEGATIVE research findings (e.g., sugar's impact on blood sugar, whole grain benefits, etc.)
            - If no studies exist for the main ingredients, say: "No peer-reviewed studies available for the main ingredients in \(foodName)"
            """
        } else if !ingredients.isEmpty {
            // For recipes, foods, and meals - process ALL ingredients for ingredient-specific nutrient-health links
            let ingredientNames = ingredients.map { $0.name }.joined(separator: ", ")
            
            researchInstructions = """
            
            CRITICAL FOR RECIPES AND MEALS - INGREDIENT-SPECIFIC RESEARCH ONLY:
            
            RULE 1: NEVER mention the recipe/meal name "\(foodName)" in research evidence. Only reference individual ingredients.
            
            RULE 2: Process EACH ingredient separately. For each ingredient, search PubMed for: "[ingredient name] + [specific nutrient] + \(category.lowercased()) health"
            
            RULE 3: Only include research evidence if you find a REAL peer-reviewed study linking that ingredient's SPECIFIC NUTRIENT to \(category.lowercased()) health.
            
            RULE 4: Format each finding as: "[Ingredient]'s [nutrient] [specific health benefit/finding]. ([First Author] et al., [Year])"
            
            Examples of CORRECT format (educational language only):
            - "Tomatoes' lycopene is associated with cardiovascular health in research. (Ried & Fakler, 2011)"
            - "Spinach's lutein is commonly studied in relation to vision function. (Ma et al., 2012)"
            - "Olive oil's monounsaturated fats are part of dietary patterns researched for heart health. (Estruch et al., 2013)"
            
            Examples of INCORRECT format (DO NOT USE):
            - "Spaghetti marinara benefits heart health" (mentions recipe name)
            - "Tomatoes are good for heart health" (no specific nutrient)
            - "No research available on pasta" (skip ingredients with no research)
            
            RULE 5: If an ingredient has NO relevant research linking its nutrients to \(category.lowercased()) health, SKIP IT ENTIRELY. Do not mention it.
            
            RULE 6: Prioritize ingredients with the strongest, most specific research. Include 2-3 strongest findings.
            
            RULE 7: Each research evidence point must cite a REAL study from PubMed with author names and year.
            
            Ingredients to evaluate: \(ingredientNames)
            
            Return ONLY research evidence for ingredients that have real studies. Skip all others silently.
            """
        } else {
            // Fallback if no ingredients available (single food item)
            researchInstructions = """
            
            RESEARCH INSTRUCTIONS FOR SINGLE FOOD:
            - Search PubMed for: "\(foodName) + [specific nutrient] + \(category.lowercased()) health"
            - Only include research if you find a REAL study linking \(foodName)'s SPECIFIC NUTRIENT to \(category.lowercased()) health
            - Format: "\(foodName)'s [nutrient] [specific finding]. ([First Author] et al., [Year])"
            - If no relevant research exists, return empty array [] - do not include "no research" messages
            """
        }
        
        let prompt = """
        Analyze \(foodName) for \(category.lowercased()) health benefits. This food has a longevity score of \(longevityScore)/100.
        
        \(categorySpecificPrompt)
        
        Generate three sections for this food's health benefits screen:
        
        SUMMARY SECTION (1 paragraph, 40-60 words):
        
        Write ONE punchy paragraph that:
        - States the \(category.lowercased()) score first (e.g., "Scoring \(score)/100 for \(category.lowercased())...")
        - Names 1-2 specific beneficial compounds and their effects
        - Acknowledges any negatives honestly
        - Uses specific numbers when possible (mg, %, grams)
        - Never uses wishy-washy language ("may," "could," "potentially")
        - CRITICAL: Reference the \(category.lowercased()) score (\(score)/100), NOT the overall longevity score (\(longevityScore)/100)
        
        RESEARCH EVIDENCE SECTION (2-3 bullet points, ingredient-specific only):
        \(researchInstructions)
        - Each point must link a SPECIFIC INGREDIENT's SPECIFIC NUTRIENT to \(category.lowercased()) health
        - CRITICAL: Only cite REAL, verifiable studies from PubMed-indexed peer-reviewed journals
        - USDA FoodData Central is for nutrient data ONLY, NOT research evidence - do NOT cite USDA as research
        - NEVER fabricate sources, author names, or study findings
        - NEVER use generic citations like "studies show" or "research indicates"
        - Ban these words: "suggests," "may," "potentially," "highlights," "indicates," "could," "might"
        - NEVER mention the recipe/meal name "\(foodName)" in research evidence - only ingredient names
        - CRITICAL: Each citation MUST include DOI or PubMed PMID for verification
        - If you cannot provide DOI or PMID, EXCLUDE the study entirely
        - Do NOT guess identifiers - only include studies where you can provide accurate DOI or PMID
        - If no ingredient has relevant research with verifiable identifiers, return empty array []
        - If research is unavailable, it's better to show none than to show fake citations
        - Prioritize dietary patterns over isolated nutrient fear - focus on whole food benefits
        
        BANNED PHRASES:
        - "consumed responsibly"
        - "when balanced with"
        - "contributing to positive outcomes"
        - "research indicates"
        - "studies highlight"
        
        Write in direct, factual language. State what IS, not what MIGHT BE.
        
        Return ONLY this JSON format:
        {
            "summary": "One paragraph (40-60 words) starting with the \(category.lowercased()) score (\(score)/100), naming specific compounds with numbers, acknowledging negatives",
            "researchEvidence": [
                {
                    "ingredient": "Ingredient name",
                    "nutrient": "Specific nutrient",
                    "outcome": "Health outcome finding",
                    "authors": "First Author et al.",
                    "year": 2021,
                    "journal": "Journal Name",
                    "doi": "10.xxxx/xxxxx or null",
                    "pmid": "12345678 or null",
                    "title": "Study title or null",
                    "url": "https://doi.org/10.xxxx/xxxxx or https://pubmed.ncbi.nlm.nih.gov/12345678/ or null"
                }
            ]
        }
        
        REQUIREMENTS:
        - At least ONE of doi or pmid must be provided (not both null)
        - DOI format: 10.xxxx/xxxxx
        - PMID format: numeric, 6-8 digits
        - If no verified studies exist, return empty researchEvidence array []
        """
        
        Task {
            do {
                let text = try await AIService.shared.makeOpenAIRequestAsync(prompt: prompt)
                
                // Process through ResearchEvidenceService for verification
                let verifiedCitations = await ResearchEvidenceService.shared.processAIResponse(text)
                
                await MainActor.run {
                    isLoading = false
                    
                    // Extract summary from response
                    let summary = extractSummary(from: text) ?? self.getCategorySpecificFallbackSummary()
                    
                    // Convert verified citations to legacy format
                    if !verifiedCitations.isEmpty {
                        self.healthInfo = HealthInfo(summary: summary, verifiedCitations: verifiedCitations)
                        print("✅ Successfully processed \(verifiedCitations.count) verified citations")
                    } else {
                        // No verified citations - return empty structure
                        self.healthInfo = HealthInfo(summary: summary, verifiedCitations: [])
                        print("⚠️ No verified citations found - returning empty research evidence")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("❌ Network error loading health info: \(error)")
                    
                    if attempt < 2 {
                        print("🔄 Retrying API call (attempt \(attempt + 1))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.loadHealthInfoWithRetry(attempt: attempt + 1)
                        }
                    } else {
                        print("❌ Max retries reached, showing error alert")
                        // Show alert instead of silent fallback
                        self.showErrorAlert = true
                    }
                }
            }
        }
    }
    
    private func extractJSONFromText(_ text: String) -> String {
        // Look for JSON object in the text
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            return String(text[jsonRange])
        }
        
        // If no JSON found, return the original text
        return text
    }
    
    private func createFallbackHealthInfo() {
        let categorySpecificSummary = getCategorySpecificFallbackSummary()
        
        // Return empty citations - no fake citations allowed
        self.healthInfo = HealthInfo(
            summary: categorySpecificSummary,
            verifiedCitations: []
        )
    }
    
    /// Extracts summary from AI response JSON
    private func extractSummary(from text: String) -> String? {
        // Extract JSON from text
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: .newlines)
            var jsonLines = lines
            if let firstLine = jsonLines.first, firstLine.contains("json") {
                jsonLines.removeFirst()
            } else if let firstLine = jsonLines.first, firstLine.hasPrefix("```") {
                jsonLines.removeFirst()
            }
            if let lastLine = jsonLines.last, lastLine == "```" {
                jsonLines.removeLast()
            }
            cleaned = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            cleaned = String(cleaned[jsonRange])
        }
        
        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let summary = json["summary"] as? String else {
            return nil
        }
        return summary
    }
    
    private func getCategorySpecificFallbackSummary() -> String {
        let scoreDescription = longevityScore >= 80 ? "excellent" : longevityScore >= 60 ? "good" : longevityScore >= 40 ? "moderate" : "limited"
        
        switch category.lowercased() {
        case "heart":
            return "This food contains nutrients commonly studied in relation to heart health, with a longevity score of \(longevityScore)/100. Foods researched for heart health typically contain antioxidants, healthy fats, and nutrients that are part of dietary patterns associated with cardiovascular function."
        case "brain":
            return "This food contains nutrients commonly studied in relation to brain health, with a longevity score of \(longevityScore)/100. Foods researched for brain health often contain omega-3 fatty acids, antioxidants, and nutrients that are part of dietary patterns associated with cognitive function."
        case "anti-inflam", "anti-inflammation":
            return "This food contains nutrients commonly studied in relation to inflammation, with a longevity score of \(longevityScore)/100. Foods researched for inflammation typically contain compounds that are part of dietary patterns associated with normal inflammatory function."
        case "bones", "joints", "bones & joints":
            return "This food contains nutrients commonly studied in relation to bone and joint health, with a longevity score of \(longevityScore)/100. Foods researched for bone health typically contain calcium, vitamin D, magnesium, and other nutrients that are part of dietary patterns associated with bone function."
        case "weight", "weight management":
            return "This food contains nutrients commonly studied in relation to weight management, with a longevity score of \(longevityScore)/100. Foods researched for weight management typically provide satiety-supporting nutrients and are part of dietary patterns associated with metabolic function."
        case "blood sugar":
            return "This food contains nutrients commonly studied in relation to blood sugar, with a longevity score of \(longevityScore)/100. Foods researched for blood sugar typically have a low glycemic index and contain fiber, protein, and healthy fats that are part of dietary patterns associated with glucose metabolism."
        case "energy":
            return "This food contains nutrients commonly studied in relation to energy, with a longevity score of \(longevityScore)/100. Foods researched for energy typically contain B vitamins, iron, complex carbohydrates, and other nutrients that are part of dietary patterns associated with energy metabolism."
        case "immune":
            return "This food contains nutrients commonly studied in relation to immune function, with a longevity score of \(longevityScore)/100. Foods researched for immune health typically contain vitamin C, zinc, antioxidants, and other nutrients that are part of dietary patterns associated with immune function."
        case "sleep":
            return "This food contains nutrients commonly studied in relation to sleep, with a longevity score of \(longevityScore)/100. Foods researched for sleep typically contain magnesium, tryptophan, melatonin precursors, and other nutrients that are part of dietary patterns associated with sleep function."
        case "skin":
            return "This food contains nutrients commonly studied in relation to skin health, with a longevity score of \(longevityScore)/100. Foods researched for skin health typically contain antioxidants, healthy fats, and nutrients that are part of dietary patterns associated with skin function."
        case "stress":
            return "This food contains nutrients commonly studied in relation to stress, with a longevity score of \(longevityScore)/100. Foods researched for stress typically contain adaptogens, B vitamins, magnesium, and other nutrients that are part of dietary patterns associated with stress function."
        default:
            return "This food contains nutrients commonly studied in relation to \(category.lowercased()), with a longevity score of \(longevityScore)/100. While specific research details are temporarily unavailable, the overall nutritional profile contains nutrients that are part of dietary patterns researched for this category."
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
        }
    }
    
    // Find the most relevant ingredient for a specific health goal category
    private func findMostRelevantIngredient(for category: String, from ingredients: [FoodIngredient]) -> String? {
        // Map health goal categories to ingredient keywords (prioritized lists)
        let categoryKeywords: [String: [String]] = [
            "Heart": ["salmon", "mackerel", "sardines", "tuna", "walnuts", "almonds", "olive oil", "avocado", "spinach", "kale", "oats", "quinoa", "berries", "dark chocolate", "garlic", "onion"],
            "Brain": ["salmon", "mackerel", "sardines", "blueberries", "walnuts", "dark chocolate", "spinach", "kale", "broccoli", "eggs", "turmeric", "pumpkin seeds", "green tea"],
            "Kidneys": ["berries", "blueberries", "cranberries", "red bell peppers", "cabbage", "cauliflower", "garlic", "onion", "fish", "olive oil", "apples", "red grapes"],
            "Vision": ["spinach", "kale", "carrots", "sweet potatoes", "eggs", "salmon", "mackerel", "bell peppers", "broccoli", "berries", "citrus", "nuts", "seeds"],
            "Detox/Liver": ["garlic", "onion", "beets", "leafy greens", "spinach", "kale", "broccoli", "cauliflower", "green tea", "turmeric", "grapefruit", "avocado", "walnuts"],
            "Anti-Inflam": ["salmon", "mackerel", "sardines", "olive oil", "berries", "cherries", "spinach", "kale", "broccoli", "turmeric", "ginger", "green tea", "nuts"],
            "Joints": ["salmon", "mackerel", "sardines", "olive oil", "cherries", "berries", "broccoli", "spinach", "kale", "nuts", "seeds", "green tea", "turmeric"],
            "Weight": ["oats", "quinoa", "beans", "lentils", "chicken", "turkey", "fish", "eggs", "vegetables", "leafy greens", "berries", "nuts", "avocado"],
            "Blood Sugar": ["oats", "quinoa", "beans", "lentils", "sweet potatoes", "berries", "nuts", "seeds", "leafy greens", "broccoli", "cinnamon", "vinegar"],
            "Energy": ["oats", "quinoa", "bananas", "sweet potatoes", "eggs", "chicken", "turkey", "fish", "nuts", "seeds", "dark chocolate", "green tea", "berries"],
            "Immune": ["citrus", "oranges", "lemons", "berries", "broccoli", "spinach", "kale", "garlic", "ginger", "turmeric", "yogurt", "almonds", "green tea"],
            "Sleep": ["almonds", "walnuts", "kiwi", "cherries", "bananas", "oats", "turkey", "chamomile", "milk", "eggs", "fish"],
            "Skin": ["salmon", "mackerel", "avocado", "walnuts", "sweet potatoes", "bell peppers", "broccoli", "tomatoes", "berries", "green tea", "dark chocolate"],
            "Stress": ["salmon", "mackerel", "dark chocolate", "green tea", "turmeric", "berries", "nuts", "seeds", "leafy greens", "avocado", "oats"],
            "Mood": ["salmon", "mackerel", "sardines", "dark chocolate", "berries", "bananas", "nuts", "seeds", "leafy greens", "turmeric", "green tea"],
            "Allergies": ["turmeric", "ginger", "onion", "garlic", "berries", "green tea", "probiotics", "yogurt", "leafy greens"]
        ]
        
        // Get keywords for this category (case-insensitive)
        let categoryLower = category.lowercased()
        let keywords = categoryKeywords.first { key, _ in
            key.lowercased() == categoryLower || categoryLower.contains(key.lowercased())
        }?.value ?? []
        
        // If no specific keywords, use general healthy ingredients
        let fallbackKeywords = keywords.isEmpty ? ["salmon", "berries", "leafy greens", "nuts", "olive oil", "whole grains"] : keywords
        
        // Search for matching ingredient (case-insensitive, partial match)
        for keyword in fallbackKeywords {
            if let match = ingredients.first(where: { ingredient in
                let name = ingredient.name.lowercased()
                return name.contains(keyword.lowercased()) || keyword.lowercased().contains(name)
            }) {
                return match.name
            }
        }
        
        // If no match found, return the first main ingredient (prioritize by position in list)
        return ingredients.first?.name
    }
    
    // CRITICAL: Use educational language only - no medical claims, no treatment/prevention language
    private func getCategorySpecificPrompt(category: String, foodName: String) -> String {
        switch category {
        case "Heart":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to heart health. Focus on:
            - Nutrients present that are researched for cardiovascular function
            - Dietary patterns associated with heart health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to heart function
            """
            
        case "Brain":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to brain health. Focus on:
            - Nutrients present that are researched for cognitive function
            - Dietary patterns associated with brain health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to brain function
            """
            
        case "Anti-Inflam":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to inflammation. Focus on:
            - Nutrients and compounds present in the food
            - Research associations with inflammatory markers
            - Dietary patterns researched for inflammation
            - Educational context about nutrient presence (do NOT describe mechanisms as outcomes)
            """
            
        case "Joints":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to joint health. Focus on:
            - Nutrients present that are researched for joint function
            - Dietary patterns associated with joint health
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to joint function
            """
            
        case "Eyes", "Vision":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to eye health. Focus on:
            - Nutrients present that are researched for vision function
            - Dietary patterns associated with eye health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to vision
            """
            
        case "Weight":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to weight management. Focus on:
            - Nutrients present that are researched for satiety and metabolism
            - Dietary patterns associated with weight management
            - Research context about nutrient presence (do NOT describe weight loss outcomes)
            - Educational information about nutrients linked to satiety
            """
            
        case "Blood Sugar":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to blood sugar. Focus on:
            - Nutrients present that are researched for glucose metabolism
            - Dietary patterns associated with blood sugar regulation
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to blood sugar function
            """
            
        case "Energy":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to energy. Focus on:
            - Nutrients present that are researched for energy metabolism
            - Dietary patterns associated with energy function
            - Research context about nutrient presence (do NOT describe mechanisms as outcomes)
            - Educational information about nutrients linked to energy
            """
            
        case "Immune":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to immune function. Focus on:
            - Nutrients present that are researched for immune health
            - Dietary patterns associated with immune function
            - Research context about nutrient presence (do NOT describe enhancement or treatment)
            - Educational information about nutrients linked to immune function
            """
            
        case "Sleep":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to sleep. Focus on:
            - Nutrients present that are researched for sleep function
            - Dietary patterns associated with sleep
            - Research context about nutrient presence (do NOT describe improvement or treatment)
            - Educational information about nutrients linked to sleep
            """
            
        case "Skin":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to skin health. Focus on:
            - Nutrients present that are researched for skin function
            - Dietary patterns associated with skin health
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to skin function
            """
            
        case "Stress":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to stress. Focus on:
            - Nutrients present that are researched for stress response
            - Dietary patterns associated with stress management
            - Research context about nutrient presence (do NOT describe treatment or management)
            - Educational information about nutrients linked to stress function
            """
            
        case "Kidneys":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to kidney health. Focus on:
            - Nutrients present that are researched for kidney function
            - Dietary patterns associated with kidney health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to kidney function
            """
            
        case "Detox/Liver":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to liver health. Focus on:
            - Nutrients present that are researched for liver function
            - Dietary patterns associated with liver health
            - Research context about nutrient presence (do NOT describe prevention or treatment)
            - Educational information about nutrients linked to liver function
            """
            
        case "Mood":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to mood. Focus on:
            - Nutrients present that are researched for mood function
            - Dietary patterns associated with mood
            - Research context about nutrient presence (do NOT describe treatment or management)
            - Educational information about nutrients linked to mood
            """
            
        case "Allergies":
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to allergies. Focus on:
            - Nutrients present that are researched for immune response
            - Dietary patterns associated with allergy response
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to immune function
            """
            
        default:
            return """
            Analyze nutrients in \(foodName) that are commonly studied in relation to \(category.lowercased()). Focus on:
            - Nutrients present that are researched for \(category.lowercased()) function
            - Dietary patterns associated with \(category.lowercased())
            - Research context about nutrient presence (do NOT describe treatment or prevention)
            - Educational information about nutrients linked to \(category.lowercased())
            """
        }
    }
}

// HealthInfo moved to ResearchCitation.swift

struct AddToMealTrackerSheet: View {
    let analysis: FoodAnalysis
    @Binding var mealName: String
    @Binding var notes: String
    let onSave: (TrackedMeal) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mealStorageManager = MealStorageManager.shared
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text("Add to Meal Tracker")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Add this food to your meal tracking history")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Food Preview
                VStack(spacing: 12) {
                    Text(analysis.foodName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Score Circle (smaller version)
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: max(0, min(1, CGFloat(analysis.overallScore) / 100)))
                            .stroke(
                                scoreColor(analysis.overallScore),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        VStack {
                            Text("\(analysis.overallScore)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(scoreColor(analysis.overallScore))
                            
                            Text("Score")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Form Fields
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter meal name", text: $mealName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Add any notes about this meal", text: $notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: saveMeal) {
                        Text("Add to Meal Tracker")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.0, green: 0.478, blue: 1.0), // Blue
                                        Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    }
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func saveMeal() {
        // Look up imageHash and inputMethod from FoodCacheManager (analysis is already cached there)
        // Try to find the exact cached entry by matching the analysis object itself
        var imageHash: String? = nil
        var inputMethod: String? = nil
        
        // First, try to find by matching the analysis object directly (most reliable)
        if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == analysis.foodName &&
            entry.fullAnalysis.overallScore == analysis.overallScore &&
            entry.fullAnalysis.summary == analysis.summary // More specific match
        }) {
            imageHash = cachedEntry.imageHash
            inputMethod = cachedEntry.inputMethod
            print("🍽️ AddToMealTrackerSheet: Found exact cached entry - imageHash: \(imageHash ?? "nil"), inputMethod: \(inputMethod ?? "nil")")
        } else if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == analysis.foodName &&
            entry.fullAnalysis.overallScore == analysis.overallScore
        }) {
            // Fallback: match by name and score only
            imageHash = cachedEntry.imageHash
            inputMethod = cachedEntry.inputMethod
            print("🍽️ AddToMealTrackerSheet: Found cached entry (fallback) - imageHash: \(imageHash ?? "nil"), inputMethod: \(inputMethod ?? "nil")")
        } else {
            print("🍽️ AddToMealTrackerSheet: No cached entry found for analysis, imageHash will be nil")
        }
        
        let mealNameToUse = mealName.isEmpty ? analysis.foodName : mealName
        
        // For text/voice entries (no imageHash), use stricter duplicate detection
        // For image entries, use standard duplicate detection
        let existingMeal: TrackedMeal?
        
        // Check if this is a text/voice entry: no imageHash means it's text/voice (even if inputMethod is nil)
        // If imageHash is nil, it's definitely a text/voice entry, regardless of inputMethod value
        let isTextVoiceEntry = imageHash == nil
        
        if isTextVoiceEntry {
            // Text/voice entry: Check for duplicate using multiple criteria (ignore timestamp)
            // This prevents duplicates even if user views entry hours/days later
            // Text/voice entries don't have unique imageHash identifiers, so we match by name+score+analysis
            print("🍽️ AddToMealTrackerSheet: Checking for duplicate text/voice entry: '\(mealNameToUse)' (score: \(analysis.overallScore))")
            print("🍽️ AddToMealTrackerSheet: Total meals in tracker: \(mealStorageManager.trackedMeals.count)")
            
            existingMeal = mealStorageManager.trackedMeals.first { meal in
                let nameMatch = meal.name == mealNameToUse
                let scoreMatch = abs(meal.healthScore - Double(analysis.overallScore)) < 1.0
                // Also check if it's a text/voice entry (no imageHash)
                let isTextVoiceMeal = meal.imageHash == nil
                
                // Additional check: match by originalAnalysis if available (most reliable)
                let analysisMatch = meal.originalAnalysis?.foodName == analysis.foodName &&
                                   meal.originalAnalysis?.overallScore == analysis.overallScore
                
                // Match if: (name+score+textVoice) OR (analysis match)
                let isMatch = (nameMatch && scoreMatch && isTextVoiceMeal) || analysisMatch
                
                if isMatch {
                    print("🍽️ AddToMealTrackerSheet: ✅ FOUND DUPLICATE text/voice meal: '\(meal.name)' (score: \(meal.healthScore), saved: \(meal.timestamp))")
                } else if nameMatch && scoreMatch {
                    print("🍽️ AddToMealTrackerSheet: ⚠️ Name+score match but meal has imageHash: '\(meal.name)' (imageHash: \(meal.imageHash ?? "nil"))")
                }
                
                return isMatch
            }
            
            if existingMeal == nil {
                print("🍽️ AddToMealTrackerSheet: No duplicate found, will save new meal")
            }
        } else {
            // Image entry: Use standard duplicate detection with imageHash matching
            let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
            existingMeal = mealStorageManager.trackedMeals.first { meal in
                let nameMatch = meal.name == mealNameToUse
                let scoreMatch = abs(meal.healthScore - Double(analysis.overallScore)) < 1.0
                let recentMatch = meal.timestamp > thirtyMinutesAgo
                
                // For image entries, also check imageHash match
                let imageHashMatch = imageHash != nil && meal.imageHash == imageHash
                let analysisMatch = meal.originalAnalysis?.overallScore == analysis.overallScore &&
                                   meal.originalAnalysis?.foodName == analysis.foodName
                
                return (nameMatch && scoreMatch && recentMatch) || imageHashMatch || analysisMatch
            }
        }
        
        if let existing = existingMeal {
            let secondsAgo = Int(Date().timeIntervalSince(existing.timestamp))
            print("🍽️ AddToMealTrackerSheet: Meal '\(mealNameToUse)' already exists in tracker (saved \(secondsAgo) seconds ago), skipping duplicate save")
            onSave(existing)
            return
        }
        
        let trackedMeal = TrackedMeal(
            id: UUID(),
            name: mealNameToUse,
            foods: [analysis.foodName],
            healthScore: Double(analysis.overallScore), // Use 0-100 scale (same as other places)
            goalsMet: getGoalsMet(from: analysis),
            timestamp: Date(),
            notes: notes.isEmpty ? nil : notes,
            originalAnalysis: analysis, // Store the original analysis for detailed view
            imageHash: imageHash, // Store image hash for fast direct lookup (like Shop screen)
            isFavorite: false
        )
        
        // Save to the meal storage system (Tracker/Diary)
        print("🍽️ AddToMealTrackerSheet: Saving meal to Tracker - \(trackedMeal.name), score: \(trackedMeal.healthScore), imageHash: \(imageHash ?? "nil")")
        mealStorageManager.addMeal(trackedMeal)
        print("🍽️ AddToMealTrackerSheet: Meal saved successfully to MealStorageManager")
        
        // Note: Analysis is already saved to FoodCacheManager (Score screen) in handleAnalysisResult
        // So it appears in both places without duplicates
        
        onSave(trackedMeal)
    }
    
    private func getGoalsMet(from analysis: FoodAnalysis) -> [String] {
        var metGoals: [String] = []
        
        // Simple logic to determine goals met based on scores
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
        if analysis.healthScores.weightManagement >= 7 {
            metGoals.append("Weight management")
        }
        if analysis.healthScores.bloodSugar >= 7 {
            metGoals.append("Blood sugar control")
        }
        if analysis.healthScores.energy >= 7 {
            metGoals.append("Energy")
        }
        if analysis.healthScores.immune >= 7 {
            metGoals.append("Immune support")
        }
        if analysis.healthScores.sleep >= 7 {
            metGoals.append("Sleep quality")
        }
        if analysis.healthScores.skin >= 7 {
            metGoals.append("Skin health")
        }
        if analysis.healthScores.stress >= 7 {
            metGoals.append("Stress management")
        }
        
        return metGoals
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
        }
    }
}

// MARK: - Secondary Details Response (Outside ResultsView)

struct SecondaryDetailsResponse: Codable {
    let keyBenefits: [String]
    let ingredientAnalyses: [IngredientAnalysis]
    let drugInteractions: [DrugInteraction]
    let dosageAnalyses: [DosageAnalysis]
    let safetyWarnings: [SafetyWarning]
    let qualityIndicators: [QualityIndicator]
}

// MARK: - Row Components (Outside ResultsView)

struct DosageAnalysisRow: View {
    let dosage: DosageAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dosage.ingredient)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("Label: \(dosage.labelDose)")
                    .font(.caption)
                Spacer()
                Text("Clinical: \(dosage.clinicalRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(dosageColor)
                        .frame(width: geo.size.width * dosagePercentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            HStack {
                Image(systemName: dosage.verdict == "optimal" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(dosage.verdict == "optimal" ? .green : .orange)
                Text(verdictText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    var dosagePercentage: CGFloat {
        switch dosage.verdict {
        case "optimal": return 0.8
        case "high": return 1.0
        default: return 0.3
        }
    }
    
    var dosageColor: Color {
        switch dosage.verdict {
        case "optimal": return .green
        case "high": return .orange
        default: return .yellow
        }
    }
    
    var verdictText: String {
        switch dosage.verdict {
        case "optimal": return "Optimal — Within effective range"
        case "high": return "High — Above typical clinical range"
        default: return "Below optimal — Consider higher dose"
        }
    }
}

struct SafetyWarningRow: View {
    let warning: SafetyWarning
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: warning.category == "sideEffect" ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(warning.category == "sideEffect" ? .blue : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(warning.category.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Text(warning.warning)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct QualityIndicatorRow: View {
    let indicator: QualityIndicator
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(indicator.indicator)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let detail = indicator.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    var statusIcon: String {
        switch indicator.status {
        case "positive": return "checkmark.circle.fill"
        case "negative": return "exclamationmark.triangle.fill"
        default: return "info.circle.fill"
        }
    }
    
    var statusColor: Color {
        switch indicator.status {
        case "positive": return .green
        case "negative": return .orange
        default: return .blue
        }
    }
}

// Preview removed due to complex initialization requirements
/*
#Preview {
    ResultsView(
        analysis: FoodAnalysis(
            foodName: "Sample Food",
            overallScore: 85,
            summary: "This food provides excellent health benefits.",
            healthScores: HealthScores(
                allergies: 75,
                antiInflammation: 80,
                bloodSugar: 80,
                brainHealth: 85,
                detoxLiver: 85,
                energy: 90,
                eyeHealth: 70,
                heartHealth: 90,
                immune: 85,
                jointHealth: 75,
                kidneys: 75,
                mood: 80,
                skin: 80,
                sleep: 75,
                stress: 85,
                weightManagement: 85
            ),
            keyBenefits: ["High in antioxidants", "Contains nutrients linked to heart health", "Contains nutrients linked to energy"],
            ingredients: [
                FoodIngredient(name: "Sample Ingredient", impact: "Positive", explanation: "Good for health")
            ],
            bestPreparation: "Steam or bake",
            servingSize: "1 cup",
            nutritionInfo: NutritionInfo(
                calories: "150",
                protein: "8g",
                carbohydrates: "25g",
                fat: "3g",
                sugar: "5g",
                fiber: "4g",
                sodium: "200mg"
            ),
            scanType: "food",
            foodNames: nil,
            foodPortions: nil,
            suggestions: nil
        ),
        onNewSearch: {}
    )
}
*/
