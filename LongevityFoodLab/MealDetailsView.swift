import SwiftUI

struct MealDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let meal: TrackedMeal
    @State private var healthDetailItem: HealthDetailItem? = nil
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @StateObject private var mealStorageManager = MealStorageManager.shared
    @State private var cachedImage: UIImage? = nil
    @State private var cachedAnalysis: FoodAnalysis? = nil // Retrieved from cache instead of stored copy
    @State private var cachedEntry: FoodCacheEntry? = nil // Store cached entry for inputMethod access
    @State private var isFavorite: Bool
    
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
    @State private var macroCustomDisclaimerAccepted = false
    @State private var microCustomDisclaimerAccepted = false
    @State private var showingMacroSelection = false
    @State private var showingMicroSelection = false
    @State private var selectedMacros: Set<String> = []
    @State private var selectedMicronutrientsForSelection: Set<String> = []
    @State private var selectedMacroForTarget: String?
    @State private var selectedMicronutrientForTarget: String?
    // REMOVED: Serving size editor functionality - nutrition now based on typical serving
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
    
    // Loading states
    @State private var isLoadingKeyBenefits = false
    @State private var isLoadingIngredients = false
    @State private var isLoadingNutritionInfo = false
    
    // Expanded ingredients for dropdown
    @State private var expandedIngredients: Set<Int> = []
    
    init(meal: TrackedMeal) {
        self.meal = meal
        _isFavorite = State(initialValue: meal.isFavorite)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark mode: 100% black background, light mode: system grouped background
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground)).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Use cached analysis (retrieved from FoodCacheManager) instead of stored copy
                        if let analysis = cachedAnalysis {
                            // Show the complete analysis (same as ResultsView)
                            analysisContent(analysis)
                        } else {
                            // Fallback to basic meal details if no analysis available
                            basicMealDetails
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                loadCachedAnalysis()
                if cachedAnalysis != nil {
                    loadImage()
                    loadNutritionInfo() // Load nutrition info after cached analysis is loaded
                }
                
                // Load selected macros/micros
                if selectedMacros.isEmpty {
                    selectedMacros = Set(healthProfileManager.getTrackedMacros())
                }
                if selectedMicronutrientsForSelection.isEmpty {
                    selectedMicronutrientsForSelection = Set(healthProfileManager.getTrackedMicronutrients())
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
            // REMOVED: Serving size editor sheet - nutrition now based on typical serving
            .sheet(item: $healthDetailItem) { item in
                if let analysis = cachedAnalysis {
                    HealthDetailView(
                        category: item.category,
                        score: item.score,
                        foodName: analysis.foodName,
                        longevityScore: analysis.overallScore,
                        isMealAnalysis: true,
                        scanType: analysis.scanType,
                        ingredients: analysis.ingredientsOrDefault
                    )
                }
            }
        }
    }
    
    
    
    // MARK: - Dropdown Components (using cached analysis data)
    
    private func keyBenefitsDropdown(_ analysis: FoodAnalysis) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isKeyBenefitsExpanded.toggle()
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
                let benefits = analysis.keyBenefitsOrDefault
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
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func ingredientsAnalysisDropdown(_ analysis: FoodAnalysis) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isIngredientsExpanded.toggle()
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
                let ingredients = analysis.ingredientsOrDefault
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
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Your Macronutrients Dropdown (Tracker Style)
    private func macrosDropdownTrackerStyle(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMacrosExpanded.toggle()
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
                    let nutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
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
                }
            }
        }
    }
    
    // MARK: - Your Micronutrients Dropdown (Tracker Style)
    private func microsDropdownTrackerStyle(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMicrosExpanded.toggle()
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
                    let nutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
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
                            let nutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
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
                            let nutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
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
    
    // Helper structs for sheet presentation
    struct MacroTargetItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    struct MicroTargetItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    private func bestPracticesDropdown(_ analysis: FoodAnalysis) -> some View {
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
                let bestPrep = analysis.bestPreparationOrDefault
                VStack(alignment: .leading, spacing: 12) {
                    if !bestPrep.isEmpty {
                        Text(bestPrep)
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
    
    private func nutritionInfoView(_ nutrition: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Macros Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Macros")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                
                nutritionRow("Calories", nutrition.calories)
                nutritionRow("Protein", nutrition.protein)
                nutritionRow("Carbs", nutrition.carbohydrates)
                nutritionRow("Fat", nutrition.fat)
                nutritionRow("Sugar", nutrition.sugar)
                nutritionRow("Fiber", nutrition.fiber)
                nutritionRow("Sodium", nutrition.sodium)
            }
            
            // Micros Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Micros")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.bottom, 4)
                
                if let vitaminD = nutrition.vitaminD, !vitaminD.isEmpty {
                    nutritionRow("Vitamin D", vitaminD)
                }
                if let vitaminE = nutrition.vitaminE, !vitaminE.isEmpty {
                    nutritionRow("Vitamin E", vitaminE)
                }
                if let potassium = nutrition.potassium, !potassium.isEmpty {
                    nutritionRow("Potassium", potassium)
                }
                if let vitaminK = nutrition.vitaminK, !vitaminK.isEmpty {
                    nutritionRow("Vitamin K", vitaminK)
                }
                if let magnesium = nutrition.magnesium, !magnesium.isEmpty {
                    nutritionRow("Magnesium", magnesium)
                }
                if let vitaminA = nutrition.vitaminA, !vitaminA.isEmpty {
                    nutritionRow("Vitamin A", vitaminA)
                }
                if let calcium = nutrition.calcium, !calcium.isEmpty {
                    nutritionRow("Calcium", calcium)
                }
                if let vitaminC = nutrition.vitaminC, !vitaminC.isEmpty {
                    nutritionRow("Vitamin C", vitaminC)
                }
                if let choline = nutrition.choline, !choline.isEmpty {
                    nutritionRow("Choline", choline)
                }
                if let iron = nutrition.iron, !iron.isEmpty {
                    nutritionRow("Iron", iron)
                }
                if let zinc = nutrition.zinc, !zinc.isEmpty {
                    nutritionRow("Zinc", zinc)
                }
                if let folate = nutrition.folate, !folate.isEmpty {
                    nutritionRow("Folate (B9)", folate)
                }
                if let vitaminB12 = nutrition.vitaminB12, !vitaminB12.isEmpty {
                    nutritionRow("Vitamin B12", vitaminB12)
                }
                if let vitaminB6 = nutrition.vitaminB6, !vitaminB6.isEmpty {
                    nutritionRow("Vitamin B6", vitaminB6)
                }
                if let selenium = nutrition.selenium, !selenium.isEmpty {
                    nutritionRow("Selenium", selenium)
                }
                if let copper = nutrition.copper, !copper.isEmpty {
                    nutritionRow("Copper", copper)
                }
                if let manganese = nutrition.manganese, !manganese.isEmpty {
                    nutritionRow("Manganese", manganese)
                }
                if let thiamin = nutrition.thiamin, !thiamin.isEmpty {
                    nutritionRow("Thiamin (B1)", thiamin)
                }
            }
        }
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
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Old Functions (kept for reference but not used in new design)
    
    private func scoreCard(_ analysis: FoodAnalysis) -> some View {
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
                
                Circle()
                    .trim(from: 0, to: max(0, min(1, CGFloat(analysis.overallScore) / 100)))
                    .stroke(
                        scoreColor(analysis.overallScore),
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(analysis.overallScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor(analysis.overallScore))
                    
                    Text(scoreLabel(analysis.overallScore))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)
            
            Text(analysis.summary)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(30)
        .background(Color(UIColor.systemBackground))
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
    
    // Helper function to map profile goal names to health score category names
    // Returns mapping even if score is -1 (to ensure all selected goals render)
    private func mapProfileGoalToCategory(_ goal: String, analysis: FoodAnalysis) -> (category: String, icon: String, label: String, score: Int)? {
        let normalized = normalizeHealthGoal(goal)
        
        switch normalized {
        case "heart health":
            return ("Heart", "❤️", "Heart\nHealth", analysis.healthScores.heartHealth)
        case "brain health":
            return ("Brain", "🧠", "Brain\nHealth", analysis.healthScores.brainHealth)
        case "weight management":
            return ("Weight", "⚖️", "Weight", analysis.healthScores.weightManagement)
        case "immune support":
            return ("Immune", "🛡️", "Immune", analysis.healthScores.immune)
        case "blood sugar", "blood_sugar":
            return ("Blood Sugar", "🩸", "Blood Sugar", analysis.healthScores.bloodSugar)
        case "energy":
            return ("Energy", "⚡", "Energy", analysis.healthScores.energy)
        case "sleep quality", "sleep":
            return ("Sleep", "😴", "Sleep", analysis.healthScores.sleep)
        case "stress management", "stress":
            return ("Stress", "🧘", "Stress", analysis.healthScores.stress)
        case "skin health", "skin":
            return ("Skin", "✨", "Skin", analysis.healthScores.skin)
        case "joint health", "joints":
            return ("Joints", "🦴", "Joint\nHealth", analysis.healthScores.jointHealth)
        case "bone/muscle health", "bone muscle health", "bones muscle health":
            return ("Joints", "🦴", "Bones &\nJoints", analysis.healthScores.jointHealth)
        case "digestive health", "digestive":
            return ("Detox/Liver", "🧪", "Detox/\nLiver", analysis.healthScores.detoxLiver)
        case "hormonal balance", "hormonal":
            return ("Mood", "😊", "Mood", analysis.healthScores.mood)
        default:
            // Try partial matching for Blood Sugar
            if normalized.contains("blood") && normalized.contains("sugar") {
                return ("Blood Sugar", "🩸", "Blood Sugar", analysis.healthScores.bloodSugar)
            }
            return nil
        }
    }
    
    @ViewBuilder
    private func healthScoresGrid(_ analysis: FoodAnalysis) -> some View {
        let userHealthGoals = healthProfileManager.getHealthGoals()
        
        // Map user-selected goals to categories (always returns mapping, even if score is -1)
        let filteredGoals = userHealthGoals.compactMap { mapProfileGoalToCategory($0, analysis: analysis) }
        
        VStack(alignment: .leading, spacing: 12) {
            Text("Research For Your Health Goals")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            
            if filteredGoals.isEmpty {
                Text("Select health goals in your profile to see personalized research.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // 3-column grid matching Supplements style
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
                            onTap: { category, score in
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
    
    // Tappable health score box matching Supplements style (gray cards)
    private struct TappableHealthScoreBox: View {
        let icon: String
        let label: String
        let score: Int
        let category: String
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
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
            .disabled(score == -1)
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func scoreLabel(_ score: Int) -> String {
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
    
    private func ingredientsSection(_ analysis: FoodAnalysis) -> some View {
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
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Old Functions (kept for fallback basicMealDetails)
    
    private func benefitsSection(_ analysis: FoodAnalysis) -> some View {
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
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    private func practicesSection(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Text("🍳")
                Text("Best Practices")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Only show Preparation if it's NOT healthier choices text
                let bestPrep = analysis.bestPreparationOrDefault
                if !bestPrep.isEmpty && !isHealthierChoicesText(bestPrep) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preparation:")
                            .fontWeight(.semibold)
                        Text(bestPrep)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Serving Size:")
                        .fontWeight(.semibold)
                    Text(analysis.servingSize)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nutritional Information:")
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        let nutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
                        nutritionRow("Calories", nutrition.calories)
                        nutritionRow("Protein", nutrition.protein)
                        nutritionRow("Carbs", nutrition.carbohydrates)
                        nutritionRow("Fat", nutrition.fat)
                        nutritionRow("Sugar", nutrition.sugar)
                        nutritionRow("Fiber", nutrition.fiber)
                        nutritionRow("Sodium", nutrition.sodium)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // Helper functions
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
    
    private func nutritionRow(_ label: String, _ value: String) -> some View {
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
    
    // MARK: - Analysis Content (new design matching ResultsView)
    
    private func analysisContent(_ analysis: FoodAnalysis) -> some View {
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
                        scoreCircleOverlay(analysis)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
                .padding(.horizontal, 20)
            } else if meal.imageHash == nil {
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
                        scoreCircleOverlay(analysis)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
                .padding(.horizontal, 20)
            } else {
                // Fallback: Show score circle without image (if image not available but imageHash exists)
                scoreCircleRecipeStyle(analysis)
            }
            
            // Summary text with optional longevity reassurance
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
            .padding(.horizontal, 20)
            
            // Key Benefits dropdown
            keyBenefitsDropdown(analysis)
            
            // Health Scores Grid
            healthScoresGrid(analysis)
            
            // Ingredients Analysis dropdown
            ingredientsAnalysisDropdown(analysis)
            
            // Your Macronutrients dropdown
            macrosDropdownTrackerStyle(analysis)
            
            // Your Micronutrients dropdown
            microsDropdownTrackerStyle(analysis)
            
            // Quality & Source dropdown
            QualitySourceView(foodName: analysis.foodName)
            
            // Healthier Choices (only for scanned products)
            if isHealthierChoicesText(analysis.bestPreparationOrDefault) {
                HealthierChoicesView(analysis: analysis)
            }
            
            // Best Practices dropdown
            if !analysis.bestPreparationOrDefault.isEmpty && !isHealthierChoicesText(analysis.bestPreparationOrDefault) {
                bestPracticesDropdown(analysis)
            }
            
            // Educational disclaimer - always shown at bottom
            HealthGoalsDisclaimerView()
            
            // Notes if available
            if let notes = meal.notes, !notes.isEmpty {
                notesSection(notes)
            }
        }
    }
    
    // MARK: - Load Cached Analysis
    
    private func toggleFavorite() {
        isFavorite.toggle()
        
        // Update the meal in MealStorageManager (if it exists there)
        if mealStorageManager.trackedMeals.contains(where: { $0.id == meal.id }) {
            var updatedMeal = meal
            updatedMeal.isFavorite = isFavorite
            mealStorageManager.updateMeal(updatedMeal)
        }
        
        // Also update FoodCacheEntry if this meal came from FoodCacheManager (scanned from Score screen)
        if let imageHash = meal.imageHash {
            foodCacheManager.updateEntryFavorite(imageHash: imageHash, isFavorite: isFavorite)
        }
    }
    
    private func loadCachedAnalysis() {
        // First try: Use imageHash to get cached analysis (most reliable)
        if let imageHash = meal.imageHash,
           let entry = foodCacheManager.cachedAnalyses.first(where: { $0.imageHash == imageHash }) {
            cachedAnalysis = entry.fullAnalysis
            cachedEntry = entry
            print("🔍 MealDetailsView: Retrieved analysis from cache using imageHash: \(imageHash)")
            return
        }
        
        // Fallback: Use stored originalAnalysis (for backward compatibility with old meals)
        if let analysis = meal.originalAnalysis {
            cachedAnalysis = analysis
            // Try to find cached entry by name and score
            cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
                entry.foodName == analysis.foodName &&
                entry.fullAnalysis.overallScore == analysis.overallScore
            })
            print("🔍 MealDetailsView: Using stored originalAnalysis (fallback)")
            return
        }
        
        // Final fallback: Try name matching in cache
        if let entry = foodCacheManager.cachedAnalyses.first(where: { $0.foodName == meal.name }) {
            cachedAnalysis = entry.fullAnalysis
            cachedEntry = entry
            print("🔍 MealDetailsView: Retrieved analysis from cache using name matching")
            return
        }
        
        // No analysis found
        cachedAnalysis = nil
        cachedEntry = nil
        print("🔍 MealDetailsView: No cached analysis found for meal: \(meal.name)")
    }
    
    // MARK: - Nutrition Loading
    
    // Check if nutrition info is valid (not all "N/A")
    private func isNutritionInfoValid(_ nutrition: NutritionInfo) -> Bool {
        // Check if any macro has a valid value (not "N/A" or empty)
        let macros = [nutrition.calories, nutrition.protein, nutrition.carbohydrates, nutrition.fat]
        return macros.contains { value in
            !value.isEmpty && value.uppercased() != "N/A" && parseNutritionValueDouble(value) != nil && parseNutritionValueDouble(value) ?? 0 > 0
        }
    }
    
    // Check if nutrition values are reasonable (not obviously wrong)
    private func isNutritionReasonable(_ nutrition: NutritionInfo, isMeal: Bool = true) -> Bool {
        guard let calories = Int(nutrition.calories) else { 
            // If calories can't be parsed, it's not reasonable
            return false 
        }
        
        // For meals, allow higher calories (up to 2000)
        // For single foods, calories should be reasonable (< 500)
        let maxCalories = isMeal ? 2000 : 500
        
        if calories > maxCalories {
            print("⚠️ MealDetailsView: Nutrition validation failed - Calories (\(calories)) exceeds reasonable limit (\(maxCalories)) for \(isMeal ? "meal" : "single food")")
            return false
        }
        
        return true
    }
    
    private func loadNutritionInfo() {
        // Step 1: If already loaded with valid data (in-memory cache), don't reload
        if let loaded = loadedNutritionInfo, 
           isNutritionInfoValid(loaded),
           isNutritionReasonable(loaded, isMeal: true) {
            print("ℹ️ MealDetailsView: Nutrition already loaded and valid (in-memory), skipping")
            return
        } else if let loaded = loadedNutritionInfo, isNutritionInfoValid(loaded) {
            print("⚠️ MealDetailsView: In-memory nutrition exists but is unreasonable, re-fetching from USDA...")
        }
        
        // Step 2: Check if cached analysis has valid nutrition info
        if let analysis = cachedAnalysis,
           let currentNutrition = analysis.nutritionInfo,
           isNutritionInfoValid(currentNutrition),
           isNutritionReasonable(currentNutrition, isMeal: true) {
            print("ℹ️ MealDetailsView: Cached analysis has valid nutrition info, using it")
            loadedNutritionInfo = currentNutrition
            return
        } else if let analysis = cachedAnalysis, let currentNutrition = analysis.nutritionInfo, isNutritionInfoValid(currentNutrition) {
            print("⚠️ MealDetailsView: Cached analysis nutrition exists but is unreasonable, re-fetching from USDA...")
        }
        
        // Step 3: Check persistent cache (FoodCacheManager) for cached nutrition info
        // First, try using imageHash if available
        if let imageHash = meal.imageHash,
           let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { $0.imageHash == imageHash }) {
            if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, 
               isNutritionInfoValid(cachedNutrition),
               isNutritionReasonable(cachedNutrition, isMeal: true) {
                print("✅ MealDetailsView: Found valid nutrition info in cache by imageHash, using cache (no API call)")
                loadedNutritionInfo = cachedNutrition
                // Update cachedAnalysis with nutrition if needed
                if cachedAnalysis != nil {
                    updateCachedAnalysisWithNutrition(cachedNutrition)
                }
                return
            } else if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                print("⚠️ MealDetailsView: Cache nutrition by imageHash exists but is unreasonable, re-fetching from USDA...")
            }
        }
        
        // Step 4: Search cache by meal name and score
        if let analysis = cachedAnalysis,
           let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
               entry.foodName == analysis.foodName &&
               entry.fullAnalysis.overallScore == analysis.overallScore
           }) {
            if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, 
               isNutritionInfoValid(cachedNutrition),
               isNutritionReasonable(cachedNutrition, isMeal: true) {
                print("✅ MealDetailsView: Found valid nutrition info in cache by meal name, using cache (no API call)")
                loadedNutritionInfo = cachedNutrition
                updateCachedAnalysisWithNutrition(cachedNutrition)
                return
            } else if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                print("⚠️ MealDetailsView: Cache nutrition by meal name exists but is unreasonable, re-fetching from USDA...")
            }
        }
        
        // Step 5: Fallback to name matching (for old meals without exact match)
        if let analysis = cachedAnalysis {
            let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
                let mealName = analysis.foodName.lowercased().trimmingCharacters(in: .whitespaces)
                return entryName == mealName ||
                       entryName.contains(mealName) ||
                       mealName.contains(entryName)
            }
            
            if let matchingEntry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
                if let cachedNutrition = matchingEntry.fullAnalysis.nutritionInfo, 
                   isNutritionInfoValid(cachedNutrition),
                   isNutritionReasonable(cachedNutrition, isMeal: true) {
                    print("✅ MealDetailsView: Found valid nutrition info in cache by name match, using cache (no API call)")
                    loadedNutritionInfo = cachedNutrition
                    updateCachedAnalysisWithNutrition(cachedNutrition)
                    return
                } else if let cachedNutrition = matchingEntry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                    print("⚠️ MealDetailsView: Cache nutrition by name match exists but is unreasonable, re-fetching from USDA...")
                }
            }
        }
        
        // Step 6: No cache found - make API call
        guard let analysis = cachedAnalysis else {
            print("⚠️ MealDetailsView: No cached analysis available, cannot load nutrition")
            return
        }
        
        print("🚀 MealDetailsView: No cached nutrition found, starting API load for meal '\(analysis.foodName)'")
        isLoadingNutritionInfo = true
        
        Task {
            let startTime = Date()
            do {
                let nutrition: NutritionInfo
                
                // Check if this is a meal with multiple foods
                if let foodNames = analysis.foodNames, !foodNames.isEmpty {
                    print("🔍 MealDetailsView: Detected meal with \(foodNames.count) ingredients: \(foodNames.joined(separator: ", "))")
                    // Meal: aggregate nutrition from all ingredients using tiered lookup
                    if let aggregatedNutrition = try await aggregateNutritionForMealWithTieredLookup(foodNames: foodNames) {
                        nutrition = aggregatedNutrition
                        let duration = Date().timeIntervalSince(startTime)
                        print("✅ MealDetailsView: Loaded nutrition from meal aggregation in \(String(format: "%.2f", duration))s")
                    } else {
                        throw NSError(domain: "MealDetailsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to aggregate nutrition for meal"])
                    }
                } else {
                    // Single food: Try tiered lookup
                    if let tieredNutrition = try await NutritionService.shared.getNutritionForFood(analysis.foodName) {
                        nutrition = tieredNutrition
                        let duration = Date().timeIntervalSince(startTime)
                        print("✅ MealDetailsView: Loaded nutrition via tiered lookup in \(String(format: "%.2f", duration))s")
                    } else {
                        throw NSError(domain: "MealDetailsView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get nutrition for food"])
                    }
                }
                
                await MainActor.run {
                    loadedNutritionInfo = nutrition
                    isLoadingNutritionInfo = false
                    
                    // Update the cached analysis with the loaded nutrition info
                    updateCachedAnalysisWithNutrition(nutrition)
                    print("✅ MealDetailsView: Nutrition info displayed and cached")
                }
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                print("❌ MealDetailsView: Failed to load nutrition info after \(String(format: "%.2f", duration))s")
                print("❌ MealDetailsView: Error: \(error.localizedDescription)")
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
                    print("⚠️ MealDetailsView: Using fallback N/A values")
                }
            }
        }
    }
    
    /// Aggregate nutrition for a meal with multiple foods using tiered lookup (USDA -> Spoonacular -> AI)
    private func aggregateNutritionForMealWithTieredLookup(foodNames: [String]) async throws -> NutritionInfo? {
        print("🔍 MealDetailsView: Aggregating nutrition for meal with \(foodNames.count) ingredients using tiered lookup")
        var totalNutrition: [String: Double] = [:]
        var foundAny = false
        
        // Use TaskGroup for parallel lookups
        // Estimate typical serving sizes for each ingredient first
        try await withThrowingTaskGroup(of: (String, NutritionInfo?).self) { group in
            for foodName in foodNames {
                group.addTask {
                    do {
                        // Estimate typical serving size for this ingredient in a meal context
                        let servingInfo: (size: String, weightGrams: Double)
                        do {
                            servingInfo = try await AIService.shared.estimateTypicalServingSize(foodName: foodName, isRecipe: false)
                            print("✅ MealDetailsView: Estimated serving size for '\(foodName)': \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
                        } catch {
                            print("⚠️ MealDetailsView: Failed to estimate serving size for '\(foodName)', using default 100g: \(error)")
                            servingInfo = (size: "1 serving", weightGrams: 100.0)
                        }
                        
                        // Use tiered lookup with estimated serving size
                        if let nutrition = try await NutritionService.shared.getNutritionForFood(foodName, amount: servingInfo.weightGrams, unit: "g") {
                            print("✅ MealDetailsView: Found nutrition for '\(foodName)' at \(servingInfo.size) (\(Int(servingInfo.weightGrams))g)")
                            return (foodName, nutrition)
                        } else {
                            print("⚠️ MealDetailsView: No nutrition found for '\(foodName)'")
                            return (foodName, nil)
                        }
                    } catch {
                        print("⚠️ MealDetailsView: Error looking up '\(foodName)': \(error.localizedDescription)")
                        return (foodName, nil)
                    }
                }
            }
            
            for try await (foodName, nutrition) in group {
                if let nutrition = nutrition {
                    foundAny = true
                    print("✅ MealDetailsView: Found nutrition for '\(foodName)'")
                    addNutritionToTotals(nutrition, to: &totalNutrition)
                }
            }
        }
        
        guard foundAny else {
            print("⚠️ MealDetailsView: No nutrition found for any ingredient")
            return nil
        }
        
        // Convert totals to NutritionInfo
        return createNutritionInfoFromTotals(totalNutrition)
    }
    
    /// Add nutrition values to totals dictionary
    private func addNutritionToTotals(_ nutrition: NutritionInfo, to totals: inout [String: Double]) {
        // Macros
        if let calories = parseNutritionValueDouble(nutrition.calories) {
            totals["calories", default: 0] += calories
        }
        if let protein = parseNutritionValueDouble(nutrition.protein) {
            totals["protein", default: 0] += protein
        }
        if let carbs = parseNutritionValueDouble(nutrition.carbohydrates) {
            totals["carbohydrates", default: 0] += carbs
        }
        if let fat = parseNutritionValueDouble(nutrition.fat) {
            totals["fat", default: 0] += fat
        }
        if let fiber = parseNutritionValueDouble(nutrition.fiber) {
            totals["fiber", default: 0] += fiber
        }
        if let sugar = parseNutritionValueDouble(nutrition.sugar) {
            totals["sugar", default: 0] += sugar
        }
        if let sodium = parseNutritionValueDouble(nutrition.sodium) {
            totals["sodium", default: 0] += sodium
        }
        
        // Micronutrients
        if let vitaminD = parseNutritionValueDouble(nutrition.vitaminD) {
            totals["vitaminD", default: 0] += vitaminD
        }
        if let vitaminE = parseNutritionValueDouble(nutrition.vitaminE) {
            totals["vitaminE", default: 0] += vitaminE
        }
        if let potassium = parseNutritionValueDouble(nutrition.potassium) {
            totals["potassium", default: 0] += potassium
        }
        if let vitaminK = parseNutritionValueDouble(nutrition.vitaminK) {
            totals["vitaminK", default: 0] += vitaminK
        }
        if let magnesium = parseNutritionValueDouble(nutrition.magnesium) {
            totals["magnesium", default: 0] += magnesium
        }
        if let vitaminA = parseNutritionValueDouble(nutrition.vitaminA) {
            totals["vitaminA", default: 0] += vitaminA
        }
        if let calcium = parseNutritionValueDouble(nutrition.calcium) {
            totals["calcium", default: 0] += calcium
        }
        if let vitaminC = parseNutritionValueDouble(nutrition.vitaminC) {
            totals["vitaminC", default: 0] += vitaminC
        }
        if let choline = parseNutritionValueDouble(nutrition.choline) {
            totals["choline", default: 0] += choline
        }
        if let iron = parseNutritionValueDouble(nutrition.iron) {
            totals["iron", default: 0] += iron
        }
        if let zinc = parseNutritionValueDouble(nutrition.zinc) {
            totals["zinc", default: 0] += zinc
        }
        if let folate = parseNutritionValueDouble(nutrition.folate) {
            totals["folate", default: 0] += folate
        }
        if let vitaminB12 = parseNutritionValueDouble(nutrition.vitaminB12) {
            totals["vitaminB12", default: 0] += vitaminB12
        }
        if let vitaminB6 = parseNutritionValueDouble(nutrition.vitaminB6) {
            totals["vitaminB6", default: 0] += vitaminB6
        }
        if let selenium = parseNutritionValueDouble(nutrition.selenium) {
            totals["selenium", default: 0] += selenium
        }
        if let copper = parseNutritionValueDouble(nutrition.copper) {
            totals["copper", default: 0] += copper
        }
        if let manganese = parseNutritionValueDouble(nutrition.manganese) {
            totals["manganese", default: 0] += manganese
        }
        if let thiamin = parseNutritionValueDouble(nutrition.thiamin) {
            totals["thiamin", default: 0] += thiamin
        }
    }
    
    /// Create NutritionInfo from totals dictionary
    private func createNutritionInfoFromTotals(_ totals: [String: Double]) -> NutritionInfo {
        func formatValue(_ key: String, unit: String = "g") -> String {
            guard let value = totals[key], value > 0 else { return "0\(unit)" }
            if key == "calories" || key == "sodium" {
                return "\(Int(round(value)))\(unit == "g" ? "" : unit)"
            }
            return String(format: "%.1f\(unit)", value)
        }
        
        return NutritionInfo(
            calories: formatValue("calories", unit: ""),
            protein: formatValue("protein"),
            carbohydrates: formatValue("carbohydrates"),
            fat: formatValue("fat"),
            sugar: formatValue("sugar"),
            fiber: formatValue("fiber"),
            sodium: formatValue("sodium", unit: "mg"),
            vitaminD: formatValue("vitaminD", unit: "mcg"),
            vitaminE: formatValue("vitaminE", unit: "mg"),
            potassium: formatValue("potassium", unit: "mg"),
            vitaminK: formatValue("vitaminK", unit: "mcg"),
            magnesium: formatValue("magnesium", unit: "mg"),
            vitaminA: formatValue("vitaminA", unit: "mcg"),
            calcium: formatValue("calcium", unit: "mg"),
            vitaminC: formatValue("vitaminC", unit: "mg"),
            choline: formatValue("choline", unit: "mg"),
            iron: formatValue("iron", unit: "mg"),
            zinc: formatValue("zinc", unit: "mg"),
            folate: formatValue("folate", unit: "mcg"),
            vitaminB12: formatValue("vitaminB12", unit: "mcg"),
            vitaminB6: formatValue("vitaminB6", unit: "mg"),
            selenium: formatValue("selenium", unit: "mcg"),
            copper: formatValue("copper", unit: "mg"),
            manganese: formatValue("manganese", unit: "mg"),
            thiamin: formatValue("thiamin", unit: "mg")
        )
    }
    
    private func updateCachedAnalysisWithNutrition(_ nutrition: NutritionInfo) {
        guard let analysis = cachedAnalysis else {
            print("⚠️ MealDetailsView: No cached analysis available to update")
            return
        }
        
        // Find the cached entry for this meal
        var cachedEntry: FoodCacheEntry?
        
        // First try: Use imageHash if available
        if let imageHash = meal.imageHash {
            cachedEntry = foodCacheManager.cachedAnalyses.first(where: { $0.imageHash == imageHash })
        }
        
        // Second try: Match by food name and score
        if cachedEntry == nil {
            cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
                entry.foodName == analysis.foodName &&
                entry.fullAnalysis.overallScore == analysis.overallScore
            })
        }
        
        if let entry = cachedEntry {
            // Create updated analysis with nutrition info
            let updatedAnalysis = FoodAnalysis(
                foodName: entry.fullAnalysis.foodName,
                overallScore: entry.fullAnalysis.overallScore,
                summary: entry.fullAnalysis.summary,
                healthScores: entry.fullAnalysis.healthScores,
                keyBenefits: entry.fullAnalysis.keyBenefits,
                ingredients: entry.fullAnalysis.ingredients,
                bestPreparation: entry.fullAnalysis.bestPreparation,
                servingSize: entry.fullAnalysis.servingSize,
                nutritionInfo: nutrition, // Updated nutrition info
                scanType: entry.fullAnalysis.scanType,
                foodNames: entry.fullAnalysis.foodNames,
                suggestions: entry.fullAnalysis.suggestions
            )
            
            // Update the cached entry with the new analysis
            foodCacheManager.cacheAnalysis(updatedAnalysis, imageHash: entry.imageHash, scanType: entry.scanType)
            
            // Also update local cachedAnalysis
            cachedAnalysis = updatedAnalysis
            
            print("✅ MealDetailsView: Updated cached analysis with nutrition info for \(analysis.foodName)")
        } else {
            print("⚠️ MealDetailsView: Could not find cached entry to update for \(analysis.foodName)")
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage() {
        // Use direct hash lookup (fast) if imageHash is available
        if let imageHash = meal.imageHash {
            // Direct lookup - instant load from disk
            if let image = foodCacheManager.loadImage(forHash: imageHash) {
                cachedImage = image
                print("🔍 MealDetailsView: Loaded image for hash: \(imageHash)")
                return
            }
        }
        
        // Fallback: Try to find image using cachedAnalysis or name matching
        DispatchQueue.global(qos: .userInitiated).async {
            var matchingEntry: FoodCacheEntry?
            
            // First, try to match by cachedAnalysis if available
            if let analysis = cachedAnalysis {
                // Find cache entries that match the analysis
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    // Match by food name and analysis content
                    entry.foodName == analysis.foodName &&
                    entry.fullAnalysis.overallScore == analysis.overallScore
                }
                
                // Get the most recent matching entry (closest to meal timestamp)
                matchingEntry = matchingEntries.sorted { entry1, entry2 in
                    let diff1 = abs(entry1.analysisDate.timeIntervalSince(meal.timestamp))
                    let diff2 = abs(entry2.analysisDate.timeIntervalSince(meal.timestamp))
                    return diff1 < diff2
                }.first
            }
            
            // Fallback to name matching if no cachedAnalysis match found
            if matchingEntry == nil {
                let foodName = meal.name.lowercased().trimmingCharacters(in: .whitespaces)
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
                    return entryName == foodName ||
                           entryName.contains(foodName) ||
                           foodName.contains(entryName)
                }
                
                // Get the most recent matching entry
                matchingEntry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first
            }
            
            // Load image if match found
            if let matchingEntry = matchingEntry,
               let imageHash = matchingEntry.imageHash {
                if let image = foodCacheManager.loadImage(forHash: imageHash) {
                    DispatchQueue.main.async {
                        self.cachedImage = image
                        print("🔍 MealDetailsView: Loaded image from fallback match")
                    }
                }
            }
        }
    }
    
    // MARK: - Score Circle Components
    
    private func scoreCircleOverlay(_ analysis: FoodAnalysis) -> some View {
        ZStack {
            // Background circle with gradient fill (recipe style)
            Circle()
                .fill(scoreGradient(analysis.overallScore))
                .frame(width: 90, height: 90)
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            
            // Score number and label (white text - reverse type)
            VStack(spacing: -4) {
                Text("\(analysis.overallScore)")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(.white)
                
                Text(scoreLabel(analysis.overallScore).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private func scoreCircleRecipeStyle(_ analysis: FoodAnalysis) -> some View {
        scoreCircleOverlay(analysis)
            .padding(.vertical, 10)
    }
    
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
    
    // MARK: - Basic Meal Details (fallback)
    
    private var basicMealDetails: some View {
        VStack(spacing: 24) {
            // Header
            headerSection
            
            // Health Score
            healthScoreSection
            
            // Food Items
            foodItemsSection
            
            // Health Goals Met
            if !meal.goalsMet.isEmpty {
                healthGoalsSection()
            }
            
            // Notes
            if let notes = meal.notes, !notes.isEmpty {
                notesSection(notes)
            }
            
            // Meal Info
            mealInfoSection
        }
    }
    
    // MARK: - Analysis Content Sections
    
    private var mealHeaderSection: some View {
        VStack(spacing: 16) {
            Text(meal.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(meal.timestamp, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private func overallScoreSection(_ analysis: FoodAnalysis) -> some View {
        VStack(spacing: 16) {
            Text("Overall Health Score")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Text("\(analysis.overallScore)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                    
                    Text("Score")
                        .font(.subheadline)
                        .foregroundColor((colorScheme == .dark ? Color.black : Color.white).opacity(0.8))
                }
                .frame(width: 120, height: 120)
                .background(scoreColor(analysis.overallScore))
                .cornerRadius(60)
                
                Text(analysis.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func healthScoresSection(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Category Scores")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                HealthScoreCard(title: "Allergies", score: analysis.healthScores.allergies)
                HealthScoreCard(title: "Anti-Inflammation", score: analysis.healthScores.antiInflammation)
                HealthScoreCard(title: "Blood Sugar", score: analysis.healthScores.bloodSugar)
                HealthScoreCard(title: "Brain Health", score: analysis.healthScores.brainHealth)
                HealthScoreCard(title: "Detox/Liver", score: analysis.healthScores.detoxLiver)
                HealthScoreCard(title: "Energy", score: analysis.healthScores.energy)
                HealthScoreCard(title: "Vision", score: analysis.healthScores.eyeHealth)
                HealthScoreCard(title: "Heart Health", score: analysis.healthScores.heartHealth)
                HealthScoreCard(title: "Immune Support", score: analysis.healthScores.immune)
                HealthScoreCard(title: "Joint Health", score: analysis.healthScores.jointHealth)
                HealthScoreCard(title: "Kidneys", score: analysis.healthScores.kidneys)
                HealthScoreCard(title: "Mood", score: analysis.healthScores.mood)
                HealthScoreCard(title: "Skin Health", score: analysis.healthScores.skin)
                HealthScoreCard(title: "Sleep Quality", score: analysis.healthScores.sleep)
                HealthScoreCard(title: "Stress Management", score: analysis.healthScores.stress)
                HealthScoreCard(title: "Weight Management", score: analysis.healthScores.weightManagement)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func nutritionSection(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                let nutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
                nutritionRow("Calories", nutrition.calories)
                nutritionRow("Protein", nutrition.protein)
                nutritionRow("Carbs", nutrition.carbohydrates)
                nutritionRow("Fat", nutrition.fat)
                nutritionRow("Fiber", nutrition.fiber)
                nutritionRow("Sugar", nutrition.sugar)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func healthBenefitsSection(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Benefits")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(analysis.keyBenefitsOrDefault, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        
                        Text(benefit)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Original Sections (for fallback)
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Meal Icon
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.white)
                        .font(.title)
                )
            
            Text(meal.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(meal.timestamp, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var healthScoreSection: some View {
        VStack(spacing: 16) {
            Text("Health Score")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Text(String(format: "%.0f", meal.healthScore))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                    
                    Text("Score")
                        .font(.subheadline)
                        .foregroundColor((colorScheme == .dark ? Color.black : Color.white).opacity(0.8))
                }
                .frame(width: 120, height: 120)
                .background(scoreColor(Int(meal.healthScore)))
                .cornerRadius(60)
                
                Text(scoreDescription(meal.healthScore))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var foodItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Food Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(meal.foods, id: \.self) { food in
                    FoodItemCard(food: food)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func healthGoalsSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Goals Met")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(meal.goalsMet, id: \.self) { goal in
                    HealthGoalCard(goal: goal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(notes)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var mealInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meal Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                InfoRow(
                    title: "Date",
                    value: meal.timestamp.formatted(date: .abbreviated, time: .omitted)
                )
                
                InfoRow(
                    title: "Time",
                    value: meal.timestamp.formatted(date: .omitted, time: .shortened)
                )
                
                InfoRow(
                    title: "Food Count",
                    value: "\(meal.foods.count) items"
                )
                
                InfoRow(
                    title: "Goals Achieved",
                    value: "\(meal.goalsMet.count) goals"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func scoreDescription(_ score: Double) -> String {
        // Score is already on 0-100 scale (matches Score screen)
        switch score {
        case 90...100:
            return "Excellent! This meal is highly beneficial for your health goals."
        case 70..<90:
            return "Great choice! This meal supports your health goals well."
        case 50..<70:
            return "Good meal with some health benefits."
        case 30..<50:
            return "This meal has limited health benefits."
        default:
            return "Consider adding more nutritious foods to your meal."
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60...79:
            return .orange
        case 40...59:
            return .yellow
        default:
            return .red
        }
    }
    
    // MARK: - Tracker-Style View Functions
    
    // Macros View (Tracker Style)
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
            // Nutrition values are already per typical serving
            if trackedMacros.contains("Kcal") {
                let calories = parseNutritionValueDouble(nutrition.calories) ?? 0.0
                let dailyCalorieTarget = getDailyCalorieTarget()
                macroProgressBar(macroName: "Kcal", currentValue: calories, gradient: LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), targetValue: dailyCalorieTarget, unit: "Kcal")
            }
            
            // Progress bars for each selected macro
            // Nutrition values are already per typical serving
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
    
    // Micros View (Tracker Style)
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
            // Nutrition values are already per typical serving
            ForEach(selectedMicronutrients, id: \.self) { name in
                let value = getMicronutrientValue(nutrition, name: name) ?? 0.0
                micronutrientRow(name: name, value: value)
            }
        }
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
}

// MARK: - Supporting Views

struct FoodItemCard: View {
    let food: String
    
    var body: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .foregroundColor(.green)
                .font(.title3)
            
            Text(food)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HealthGoalCard: View {
    let goal: String
    
    var body: some View {
        HStack {
            Image(systemName: "target")
                .foregroundColor(.green)
                .font(.title3)
            
            Text(goal)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct HealthScoreCard: View {
    let title: String
    let score: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            VStack(spacing: 4) {
                Text("\(score)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                
                Text("Score")
                    .font(.caption2)
                    .foregroundColor((colorScheme == .dark ? Color.black : Color.white).opacity(0.8))
            }
            .frame(width: 60, height: 60)
            .background(scoreColor(score))
            .cornerRadius(30)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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


#Preview {
    MealDetailsView(
        meal: TrackedMeal(
            id: UUID(),
            name: "Breakfast Bowl",
            foods: ["Oatmeal", "Blueberries", "Almonds"],
            healthScore: 8.5,
            goalsMet: ["Heart health", "Brain health"],
            timestamp: Date(),
            notes: "Great start to the day!",
            originalAnalysis: nil,
            imageHash: nil, // Preview doesn't need imageHash
            isFavorite: false
        )
    )
}
