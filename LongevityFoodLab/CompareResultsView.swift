import SwiftUI

struct CompareResultsView: View {
    let analyses: [FoodAnalysis]
    let onNewCompare: () -> Void
    
    @State private var showingLoading = false
    @State private var selectedCategory: String?
    @State private var comparisonSummary: String = ""
    @State private var isLoadingSummary = false
    @State private var isSummaryExpanded = false
    @State private var hasGeneratedSummary = false
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    
    // Add safety checks to prevent crashes
    private var food1: FoodAnalysis? { 
        guard analyses.count > 0 else { 
            print("CompareResultsView: No analyses available, food1 is nil")
            return nil 
        }
        let food = analyses[0]
        print("CompareResultsView: food1 = \(food.foodName) with score \(food.overallScore)")
        return food
    }
    private var food2: FoodAnalysis? { 
        guard analyses.count > 1 else { 
            print("CompareResultsView: Only \(analyses.count) analyses available, food2 is nil")
            return nil 
        }
        let food = analyses[1]
        print("CompareResultsView: food2 = \(food.foodName) with score \(food.overallScore)")
        return food
    }
    
    // Check if we have valid data to display
    private var hasValidData: Bool {
        let valid = food1 != nil && food2 != nil
        print("CompareResultsView: hasValidData = \(valid), analyses count = \(analyses.count)")
        return valid
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 75)
                            .padding(.top, 0)
                        
                        VStack(spacing: 0) {
                            Text("LONGEVITY")
                                .font(.custom("Avenir-Light", size: 28))
                                .fontWeight(.light)
                                .tracking(6)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 40, height: 1)
                                
                                Text("FOOD LAB")
                                    .font(.custom("Avenir-Light", size: 14))
                                    .tracking(4)
                                    .foregroundColor(.secondary)
                                
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 40, height: 1)
                            }
                        }
                    }
                    .padding(.vertical, 15)
                    .padding(.top, -20)
                    
                    // Overall Scores Section
                    VStack(alignment: .center, spacing: 16) {
                        Text("Overall Scores")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        HStack(spacing: 16) {
                            // Food 1 Score
                            VStack(spacing: 8) {
                                Text(food1?.foodName ?? "N/A")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 44) // Fixed height to align circles
                                
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                        .frame(width: 100, height: 100)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(food1?.overallScore ?? 0) / 100)
                                        .stroke(scoreColor(food1?.overallScore ?? 0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 100, height: 100)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut(duration: 1), value: food1?.overallScore)
                                    
                                    VStack {
                                        Text("\(food1?.overallScore ?? 0)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text("/100")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Text(scoreLabel(food1?.overallScore ?? 0))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(scoreColor(food1?.overallScore ?? 0))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            
                            // Food 2 Score
                            VStack(spacing: 8) {
                                Text(food2?.foodName ?? "N/A")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                    .frame(height: 44) // Fixed height to align circles
                                
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                        .frame(width: 100, height: 100)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(food2?.overallScore ?? 0) / 100)
                                        .stroke(scoreColor(food2?.overallScore ?? 0), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 100, height: 100)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut(duration: 1), value: food2?.overallScore)
                                    
                                    VStack {
                                        Text("\(food2?.overallScore ?? 0)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                        Text("/100")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Text(scoreLabel(food2?.overallScore ?? 0))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(scoreColor(food2?.overallScore ?? 0))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                        }
                    }
                    
                    // Comparison Summary Dropdown
                    VStack(alignment: .leading, spacing: 16) {
                        Button(action: {
                            isSummaryExpanded.toggle()
                            if isSummaryExpanded && !hasGeneratedSummary {
                                generateComparisonSummary()
                            }
                        }) {
                            HStack {
                                Text("Key Differences & Health Impact")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Image(systemName: isSummaryExpanded ? "chevron.up" : "chevron.down")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if isSummaryExpanded {
                            if isLoadingSummary {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Analyzing differences...")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                            } else if !comparisonSummary.isEmpty {
                                Text(comparisonSummary)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineSpacing(4)
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Detailed Comparison Chart
                    VStack(alignment: .center, spacing: 16) {
                        Text("Detailed Comparison")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        VStack(spacing: 0) {
                            // Header row
                            HStack(spacing: 0) {
                                Text("Longevity Benefits")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .frame(width: 120, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color(UIColor.systemBackground))
                                
                                Text(food1?.foodName ?? "N/A")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(UIColor.systemBackground))
                                
                                Text(food2?.foodName ?? "N/A")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(UIColor.systemBackground))
                            }
                            
                            // Data rows
                            ForEach(Array(healthCategories.enumerated()), id: \.element) { _, category in
                                HStack(spacing: 0) {
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        HStack {
                                            Text(category)
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .underline()
                                                .frame(width: 120, alignment: .leading)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .background(Color(UIColor.secondarySystemBackground))
                                    
                                    // Food 1 score
                                    Text("\(getCategoryScore(food1, category))")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(scoreColor(getCategoryScore(food1, category)))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(UIColor.secondarySystemBackground))
                                    
                                    // Food 2 score
                                    Text("\(getCategoryScore(food2, category))")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(scoreColor(getCategoryScore(food2, category)))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(UIColor.secondarySystemBackground))
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // New Compare Button
                    Button(action: {
                        onNewCompare()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("Compare New Foods")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(red: 0.255, green: 0.643, blue: 0.655))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onNewCompare()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            // No longer automatically generate summary - only when user expands dropdown
        }
        .sheet(isPresented: Binding(
            get: { selectedCategory != nil },
            set: { if !$0 { selectedCategory = nil } }
        )) {
            if let category = selectedCategory {
                CompareHealthDetailView(
                    category: category,
                    food1Name: food1?.foodName ?? "N/A",
                    food1Score: getCategoryScore(food1, category),
                    food2Name: food2?.foodName ?? "N/A",
                    food2Score: getCategoryScore(food2, category),
                    food1LongevityScore: food1?.overallScore ?? 0,
                    food2LongevityScore: food2?.overallScore ?? 0
                )
            }
        }
    }
    
    private var healthCategories: [String] {
        return ["Heart", "Brain", "Anti-Inflam", "Weight", "Blood Sugar", "Energy", "Immune", "Sleep", "Skin", "Stress", "Microbiome", "Bone & Joints"]
    }
    
    private func getCategoryScore(_ analysis: FoodAnalysis?, _ category: String) -> Int {
        guard let analysis = analysis else { return 0 }
        switch category {
        case "Heart": return analysis.healthScores.heartHealth
        case "Brain": return analysis.healthScores.brainHealth
        case "Anti-Inflam": return analysis.healthScores.antiInflammation

        case "Weight": return analysis.healthScores.weightManagement
        case "Blood Sugar": return analysis.healthScores.bloodSugar
        case "Energy": return analysis.healthScores.energy
        case "Immune": return analysis.healthScores.immune
        case "Sleep": return analysis.healthScores.sleep
        case "Skin": return analysis.healthScores.skin
        case "Stress": return analysis.healthScores.stress
        case "Microbiome": return analysis.healthScores.weightManagement // Using weight management as proxy for microbiome health
        case "Bone & Joints": return analysis.healthScores.jointHealth // Using joint health for bone & joints
        default: return 0
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...100: return Color.green
        case 80...89: return Color(red: 0.2, green: 0.8, blue: 0.2)
        case 70...79: return Color(red: 0.4, green: 0.7, blue: 0.2)
        case 60...69: return Color(red: 0.6, green: 0.6, blue: 0.2)
        case 50...59: return Color.orange
        case 40...49: return Color(red: 1.0, green: 0.5, blue: 0.0)
        default: return Color.red
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
    
    private func generateComparisonSummary() {
        guard let food1 = food1, let food2 = food2 else {
            isLoadingSummary = false
            return
        }
        
        // Prevent duplicate API calls
        guard !hasGeneratedSummary else { return }
        
        hasGeneratedSummary = true
        
        Task {
            do {
                let summary = try await generateAISummary(food1: food1, food2: food2)
                await MainActor.run {
                    comparisonSummary = summary
                    isLoadingSummary = false
                }
            } catch {
                await MainActor.run {
                    comparisonSummary = "Unable to generate comparison summary at this time."
                    isLoadingSummary = false
                }
            }
        }
    }
    
    private func generateAISummary(food1: FoodAnalysis, food2: FoodAnalysis) async throws -> String {
        // Get user's health goals
        let healthGoals = healthProfileManager.getHealthGoals()
        let healthGoalsText = healthGoals.isEmpty ? "general health and longevity" : healthGoals.joined(separator: ", ")
        
        // Get top scoring categories for each food
        let food1TopCategories = getTopCategories(for: food1, limit: 3)
        let food2TopCategories = getTopCategories(for: food2, limit: 3)
        
        let prompt = """
        Compare \(food1.foodName) (score: \(food1.overallScore)/100) and \(food2.foodName) (score: \(food2.overallScore)/100) for someone focused on \(healthGoalsText).
        
        Food 1 (\(food1.foodName)) strengths: \(food1TopCategories.joined(separator: ", "))
        Food 2 (\(food2.foodName)) strengths: \(food2TopCategories.joined(separator: ", "))
        
        Write exactly 2 short paragraphs:
        
        Paragraph 1: Brief comparison highlighting the key nutritional differences between these foods, mentioning specific nutrients or compounds that drive these differences. Do not mention scores.
        
        Paragraph 2: Focus specifically on the user's health goals (\(healthGoalsText)) and highlight the biggest, health-impacting difference between these foods.
        
        Be concise, scientific, and practical. Each paragraph should be 1-2 sentences.
        """
        
        // Use AIService's OpenAI helper
        return try await AIService.shared.makeOpenAIRequestAsync(prompt: prompt)
    }
    
    private func getTopCategories(for food: FoodAnalysis, limit: Int) -> [String] {
        let categories = [
            ("Heart", food.healthScores.heartHealth),
            ("Brain", food.healthScores.brainHealth),
            ("Anti-Inflammation", food.healthScores.antiInflammation),
            ("Weight Management", food.healthScores.weightManagement),
            ("Blood Sugar", food.healthScores.bloodSugar),
            ("Energy", food.healthScores.energy),
            ("Immune", food.healthScores.immune),
            ("Sleep", food.healthScores.sleep),
            ("Skin", food.healthScores.skin),
            ("Stress", food.healthScores.stress),
            ("Bone & Joints", food.healthScores.jointHealth)
        ]
        
        return categories
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { "\($0.0) (\($0.1)/100)" }
    }
}

struct CompareHealthDetailView: View {
    let category: String
    let food1Name: String
    let food1Score: Int
    let food2Name: String
    let food2Score: Int
    let food1LongevityScore: Int
    let food2LongevityScore: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var healthInfo: CompareHealthInfo?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading comparison...")
                            .padding()
                    } else if let info = healthInfo {
                        compareHealthInfoContent(info)
                    } else {
                        Text("Unable to load comparison")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("\(category) Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCompareHealthInfo()
        }
    }
    
    private func compareHealthInfoContent(_ info: CompareHealthInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Scores Display
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    // Food 1
                    VStack(spacing: 8) {
                        Text(food1Name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("\(category) Score: \(food1Score)/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Longevity: \(food1LongevityScore)/100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Food 2
                    VStack(spacing: 8) {
                        Text(food2Name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("\(category) Score: \(food2Score)/100")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Longevity: \(food2LongevityScore)/100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            
            // Summary
            VStack(alignment: .leading, spacing: 10) {
                Text("Comparison Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(info.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Research Evidence
            if !info.researchEvidence.isEmpty {
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
            
            // Sources
            if !info.sources.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sources")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(info.sources, id: \.self) { source in
                        Text("• \(source)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func loadCompareHealthInfo() {
        isLoading = true
        
        let prompt = """
        Compare how \(food1Name) and \(food2Name) specifically benefit \(category.lowercased()) health.
        
        \(food1Name) has a \(category.lowercased()) score of \(food1Score)/100 and overall longevity score of \(food1LongevityScore)/100.
        \(food2Name) has a \(category.lowercased()) score of \(food2Score)/100 and overall longevity score of \(food2LongevityScore)/100.
        
        Return ONLY valid JSON with this exact format:
        
        {
            "summary": "2-3 sentence comparison summary focused on \(category.lowercased()) benefits, highlighting key differences between the two foods",
            "researchEvidence": [
                "Specific research finding comparing \(category.lowercased()) effects",
                "Key study result showing differences in \(category.lowercased()) benefits"
            ],
            "sources": [
                "Trusted institution or journal name 1",
                "Trusted institution or journal name 2"
            ]
        }
        
        Focus on peer-reviewed research, clinical studies, and reputable health institutions. Be specific about how each food directly impacts \(category.lowercased()) health and highlight the comparative advantages.
        """
        
        Task {
            do {
                let text = try await AIService.shared.makeOpenAIRequestAsync(prompt: prompt)
                
                await MainActor.run {
                    isLoading = false
                    
                    guard let infoData = text.data(using: .utf8) else { return }
                    
                    do {
                        let info = try JSONDecoder().decode(CompareHealthInfo.self, from: infoData)
                        self.healthInfo = info
                    } catch {
                        print("Error parsing compare health info: \(error)")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("Error loading compare health info: \(error)")
                }
            }
        }
    }
}

struct CompareHealthInfo: Codable {
    let summary: String
    let researchEvidence: [String]
    let sources: [String]
}

#Preview {
    CompareResultsView(
        analyses: [
            FoodAnalysis(
                foodName: "Apple",
                overallScore: 85,
                summary: "Apple provides excellent health benefits.",
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
                keyBenefits: ["High in antioxidants", "Supports heart health", "Boosts energy"],
                ingredients: [
                    FoodIngredient(name: "Apple", impact: "Positive", explanation: "Good for health")
                ],
                bestPreparation: "Raw or baked",
                servingSize: "1 medium apple",
                nutritionInfo: NutritionInfo(
                    calories: "95",
                    protein: "0.5g",
                    carbohydrates: "25g",
                    fat: "0.3g",
                    sugar: "19g",
                    fiber: "4g",
                    sodium: "2mg",
                    saturatedFat: nil
                ),
                scanType: "food",
                foodNames: nil,
                foodPortions: nil,
                suggestions: nil
            ),
            FoodAnalysis(
                foodName: "Banana",
                overallScore: 75,
                summary: "Banana provides good health benefits.",
                healthScores: HealthScores(
                    allergies: 70,
                    antiInflammation: 70,
                    bloodSugar: 70,
                    brainHealth: 75,
                    detoxLiver: 75,
                    energy: 80,
                    eyeHealth: 60,
                    heartHealth: 80,
                    immune: 75,
                    jointHealth: 65,
                    kidneys: 70,
                    mood: 75,
                    skin: 70,
                    sleep: 65,
                    stress: 75,
                    weightManagement: 75
                ),
                keyBenefits: ["Good source of potassium", "Supports digestion", "Provides energy"],
                ingredients: [
                    FoodIngredient(name: "Banana", impact: "Positive", explanation: "Good for health")
                ],
                bestPreparation: "Raw or blended",
                servingSize: "1 medium banana",
                nutritionInfo: NutritionInfo(
                    calories: "105",
                    protein: "1.3g",
                    carbohydrates: "27g",
                    fat: "0.4g",
                    sugar: "14g",
                    fiber: "3g",
                    sodium: "1mg",
                    saturatedFat: nil
                ),
                scanType: "food",
                foodNames: nil,
                foodPortions: nil,
                suggestions: nil
            )
        ],
        onNewCompare: {}
    )
}

 