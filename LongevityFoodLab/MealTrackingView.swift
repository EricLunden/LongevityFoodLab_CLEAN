import SwiftUI
import CoreData
import Charts

extension Notification.Name {
    static let cameFromMealTracker = Notification.Name("cameFromMealTracker")
    static let addMealToTracker = Notification.Name("addMealToTracker")
}

struct MealTrackingView: View {
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @StateObject private var mealStorageManager = MealStorageManager.shared
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var selectedDate = Date()
    @State private var selectedMeal: TrackedMeal?
    @State private var selectedRecipe: Recipe?
    @State private var suggestedRecipe: Recipe?
    @State private var dailyMeals: [TrackedMeal] = []
    @State private var dailyStats: DailyStats?
    @State private var nutritionalSummaryExpanded = false
    @State private var micronutrientsExpanded = false
    @State private var insightsExpanded = false
    @State private var aiEncouragementText = ""
    @State private var isMealAnalysisExpanded = false
    @State private var isAIAnalysisLoading = false
    @State private var showingHealthGoals = false
    
    // Caching for AI analysis
    @State private var cachedAIAnalysis: String = ""
    @State private var lastAnalysisMealCount: Int = 0
    @State private var lastAnalysisDate: Date = Date()
    @State private var needsAnalysisUpdate = false
    @State private var showingSelectMealsView = false
    @State private var dateRangeOption: DateRangeOption = .today
    @State private var showingDatePicker = false
    @State private var motivationalMessage: String = ""
    @State private var motivationalMessageCategory: MessageCategory = .good
    @State private var isGeneratingMessage = false
    @State private var suggestedMeal: TrackedMeal?
    @State private var messageCacheTimestamp: Date?
    @State private var lastMessages: [String] = []
    @State private var mealSortOption: MealSortOption = .dateNewest
    @State private var mealFilterOption: MealFilterOption = .all
    @State private var viewMode: ViewMode = .list
    @State private var isEditing = false
    @State private var selectedMealIDs: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var showingSideMenu = false
    @State private var longevityGraphExpanded = false
    @State private var selectedGraphPeriod: GraphPeriod = .week
    @State private var scoreHistoryData: [ScoreDataPoint] = []
    @State private var timelineData: [DailyTimelineData] = []
    @State private var mealToDelete: TrackedMeal?
    @State private var showingDeleteConfirmationForCarousel = false
    @State private var nutritionSummaryText: String = ""
    @State private var isLoadingNutritionSummary: Bool = false
    @State private var lastNutritionSummaryMealCount: Int = 0
    @State private var lastNutritionSummaryDate: Date?
    @State private var micronutrientTargets: [String: Double] = [:]
    @State private var selectedMicronutrientForTarget: Micronutrient?
    @State private var targetInputValue: String = ""
    @State private var targetMode: TargetMode = .standardRDA
    @State private var showingTargetModeSelection = false
    @State private var showingCustomDisclaimer = false
    @State private var customDisclaimerAccepted = false
    
    // Macro target state variables
    @State private var macroTargets: [String: Double] = [:]
    @AppStorage("macroTargetMode") private var macroTargetModeRaw: String = TargetMode.standardRDA.rawValue
    @State private var showingMacroTargetModeSelection = false
    
    // Computed property for type-safe access to macro target mode
    private var macroTargetMode: TargetMode {
        get { TargetMode(rawValue: macroTargetModeRaw) ?? .standardRDA }
        set { macroTargetModeRaw = newValue.rawValue }
    }
    @State private var showingMacroCustomDisclaimer = false
    @State private var macroCustomDisclaimerAccepted = false
    @State private var selectedMacroForTarget: String?
    @State private var macroTargetInputValue: String = ""
    @State private var showingMacroSelection = false
    @State private var showingMicroSelection = false
    @State private var showingServingSizeEditor = false
    @State private var servingSizeInput: String = "Daily Totals"
    @State private var selectedMacros: Set<String> = []
    @State private var selectedMicronutrientsForSelection: Set<String> = []
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: Int
    
    enum TargetMode: String, Codable {
        case standardRDA = "standardRDA"
        case custom = "custom"
    }
    
    enum GraphPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
    }
    
    enum ViewMode {
        case list
        case grid
    }
    
    enum MealSortOption: String, CaseIterable {
        case dateNewest = "Most Recent"
        case scoreHighest = "Highest First"
        case scoreLowest = "Lowest First"
        case nameAZ = "A-Z"
        case nameZA = "Z-A"
        case dateOldest = "Oldest"
    }
    
    enum MealFilterOption: String, CaseIterable {
        case all = "All Meals"
        case highScore = "High Score (80+)"
        case mediumScore = "Medium Score (60-79)"
        case lowScore = "Low Score (<60)"
    }
    
    enum DateRangeOption: String, CaseIterable {
        case today = "Today"
        case yesterday = "Yesterday"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case pickDate = "Pick A Date"
    }
    
    // MARK: - Logo Header Section
    private var logoHeaderSection: some View {
        Image("LogoHorizontal")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 37)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.top, -8)
    }
    
    // MARK: - Today's Meals (filtered based on selected date range)
    private var filteredTodayMeals: [TrackedMeal] {
        let calendar = Calendar.current
        let today = Date()
        
        switch dateRangeOption {
        case .today:
            return dailyMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        case .yesterday:
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
                return dailyMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: yesterday) }
            }
            return []
        case .last7Days:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            return dailyMeals.filter { $0.timestamp >= sevenDaysAgo && $0.timestamp <= today }
        case .last30Days:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            return dailyMeals.filter { $0.timestamp >= thirtyDaysAgo && $0.timestamp <= today }
        case .pickDate:
            return dailyMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
        }
    }
    
    // MARK: - Today's Meals Carousel Box
    private var todaysMealsCarouselBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon and dropdown title (centered)
            HStack(spacing: 12) {
                Spacer()
                
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.42, green: 0.557, blue: 0.498),
                                Color(red: 0.3, green: 0.7, blue: 0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Menu {
                    Button(action: {
                        dateRangeOption = .today
                        loadDailyMeals()
                    }) {
                        HStack {
                            Text("Today")
                            if dateRangeOption == .today {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: {
                        dateRangeOption = .yesterday
                        loadDailyMeals()
                    }) {
                        HStack {
                            Text("Yesterday")
                            if dateRangeOption == .yesterday {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: {
                        dateRangeOption = .last7Days
                        loadDailyMeals()
                    }) {
                        HStack {
                            Text("Last 7 Days")
                            if dateRangeOption == .last7Days {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: {
                        dateRangeOption = .last30Days
                        loadDailyMeals()
                    }) {
                        HStack {
                            Text("Last 30 Days")
                            if dateRangeOption == .last30Days {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: {
                        dateRangeOption = .pickDate
                        showingDatePicker = true
                        loadDailyMeals()
                    }) {
                        HStack {
                            Text("Pick A Date")
                            if dateRangeOption == .pickDate {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(dateRangeDisplayTextForHeader)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(colorScheme == .dark ? .white : .secondary)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .white : .secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Carousel of meal cards
            if filteredTodayMeals.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text(emptyStateMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(filteredTodayMeals) { meal in
                            TodayMealCard(
                                meal: meal,
                                isDeleteSelected: mealToDelete?.id == meal.id,
                                onTap: {
                                    selectedMeal = meal
                                },
                                onDeleteTap: {
                                    mealToDelete = meal
                                    showingDeleteConfirmationForCarousel = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
                .confirmationDialog(
                    "Delete meal?",
                    isPresented: $showingDeleteConfirmationForCarousel,
                    presenting: mealToDelete
                ) { meal in
                    Button("Yes", role: .destructive) {
                        deleteMeal(meal)
                        mealToDelete = nil
                    }
                    Button("No", role: .cancel) {
                        mealToDelete = nil
                    }
                } message: { meal in
                    Text("Are you sure you want to delete '\(meal.name)'?")
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(16)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                    // Logo Header (matching Grocery Scores)
                    logoHeaderSection
                    
                    // Today's Meals Carousel Box
                    todaysMealsCarouselBox
                    
                    // Add A Meal Button - moved below Today's Meals
                    addMealButton
                    
                    // Daily Stats Summary (wrapped in box) - moved under carousel
                    if let stats = dailyStats {
                        dailyStatsViewBox(stats, onScrollToMeals: {
                            proxy.scrollTo("mealsSection", anchor: .top)
                        })
                    }
                    
                    // Padding between Add A Meal and Insights
                    Spacer()
                        .frame(height: 10)
                    
                    // Insights Dropdown (formerly motivational message) - moved below Add A Meal
                    insightsSection
                    
                    // Padding between Insights and Meal Analysis
                    Spacer()
                        .frame(height: 10)
                    
                    // AI Encouragement Paragraph (existing)
                    aiEncouragementSection
                    
                    // Padding between Meal Analysis and Nutritional Summary
                    Spacer()
                        .frame(height: 10)
                    
                    // Science Summary Dropdown
                    
                    // Nutritional Summary Dropdown - moved below Add A Meal
                    nutritionalSummarySection
                    
                    // Padding between Nutritional Summary and Micronutrients
                    Spacer()
                        .frame(height: 10)
                    
                    // Micronutrients Dropdown
                    micronutrientsSection
                    
                    // Padding above date modal
                    Spacer()
                        .frame(height: 8)
                    
                    // Date Range Header with Dropdown
                    dateRangeHeader
                    
                    // Padding below date modal
                    Spacer()
                        .frame(height: 8)
                    
                    // Meals List or Grid
                    mealsList
                        .id("mealsSection")
                    
                    // Edit/Sort/View Toggle Section
                    if !dailyMeals.isEmpty {
                        if viewMode == .grid {
                            // Grid view: List icon on left, Sort centered, Grid icon on right
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
                                
                                // Sort Picker (centered)
                                HStack {
                                    Text("Sort by:")
                                        .font(.headline)
                                        .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                                    
                                    Picker("Sort", selection: $mealSortOption) {
                                        ForEach(MealSortOption.allCases, id: \.self) { option in
                                            Text(option.rawValue).tag(option)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .font(.caption)
                                }
                                
                                Spacer()
                                
                                // Grid Icon (right)
                                Button(action: {
                                    viewMode = .grid
                                }) {
                                    Image(systemName: "square.grid.3x3")
                                        .font(.title3)
                                        .foregroundColor(viewMode == .grid ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                                }
                                .padding(.trailing, 20)
                            }
                            .padding(.bottom, 8)
                        } else {
                            // List view: List icon on left, Sort centered, Grid icon on right
                            viewToggleSectionWithSort
                        }
                    }
                    }
                }
            }
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
            .onAppear {
                loadDailyMeals()
                calculateDailyStats()
                generateMotivationalMessage()
                generateAIEncouragement()
            }
            .onChange(of: selectedDate) { _ in
                loadDailyMeals()
                calculateDailyStats()
                generateMotivationalMessage()
                generateAIEncouragement()
            }
            .onChange(of: dateRangeOption) { _ in
                if dateRangeOption == .pickDate {
                    showingDatePicker = true
                } else {
                    updateDateForRange()
                    loadDailyMeals()
                    calculateDailyStats()
                    // Clear cache and regenerate message for new time frame
                    messageCacheTimestamp = nil
                    generateMotivationalMessage()
                }
            }
            .onChange(of: mealSortOption) { _ in
                loadDailyMeals()
            }
            .onChange(of: mealFilterOption) { _ in
                loadDailyMeals()
                calculateDailyStats()
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $selectedDate, onDateSelected: {
                    // Update dateRangeOption based on selected date
                    updateDateRangeOptionForSelectedDate()
                    showingDatePicker = false
                    loadDailyMeals()
                    calculateDailyStats()
                    generateMotivationalMessage()
                })
            }
            .onReceive(NotificationCenter.default.publisher(for: .healthProfileUpdated)) { _ in
                calculateDailyStats()
            }
            .onReceive(NotificationCenter.default.publisher(for: .addMealToTracker)) { notification in
                if let analysis = notification.object as? FoodAnalysis {
                    addMealToTracker(analysis)
                    // Regenerate message when new meal is added
                    generateMotivationalMessage()
                }
            }
            .onChange(of: mealStorageManager.trackedMeals.count) { oldCount, newCount in
                // Refresh meals list when meals are added/removed from anywhere
                if newCount != oldCount {
                    print("🍽️ MealTrackingView: Meal count changed from \(oldCount) to \(newCount), refreshing...")
                    loadDailyMeals()
                    calculateDailyStats()
                    generateMotivationalMessage()
                    // Recalculate graph if it's expanded
                    if longevityGraphExpanded {
                        calculateScoreHistory()
                    }
                }
            }
            .onChange(of: dailyMeals.count) { _ in
                // Regenerate message when meals change
                generateMotivationalMessage()
                // Recalculate timeline data when meals change
                if longevityGraphExpanded {
                    calculateTimelineData()
                }
            }
            .sheet(item: $selectedMeal) { meal in
                MealDetailsView(meal: meal)
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showingHealthGoals) {
                ProfileSettingsView()
            }
            .onChange(of: showingHealthGoals) { isShowing in
                if !isShowing {
                    // Refresh stats when health goals sheet is dismissed
                    calculateDailyStats()
                }
            }
            .onChange(of: showingSelectMealsView) { isShowing in
                if !isShowing {
                    // Refresh meals list when SelectMealsView sheet closes (meal may have been added)
                    loadDailyMeals()
                    calculateDailyStats()
                    generateMotivationalMessage()
                }
            }
        }
    }
    
    // MARK: - Date Range Header with Dropdown
    private var dateRangeHeader: some View {
        HStack {
            Spacer()
            
            Menu {
                ForEach(DateRangeOption.allCases, id: \.self) { option in
                    Button(action: {
                        dateRangeOption = option
                        if option == .pickDate {
                            showingDatePicker = true
                        }
                    }) {
                        HStack {
                            Text(option.rawValue)
                            if option == dateRangeOption {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(dateRangeDisplayText)
                        .font(.headline)
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var dateRangeDisplayText: String {
        let calendar = Calendar.current
        let today = Date()
        
        // If dateRangeOption is .pickDate and selectedDate is not today, show formatted date
        if dateRangeOption == .pickDate && !calendar.isDate(selectedDate, inSameDayAs: today) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: selectedDate)
        }
        
        // Otherwise, show the option's raw value
        return dateRangeOption.rawValue
    }
    
    private var dateRangeDisplayTextForHeader: String {
        // For the header, show a user-friendly title
        switch dateRangeOption {
        case .today:
            return "Today's Meals"
        case .yesterday:
            return "Yesterday's Meals"
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .pickDate:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: selectedDate)
        }
    }
    
    private var emptyStateMessage: String {
        switch dateRangeOption {
        case .today:
            return "No meals tracked today"
        case .yesterday:
            return "No meals tracked yesterday"
        case .last7Days:
            return "No meals tracked in the last 7 days"
        case .last30Days:
            return "No meals tracked in the last 30 days"
        case .pickDate:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "No meals tracked on \(formatter.string(from: selectedDate))"
        }
    }
    
    private func updateDateForRange() {
        let calendar = Calendar.current
        switch dateRangeOption {
        case .today:
            selectedDate = Date()
        case .last7Days:
            // Show today, but aggregate last 7 days
            selectedDate = Date()
        case .last30Days:
            selectedDate = Date()
        case .yesterday:
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) {
                selectedDate = yesterday
            }
        case .pickDate:
            showingDatePicker = true
        }
    }
    
    private func updateDateRangeOptionForSelectedDate() {
        let calendar = Calendar.current
        let today = Date()
        
        // Check if selected date is today
        if calendar.isDate(selectedDate, inSameDayAs: today) {
            dateRangeOption = .today
        } else {
            // For custom dates, keep as .pickDate but the picker will show the formatted date
            // We'll handle the display in the picker itself
            dateRangeOption = .pickDate
        }
    }
    
    // MARK: - Daily Stats View (wrapped in box with drop shadow)
    private func dailyStatsViewBox(_ stats: DailyStats, onScrollToMeals: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("\(stats.mealCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: onScrollToMeals) {
                        Text("Total Meals")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Circle format for Avg Score (matching meal cards below)
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(scoreGradient(Int(stats.averageScore)))
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        Text(String(format: "%.0f", stats.averageScore))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("Avg Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                MealStatCard(
                    title: "Health Goals",
                    value: "\(stats.goalsMet)",
                    icon: "target",
                    color: .green,
                    onTap: {
                        showingHealthGoals = true
                    },
                    subtitle: "Update"
                )
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black : Color.white)
        .cornerRadius(16)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
    
    // MARK: - View Toggle Section
    private var viewToggleSection: some View {
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
        .padding(.top, 5)  // 5pt padding above icons
        .padding(.bottom, 5)  // 5pt padding below icons
    }
    
    private var viewToggleSectionWithSort: some View {
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
            
            // Sort Picker (centered)
            HStack {
                Text("Sort by:")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.0, green: 0.478, blue: 1.0))
                
                Picker("Sort", selection: $mealSortOption) {
                    ForEach(MealSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }
            
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
        .padding(.top, 5)  // 5pt padding above icons
        .padding(.bottom, 8)  // 8pt padding below to match grid view
    }
    
    private var mealsList: some View {
        Group {
            if dailyMeals.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No meals tracked for this day")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Search for food on the main screen and add it to your meal tracker")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                if viewMode == .grid {
                    mealGridView
                } else {
                    mealListView
                }
            }
        }
    }
    
    // MARK: - Meal List View
    private var mealListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(dailyMeals) { meal in
                MealListRowView(meal: meal, onTap: {
                    // Set the meal directly - this will trigger the sheet
                    selectedMeal = meal
                }, onDelete: {
                    deleteMeal(meal)
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)  // 6pt padding from view toggle
    }
    
    // MARK: - Meal Grid View
    private var mealGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(dailyMeals) { meal in
                MealGridCardView(
                    meal: meal,
                    isEditing: isEditing,
                    isSelected: selectedMealIDs.contains(meal.id),
                    onTap: {
                        selectedMeal = meal
                    },
                    onToggleSelection: {
                        if selectedMealIDs.contains(meal.id) {
                            selectedMealIDs.remove(meal.id)
                        } else {
                            selectedMealIDs.insert(meal.id)
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)  // 6pt padding from view toggle
        .confirmationDialog("Delete Meals", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedMeals()
            }
            Button("Cancel", role: .cancel) {
                // Deselect all items and exit edit mode
                selectedMealIDs.removeAll()
                isEditing = false
            }
        } message: {
            Text("Are you sure you want to delete \(selectedMealIDs.count) meal\(selectedMealIDs.count == 1 ? "" : "s")?")
        }
    }
    
    // MARK: - Edit Button Text Computed Property
    private var editButtonText: String {
        if !selectedMealIDs.isEmpty {
            return "Delete"
        } else if isEditing {
            return "Cancel"
        } else {
            return "Edit"
        }
    }
    
    // MARK: - Delete Selected Meals
    private func deleteSelectedMeals() {
        for mealID in selectedMealIDs {
            if let meal = dailyMeals.first(where: { $0.id == mealID }) {
                deleteMeal(meal)
            }
        }
        selectedMealIDs.removeAll()
        // Stay in edit mode after deletion
        isEditing = true
    }
    
    private func changeDate(_ days: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
    }
    
    private func loadDailyMeals() {
        // Load meals based on selected date range
        let calendar = Calendar.current
        let allMeals = mealStorageManager.getAllMeals()
        let today = Date()
        
        let filteredMeals: [TrackedMeal]
        
        switch dateRangeOption {
        case .today:
            // Get meals for today
            filteredMeals = allMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
        case .yesterday:
            // Get meals for yesterday
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
                filteredMeals = allMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: yesterday) }
            } else {
                filteredMeals = []
            }
        case .last7Days:
            // Get meals from last 7 days
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            filteredMeals = allMeals.filter { $0.timestamp >= sevenDaysAgo && $0.timestamp <= today }
        case .last30Days:
            // Get meals from last 30 days
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            filteredMeals = allMeals.filter { $0.timestamp >= thirtyDaysAgo && $0.timestamp <= today }
        case .pickDate:
            // Get meals for the selected date
            filteredMeals = allMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
        }
        
        // Apply filter
        let filtered = applyMealFilter(filteredMeals)
        
        // Apply sort
        dailyMeals = applyMealSort(filtered)
        
        print("🍽️ MealTrackingView: Loaded \(dailyMeals.count) meals for \(dateRangeOption.rawValue)")
    }
    
    private func applyMealFilter(_ meals: [TrackedMeal]) -> [TrackedMeal] {
        switch mealFilterOption {
        case .all:
            return meals
        case .highScore:
            return meals.filter { $0.healthScore >= 80 }
        case .mediumScore:
            return meals.filter { $0.healthScore >= 60 && $0.healthScore < 80 }
        case .lowScore:
            return meals.filter { $0.healthScore < 60 }
        }
    }
    
    private func applyMealSort(_ meals: [TrackedMeal]) -> [TrackedMeal] {
        switch mealSortOption {
        case .dateNewest:
            return meals.sorted { $0.timestamp > $1.timestamp }
        case .dateOldest:
            return meals.sorted { $0.timestamp < $1.timestamp }
        case .scoreHighest:
            return meals.sorted { $0.healthScore > $1.healthScore }
        case .scoreLowest:
            return meals.sorted { $0.healthScore < $1.healthScore }
        case .nameAZ:
            return meals.sorted { $0.name < $1.name }
        case .nameZA:
            return meals.sorted { $0.name > $1.name }
        }
    }
    
    private func calculateDailyStats() {
        guard !dailyMeals.isEmpty else {
            dailyStats = nil
            return
        }
        
        let totalScore = dailyMeals.reduce(0) { $0 + $1.healthScore }
        let averageScore = totalScore / Double(dailyMeals.count)
        let userHealthGoals = healthProfileManager.getHealthGoals()
        let goalsMet = userHealthGoals.count
        
        dailyStats = DailyStats(
            mealCount: dailyMeals.count,
            averageScore: averageScore,
            goalsMet: goalsMet
        )
    }
    
    // MARK: - Motivational Message Generation
    private func generateMotivationalMessage() {
        // Check cache (4 hours)
        if let cacheTime = messageCacheTimestamp,
           Date().timeIntervalSince(cacheTime) < 14400, // 4 hours
           !motivationalMessage.isEmpty {
            print("🤖 MealTrackingView: Using cached motivational message")
            return
        }
        
        guard !dailyMeals.isEmpty else {
            motivationalMessage = ""
            return
        }
        
        let averageScore = Int(dailyStats?.averageScore ?? 0)
        
        // Determine category
        let category: MessageCategory
        if averageScore >= 80 {
            category = .exceptional
        } else if averageScore >= 70 {
            category = .great
        } else if averageScore >= 60 {
            category = .good
        } else {
            category = .needsEncouragement
        }
        
        motivationalMessageCategory = category
        isGeneratingMessage = true
        
        // Get time frame description
        let timeFrameDescription = getTimeFrameDescription()
        
        // Get saved recipes with 4-5 star ratings for suggestions
        let favoriteRecipes = recipeManager.recipes.filter { recipe in
            recipe.rating >= 4 && recipe.rating <= 5
        }
        
        // Get top meals from past 7 days as fallback
        let allMeals = mealStorageManager.getAllMeals()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentMeals = allMeals.filter { $0.timestamp >= sevenDaysAgo }
            .sorted { $0.healthScore > $1.healthScore }
            .prefix(5)
        
        // Find best suggestion: prefer favorite recipes, fallback to high-scoring meals
        if category == .needsEncouragement {
            if let favoriteRecipe = favoriteRecipes.randomElement() {
                suggestedRecipe = favoriteRecipe
                suggestedMeal = nil // Clear meal suggestion when using recipe
            } else if let bestMeal = recentMeals.first {
                suggestedMeal = bestMeal
                suggestedRecipe = nil
            } else {
                suggestedMeal = nil
                suggestedRecipe = nil
            }
        } else {
            suggestedMeal = nil
            suggestedRecipe = nil
        }
        
        // Generate message based on category
        Task {
            do {
                let message = try await AIService.shared.generateMotivationalMessage(
                    averageScore: averageScore,
                    category: messageCategoryToAIServiceCategory(category),
                    mealCount: dailyMeals.count,
                    todayMeals: dailyMeals,
                    suggestedMeal: suggestedMeal,
                    suggestedRecipe: suggestedRecipe,
                    timeFrameDescription: timeFrameDescription,
                    previousMessages: lastMessages
                )
                
                await MainActor.run {
                    motivationalMessage = message
                    isGeneratingMessage = false
                    messageCacheTimestamp = Date()
                    
                    // Update last messages (keep last 3)
                    lastMessages.append(message)
                    if lastMessages.count > 3 {
                        lastMessages.removeFirst()
                    }
                }
            } catch {
                print("🤖 MealTrackingView: Error generating motivational message: \(error)")
                await MainActor.run {
                    motivationalMessage = generateFallbackMotivationalMessage(averageScore: averageScore, category: category)
                    isGeneratingMessage = false
                    messageCacheTimestamp = Date()
                }
            }
        }
    }
    
    private func getTimeFrameDescription() -> String {
        switch dateRangeOption {
        case .today:
            return "today"
        case .last7Days:
            return "the last 7 days"
        case .last30Days:
            return "the last 30 days"
        case .yesterday:
            return "yesterday"
        case .pickDate:
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            return "on \(dateFormatter.string(from: selectedDate))"
        }
    }
    
    private func messageCategoryToAIServiceCategory(_ category: MessageCategory) -> MessageCategory {
        switch category {
        case .exceptional: return .exceptional
        case .great: return .great
        case .good: return .good
        case .needsEncouragement: return .needsEncouragement
        }
    }
    
    private func generateFallbackMotivationalMessage(averageScore: Int, category: MessageCategory) -> String {
        switch category {
        case .exceptional:
            return "You absolutely crushed it today! This is the kind of eating that makes your body sing. Your future self is already thanking you!"
        case .great:
            return "'Take care of your body. It's the only place you have to live.' —Jim Rohn. Today you truly honored that home with smart choices!"
        case .good:
            if let bestMeal = dailyMeals.max(by: { $0.healthScore < $1.healthScore }) {
                return "Pretty solid day overall! You're building good habits even if every choice wasn't perfect. Your \(bestMeal.name) (scored \(Int(bestMeal.healthScore))) shows you know exactly how to eat well when you focus."
            }
            return "Pretty solid day! You're doing better than you think. Keep making those small improvements!"
        case .needsEncouragement:
            if let suggested = suggestedMeal {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                return "Hey friend, today was more about comfort than nutrition, and that's totally okay! We all have those days. Your \(suggested.name) scored \(Int(suggested.healthScore)) - maybe revisit that winner tomorrow?"
            }
            return "Hey, rough food day? We've all been there. Tomorrow's a clean slate! Focus on adding one healthy choice to your next meal."
        }
    }
    
    private func saveMeal(_ meal: TrackedMeal) {
        mealStorageManager.addMeal(meal)
        loadDailyMeals() // Reload to get updated data
        calculateDailyStats()
        
        // Mark that analysis needs to be updated
        needsAnalysisUpdate = true
        
        // Generate AI encouragement immediately
        generateAIEncouragement() // Update AI encouragement text
        print("🤖 MealTrackingView: AI encouragement text updated to: '\(aiEncouragementText.prefix(50))...'")
    }
    
    private func deleteMeal(_ meal: TrackedMeal) {
        mealStorageManager.deleteMeal(meal)
        loadDailyMeals() // Reload to get updated data
        calculateDailyStats()
        print("🗑️ MealTrackingView: After delete - \(dailyMeals.count) meals, average score: \(dailyStats?.averageScore ?? 0)")
        
        // Mark that analysis needs to be updated
        needsAnalysisUpdate = true
        
        // Clear cache and regenerate message when meal is deleted
        messageCacheTimestamp = nil
        generateMotivationalMessage()
        
        // Generate AI encouragement immediately
        generateAIEncouragement() // Update AI encouragement text
        print("🤖 MealTrackingView: AI encouragement text updated to: '\(aiEncouragementText.prefix(50))...'")
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
    
    // MARK: - AI Encouragement Section
    private var aiEncouragementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !aiEncouragementText.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMealAnalysisExpanded.toggle()
                        }
                        
                        // Load AI analysis when expanded for the first time (if not already loaded)
                        if isMealAnalysisExpanded && !isAIAnalysisLoading {
                            // Check if we have fallback text but not AI text yet
                            if aiEncouragementText.contains("Your meals show varying levels") {
                                loadAIMealAnalysis()
                            }
                        }
                    }) {
                        HStack {
                            // Icon with bright gradient (blue-teal like camera)
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 18, weight: .medium))
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
                                .frame(width: 32, height: 32)
                            
                            Text("Analysis & Recommendations")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: isMealAnalysisExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    colorScheme == .dark ?
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.478, blue: 1.0), // Blue
                                            Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: colorScheme == .dark ? 1.0 : 0
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if isMealAnalysisExpanded {
                        if isAIAnalysisLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating personalized analysis...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        } else {
                            Text(aiEncouragementText.isEmpty ? generateFallbackAnalysis() : aiEncouragementText)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(4)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                                .cornerRadius(12)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity.combined(with: .scale(scale: 0.95))
                                ))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    
    // MARK: - Nutritional Summary Section
    private var nutritionalSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    // Check if we're about to expand (currently closed) and meals have changed
                    let wasClosed = !nutritionalSummaryExpanded
                    let shouldGenerate = shouldRegenerateNutritionSummary()
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        nutritionalSummaryExpanded.toggle()
                    }
                    
                    // Only generate summary when user taps to expand (was closed) AND meals have changed
                    if wasClosed && shouldGenerate {
                        generateNutritionSummary()
                    }
                }) {
                    HStack {
                        // Icon with bright gradient (purple like photo)
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
                        
                        Image(systemName: nutritionalSummaryExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
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
                
                if nutritionalSummaryExpanded {
                    VStack(alignment: .leading, spacing: 0) {
                        // Pie Chart with Callouts
                        macrosPieChart
                            .padding(.top, 0)
                            .padding(.bottom, -40)
                        
                        // Kcal subhead below donut
                        let macros = totalMacros
                        let estimatedCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
                        let kcalDifference = getKcalDifferenceToTarget()
                        let kcalSubheadText: String = {
                            if abs(kcalDifference) < 10 {
                                return "On Target"
                            } else if kcalDifference > 0 {
                                return "\(Int(kcalDifference)) Kcals To Daily Target"
                            } else {
                                return "\(Int(abs(kcalDifference))) Kcals Over Daily Target"
                            }
                        }()
                        
                        Text(kcalSubheadText)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 0)
                            .padding(.bottom, 16)
                        
                        // Progress Bars Section
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            
                            // Serving Size display (blue, tappable) - shows "Daily Totals" for meal tracker
                            Button(action: {
                                servingSizeInput = "Daily Totals"
                                showingServingSizeEditor = true
                            }) {
                                Text("Serving Size: Daily Totals")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)
                            
                            // Get selected macros from profile
                            let trackedMacros = UserHealthProfileManager.shared.getTrackedMacros()
                            
                            // Kcal progress bar (always show if selected)
                            if trackedMacros.contains("Kcal") {
                                let estimatedCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
                                let dailyCalorieTarget = getDailyCalorieTarget()
                                macroProgressBar(macroName: "Kcal", currentValue: estimatedCalories, gradient: LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), targetValue: dailyCalorieTarget, unit: "Kcal")
                            }
                            
                            // Progress bars for each selected macro
                            if trackedMacros.contains("Protein") {
                                macroProgressBar(macroName: "Protein", currentValue: macros.protein, gradient: LinearGradient(colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.0, green: 0.8, blue: 0.8)], startPoint: .leading, endPoint: .trailing))
                            }
                            
                            if trackedMacros.contains("Carbs") {
                                macroProgressBar(macroName: "Carbs", currentValue: macros.carbs, gradient: LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing))
                            }
                            
                            if trackedMacros.contains("Fat") {
                                macroProgressBar(macroName: "Fat", currentValue: macros.fat, gradient: LinearGradient(colors: [Color(red: 1.0, green: 0.843, blue: 0.0), Color(red: 0.678, green: 0.847, blue: 0.902)], startPoint: .leading, endPoint: .trailing))
                            }
                            
                            if trackedMacros.contains("Fiber") {
                                macroProgressBar(macroName: "Fiber", currentValue: macros.fiber, gradient: LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)], startPoint: .leading, endPoint: .trailing))
                            }
                            
                            if trackedMacros.contains("Sugar") {
                                macroProgressBar(macroName: "Sugar", currentValue: macros.sugar, gradient: LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing))
                            }
                            
                            // Note: Sodium not included in totalMacros tuple, skip for now
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                        
                        // "What This Means For You" section
                        VStack(alignment: .center, spacing: 12) {
                            Text("What This Means For You")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            if isLoadingNutritionSummary {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Analyzing your nutrition...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                            } else if !nutritionSummaryText.isEmpty {
                                Text(nutritionSummaryText)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineSpacing(4)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 16)
                    }
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
                            currentMode: macroTargetMode,
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
                    .sheet(isPresented: $showingMacroSelection) {
                        MacroSelectionView(selectedMacros: $selectedMacros) {
                            UserHealthProfileManager.shared.setTrackedMacros(Array(selectedMacros))
                        }
                    }
                    .sheet(isPresented: $showingMicroSelection) {
                        MicronutrientSelectionView(selectedMicronutrients: $selectedMicronutrientsForSelection) {
                            UserHealthProfileManager.shared.updateTrackedMicronutrients(Array(selectedMicronutrientsForSelection))
                        }
                    }
                    .sheet(item: Binding(
                        get: { selectedMacroForTarget.map { MacroTargetItem(name: $0) } },
                        set: { selectedMacroForTarget = $0?.name }
                    )) { macroItem in
                        MacroTargetPopup(
                            macroName: macroItem.name,
                            currentValue: {
                                let macros = totalMacros
                                switch macroItem.name {
                                case "Protein": return macros.protein
                                case "Carbs": return macros.carbs
                                case "Fat": return macros.fat
                                case "Fiber": return macros.fiber
                                case "Sugar": return macros.sugar
                                default: return 0.0
                                }
                            }(),
                            targetValue: getMacroTargetValue(for: macroItem.name),
                            rdaValue: getMacroRDAValue(for: macroItem.name),
                            targetMode: macroTargetMode,
                            onSave: { target in
                                saveMacroTarget(macroItem.name, target: target)
                                selectedMacroForTarget = nil
                            },
                            onCancel: {
                                selectedMacroForTarget = nil
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Macro Target Item (for sheet binding)
    struct MacroTargetItem: Identifiable {
        let id = UUID()
        let name: String
    }
    
    // MARK: - Micronutrients Section
    private var micronutrientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        micronutrientsExpanded.toggle()
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
                        
                        Image(systemName: micronutrientsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
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
                
                if micronutrientsExpanded {
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
                                showingTargetModeSelection = true
                            }) {
                                Text(targetMode == .standardRDA ? "(RDA)" : "(Custom)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                        
                        // Serving Size display (blue, tappable) - shows "Daily Totals" for meal tracker
                        Button(action: {
                            servingSizeInput = "Daily Totals"
                            showingServingSizeEditor = true
                        }) {
                            Text("Serving Size: Daily Totals")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                        
                        // Show source attribution in RDA mode
                        if targetMode == .standardRDA {
                            Text("Based on USDA Dietary Guidelines 2020-2025")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 4)
                        }
                        
                        ForEach(micronutrientList, id: \.name) { micronutrient in
                            micronutrientRow(micronutrient)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                    .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .cornerRadius(12)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    .onAppear {
                        loadMicronutrientTargets()
                        loadTargetMode()
                        loadMacroTargets()
                        
                        // Load selected macros/micros
                        if selectedMacros.isEmpty {
                            selectedMacros = Set(UserHealthProfileManager.shared.getTrackedMacros())
                        }
                        if selectedMicronutrientsForSelection.isEmpty {
                            selectedMicronutrientsForSelection = Set(UserHealthProfileManager.shared.getTrackedMicronutrients())
                        }
                    }
                    .sheet(isPresented: $showingTargetModeSelection) {
                        TargetModeSelectionPopup(
                            currentMode: targetMode,
                            onSelectStandardRDA: {
                                targetMode = .standardRDA
                                saveTargetMode()
                                showingTargetModeSelection = false
                            },
                            onSelectCustom: {
                                if !customDisclaimerAccepted {
                                    showingTargetModeSelection = false
                                    showingCustomDisclaimer = true
                                } else {
                                    targetMode = .custom
                                    saveTargetMode()
                                    showingTargetModeSelection = false
                                }
                            }
                        )
                    }
                    .sheet(isPresented: $showingCustomDisclaimer) {
                        CustomTargetDisclaimerPopup(
                            onAccept: {
                                customDisclaimerAccepted = true
                                saveDisclaimerAcceptance()
                                targetMode = .custom
                                saveTargetMode()
                                showingCustomDisclaimer = false
                            },
                            onUseStandardRDA: {
                                targetMode = .standardRDA
                                saveTargetMode()
                                showingCustomDisclaimer = false
                            }
                        )
                    }
                    .sheet(item: $selectedMicronutrientForTarget) { micronutrient in
                        MicronutrientTargetPopup(
                            micronutrient: micronutrient,
                            currentValue: getCurrentMicronutrientValue(micronutrient.name),
                            targetValue: getTargetValue(for: micronutrient.name),
                            rdaValue: getRDAValue(for: micronutrient.name),
                            targetMode: targetMode,
                            onSave: { target in
                                saveMicronutrientTarget(micronutrient.name, target: target)
                                selectedMicronutrientForTarget = nil
                            },
                            onCancel: {
                                selectedMicronutrientForTarget = nil
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Micronutrient Data Structure
    struct Micronutrient: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let iconGradient: LinearGradient
        let placeholderValue: String
        let unit: String
    }
    
    // MARK: - Calculate Total Micronutrients from Today's Meals
    private var totalMicronutrients: [String: Double] {
        var totals: [String: Double] = [:]
        
        print("🔍 MealTrackingView: Calculating micronutrients for \(filteredTodayMeals.count) meals")
        
        for meal in filteredTodayMeals {
            print("🔍 MealTrackingView: Processing meal '\(meal.name)'")
            print("   - imageHash: \(meal.imageHash ?? "nil")")
            print("   - foods: \(meal.foods)")
            
            // Try to get updated analysis from cache (has nutrition data loaded on-demand)
            var analysis: FoodAnalysis? = nil
            var lookupMethod = "none"
            
            // First try: Use imageHash to get cached analysis (most reliable, has updated nutrition)
            if let imageHash = meal.imageHash {
                print("   - Trying imageHash lookup: \(imageHash)")
                if let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
                    analysis = cachedAnalysis
                    lookupMethod = "imageHash"
                    print("   ✅ Found analysis via imageHash")
                } else {
                    print("   ⚠️ No cached analysis found for imageHash")
                }
            } else {
                print("   ⚠️ Meal has no imageHash")
            }
            
            // Second try: Use food name to get cached analysis
            if analysis == nil {
                print("   - Trying food name lookup: '\(meal.name)'")
                if let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: meal.name) {
                    analysis = cachedAnalysis
                    lookupMethod = "foodName"
                    print("   ✅ Found analysis via food name")
                } else {
                    print("   ⚠️ No cached analysis found for food name")
                }
            }
            
            // Third try: Try matching by foods array (for meals with multiple foods)
            if analysis == nil && !meal.foods.isEmpty {
                print("   - Trying foods array lookup: \(meal.foods)")
                // Try matching first food in array
                if let firstFood = meal.foods.first,
                   let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: firstFood) {
                    analysis = cachedAnalysis
                    lookupMethod = "foodsArray"
                    print("   ✅ Found analysis via foods array (first food: \(firstFood))")
                } else {
                    print("   ⚠️ No cached analysis found for foods array")
                }
            }
            
            // Fallback: Use stored originalAnalysis (may not have nutrition data)
            if analysis == nil {
                if let originalAnalysis = meal.originalAnalysis {
                    analysis = originalAnalysis
                    lookupMethod = "originalAnalysis"
                    print("   ✅ Using stored originalAnalysis")
                } else {
                    print("   ❌ No analysis found - meal has no originalAnalysis")
                }
            }
            
            // Extract nutrition info from whichever analysis we found
            if let analysis = analysis {
                print("   - Analysis found via: \(lookupMethod)")
                print("   - Analysis foodName: '\(analysis.foodName)'")
                
                if let nutrition = analysis.nutritionInfo {
                    print("   ✅ Nutrition info exists")
                    var foundAnyMicro = false
                    
                    // Parse micronutrient values from NutritionInfo
                    if let vitaminD = nutrition.vitaminD, !vitaminD.isEmpty {
                        let value = parseNutritionValue(vitaminD)
                        totals["Vitamin D", default: 0] += value
                        foundAnyMicro = true
                        print("     - Vitamin D: \(vitaminD) = \(value)")
                    }
                    if let vitaminE = nutrition.vitaminE, !vitaminE.isEmpty {
                        let value = parseNutritionValue(vitaminE)
                        totals["Vitamin E", default: 0] += value
                        foundAnyMicro = true
                        print("     - Vitamin E: \(vitaminE) = \(value)")
                    }
                    if let potassium = nutrition.potassium, !potassium.isEmpty {
                        let value = parseNutritionValue(potassium)
                        totals["Potassium", default: 0] += value
                        foundAnyMicro = true
                        print("     - Potassium: \(potassium) = \(value)")
                    }
                    if let vitaminK = nutrition.vitaminK, !vitaminK.isEmpty {
                        let value = parseNutritionValue(vitaminK)
                        totals["Vitamin K", default: 0] += value
                        foundAnyMicro = true
                        print("     - Vitamin K: \(vitaminK) = \(value)")
                    }
                    if let magnesium = nutrition.magnesium, !magnesium.isEmpty {
                        let value = parseNutritionValue(magnesium)
                        totals["Magnesium", default: 0] += value
                        foundAnyMicro = true
                        print("     - Magnesium: \(magnesium) = \(value)")
                    }
                    if let vitaminA = nutrition.vitaminA, !vitaminA.isEmpty {
                        let value = parseNutritionValue(vitaminA)
                        totals["Vitamin A", default: 0] += value
                        foundAnyMicro = true
                        print("     - Vitamin A: \(vitaminA) = \(value)")
                    }
                    if let calcium = nutrition.calcium, !calcium.isEmpty {
                        let value = parseNutritionValue(calcium)
                        totals["Calcium", default: 0] += value
                        foundAnyMicro = true
                        print("     - Calcium: \(calcium) = \(value)")
                    }
                    if let vitaminC = nutrition.vitaminC, !vitaminC.isEmpty {
                        let value = parseNutritionValue(vitaminC)
                        totals["Vitamin C", default: 0] += value
                        foundAnyMicro = true
                        print("     - Vitamin C: \(vitaminC) = \(value)")
                    }
                    if let choline = nutrition.choline, !choline.isEmpty {
                        let value = parseNutritionValue(choline)
                        totals["Choline", default: 0] += value
                        foundAnyMicro = true
                        print("     - Choline: \(choline) = \(value)")
                    }
                    if let iron = nutrition.iron, !iron.isEmpty {
                        let value = parseNutritionValue(iron)
                        totals["Iron", default: 0] += value
                        foundAnyMicro = true
                        print("     - Iron: \(iron) = \(value)")
                    }
                    if let iodine = nutrition.iodine, !iodine.isEmpty {
                        let value = parseNutritionValue(iodine)
                        totals["Iodine", default: 0] += value
                        foundAnyMicro = true
                        print("     - Iodine: \(iodine) = \(value)")
                    }
                    if let zinc = nutrition.zinc, !zinc.isEmpty {
                        let value = parseNutritionValue(zinc)
                        totals["Zinc", default: 0] += value
                        foundAnyMicro = true
                        print("     - Zinc: \(zinc) = \(value)")
                    }
                    if let folate = nutrition.folate, !folate.isEmpty {
                        let value = parseNutritionValue(folate)
                        totals["Folate (B9)", default: 0] += value
                        foundAnyMicro = true
                        print("     - Folate: \(folate) = \(value)")
                    }
                    if let vitaminB12 = nutrition.vitaminB12, !vitaminB12.isEmpty {
                        let value = parseNutritionValue(vitaminB12)
                        totals["Vitamin B12", default: 0] += value
                        foundAnyMicro = true
                        print("     - Vitamin B12: \(vitaminB12) = \(value)")
                    }
                    if let vitaminB6 = nutrition.vitaminB6, !vitaminB6.isEmpty {
                        let value = parseNutritionValue(vitaminB6)
                        totals["Vitamin B6", default: 0] += value
                        foundAnyMicro = true
                        print("     - Vitamin B6: \(vitaminB6) = \(value)")
                    }
                    if let selenium = nutrition.selenium, !selenium.isEmpty {
                        let value = parseNutritionValue(selenium)
                        totals["Selenium", default: 0] += value
                        foundAnyMicro = true
                        print("     - Selenium: \(selenium) = \(value)")
                    }
                    if let copper = nutrition.copper, !copper.isEmpty {
                        let value = parseNutritionValue(copper)
                        totals["Copper", default: 0] += value
                        foundAnyMicro = true
                        print("     - Copper: \(copper) = \(value)")
                    }
                    if let manganese = nutrition.manganese, !manganese.isEmpty {
                        let value = parseNutritionValue(manganese)
                        totals["Manganese", default: 0] += value
                        foundAnyMicro = true
                        print("     - Manganese: \(manganese) = \(value)")
                    }
                    if let thiamin = nutrition.thiamin, !thiamin.isEmpty {
                        let value = parseNutritionValue(thiamin)
                        totals["Thiamin (B1)", default: 0] += value
                        foundAnyMicro = true
                        print("     - Thiamin: \(thiamin) = \(value)")
                    }
                    
                    if !foundAnyMicro {
                        print("   ⚠️ Nutrition info exists but all micronutrients are nil/empty")
                    }
                } else {
                    print("   ❌ Analysis found but nutritionInfo is nil")
                    print("   💡 Tip: Nutrition loads on-demand when you tap the dropdown in analysis screen")
                }
            } else {
                print("   ❌ No analysis found for meal '\(meal.name)'")
            }
        }
        
        print("🔍 MealTrackingView: Total micronutrients calculated: \(totals.count) entries")
        for (key, value) in totals.sorted(by: { $0.key < $1.key }) {
            if value > 0 {
                print("   - \(key): \(value)")
            }
        }
        
        return totals
    }
    
    // MARK: - Micronutrient Metadata (icons, gradients, units)
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
        case "Iodine":
            return ("waveform", LinearGradient(colors: [Color(red: 0.255, green: 0.643, blue: 0.655), Color(red: 0.0, green: 0.8, blue: 0.8)], startPoint: .leading, endPoint: .trailing), "mcg")
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
    
    // MARK: - Micronutrient List
    private var micronutrientList: [Micronutrient] {
        // Get user's selected micronutrients from profile
        let selectedMicronutrients = UserHealthProfileManager.shared.getTrackedMicronutrients()
        
        // If no micronutrients selected, return empty list
        guard !selectedMicronutrients.isEmpty else {
            return []
        }
        
        // Get actual micronutrient totals from meals
        let totals = totalMicronutrients
        
        // Build micronutrient list with real data
        return selectedMicronutrients.compactMap { name in
            let value = totals[name] ?? 0.0
            let metadata = micronutrientMetadata(for: name)
            
            // Format value based on unit
            let formattedValue: String
            if metadata.unit == "IU" || metadata.unit == "mcg" || metadata.unit == "mg" {
                if value >= 1000 {
                    formattedValue = String(format: "%.0f", value)
                } else if value >= 100 {
                    formattedValue = String(format: "%.0f", value)
                } else if value >= 10 {
                    formattedValue = String(format: "%.1f", value)
                } else {
                    formattedValue = String(format: "%.2f", value)
                }
            } else {
                formattedValue = String(format: "%.1f", value)
            }
            
            return Micronutrient(
                name: name,
                icon: metadata.icon,
                iconGradient: metadata.gradient,
                placeholderValue: formattedValue,
                unit: metadata.unit
            )
        }
    }
    
    // MARK: - Micronutrient Row View
    private func micronutrientRow(_ micronutrient: Micronutrient) -> some View {
        let currentValue = getCurrentMicronutrientValue(micronutrient.name)
        let targetValue = getTargetValue(for: micronutrient.name)
        let rdaValue = getRDAValue(for: micronutrient.name)
        
        return VStack(spacing: 12) {
            // Name and Current/Target value row (ABOVE bar)
            HStack(spacing: 8) {
                // Micronutrient name - ColorScheme-aware, underlined, tappable
                // Only allow editing in Custom mode
                if targetMode == .custom {
                    Button(action: {
                        selectedMicronutrientForTarget = micronutrient
                        targetInputValue = ""
                    }) {
                        Text(micronutrient.name)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .underline()
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // In RDA mode, show name but not tappable
                    Text(micronutrient.name)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
                
                Spacer()
                
                // Current/Target value format "XXX/500mg" (right)
                // Show RDA label in Standard mode
                let exceedsTarget = currentValue > targetValue
                if targetMode == .standardRDA {
                    Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(micronutrient.unit) (RDA)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(exceedsTarget ? .red : .secondary)
                } else {
                    Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(micronutrient.unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(exceedsTarget ? .red : (colorScheme == .dark ? .white : .primary))
                }
            }
            
            // Progress Bar row (full width, no icon)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar with icon gradient (lighter opacity) - THINNER
                    // More visible in light mode, keep dark mode as is
                    let backgroundOpacity = colorScheme == .dark ? 0.2 : 0.4
                    RoundedRectangle(cornerRadius: 4)
                        .fill(micronutrient.iconGradient.opacity(backgroundOpacity))
                        .frame(height: 10)
                    
                    // Filled portion with full gradient from icon - THINNER
                    // More visible in light mode, keep dark mode as is
                    let progress = min(currentValue / targetValue, 1.0)
                    let fillWidth = geometry.size.width * CGFloat(progress)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(micronutrient.iconGradient)
                        .frame(width: fillWidth, height: 10)
                }
                .frame(height: 10)
            }
            
            // Benefit description under progress bar
            Text(getMicronutrientBenefits(for: micronutrient.name))
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
        case "Iodine":
            return "For thyroid, metabolism, growth"
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
    
    // MARK: - Macro Progress Bar
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
                        macroTargetInputValue = ""
                    }) {
                        Text(macroName)
                            .font(.subheadline)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                            .underline()
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Text(macroName)
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
                
                Spacer()
                
                // Current/Target value format "XXX/500g" or "XXX/2000Kcal" (right)
                let exceedsTarget = currentValue > targetValue
                if macroName == "Kcal" {
                    // For Kcal, always show without RDA label
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
    
    // MARK: - Micronutrient Value Text
    private func micronutrientValueText(_ micronutrient: Micronutrient) -> Text {
        let currentValue = getCurrentMicronutrientValue(micronutrient.name)
        let targetValue = micronutrientTargets[micronutrient.name] ?? 0
        
        if targetValue > 0 {
            // Show "current/target" format
            return Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(micronutrient.unit)")
        } else {
            // Show just current value
            return Text("\(Int(round(currentValue))) \(micronutrient.unit)")
        }
    }
    
    // MARK: - Get Current Micronutrient Value
    private func getCurrentMicronutrientValue(_ name: String) -> Double {
        // Use real data from tracked meals
        let totals = totalMicronutrients
        return totals[name] ?? 0.0
    }
    
    // MARK: - Load Micronutrient Targets
    private func loadMicronutrientTargets() {
        if let data = UserDefaults.standard.data(forKey: "micronutrientTargets"),
           let targets = try? JSONDecoder().decode([String: Double].self, from: data) {
            micronutrientTargets = targets
        }
    }
    
    // MARK: - Load Target Mode
    private func loadTargetMode() {
        if let modeString = UserDefaults.standard.string(forKey: "micronutrientTargetMode"),
           let mode = TargetMode(rawValue: modeString) {
            targetMode = mode
        } else {
            // Default to standard RDA if no mode is set
            targetMode = .standardRDA
        }
        
        // Load disclaimer acceptance
        customDisclaimerAccepted = UserDefaults.standard.bool(forKey: "customTargetDisclaimerAccepted")
    }
    
    // MARK: - Save Target Mode
    private func saveTargetMode() {
        UserDefaults.standard.set(targetMode.rawValue, forKey: "micronutrientTargetMode")
    }
    
    // MARK: - Save Disclaimer Acceptance
    private func saveDisclaimerAcceptance() {
        UserDefaults.standard.set(customDisclaimerAccepted, forKey: "customTargetDisclaimerAccepted")
    }
    
    // MARK: - Save Micronutrient Target
    private func saveMicronutrientTarget(_ name: String, target: Double) {
        micronutrientTargets[name] = target
        if let data = try? JSONEncoder().encode(micronutrientTargets) {
            UserDefaults.standard.set(data, forKey: "micronutrientTargets")
        }
    }
    
    // MARK: - Get Target Value (RDA or Custom)
    private func getTargetValue(for micronutrient: String) -> Double {
        if targetMode == .standardRDA {
            return getRDAValue(for: micronutrient) ?? 0
        } else {
            return micronutrientTargets[micronutrient] ?? getRDAValue(for: micronutrient) ?? 0
        }
    }
    
    // MARK: - Macro Target Functions
    
    // MARK: - Load Macro Targets
    private func loadMacroTargets() {
        if let data = UserDefaults.standard.data(forKey: "macroTargets"),
           let targets = try? JSONDecoder().decode([String: Double].self, from: data) {
            macroTargets = targets
        }
    }
    
    // MARK: - Save Macro Disclaimer Acceptance
    private func saveMacroDisclaimerAcceptance() {
        UserDefaults.standard.set(macroCustomDisclaimerAccepted, forKey: "macroCustomTargetDisclaimerAccepted")
    }
    
    // MARK: - Save Macro Target
    private func saveMacroTarget(_ name: String, target: Double) {
        macroTargets[name] = target
        if let data = try? JSONEncoder().encode(macroTargets) {
            UserDefaults.standard.set(data, forKey: "macroTargets")
        }
    }
    
    // MARK: - Get Macro RDA Value
    private func getMacroRDAValue(for macro: String) -> Double {
        // Standard RDA values for macros (based on 2000 calorie diet)
        let rdaValues: [String: Double] = [
            "Protein": 50.0,  // 200 calories (10% of 2000)
            "Carbs": 250.0,   // 1000 calories (50% of 2000)
            "Fat": 65.0,      // 585 calories (29% of 2000)
            "Fiber": 30.0,    // Standard recommendation
            "Sugar": 50.0     // Standard recommendation (<50g/day)
        ]
        return rdaValues[macro] ?? 0.0
    }
    
    // MARK: - Get Macro Target Value (RDA or Custom)
    private func getMacroTargetValue(for macro: String) -> Double {
        if macroTargetMode == .standardRDA {
            return getMacroRDAValue(for: macro)
        } else {
            return macroTargets[macro] ?? getMacroRDAValue(for: macro)
        }
    }
    
    // MARK: - Get Daily Calorie Target
    private func getDailyCalorieTarget() -> Double {
        // Default to 2000 calories, but can be customized
        if let stored = UserDefaults.standard.object(forKey: "dailyCalorieTarget") as? Double, stored > 0 {
            return stored
        }
        return 2000.0
    }
    
    // MARK: - Calculate Kcal Difference to Target
    private func getKcalDifferenceToTarget() -> Double {
        let macros = totalMacros
        let currentCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
        let targetCalories = getDailyCalorieTarget()
        return targetCalories - currentCalories
    }
    
    // MARK: - Get RDA Value
    private func getRDAValue(for micronutrient: String) -> Double? {
        let ageRange = healthProfileManager.currentProfile?.ageRange
        let sex = healthProfileManager.currentProfile?.sex
        return RDALookupService.shared.getRDA(for: micronutrient, ageRange: ageRange, sex: sex)
    }
    
    // MARK: - Longevity Score Graph Section
    private var longevityScoreGraphSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        longevityGraphExpanded.toggle()
                        if longevityGraphExpanded && timelineData.isEmpty {
                            calculateTimelineData()
                        }
                    }
                }) {
                    HStack {
                        // Icon with bright gradient (green like mic)
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.42, green: 0.557, blue: 0.498),
                                        Color(red: 0.3, green: 0.7, blue: 0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Text("Progress")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: longevityGraphExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                if longevityGraphExpanded {
                    VStack(spacing: 16) {
                        // Timeline Carousel
                        if !timelineData.isEmpty {
                            timelineCarouselView
                        } else {
                            VStack(spacing: 8) {
                                Text("Start tracking meals to build your timeline")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    .onAppear {
                        if timelineData.isEmpty {
                            calculateTimelineData()
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Timeline Data Calculation (Last 30 Days)
    private func calculateTimelineData() {
        let allMeals = mealStorageManager.getAllMeals()
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        
        // Group meals by day
        var groupedMeals: [Date: [TrackedMeal]] = [:]
        for meal in allMeals {
            let dayStart = calendar.startOfDay(for: meal.timestamp)
            if dayStart >= thirtyDaysAgo && dayStart <= today {
                if groupedMeals[dayStart] == nil {
                    groupedMeals[dayStart] = []
                }
                groupedMeals[dayStart]?.append(meal)
            }
        }
        
        // Date formatter for "M/d EEE" format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d EEE"
        
        // Generate data for last 30 days
        var timelineDataPoints: [DailyTimelineData] = []
        for dayOffset in 0..<30 {
            if let dayDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let dayStart = calendar.startOfDay(for: dayDate)
                let meals = groupedMeals[dayStart] ?? []
                
                let hasData = !meals.isEmpty
                let averageScore = hasData ? meals.reduce(0.0) { $0 + $1.healthScore } / Double(meals.count) : 0.0
                let dateString = dateFormatter.string(from: dayDate)
                
                timelineDataPoints.append(DailyTimelineData(
                    date: dayDate,
                    score: averageScore,
                    hasData: hasData,
                    dateString: dateString
                ))
            }
        }
        
        // Reverse to show oldest to newest (left to right)
        timelineData = timelineDataPoints.reversed()
    }
    
    // MARK: - Timeline Carousel View
    private var timelineCarouselView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(timelineData) { data in
                        DailyScoreCard(data: data, isToday: Calendar.current.isDateInToday(data.date))
                            .id(data.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .frame(height: 220)  // Increased height to accommodate extra padding
            .onAppear {
                // Scroll to today's card when opened
                if let todayData = timelineData.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(todayData.id, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Score History Calculation
    private func calculateScoreHistory() {
        let allMeals = mealStorageManager.getAllMeals()
        guard !allMeals.isEmpty else {
            scoreHistoryData = []
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch selectedGraphPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        // Filter meals within the selected period
        let filteredMeals = allMeals.filter { $0.timestamp >= startDate }
        
        // Group meals by date (day/week/month based on period)
        var groupedMeals: [Date: [TrackedMeal]] = [:]
        
        for meal in filteredMeals {
            let key: Date
            switch selectedGraphPeriod {
            case .week:
                key = calendar.startOfDay(for: meal.timestamp)
            case .month:
                // For month period, group by day (will be aggregated into weeks later)
                key = calendar.startOfDay(for: meal.timestamp)
            case .threeMonths:
                // For 3 months period, group by day (will be aggregated into weeks later)
                key = calendar.startOfDay(for: meal.timestamp)
            case .year:
                key = calendar.date(from: calendar.dateComponents([.year, .month], from: meal.timestamp)) ?? meal.timestamp
            }
            
            if groupedMeals[key] == nil {
                groupedMeals[key] = []
            }
            groupedMeals[key]?.append(meal)
        }
        
        // Generate data points based on selected period
        var dataPoints: [ScoreDataPoint] = []
        let dateFormatter = DateFormatter()
        
        switch selectedGraphPeriod {
        case .week:
            // Generate all 7 days of the week (Mon-Sun)
            dateFormatter.dateFormat = "E" // Day abbreviation (Mon, Tue, etc.)
            let endDate = now
            var currentDate = calendar.date(byAdding: .day, value: -6, to: endDate) ?? startDate
            
            // Find the Monday of the week
            let weekday = calendar.component(.weekday, from: currentDate)
            let daysFromMonday = (weekday + 5) % 7 // Convert Sunday=1 to Monday=0
            if let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: currentDate) {
                currentDate = calendar.startOfDay(for: monday)
            }
            
            // Generate all 7 days
            for dayOffset in 0..<7 {
                if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: currentDate) {
                    let dayStart = calendar.startOfDay(for: dayDate)
                    let meals = groupedMeals[dayStart] ?? []
                    let averageScore = meals.isEmpty ? 0.0 : meals.reduce(0.0) { $0 + $1.healthScore } / Double(meals.count)
                    let label = dateFormatter.string(from: dayDate)
                    
                    dataPoints.append(ScoreDataPoint(
                        date: dayDate,
                        score: averageScore,
                        label: label
                    ))
                }
            }
            
        case .month:
            // Generate weekly data points (4 weeks)
            let components = calendar.dateComponents([.year, .month], from: startDate)
            guard let monthStart = calendar.date(from: components) else {
                break
            }
            
            // Find the first Monday of the month (or start of month if it's Monday)
            var weekStart = monthStart
            let weekday = calendar.component(.weekday, from: weekStart)
            let daysFromMonday = (weekday + 5) % 7 // Convert Sunday=1 to Monday=0
            if daysFromMonday > 0, let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: weekStart) {
                weekStart = calendar.startOfDay(for: monday)
            } else {
                weekStart = calendar.startOfDay(for: weekStart)
            }
            
            // Generate 4 weeks
            for weekIndex in 0..<4 {
                if let weekDate = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: weekStart) {
                    // Collect all meals for this week
                    var weekMeals: [TrackedMeal] = []
                    for dayOffset in 0..<7 {
                        if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekDate) {
                            let dayStart = calendar.startOfDay(for: dayDate)
                            if let meals = groupedMeals[dayStart] {
                                weekMeals.append(contentsOf: meals)
                            }
                        }
                    }
                    
                    let averageScore = weekMeals.isEmpty ? 0.0 : weekMeals.reduce(0.0) { $0 + $1.healthScore } / Double(weekMeals.count)
                    let label = "WK \(weekIndex + 1)"
                    
                    // Use the middle of the week as the date for positioning
                    let weekMiddle = calendar.date(byAdding: .day, value: 3, to: weekDate) ?? weekDate
                    
                    dataPoints.append(ScoreDataPoint(
                        date: weekMiddle,
                        score: averageScore,
                        label: label
                    ))
                }
            }
            
        case .threeMonths:
            // Generate weekly data points (12 weeks)
            var currentWeek = startDate
            
            // Find the Monday of the first week
            let weekday = calendar.component(.weekday, from: currentWeek)
            let daysFromMonday = (weekday + 5) % 7
            if daysFromMonday > 0, let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: currentWeek) {
                currentWeek = calendar.startOfDay(for: monday)
            } else {
                currentWeek = calendar.startOfDay(for: currentWeek)
            }
            
            // Generate 12 weeks
            for weekIndex in 0..<12 {
                if let weekDate = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: currentWeek) {
                    // Collect all meals for this week
                    var weekMeals: [TrackedMeal] = []
                    for dayOffset in 0..<7 {
                        if let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekDate) {
                            let dayStart = calendar.startOfDay(for: dayDate)
                            if let meals = groupedMeals[dayStart] {
                                weekMeals.append(contentsOf: meals)
                            }
                        }
                    }
                    
                    let averageScore = weekMeals.isEmpty ? 0.0 : weekMeals.reduce(0.0) { $0 + $1.healthScore } / Double(weekMeals.count)
                    let label = "WK\(weekIndex + 1)"
                    
                    // Use the middle of the week as the date for positioning
                    let weekMiddle = calendar.date(byAdding: .day, value: 3, to: weekDate) ?? weekDate
                    
                    dataPoints.append(ScoreDataPoint(
                        date: weekMiddle,
                        score: averageScore,
                        label: label
                    ))
                }
            }
            
        case .year:
            // Generate monthly data points (all 12 months)
            dateFormatter.dateFormat = "MMM" // Month abbreviation (Jan, Feb, etc.)
            
            // Start from the first month of the year period
            let yearStartComponents = calendar.dateComponents([.year, .month], from: startDate)
            guard let firstMonth = calendar.date(from: yearStartComponents) else {
                break
            }
            
            var currentMonth = firstMonth
            var monthIndex = 0
            
            // Generate exactly 12 months
            while monthIndex < 12 && currentMonth <= now {
                let monthKey = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) ?? currentMonth
                let meals = groupedMeals[monthKey] ?? []
                let averageScore = meals.isEmpty ? 0.0 : meals.reduce(0.0) { $0 + $1.healthScore } / Double(meals.count)
                let label = dateFormatter.string(from: currentMonth)
                
                dataPoints.append(ScoreDataPoint(
                    date: currentMonth,
                    score: averageScore,
                    label: label
                ))
                
                // Move to next month
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
                    currentMonth = nextMonth
                    monthIndex += 1
                } else {
                    break
                }
            }
        }
        
        scoreHistoryData = dataPoints.sorted { $0.date < $1.date }
    }
    
    // MARK: - Helper Functions for Graph
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
    
    private func formatDateForAxis(_ date: Date) -> String {
        // Use the label from the data point if available
        let calendar = Calendar.current
        
        // For week period, match by day
        if selectedGraphPeriod == .week {
            if let dataPoint = scoreHistoryData.first(where: { 
                calendar.isDate($0.date, inSameDayAs: date)
            }) {
                return dataPoint.label
            }
        }
        // For month period, match by week (within 7 days)
        else if selectedGraphPeriod == .month {
            if let dataPoint = scoreHistoryData.first(where: { 
                let daysDiff = abs(calendar.dateComponents([.day], from: $0.date, to: date).day ?? 0)
                return daysDiff < 7
            }) {
                return dataPoint.label
            }
        }
        // For 3 months period, match by week (within 7 days)
        else if selectedGraphPeriod == .threeMonths {
            if let dataPoint = scoreHistoryData.first(where: { 
                let daysDiff = abs(calendar.dateComponents([.day], from: $0.date, to: date).day ?? 0)
                return daysDiff < 7
            }) {
                return dataPoint.label
            }
        }
        // For year period, match by month
        else if selectedGraphPeriod == .year {
            if let dataPoint = scoreHistoryData.first(where: { 
                calendar.component(.month, from: $0.date) == calendar.component(.month, from: date) &&
                calendar.component(.year, from: $0.date) == calendar.component(.year, from: date)
            }) {
                return dataPoint.label
            }
        }
        
        // Fallback: use the label from the closest data point
        if let dataPoint = scoreHistoryData.first(where: { 
            calendar.isDate($0.date, inSameDayAs: date) || 
            (selectedGraphPeriod == .threeMonths || selectedGraphPeriod == .year) && 
            calendar.component(.month, from: $0.date) == calendar.component(.month, from: date) &&
            calendar.component(.year, from: $0.date) == calendar.component(.year, from: date)
        }) {
            return dataPoint.label
        }
        
        // Final fallback: format based on period
        let formatter = DateFormatter()
        switch selectedGraphPeriod {
        case .week:
            formatter.dateFormat = "E" // Mon, Tue, etc.
        case .month:
            return "" // Should not reach here for month
        case .threeMonths:
            return "" // Should not reach here for 3 months
        case .year:
            formatter.dateFormat = "MMM" // Jan, Feb, etc.
        }
        return formatter.string(from: date)
    }
    
    private var chartWithBackground: some View {
        ZStack(alignment: .bottom) {
            // Background (matching score screen style)
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black : Color.white)
                .frame(height: 216) // 200 + 8pt top + 8pt bottom padding
            
            // Chart with padding
            VStack(spacing: 0) {
                scoreChart
                    .padding(.top, 8) // 8pt top padding
                    .padding(.leading, 8) // 8pt left padding
                    .padding(.trailing, 8) // 8pt right padding
                    .padding(.bottom, 8) // 8pt bottom padding
                    .overlay(alignment: .top) {
                        scoreLabelsOverlay
                    }
            }
        }
        .padding(8) // 8pt padding around entire chart container
    }
    
    private var scoreChart: some View {
        Chart(scoreHistoryData) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Score", dataPoint.score)
            )
            .foregroundStyle(Color.green) // Bright green progress line
            .lineStyle(StrokeStyle(lineWidth: 5)) // Thicker line
            
            AreaMark(
                x: .value("Date", dataPoint.date),
                y: .value("Score", dataPoint.score)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.3), // Green at top (near the line)
                        Color.green.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .leading, // Horizontal gradient (left to right)
                    endPoint: .trailing
                )
            )
            
            // Vertical lines from x-axis to score circle (only for data points with scores > 0)
            // Using RectangleMark to draw thin vertical rectangles
            if dataPoint.score > 0 {
                RectangleMark(
                    xStart: .value("Date", dataPoint.date, unit: .day),
                    xEnd: .value("Date", dataPoint.date, unit: .day),
                    yStart: .value("Score", 0),
                    yEnd: .value("Score", dataPoint.score)
                )
                .foregroundStyle(Color.gray.opacity(0.15))
            }
        }
        .frame(height: 200)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: scoreHistoryData.count)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatDateForAxis(date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: 20)) { value in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.2))
                
                // Removed AxisValueLabel to hide Y-axis numbers
            }
        }
    }
    
    private func averageScoreCircle(currentAverage: Double) -> some View {
        ZStack {
            Circle()
                .fill(scoreGradient(Int(currentAverage)))
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
            
            VStack(spacing: -2) {
                Text("Avg")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(String(format: "%.0f", currentAverage))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(scoreLabel(Int(currentAverage)).uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var scoreLabelsOverlay: some View {
        Group {
            if !scoreHistoryData.isEmpty && scoreHistoryData.count > 1 {
                GeometryReader { geometry in
                    ForEach(Array(scoreHistoryData.enumerated()), id: \.element.id) { index, dataPoint in
                        // Only show circles for non-zero scores
                        if dataPoint.score > 0 {
                            scoreLabelView(
                                dataPoint: dataPoint,
                                index: index,
                                totalCount: scoreHistoryData.count,
                                geometry: geometry
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func scoreLabelView(dataPoint: ScoreDataPoint, index: Int, totalCount: Int, geometry: GeometryProxy) -> some View {
        let normalizedIndex = CGFloat(index) / CGFloat(max(1, totalCount - 1))
        // Account for 8pt padding on each side
        let chartWidth = geometry.size.width - 16 // 8pt left + 8pt right padding
        let xPosition = 8 + (normalizedIndex * chartWidth) // Start from padding
        let normalizedScore = CGFloat(dataPoint.score) / 100.0
        // Account for 8pt padding on top and bottom
        let chartHeight = geometry.size.height - 16 // 8pt top + 8pt bottom padding
        let yPosition = 8 + ((1.0 - normalizedScore) * chartHeight) // Start from top padding
        
        return ZStack {
            Circle()
                .fill(Color.yellow)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            
            Text("\(Int(dataPoint.score))")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.black)
        }
        .position(x: xPosition, y: max(8, yPosition - 15)) // Ensure minimum 8pt from top
    }
    
    // MARK: - Insights Section (formerly Motivational Message)
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !motivationalMessage.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            insightsExpanded.toggle()
                        }
                    }) {
                        HStack {
                            // Icon with bright gradient (orange like keyboard)
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 32, height: 32)
                            
                            Text("Insights")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: insightsExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
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
                    
                    if insightsExpanded {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                // Icon based on category
                                Image(systemName: iconForCategory(motivationalMessageCategory))
                                    .font(.title2)
                                    .foregroundColor(.primary)
                                
                                Text(motivationalMessage)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(4)
                            }
                            
                            // Suggested meal/recipe link if available
                            if let meal = suggestedMeal {
                                Button(action: {
                                    selectedMeal = meal
                                }) {
                                    HStack {
                                        Text("View Recipe")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }
                            } else if let recipe = suggestedRecipe {
                                Button(action: {
                                    selectedRecipe = recipe
                                }) {
                                    HStack {
                                        Text("View Recipe")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                        .cornerRadius(12)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func iconForCategory(_ category: MessageCategory) -> String {
        switch category {
        case .exceptional: return "star.fill"
        case .great: return "hand.thumbsup.fill"
        case .good: return "leaf.fill"
        case .needsEncouragement: return "heart.fill"
        }
    }
    
    private func gradientColorsForCategory(_ category: MessageCategory) -> [Color] {
        switch category {
        case .exceptional:
            return [Color.green.opacity(0.2), Color.green.opacity(0.1)]
        case .great:
            return [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]
        case .good:
            return [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]
        case .needsEncouragement:
            return [Color.yellow.opacity(0.2), Color.orange.opacity(0.1)]
        }
    }
    
    // MARK: - Add A Meal Button (with gradient like View More buttons)
    private var addMealButton: some View {
        Button(action: {
            showingSelectMealsView = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("Add A Meal")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
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
        .padding(.top, 20)
        .sheet(isPresented: $showingSelectMealsView) {
            SelectMealsView { selectedAnalyses in
                addMultipleMealsToTracker(selectedAnalyses)
            }
            .interactiveDismissDisabled(false) // Allow dismissal only when user explicitly cancels or completes flow
        }
    }
    
    // MARK: - Today's Meals Subhead (Dynamic based on date range)
    private var todaysMealsSubhead: some View {
        Text(mealsHeaderText)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 13) // 8pt original + 5pt additional = 13pt
    }
    
    private var mealsHeaderText: String {
        switch dateRangeOption {
        case .today:
            return "Today's Meals"
        case .last7Days:
            return "Last 7 Days Meals"
        case .last30Days:
            return "Last 30 Days Meals"
        case .yesterday:
            return "Yesterday's Meals"
        case .pickDate:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(formatter.string(from: selectedDate)) Meals"
        }
    }
    
    // MARK: - Helper Functions
    private func generateAIEncouragement() {
        guard !dailyMeals.isEmpty else {
            aiEncouragementText = "Ready to begin your longevity journey? Add your first meal to start tracking your nutritional progress and see how your choices impact your health goals!"
            cachedAIAnalysis = ""
            lastAnalysisMealCount = 0
            needsAnalysisUpdate = false
            print("🤖 MealTrackingView: Generated empty state encouragement")
            return
        }
        
        let mealCount = dailyMeals.count
        let currentDate = selectedDate
        
        // Check if we need to regenerate analysis
        let shouldRegenerate = needsAnalysisUpdate || 
                              mealCount != lastAnalysisMealCount || 
                              !Calendar.current.isDate(currentDate, inSameDayAs: lastAnalysisDate) ||
                              cachedAIAnalysis.isEmpty
        
        print("🤖 MealTrackingView: Analysis check - mealCount: \(mealCount), lastCount: \(lastAnalysisMealCount), needsUpdate: \(needsAnalysisUpdate), shouldRegenerate: \(shouldRegenerate)")
        
        if shouldRegenerate {
            // Set initial text to show the section, then load AI analysis
            aiEncouragementText = generateFallbackAnalysis()
            
            // Load AI analysis asynchronously
            loadAIMealAnalysis()
            
            // Update tracking variables
            lastAnalysisMealCount = mealCount
            lastAnalysisDate = currentDate
            needsAnalysisUpdate = false
            
            print("🤖 MealTrackingView: Regenerating AI analysis for \(mealCount) meals")
        } else {
            // Use cached analysis
            aiEncouragementText = cachedAIAnalysis
            print("🤖 MealTrackingView: Using cached AI analysis")
        }
    }
    
    private func generateComprehensiveMealAnalysis() -> String {
        let mealCount = dailyMeals.count
        let averageScore = dailyStats?.averageScore ?? 0
        
        // Analyze individual meal components
        let mealAnalysis = analyzeMealComponents()
        let healthGoalAnalysis = analyzeHealthGoals()
        let nutritionalPatterns = analyzeNutritionalPatterns()
        let improvementAreas = identifyImprovementAreas()
        
        // Generate personalized message based on analysis
        if mealCount == 1 {
            return generateFirstMealMessage()
        } else {
            return generateDetailedAnalysis(
                mealAnalysis: mealAnalysis,
                healthGoalAnalysis: healthGoalAnalysis,
                nutritionalPatterns: nutritionalPatterns,
                improvementAreas: improvementAreas,
                averageScore: averageScore,
                mealCount: mealCount
            )
        }
    }
    
    private func analyzeMealComponents() -> MealAnalysis {
        var totalScore = 0.0
        var highScoringMeals: [TrackedMeal] = []
        var lowScoringMeals: [TrackedMeal] = []
        var mealTypes: [String] = []
        
        for meal in dailyMeals {
            let score = meal.healthScore
            totalScore += score
            
            if score >= 0.8 {
                highScoringMeals.append(meal)
            } else if score < 0.6 {
                lowScoringMeals.append(meal)
            }
            
            // Categorize meal types based on time
            let hour = Calendar.current.component(.hour, from: meal.timestamp)
            if hour < 11 {
                mealTypes.append("breakfast")
            } else if hour < 15 {
                mealTypes.append("lunch")
            } else {
                mealTypes.append("dinner")
            }
        }
        
        return MealAnalysis(
            highScoringMeals: highScoringMeals,
            lowScoringMeals: lowScoringMeals,
            mealTypes: mealTypes,
            averageScore: totalScore / Double(dailyMeals.count)
        )
    }
    
    private func analyzeHealthGoals() -> HealthGoalAnalysis {
        var goalScores: [String: [Int]] = [:]
        var allGoals: Set<String> = []
        
        for meal in dailyMeals {
            if let analysis = meal.originalAnalysis {
                let scores = analysis.healthScores
                goalScores["Heart Health", default: []].append(scores.heartHealth)
                goalScores["Brain Health", default: []].append(scores.brainHealth)
                goalScores["Anti-Inflammation", default: []].append(scores.antiInflammation)
                goalScores["Joint Health", default: []].append(scores.jointHealth)
                goalScores["Weight Management", default: []].append(scores.weightManagement)
                goalScores["Blood Sugar", default: []].append(scores.bloodSugar)
                goalScores["Energy", default: []].append(scores.energy)
                goalScores["Immune", default: []].append(scores.immune)
                goalScores["Sleep", default: []].append(scores.sleep)
                goalScores["Skin", default: []].append(scores.skin)
                goalScores["Stress", default: []].append(scores.stress)
                
                allGoals.formUnion(meal.goalsMet)
            }
        }
        
        // Calculate average scores for each goal
        var averageGoalScores: [String: Double] = [:]
        for (goal, scores) in goalScores {
            averageGoalScores[goal] = Double(scores.reduce(0, +)) / Double(scores.count)
        }
        
        return HealthGoalAnalysis(
            averageGoalScores: averageGoalScores,
            goalsMet: Array(allGoals),
            strongestAreas: averageGoalScores.filter { $0.value >= 80 }.map { $0.key },
            weakestAreas: averageGoalScores.filter { $0.value < 60 }.map { $0.key }
        )
    }
    
    private func analyzeNutritionalPatterns() -> NutritionalPatterns {
        var proteinSources: [String] = []
        var vegetableTypes: [String] = []
        var processedFoods: [String] = []
        var antioxidantRich: [String] = []
        
        for meal in dailyMeals {
            if let analysis = meal.originalAnalysis {
                // Analyze ingredients for patterns
                for ingredient in analysis.ingredientsOrDefault {
                    let name = ingredient.name.lowercased()
                    
                    if name.contains("protein") || name.contains("meat") || name.contains("fish") || name.contains("egg") {
                        proteinSources.append(ingredient.name)
                    }
                    if name.contains("vegetable") || name.contains("green") || name.contains("leafy") {
                        vegetableTypes.append(ingredient.name)
                    }
                    if name.contains("processed") || name.contains("refined") || name.contains("artificial") {
                        processedFoods.append(ingredient.name)
                    }
                    if name.contains("berry") || name.contains("antioxidant") || name.contains("polyphenol") {
                        antioxidantRich.append(ingredient.name)
                    }
                }
            }
        }
        
        return NutritionalPatterns(
            proteinSources: proteinSources,
            vegetableTypes: vegetableTypes,
            processedFoods: processedFoods,
            antioxidantRich: antioxidantRich
        )
    }
    
    private func identifyImprovementAreas() -> [String] {
        var improvements: [String] = []
        
        let healthAnalysis = analyzeHealthGoals()
        let nutritionalPatterns = analyzeNutritionalPatterns()
        
        // Check for missing nutritional elements
        if nutritionalPatterns.vegetableTypes.isEmpty {
            improvements.append("vegetable diversity")
        }
        if nutritionalPatterns.antioxidantRich.isEmpty {
            improvements.append("antioxidant-rich foods")
        }
        if nutritionalPatterns.proteinSources.isEmpty {
            improvements.append("quality protein sources")
        }
        
        // Check for health goal weaknesses
        for weakArea in healthAnalysis.weakestAreas {
            improvements.append(weakArea.lowercased())
        }
        
        return improvements
    }
    
    private func generateFirstMealMessage() -> String {
        guard let firstMeal = dailyMeals.first else { return "" }
        
        let score = Int(firstMeal.healthScore) // Score is already on 0-100 scale (matches Score screen)
        let mealName = firstMeal.name
        
        if score >= 80 {
            return "Excellent start! Your '\(mealName)' scored \(score) - you're already making choices that support longevity. This meal shows strong nutritional foundations. Keep this momentum going by adding more meals throughout the day to build a complete nutritional profile."
        } else if score >= 60 {
            return "Good beginning! Your '\(mealName)' scored \(score) and shows you understand the basics of healthy eating. To boost your scores, consider adding more colorful vegetables, lean proteins, or whole grains to your next meals."
        } else {
            return "Every step counts! Your '\(mealName)' scored \(score). Focus on incorporating more whole, unprocessed foods in your next meals. Try adding leafy greens, lean proteins, or healthy fats to improve your nutritional density."
        }
    }
    
    private func generateDetailedAnalysis(
        mealAnalysis: MealAnalysis,
        healthGoalAnalysis: HealthGoalAnalysis,
        nutritionalPatterns: NutritionalPatterns,
        improvementAreas: [String],
        averageScore: Double,
        mealCount: Int
    ) -> String {
        let score = Int(averageScore * 10) // Convert from 0-10 scale to 0-100
        
        // First paragraph: Analysis of the day's meals (good and bad)
        var analysis = ""
        
        if score >= 85 {
            analysis += "Excellent day! Your \(mealCount) meals averaged \(score) with outstanding longevity benefits. "
        } else if score >= 75 {
            analysis += "Good performance! Your \(mealCount) meals averaged \(score) with solid nutritional foundations. "
        } else if score >= 65 {
            analysis += "Making progress! Your \(mealCount) meals averaged \(score) with room to optimize. "
        } else {
            analysis += "Every meal counts! Your \(mealCount) meals averaged \(score) - let's enhance nutritional quality. "
        }
        
        // Highlight best and worst aspects
        if !mealAnalysis.highScoringMeals.isEmpty {
            let bestMeal = mealAnalysis.highScoringMeals.first!
            analysis += "Your '\(bestMeal.name)' was particularly strong, "
        }
        
        if !mealAnalysis.lowScoringMeals.isEmpty {
            let worstMeal = mealAnalysis.lowScoringMeals.first!
            analysis += "while '\(worstMeal.name)' could use improvement. "
        }
        
        // Add health goal insights
        if !healthGoalAnalysis.strongestAreas.isEmpty {
            let strongAreas = healthGoalAnalysis.strongestAreas.prefix(2).joined(separator: ", ")
            analysis += "Your meals show strength in \(strongAreas), "
        }
        
        if !healthGoalAnalysis.weakestAreas.isEmpty {
            let weakArea = healthGoalAnalysis.weakestAreas.first!
            analysis += "but need more focus on \(weakArea.lowercased()). "
        }
        
        // Second paragraph: Specific recommendations to boost longevity score
        analysis += "\n\n"
        analysis += "To boost your average longevity score, try these specific meal recommendations: "
        
        // Generate specific meal recommendations based on improvement areas
        var recommendations: [String] = []
        
        if improvementAreas.contains("vegetable diversity") || nutritionalPatterns.vegetableTypes.isEmpty {
            recommendations.append("a colorful salad with spinach, bell peppers, and avocado drizzled with olive oil")
        }
        
        if improvementAreas.contains("antioxidant-rich foods") || nutritionalPatterns.antioxidantRich.isEmpty {
            recommendations.append("a berry smoothie with blueberries, Greek yogurt, and chia seeds")
        }
        
        if improvementAreas.contains("quality protein sources") || nutritionalPatterns.proteinSources.isEmpty {
            recommendations.append("grilled salmon with quinoa and steamed broccoli")
        }
        
        if healthGoalAnalysis.weakestAreas.contains("Anti-Inflammation") {
            recommendations.append("turmeric-spiced lentil curry with turmeric, ginger, and leafy greens")
        }
        
        if healthGoalAnalysis.weakestAreas.contains("Heart Health") {
            recommendations.append("Mediterranean-style meal with olive oil, nuts, and fatty fish")
        }
        
        // Add 1-2 specific recommendations
        if recommendations.count >= 2 {
            analysis += "\(recommendations[0]) or \(recommendations[1]). "
        } else if recommendations.count == 1 {
            analysis += "\(recommendations[0]). "
        } else {
            analysis += "a balanced meal with lean protein, colorful vegetables, and healthy fats. "
        }
        
        analysis += "These choices provide essential nutrients, antioxidants, and compounds that are part of dietary patterns researched for cellular health and longevity."
        
        return analysis.trimmingCharacters(in: .whitespaces)
    }
    
    private func loadAIMealAnalysis() {
        guard !isAIAnalysisLoading else { return }
        
        isAIAnalysisLoading = true
        
        // Get user's health goals (you may need to adjust this based on your health profile structure)
        let healthGoals = ["Anti-Inflammation", "Cardiovascular", "Blood Sugar", "Energy", "Immune"]
        
        AIService.shared.generateMealAnalysis(
            meals: dailyMeals,
            averageScore: dailyStats?.averageScore ?? 0.0,
            healthGoals: healthGoals
        ) { result in
            DispatchQueue.main.async {
                self.isAIAnalysisLoading = false
                if !result.isEmpty && !result.contains("Unable to generate") {
                    self.aiEncouragementText = result
                    self.cachedAIAnalysis = result // Cache the successful result
                    print("🤖 AI meal analysis loaded and cached successfully")
                } else {
                    print("🤖 AI meal analysis failed, using fallback")
                }
            }
        }
    }
    
    private func generateFallbackAnalysis() -> String {
        let mealCount = dailyMeals.count
        let averageScore = Int(dailyStats?.averageScore ?? 0.0)
        
        var analysis = ""
        
        if averageScore >= 85 {
            analysis += "Excellent day! Your \(mealCount) meals averaged \(averageScore) with outstanding longevity benefits. "
        } else if averageScore >= 75 {
            analysis += "Good performance! Your \(mealCount) meals averaged \(averageScore) with solid nutritional foundations. "
        } else if averageScore >= 65 {
            analysis += "Making progress! Your \(mealCount) meals averaged \(averageScore) with room to optimize. "
        } else {
            analysis += "Every meal counts! Your \(mealCount) meals averaged \(averageScore) - let's enhance nutritional quality. "
        }
        
        // Add basic meal analysis
        if !dailyMeals.isEmpty {
            let highScoringMeals = dailyMeals.filter { ($0.originalAnalysis?.overallScore ?? 0) >= 7 }
            let lowScoringMeals = dailyMeals.filter { ($0.originalAnalysis?.overallScore ?? 0) < 5 }
            
            if !highScoringMeals.isEmpty {
                let bestMeal = highScoringMeals.first!
                analysis += "Your '\(bestMeal.name)' was particularly strong, "
            }
            
            if !lowScoringMeals.isEmpty {
                let worstMeal = lowScoringMeals.first!
                analysis += "while '\(worstMeal.name)' could use improvement. "
            }
        }
        
        analysis += "Your meals show varying levels of essential nutrients that support your health goals."
        
        // Second paragraph with recommendations
        analysis += "\n\n"
        analysis += "To boost your average longevity score, try these specific meal recommendations: Add turmeric-spiced salmon with leafy greens for nutrients commonly studied in relation to inflammation, include avocado and nuts for heart-healthy fats, and choose steel-cut oats with berries for nutrients associated with blood sugar function. These choices provide essential nutrients, antioxidants, and compounds that are part of dietary patterns researched for cellular health and longevity."
        
        return analysis.trimmingCharacters(in: .whitespaces)
    }
    
    
    
    // MARK: - Analysis Data Structures
    private struct MealAnalysis {
        let highScoringMeals: [TrackedMeal]
        let lowScoringMeals: [TrackedMeal]
        let mealTypes: [String]
        let averageScore: Double
    }
    
    private struct HealthGoalAnalysis {
        let averageGoalScores: [String: Double]
        let goalsMet: [String]
        let strongestAreas: [String]
        let weakestAreas: [String]
    }
    
    private struct NutritionalPatterns {
        let proteinSources: [String]
        let vegetableTypes: [String]
        let processedFoods: [String]
        let antioxidantRich: [String]
    }
    
    // MARK: - Macro Data for Pie Chart
    private struct MacroData: Identifiable {
        let id = UUID()
        let name: String
        let value: Double // in grams
        let gradient: LinearGradient
        let primaryColor: Color // First color from gradient for hairlines
        
        var percentage: Double {
            // Will be calculated based on total
            return 0.0
        }
    }
    
    // MARK: - Calculate Total Macros from Today's Meals
    private var totalMacros: (protein: Double, carbs: Double, fat: Double, saturatedFat: Double, fiber: Double, sugar: Double) {
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        let totalSaturatedFat: Double = 0
        var totalFiber: Double = 0
        var totalSugar: Double = 0
        
        print("🔍 MealTrackingView: Calculating macros for \(filteredTodayMeals.count) meals")
        
        for meal in filteredTodayMeals {
            // Try to get updated analysis from cache (same logic as micronutrients)
            var analysis: FoodAnalysis? = nil
            
            // First try: Use imageHash to get cached analysis (most reliable, has updated nutrition)
            if let imageHash = meal.imageHash,
               let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
                analysis = cachedAnalysis
                print("🔍 MealTrackingView: Macros - Found analysis via imageHash for \(meal.name)")
            }
            // Second try: Use food name to get cached analysis
            else if let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: meal.name) {
                analysis = cachedAnalysis
                print("🔍 MealTrackingView: Macros - Found analysis via food name for \(meal.name)")
            }
            // Third try: Try matching by foods array (for meals with multiple foods)
            else if !meal.foods.isEmpty,
                    let firstFood = meal.foods.first,
                    let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: firstFood) {
                analysis = cachedAnalysis
                print("🔍 MealTrackingView: Macros - Found analysis via foods array for \(meal.name)")
            }
            // Fallback: Use stored originalAnalysis (may not have nutrition data)
            else if let originalAnalysis = meal.originalAnalysis {
                analysis = originalAnalysis
                print("🔍 MealTrackingView: Macros - Using stored originalAnalysis for \(meal.name)")
            }
            
            if let analysis = analysis,
               let nutrition = analysis.nutritionInfo {
                // Parse string values to doubles
                let protein = parseNutritionValue(nutrition.protein)
                let carbs = parseNutritionValue(nutrition.carbohydrates)
                let fat = parseNutritionValue(nutrition.fat)
                let fiber = parseNutritionValue(nutrition.fiber)
                let sugar = parseNutritionValue(nutrition.sugar)
                
                totalProtein += protein
                totalCarbs += carbs
                totalFat += fat
                totalFiber += fiber
                totalSugar += sugar
                
                print("🔍 MealTrackingView: Macros for \(meal.name) - Protein: \(protein)g, Carbs: \(carbs)g, Fat: \(fat)g")
            } else {
                print("⚠️ MealTrackingView: Macros - No nutrition info found for meal \(meal.name)")
            }
        }
        
        print("🔍 MealTrackingView: Total macros - Protein: \(totalProtein)g, Carbs: \(totalCarbs)g, Fat: \(totalFat)g, Fiber: \(totalFiber)g, Sugar: \(totalSugar)g")
        
        return (totalProtein, totalCarbs, totalFat, totalSaturatedFat, totalFiber, totalSugar)
    }
    
    // MARK: - Check if Nutrition Summary Should Regenerate
    private func shouldRegenerateNutritionSummary() -> Bool {
        let currentMealCount = filteredTodayMeals.count
        let calendar = Calendar.current
        
        // Regenerate if:
        // 1. No summary exists yet
        // 2. Meal count has changed
        // 3. It's a new day (summary is from yesterday)
        if nutritionSummaryText.isEmpty {
            return true
        }
        
        if currentMealCount != lastNutritionSummaryMealCount {
            return true
        }
        
        if let lastDate = lastNutritionSummaryDate,
           !calendar.isDate(lastDate, inSameDayAs: Date()) {
            return true
        }
        
        return false
    }
    
    // MARK: - Generate Nutrition Summary
    private func generateNutritionSummary() {
        guard !isLoadingNutritionSummary else { return }
        
        isLoadingNutritionSummary = true
        
        let macros = totalMacros
        let estimatedCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
        
        // Get user profile data
        let healthGoals = healthProfileManager.getHealthGoals()
        let healthGoalsText = healthGoals.isEmpty ? "general health and longevity" : healthGoals.joined(separator: ", ")
        let dietaryPreference = healthProfileManager.currentProfile?.dietaryPreference ?? "balanced"
        
        let prompt = """
        Generate a personalized daily nutrition analysis based on the user's tracked meals and health goals.

        USER'S DAILY INTAKE:
        - Calories: \(Int(estimatedCalories))
        - Protein: \(Int(macros.protein))g
        - Carbs: \(Int(macros.carbs))g
        - Fat: \(Int(macros.fat))g
        - Fiber: \(Int(macros.fiber))g
        - Sugar: \(Int(macros.sugar))g
        - Saturated Fat: \(Int(macros.saturatedFat))g

        USER'S HEALTH GOALS: \(healthGoalsText)
        USER'S DIETARY PREFERENCE: \(dietaryPreference)

        Generate a 3-4 sentence personalized analysis that:

        1. FIRST SENTENCE: Acknowledge what they did well today based on their goals
        2. SECOND SENTENCE: Provide ONE specific scientific insight relevant to their intake
        3. THIRD SENTENCE: Give ONE actionable suggestion for tomorrow based on gaps
        4. OPTIONAL FOURTH: Add encouragement if needed for motivation

        TONE: Knowledgeable but friendly, like a supportive nutritionist

        RULES:
        - Reference their specific health goals directly
        - Use actual numbers from their intake
        - Include ONE relevant scientific fact (no made-up statistics)
        - Keep total response under 75 words
        - Focus on positives first, then gentle improvements
        - If ratios are good, celebrate; if imbalanced, suggest specific fixes

        Return ONLY the personalized summary, no labels or formatting.
        """
        
        Task {
            do {
                let summary = try await AIService.shared.makeOpenAIRequestAsync(prompt: prompt)
                await MainActor.run {
                    nutritionSummaryText = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                    isLoadingNutritionSummary = false
                    lastNutritionSummaryMealCount = filteredTodayMeals.count
                    lastNutritionSummaryDate = Date()
                }
            } catch {
                print("Error generating nutrition summary: \(error)")
                await MainActor.run {
                    nutritionSummaryText = "Your nutrition data shows a balanced intake today. Keep tracking to see patterns over time!"
                    isLoadingNutritionSummary = false
                    lastNutritionSummaryMealCount = filteredTodayMeals.count
                    lastNutritionSummaryDate = Date()
                }
            }
        }
    }
    
    // MARK: - Parse Nutrition String to Double
    private func parseNutritionValue(_ value: String?) -> Double {
        // Handle optional String? values
        guard let value = value, !value.isEmpty else { return 0.0 }
        
        // Remove units in order from longest to shortest to avoid partial matches
        // Also handle Unicode microgram symbol (µg)
        var cleaned = value.replacingOccurrences(of: "µg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mcg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "IU", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "N/A", with: "0")
            .replacingOccurrences(of: "nil", with: "0")
        
        return Double(cleaned) ?? 0.0
    }
    
    // MARK: - Macros Pie Chart
    private var macrosPieChart: some View {
        let macros = totalMacros
        let total = macros.protein + macros.carbs + macros.fat + macros.fiber + macros.sugar
        
        guard total > 0 else {
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No nutritional data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            )
        }
        
        let macroData: [MacroData] = [
            MacroData(
                name: "Protein", 
                value: macros.protein,
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.478, blue: 1.0), // Blue (Snap It camera)
                        Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color(red: 0.0, green: 0.478, blue: 1.0)
            ),
            MacroData(
                name: "Carbs", 
                value: macros.carbs,
                gradient: LinearGradient(
                    colors: [
                        Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), // #E7850C Orange
                        Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)  // #D9E921 Lime green
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0) // #E7850C Orange
            ),
            MacroData(
                name: "Fat", 
                value: macros.fat,
                gradient: LinearGradient(
                    colors: [
                        Color.purple, // Purple (Upload It photo)
                        Color(red: 0.6, green: 0.2, blue: 0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color.purple
            ),
            MacroData(
                name: "Fiber", 
                value: macros.fiber,
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.557, blue: 0.498), // Teal-green (Say It mic)
                        Color(red: 0.3, green: 0.7, blue: 0.6)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color(red: 0.42, green: 0.557, blue: 0.498)
            ),
            MacroData(
                name: "Sugar", 
                value: macros.sugar,
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.255, green: 0.643, blue: 0.655), // Teal (Compare arrow)
                        Color(red: 0.0, green: 0.8, blue: 0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color(red: 0.255, green: 0.643, blue: 0.655)
            )
        ].filter { $0.value > 0 } // Only show macros with values
        
        // Create indices array for ForEach
        let indices: [Int] = Array(0..<macroData.count)
        
        // Calculate estimated calories
        let estimatedCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
        
        return AnyView(
            VStack(spacing: 0) {
                // Pie Chart with callouts overlay - increased height to prevent clipping
                ZStack {
                    // Pie Chart - Larger size
                    Chart {
                        ForEach(macroData) { macro in
                            SectorMark(
                                angle: .value("Value", macro.value),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(macro.gradient)
                        }
                    }
                    .frame(height: 280) // Increased from 200 to 280
                    .padding(.horizontal, 70) // Increased padding for callouts
                    .padding(.vertical, 60) // Vertical padding for callouts
                    
                    // Kcal number in center of donut hole
                    GeometryReader { geometry in
                        let centerX = geometry.size.width / 2
                        let centerY = geometry.size.height / 2
                        
                        VStack(spacing: 2) {
                            Text("\(Int(estimatedCalories))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Kcal")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .position(x: centerX, y: centerY)
                    }
                    .frame(height: 280)
                    
                    // Callouts with hairlines overlay
                    GeometryReader { geometry in
                        let chartSize: CGFloat = 280 // Increased from 200
                        let centerX = geometry.size.width / 2
                        let centerY: CGFloat = geometry.size.height / 2 // Center vertically in available space
                        let radius: CGFloat = 110 // Increased from 80 to 110 (proportionally larger)
                        let calloutIndices = Array(0..<macroData.count)
                        
                        ZStack {
                            ForEach(calloutIndices, id: \.self) { index in
                                let macro = macroData[index]
                                let percentage = macro.value / total
                                // Calculate cumulative angle up to this slice (starting from top, clockwise)
                                let previousTotal = macroData.prefix(index).reduce(0.0) { $0 + $1.value }
                                let cumulativeAngle = -90.0 + (previousTotal / total) * 360.0 // Start at top (-90 degrees)
                                // Middle angle of this slice
                                let middleAngle = cumulativeAngle + (percentage * 360 / 2)
                                let angleInRadians = middleAngle * .pi / 180
                                
                                // Position on edge of pie chart (outer edge)
                                let sliceEdgeX = centerX + cos(angleInRadians) * radius
                                let sliceEdgeY = centerY + sin(angleInRadians) * radius
                                
                                // Position for label (further out)
                                let labelDistance: CGFloat = radius + 40
                                let labelX = centerX + cos(angleInRadians) * labelDistance
                                let labelY = centerY + sin(angleInRadians) * labelDistance
                                
                                // Hairline from slice to label
                                Path { path in
                                    path.move(to: CGPoint(x: sliceEdgeX, y: sliceEdgeY))
                                    path.addLine(to: CGPoint(x: labelX, y: labelY))
                                }
                                .stroke(macro.primaryColor.opacity(0.5), lineWidth: 1.5)
                                
                                // Label with value (current/target format)
                                let targetValue = getMacroTargetValue(for: macro.name)
                                VStack(spacing: 2) {
                                    Text(macro.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("\(Int(macro.value))/\(Int(targetValue))g")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(colorScheme == .dark ? Color.black.opacity(0.9) : Color.white.opacity(0.95))
                                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                                )
                                .position(x: labelX, y: labelY)
                            }
                        }
                    }
                }
                .frame(height: 380) // Increased from 300 to 380 to accommodate larger chart and callouts
                .clipped() // Prevent callouts from extending beyond bounds
            }
            .padding(.vertical, 8)
        )
    }
    
    private let nutritionalCategories = [
        "Kcal", "Protein", "Carbs", "Fat", "Saturated fat", 
        "Fiber", "Sodium", "Iron", "Potassium", "Calcium", "Sugar"
    ]
    
    private func nutritionalValue(for category: String) -> String {
        // Calculate from actual meal data
        let macros = totalMacros
        
        switch category {
        case "Kcal":
            // Estimate calories: protein*4 + carbs*4 + fat*9
            let estimatedCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
            return "\(Int(estimatedCalories))"
        case "Protein":
            return "\(Int(macros.protein))g"
        case "Carbs":
            return "\(Int(macros.carbs))g"
        case "Fat":
            return "\(Int(macros.fat))g"
        case "Saturated fat":
            return "\(Int(macros.saturatedFat))g"
        case "Fiber":
            return "\(Int(macros.fiber))g"
        case "Sugar":
            return "\(Int(macros.sugar))g"
        case "Sodium":
            // Would need to parse from meals
            return "N/A"
        case "Iron":
            return "N/A"
        case "Potassium":
            return "N/A"
        case "Calcium":
            return "N/A"
        default:
            return "N/A"
        }
    }
}

// MARK: - Supporting Views

struct MealStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let onTap: (() -> Void)?
    let subtitle: String?
    
    init(title: String, value: String, icon: String, color: Color, onTap: (() -> Void)? = nil, subtitle: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.onTap = onTap
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            onTap?()
        }
        .opacity(onTap != nil ? 1.0 : 0.7)
        .scaleEffect(onTap != nil ? 1.0 : 0.98)
        .animation(.easeInOut(duration: 0.1), value: onTap != nil)
    }
}

// MARK: - Meal List Row View (list-style like Recently Analyzed)
struct MealListRowView: View {
    let meal: TrackedMeal
    let onTap: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var cachedImage: UIImage?
    @State private var showingDeleteConfirmation = false
    
    init(meal: TrackedMeal, onTap: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.meal = meal
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Image - try to get from FoodCacheEntry by matching meal name
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let image = cachedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .clipped()
                            } else if meal.imageHash != nil {
                                // Loading placeholder for image
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .foregroundColor(.gray)
                                    )
                                    .onAppear {
                                        loadImage()
                                    }
                            } else {
                                // Text/voice entry - show black box with gradient icon
                                // Note: TrackedMeal doesn't have inputMethod, so we'll need to get it from FoodCacheEntry if available
                                TextVoiceEntryIcon(inputMethod: nil, size: 60)
                            }
                        }
                        
                        // Heart icon (bottom left) - blue-purple to bright blue gradient, not tappable
                        if meal.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 64/255.0, green: 56/255.0, blue: 213/255.0),  // Blue-purple #4038D5
                                            Color(red: 12/255.0, green: 97/255.0, blue: 255/255.0)   // Bright blue #0C61FF
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .padding(4)
                        }
                    }
                    
                    // Title and Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(meal.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Score Circle
                    GroceryScoreCircleCompact(score: Int(meal.healthScore))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.42, green: 0.557, blue: 0.498), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Delete Button (matching Score screen style) - Top Right Corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(colorScheme == .dark ? Color(.lightGray) : Color(red: 0.42, green: 0.557, blue: 0.498))
                            .frame(width: 44, height: 44) // Larger tap area
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, -8) // Move much closer to top edge
                    .padding(.trailing, -8) // Move much closer to right edge
                }
                Spacer()
            }
            .zIndex(1) // Ensure X button is above card button
            .allowsHitTesting(true) // Explicitly enable hit testing
        }
        .confirmationDialog("Delete?", isPresented: $showingDeleteConfirmation) {
            Button("Yes", role: .destructive) {
                onDelete()
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(meal.name)'?")
        }
    }
    
    private func loadImage() {
        // Use direct hash lookup (fast, like Shop screen) if imageHash is available
        if let imageHash = meal.imageHash {
            // Direct lookup - instant load from disk
            if let image = foodCacheManager.loadImage(forHash: imageHash) {
                cachedImage = image
                return
            }
        }
        
        // Fallback: Try to find image using originalAnalysis or name matching (for old meals without imageHash)
        DispatchQueue.global(qos: .userInitiated).async {
            var matchingEntry: FoodCacheEntry?
            
            // First, try to match by originalAnalysis if available
            if let originalAnalysis = meal.originalAnalysis {
                // Find cache entries that match the analysis
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    // Match by food name and analysis content
                    entry.foodName == originalAnalysis.foodName &&
                    entry.fullAnalysis.overallScore == originalAnalysis.overallScore
                }
                
                // Get the most recent matching entry (closest to meal timestamp)
                matchingEntry = matchingEntries.sorted { entry1, entry2 in
                    let diff1 = abs(entry1.analysisDate.timeIntervalSince(meal.timestamp))
                    let diff2 = abs(entry2.analysisDate.timeIntervalSince(meal.timestamp))
                    return diff1 < diff2
                }.first
            }
            
            // Fallback to name matching if no originalAnalysis match found
            if matchingEntry == nil {
                let mealName = meal.name.lowercased().trimmingCharacters(in: .whitespaces)
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
                    return entryName == mealName || 
                           entryName.contains(mealName) || 
                           mealName.contains(entryName)
                }
                
                // Get the most recent matching entry (closest to meal timestamp)
                matchingEntry = matchingEntries.sorted { entry1, entry2 in
                    let diff1 = abs(entry1.analysisDate.timeIntervalSince(meal.timestamp))
                    let diff2 = abs(entry2.analysisDate.timeIntervalSince(meal.timestamp))
                    return diff1 < diff2
                }.first
            }
            
            if let entry = matchingEntry, let imageHash = entry.imageHash {
                if let image = foodCacheManager.loadImage(forHash: imageHash) {
                    DispatchQueue.main.async {
                        cachedImage = image
                    }
                }
            }
        }
    }
}

// MARK: - Today Meal Card (for carousel)
struct TodayMealCard: View {
    let meal: TrackedMeal
    let isDeleteSelected: Bool
    let onTap: () -> Void
    let onDeleteTap: () -> Void
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var cachedImage: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Square Image with Score Circle Overlay - fixed size
            ZStack(alignment: .bottomTrailing) {
                // Meal Image - ensure perfect square with fixed size
                Group {
                    if let image = cachedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 20))
                            )
                            .onAppear {
                                loadImage()
                            }
                    }
                }
                .frame(width: 140, height: 140)
                .clipped()
                .cornerRadius(8)
            
                // Score Circle - lower right corner (100% larger: 28pt -> 56pt)
                Circle()
                    .fill(scoreGradient(Int(meal.healthScore)))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text("\(Int(meal.healthScore))")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding(4)
                
                // Delete Button - top right corner
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDeleteTap) {
                            Circle()
                                .fill(isDeleteSelected ? Color.red : Color.white.opacity(0.7))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(isDeleteSelected ? .white : .black.opacity(0.8))
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                    }
                    Spacer()
                }
                .padding(4)
            }
            .frame(width: 140, height: 140)
            .onTapGesture {
                onTap()
            }
            
            // Meal Name (max 2 lines)
            Text(meal.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 140, alignment: .leading)
        }
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
    
    private func loadImage() {
        // Use direct hash lookup (fast, like Shop screen) if imageHash is available
        if let imageHash = meal.imageHash {
            // Direct lookup - instant load from disk
            if let image = foodCacheManager.loadImage(forHash: imageHash) {
                cachedImage = image
                return
            }
        }
        
        // Fallback: Try to find image using originalAnalysis or name matching (for old meals without imageHash)
        DispatchQueue.global(qos: .userInitiated).async {
            var matchingEntry: FoodCacheEntry?
            
            // First, try to match by originalAnalysis if available
            if let originalAnalysis = meal.originalAnalysis {
                // Find cache entries that match the analysis
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    // Match by food name and analysis content
                    entry.foodName == originalAnalysis.foodName &&
                    entry.fullAnalysis.overallScore == originalAnalysis.overallScore
                }
                
                // Get the most recent matching entry (closest to meal timestamp)
                matchingEntry = matchingEntries.sorted { entry1, entry2 in
                    let diff1 = abs(entry1.analysisDate.timeIntervalSince(meal.timestamp))
                    let diff2 = abs(entry2.analysisDate.timeIntervalSince(meal.timestamp))
                    return diff1 < diff2
                }.first
            }
            
            // Fallback to name matching if no originalAnalysis match found
            if matchingEntry == nil {
                let mealName = meal.name.lowercased().trimmingCharacters(in: .whitespaces)
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
                    return entryName == mealName ||
                           entryName.contains(mealName) ||
                           mealName.contains(entryName)
                }
                
                // Get the most recent matching entry (closest to meal timestamp)
                matchingEntry = matchingEntries.sorted { entry1, entry2 in
                    let diff1 = abs(entry1.analysisDate.timeIntervalSince(meal.timestamp))
                    let diff2 = abs(entry2.analysisDate.timeIntervalSince(meal.timestamp))
                    return diff1 < diff2
                }.first
            }
            
            if let entry = matchingEntry, let imageHash = entry.imageHash {
                if let image = foodCacheManager.loadImage(forHash: imageHash) {
                    DispatchQueue.main.async {
                        cachedImage = image
                    }
                }
            }
        }
    }
}

// MARK: - Meal Grid Card View
struct MealGridCardView: View {
    let meal: TrackedMeal
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void
    let scoreCircleSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var cachedImage: UIImage?
    
    init(meal: TrackedMeal, isEditing: Bool, isSelected: Bool, onTap: @escaping () -> Void, onToggleSelection: @escaping () -> Void, scoreCircleSize: CGFloat = 28) {
        self.meal = meal
        self.isEditing = isEditing
        self.isSelected = isSelected
        self.onTap = onTap
        self.onToggleSelection = onToggleSelection
        self.scoreCircleSize = scoreCircleSize
    }
    
    var body: some View {
        Button(action: {
            if isEditing {
                // In edit mode: toggle selection
                onToggleSelection()
            } else {
                // Normal mode: open meal
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Square Image with Score Circle Overlay
                GeometryReader { geometry in
                    ZStack(alignment: .bottomTrailing) {
                        // Meal Image - ensure perfect square
                        Group {
                            if let image = cachedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 10))
                                    )
                                    .onAppear {
                                        loadImage()
                                    }
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                        .cornerRadius(0) // No rounded corners
                    
                        // Heart icon (bottom left) - blue-purple to bright blue gradient, not tappable
                        if meal.isFavorite {
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 64/255.0, green: 56/255.0, blue: 213/255.0),  // Blue-purple #4038D5
                                                    Color(red: 12/255.0, green: 97/255.0, blue: 255/255.0)   // Bright blue #0C61FF
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    Spacer()
                                }
                            }
                            .padding(4)
                        }
                        
                        // Score Circle (number only, no text) - lower right corner
                        Circle()
                            .fill(scoreGradient(Int(meal.healthScore)))
                            .frame(width: scoreCircleSize, height: scoreCircleSize)
                            .overlay(
                                Text("\(Int(meal.healthScore))")
                                    .font(.system(size: scoreCircleSize == 56 ? 20 : 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(4)
                        
                        // Selection Circle (when editing) - top right corner (visual only, not tappable)
                        if isEditing {
                            VStack {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(isSelected ? Color.red : Color.white)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(isSelected ? .white : .black)
                                        )
                                }
                                Spacer()
                            }
                            .padding(4)
                            .allowsHitTesting(false) // Make it non-interactive - whole card handles taps
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                
                // Meal Name (max 2 lines) - smaller text
                Text(meal.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 28, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Gradient that runs from red to green based on score
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
    
    private func loadImage() {
        // Use direct hash lookup (fast, like Shop screen) if imageHash is available
        if let imageHash = meal.imageHash {
            // Direct lookup - instant load from disk
            if let image = foodCacheManager.loadImage(forHash: imageHash) {
                cachedImage = image
                return
            }
        }
        
        // Fallback: Try to find image using originalAnalysis or name matching (for old meals without imageHash)
        DispatchQueue.global(qos: .userInitiated).async {
            var matchingEntry: FoodCacheEntry?
            
            // First, try to match by originalAnalysis if available
            if let originalAnalysis = meal.originalAnalysis {
                // Find cache entries that match the analysis
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    // Match by food name and analysis content
                    entry.foodName == originalAnalysis.foodName &&
                    entry.fullAnalysis.overallScore == originalAnalysis.overallScore
                }
                
                // Get the most recent matching entry (closest to meal timestamp)
                matchingEntry = matchingEntries.sorted { entry1, entry2 in
                    let diff1 = abs(entry1.analysisDate.timeIntervalSince(meal.timestamp))
                    let diff2 = abs(entry2.analysisDate.timeIntervalSince(meal.timestamp))
                    return diff1 < diff2
                }.first
            }
            
            // Fallback to name matching if no originalAnalysis match found
            if matchingEntry == nil {
                let mealName = meal.name.lowercased().trimmingCharacters(in: .whitespaces)
                let matchingEntries = foodCacheManager.cachedAnalyses.filter { entry in
                    let entryName = entry.foodName.lowercased().trimmingCharacters(in: .whitespaces)
                    return entryName == mealName || 
                           entryName.contains(mealName) || 
                           mealName.contains(entryName)
                }
                
                // Get the most recent matching entry (closest to meal timestamp)
                matchingEntry = matchingEntries.sorted { entry1, entry2 in
                    let diff1 = abs(entry1.analysisDate.timeIntervalSince(meal.timestamp))
                    let diff2 = abs(entry2.analysisDate.timeIntervalSince(meal.timestamp))
                    return diff1 < diff2
                }.first
            }
            
            if let entry = matchingEntry, let imageHash = entry.imageHash {
                if let image = foodCacheManager.loadImage(forHash: imageHash) {
                    DispatchQueue.main.async {
                        self.cachedImage = image
                    }
                }
            }
        }
    }
}

// MARK: - Legacy MealRow (kept for compatibility, but not used)
struct MealRow: View {
    let meal: TrackedMeal
    let onTap: () -> Void
    let onDelete: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    // Score Badge (matching FoodCacheRow style)
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", meal.healthScore))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                        
                        Text("Score")
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? .black.opacity(0.8) : .white.opacity(0.8))
                    }
                    .frame(width: 80, height: 80)
                    .background(scoreColor(Int(meal.healthScore)))
                    .cornerRadius(40)
                    
                    // Meal Name
                    Text(meal.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: 80)
                    
                    // Time
                    Text(meal.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.6), lineWidth: 0.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Delete Button (matching FoodCacheRow style)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                            .padding(8)
                    }
                }
                Spacer()
            }
        }
        .alert("Delete Meal?", isPresented: $showingDeleteConfirmation) {
            Button("Yes", role: .destructive) {
                onDelete()
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this meal?")
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
}

// MARK: - Data Models

struct TrackedMeal: Identifiable, Equatable {
    let id: UUID
    let name: String
    let foods: [String]
    let healthScore: Double
    let goalsMet: [String]
    let timestamp: Date
    let notes: String?
    let originalAnalysis: FoodAnalysis? // Store the original analysis for detailed view
    let imageHash: String? // Store image hash for fast direct lookup (like Shop screen)
    var isFavorite: Bool
    
    init(id: UUID, name: String, foods: [String], healthScore: Double, goalsMet: [String], timestamp: Date, notes: String?, originalAnalysis: FoodAnalysis?, imageHash: String?, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.foods = foods
        self.healthScore = healthScore
        self.goalsMet = goalsMet
        self.timestamp = timestamp
        self.notes = notes
        self.originalAnalysis = originalAnalysis
        self.imageHash = imageHash
        self.isFavorite = isFavorite
    }
}

struct DailyStats {
    let mealCount: Int
    let averageScore: Double
    let goalsMet: Int
}

// MARK: - Score Data Point for Graph
struct ScoreDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
    let label: String // e.g., "Mon", "Jan 1", etc.
}

struct DailyTimelineData: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double // 0.0 if no data
    let hasData: Bool
    let dateString: String // Format: "12/23 Tues"
}

// MARK: - Daily Score Card Component
struct DailyScoreCard: View {
    let data: DailyTimelineData
    let isToday: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private let maxBarHeight: CGFloat = 120
    private let cardWidth: CGFloat = 80
    private let circleSize: CGFloat = 40  // Increased from 30 to 40
    private let barWidth: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 8) {
            // Vertical Bar with Circle at Top
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // Vertical Bar
                    VStack {
                        Spacer()
                        
                        if data.hasData {
                            let barHeight = maxBarHeight * CGFloat(data.score / 100.0)
                            Rectangle()
                                .fill(scoreGradient(Int(data.score)))
                                .frame(width: barWidth, height: max(barHeight, 2))
                                .cornerRadius(0) // Square corners
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: barWidth, height: 2)
                        }
                    }
                    .frame(width: cardWidth)
                    
                    // Score Circle at top of bar
                    if data.hasData {
                        Circle()
                            .fill(scoreGradient(Int(data.score)))
                            .frame(width: circleSize, height: circleSize)
                            .overlay(
                                Text("\(Int(data.score))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 0.5)  // Reduced shadow size
                            .offset(y: -circleSize / 2)  // Position circle so half is above bar, half overlaps
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: circleSize, height: circleSize)
                            .overlay(
                                Image(systemName: "minus")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            )
                            .offset(y: -circleSize / 2)
                    }
                }
                .frame(width: cardWidth)
            }
            .frame(height: maxBarHeight)
            
            // Date String
            Text(data.dateString)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: cardWidth)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black : Color.white)
                .shadow(
                    color: colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.15),
                    radius: 16,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isToday ?
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.557, blue: 0.498),
                            Color(red: 0.3, green: 0.7, blue: 0.6)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isToday ? 2 : 0
                )
        )
        .scaleEffect(isToday ? 1.05 : 1.0)
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
}

// MARK: - Macro Target Popup
struct MacroTargetPopup: View {
    let macroName: String
    let currentValue: Double
    let targetValue: Double
    let rdaValue: Double
    let targetMode: MealTrackingView.TargetMode
    let onSave: (Double) -> Void
    let onCancel: () -> Void
    
    @State private var inputValue: String
    @FocusState private var isInputFocused: Bool
    
    init(macroName: String, currentValue: Double, targetValue: Double, rdaValue: Double, targetMode: MealTrackingView.TargetMode, onSave: @escaping (Double) -> Void, onCancel: @escaping () -> Void) {
        self.macroName = macroName
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.rdaValue = rdaValue
        self.targetMode = targetMode
        self.onSave = onSave
        self.onCancel = onCancel
        let initialValue = targetValue > 0 ? targetValue : rdaValue
        _inputValue = State(initialValue: initialValue > 0 ? String(Int(round(initialValue))) : "")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    // Macro icon based on name
                    let iconName: String = {
                        switch macroName {
                        case "Protein": return "dumbbell.fill"
                        case "Carbs": return "leaf.fill"
                        case "Fat": return "drop.fill"
                        case "Fiber": return "leaf.fill"
                        case "Sugar": return "sparkles"
                        default: return "chart.pie.fill"
                        }
                    }()
                    
                    Image(systemName: iconName)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: {
                                    switch macroName {
                                    case "Protein": return [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.0, green: 0.8, blue: 0.8)]
                                    case "Carbs": return [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)]
                                    case "Fat": return [Color(red: 1.0, green: 0.843, blue: 0.0), Color(red: 0.678, green: 0.847, blue: 0.902)]
                                    case "Fiber": return [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)]
                                    case "Sugar": return [Color.red, Color.orange]
                                    default: return [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)]
                                    }
                                }(),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(macroName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Current: \(Int(round(currentValue)))g")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Set Target (g)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter target value", text: $inputValue)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title3)
                        .focused($isInputFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isInputFocused = true
                            }
                        }
                    
                    // Show RDA reference in Custom mode
                    if targetMode == .custom {
                        Text("RDA: \(Int(round(rdaValue)))g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        if let value = Double(inputValue), value > 0 {
                            onSave(value)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(Double(inputValue) == nil || Double(inputValue)! <= 0)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Set \(macroName) Target")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Micronutrient Target Popup
struct MicronutrientTargetPopup: View {
    let micronutrientName: String
    let micronutrientIcon: String
    let micronutrientUnit: String
    let micronutrientGradient: LinearGradient
    let currentValue: Double
    let targetValue: Double
    let rdaValue: Double?
    let targetMode: MealTrackingView.TargetMode
    let onSave: (Double) -> Void
    let onCancel: () -> Void
    
    @State private var inputValue: String
    @FocusState private var isInputFocused: Bool
    
    init(micronutrient: MealTrackingView.Micronutrient, currentValue: Double, targetValue: Double, rdaValue: Double?, targetMode: MealTrackingView.TargetMode, onSave: @escaping (Double) -> Void, onCancel: @escaping () -> Void) {
        self.micronutrientName = micronutrient.name
        self.micronutrientIcon = micronutrient.icon
        self.micronutrientUnit = micronutrient.unit
        self.micronutrientGradient = micronutrient.iconGradient
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.rdaValue = rdaValue
        self.targetMode = targetMode
        self.onSave = onSave
        self.onCancel = onCancel
        // Pre-fill with RDA value if available and no custom target set
        let initialValue = targetValue > 0 ? targetValue : (rdaValue ?? 0)
        _inputValue = State(initialValue: initialValue > 0 ? String(Int(round(initialValue))) : "")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: micronutrientIcon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(micronutrientGradient)
                    
                    Text(micronutrientName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Current: \(Int(round(currentValue))) \(micronutrientUnit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Set Target (\(micronutrientUnit))")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter target value", text: $inputValue)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title3)
                        .focused($isInputFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isInputFocused = true
                            }
                        }
                    
                    // Show RDA reference in Custom mode
                    if targetMode == .custom, let rda = rdaValue {
                        Text("RDA: \(Int(round(rda))) \(micronutrientUnit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        if let value = Double(inputValue), value > 0 {
                            onSave(value)
                        }
                    }) {
                        Text("Save Target")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.42, green: 0.557, blue: 0.498),
                                        Color(red: 0.3, green: 0.7, blue: 0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(inputValue.isEmpty || Double(inputValue) == nil || (Double(inputValue) ?? 0) <= 0)
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Set Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if let value = Double(inputValue), value > 0 {
                            onSave(value)
                        } else {
                            onCancel()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onDateSelected: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Pick Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDateSelected()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Scientific Analysis Functions
extension MealTrackingView {
    private func generateMealScientificExplanation(meal: TrackedMeal) -> String {
        guard let analysis = meal.originalAnalysis else {
            return "Your '\(meal.name)' shows strong nutritional foundations. "
        }
        
        // Get scientific explanations from all categories
        let bioactiveCompounds = analyzeBioactiveCompounds(analysis: analysis)
        let nutrients = analyzeNutrientProfile(analysis: analysis)
        let healthMechanisms = analyzeHealthMechanisms(analysis: analysis)
        
        // Build comprehensive scientific explanation with complete sentences
        var explanation = "Your '\(meal.name)' "
        
        // Combine explanations for a more complete analysis
        var explanations: [String] = []
        
        if !bioactiveCompounds.isEmpty {
            explanations.append(bioactiveCompounds.first!)
        }
        if !nutrients.isEmpty {
            explanations.append(nutrients.first!)
        }
        if !healthMechanisms.isEmpty {
            explanations.append(healthMechanisms.first!)
        }
        
        if !explanations.isEmpty {
            // Join explanations with proper sentence structure
            if explanations.count == 1 {
                explanation += "provides \(explanations.first!.lowercased()). "
            } else {
                explanation += "offers multiple health benefits: \(explanations.joined(separator: " Additionally, ")). "
            }
        } else {
            explanation += "shows strong nutritional foundations. "
        }
        
        return explanation
    }
    
    private func generateLowScoringMealAnalysis(_ lowScoringMeals: [TrackedMeal]) -> String {
        guard let lowMeal = lowScoringMeals.first else { return "" }
        
        let score = Int(lowMeal.healthScore) // Score is already on 0-100 scale (matches Score screen)
        let mealName = lowMeal.name
        
        // Analyze specific nutritional concerns
        var concerns: [String] = []
        var treatAcknowledgment = ""
        
        if let analysis = lowMeal.originalAnalysis {
            // Check for high sugar content
            let nutrition = analysis.nutritionInfoOrDefault
            if let sugar = Double(nutrition.sugar.replacingOccurrences(of: "g", with: "")) {
                if sugar >= 20 {
                    concerns.append("high sugar content (\(Int(sugar))g) which can spike blood glucose, contribute to inflammation, and accelerate cellular aging")
                } else if sugar >= 10 {
                    concerns.append("moderate sugar content (\(Int(sugar))g) that may cause energy crashes and blood sugar fluctuations")
                }
            }
            
            // Check for high sodium
            if let sodium = Double(nutrition.sodium.replacingOccurrences(of: "mg", with: "")) {
                if sodium >= 1200 {
                    concerns.append("excessive sodium levels (\(Int(sodium))mg) that can increase blood pressure and strain cardiovascular health")
                } else if sodium >= 800 {
                    concerns.append("elevated sodium levels (\(Int(sodium))mg) that may contribute to water retention and cardiovascular stress")
                }
            }
            
            // Check for low fiber
            if let fiber = Double(nutrition.fiber.replacingOccurrences(of: "g", with: "")) {
                if fiber < 3 {
                    concerns.append("minimal fiber content (\(Int(fiber))g) which limits gut microbiome benefits and may contribute to digestive issues")
                } else if fiber < 5 {
                    concerns.append("low fiber content (\(Int(fiber))g) that doesn't provide optimal gut health support")
                }
            }
            
            // Check for high saturated fat
            if let fat = Double(nutrition.fat.replacingOccurrences(of: "g", with: "")) {
                if fat >= 20 {
                    concerns.append("high fat content (\(Int(fat))g) that may contribute to inflammation and metabolic dysfunction")
                }
            }
            
            // Check for low protein
            if let protein = Double(nutrition.protein.replacingOccurrences(of: "g", with: "")) {
                if protein < 10 {
                    concerns.append("inadequate protein (\(Int(protein))g) which limits muscle maintenance and cellular repair processes")
                }
            }
            
            // Check for high calories with low nutrients
            if let calories = Double(nutrition.calories.replacingOccurrences(of: "kcal", with: "")) {
                if calories >= 500 && (Double(nutrition.fiber.replacingOccurrences(of: "g", with: "")) ?? 0) < 5 {
                    concerns.append("high calorie density (\(Int(calories)) calories) with minimal nutritional value, leading to empty calories")
                }
            }
            
            // Check for processed ingredients
            let processedKeywords = ["processed", "refined", "artificial", "preservative", "additive", "hydrogenated", "trans fat"]
            let hasProcessedIngredients = analysis.ingredientsOrDefault.contains { ingredient in
                processedKeywords.contains { keyword in
                    ingredient.name.lowercased().contains(keyword)
                }
            }
            
            if hasProcessedIngredients {
                concerns.append("processed ingredients that may contain harmful additives, lack natural nutrients, and contribute to chronic inflammation")
            }
            
            // Check for refined carbohydrates
            let refinedKeywords = ["white flour", "white rice", "white bread", "refined", "enriched flour"]
            let hasRefinedCarbs = analysis.ingredientsOrDefault.contains { ingredient in
                refinedKeywords.contains { keyword in
                    ingredient.name.lowercased().contains(keyword)
                }
            }
            
            if hasRefinedCarbs {
                concerns.append("refined carbohydrates that cause rapid blood sugar spikes and lack essential nutrients")
            }
            
            // Check for artificial sweeteners
            let artificialSweetenerKeywords = ["aspartame", "sucralose", "saccharin", "acesulfame", "artificial sweetener"]
            let hasArtificialSweeteners = analysis.ingredientsOrDefault.contains { ingredient in
                artificialSweetenerKeywords.contains { keyword in
                    ingredient.name.lowercased().contains(keyword)
                }
            }
            
            if hasArtificialSweeteners {
                concerns.append("artificial sweeteners that may disrupt gut microbiome and metabolic health")
            }
            
            // Check for high fructose corn syrup
            let hfcsKeywords = ["high fructose corn syrup", "hfcs", "corn syrup"]
            let hasHFCS = analysis.ingredientsOrDefault.contains { ingredient in
                hfcsKeywords.contains { keyword in
                    ingredient.name.lowercased().contains(keyword)
                }
            }
            
            if hasHFCS {
                concerns.append("high fructose corn syrup that can contribute to fatty liver disease and metabolic dysfunction")
            }
            
            // Check for trans fats
            let transFatKeywords = ["partially hydrogenated", "trans fat", "hydrogenated oil"]
            let hasTransFats = analysis.ingredientsOrDefault.contains { ingredient in
                transFatKeywords.contains { keyword in
                    ingredient.name.lowercased().contains(keyword)
                }
            }
            
            if hasTransFats {
                concerns.append("trans fats that increase inflammation, raise bad cholesterol, and significantly increase cardiovascular disease risk")
            }
        }
        
        // Determine if it's a treat-type food
        let treatKeywords = ["dessert", "sweet", "cake", "cookie", "candy", "chocolate", "ice cream", "pastry", "pie", "treat"]
        let isTreat = treatKeywords.contains { keyword in
            mealName.lowercased().contains(keyword)
        }
        
        if isTreat {
            treatAcknowledgment = " While this appears to be a treat, it's perfectly fine to enjoy occasionally as part of a balanced approach to nutrition. "
        } else {
            treatAcknowledgment = " For regular meals, consider incorporating more nutrient-dense alternatives. "
        }
        
        // Build the analysis
        var analysis = "Your '\(mealName)' scored \(score), which indicates significant nutritional concerns. "
        
        if !concerns.isEmpty {
            if concerns.count == 1 {
                analysis += "Specifically, it contains \(concerns.first!). "
            } else if concerns.count == 2 {
                analysis += "The main concerns include \(concerns.joined(separator: " and ")). "
            } else {
                analysis += "Key concerns include \(concerns.prefix(3).joined(separator: ", ")), and \(concerns.count - 3) other nutritional issues. "
            }
        } else {
            analysis += "This meal lacks the nutrient density needed for optimal health and may contribute to chronic disease risk. "
        }
        
        // Add additional health impact warnings for very low scores
        if score < 40 {
            analysis += "Such low scores are associated with increased risk of metabolic syndrome, cardiovascular disease, and accelerated aging. "
        } else if score < 50 {
            analysis += "Regular consumption of such foods may contribute to inflammation, weight gain, and reduced longevity. "
        }
        
        analysis += treatAcknowledgment
        
        return analysis
    }
    
    private func analyzeNutrientProfile(analysis: FoodAnalysis) -> [String] {
        var nutrients: [String] = []
        
        // Analyze protein content
        let nutrition2 = analysis.nutritionInfoOrDefault
        if let protein = Double(nutrition2.protein.replacingOccurrences(of: "g", with: "")) {
            if protein >= 20 {
                nutrients.append("High-quality protein (\(Int(protein))g) supports muscle protein synthesis and cellular repair.")
            } else if protein >= 10 {
                nutrients.append("Moderate protein (\(Int(protein))g) provides essential amino acids for tissue maintenance.")
            }
        }
        
        // Analyze fiber content
        if let fiber = Double(nutrition2.fiber.replacingOccurrences(of: "g", with: "")) {
            if fiber >= 8 {
                nutrients.append("High fiber (\(Int(fiber))g) is associated with gut microbiome diversity and is part of dietary patterns researched for normal inflammatory function.")
            } else if fiber >= 4 {
                nutrients.append("Good fiber content (\(Int(fiber))g) supports digestive health and satiety.")
            }
        }
        
        // Analyze fat content
        if let fat = Double(nutrition2.fat.replacingOccurrences(of: "g", with: "")) {
            if fat >= 15 {
                nutrients.append("Healthy fats (\(Int(fat))g) enhance nutrient absorption and support brain function.")
            }
        }
        
        return nutrients
    }
    
    private func analyzeBioactiveCompounds(analysis: FoodAnalysis) -> [String] {
        var compounds: [String] = []
        
        // Analyze ingredients for specific bioactive compounds
        for ingredient in analysis.ingredientsOrDefault {
            let name = ingredient.name.lowercased()
            
            if name.contains("coffee") || name.contains("caffeine") {
                compounds.append("Caffeine and chlorogenic acids are compounds commonly studied in relation to cognitive function.")
            }
            if name.contains("lemon") || name.contains("citrus") {
                compounds.append("Citrus flavonoids like hesperidin are part of dietary patterns researched for cardiovascular health.")
            }
            if name.contains("berry") || name.contains("blueberry") || name.contains("strawberry") {
                compounds.append("Anthocyanins and polyphenols are compounds commonly studied in relation to cognitive function and inflammation.")
            }
            if name.contains("green") || name.contains("leafy") || name.contains("spinach") || name.contains("kale") {
                compounds.append("Lutein, zeaxanthin, and folate are nutrients commonly studied in relation to eye health.")
            }
            if name.contains("fish") || name.contains("salmon") || name.contains("omega") {
                compounds.append("Omega-3 fatty acids are nutrients commonly studied in relation to inflammation and brain function.")
            }
            if name.contains("olive") || name.contains("extra virgin") {
                compounds.append("Oleocanthal and oleuropein are compounds commonly studied in relation to inflammation.")
            }
            if name.contains("turmeric") || name.contains("curcumin") {
                compounds.append("Curcumin is a compound commonly studied in relation to longevity pathways.")
            }
            if name.contains("garlic") || name.contains("onion") {
                compounds.append("Allicin and organosulfur compounds are part of dietary patterns researched for cardiovascular and immune function.")
            }
            if name.contains("ginger") {
                compounds.append("Gingerols are compounds commonly studied in relation to inflammation and digestive function.")
            }
            if name.contains("cocoa") || name.contains("dark chocolate") {
                compounds.append("Flavonoids are compounds commonly studied in relation to endothelial and cognitive function.")
            }
        }
        
        return compounds
    }
    
    private func analyzeHealthMechanisms(analysis: FoodAnalysis) -> [String] {
        var mechanisms: [String] = []
        
        // Analyze health scores to explain mechanisms
        let scores = analysis.healthScores
        
        if scores.heartHealth >= 8 {
            mechanisms.append("These nutrients are commonly studied in relation to endothelial function and are part of dietary patterns researched for cardiovascular health.")
        }
        if scores.brainHealth >= 8 {
            mechanisms.append("Compounds commonly studied in relation to brain health are part of dietary patterns associated with cognitive function.")
        }
        if scores.antiInflammation >= 8 {
            mechanisms.append("Compounds commonly studied in relation to inflammation are part of dietary patterns researched for normal inflammatory function.")
        }
        if scores.immune >= 8 {
            mechanisms.append("Nutrients commonly studied in relation to immune function are part of dietary patterns associated with immune health.")
        }
        if scores.bloodSugar >= 8 {
            mechanisms.append("Nutrients commonly studied in relation to blood sugar are part of dietary patterns associated with glucose metabolism.")
        }
        if scores.energy >= 8 {
            mechanisms.append("Nutrients commonly studied in relation to energy are part of dietary patterns associated with energy metabolism.")
        }
        
        return mechanisms
    }
    
    // MARK: - Add Meal to Tracker
    private func addMealToTracker(_ analysis: FoodAnalysis) {
        // Look up imageHash and inputMethod from FoodCacheManager (analysis is already cached there)
        var imageHash: String? = nil
        var inputMethod: String? = nil
        if let cachedEntry = foodCacheManager.cachedAnalyses.first(where: { entry in
            entry.foodName == analysis.foodName &&
            entry.fullAnalysis.overallScore == analysis.overallScore
        }) {
            imageHash = cachedEntry.imageHash
            inputMethod = cachedEntry.inputMethod
            print("🍽️ MealTrackingView: Found imageHash from cache: \(imageHash ?? "nil"), inputMethod: \(inputMethod ?? "nil")")
        } else {
            print("🍽️ MealTrackingView: No cached entry found for analysis, imageHash will be nil")
        }
        
        // For text/voice entries (no imageHash), use stricter duplicate detection
        // For image entries, use standard duplicate detection with imageHash matching
        let thirtyMinutesAgo = Date().addingTimeInterval(-1800)
        let existingMeal: TrackedMeal?
        
        if imageHash == nil && (inputMethod == "text" || inputMethod == "voice") {
            // Text/voice entry: Check for duplicate using name + score (ignore timestamp)
            // This prevents duplicates even if user views entry hours/days later
            // Text/voice entries don't have unique imageHash identifiers, so we match by name+score only
            existingMeal = mealStorageManager.trackedMeals.first { meal in
                let nameMatch = meal.name == analysis.foodName
                let scoreMatch = abs(meal.healthScore - Double(analysis.overallScore)) < 1.0
                // Also check if it's a text/voice entry (no imageHash)
                let isTextVoiceEntry = meal.imageHash == nil
                
                return nameMatch && scoreMatch && isTextVoiceEntry
            }
        } else {
            // Image entry: Use standard duplicate detection with imageHash matching
            // Don't change behavior for image entries
            existingMeal = mealStorageManager.trackedMeals.first { meal in
                let nameMatch = meal.name == analysis.foodName
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
            print("🍽️ MealTrackingView: Meal '\(analysis.foodName)' already exists in tracker (saved \(secondsAgo) seconds ago), skipping duplicate save")
            return
        }
        
        let trackedMeal = TrackedMeal(
            id: UUID(),
            name: analysis.foodName,
            foods: [analysis.foodName], // Single food for now
            healthScore: Double(analysis.overallScore),
            goalsMet: [], // Will be calculated by MealStorageManager
            timestamp: selectedDate,
            notes: nil,
            originalAnalysis: analysis,
            imageHash: imageHash, // Store image hash for fast direct lookup (like Shop screen)
            isFavorite: false
        )
        
        mealStorageManager.addMeal(trackedMeal)
        loadDailyMeals()
        calculateDailyStats()
        generateAIEncouragement()
    }
    
    // MARK: - Add Multiple Meals to Tracker
    private func addMultipleMealsToTracker(_ analyses: [FoodAnalysis]) {
        for analysis in analyses {
            addMealToTracker(analysis)
        }
    }
    
    // MARK: - Helper to find ContentView
    private func findContentView() -> ContentView? {
        // This is a simplified approach - in a real app you might use a different pattern
        // For now, we'll use a notification to communicate with ContentView
        return nil
    }
}



// MARK: - Triangle Shape for Progress Indicator (pointing down)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Triangle Shape pointing up (for micronutrient indicators)
struct TriangleUp: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Target Mode Selection Popup
struct TargetModeSelectionPopup: View {
    let currentMode: MealTrackingView.TargetMode
    let onSelectStandardRDA: () -> Void
    let onSelectCustom: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Set Micronutrient Targets")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("Choose how you want to track your micronutrients")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Options
                VStack(spacing: 16) {
                    // Standard RDA Option
                    Button(action: {
                        onSelectStandardRDA()
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(currentMode == .standardRDA ? .green : .gray)
                                
                                Text("Use Standard RDA")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            Text("Based on USDA Dietary Guidelines 2020-2025. Values automatically adjust based on your age and sex.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentMode == .standardRDA ? Color.green.opacity(0.1) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(currentMode == .standardRDA ? Color.green : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Custom Targets Option
                    Button(action: {
                        onSelectCustom()
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title2)
                                    .foregroundColor(currentMode == .custom ? .blue : .gray)
                                
                                Text("Set Custom Targets")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            Text("Set your own targets for each micronutrient. You'll see RDA values as reference.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentMode == .custom ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(currentMode == .custom ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Custom Target Disclaimer Popup
struct CustomTargetDisclaimerPopup: View {
    let onAccept: () -> Void
    let onUseStandardRDA: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var dontShowAgain = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.top, 20)
                    
                    // Title
                    Text("Custom Tracking Targets")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    // Disclaimer Text
                    VStack(alignment: .leading, spacing: 16) {
                        Text("You can set your own targets for tracking purposes. These are not medical recommendations.")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("⚠️")
                                    .font(.title3)
                                
                                Text("Important: Custom targets are for personal tracking only. Individual nutrient needs vary based on health conditions, medications, and other factors. Always consult with a healthcare provider before making significant dietary changes or taking supplements.")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            
                            Text("These values are general guidelines and may not apply to everyone.")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Don't show again checkbox
                    HStack {
                        Button(action: {
                            dontShowAgain.toggle()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                    .foregroundColor(dontShowAgain ? .blue : .secondary)
                                
                                Text("Don't show this again")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            if dontShowAgain {
                                UserDefaults.standard.set(true, forKey: "customTargetDisclaimerAccepted")
                            }
                            onAccept()
                            dismiss()
                        }) {
                            Text("I Understand")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.42, green: 0.557, blue: 0.498),
                                            Color(red: 0.3, green: 0.7, blue: 0.6)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            onUseStandardRDA()
                            dismiss()
                        }) {
                            Text("Use Standard RDA")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MealTrackingView(selectedTab: .constant(2))
}


