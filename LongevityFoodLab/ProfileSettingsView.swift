import SwiftUI

struct ProfileSettingsView: View {
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var ageRange: String = ""
    @State private var sex: String = ""
    @State private var selectedHealthGoals: Set<String> = []
    @State private var dietaryPreference: String = ""
    @State private var selectedRestrictions: Set<String> = []
    @State private var selectedMicronutrients: Set<String> = []
    
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    
    private let healthGoals = [
        "Heart health", "Brain health", "Digestive health", "Weight management",
        "Energy", "Bone/muscle health", "Joint health", "Immune support",
        "Hormonal balance", "Skin health", "Sleep quality", "Stress management",
        "Blood sugar control"
    ]
    
    private let dietaryPreferences = [
        "No preference", "Mediterranean", "Vegetarian", "Vegan", "Keto", "Paleo", "Low-carb", "Balanced"
    ]
    
    private let foodRestrictions = [
        "None", "Gluten-free", "Dairy-free", "Nut-free", "Soy-free", "Shellfish-free", "Egg-free", "Low-sodium"
    ]
    
    private let micronutrientOptions = [
        "Vitamin D", "Vitamin E", "Potassium", "Vitamin K", "Magnesium",
        "Vitamin A", "Calcium", "Vitamin C", "Choline", "Iron",
        "Iodine", "Zinc", "Folate (B9)", "Vitamin B12", "Vitamin B6",
        "Selenium", "Copper", "Manganese", "Thiamin (B1)"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    profileHeader
                    
                    // Demographics Section
                    demographicsSection
                    
                    // Health Goals Section
                    healthGoalsSection
                    
                    // Dietary Preferences Section
                    dietaryPreferencesSection
                    
                    // Food Restrictions Section
                    foodRestrictionsSection
                    
                    // Micronutrients Section
                    micronutrientsSection
                    
                    // Save Button
                    saveButton
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentProfile()
            }
            .alert("Profile Updated", isPresented: $showingSaveAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(saveMessage)
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                )
            
            Text("Health Profile Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Customize your health profile to get personalized recommendations")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var demographicsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Demographics")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Age Range
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age Range")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Age Range", selection: $ageRange) {
                        Text("Select Age Range").tag("")
                        Text("Under 30").tag("Under 30")
                        Text("30-50").tag("30-50")
                        Text("50-70").tag("50-70")
                        Text("70+").tag("70+")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Sex
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sex")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Sex", selection: $sex) {
                        Text("Select Sex").tag("")
                        Text("Female").tag("Female")
                        Text("Male").tag("Male")
                        Text("Prefer not to say").tag("Prefer not to say")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var healthGoalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Goals")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Select all that apply (minimum 1 required)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(healthGoals, id: \.self) { goal in
                    HealthGoalChip(
                        title: goal,
                        isSelected: selectedHealthGoals.contains(goal)
                    ) {
                        if selectedHealthGoals.contains(goal) {
                            selectedHealthGoals.remove(goal)
                        } else {
                            selectedHealthGoals.insert(goal)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var dietaryPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dietary Preference")
                .font(.headline)
                .fontWeight(.semibold)
            
            Picker("Dietary Preference", selection: $dietaryPreference) {
                ForEach(dietaryPreferences, id: \.self) { preference in
                    Text(preference).tag(preference)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var foodRestrictionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Food Restrictions")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Select any dietary restrictions or allergies")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(foodRestrictions, id: \.self) { restriction in
                    FoodRestrictionChip(
                        title: restriction,
                        isSelected: selectedRestrictions.contains(restriction)
                    ) {
                        if selectedRestrictions.contains(restriction) {
                            selectedRestrictions.remove(restriction)
                        } else {
                            selectedRestrictions.insert(restriction)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var micronutrientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Track Micronutrients")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Select which micronutrients you want to track")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(micronutrientOptions, id: \.self) { micronutrient in
                    HealthGoalChip(
                        title: micronutrient,
                        isSelected: selectedMicronutrients.contains(micronutrient)
                    ) {
                        if selectedMicronutrients.contains(micronutrient) {
                            selectedMicronutrients.remove(micronutrient)
                        } else {
                            selectedMicronutrients.insert(micronutrient)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var saveButton: some View {
        Button(action: saveProfile) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                Text("Save Profile")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Group {
                    if isFormValid {
                        LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.gray
                    }
                }
            )
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .disabled(!isFormValid)
    }
    
    private var isFormValid: Bool {
        !ageRange.isEmpty && !sex.isEmpty && !selectedHealthGoals.isEmpty && !dietaryPreference.isEmpty
    }
    
    private func loadCurrentProfile() {
        if let profile = healthProfileManager.currentProfile {
            ageRange = profile.ageRange ?? ""
            sex = profile.sex ?? ""
            dietaryPreference = profile.dietaryPreference ?? ""
            
            // Parse health goals from JSON
            if let healthGoalsData = profile.healthGoals?.data(using: .utf8),
               let goals = try? JSONDecoder().decode([String].self, from: healthGoalsData) {
                selectedHealthGoals = Set(goals)
            }
            
            // Parse food restrictions from JSON
            if let restrictionsData = profile.foodRestrictions?.data(using: .utf8),
               let restrictions = try? JSONDecoder().decode([String].self, from: restrictionsData) {
                selectedRestrictions = Set(restrictions)
            }
            
            // Parse tracked micronutrients from JSON
            if let micronutrientsData = profile.trackedMicronutrients?.data(using: .utf8),
               let micronutrients = try? JSONDecoder().decode([String].self, from: micronutrientsData) {
                selectedMicronutrients = Set(micronutrients)
            }
        }
    }
    
    private func saveProfile() {
        // Convert sets to JSON strings
        let healthGoalsJSON = try? JSONEncoder().encode(Array(selectedHealthGoals))
        let restrictionsJSON = try? JSONEncoder().encode(Array(selectedRestrictions))
        let micronutrientsJSON = try? JSONEncoder().encode(Array(selectedMicronutrients))
        
        let healthGoalsString = String(data: healthGoalsJSON ?? Data(), encoding: .utf8) ?? "[]"
        let restrictionsString = String(data: restrictionsJSON ?? Data(), encoding: .utf8) ?? "[]"
        let micronutrientsString = String(data: micronutrientsJSON ?? Data(), encoding: .utf8) ?? "[]"
        
        // Update the profile using the manager's update method
        let success = healthProfileManager.updateProfile(
            ageRange: ageRange,
            sex: sex,
            healthGoals: Array(selectedHealthGoals),
            dietaryPreference: dietaryPreference,
            foodRestrictions: Array(selectedRestrictions),
            trackedMicronutrients: Array(selectedMicronutrients)
        )
        
        if success {
            saveMessage = "Your health profile has been updated successfully!"
            showingSaveAlert = true
        } else {
            saveMessage = "Failed to update profile. Please try again."
            showingSaveAlert = true
        }
    }
}

// MARK: - Supporting Views

struct HealthGoalChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? 
                    Color(hex: "10B981") : 
                    Color(.systemGray5)
                )
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .cornerRadius(20)
        }
    }
}

struct FoodRestrictionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? 
                    Color(hex: "F59E0B") : 
                    Color(.systemGray5)
                )
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .cornerRadius(20)
        }
    }
}

#Preview {
    ProfileSettingsView()
}
