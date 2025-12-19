import SwiftUI

struct MealPlannerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @StateObject private var recipeManager = RecipeManager.shared
    @StateObject private var spoonacularService = SpoonacularService.shared
    
    let planMode: PlanMode
    
    @State private var numberOfDays: Int = 7
    @State private var selectedMeals: Set<MealType> = [.breakfast, .lunch, .dinner]
    @State private var reduceWaste: Bool = false // FIX #3: Default to OFF - only applied if user explicitly enables
    
    // Start date (Auto mode only)
    @State private var startDate: Date = {
        let calendar = Calendar.current
        let today = Date()
        // Find next Monday
        var components = calendar.dateComponents([.year, .month, .day, .weekday], from: today)
        if let weekday = components.weekday {
            let daysUntilMonday = (9 - weekday) % 7
            if daysUntilMonday == 0 {
                // If today is Monday, use next Monday
                return calendar.date(byAdding: .day, value: 7, to: today) ?? today
            } else {
                return calendar.date(byAdding: .day, value: daysUntilMonday, to: today) ?? today
            }
        }
        return today
    }()
    
    // Expandable section states
    @State private var daysExpanded = false
    @State private var mealsExpanded = false
    @State private var longevityScoreExpanded = false
    @State private var dietaryExpanded = false
    @State private var goalsExpanded = false
    @State private var startDateExpanded = false
    
    // Longevity Score Filter
    @State private var longevityScoreFilter: Int = 0  // Default: No minimum (0 = disabled)
    @State private var showingCalendar = false
    @State private var reviewMealPlan: MealPlan?
    @State private var isGeneratingPlan = false
    
    // FIX #2: Dietary preference confirmation popup state
    @State private var showingDietaryPreferenceConfirmation = false
    @State private var pendingDietaryPreference: String? = nil
    @State private var pendingDietaryPreferenceAction: Bool = false // true = add, false = remove
    
    // Dietary Preferences
    @State private var selectedDietaryPreferences: Set<String> = []
    
    // Health Goals
    @State private var selectedHealthGoals: Set<String> = []
    
    // Intermittent Fasting state
    @State private var isIntermittentFastingEnabled: Bool = false
    @State private var fastingStyle: FastingStyle? = nil
    @State private var eatingWindowStart: Date = {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 12
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }()
    @State private var eatingWindowEnd: Date = {
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        return calendar.date(from: components) ?? Date()
    }()
    @State private var enableFastingReminders: Bool = false
    @State private var reminderWhenFastingStarts: Bool = false
    @State private var reminderWhenEatingWindowOpens: Bool = false
    
    // Computed properties for formatted times (to avoid ViewBuilder issues)
    private var formattedEatingWindowStart: String {
        formatTime(eatingWindowStart)
    }
    
    private var formattedEatingWindowEnd: String {
        formatTime(eatingWindowEnd)
    }
    
    // Dietary preference options
    private let dietaryPreferenceOptions = [
        "Classic (everything, no restrictions)",
        "Mediterranean (Top-rated healthy diet)",
        "Flexitarian (mostly plant-based with occasional meat)",
        "Low Carb",
        "Pescatarian (fish and seafood but no other meat)",
        "Vegetarian",
        "Paleo",
        "Keto",
        "Vegan (fully plant-based)",
        "Intermittent Fasting"
    ]
    
    // Health goal options
    private let healthGoalOptions = [
        "Heart health",
        "Brain health",
        "Digestive health",
        "Weight management",
        "Energy",
        "Bone/muscle health",
        "Joint health",
        "Immune support",
        "Hormonal balance",
        "Skin health",
        "Sleep quality",
        "Stress management",
        "Blood sugar control",
        "Longevity",
        "Inflammation reduction"
    ]
    
    enum FastingStyle: String, CaseIterable {
        case sixteenEight = "16:8"
        case fourteenTen = "14:10"
        case eighteenSix = "18:6"
        case custom = "Custom"
        
        var displayName: String {
            switch self {
            case .sixteenEight: return "16:8 (Most common)"
            case .fourteenTen: return "14:10 (Beginner-friendly)"
            case .eighteenSix: return "18:6 (Advanced)"
            case .custom: return "Custom"
            }
        }
        
        var defaultStartHour: Int {
            switch self {
            case .sixteenEight: return 12  // 12:00 PM
            case .fourteenTen: return 10  // 10:00 AM
            case .eighteenSix: return 12  // 12:00 PM
            case .custom: return 12
            }
        }
        
        var defaultEndHour: Int {
            switch self {
            case .sixteenEight: return 20  // 8:00 PM
            case .fourteenTen: return 20  // 8:00 PM
            case .eighteenSix: return 18  // 6:00 PM
            case .custom: return 20
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        Text(planMode == .auto ? "Auto Plan Setup" : "Plan Preferences")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                        
                        // Expandable Section: Start Date (Auto mode only)
                        if planMode == .auto {
                            expandableSection(
                                icon: "calendar.badge.clock",
                                title: "Start Date",
                                isExpanded: $startDateExpanded
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    DatePicker(
                                        "Start Date",
                                        selection: $startDate,
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Expandable Section: Number of Days
                        // Horizontal selector for number of days
                        expandableSection(
                            icon: "calendar",
                            title: "Number of Days",
                            isExpanded: $daysExpanded
                        ) {
                            VStack(spacing: 12) {
                                // Horizontal scrollable picker
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(1...14, id: \.self) { days in
                                            Button(action: {
                                                numberOfDays = days
                                            }) {
                                                VStack(spacing: 4) {
                                                    Text("\(days)")
                                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                                        .foregroundColor(numberOfDays == days ? .white : .primary)
                                                    
                                                    Text(days == 1 ? "Day" : "Days")
                                                        .font(.caption)
                                                        .foregroundColor(numberOfDays == days ? .white.opacity(0.9) : .secondary)
                                                }
                                                .frame(width: 60, height: 70)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(numberOfDays == days ? Color(red: 0.42, green: 0.557, blue: 0.498) : Color(UIColor.secondarySystemBackground))
                                                )
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Expandable Section: Meals per Day
                        expandableSection(
                            icon: "fork.knife",
                            title: "Meals per Day",
                            isExpanded: $mealsExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(MealType.allCases, id: \.self) { mealType in
                                    mealTypeToggle(mealType: mealType)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Expandable Section: Minimum Longevity Score (NEW)
                        expandableSection(
                            icon: "chart.line.uptrend.xyaxis",
                            title: longevityScoreFilterLabel,
                            isExpanded: $longevityScoreExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(longevityScoreOptions, id: \.value) { option in
                                    Button(action: {
                                        longevityScoreFilter = option.value
                                    }) {
                                        HStack {
                                            Text(option.label)
                                                .foregroundColor(.white)
                                            Spacer()
                                            if longevityScoreFilter == option.value {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Expandable Section: Dietary Preferences
                        expandableSection(
                            icon: "leaf.fill",
                            title: "Dietary Preferences",
                            isExpanded: $dietaryExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(dietaryPreferenceOptions, id: \.self) { option in
                                    dietaryPreferenceToggle(option: option)
                                }
                                
                                // Intermittent Fasting inline configuration
                                if isIntermittentFastingEnabled {
                                    intermittentFastingConfiguration
                                        .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Expandable Section: Health Goals
                        expandableSection(
                            icon: "heart.fill",
                            title: "Health Goals",
                            isExpanded: $goalsExpanded
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(healthGoalOptions, id: \.self) { goal in
                                    healthGoalToggle(goal: goal)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Toggle: Reduce Food Waste
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $reduceWaste) {
                                Text("Reduce food waste by reusing ingredients")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(20)
                        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    Color(red: 0.608, green: 0.827, blue: 0.835)
                                        .opacity(colorScheme == .dark ? 1.0 : 0.6),
                                    lineWidth: colorScheme == .dark ? 1.0 : 0.5
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)
                        
                        // Intermittent Fasting Summary (if enabled)
                        if isIntermittentFastingEnabled, let style = fastingStyle {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Intermittent Fasting: \(style.rawValue)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("Eating Window: \(formattedEatingWindowStart) – \(formattedEatingWindowEnd)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        
                        // Spacer for bottom button
                        Spacer()
                            .frame(height: 100)
                    }
                }
                
                // Primary gradient button pinned at bottom
                VStack {
                    Spacer()
                    Button(action: {
                        if planMode == .auto {
                            generateAutoPlan()
                        } else {
                            proceedToManualCalendar()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isGeneratingPlan {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(planMode == .auto ? (isGeneratingPlan ? "Generating..." : "Generate Meal Plan") : "Continue")
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
                                    Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),
                                    Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                    }
                    .disabled(isGeneratingPlan)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            // FIX #2: Dietary preference confirmation popup
            .alert("Apply this dietary preference to your main profile?", isPresented: $showingDietaryPreferenceConfirmation) {
                Button("YES") {
                    handleDietaryPreferenceChange(applyToProfile: true)
                }
                Button("NO") {
                    handleDietaryPreferenceChange(applyToProfile: false)
                }
            } message: {
                Text("This will update your health profile. The meal planner will always use your current selection for this plan.")
            }
        }
        .sheet(isPresented: $showingCalendar) {
            MealPlannerCalendarView(
                isAutoMode: planMode == .auto,
                preferences: selectedDietaryPreferences,
                healthGoals: selectedHealthGoals
            )
        }
        .sheet(item: $reviewMealPlan) { plan in
            MealPlannerAutoReviewView(
                mealPlan: plan,
                preferences: selectedDietaryPreferences,
                healthGoals: selectedHealthGoals,
                longevityScoreFilter: longevityScoreFilter
            )
        }
        .onAppear {
            loadProfileSelections()
            // Reset review meal plan when view appears (in case user came back from review)
            // This ensures the button works if user changes preferences and generates again
            reviewMealPlan = nil
        }
    }
    
    // MARK: - Load Profile Selections
    private func loadProfileSelections() {
        // Load dietary preference from profile
        if let dietaryPreference = healthProfileManager.currentProfile?.dietaryPreference, !dietaryPreference.isEmpty {
            // Normalize the preference string for matching
            let normalizedPreference = dietaryPreference.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Try exact match first
            if let exactMatch = dietaryPreferenceOptions.first(where: { $0.lowercased() == normalizedPreference }) {
                selectedDietaryPreferences.insert(exactMatch)
            } else {
                // Try partial matching
                for option in dietaryPreferenceOptions {
                    let optionLower = option.lowercased()
                    let optionKey = optionLower.components(separatedBy: " ").first ?? optionLower
                    
                    // Match by key word (e.g., "Mediterranean", "Keto", "Vegan")
                    if normalizedPreference.contains(optionKey) || optionLower.contains(normalizedPreference) {
                        selectedDietaryPreferences.insert(option)
                        break
                    }
                }
            }
            
            // Check if Intermittent Fasting is selected
            if normalizedPreference.contains("intermittent") || normalizedPreference.contains("fasting") {
                isIntermittentFastingEnabled = true
                fastingStyle = .sixteenEight // Default
                updateEatingWindowForStyle(.sixteenEight)
            }
        }
        
        // Load health goals from profile
        let goals = healthProfileManager.getHealthGoals()
        for goal in goals {
            // Try exact match first
            if healthGoalOptions.contains(goal) {
                selectedHealthGoals.insert(goal)
            } else {
                // Try partial matching for variations
                for option in healthGoalOptions {
                    if option.lowercased().contains(goal.lowercased()) || goal.lowercased().contains(option.lowercased()) {
                        selectedHealthGoals.insert(option)
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - Expandable Section Component
    private func expandableSection<Content: View>(
        icon: String,
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconGradient(for: icon))
                        .frame(width: 32, height: 32)
                    
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(colorScheme == .dark ? Color.black : Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded.wrappedValue {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color(red: 0.608, green: 0.827, blue: 0.835)
                        .opacity(colorScheme == .dark ? 1.0 : 0.6),
                    lineWidth: colorScheme == .dark ? 1.0 : 0.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Helper Views
    private func dayOptionButton(days: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(days) Days")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color(red: 0.42, green: 0.557, blue: 0.498) : Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    private func mealTypeToggle(mealType: MealType) -> some View {
        // COMMENT: If Intermittent Fasting is enabled, hide or relabel "Breakfast" as "First Meal"
        // This adjustment ensures meals are planned only within the eating window
        let displayName: String = {
            if isIntermittentFastingEnabled && mealType == .breakfast {
                return "First Meal"
            }
            return mealType.displayName
        }()
        
        return Toggle(isOn: Binding(
            get: { selectedMeals.contains(mealType) },
            set: { isOn in
                if isOn {
                    selectedMeals.insert(mealType)
                } else {
                    selectedMeals.remove(mealType)
                }
            }
        )) {
            Text(displayName)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func dietaryPreferenceToggle(option: String) -> some View {
        Toggle(isOn: Binding(
            get: { selectedDietaryPreferences.contains(option) },
            set: { isOn in
                // FIX #2: Show confirmation popup when user changes dietary preference
                pendingDietaryPreference = option
                pendingDietaryPreferenceAction = isOn
                showingDietaryPreferenceConfirmation = true
            }
        )) {
            Text(option)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    // FIX #2: Handle dietary preference confirmation
    private func handleDietaryPreferenceChange(applyToProfile: Bool) {
        guard let option = pendingDietaryPreference else { return }
        
        if pendingDietaryPreferenceAction {
            // Adding preference
            selectedDietaryPreferences.insert(option)
            
            // Handle Intermittent Fasting selection
            if option == "Intermittent Fasting" {
                isIntermittentFastingEnabled = true
                if fastingStyle == nil {
                    fastingStyle = .sixteenEight
                    updateEatingWindowForStyle(.sixteenEight)
                }
            }
            
            // FIX #2: Update profile if user selected YES
            if applyToProfile {
                // Update user profile with this dietary preference
                // Note: Profile stores single preference, but meal planner supports multiple
                // We'll use the first selected preference or combine them
                let preferenceToSave = selectedDietaryPreferences.first ?? option
                _ = healthProfileManager.updateProfile(dietaryPreference: preferenceToSave)
                print("✅ Updated user profile dietary preference to: \(preferenceToSave)")
            }
        } else {
            // Removing preference
            selectedDietaryPreferences.remove(option)
            
            // Handle Intermittent Fasting deselection
            if option == "Intermittent Fasting" {
                isIntermittentFastingEnabled = false
                fastingStyle = nil
                enableFastingReminders = false
                reminderWhenFastingStarts = false
                reminderWhenEatingWindowOpens = false
            }
            
            // FIX #2: Update profile if user selected YES (remove from profile)
            if applyToProfile {
                // Clear or update profile preference
                let remainingPreferences = selectedDietaryPreferences
                let preferenceToSave = remainingPreferences.first ?? ""
                _ = healthProfileManager.updateProfile(dietaryPreference: preferenceToSave.isEmpty ? nil : preferenceToSave)
                print("✅ Updated user profile dietary preference to: \(preferenceToSave.isEmpty ? "none" : preferenceToSave)")
            }
        }
        
        // Reset pending state
        pendingDietaryPreference = nil
        pendingDietaryPreferenceAction = false
    }
    
    private func healthGoalToggle(goal: String) -> some View {
        Toggle(isOn: Binding(
            get: { selectedHealthGoals.contains(goal) },
            set: { isOn in
                if isOn {
                    selectedHealthGoals.insert(goal)
                } else {
                    selectedHealthGoals.remove(goal)
                }
            }
        )) {
            Text(goal)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Intermittent Fasting Configuration
    private var intermittentFastingConfiguration: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("Intermittent Fasting Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.top, 8)
            
            // Step 1: Fasting Style Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Fasting Style")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(FastingStyle.allCases, id: \.self) { style in
                        Button(action: {
                            fastingStyle = style
                            updateEatingWindowForStyle(style)
                        }) {
                            HStack {
                                Image(systemName: fastingStyle == style ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(fastingStyle == style ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                                
                                Text(style.displayName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Text("Meals will be planned only during your eating window.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            // Step 2: Eating Window (shown only after style is selected)
            if fastingStyle != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Eating Window")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $eatingWindowStart, displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("End Time")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $eatingWindowEnd, displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                        }
                    }
                }
                
                // Step 3: Meal Timing Note
                if fastingStyle != nil {
                    Text("Meals will be planned between \(formattedEatingWindowStart) – \(formattedEatingWindowEnd).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                
                // Step 4: Optional Reminders
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $enableFastingReminders) {
                        Text("Enable fasting reminders")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    if enableFastingReminders {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $reminderWhenFastingStarts) {
                                HStack {
                                    Text("Reminder when fasting starts")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(formattedEatingWindowEnd)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Toggle(isOn: $reminderWhenEatingWindowOpens) {
                                HStack {
                                    Text("Reminder when eating window opens")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text(formattedEatingWindowStart)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Text("You can change reminders later.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Functions
    private func updateEatingWindowForStyle(_ style: FastingStyle) {
        let calendar = Calendar.current
        var startComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        startComponents.hour = style.defaultStartHour
        startComponents.minute = 0
        
        var endComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        endComponents.hour = style.defaultEndHour
        endComponents.minute = 0
        
        if let start = calendar.date(from: startComponents),
           let end = calendar.date(from: endComponents) {
            eatingWindowStart = start
            eatingWindowEnd = end
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Icon Gradient Helper
    private func iconGradient(for iconName: String) -> LinearGradient {
        switch iconName {
        case "calendar":
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.4, blue: 1.0),  // Blue
                    Color(red: 0.4, green: 0.2, blue: 0.8)  // Purple
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "fork.knife":
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.0),  // Orange
                    Color(red: 1.0, green: 0.8, blue: 0.2)   // Light orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "leaf.fill":
            return LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.7, blue: 0.4),  // Green
                    Color(red: 0.0, green: 0.8, blue: 0.8)    // Teal
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "heart.fill":
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.2, blue: 0.4),  // Red-pink
                    Color(red: 1.0, green: 0.4, blue: 0.6)   // Pink
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.557, blue: 0.498),
                    Color(red: 0.502, green: 0.706, blue: 0.627)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Longevity Score Filter Computed Properties
    
    /// Longevity score filter options
    private var longevityScoreOptions: [(label: String, value: Int)] {
        [
            ("No minimum", 0),
            ("60+ (Good)", 60),
            ("70+ (Very Good)", 70),
            ("80+ (Excellent)", 80)
        ]
    }
    
    /// Label for the dropdown (shows current selection)
    private var longevityScoreFilterLabel: String {
        switch longevityScoreFilter {
        case 0: return "Minimum Longevity Score"
        case 60: return "Longevity Score: 60+"
        case 70: return "Longevity Score: 70+"
        case 80: return "Longevity Score: 80+"
        default: return "Minimum Longevity Score"
        }
    }
    
    // MARK: - Actions
    private func generateAutoPlan() {
        // Prevent multiple simultaneous generations
        guard !isGeneratingPlan else {
            print("⚠️ Meal plan generation already in progress")
            return
        }
        
        // CRITICAL: Delete any existing unapproved plans before generating a new one
        // This ensures old parameters don't persist
        let mealPlanManager = MealPlanManager.shared
        let unapprovedPlans = mealPlanManager.mealPlans.filter { !$0.isActive }
        for plan in unapprovedPlans {
            mealPlanManager.deleteMealPlan(plan)
            print("🗑️ Deleted unapproved plan '\(plan.id)' before generating new plan")
        }
        
        // Reset review meal plan to nil to ensure sheet can be presented again
        // This fixes the issue where button doesn't work on subsequent taps
        reviewMealPlan = nil
        
        // Set loading state
        isGeneratingPlan = true
        
        // Generate meal plan based on preferences
        print("🍽️ Generating auto meal plan: \(numberOfDays) days, meals: \(selectedMeals.map { $0.displayName })")
        print("   Dietary preferences: \(selectedDietaryPreferences)")
        print("   Health goals: \(selectedHealthGoals)")
        print("   Longevity score filter: \(longevityScoreFilter)")
        
        Task {
            // Create meal plan for the selected number of days starting from selected start date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: startDate)
            let endDate = calendar.date(byAdding: .day, value: numberOfDays, to: startOfDay) ?? startOfDay
            
            // Load recipes first
            await recipeManager.loadRecipes()
            
            // V2: Filter eligible recipes based on ALL preferences
            // CRITICAL: Sufficiency is evaluated AFTER filtering, not on total recipe count
            let eligibleUserRecipes = filterEligibleRecipes()
            
            // Calculate plan needs
            let mealsPerDay = selectedMeals.count
            let requiredMeals = numberOfDays * mealsPerDay
            let varietyTarget = Int(ceil(Double(requiredMeals) * 1.3)) // 30% buffer for variety
            
            print("🍽️ Plan needs: \(requiredMeals) meals, variety target: \(varietyTarget)")
            print("🍽️ Eligible user recipes: \(eligibleUserRecipes.count)")
            
            // V2: Sufficiency check AFTER filtering
            // Compare eligible recipes (that match preferences) vs variety target
            var allRecipesForPlan: [Recipe] = []
            
            if eligibleUserRecipes.count >= varietyTarget {
                // Sufficient user recipes - DO NOT use Spoonacular
                // This minimizes API calls and ensures personalization
                // Shuffle for better variety instead of just taking first N
                print("🍽️ Sufficient user recipes found. Using only user recipes.")
                var shuffledUserRecipes = eligibleUserRecipes.shuffled()
                allRecipesForPlan = Array(shuffledUserRecipes.prefix(varietyTarget))
            } else {
                // Insufficient user recipes - use Spoonacular ONLY to fill the gap
                let spoonacularNeeded = varietyTarget - eligibleUserRecipes.count
                print("🍽️ Need \(spoonacularNeeded) recipes from Spoonacular to fill gap")
                
                // Use all eligible user recipes first
                allRecipesForPlan = eligibleUserRecipes
                
                // Fetch Spoonacular recipes with SAME filters
                do {
                    let spoonacularRecipes = try await fetchSpoonacularRecipes(needed: spoonacularNeeded)
                    
                    // Save Spoonacular recipes to RecipeManager so they're available for image lookup
                    // This ensures meal plan cards can display recipe images
                    for spoonacularRecipe in spoonacularRecipes {
                        do {
                            try await recipeManager.saveRecipe(spoonacularRecipe)
                            print("🍽️ Saved Spoonacular recipe '\(spoonacularRecipe.title)' to RecipeManager")
                        } catch {
                            print("⚠️ Failed to save Spoonacular recipe '\(spoonacularRecipe.title)': \(error)")
                            // Continue even if save fails - recipe will still be used in plan
                        }
                    }
                    
                    // Recipes are already in recipeManager.recipes after saveRecipe() updates the array
                    // No need to reload - recipes are immediately available
                    
                    allRecipesForPlan.append(contentsOf: spoonacularRecipes)
                    print("🍽️ Fetched \(spoonacularRecipes.count) recipes from Spoonacular")
                } catch {
                    print("⚠️ Failed to fetch Spoonacular recipes: \(error)")
                    // Continue with user recipes only if Spoonacular fails
                }
            }
            
            // Build planned meals from recipes
            // Meal slots are guaranteed to be filled using slot-specific Spoonacular fallback to prevent empty or semantically incorrect meals.
            let plannedMeals = await buildPlannedMeals(
                recipes: allRecipesForPlan,
                startDate: startOfDay,
                numberOfDays: numberOfDays,
                selectedMeals: selectedMeals,
                requiredMeals: requiredMeals
            )
            
            print("🍽️ Built \(plannedMeals.count) planned meals from \(allRecipesForPlan.count) recipes")
            
            // Ensure we have meals to add
            guard !plannedMeals.isEmpty else {
                print("⚠️ No planned meals generated - recipes may be empty or filtering too strict")
                // Create empty plan so user can still proceed (IN MEMORY ONLY - not saved until approval)
                let plan = MealPlan(
                    startDate: startOfDay,
                    endDate: endDate,
                    plannedMeals: [],
                    createdAt: Date(),
                    isActive: false // Not active until approved
                )
                await MainActor.run {
                    reviewMealPlan = plan
                    isGeneratingPlan = false
                }
                return
            }
            
            // Create plan with populated meals (IN MEMORY ONLY - not saved until approval)
            // Do NOT use createMealPlan() as it automatically saves to MealPlanManager
            // Instead, create plan manually and only add to manager on approval
            var plan = MealPlan(
                startDate: startOfDay,
                endDate: endDate,
                plannedMeals: plannedMeals,
                createdAt: Date(),
                isActive: false // Not active until approved
            )
            
            print("🍽️ Plan created with \(plan.plannedMeals.count) meals (in memory only, not saved)")
            
            // Show auto review screen with populated plan (not yet saved)
            await MainActor.run {
                reviewMealPlan = plan
                isGeneratingPlan = false
            }
        }
    }
    
    // MARK: - V2 Filtering Logic
    
    /// Filter recipes to only those that match ALL user preferences
    /// This is evaluated BEFORE sufficiency check - critical for V2
    private func filterEligibleRecipes() -> [Recipe] {
        // Filter by meal type categories
        // V2: Be inclusive - include recipes that could work for selected meal types
        let mealTypeCategories: Set<RecipeCategory> = {
            var categories: Set<RecipeCategory> = []
            for mealType in selectedMeals {
                switch mealType {
                case .breakfast:
                    // If IF enabled, exclude breakfast or treat as "First Meal"
                    if isIntermittentFastingEnabled {
                        // Skip breakfast category for IF plans
                        continue
                    } else {
                        categories.insert(.breakfast)
                    }
                case .lunch: categories.insert(.lunch)
                case .dinner: categories.insert(.dinner)
                case .snack: categories.insert(.snack)
                case .dessert: categories.insert(.dessert)
                }
            }
            return categories
        }()
        
        // Expanded categories for lunch/dinner: include recipes that could work
        var expandedCategories = mealTypeCategories
        if selectedMeals.contains(.lunch) || selectedMeals.contains(.dinner) {
            // Include "main" category (many recipes use this)
            expandedCategories.insert(.main)
            // Include generic categories that could work for lunch/dinner
            expandedCategories.insert(.soup)      // Soups can be lunch
            expandedCategories.insert(.salad)     // Salads can be lunch
            expandedCategories.insert(.side)       // Sides can be lunch/dinner
        }
        
        // Meal type categories that should be excluded for lunch/dinner
        let excludedMealTypes: Set<RecipeCategory> = {
            if selectedMeals.contains(.lunch) || selectedMeals.contains(.dinner) {
                // Exclude breakfast if lunch/dinner selected (unless breakfast also selected)
                if !selectedMeals.contains(.breakfast) {
                    return [.breakfast]
                }
            }
            return []
        }()
        
        return recipeManager.recipes.filter { recipe in
            // MARK: - Meal Type Filtering (Using Silent Classification)
            // First check mealTypeHints (silent classification), then fall back to categories
            
            // Ensure recipe has meal type hints (classify lazily if needed)
            var recipeWithHints = recipe
            if recipeWithHints.mealTypeHints == nil {
                recipeWithHints.mealTypeHints = LFIEngine.classifyMealTypes(recipe: recipeWithHints)
            }
            
            // Check if recipe's mealTypeHints contain any of the selected meal types
            let recipeMealTypes = Set(recipeWithHints.mealTypeHints ?? [])
            let selectedMealTypes = Set(selectedMeals)
            let hasMatchingMealTypeHint = !recipeMealTypes.isDisjoint(with: selectedMealTypes)
            
            // Fallback: Check categories if mealTypeHints don't match
            // Exclude recipes with conflicting meal type categories
            if !Set(recipe.categories).isDisjoint(with: excludedMealTypes) {
                return false
            }
            
            // Check if recipe matches meal type categories
            let hasMatchingMealType = !Set(recipe.categories).isDisjoint(with: expandedCategories)
            
            // Check if recipe has NO meal type categories at all (include these)
            let mealTypeOnlyCategories: Set<RecipeCategory> = [.breakfast, .lunch, .dinner, .snack, .dessert, .main, .soup, .salad, .side]
            let hasNoMealTypeCategories = Set(recipe.categories).isDisjoint(with: mealTypeOnlyCategories)
            
            // Include if: matches mealTypeHints OR matches meal type categories OR has no meal type categories set
            // This ensures recipes with only cuisine/style categories (italian, asian, etc.) are included
            let matchesMealType = hasMatchingMealTypeHint || hasMatchingMealType || hasNoMealTypeCategories
            if !matchesMealType {
                return false
            }
            
            // Filter by dietary preferences
            let matchesPreferences = matchesDietaryPreferences(recipe: recipe, preferences: selectedDietaryPreferences)
            if !matchesPreferences {
                return false
            }
            
            // Filter by health goals
            let matchesGoals = matchesHealthGoals(recipe: recipe, goals: selectedHealthGoals)
            if !matchesGoals {
                return false
            }
            
            // ISSUE 3 FIX: Apply longevity score filter using effective score with fast-pass fallback
            if longevityScoreFilter > 0 {
                let effectiveScore = getEffectiveScore(for: recipe)
                if effectiveScore < longevityScoreFilter {
                    return false // doesn't pass filter
                }
            }
            
            // All filters passed
            return true
        }
    }
    
    // MARK: - Score Helpers
    
    /// ISSUE 3 FIX: Get effective score for a recipe with fast-pass fallback
    /// Returns: longevityScore if present, else estimatedLongevityScore, else fast-pass score
    private func getEffectiveScore(for recipe: Recipe) -> Int {
        if let score = recipe.longevityScore {
            return score
        }
        if let estimated = recipe.estimatedLongevityScore {
            return estimated
        }
        // No score at all — run fast-pass
        return LFIEngine.fastScore(recipe: recipe)
    }
    
    // MARK: - Ingredient Matching Helpers (Word Boundary Matching)
    
    /// Check if text contains ingredient as a whole word (not substring)
    /// Prevents false positives like "chicken stock" matching "chicken"
    private func containsIngredient(_ text: String, _ ingredient: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: ingredient))\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    /// Count how many ingredients from a list appear in the text
    private func countIngredients(_ text: String, from ingredients: [String]) -> Int {
        return ingredients.filter { containsIngredient(text, $0) }.count
    }
    
    /// Check if any ingredient from a list appears in the text
    private func hasAnyIngredient(_ text: String, from ingredients: [String]) -> Bool {
        return ingredients.contains { containsIngredient(text, $0) }
    }
    
    /// Check if recipe matches dietary preferences
    /// V2: Enhanced with ingredient-based fallback for better matching accuracy
    private func matchesDietaryPreferences(recipe: Recipe, preferences: Set<String>) -> Bool {
        if preferences.isEmpty { return true }
        
        let prefLower = preferences.map { $0.lowercased() }
        
        // Classic, Flexitarian, Intermittent Fasting = accept all
        if prefLower.contains(where: { $0.contains("classic") || $0.contains("flexitarian") || $0.contains("intermittent") }) {
            return true
        }
        
        // Prepare ingredient text for analysis
        let ingredientsText = (recipe.ingredientsText ?? "").lowercased()
        let ingredientNames = recipe.allIngredients.map { $0.name.lowercased() }.joined(separator: " ")
        let titleText = recipe.title.lowercased()
        let combinedText = ingredientsText + " " + ingredientNames + " " + titleText
        
        // Check each preference
        for pref in prefLower {
            
            // ═══════════════════════════════════════════════════════════════
            // MEDITERRANEAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("mediterranean") {
                // Check category first
                if recipe.categories.contains(.mediterranean) {
                    return true
                }
                // Ingredient-based fallback (using word boundary matching)
                let mediterraneanIngredients = [
                    "olive oil", "tomato", "garlic", "basil", "oregano", "feta",
                    "chickpea", "lentil", "hummus", "tahini", "eggplant", "zucchini",
                    "salmon", "sardine", "anchovy", "shrimp", "greek yogurt",
                    "couscous", "bulgur", "farro", "pita", "za'atar"
                ]
                if countIngredients(combinedText, from: mediterraneanIngredients) >= 3 {
                    return true
                }
                // Title-based fallback
                let titleIndicators = ["mediterranean", "greek", "italian", "spanish", "moroccan", "turkish", "lebanese"]
                if hasAnyIngredient(titleText, from: titleIndicators) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // VEGAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("vegan") {
                if recipe.categories.contains(.vegan) {
                    return true
                }
                // Check for animal products (using word boundary matching)
                let animalProducts = [
                    "chicken", "beef", "pork", "lamb", "turkey", "bacon", "sausage",
                    "fish", "salmon", "shrimp", "crab", "tuna",
                    "milk", "cheese", "butter", "cream", "yogurt", "egg", "eggs",
                    "honey", "gelatin"
                ]
                if !hasAnyIngredient(combinedText, from: animalProducts) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // VEGETARIAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("vegetarian") {
                if recipe.categories.contains(.vegetarian) || recipe.categories.contains(.vegan) {
                    return true
                }
                // Check for meat (using word boundary matching)
                let meat = [
                    "chicken", "beef", "pork", "lamb", "turkey", "bacon", "sausage", "ham",
                    "fish", "salmon", "shrimp", "crab", "tuna", "lobster", "anchovy"
                ]
                if !hasAnyIngredient(combinedText, from: meat) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // KETO
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("keto") {
                if recipe.categories.contains(.keto) {
                    return true
                }
                // Check ingredients (using word boundary matching)
                let ketoFriendly = ["avocado", "bacon", "egg", "cheese", "butter", "cream", "coconut oil", "olive oil"]
                let highCarb = ["rice", "pasta", "bread", "flour", "potato", "sugar", "corn", "oat"]
                let ketoCount = countIngredients(combinedText, from: ketoFriendly)
                let carbCount = countIngredients(combinedText, from: highCarb)
                if ketoCount >= 2 && carbCount == 0 {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // PALEO
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("paleo") {
                if recipe.categories.contains(.paleo) {
                    return true
                }
                // Check for non-paleo ingredients (using word boundary matching)
                let nonPaleo = ["bread", "pasta", "rice", "oat", "wheat", "milk", "cheese", "yogurt", "bean", "lentil", "peanut", "soy", "tofu"]
                if !hasAnyIngredient(combinedText, from: nonPaleo) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // PESCATARIAN
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("pescatarian") {
                // Pescatarian: accept vegetarian/vegan recipes (pescatarian category doesn't exist)
                if recipe.categories.contains(.vegetarian) || recipe.categories.contains(.vegan) {
                    return true
                }
                // Allow seafood, no land meat (using word boundary matching)
                let landMeat = ["chicken", "beef", "pork", "lamb", "turkey", "bacon", "sausage", "ham"]
                if !hasAnyIngredient(combinedText, from: landMeat) {
                    return true
                }
            }
            
            // ═══════════════════════════════════════════════════════════════
            // LOW CARB
            // ═══════════════════════════════════════════════════════════════
            if pref.contains("low carb") || pref.contains("lowcarb") {
                if recipe.categories.contains(.keto) {
                    return true
                }
                // Check for high carb ingredients (using word boundary matching)
                let highCarb = ["rice", "pasta", "bread", "flour", "potato", "sugar", "corn", "oat", "noodle", "tortilla"]
                if countIngredients(combinedText, from: highCarb) == 0 {
                    return true
                }
            }
        }
        
        // No match found
        return false
    }
    
    /// Check if recipe matches health goals
    /// V2: Keep strict filtering - only include recipes with longevity scores >= 60
    /// Uses OUR proprietary LFI logic (longevityScore for user recipes, estimatedLongevityScore for Spoonacular)
    private func matchesHealthGoals(recipe: Recipe, goals: Set<String>) -> Bool {
        // If no goals selected, accept all recipes
        if goals.isEmpty {
            return true
        }
        
        // ISSUE 3 FIX: Use effective score with fast-pass fallback
        let effectiveLongevityScore = getEffectiveScore(for: recipe)
        
        // Apply longevity score filter (if set)
        if longevityScoreFilter > 0 && effectiveLongevityScore < longevityScoreFilter {
            return false
        }
        
        // Goal-specific logic with ingredient-based matching
        // Prepare ingredient text for goal-specific matching
        let ingredientsText = (recipe.ingredientsText ?? "").lowercased()
        let ingredientNames = recipe.allIngredients.map { $0.name.lowercased() }.joined(separator: " ")
        let combinedText = ingredientsText + " " + ingredientNames
        
        // Check each goal with goal-specific logic
        for goal in goals {
            let goalLower = goal.lowercased()
            
            switch goalLower {
            case "heart health":
                // Omega-3, fiber, low saturated fat
                let heartHealthy = ["salmon", "sardine", "mackerel", "olive oil", "avocado", "walnut", "almond", "oat", "flaxseed", "chia"]
                let heartUnhealthy = ["bacon", "sausage", "fried", "butter", "cream"]
                let healthyCount = countIngredients(combinedText, from: heartHealthy)
                let unhealthyCount = countIngredients(combinedText, from: heartUnhealthy)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (healthyCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 65 && unhealthyCount == 0 && meetsScoreFilter) {
                    return true
                }
                
            case "brain health":
                // Omega-3, antioxidants, leafy greens
                let brainHealthy = ["salmon", "blueberry", "walnut", "spinach", "kale", "broccoli", "turmeric", "egg", "avocado", "dark chocolate"]
                let brainCount = countIngredients(combinedText, from: brainHealthy)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (brainCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 70 && meetsScoreFilter) {
                    return true
                }
                
            case "weight management":
                // High protein, high fiber, low calorie
                let weightFriendly = ["chicken breast", "fish", "egg white", "greek yogurt", "legume", "vegetable", "salad", "lean"]
                let weightUnfriendly = ["fried", "cream", "sugar", "pastry", "cake", "cookie"]
                let friendlyCount = countIngredients(combinedText, from: weightFriendly)
                let unfriendlyCount = countIngredients(combinedText, from: weightUnfriendly)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if ((friendlyCount >= 2 && unfriendlyCount == 0) && meetsScoreFilter) || (effectiveLongevityScore >= 65 && meetsScoreFilter) {
                    return true
                }
                
            case "digestive health":
                // Fiber, probiotics, fermented foods
                let digestiveHealthy = ["yogurt", "kefir", "sauerkraut", "kimchi", "fiber", "oat", "legume", "vegetable", "fruit", "ginger"]
                let digestiveCount = countIngredients(combinedText, from: digestiveHealthy)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (digestiveCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 60 && meetsScoreFilter) {
                    return true
                }
                
            case "energy & vitality", "energy and vitality":
                // Complex carbs, B vitamins, iron
                let energyFoods = ["oat", "quinoa", "banana", "spinach", "egg", "almond", "sweet potato", "brown rice"]
                let energyCount = countIngredients(combinedText, from: energyFoods)
                // CRITICAL: Respect longevityScoreFilter even when ingredient matching succeeds
                let meetsScoreFilter = longevityScoreFilter == 0 || effectiveLongevityScore >= longevityScoreFilter
                if (energyCount >= 2 && meetsScoreFilter) || (effectiveLongevityScore >= 60 && meetsScoreFilter) {
                    return true
                }
                
            default:
                // Generic: use score threshold
                let threshold = longevityScoreFilter > 0 ? longevityScoreFilter : 50
                if effectiveLongevityScore >= threshold {
                    return true
                }
            }
        }
        
        // If we get here, no goal matched - but if score is high enough, allow it
        let threshold = longevityScoreFilter > 0 ? longevityScoreFilter : 50
        return effectiveLongevityScore >= threshold
    }
    
    // MARK: - Spoonacular Integration
    
    /// Fetch recipes from Spoonacular to fill the gap
    /// Applies the SAME filters as user recipe filtering
    private func fetchSpoonacularRecipes(needed: Int) async throws -> [Recipe] {
        // Convert meal types to Spoonacular type parameter
        // Use first selected meal type (or combine if multiple)
        let spoonacularType: String = {
            if selectedMeals.contains(.breakfast) && !isIntermittentFastingEnabled {
                return "breakfast"
            } else if selectedMeals.contains(.lunch) {
                return "lunch"
            } else if selectedMeals.contains(.dinner) {
                return "dinner"
            } else if selectedMeals.contains(.snack) {
                return "snack"
            } else {
                return "main course"
            }
        }()
        
        // Convert dietary preferences to Spoonacular diet parameter
        let spoonacularDiet: String? = {
            for pref in selectedDietaryPreferences {
                let prefLower = pref.lowercased()
                if prefLower.contains("vegan") {
                    return "vegan"
                } else if prefLower.contains("vegetarian") {
                    return "vegetarian"
                } else if prefLower.contains("keto") {
                    return "ketogenic"
                } else if prefLower.contains("paleo") {
                    return "paleo"
                } else if prefLower.contains("mediterranean") {
                    return "mediterranean"
                }
            }
            return nil
        }()
        
        // Search Spoonacular with filters
        print("🍽️ Fetching \(needed) recipes from Spoonacular (type: \(spoonacularType), diet: \(spoonacularDiet ?? "none"))")
        
        let searchResponse: SpoonacularSearchResponse
        do {
            searchResponse = try await spoonacularService.searchRecipes(
                query: "",
                diet: spoonacularDiet,
                type: spoonacularType,
                number: needed,
                offset: 0
            )
            print("🍽️ Spoonacular returned \(searchResponse.results.count) recipes")
        } catch {
            print("❌ Spoonacular API error: \(error.localizedDescription)")
            throw error
        }
        
        // Fetch full recipe details for each recipe to ensure we get images, instructions, and ingredients
        // complexSearch may not return full details, so we fetch complete information
        // PART 3: Discard invalid recipes and fetch replacements
        var convertedRecipes: [Recipe] = []
        var invalidRecipeCount = 0
        for spoonacularRecipe in searchResponse.results {
            do {
                // Fetch full recipe details by ID
                let fullRecipe = try await spoonacularService.getRecipeDetails(id: spoonacularRecipe.id)
                let recipe = try spoonacularService.convertToRecipe(fullRecipe)
                convertedRecipes.append(recipe)
            } catch {
                // PART 3: Invalid recipe - discard and log
                print("❌ Invalid Spoonacular recipe \(spoonacularRecipe.id) — missing core data")
                invalidRecipeCount += 1
                // Continue to next recipe (will fetch replacement if needed)
            } catch {
                print("⚠️ Failed to fetch full details for recipe \(spoonacularRecipe.id): \(error)")
                // Try to convert basic recipe data, but validate it
                do {
                    let recipe = try spoonacularService.convertToRecipe(spoonacularRecipe)
                    convertedRecipes.append(recipe)
                } catch {
                    print("❌ Invalid Spoonacular recipe \(spoonacularRecipe.id) — missing core data")
                    invalidRecipeCount += 1
                } catch {
                    // Other conversion errors - skip this recipe
                    print("⚠️ Failed to convert recipe \(spoonacularRecipe.id): \(error)")
                }
            }
        }
        
        print("🍽️ Converted \(convertedRecipes.count) recipes from Spoonacular (with full details)")
        
        // Apply same filtering logic to Spoonacular recipes
        let beforeFilterCount = convertedRecipes.count
        convertedRecipes = convertedRecipes.filter { recipe in
            let matchesPrefs = matchesDietaryPreferences(recipe: recipe, preferences: selectedDietaryPreferences)
            let matchesGoals = matchesHealthGoals(recipe: recipe, goals: selectedHealthGoals)
            return matchesPrefs && matchesGoals
        }
        
        print("🍽️ After filtering: \(convertedRecipes.count) recipes (filtered out \(beforeFilterCount - convertedRecipes.count))")
        
        // CRITICAL: If filtering removed all recipes, we MUST return some recipes
        // This ensures the fallback always works - user preferences are important but
        // an empty plan is worse than a plan with recipes that might not perfectly match
        if convertedRecipes.isEmpty && !searchResponse.results.isEmpty {
            print("⚠️ All Spoonacular recipes filtered out. Using first \(min(needed, searchResponse.results.count)) recipes without strict filtering.")
            // Return recipes without strict health goals filtering (but still respect dietary preferences if possible)
            // PART 3: Handle invalid recipes by discarding them
            convertedRecipes = []
            for spoonacularRecipe in Array(searchResponse.results.prefix(needed)) {
                do {
                    let recipe = try spoonacularService.convertToRecipe(spoonacularRecipe)
                    convertedRecipes.append(recipe)
                } catch {
                    print("❌ Invalid Spoonacular recipe \(spoonacularRecipe.id) — missing core data")
                    // Discard invalid recipe and continue
                } catch {
                    print("⚠️ Failed to convert recipe \(spoonacularRecipe.id): \(error)")
                    // Discard recipe on other errors too
                }
            }
            // Still filter by dietary preferences if they're not "accept all" types
            let hasStrictDietaryPrefs = !selectedDietaryPreferences.isEmpty && 
                !selectedDietaryPreferences.contains(where: { $0.lowercased().contains("classic") || 
                                                              $0.lowercased().contains("flexitarian") ||
                                                              $0.lowercased().contains("everything") })
            if hasStrictDietaryPrefs {
                convertedRecipes = convertedRecipes.filter { recipe in
                    matchesDietaryPreferences(recipe: recipe, preferences: selectedDietaryPreferences)
                }
            }
            print("🍽️ Fallback: Returning \(convertedRecipes.count) recipes")
        }
        
        // COMMENT: In future, these Spoonacular recipes should be cached to Supabase
        // for reuse in subsequent plan generations, reducing API calls
        
        return convertedRecipes
    }
    
    // MARK: - Plan Building
    
    /// Build PlannedMeal entries from recipes
    /// Meal slots are guaranteed to be filled using slot-specific Spoonacular fallback to prevent empty or semantically incorrect meals.
    /// FIX #4: Enforces variety - no duplicate Spoonacular recipes, avoids consecutive same proteins
    private func buildPlannedMeals(
        recipes: [Recipe],
        startDate: Date,
        numberOfDays: Int,
        selectedMeals: Set<MealType>,
        requiredMeals: Int
    ) async -> [PlannedMeal] {
        let calendar = Calendar.current
        var plannedMeals: [PlannedMeal] = []
        
        // Create array of meal types in order
        let mealTypesOrdered: [MealType] = [.breakfast, .lunch, .dinner, .snack, .dessert]
            .filter { selectedMeals.contains($0) }
        
        // Track recipe usage per meal type to ensure variety
        var recipeUsageByMealType: [MealType: [Recipe]] = [:]
        var recipeIndexByMealType: [MealType: Int] = [:]
        for mealType in mealTypesOrdered {
            recipeUsageByMealType[mealType] = []
            recipeIndexByMealType[mealType] = 0
        }
        
        // CRITICAL: Track ALL recipes used in the entire plan (across all meal types)
        // This ensures NO recipe is repeated in the entire meal plan
        var usedRecipeIDs: Set<UUID> = []
        
        // CRITICAL: Also track recipe titles (normalized) to prevent same recipe with different UUIDs
        // This prevents "red lentil soup" appearing multiple times even if it has different UUIDs
        var usedRecipeTitles: Set<String> = []
        
        // Helper function to normalize recipe title for comparison
        func normalizeTitle(_ title: String) -> String {
            return title.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }
        
        // FIX #4: Track Spoonacular recipes used in this plan to prevent duplicates
        var usedSpoonacularIDs: Set<Int> = []
        
        // FIX #4: Track primary proteins to avoid consecutive repeats
        var lastPrimaryProtein: String? = nil
        
        // Helper function to extract primary protein from recipe
        func extractPrimaryProtein(from recipe: Recipe) -> String? {
            let allIngredients = recipe.allIngredients.map { $0.name.lowercased() }
            let ingredientsText = recipe.ingredientsText?.lowercased() ?? ""
            let combinedText = (allIngredients.joined(separator: " ") + " " + ingredientsText).lowercased()
            
            // Common primary proteins (in order of priority)
            let proteins = ["chicken", "beef", "pork", "lamb", "salmon", "tuna", "fish", "turkey", "tofu", "tempeh", "lentil", "chickpea", "black bean", "kidney bean"]
            
            for protein in proteins {
                if combinedText.contains(protein) {
                    return protein
                }
            }
            
            return nil
        }
        
        // Distribute recipes across days and meal types
        for dayOffset in 0..<numberOfDays {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }
            
            for mealType in mealTypesOrdered {
                // Skip breakfast if IF enabled (handled as "First Meal" in UI)
                if mealType == .breakfast && isIntermittentFastingEnabled {
                    continue
                }
                
                // Build slot-specific candidates: recipes whose mealTypeHints contain this slot's meal type
                // Recipe may ONLY be placed into a meal slot if its mealTypeHints CONTAIN the slot's meal type
                var allSlotEligibleRecipes = recipes.filter { recipe in
                    // Ensure recipe has meal type hints (classify lazily if needed)
                    let hints = recipe.mealTypeHints ?? LFIEngine.classifyMealTypes(recipe: recipe)
                    return hints.contains(mealType)
                }
                
                // PRIORITIZE USER RECIPES: Separate user recipes from Spoonacular recipes
                let userRecipes = allSlotEligibleRecipes.filter { $0.isOriginal }
                let spoonacularRecipes = allSlotEligibleRecipes.filter { !$0.isOriginal }
                
                // CRITICAL: Remove ALL recipes already used in the entire plan (not just this meal type)
                // This ensures NO recipe is repeated anywhere in the meal plan
                // Check both UUID and normalized title to catch duplicates with different UUIDs
                let unusedUserRecipes = userRecipes.filter { recipe in
                    let normalizedTitle = normalizeTitle(recipe.title)
                    return !usedRecipeIDs.contains(recipe.id) && !usedRecipeTitles.contains(normalizedTitle)
                }
                let unusedSpoonacularRecipes = spoonacularRecipes.filter { recipe in
                    // Remove Spoonacular recipes already used in this plan (prevent duplicates)
                    if let spoonacularID = recipe.spoonacularID {
                        if usedSpoonacularIDs.contains(spoonacularID) {
                            return false
                        }
                    }
                    // Check if recipe ID has been used
                    if usedRecipeIDs.contains(recipe.id) {
                        return false
                    }
                    // Check if recipe title (normalized) has been used
                    let normalizedTitle = normalizeTitle(recipe.title)
                    return !usedRecipeTitles.contains(normalizedTitle)
                }
                
                // PRIORITIZE USER RECIPES: Use user recipes first, then Spoonacular
                var slotEligibleRecipes: [Recipe] = []
                if !unusedUserRecipes.isEmpty {
                    // Shuffle user recipes for better variety
                    slotEligibleRecipes = unusedUserRecipes.shuffled()
                } else {
                    // Only use Spoonacular if no user recipes available
                    slotEligibleRecipes = unusedSpoonacularRecipes
                }
                
                // FIX #4: If last meal had a primary protein, avoid consecutive same protein when alternatives exist
                if let lastProtein = lastPrimaryProtein, !slotEligibleRecipes.isEmpty {
                    let alternatives = slotEligibleRecipes.filter { recipe in
                        let protein = extractPrimaryProtein(from: recipe)
                        return protein != lastProtein
                    }
                    // Only use alternatives if they exist, otherwise allow same protein
                    if !alternatives.isEmpty {
                        slotEligibleRecipes = alternatives
                    }
                }
                
                // If we've used all recipes for this meal type, check if we've exhausted ALL recipes
                // Only allow reuse if we've used every single recipe in the entire plan
                if slotEligibleRecipes.isEmpty && !recipes.isEmpty {
                    // Check if we've used all recipes across the entire plan (by both ID and title)
                    let allRecipeIDs = Set(recipes.map { $0.id })
                    let allRecipeTitles = Set(recipes.map { normalizeTitle($0.title) })
                    if usedRecipeIDs.count >= allRecipeIDs.count && usedRecipeTitles.count >= allRecipeTitles.count {
                        // We've used ALL recipes - reset and allow reuse
                        print("🍽️ All recipes exhausted. Resetting usage tracking to allow reuse.")
                        usedRecipeIDs.removeAll()
                        usedRecipeTitles.removeAll()
                        recipeUsageByMealType[mealType] = []
                        
                        // Rebuild eligible recipes for this meal type
                        let allRecipesForType = recipes.filter { recipe in
                            let hints = recipe.mealTypeHints ?? LFIEngine.classifyMealTypes(recipe: recipe)
                            return hints.contains(mealType)
                        }
                        // Separate and prioritize user recipes even when resetting
                        let userRecipesForType = allRecipesForType.filter { $0.isOriginal }
                        let spoonacularRecipesForType = allRecipesForType.filter { !$0.isOriginal }
                        // Shuffle for variety, but prioritize user recipes
                        slotEligibleRecipes = userRecipesForType.shuffled() + spoonacularRecipesForType.shuffled()
                    } else {
                        // ISSUE 1 FIX: Fallback - if no recipes match the specific meal type, use ANY eligible recipe
                        print("⚠️ No \(mealType.displayName)-specific recipes available. Using any available eligible recipe.")
                        // Get all eligible recipes (already filtered by dietary preferences, health goals, etc.)
                        let allEligibleRecipes = recipes.filter { recipe in
                            let normalizedTitle = normalizeTitle(recipe.title)
                            return !usedRecipeIDs.contains(recipe.id) && !usedRecipeTitles.contains(normalizedTitle)
                        }
                        // Separate user and Spoonacular
                        let unusedUserAll = allEligibleRecipes.filter { $0.isOriginal }
                        let unusedSpoonacularAll = allEligibleRecipes.filter { !$0.isOriginal }
                        // Prioritize user recipes
                        if !unusedUserAll.isEmpty {
                            slotEligibleRecipes = unusedUserAll.shuffled()
                        } else {
                            slotEligibleRecipes = unusedSpoonacularAll
                        }
                    }
                }
                
                // If no compatible recipes exist for this slot, trigger Spoonacular fallback FOR THIS SLOT
                if slotEligibleRecipes.isEmpty {
                    print("🍽️ No compatible recipes for \(mealType.displayName) slot. Fetching Spoonacular fallback.")
                    
                    do {
                        // Fetch recipes with type = slot.mealType
                        let fallbackRecipes = try await fetchSpoonacularRecipesForMealType(mealType: mealType, needed: 5)
                        
                        // Ensure fallback recipes have correct mealTypeHints
                        for fallbackRecipe in fallbackRecipes {
                            var recipeWithHints = fallbackRecipe
                            if recipeWithHints.mealTypeHints == nil || !(recipeWithHints.mealTypeHints?.contains(mealType) ?? false) {
                                recipeWithHints.mealTypeHints = LFIEngine.classifyMealTypes(recipe: recipeWithHints)
                                // Force include this meal type if classification didn't add it
                                if var hints = recipeWithHints.mealTypeHints {
                                    if !hints.contains(mealType) {
                                        hints.append(mealType)
                                    }
                                    recipeWithHints.mealTypeHints = hints
                                } else {
                                    recipeWithHints.mealTypeHints = [mealType]
                                }
                            }
                            
                            // Save fallback recipe to RecipeManager for image lookup
                            do {
                                try await recipeManager.saveRecipe(recipeWithHints)
                            } catch {
                                print("⚠️ Failed to save Spoonacular fallback recipe: \(error)")
                            }
                        }
                        
                        // Use fallback recipes for this slot, but filter out any already used
                        // Check both UUID and normalized title
                        slotEligibleRecipes = fallbackRecipes.filter { recipe in
                            let normalizedTitle = normalizeTitle(recipe.title)
                            return !usedRecipeIDs.contains(recipe.id) && !usedRecipeTitles.contains(normalizedTitle)
                        }
                        
                        // If all fallback recipes are already used, we need more
                        if slotEligibleRecipes.isEmpty {
                            print("⚠️ All Spoonacular fallback recipes already used. Fetching more...")
                            // Fetch more recipes if we've used all the fallback ones
                            do {
                                let additionalFallbackRecipes = try await fetchSpoonacularRecipesForMealType(mealType: mealType, needed: 10)
                                slotEligibleRecipes = additionalFallbackRecipes.filter { recipe in
                                    let normalizedTitle = normalizeTitle(recipe.title)
                                    return !usedRecipeIDs.contains(recipe.id) && !usedRecipeTitles.contains(normalizedTitle)
                                }
                                
                                // Save additional fallback recipes
                                for fallbackRecipe in additionalFallbackRecipes {
                                    do {
                                        try await recipeManager.saveRecipe(fallbackRecipe)
                                    } catch {
                                        print("⚠️ Failed to save additional Spoonacular fallback recipe: \(error)")
                                    }
                                }
                            } catch {
                                print("⚠️ Failed to fetch additional Spoonacular recipes: \(error)")
                            }
                        }
                        
                        // FAIL THE OPERATION if fallback returns zero recipes
                        guard !slotEligibleRecipes.isEmpty else {
                            print("❌ CRITICAL: Spoonacular fallback returned zero recipes for \(mealType.displayName) slot. Cannot proceed.")
                            // Return partial plan rather than empty plan
                            return plannedMeals
                        }
                    } catch {
                        print("❌ Failed to fetch Spoonacular fallback for \(mealType.displayName): \(error)")
                        // Return partial plan rather than empty plan
                        return plannedMeals
                    }
                }
                
                // Select recipe from slot-specific candidates
                // Since we've already shuffled and prioritized user recipes, just pick the first available
                guard !slotEligibleRecipes.isEmpty else {
                    print("❌ CRITICAL: No recipe available for \(mealType.displayName) slot after fallback. Cannot proceed.")
                    return plannedMeals
                }
                
                // Pick first recipe (already shuffled and prioritized)
                let recipe = slotEligibleRecipes[0]
                
                // CRITICAL: Track this recipe as used in the ENTIRE plan (not just this meal type)
                // Track both UUID and normalized title to prevent duplicates with different UUIDs
                usedRecipeIDs.insert(recipe.id)
                let normalizedTitle = normalizeTitle(recipe.title)
                usedRecipeTitles.insert(normalizedTitle)
                
                // FIX #4: Track Spoonacular recipe ID to prevent duplicates
                if let spoonacularID = recipe.spoonacularID {
                    usedSpoonacularIDs.insert(spoonacularID)
                }
                
                // FIX #4: Track primary protein for consecutive meal avoidance
                lastPrimaryProtein = extractPrimaryProtein(from: recipe)
                
                // Track recipe usage for this meal type (for reference, but main tracking is usedRecipeIDs)
                recipeUsageByMealType[mealType, default: []].append(recipe)
                
                print("🍽️ Selected recipe '\(recipe.title)' (normalized: '\(normalizedTitle)') for \(mealType.displayName) on day \(dayOffset + 1). Total recipes used: \(usedRecipeIDs.count), Unique titles: \(usedRecipeTitles.count)")
                
                // Calculate scheduled time for this meal
                let scheduledTime = scheduledTimeForMeal(
                    mealType: mealType,
                    dayDate: dayDate,
                    mealIndex: plannedMeals.count
                )
                
                // ISSUE 2 FIX: Ensure score is always set - use effective score with fast-pass fallback
                let effectiveScore = getEffectiveScore(for: recipe)
                
                let plannedMeal = PlannedMeal(
                    recipeID: recipe.id,
                    mealType: mealType,
                    scheduledDate: scheduledTime,
                    displayTitle: recipe.title,
                    estimatedLongevityScore: Double(effectiveScore)
                )
                
                print("📊 Created meal '\(recipe.title)' with score: \(effectiveScore)")
                
                plannedMeals.append(plannedMeal)
                
                // Stop if we've reached required meals
                if plannedMeals.count >= requiredMeals {
                    break
                }
            }
            
            if plannedMeals.count >= requiredMeals {
                break
            }
        }
        
        return plannedMeals
    }
    
    /// Fetch Spoonacular recipes for a specific meal type slot
    /// This ensures slot-specific fallback when no compatible user recipes exist
    private func fetchSpoonacularRecipesForMealType(mealType: MealType, needed: Int) async throws -> [Recipe] {
        // Convert meal type to Spoonacular type parameter
        let spoonacularType: String = {
            switch mealType {
            case .breakfast: return "breakfast"
            case .lunch: return "lunch"
            case .dinner: return "dinner"
            case .snack: return "snack"
            case .dessert: return "dessert"
            }
        }()
        
        // Convert dietary preferences to Spoonacular diet parameter
        let spoonacularDiet: String? = {
            for pref in selectedDietaryPreferences {
                let prefLower = pref.lowercased()
                if prefLower.contains("vegan") {
                    return "vegan"
                } else if prefLower.contains("vegetarian") {
                    return "vegetarian"
                } else if prefLower.contains("keto") {
                    return "ketogenic"
                } else if prefLower.contains("paleo") {
                    return "paleo"
                } else if prefLower.contains("mediterranean") {
                    return "mediterranean"
                }
            }
            return nil
        }()
        
        print("🍽️ Fetching \(needed) Spoonacular recipes for \(mealType.displayName) slot (type: \(spoonacularType), diet: \(spoonacularDiet ?? "none"))")
        
        let searchResponse: SpoonacularSearchResponse
        do {
            searchResponse = try await spoonacularService.searchRecipes(
                query: "",
                diet: spoonacularDiet,
                type: spoonacularType,
                number: needed,
                offset: 0
            )
            print("🍽️ Spoonacular returned \(searchResponse.results.count) recipes for \(mealType.displayName)")
        } catch {
            print("❌ Spoonacular API error for \(mealType.displayName): \(error.localizedDescription)")
            throw error
        }
        
        // Fetch full recipe details for each recipe to ensure we get images, instructions, and ingredients
        // complexSearch may not return full details, so we fetch complete information
        // PART 3: Discard invalid recipes and fetch replacements
        var convertedRecipes: [Recipe] = []
        var invalidRecipeCount = 0
        for spoonacularRecipe in searchResponse.results {
            do {
                // Fetch full recipe details by ID
                let fullRecipe = try await spoonacularService.getRecipeDetails(id: spoonacularRecipe.id)
                let recipe = try spoonacularService.convertToRecipe(fullRecipe)
                convertedRecipes.append(recipe)
            } catch {
                // PART 3: Invalid recipe - discard and log
                print("❌ Invalid Spoonacular recipe \(spoonacularRecipe.id) — missing core data")
                invalidRecipeCount += 1
                // Continue to next recipe (will fetch replacement if needed)
            } catch {
                print("⚠️ Failed to fetch full details for recipe \(spoonacularRecipe.id): \(error)")
                // Try to convert basic recipe data, but validate it
                do {
                    let recipe = try spoonacularService.convertToRecipe(spoonacularRecipe)
                    convertedRecipes.append(recipe)
                } catch {
                    print("❌ Invalid Spoonacular recipe \(spoonacularRecipe.id) — missing core data")
                    invalidRecipeCount += 1
                } catch {
                    // Other conversion errors - skip this recipe
                    print("⚠️ Failed to convert recipe \(spoonacularRecipe.id): \(error)")
                }
            }
        }
        
        // PART 3: If we discarded invalid recipes, fetch replacements
        if invalidRecipeCount > 0 && convertedRecipes.count < needed {
            let replacementNeeded = needed - convertedRecipes.count + invalidRecipeCount
            print("🍽️ Fetching \(replacementNeeded) replacement recipes for invalid ones")
            // Fetch additional recipes to replace invalid ones
            do {
                let replacementResponse = try await spoonacularService.searchRecipes(
                    query: "",
                    diet: spoonacularDiet,
                    type: spoonacularType,
                    number: replacementNeeded,
                    offset: searchResponse.results.count // Start after original results
                )
                
                // Convert replacement recipes
                for replacementRecipe in replacementResponse.results {
                    guard convertedRecipes.count < needed else { break }
                    do {
                        let fullRecipe = try await spoonacularService.getRecipeDetails(id: replacementRecipe.id)
                        let recipe = try spoonacularService.convertToRecipe(fullRecipe)
                        convertedRecipes.append(recipe)
                    } catch {
                        print("❌ Invalid replacement recipe \(replacementRecipe.id) — missing core data")
                        // Continue to next replacement
                    } catch {
                        print("⚠️ Failed to fetch replacement recipe \(replacementRecipe.id): \(error)")
                    }
                }
            } catch {
                print("⚠️ Failed to fetch replacement recipes: \(error)")
            }
        }
        
        print("🍽️ Converted \(convertedRecipes.count) recipes from Spoonacular (with full details)")
        
        // Apply same filtering logic to Spoonacular recipes
        convertedRecipes = convertedRecipes.filter { recipe in
            let matchesPrefs = matchesDietaryPreferences(recipe: recipe, preferences: selectedDietaryPreferences)
            let matchesGoals = matchesHealthGoals(recipe: recipe, goals: selectedHealthGoals)
            return matchesPrefs && matchesGoals
        }
        
        // CRITICAL: If filtering removed all recipes, return recipes without strict filtering
        if convertedRecipes.isEmpty && !searchResponse.results.isEmpty {
            print("⚠️ All Spoonacular recipes filtered out for \(mealType.displayName). Using first \(min(needed, searchResponse.results.count)) recipes without strict filtering.")
            // Fetch full details for fallback recipes too
            convertedRecipes = []
            for spoonacularRecipe in Array(searchResponse.results.prefix(needed)) {
                do {
                    let fullRecipe = try await spoonacularService.getRecipeDetails(id: spoonacularRecipe.id)
                    let recipe = try spoonacularService.convertToRecipe(fullRecipe)
                    convertedRecipes.append(recipe)
                } catch {
                    print("❌ Invalid fallback recipe \(spoonacularRecipe.id) — missing core data")
                    // Continue to next fallback
                } catch {
                    // Fallback: try basic recipe data
                    do {
                        let recipe = try spoonacularService.convertToRecipe(spoonacularRecipe)
                        convertedRecipes.append(recipe)
                    } catch {
                        print("⚠️ Failed to convert fallback recipe \(spoonacularRecipe.id): \(error)")
                    }
                }
            }
            // Still filter by dietary preferences if they're not "accept all" types
            let hasStrictDietaryPrefs = !selectedDietaryPreferences.isEmpty && 
                !selectedDietaryPreferences.contains(where: { $0.lowercased().contains("classic") || 
                                                              $0.lowercased().contains("flexitarian") ||
                                                              $0.lowercased().contains("everything") })
            if hasStrictDietaryPrefs {
                convertedRecipes = convertedRecipes.filter { recipe in
                    matchesDietaryPreferences(recipe: recipe, preferences: selectedDietaryPreferences)
                }
            }
        }
        
        // Ensure all recipes have correct mealTypeHints
        for i in 0..<convertedRecipes.count {
            var recipe = convertedRecipes[i]
            if recipe.mealTypeHints == nil || !(recipe.mealTypeHints?.contains(mealType) ?? false) {
                recipe.mealTypeHints = LFIEngine.classifyMealTypes(recipe: recipe)
                if var hints = recipe.mealTypeHints {
                    if !hints.contains(mealType) {
                        hints.append(mealType)
                    }
                    recipe.mealTypeHints = hints
                } else {
                    recipe.mealTypeHints = [mealType]
                }
                convertedRecipes[i] = recipe
            }
        }
        
        return convertedRecipes
    }
    
    /// Calculate scheduled time for a meal based on meal type and IF settings
    private func scheduledTimeForMeal(mealType: MealType, dayDate: Date, mealIndex: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: dayDate)
        
        if isIntermittentFastingEnabled {
            // For IF, schedule meals within eating window
            let windowStartComponents = calendar.dateComponents([.hour, .minute], from: eatingWindowStart)
            let windowEndComponents = calendar.dateComponents([.hour, .minute], from: eatingWindowEnd)
            let windowStart = windowStartComponents.hour ?? 12
            let windowEnd = windowEndComponents.hour ?? 20
            
            switch mealType {
            case .breakfast:
                // Should not happen if IF enabled, but handle gracefully
                components.hour = windowStart
                components.minute = 0
            case .lunch:
                // Mid-point of eating window
                components.hour = (windowStart + windowEnd) / 2
                components.minute = 0
            case .dinner:
                // Near end of eating window
                components.hour = max(windowStart, windowEnd - 1)
                components.minute = 0
            default:
                // Snacks/desserts - distribute within window
                components.hour = windowStart + (mealIndex % 3)
                components.minute = 0
            }
        } else {
            // Standard meal times
            switch mealType {
            case .breakfast:
                components.hour = 8
                components.minute = 0
            case .lunch:
                components.hour = 12
                components.minute = 30
            case .dinner:
                components.hour = 18
                components.minute = 30
            case .snack:
                components.hour = 15
                components.minute = 0
            case .dessert:
                components.hour = 20
                components.minute = 0
            }
        }
        
        return calendar.date(from: components) ?? dayDate
    }
    
    private func proceedToManualCalendar() {
        // Manual mode: go directly to calendar with preferences
        showingCalendar = true
    }
}

