import SwiftUI

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    private let aiService = AIService.shared
    
    let selectedDate: Date
    let onMealAdded: (TrackedMeal) -> Void
    
    @State private var mealName = ""
    @State private var foodItems: [String] = []
    @State private var currentFoodItem = ""
    @State private var notes = ""
    @State private var isAnalyzing = false
    @State private var analysisResult: FoodAnalysis?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Meal Name
                    mealNameSection
                    
                    // Food Items
                    foodItemsSection
                    
                    // Analysis Results
                    if let analysis = analysisResult {
                        analysisResultsSection(analysis)
                    }
                    
                    // Notes
                    notesSection
                    
                    // Add Button
                    addButton
                }
                .padding()
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Track Your Meal")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add the foods you ate and get personalized health insights")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var mealNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Meal Name")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("e.g., Breakfast, Lunch, Dinner", text: $mealName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var foodItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Food Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Add Food Item
            HStack {
                TextField("Add a food item", text: $currentFoodItem)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        addFoodItem()
                    }
                
                Button(action: addFoodItem) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
                .disabled(currentFoodItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Food Items List
            if !foodItems.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(foodItems, id: \.self) { item in
                        FoodItemChip(
                            item: item,
                            onRemove: { removeFoodItem(item) }
                        )
                    }
                }
                
                // Analyze Button
                Button(action: analyzeMeal) {
                    HStack {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        
                        Text(isAnalyzing ? "Analyzing..." : "Analyze Meal")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        Group {
                            if foodItems.isEmpty || isAnalyzing {
                                Color.gray
                            } else {
                                LinearGradient(
                                    colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(foodItems.isEmpty || isAnalyzing)
            }
        }
    }
    
    private func analysisResultsSection(_ analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Results")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Health Score
            HStack {
                VStack {
                    Text("Health Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                                    CircularProgressView(
                    progress: Double(analysis.overallScore) / 10.0,
                    color: scoreColor(analysis.overallScore)
                )
                }
            }
            
            // Health Goals Met
            let goalsMet = getGoalsMet(from: analysis)
            if !goalsMet.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Health Goals Met")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(goalsMet, id: \.self) { goal in
                            Text(goal)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            
            // Key Benefits
            if !analysis.keyBenefitsOrDefault.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Key Benefits")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(analysis.keyBenefitsOrDefault.prefix(3), id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(benefit)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (Optional)")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("Add any notes about this meal...", text: $notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    private var addButton: some View {
        Button(action: addMeal) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                Text("Add Meal")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Group {
                    if mealName.isEmpty || foodItems.isEmpty {
                        Color.gray
                    } else {
                        LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .disabled(mealName.isEmpty || foodItems.isEmpty)
    }
    
    private func addFoodItem() {
        let trimmedItem = currentFoodItem.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedItem.isEmpty && !foodItems.contains(trimmedItem) {
            foodItems.append(trimmedItem)
            currentFoodItem = ""
        }
    }
    
    private func removeFoodItem(_ item: String) {
        foodItems.removeAll { $0 == item }
        if analysisResult != nil {
            analysisResult = nil
        }
    }
    
    private func analyzeMeal() {
        guard !foodItems.isEmpty else { return }
        
        isAnalyzing = true
        let combinedFoods = foodItems.joined(separator: ", ")
        
        let healthProfile = healthProfileManager.currentProfile
        aiService.analyzeFoodWithProfile(combinedFoods, healthProfile: healthProfile) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                
                switch result {
                case .success(let analysis):
                    analysisResult = analysis
                case .failure(let error):
                    errorMessage = "Failed to analyze meal: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    private func addMeal() {
        guard !mealName.isEmpty && !foodItems.isEmpty else { return }
        
        let healthScore = Double(analysisResult?.overallScore ?? 5)
        let goalsMet = analysisResult != nil ? getGoalsMet(from: analysisResult!) : []
        
        let meal = TrackedMeal(
            id: UUID(),
            name: mealName,
            foods: foodItems,
            healthScore: healthScore,
            goalsMet: goalsMet,
            timestamp: selectedDate,
            notes: notes.isEmpty ? nil : notes,
            originalAnalysis: nil, // AddMealView doesn't have original analysis
            imageHash: nil, // AddMealView doesn't have image (manual entry)
            isFavorite: false
        )
        
        onMealAdded(meal)
        dismiss()
    }
    
    private func getGoalsMet(from analysis: FoodAnalysis) -> [String] {
        var goals: [String] = []
        let scores = analysis.healthScores
        
        if scores.heartHealth >= 7 { goals.append("Heart health") }
        if scores.brainHealth >= 7 { goals.append("Brain health") }
        if scores.antiInflammation >= 7 { goals.append("Anti-inflammation") }
        if scores.jointHealth >= 7 { goals.append("Joint health") }
        if scores.eyeHealth >= 7 { goals.append("Eye health") }
        if scores.weightManagement >= 7 { goals.append("Weight management") }
        if scores.bloodSugar >= 7 { goals.append("Blood sugar control") }
        if scores.energy >= 7 { goals.append("Energy") }
        if scores.immune >= 7 { goals.append("Immune support") }
        if scores.sleep >= 7 { goals.append("Sleep quality") }
        if scores.skin >= 7 { goals.append("Skin health") }
        if scores.stress >= 7 { goals.append("Stress management") }
        
        return goals
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
}

// MARK: - Supporting Views

struct FoodItemChip: View {
    let item: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(item)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            Text(String(format: "%.0f", progress * 100))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
            
            Text("Score")
                .font(.caption)
                .foregroundColor((colorScheme == .dark ? Color.black : Color.white).opacity(0.8))
        }
        .frame(width: 80, height: 80)
        .background(color)
        .cornerRadius(40)
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
}

#Preview {
    AddMealView(
        selectedDate: Date(),
        onMealAdded: { _ in }
    )
}
