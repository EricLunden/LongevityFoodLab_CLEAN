import SwiftUI

struct RecipeAnalysisView: View {
    let recipe: Recipe
    let analysis: FoodAnalysis
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var spoonacularService = SpoonacularService.shared
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var expandedIngredients: Set<Int> = []
    @State private var healthDetailItem: HealthDetailItem? = nil
    @State private var recipeImage: UIImage? = nil
    
    // Progressive loading state
    @State private var loadedNutritionInfo: NutritionInfo? = nil
    @State private var isLoadingNutritionInfo = false
    @State private var estimatedServingSize: String = "1 serving"
    
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
    @State private var showingMacroSelection = false
    @State private var showingMicroSelection = false
    // Parse serving size to get multiplier (e.g., "2 slices" -> 2.0, "1 cup" -> 1.0, "0.5 cups" -> 0.5)
    // REMOVED: Serving size editor functionality - nutrition now based on typical serving
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
    @State private var selectedMacros: Set<String> = []
    @State private var selectedMicronutrientsForSelection: Set<String> = []
    @State private var macroCustomDisclaimerAccepted = false
    @State private var selectedMacroForTarget: String?
    @State private var selectedMicronutrientForTarget: String?
    @State private var microCustomDisclaimerAccepted = false
    
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
        NavigationView {
            ZStack {
                // Dark mode: 100% black background, light mode: system grouped background
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                ScrollView {
                    VStack(spacing: 16) {
                            // Title
                            Text(recipe.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                                .padding(.horizontal, 20)
                            
                            // Image with Score Circle Overlay (matching meals screen)
                            if let image = recipeImage {
                                VStack(spacing: 8) {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: UIScreen.main.bounds.width - 40, height: 250)
                                            .clipped()
                                            .cornerRadius(12)
                                        
                                        // Score Circle Overlay (positioned bottom-right)
                                        scoreCircleOverlay
                                            .padding(.trailing, 16)
                                            .padding(.bottom, 16)
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else {
                                // No image - show black box (dark mode) or light gray box (light mode) with gradient icon
                                VStack(spacing: 8) {
                                    ZStack(alignment: .bottomTrailing) {
                                        TextVoiceEntryIcon(
                                            inputMethod: nil, // Recipes don't have inputMethod, default to keyboard icon
                                            width: UIScreen.main.bounds.width - 40,
                                            height: 250,
                                            cornerRadius: 12
                                        )
                                        .frame(width: UIScreen.main.bounds.width - 40, height: 250)
                                        .cornerRadius(12)
                                        .clipped()
                                        
                                        // Score Circle Overlay (positioned bottom-right)
                                        scoreCircleOverlay
                                            .padding(.trailing, 16)
                                            .padding(.bottom, 16)
                                    }
                                }
                                .padding(.horizontal, 20)
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
                            keyBenefitsDropdown
                            
                            // Latest Health Goals Research grid
                            healthScoresGrid
                            
                            // Ingredients Analysis dropdown
                            ingredientsAnalysisDropdown
                            
                            // Your Macronutrients dropdown
                            macrosDropdownTrackerStyle
                            
                            // Your Micronutrients dropdown
                            microsDropdownTrackerStyle
                            
                            // Quality & Source dropdown
                            VStack {
                                QualitySourceView(foodName: recipe.title)
                            }
                            .padding(.horizontal, 20)
                            
                            // Best Practices dropdown (if available)
                            if !analysis.bestPreparationOrDefault.isEmpty && !isHealthierChoicesText(analysis.bestPreparationOrDefault) {
                                bestPracticesDropdown
                            }
                            
                            // Educational disclaimer - always shown at bottom
                            HealthGoalsDisclaimerView()
                        }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Load selected macros/micros
                if selectedMacros.isEmpty {
                    selectedMacros = Set(healthProfileManager.getTrackedMacros())
                }
                if selectedMicronutrientsForSelection.isEmpty {
                    selectedMicronutrientsForSelection = Set(healthProfileManager.getTrackedMicronutrients())
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAnalysis()
                    }
                    .foregroundColor(.blue)
                }
            }
            .sheet(item: $healthDetailItem) { item in
                HealthDetailView(
                    category: item.category,
                    score: item.score,
                    foodName: recipe.title,
                    longevityScore: analysis.overallScore,
                    isMealAnalysis: false,
                    scanType: analysis.scanType,
                    ingredients: analysis.ingredientsOrDefault
                )
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
            .onAppear {
                loadRecipeImage()
                
                // Load selected macros/micros
                if selectedMacros.isEmpty {
                    selectedMacros = Set(healthProfileManager.getTrackedMacros())
                }
                if selectedMicronutrientsForSelection.isEmpty {
                    selectedMicronutrientsForSelection = Set(healthProfileManager.getTrackedMicronutrients())
                }
            }
        }
    }
    
    // MARK: - Image Loading
    
    private func loadRecipeImage() {
        // Check if recipe has an image URL
        guard let imageUrlString = recipe.image, !imageUrlString.isEmpty else {
            return
        }
        
        // Fix malformed URLs that start with //
        let fixedImageUrl = imageUrlString.hasPrefix("//") ? "https:" + imageUrlString : imageUrlString
        
        // Use RecipeImageCacheManager to load and cache the image
        let cacheManager = RecipeImageCacheManager.shared
        Task {
            if let cachedImage = await cacheManager.loadImage(from: fixedImageUrl) {
                await MainActor.run {
                    self.recipeImage = cachedImage
                }
            } else {
                print("RecipeAnalysisView: Failed to load image from cache for URL: \(fixedImageUrl)")
            }
        }
    }
    
    // MARK: - Score Circle
    
    // Score circle overlay for image (positioned bottom-right like meals screen)
    private var scoreCircleOverlay: some View {
        ZStack {
            // Background circle with gradient fill
            Circle()
                .fill(scoreGradient(analysis.overallScore))
                .frame(width: 90, height: 90)
                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            
            // Score number and label (white text)
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
    
    // Score circle standalone (fallback when no image)
    private var scoreCircleRecipeStyle: some View {
        scoreCircleOverlay
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
    
    // MARK: - Dropdown Components
    
    private var keyBenefitsDropdown: some View {
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
                .padding(20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
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
    private func mapProfileGoalToCategory(_ goal: String) -> (category: String, icon: String, label: String, score: Int)? {
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
    
    private var ingredientsAnalysisDropdown: some View {
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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(analysis.ingredientsOrDefault.enumerated()), id: \.offset) { index, ingredient in
                        ingredientRow(ingredient, index: index)
                    }
                }
                .padding(20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
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
    
    // MARK: - Your Macronutrients Dropdown (Tracker Style)
    private var macrosDropdownTrackerStyle: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMacrosExpanded.toggle()
                        if isMacrosExpanded {
                            let currentNutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
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
        .padding(.horizontal, 20)
    }
    
    // MARK: - Your Micronutrients Dropdown (Tracker Style)
    private var microsDropdownTrackerStyle: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMicrosExpanded.toggle()
                        if isMicrosExpanded {
                            let currentNutrition = loadedNutritionInfo ?? analysis.nutritionInfoOrDefault
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
        .padding(.horizontal, 20)
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
                nutritionRow("Carbohydrates", nutrition.carbohydrates)
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
                    Text(analysis.bestPreparationOrDefault)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Functions
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
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
    
    private func isHealthierChoicesText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("healthier choices") || lowercased.contains("alternatives") || lowercased.contains("better options")
    }
    
    // MARK: - Cache Update Function
    
    private func updateCachedAnalysisWithNutrition(_ nutrition: NutritionInfo) {
        // Find the cached entry for this recipe
        if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == recipe.title &&
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
                suggestions: cachedEntry.fullAnalysis.suggestions
            )
            
            // Update the cached entry with the new analysis
            foodCacheManager.cacheAnalysis(updatedAnalysis, imageHash: cachedEntry.imageHash, scanType: cachedEntry.scanType, inputMethod: cachedEntry.inputMethod)
            
            // Also update the recipe's fullAnalysisData so meals created from this recipe have the nutrition
            var updatedRecipe = recipe
            if let jsonData = try? JSONEncoder().encode(updatedAnalysis),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                updatedRecipe.fullAnalysisData = jsonString
                // Save the updated recipe
                Task {
                    do {
                        try await recipeManager.saveRecipe(updatedRecipe)
                        print("✅ RecipeAnalysisView: Updated recipe.fullAnalysisData with nutrition info for \(recipe.title)")
                    } catch {
                        print("⚠️ RecipeAnalysisView: Failed to save updated recipe with nutrition: \(error)")
                    }
                }
            }
            
            print("✅ RecipeAnalysisView: Updated cached analysis with nutrition info for \(recipe.title)")
            print("   Calcium: \(nutrition.calcium ?? "nil")")
        } else {
            print("⚠️ RecipeAnalysisView: Could not find cached entry to update for \(recipe.title)")
        }
    }
    
    // MARK: - Save Function
    
    private func saveAnalysis() {
        // Update recipe with analysis results (including full analysis JSON)
        var updatedRecipe = recipe
        updatedRecipe.longevityScore = analysis.overallScore
        updatedRecipe.analysisReport = analysis.summary
        updatedRecipe.analysisType = .full
        
        // Encode full FoodAnalysis as JSON and save
        if let jsonData = try? JSONEncoder().encode(analysis),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            updatedRecipe.fullAnalysisData = jsonString
        }
        
        Task {
            do {
                try await recipeManager.saveRecipe(updatedRecipe)
                // Reload recipes to ensure the shared instance is updated
                await recipeManager.loadRecipes()
                print("RecipeAnalysisView: Saved analysis results with full analysis data for recipe: \(recipe.title)")
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("RecipeAnalysisView: Failed to save analysis: \(error)")
            }
        }
    }
    
    // MARK: - Nutrition Loading Functions
    
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
        
        // For recipes/meals, allow higher calories (up to 2000)
        // For single foods, calories should be reasonable (< 500)
        let maxCalories = isMeal ? 2000 : 500
        
        if calories > maxCalories {
            print("⚠️ RecipeAnalysisView: Nutrition validation failed - Calories (\(calories)) exceeds reasonable limit (\(maxCalories)) for \(isMeal ? "recipe/meal" : "single food")")
            return false
        }
        
        return true
    }
    
    private func loadNutritionInfo() {
        // Step 1: If already loaded with valid data (in-memory cache), don't reload
        if let loaded = loadedNutritionInfo, 
           isNutritionInfoValid(loaded),
           isNutritionReasonable(loaded, isMeal: true) {
            print("ℹ️ RecipeAnalysisView: Nutrition already loaded and valid (in-memory), skipping")
            return
        } else if let loaded = loadedNutritionInfo, isNutritionInfoValid(loaded) {
            print("⚠️ RecipeAnalysisView: In-memory nutrition exists but is unreasonable, re-fetching from USDA...")
        }
        
        // Step 2: Check if current analysis has valid nutrition info
        if let currentNutrition = analysis.nutritionInfo, 
           isNutritionInfoValid(currentNutrition),
           isNutritionReasonable(currentNutrition, isMeal: true) {
            print("ℹ️ RecipeAnalysisView: Current analysis has valid nutrition info, using it")
            loadedNutritionInfo = currentNutrition
            return
        } else if let currentNutrition = analysis.nutritionInfo, isNutritionInfoValid(currentNutrition) {
            print("⚠️ RecipeAnalysisView: Current analysis nutrition exists but is unreasonable, re-fetching from USDA...")
        }
        
        // Step 2.5: Check if recipe has saved analysis data with nutrition
        if let fullAnalysisData = recipe.fullAnalysisData,
           let jsonData = fullAnalysisData.data(using: .utf8),
           let savedAnalysis = try? JSONDecoder().decode(FoodAnalysis.self, from: jsonData),
           let savedNutrition = savedAnalysis.nutritionInfo,
           isNutritionInfoValid(savedNutrition),
           isNutritionReasonable(savedNutrition, isMeal: true) {
            print("✅ RecipeAnalysisView: Found valid nutrition info in recipe's saved analysis, using it (no API call)")
            loadedNutritionInfo = savedNutrition
            return
        } else if let fullAnalysisData = recipe.fullAnalysisData,
                  let jsonData = fullAnalysisData.data(using: .utf8),
                  let savedAnalysis = try? JSONDecoder().decode(FoodAnalysis.self, from: jsonData),
                  let savedNutrition = savedAnalysis.nutritionInfo,
                  isNutritionInfoValid(savedNutrition) {
            print("⚠️ RecipeAnalysisView: Saved recipe analysis nutrition exists but is unreasonable, re-fetching from USDA...")
        }
        
        // Step 3: Check persistent cache (FoodCacheManager) for cached nutrition info
        // Search cache by recipe title (food name)
        if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == recipe.title &&
            entry.fullAnalysis.overallScore == analysis.overallScore
        }) {
            if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, 
               isNutritionInfoValid(cachedNutrition),
               isNutritionReasonable(cachedNutrition, isMeal: true) {
                print("✅ RecipeAnalysisView: Found valid nutrition info in cache by recipe title, using cache (no API call)")
                loadedNutritionInfo = cachedNutrition
                return
            } else if let cachedNutrition = cachedEntry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                print("⚠️ RecipeAnalysisView: Cache nutrition by recipe title exists but is unreasonable, re-fetching from USDA...")
            }
        }
        
        // Step 4: Fallback to name matching (for recipes with similar names)
        let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
            let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
            let recipeName = recipe.title.lowercased().trimmingCharacters(in: .whitespaces)
            return entryName == recipeName ||
                   entryName.contains(recipeName) ||
                   recipeName.contains(entryName)
        }
        
        if let matchingEntry = matchingEntries.sorted(by: { $0.analysisDate > $1.analysisDate }).first {
            if let cachedNutrition = matchingEntry.fullAnalysis.nutritionInfo, 
               isNutritionInfoValid(cachedNutrition),
               isNutritionReasonable(cachedNutrition, isMeal: true) {
                print("✅ RecipeAnalysisView: Found valid nutrition info in cache by name match, using cache (no API call)")
                loadedNutritionInfo = cachedNutrition
                return
            } else if let cachedNutrition = matchingEntry.fullAnalysis.nutritionInfo, isNutritionInfoValid(cachedNutrition) {
                print("⚠️ RecipeAnalysisView: Cache nutrition by name match exists but is unreasonable, re-fetching from USDA...")
            }
        }
        
        // Step 5: No cache found - make API call
        print("🚀 RecipeAnalysisView: No cached nutrition found, starting API load for recipe '\(recipe.title)'")
        isLoadingNutritionInfo = true
        
        Task {
            let startTime = Date()
            let isFallbackServings = recipe.servingsSource?.lowercased() == "fallback"
            let nutritionSourceFlag = recipe.nutritionSource?.lowercased()
            let ingredientSourceFlag = recipe.ingredientSource?.lowercased()
            
            if isFallbackServings || nutritionSourceFlag == "none" || ingredientSourceFlag == "none" {
                print("⚠️ RecipeAnalysisView: Low-confidence provenance recipe=\(recipe.id) servings_source=\(recipe.servingsSource ?? "unknown") nutrition_source=\(recipe.nutritionSource ?? "unknown") ingredient_source=\(recipe.ingredientSource ?? "unknown")")
            }
            do {
                // Extract ingredient names from recipe
                let ingredientNames = extractIngredientNames()
                
                if ingredientNames.isEmpty {
                    print("⚠️ RecipeAnalysisView: No ingredients found, falling back to AI")
                    let nutrition = try await fetchNutritionInfoFromAI()
                    await MainActor.run {
                        loadedNutritionInfo = nutrition
                        isLoadingNutritionInfo = false
                        estimatedServingSize = estimateServingSize()
                        
                        // Update cached analysis with nutrition info if found in cache
                        updateCachedAnalysisWithNutrition(nutrition)
                    }
                } else {
                    // Priority 1: Check if recipe has extracted nutrition from source page (and nutrition_source allows it)
                    if let extractedNutrition = recipe.extractedNutrition, nutritionSourceFlag == "page" || recipe.nutritionSource == nil {
                        print("✅ RecipeAnalysisView: Using nutrition extracted from recipe source")
                        print("   Calories: \(extractedNutrition.calories)")
                        print("   Protein: \(extractedNutrition.protein)")
                        print("   Fat: \(extractedNutrition.fat)")
                        print("   Calcium: \(extractedNutrition.calcium ?? "nil")")
                        print("   Full nutrition dict: calories=\(extractedNutrition.calories), protein=\(extractedNutrition.protein), calcium=\(extractedNutrition.calcium ?? "nil")")
                        await MainActor.run {
                            loadedNutritionInfo = extractedNutrition
                            isLoadingNutritionInfo = false
                            estimatedServingSize = estimateServingSize()
                            
                            // Update cached analysis with nutrition info if found in cache
                            updateCachedAnalysisWithNutrition(extractedNutrition)
                            
                            print("✅ RecipeAnalysisView: Loaded extracted nutrition in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
                        }
                        return  // Don't calculate, use extracted nutrition
                    } else if nutritionSourceFlag == "page" && recipe.extractedNutrition == nil {
                        print("⚠️ RecipeAnalysisView: nutrition_source=page but no extractedNutrition present; proceeding with ingredient-based calculation")
                    }
                    
                    print("🔍 RecipeAnalysisView: Found \(ingredientNames.count) ingredients: \(ingredientNames.joined(separator: ", "))")
                    print("⚠️ RecipeAnalysisView: No extracted nutrition found, calculating from ingredients...")
                    // Use meal aggregation method for recipes (same as foods and meals)
                    if let nutrition = try await aggregateNutritionForRecipeUsingMealMethod(ingredientNames: ingredientNames) {
                        await MainActor.run {
                            loadedNutritionInfo = nutrition
                            isLoadingNutritionInfo = false
                            estimatedServingSize = estimateServingSize()
                            
                            // Update cached analysis with nutrition info if found in cache
                            updateCachedAnalysisWithNutrition(nutrition)
                            
                            print("✅ RecipeAnalysisView: Loaded nutrition from ingredients in \(String(format: "%.2f", Date().timeIntervalSince(startTime)))s")
                        }
                    } else {
                        // Fallback to AI if aggregation fails
                        print("⚠️ RecipeAnalysisView: Aggregation failed, falling back to AI")
                        let nutrition = try await fetchNutritionInfoFromAI()
                        await MainActor.run {
                            loadedNutritionInfo = nutrition
                            isLoadingNutritionInfo = false
                            estimatedServingSize = estimateServingSize()
                        }
                    }
                }
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                print("❌ RecipeAnalysisView: Failed to load nutrition info after \(String(format: "%.2f", duration))s")
                print("❌ RecipeAnalysisView: Error: \(error.localizedDescription)")
                await MainActor.run {
                    // Fallback to default values if API fails
                    loadedNutritionInfo = NutritionInfo(
                        calories: "N/A",
                        protein: "N/A",
                        carbohydrates: "N/A",
                        fat: "N/A",
                        sugar: "N/A",
                        fiber: "N/A",
                        sodium: "N/A",
                        saturatedFat: nil
                    )
                    isLoadingNutritionInfo = false
                    estimatedServingSize = "1 serving"
                    print("⚠️ RecipeAnalysisView: Using fallback N/A values")
                }
            }
        }
    }
    
    // Extract ingredient names from recipe
    private func extractIngredientNames() -> [String] {
        var ingredientNames: [String] = []
        
        // First try structured ingredients
        if !recipe.ingredients.isEmpty {
            for group in recipe.ingredients {
                for ingredient in group.ingredients {
                    // Clean ingredient name (remove common prefixes/suffixes)
                    let cleanedName = ingredient.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: ",.*", with: "", options: .regularExpression) // Remove notes after comma
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanedName.isEmpty && cleanedName.count > 2 {
                        ingredientNames.append(cleanedName)
                    }
                }
            }
        }
        
        // Fallback to ingredientsText if structured ingredients are empty
        if ingredientNames.isEmpty, let ingredientsText = recipe.ingredientsText {
            // Parse ingredients from text (one per line or comma-separated)
            let lines = ingredientsText.components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            for line in lines {
                // Try to extract ingredient name (remove amounts, units, etc.)
                let cleaned = line
                    .replacingOccurrences(of: "^\\d+[\\s/\\d]*", with: "", options: .regularExpression) // Remove leading numbers/fractions
                    .replacingOccurrences(of: "^(cup|cups|tbsp|tsp|oz|lb|g|kg|ml|l|tablespoon|teaspoon|ounce|pound|gram|kilogram|milliliter|liter)\\s+", with: "", options: [.regularExpression, .caseInsensitive]) // Remove units
                    .replacingOccurrences(of: ",.*", with: "", options: .regularExpression) // Remove notes after comma
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleaned.isEmpty && cleaned.count > 2 {
                    ingredientNames.append(cleaned)
                }
            }
        }
        
        return ingredientNames
    }
    
    // Estimate serving size based on recipe type
    private func estimateServingSize() -> String {
        let title = recipe.title.lowercased()
        let description = recipe.description.lowercased()
        let combined = "\(title) \(description)"
        
        // Analyze recipe type to estimate serving size
        if combined.contains("soup") || combined.contains("stew") || combined.contains("chili") {
            return "1 cup"
        } else if combined.contains("salad") {
            return "1 cup"
        } else if combined.contains("cake") || combined.contains("pie") || combined.contains("bread") || combined.contains("muffin") || combined.contains("cookie") {
            return "1 piece"
        } else if combined.contains("pizza") {
            return "1 slice"
        } else if combined.contains("pasta") || combined.contains("noodle") {
            return "1 cup"
        } else if combined.contains("rice") || combined.contains("grain") {
            return "1/2 cup"
        } else if combined.contains("sauce") || combined.contains("dressing") || combined.contains("dip") {
            return "2 tablespoons"
        } else if combined.contains("smoothie") || combined.contains("shake") {
            return "1 cup"
        } else if combined.contains("side") || combined.contains("side dish") {
            return "1/2 cup"
        } else {
            // Default: estimate based on total ingredient count/volume
            let ingredientCount = recipe.allIngredients.count
            if ingredientCount <= 3 {
                return "1 serving"
            } else if ingredientCount <= 6 {
                return "1 cup"
            } else {
                return "1 serving"
            }
        }
    }
    
    // Aggregate nutrition from recipe ingredients using actual quantities
    private func aggregateNutritionForRecipeUsingMealMethod(ingredientNames: [String]) async throws -> NutritionInfo? {
        print("🔍 RecipeAnalysisView: Aggregating nutrition for recipe with \(ingredientNames.count) ingredients")
        let isFallbackServings = recipe.servingsSource?.lowercased() == "fallback"
        
        // DEBUG: Log recipe details for troubleshooting
        print("📊 NUTRITION CALCULATION DEBUG:")
        print("   Recipe: \(recipe.title)")
        print("   Servings (from recipe object): \(recipe.servings)")
        print("   Ingredients count: \(ingredientNames.count)")
        
        // Step 1: Try to extract actual ingredient quantities from recipe
        let ingredientsWithQuantities = extractIngredientsWithQuantities()
        
        // Step 2: If we have actual quantities and servings > 1, use them
        if !ingredientsWithQuantities.isEmpty && recipe.servings > 1 {
            print("✅ RecipeAnalysisView: Using actual ingredient quantities (recipe serves \(recipe.servings))")
            if let nutrition = try await aggregateNutritionFromActualQuantities(ingredients: ingredientsWithQuantities) {
                // DEBUG: Log aggregated totals before division
                let caloriesStr = nutrition.calories
                if let calories = Double(caloriesStr.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespaces)) {
                    print("📊 NUTRITION CALCULATION DEBUG:")
                    print("   Using ACTUAL QUANTITIES path")
                    print("   Aggregated TOTAL calories (before division): \(Int(calories))")
                    print("   Recipe servings: \(recipe.servings)")
                    print("   Expected per-serving calories: ~\(Int(calories / Double(recipe.servings)))")
                }
                if isFallbackServings {
                    print("⚠️ RecipeAnalysisView: Skipped per-serving division due to fallback servings")
                    return nutrition
                }
                // Divide by servings to get per-serving nutrition
                return scaleNutritionByServings(nutrition, servings: recipe.servings)
            } else {
                print("⚠️ RecipeAnalysisView: Failed to aggregate from actual quantities, falling back to AI estimation")
            }
        } else if !ingredientsWithQuantities.isEmpty && recipe.servings == 1 {
            print("✅ RecipeAnalysisView: Using actual ingredient quantities (servings = 1, no division needed)")
            if let nutrition = try await aggregateNutritionFromActualQuantities(ingredients: ingredientsWithQuantities) {
                return nutrition
            } else {
                print("⚠️ RecipeAnalysisView: Failed to aggregate from actual quantities, falling back to AI estimation")
            }
        } else {
            print("⚠️ RecipeAnalysisView: No actual quantities found or servings not parsed, using AI estimation")
        }
        
        // Step 3: Fallback to AI estimation (existing system)
        let componentsWithAmounts: [(name: String, amountGrams: Double)]
        do {
            componentsWithAmounts = try await estimateIngredientAmountsPerServing(ingredientNames: ingredientNames)
        } catch {
            print("⚠️ RecipeAnalysisView: Failed to estimate amounts, using default 100g per ingredient")
            if let nutrition = try await aggregateWithDefaultAmounts(ingredientNames: ingredientNames) {
                // Divide by servings since default amounts are total recipe amounts
                if recipe.servings > 1 && !isFallbackServings {
                    print("✅ RecipeAnalysisView: Dividing default-amount nutrition by \(recipe.servings) servings")
                    return scaleNutritionByServings(nutrition, servings: recipe.servings)
                } else if recipe.servings > 1 && isFallbackServings {
                    print("⚠️ RecipeAnalysisView: Skipped per-serving division due to fallback servings")
                }
                return nutrition
            }
            return nil
        }
        
        // Step 4: Aggregate nutrition using AI-estimated amounts (parallelized)
        var aggregator = NutritionAggregator()
        var foundAny = false
        var foundCount = 0
        
        // Parallelize all ingredient lookups
        try await withThrowingTaskGroup(of: (Int, String, NutritionInfo?).self) { group in
            for (index, component) in componentsWithAmounts.enumerated() {
                group.addTask {
                    print("🔍 RecipeAnalysisView: Looking up ingredient \(index + 1)/\(componentsWithAmounts.count): '\(component.name)' at \(Int(component.amountGrams))g")
                    do {
                        let nutrition = try await getNutritionForIngredientAtAmount(foodName: component.name, amount: component.amountGrams)
                        return (index, component.name, nutrition)
                    } catch {
                        print("❌ RecipeAnalysisView: Error looking up '\(component.name)': \(error.localizedDescription)")
                        return (index, component.name, nil)
                    }
                }
            }
            
            // Collect all results
            var results: [(Int, String, NutritionInfo?)] = []
            for try await result in group {
                results.append(result)
            }
            
            // Process results in order
            for (index, name, nutrition) in results.sorted(by: { $0.0 < $1.0 }) {
                if let nutrition = nutrition {
                    foundAny = true
                    foundCount += 1
                    print("✅ RecipeAnalysisView: Found nutrition for '\(name)' at \(Int(componentsWithAmounts[index].amountGrams))g")
                    aggregator.add(nutrition)
                } else {
                    print("⚠️ RecipeAnalysisView: No nutrition found for '\(name)'")
                }
            }
        }
        
        print("📊 RecipeAnalysisView: Found nutrition for \(foundCount)/\(componentsWithAmounts.count) ingredients")
        
        guard foundAny else {
            print("⚠️ RecipeAnalysisView: No nutrition data found for any ingredient")
            return nil
        }
        
        let result = aggregator.toNutritionInfo()
        
        // DEBUG: Log aggregated totals before division
        let caloriesStr = result.calories
        if let calories = Double(caloriesStr.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespaces)) {
            print("📊 NUTRITION CALCULATION DEBUG:")
            print("   Aggregated TOTAL calories (before division): \(Int(calories))")
            print("   Recipe servings: \(recipe.servings)")
            if recipe.servings > 1 {
                print("   Expected per-serving calories: ~\(Int(calories / Double(recipe.servings)))")
            }
        }
        
        print("✅ RecipeAnalysisView: Successfully aggregated nutrition with AI-estimated amounts")
        
        // Divide by servings to get per-serving nutrition (AI estimates TOTAL recipe amounts)
        if recipe.servings > 1 {
            print("✅ RecipeAnalysisView: Dividing AI-estimated nutrition by \(recipe.servings) servings")
            return scaleNutritionByServings(result, servings: recipe.servings)
        }
        return result
    }
    
    /// Estimate ingredient amounts for TOTAL recipe using AI
    private func estimateIngredientAmountsPerServing(ingredientNames: [String]) async throws -> [(name: String, amountGrams: Double)] {
        let prompt = """
        Estimate the TOTAL amount in grams of each ingredient for the ENTIRE recipe (all servings combined, not per-serving).
        
        Recipe: \(recipe.title)
        Ingredients: \(ingredientNames.joined(separator: ", "))
        Recipe serves: \(recipe.servings) servings
        
        Estimate the TOTAL amount of each ingredient needed for the entire recipe (all \(recipe.servings) servings combined).
        Return a JSON array with ingredient names and their estimated TOTAL weight in grams for the whole recipe.
        
        Example for "Apple Pie" (serves 8):
        [{"name": "apples", "amountGrams": 640}, {"name": "flour", "amountGrams": 320}, {"name": "sugar", "amountGrams": 200}, {"name": "butter", "amountGrams": 120}]
        Note: These are TOTAL amounts for all 8 servings, not per-serving.
        
        Return ONLY this JSON format (no markdown, no explanation):
        [{"name": "ingredient1", "amountGrams": number}, {"name": "ingredient2", "amountGrams": number}]
        """
        
        let jsonString = try await AIService.shared.makeOpenAIRequestAsync(prompt: prompt)
        
        // Clean JSON string
        var cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: .newlines)
            var jsonLines = lines
            if let firstLine = jsonLines.first, firstLine.contains("json") {
                jsonLines.removeFirst()
            }
            if let lastLine = jsonLines.last, lastLine == "```" {
                jsonLines.removeLast()
            }
            cleaned = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let data = cleaned.data(using: .utf8),
              let componentsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw NSError(domain: "Invalid JSON", code: 0, userInfo: nil)
        }
        
        var components: [(name: String, amountGrams: Double)] = []
        for item in componentsArray {
            if let name = item["name"] as? String,
               let amount = item["amountGrams"] as? Double {
                components.append((name: name, amountGrams: amount))
            }
        }
        
        return components
    }
    
    /// Fallback: Aggregate with default 100g per ingredient
    private func aggregateWithDefaultAmounts(ingredientNames: [String]) async throws -> NutritionInfo? {
        var aggregator = NutritionAggregator()
        var foundAny = false
        
        for ingredientName in ingredientNames {
            if let nutrition = try await getNutritionForSingleIngredient(foodName: ingredientName) {
                foundAny = true
                aggregator.add(nutrition)
            }
        }
        
        guard foundAny else { return nil }
        return aggregator.toNutritionInfo()
    }
    
    /// Get nutrition for an ingredient at a specific amount
    private func getNutritionForIngredientAtAmount(foodName: String, amount: Double) async throws -> NutritionInfo? {
        // Try tiered lookup first (USDA → Spoonacular → AI)
        let context = NutritionNormalizationContext(
            canonicalFoodName: foodName,
            quantity: amount,
            unit: "g",
            gramsKnown: true,
            perServingProvided: nil,
            per100gProvided: nil,
            servings: recipe.servings,
            ingredientNames: nil,
            timestamp: nil,
            imageHash: nil,
            inputMethod: nil
        )
        if let nutrition = try await NutritionNormalizationPipeline.shared.getNutritionForFood(foodName, amount: amount, unit: "g", context: context) {
            print("✅ RecipeAnalysisView: Found nutrition via tiered lookup at \(Int(amount))g")
            return nutrition
        }
        
        // Fallback to direct Spoonacular lookup
        do {
            guard let nutrition = try await spoonacularService.getNutritionForFood(foodName, amount: amount, unit: "g") else {
                return nil
            }
            return convertSpoonacularNutritionToNutritionInfo(nutrition)
        } catch {
            throw error
        }
    }
    
    // REMOVED: determineRecipeType and scaleNutritionInfo functions
    // Using aggregated nutrition values directly for accuracy (same as meals)
    
    // Get nutrition for a single ingredient
    private func getNutritionForSingleIngredient(foodName: String) async throws -> NutritionInfo? {
        print("🔍 RecipeAnalysisView: Getting nutrition for '\(foodName)'")
        
        // Try tiered lookup first (USDA → Spoonacular → AI)
        let context = NutritionNormalizationContext(
            canonicalFoodName: foodName,
            quantity: nil,
            unit: nil,
            gramsKnown: nil,
            perServingProvided: nil,
            per100gProvided: nil,
            servings: recipe.servings,
            ingredientNames: extractIngredientNames(),
            timestamp: nil,
            imageHash: nil,
            inputMethod: nil
        )
        if let nutrition = try await NutritionNormalizationPipeline.shared.getNutritionForFood(foodName, context: context) {
            print("✅ RecipeAnalysisView: Found nutrition via tiered lookup")
            return nutrition
        }
        
        // Fallback to direct Spoonacular lookup
        do {
            guard let nutrition = try await spoonacularService.getNutritionForFood(foodName) else {
                print("⚠️ RecipeAnalysisView: Spoonacular returned nil for '\(foodName)'")
                return nil
            }
            
            print("✅ RecipeAnalysisView: Received Spoonacular nutrition data for '\(foodName)'")
            let converted = convertSpoonacularNutritionToNutritionInfo(nutrition)
            print("✅ RecipeAnalysisView: Converted nutrition - Calories: \(converted.calories), Protein: \(converted.protein)")
            return converted
        } catch {
            print("❌ RecipeAnalysisView: Error getting nutrition for '\(foodName)': \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Actual Quantity-Based Nutrition Calculation
    
    /// Extract ingredients with their actual quantities from recipe
    private func extractIngredientsWithQuantities() -> [(name: String, amount: String, unit: String?)] {
        var ingredients: [(name: String, amount: String, unit: String?)] = []
        
        // Extract from structured ingredients
        if !recipe.ingredients.isEmpty {
            for group in recipe.ingredients {
                for ingredient in group.ingredients {
                    let cleanedName = ingredient.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: ",.*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanedName.isEmpty && !ingredient.amount.isEmpty {
                        ingredients.append((name: cleanedName, amount: ingredient.amount, unit: ingredient.unit))
                    }
                }
            }
        }
        
        return ingredients
    }
    
    /// Aggregate nutrition from actual ingredient quantities
    private func aggregateNutritionFromActualQuantities(ingredients: [(name: String, amount: String, unit: String?)]) async throws -> NutritionInfo? {
        print("🔍 RecipeAnalysisView: Aggregating nutrition from \(ingredients.count) ingredients with actual quantities")
        
        var aggregator = NutritionAggregator()
        var foundAny = false
        var foundCount = 0
        
        // Prepare all ingredient lookups (parse amounts and convert units first)
        var lookupTasks: [(Int, String, Double?, String?)] = []
        for (index, ingredient) in ingredients.enumerated() {
            // Parse amount to numeric value
            guard let quantity = parseIngredientAmount(ingredient.amount) else {
                print("⚠️ RecipeAnalysisView: Could not parse amount '\(ingredient.amount)' for '\(ingredient.name)'")
                continue
            }
            
            // Convert unit to grams
            if let unit = ingredient.unit, !unit.isEmpty {
                if let grams = convertUnitToGrams(quantity: quantity, unit: unit, ingredientName: ingredient.name) {
                    lookupTasks.append((index, ingredient.name, grams, nil))
                } else {
                    // Try with original unit (Spoonacular)
                    lookupTasks.append((index, ingredient.name, quantity, unit))
                }
            } else {
                // No unit specified - try with quantity as-is
                lookupTasks.append((index, ingredient.name, quantity, ""))
            }
        }
        
        // Parallelize all ingredient lookups
        try await withThrowingTaskGroup(of: (Int, String, NutritionInfo?).self) { group in
            for (index, name, amountGrams, unit) in lookupTasks {
                group.addTask {
                    print("🔍 RecipeAnalysisView: Looking up ingredient \(index + 1)/\(ingredients.count): '\(name)'")
                    do {
                        let nutrition: NutritionInfo?
                        if let unit = unit {
                            // Use unit-based lookup
                            nutrition = try await getNutritionForIngredientWithUnit(foodName: name, amount: amountGrams ?? 0, unit: unit)
                        } else if let grams = amountGrams {
                            // Use gram-based lookup
                            nutrition = try await getNutritionForIngredientAtAmount(foodName: name, amount: grams)
                        } else {
                            nutrition = nil
                        }
                        return (index, name, nutrition)
                    } catch {
                        print("❌ RecipeAnalysisView: Error looking up '\(name)': \(error.localizedDescription)")
                        return (index, name, nil)
                    }
                }
            }
            
            // Collect all results
            var results: [(Int, String, NutritionInfo?)] = []
            for try await result in group {
                results.append(result)
            }
            
            // Process results in order
            for (index, name, nutrition) in results.sorted(by: { $0.0 < $1.0 }) {
                if let nutrition = nutrition {
                    foundAny = true
                    foundCount += 1
                    if let amountGrams = lookupTasks.first(where: { $0.0 == index })?.2 {
                        print("✅ RecipeAnalysisView: Found nutrition for '\(name)' at \(Int(amountGrams))g")
                    } else {
                        print("✅ RecipeAnalysisView: Found nutrition for '\(name)'")
                    }
                    aggregator.add(nutrition)
                } else {
                    print("⚠️ RecipeAnalysisView: No nutrition found for '\(name)'")
                }
            }
        }
        
        print("📊 RecipeAnalysisView: Found nutrition for \(foundCount)/\(ingredients.count) ingredients")
        
        guard foundAny else {
            print("⚠️ RecipeAnalysisView: No nutrition data found for any ingredient")
            return nil
        }
        
        print("✅ RecipeAnalysisView: Successfully aggregated nutrition from actual quantities")
        return aggregator.toNutritionInfo()
    }
    
    /// Parse ingredient amount string to numeric value (handles fractions, mixed numbers)
    private func parseIngredientAmount(_ amountString: String) -> Double? {
        let cleaned = amountString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle Unicode fractions
        let unicodeFractions: [String: Double] = [
            "½": 0.5, "⅓": 0.333333, "⅔": 0.666667, "¼": 0.25, "¾": 0.75,
            "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8, "⅙": 0.166667,
            "⅚": 0.833333, "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875
        ]
        
        // Check for Unicode fraction
        for (unicode, value) in unicodeFractions {
            if cleaned.contains(unicode) {
                let wholePart = cleaned.replacingOccurrences(of: unicode, with: "")
                    .trimmingCharacters(in: .whitespaces)
                let whole = Double(wholePart) ?? 0
                return whole + value
            }
        }
        
        // Handle mixed numbers like "1 1/2" or "2 2/3"
        if cleaned.contains(" ") {
            let parts = cleaned.split(separator: " ")
            if parts.count == 2, let whole = Double(parts[0]) {
                let fracPart = String(parts[1])
                if fracPart.contains("/") {
                    let fracParts = fracPart.split(separator: "/")
                    if fracParts.count == 2, let num = Double(fracParts[0]), let den = Double(fracParts[1]), den != 0 {
                        return whole + (num / den)
                    }
                }
                return whole
            }
        }
        
        // Handle simple fractions like "1/2" or "2/3"
        if cleaned.contains("/") && !cleaned.contains(" ") {
            let parts = cleaned.split(separator: "/")
            if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
                return num / den
            }
        }
        
        // Simple number
        return Double(cleaned)
    }
    
    /// Convert unit to grams
    private func convertUnitToGrams(quantity: Double, unit: String, ingredientName: String) -> Double? {
        let unitLower = unit.lowercased()
        
        // Weight units
        switch unitLower {
        case "oz", "ounce", "ounces":
            return quantity * 28.35
        case "lb", "pound", "pounds":
            return quantity * 453.59
        case "g", "gram", "grams":
            return quantity
        case "kg", "kilogram", "kilograms":
            return quantity * 1000
        default:
            break
        }
        
        // Volume units - convert to grams based on ingredient type
        let ingredientLower = ingredientName.lowercased()
        
        switch unitLower {
        case "cup", "cups":
            return convertCupToGrams(quantity: quantity, ingredient: ingredientLower)
        case "tbsp", "tablespoon", "tablespoons":
            return convertCupToGrams(quantity: quantity / 16.0, ingredient: ingredientLower) // 1 cup = 16 tbsp
        case "tsp", "teaspoon", "teaspoons":
            return convertCupToGrams(quantity: quantity / 48.0, ingredient: ingredientLower) // 1 cup = 48 tsp
        case "fl oz", "fluid ounce", "fluid ounces":
            // For liquids, 1 fl oz ≈ 30ml ≈ 30g (for water-like liquids)
            // For other ingredients, use cup conversion
            if isLiquidIngredient(ingredientLower) {
                return quantity * 30.0
            } else {
                return convertCupToGrams(quantity: quantity / 8.0, ingredient: ingredientLower) // 1 cup = 8 fl oz
            }
        case "ml", "milliliter", "milliliters":
            // For liquids, assume 1ml = 1g (for water-like liquids)
            if isLiquidIngredient(ingredientLower) {
                return quantity
            } else {
                // For solids, this is tricky - try to estimate based on ingredient
                return convertCupToGrams(quantity: quantity / 240.0, ingredient: ingredientLower) // 1 cup ≈ 240ml
            }
        case "l", "liter", "liters":
            if isLiquidIngredient(ingredientLower) {
                return quantity * 1000.0
            } else {
                return convertCupToGrams(quantity: quantity * 4.167, ingredient: ingredientLower) // 1L ≈ 4.167 cups
            }
        default:
            return nil
        }
    }
    
    /// Convert cups to grams based on ingredient type
    private func convertCupToGrams(quantity: Double, ingredient: String) -> Double {
        if ingredient.contains("flour") {
            return quantity * 120
        } else if ingredient.contains("sugar") && !ingredient.contains("brown") {
            return quantity * 200
        } else if ingredient.contains("brown sugar") {
            return quantity * 220
        } else if ingredient.contains("butter") {
            return quantity * 227
        } else if ingredient.contains("powdered sugar") || ingredient.contains("confectioner") {
            return quantity * 120
        } else if ingredient.contains("cocoa") {
            return quantity * 85
        } else if ingredient.contains("oats") {
            return quantity * 100
        } else if ingredient.contains("rice") && !ingredient.contains("cooked") {
            return quantity * 185
        } else if ingredient.contains("cheese") {
            return quantity * 113
        } else if ingredient.contains("nuts") {
            return quantity * 135
        } else {
            // Default for other solids
            return quantity * 120
        }
    }
    
    /// Check if ingredient is a liquid
    private func isLiquidIngredient(_ ingredient: String) -> Bool {
        let liquidKeywords = ["oil", "milk", "water", "juice", "broth", "stock", "vinegar", "wine", "beer", "sauce", "syrup", "honey"]
        return liquidKeywords.contains { ingredient.contains($0) }
    }
    
    /// Get nutrition for ingredient with specific unit (use tiered lookup: Local DB → USDA → Spoonacular)
    private func getNutritionForIngredientWithUnit(foodName: String, amount: Double, unit: String) async throws -> NutritionInfo? {
        // Try NutritionService first (includes Local DB → USDA → Spoonacular)
        // This ensures we check the local database first for instant, offline results
        let context = NutritionNormalizationContext(
            canonicalFoodName: foodName,
            quantity: amount,
            unit: unit,
            gramsKnown: unit.lowercased() == "g",
            perServingProvided: nil,
            per100gProvided: nil,
            servings: recipe.servings,
            ingredientNames: extractIngredientNames(),
            timestamp: nil,
            imageHash: nil,
            inputMethod: nil
        )
        if let nutrition = try await NutritionNormalizationPipeline.shared.getNutritionForFood(foodName, amount: amount, unit: unit, context: context) {
            print("✅ RecipeAnalysisView: Found nutrition via tiered lookup for '\(foodName)' with unit '\(unit)'")
            return nutrition
        }
        
        // Fallback: try to convert unit to grams and retry with tiered lookup
        if let grams = convertUnitToGrams(quantity: amount, unit: unit, ingredientName: foodName) {
            print("⚠️ RecipeAnalysisView: Converting '\(unit)' to grams (\(grams)g) and retrying tiered lookup")
            return try await getNutritionForIngredientAtAmount(foodName: foodName, amount: grams)
        }
        
        return nil
    }
    
    /// Scale nutrition by servings (divide all values)
    private func scaleNutritionByServings(_ nutrition: NutritionInfo, servings: Int) -> NutritionInfo {
        guard servings > 1 else { return nutrition }
        
        // DEBUG: Log before/after values for validation
        let caloriesStr = nutrition.calories
        if let caloriesBefore = Double(caloriesStr.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespaces)) {
            let caloriesAfter = caloriesBefore / Double(servings)
            print("📊 SCALING DEBUG:")
            print("   Before division: \(Int(caloriesBefore)) calories (total recipe)")
            print("   Servings: \(servings)")
            print("   After division: \(Int(caloriesAfter)) calories (per serving)")
        }
        
        let scaleFactor = 1.0 / Double(servings)
        
        return NutritionInfo(
            calories: scaleNutritionValue(nutrition.calories, by: scaleFactor) ?? nutrition.calories,
            protein: scaleNutritionValue(nutrition.protein, by: scaleFactor) ?? nutrition.protein,
            carbohydrates: scaleNutritionValue(nutrition.carbohydrates, by: scaleFactor) ?? nutrition.carbohydrates,
            fat: scaleNutritionValue(nutrition.fat, by: scaleFactor) ?? nutrition.fat,
            sugar: scaleNutritionValue(nutrition.sugar, by: scaleFactor) ?? nutrition.sugar,
            fiber: scaleNutritionValue(nutrition.fiber, by: scaleFactor) ?? nutrition.fiber,
            sodium: scaleNutritionValue(nutrition.sodium, by: scaleFactor) ?? nutrition.sodium,
            saturatedFat: scaleNutritionValue(nutrition.saturatedFat, by: scaleFactor),
            vitaminD: scaleNutritionValue(nutrition.vitaminD, by: scaleFactor),
            vitaminE: scaleNutritionValue(nutrition.vitaminE, by: scaleFactor),
            potassium: scaleNutritionValue(nutrition.potassium, by: scaleFactor),
            vitaminK: scaleNutritionValue(nutrition.vitaminK, by: scaleFactor),
            magnesium: scaleNutritionValue(nutrition.magnesium, by: scaleFactor),
            vitaminA: scaleNutritionValue(nutrition.vitaminA, by: scaleFactor),
            calcium: scaleNutritionValue(nutrition.calcium, by: scaleFactor),
            vitaminC: scaleNutritionValue(nutrition.vitaminC, by: scaleFactor),
            choline: scaleNutritionValue(nutrition.choline, by: scaleFactor),
            iron: scaleNutritionValue(nutrition.iron, by: scaleFactor),
            iodine: scaleNutritionValue(nutrition.iodine, by: scaleFactor),
            zinc: scaleNutritionValue(nutrition.zinc, by: scaleFactor),
            folate: scaleNutritionValue(nutrition.folate, by: scaleFactor),
            vitaminB12: scaleNutritionValue(nutrition.vitaminB12, by: scaleFactor),
            vitaminB6: scaleNutritionValue(nutrition.vitaminB6, by: scaleFactor),
            selenium: scaleNutritionValue(nutrition.selenium, by: scaleFactor),
            copper: scaleNutritionValue(nutrition.copper, by: scaleFactor),
            manganese: scaleNutritionValue(nutrition.manganese, by: scaleFactor),
            thiamin: scaleNutritionValue(nutrition.thiamin, by: scaleFactor)
        )
    }
    
    /// Scale a nutrition value string by a factor
    private func scaleNutritionValue(_ value: String?, by factor: Double) -> String? {
        guard let value = value, !value.isEmpty else { return value }
        
        // Parse numeric value
        let cleaned = value.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        guard let numericValue = Double(cleaned) else { return value }
        
        let scaled = numericValue * factor
        
        // Preserve unit if present
        if value.contains("mg") {
            return "\(Int(round(scaled)))mg"
        } else if value.contains("mcg") || value.contains("µg") {
            return "\(Int(round(scaled)))mcg"
        } else if value.contains("IU") {
            return "\(Int(round(scaled)))IU"
        } else if value.contains("g") {
            return "\(Int(round(scaled)))g"
        } else if value.contains("kcal") || value.contains("cal") {
            return "\(Int(round(scaled)))kcal"
        } else {
            return "\(Int(round(scaled)))"
        }
    }
    
    // Convert Spoonacular nutrition to NutritionInfo
    private func convertSpoonacularNutritionToNutritionInfo(_ spoonNutrition: SpoonacularIngredientNutrition) -> NutritionInfo {
        print("🔄 RecipeAnalysisView: Converting Spoonacular nutrition to NutritionInfo")
        print("🔄 RecipeAnalysisView: Processing \(spoonNutrition.nutrition.nutrients.count) nutrients")
        var nutritionDict: [String: String] = [:]
        
        // Extract nutrients from Spoonacular response
        for nutrient in spoonNutrition.nutrition.nutrients {
            let originalName = nutrient.name
            let name = nutrient.name.lowercased()
            let amount = nutrient.amount
            let unit = nutrient.unit
            
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
        
        print("✅ RecipeAnalysisView: Conversion complete - Macros: \(result.calories) cal, \(result.protein) protein")
        return result
    }
    
    // Format nutrition value (round to whole numbers)
    private func formatNutritionValue(_ amount: Double, unit: String) -> String {
        return "\(Int(round(amount)))\(unit)"
    }
    
    
    // Fetch nutrition info from AI (fallback)
    private func fetchNutritionInfoFromAI() async throws -> NutritionInfo {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Based on this recipe analysis, provide estimated nutritional information for an estimated serving size.
        
        Recipe: \(recipe.title)
        Summary: \(analysis.summary)
        Longevity Score: \(analysis.overallScore)/100
        Ingredients: \(recipe.allIngredients.map { $0.name }.joined(separator: ", "))
        
        Estimate a reasonable serving size based on the recipe type (e.g., "1 cup" for soups, "1 piece" for baked goods, "1 serving" for main dishes).
        Provide nutritional information for that estimated serving size.
        
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
                "vitaminB6": "XX mg",
                "selenium": "XXX mcg",
                "copper": "XX mg",
                "manganese": "XXX mg",
                "thiamin": "XX mg"
            }
        }
        
        Provide realistic estimates based on the recipe type and ingredients. Use standard serving sizes.
        For micronutrients, provide estimates based on typical values for these ingredients. If a micronutrient is not present in significant amounts, use "0" or omit the field.
        """
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
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
              let content = message["content"] as? String else {
            throw NSError(domain: "Invalid JSON", code: 0, userInfo: nil)
        }
        
        // Parse JSON from content
        let jsonStart = content.range(of: "{")
        let jsonEnd = content.range(of: "}", options: .backwards)
        
        guard let start = jsonStart?.lowerBound, let end = jsonEnd?.upperBound else {
            throw NSError(domain: "No JSON found", code: 0, userInfo: nil)
        }
        
        let jsonString = String(content[start..<end])
        guard let jsonData = jsonString.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let nutritionInfoDict = parsed["nutritionInfo"] as? [String: Any] else {
            throw NSError(domain: "Invalid nutrition info", code: 0, userInfo: nil)
        }
        
        return NutritionInfo(
            calories: nutritionInfoDict["calories"] as? String ?? "N/A",
            protein: nutritionInfoDict["protein"] as? String ?? "N/A",
            carbohydrates: nutritionInfoDict["carbohydrates"] as? String ?? "N/A",
            fat: nutritionInfoDict["fat"] as? String ?? "N/A",
            sugar: nutritionInfoDict["sugar"] as? String ?? "N/A",
            fiber: nutritionInfoDict["fiber"] as? String ?? "N/A",
            sodium: nutritionInfoDict["sodium"] as? String ?? "N/A",
            saturatedFat: nutritionInfoDict["saturatedFat"] as? String,
            vitaminD: nutritionInfoDict["vitaminD"] as? String,
            vitaminE: nutritionInfoDict["vitaminE"] as? String,
            potassium: nutritionInfoDict["potassium"] as? String,
            vitaminK: nutritionInfoDict["vitaminK"] as? String,
            magnesium: nutritionInfoDict["magnesium"] as? String,
            vitaminA: nutritionInfoDict["vitaminA"] as? String,
            calcium: nutritionInfoDict["calcium"] as? String,
            vitaminC: nutritionInfoDict["vitaminC"] as? String,
            choline: nutritionInfoDict["choline"] as? String,
            iron: nutritionInfoDict["iron"] as? String,
            iodine: nutritionInfoDict["iodine"] as? String,
            zinc: nutritionInfoDict["zinc"] as? String,
            folate: nutritionInfoDict["folate"] as? String,
            vitaminB12: nutritionInfoDict["vitaminB12"] as? String,
            vitaminB6: nutritionInfoDict["vitaminB6"] as? String,
            selenium: nutritionInfoDict["selenium"] as? String,
            copper: nutritionInfoDict["copper"] as? String,
            manganese: nutritionInfoDict["manganese"] as? String,
            thiamin: nutritionInfoDict["thiamin"] as? String
        )
    }
}

