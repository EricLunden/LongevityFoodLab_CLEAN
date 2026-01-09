import SwiftUI

struct HealthQuizView: View {
    @State private var currentStep = 1
    @State private var showingMainApp = false
    
    // Quiz Data
    @State private var ageRange: String = ""
    @State private var sex: String = ""
    @State private var selectedHealthGoals: Set<String> = []
    @State private var dietaryPreference: String = ""
    @State private var selectedRestrictions: Set<String> = []
    @State private var selectedMicronutrients: Set<String> = []
    
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Header
                progressHeader
                
                // Quiz Content
                TabView(selection: $currentStep) {
                    // Step 1: Demographics
                    DemographicsStepView(
                        ageRange: $ageRange,
                        sex: $sex,
                        onContinue: { goToNextStep() }
                    )
                    .tag(1)
                    
                    // Step 2: Health Goals
                    HealthGoalsStepView(
                        selectedGoals: $selectedHealthGoals,
                        onContinue: { goToNextStep() },
                        onBack: { goToPreviousStep() }
                    )
                    .tag(2)
                    
                    // Step 3: Diet
                    DietStepView(
                        dietaryPreference: $dietaryPreference,
                        onContinue: { goToNextStep() },
                        onBack: { goToPreviousStep() }
                    )
                    .tag(3)
                    
                    // Step 4: Restrictions
                    RestrictionsStepView(
                        selectedRestrictions: $selectedRestrictions,
                        onContinue: { goToNextStep() },
                        onBack: { goToPreviousStep() }
                    )
                    .tag(4)
                    
                    // Step 5: Micronutrients
                    MicronutrientsStepView(
                        selectedMicronutrients: $selectedMicronutrients,
                        onComplete: { completeQuiz() },
                        onBack: { goToPreviousStep() }
                    )
                    .tag(5)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingMainApp) {
            ContentView()
        }
    }
    
    private var progressHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    if currentStep > 1 {
                        goToPreviousStep()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(currentStep > 1 ? .primary : .clear)
                }
                .disabled(currentStep <= 1)
                
                Spacer()
                
                Text("Health Profile Setup")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible button for balance
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal)
            
            // Progress Bar
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? Color(hex: "10B981") : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .padding(.horizontal)
            
            Text("Step \(currentStep) of 5")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    private func goToNextStep() {
        withAnimation {
            currentStep += 1
        }
    }
    
    private func goToPreviousStep() {
        withAnimation {
            currentStep -= 1
        }
    }
    
    private func completeQuiz() {
        // Save profile to Core Data
        let success = healthProfileManager.createProfile(
            ageRange: ageRange,
            sex: sex,
            healthGoals: Array(selectedHealthGoals),
            dietaryPreference: dietaryPreference,
            foodRestrictions: Array(selectedRestrictions),
            trackedMicronutrients: Array(selectedMicronutrients)
        )
        
        if success {
            print("✅ Health profile created successfully!")
            showingMainApp = true
        } else {
            print("❌ Failed to create health profile")
            // TODO: Show error alert
        }
    }
}

// MARK: - Step 1: Demographics

struct DemographicsStepView: View {
    @Binding var ageRange: String
    @Binding var sex: String
    let onContinue: () -> Void
    
    private let ageRanges = ["Under 30", "30-50", "50-70", "70+"]
    private let sexOptions = ["Female", "Male", "Prefer not to say"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "10B981"))
                    
                    VStack(spacing: 8) {
                        Text("Tell us about yourself")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This helps us personalize your health recommendations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                // Age Range Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Age Range")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        ForEach(ageRanges, id: \.self) { range in
                            SelectionRow(
                                title: range,
                                isSelected: ageRange == range,
                                onTap: { ageRange = range }
                            )
                        }
                    }
                }
                
                // Sex Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sex")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        ForEach(sexOptions, id: \.self) { option in
                            SelectionRow(
                                title: option,
                                isSelected: sex == option,
                                onTap: { sex = option }
                            )
                        }
                    }
                }
                
                Spacer(minLength: 40)
                
                // Continue Button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Group {
                                if ageRange.isEmpty || sex.isEmpty {
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
                }
                .disabled(ageRange.isEmpty || sex.isEmpty)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding()
        }
    }
}

// MARK: - Step 2: Health Goals

struct HealthGoalsStepView: View {
    @Binding var selectedGoals: Set<String>
    let onContinue: () -> Void
    let onBack: () -> Void
    
    private let healthGoals = [
        "Heart health", "Brain health", "Digestive health", "Weight management",
        "Energy", "Bone/muscle health", "Joint health", "Immune support",
        "Hormonal balance", "Skin health", "Sleep quality", "Stress management", "Blood sugar"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "target")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "10B981"))
                    
                    VStack(spacing: 8) {
                        Text("What are your health goals?")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Select all that apply (minimum 1 required)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                // Health Goals Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(healthGoals, id: \.self) { goal in
                        GoalChip(
                            title: goal,
                            isSelected: selectedGoals.contains(goal),
                            onTap: { toggleGoal(goal) }
                        )
                    }
                }
                
                Spacer(minLength: 40)
                
                // Continue Button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Group {
                                if selectedGoals.isEmpty {
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
                }
                .disabled(selectedGoals.isEmpty)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding()
        }
    }
    
    private func toggleGoal(_ goal: String) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }
}

// MARK: - Step 3: Diet

struct DietStepView: View {
    @Binding var dietaryPreference: String
    let onContinue: () -> Void
    let onBack: () -> Void
    
    private let dietOptions = [
        "No specific diet", "Mediterranean", "Keto", "Intermittent fasting",
        "Paleo", "Pescatarian", "Vegetarian", "Vegan", "Omnivore"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "10B981"))
                    
                    VStack(spacing: 8) {
                        Text("What's your dietary preference?")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Choose the option that best describes your eating style")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                // Diet Options
                VStack(spacing: 12) {
                    ForEach(dietOptions, id: \.self) { diet in
                        SelectionRow(
                            title: diet,
                            isSelected: dietaryPreference == diet,
                            onTap: { dietaryPreference = diet }
                        )
                    }
                }
                
                Spacer(minLength: 40)
                
                // Continue Button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            Group {
                                if dietaryPreference.isEmpty {
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
                }
                .disabled(dietaryPreference.isEmpty)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding()
        }
    }
}

// MARK: - Step 4: Restrictions

struct RestrictionsStepView: View {
    @Binding var selectedRestrictions: Set<String>
    let onContinue: () -> Void
    let onBack: () -> Void
    
    private let restrictionOptions = [
        "No restrictions", "Gluten", "Dairy", "Nuts", "Shellfish",
        "Soy", "Eggs", "FODMAPs", "Sugar/carbs"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "10B981"))
                    
                    VStack(spacing: 8) {
                        Text("Any food restrictions?")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Select any foods you avoid or are allergic to")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                // Restrictions Options
                VStack(spacing: 12) {
                    ForEach(restrictionOptions, id: \.self) { restriction in
                        RestrictionRow(
                            title: restriction,
                            isSelected: selectedRestrictions.contains(restriction),
                            onTap: { toggleRestriction(restriction) }
                        )
                    }
                }
                
                Spacer(minLength: 40)
                
                // Continue Button
                HStack(spacing: 16) {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                    
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding()
        }
    }
    
    private func toggleRestriction(_ restriction: String) {
        if restriction == "No restrictions" {
            if selectedRestrictions.contains("No restrictions") {
                selectedRestrictions.remove("No restrictions")
            } else {
                selectedRestrictions = ["No restrictions"]
            }
        } else {
            selectedRestrictions.remove("No restrictions")
            if selectedRestrictions.contains(restriction) {
                selectedRestrictions.remove(restriction)
            } else {
                selectedRestrictions.insert(restriction)
            }
        }
    }
}

// MARK: - Step 5: Micronutrients

struct MicronutrientsStepView: View {
    @Binding var selectedMicronutrients: Set<String>
    let onComplete: () -> Void
    let onBack: () -> Void
    
    private let micronutrientOptions = [
        "Vitamin D", "Vitamin E", "Potassium", "Vitamin K", "Magnesium",
        "Vitamin A", "Calcium", "Vitamin C", "Choline", "Iron",
        "Zinc", "Folate (B9)", "Vitamin B12", "Vitamin B6",
        "Selenium", "Copper", "Manganese", "Thiamin (B1)"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "10B981"))
                    
                    VStack(spacing: 8) {
                        Text("Which micronutrients do you want to track?")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Select all that interest you (optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                
                // Micronutrients Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(micronutrientOptions, id: \.self) { micronutrient in
                        GoalChip(
                            title: micronutrient,
                            isSelected: selectedMicronutrients.contains(micronutrient),
                            onTap: { toggleMicronutrient(micronutrient) }
                        )
                    }
                }
                
                Spacer(minLength: 40)
                
                // Complete Button
                HStack(spacing: 16) {
                    Button(action: onBack) {
                        Text("Back")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                    
                    Button(action: onComplete) {
                        Text("Complete Setup")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding()
        }
    }
    
    private func toggleMicronutrient(_ micronutrient: String) {
        if selectedMicronutrients.contains(micronutrient) {
            selectedMicronutrients.remove(micronutrient)
        } else {
            selectedMicronutrients.insert(micronutrient)
        }
    }
}

// MARK: - Helper Views

struct SelectionRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color(hex: "10B981") : .gray)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "10B981") : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

struct GoalChip: View {
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
                .padding(.vertical, 12)
                .background(
                    isSelected ? 
                    Color(hex: "10B981") : 
                    Color(UIColor.systemBackground)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color(hex: "10B981") : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct RestrictionRow: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? Color(hex: "10B981") : .gray)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "10B981") : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}

#Preview {
    HealthQuizView()
}
