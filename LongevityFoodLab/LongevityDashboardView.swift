import SwiftUI
import Charts

struct LongevityDashboardView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedPeriod = "week"
    @State private var longevityScore = 0
    @State private var yesterdayScore = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isAnimating = false
    
    // API-connected data
    @State private var longevityScoreData: [ScoreData] = []
    @State private var nutritionBalance: [NutrientBalance] = []
    @State private var nutritionData: [NutritionItem] = []
    @State private var topFoods: [TopFood] = []
    @State private var recentMeals: [RecentMeal] = []
    @State private var yearsAdded = "0.0"
    @State private var dayStreak = "0"
    @State private var goalProgress = "0%"
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                dashboardContent
            }
        }
        .onAppear {
            loadDashboardData()
        }
        .refreshable {
            await refreshDashboardData()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 0) {
            // Logo and styled text at the top (matching main screen header)
            VStack(spacing: 8) {
                // Logo Image
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
            .padding(.top, -85)
            
            // Simple SwiftUI Animation
            ZStack {
                Circle()
                    .stroke(Color(red: 0.608, green: 0.827, blue: 0.835).opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color(red: 0.608, green: 0.827, blue: 0.835), lineWidth: 4)
                    .frame(width: 100, height: 100)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .frame(width: 200, height: 200)
            .padding(.top, 5)
            .onAppear {
                isAnimating = true
            }
            
            // Loading message
            VStack(spacing: 8) {
                Text("Loading Dashboard...")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Just a sec while we gather your longevity insights!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Unable to load dashboard")
                .font(.headline)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                loadDashboardData()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.42, green: 0.557, blue: 0.498))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    private var dashboardContent: some View {
        NavigationView {
            ScrollView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Quick Stats
                quickStatsSection
                    .padding(.top, -20)
                
                // Period Selector
                periodSelector
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Score Chart
                scoreChartSection
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Nutrition Balance
                nutritionBalanceSection
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Daily Nutrition
                dailyNutritionSection
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Top Foods
                topFoodsSection
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Recent Meals
                recentMealsSection
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                // Personalized Recommendations
                personalizedRecommendationsSection
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
            }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                startPoint: .leading,
                endPoint: .trailing
            )
            
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Good morning, \(authManager.currentUser?.displayName ?? "User")!")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Your longevity journey")
                            .font(.subheadline)
                            .opacity(0.9)
                    }
                    Spacer()
                    
                    HStack(spacing: 12) {
                        NavigationLink(destination: ProfileView()) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                )
                        }
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.white)
                                    .font(.title2)
                            )
                    }
                }
                .padding(.top, 60)
                
                // Score Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Longevity Score")
                                .font(.subheadline)
                                .opacity(0.9)
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(longevityScore)")
                                    .font(.system(size: 48, weight: .bold))
                                Text("/100")
                                    .font(.title2)
                                    .opacity(0.8)
                            }
                        }
                        Spacer()
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "arrow.up.forward")
                                    .foregroundColor(.white)
                                    .font(.title)
                            )
                    }
                    
                    HStack(spacing: 12) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 30)
                            .overlay(
                                Text("+\(longevityScore - yesterdayScore) from yesterday")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            )
                            .fixedSize()
                            .padding(.horizontal, 16)
                        
                        Text("Great progress!")
                            .font(.caption)
                            .opacity(0.9)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .foregroundColor(.white)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .frame(height: 320)
        .clipShape(RoundedCorner(radius: 30, corners: [.bottomLeft, .bottomRight]))
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            StatCard(icon: "bolt.fill", value: yearsAdded, label: "Years Added", color: Color(hex: "10B981"))
            StatCard(icon: "calendar", value: dayStreak, label: "Day Streak", color: Color(hex: "14B8A6"))
            StatCard(icon: "trophy.fill", value: goalProgress, label: "Goal Progress", color: Color(red: 0.608, green: 0.827, blue: 0.835))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Period Selector
    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(["day", "week", "month"], id: \.self) { period in
                Button(action: {
                    selectedPeriod = period
                }) {
                    Text(period.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            selectedPeriod == period ?
                            Color(hex: "10B981") :
                            Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
    
    // MARK: - Score Chart Section
    private var scoreChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Score Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            Chart(longevityScoreData) { data in
                LineMark(
                    x: .value("Day", data.day),
                    y: .value("Score", data.score)
                )
                .foregroundStyle(Color(hex: "10B981"))
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(
                    x: .value("Day", data.day),
                    y: .value("Score", data.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "10B981").opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                PointMark(
                    x: .value("Day", data.day),
                    y: .value("Score", data.score)
                )
                .foregroundStyle(Color(hex: "10B981"))
                .symbolSize(30)
            }
            .frame(height: 200)
            .chartYScale(domain: 70...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisValueLabel()
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Nutrition Balance Section
    private var nutritionBalanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutrition Balance")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(nutritionBalance) { nutrient in
                    HStack {
                        Text(nutrient.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(nutrient.value))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(nutrient.colorValue)
                    }
                    
                    ProgressView(value: nutrient.value, total: 100)
                        .progressViewStyle(LinearProgressViewStyle(tint: nutrient.colorValue))
                        .scaleEffect(y: 1.5)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Daily Nutrition Section
    private var dailyNutritionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Nutrition")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(nutritionData) { item in
                    NutritionCard(item: item)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Top Foods Section
    private var topFoodsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Longevity Foods")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(topFoods) { food in
                    TopFoodCard(food: food)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Recent Meals Section
    private var recentMealsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Meals")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(recentMeals) { meal in
                    RecentMealCard(meal: meal)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - API Integration
    private func loadDashboardData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            await refreshDashboardData()
        }
    }
    
    @MainActor
    private func refreshDashboardData() async {
        do {
            // Load personalized dashboard data from Claude API
            let healthProfile = UserHealthProfileManager.shared.currentProfile
            let dashboardData = try await AIService.shared.getDashboardData(period: selectedPeriod, healthProfile: healthProfile)
            
            self.longevityScore = dashboardData.currentScore
            self.yesterdayScore = dashboardData.yesterdayScore
            self.longevityScoreData = dashboardData.scoreHistory
            self.nutritionBalance = dashboardData.nutritionBalance
            self.nutritionData = dashboardData.nutritionData
            self.topFoods = dashboardData.topFoods
            self.recentMeals = dashboardData.recentMeals
            self.yearsAdded = dashboardData.yearsAdded
            self.dayStreak = dashboardData.dayStreak
            self.goalProgress = dashboardData.goalProgress
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    // Removed startAnimations()
}

// MARK: - Supporting Views
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct NutritionCard: View {
    let item: NutritionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.icon)
                    .font(.title2)
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(item.current))/\(Int(item.recommended))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: min(item.current, item.recommended), total: item.recommended)
                .progressViewStyle(LinearProgressViewStyle(tint: item.statusColor))
                .scaleEffect(y: 1.2)
            
            Text(item.unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TopFoodCard: View {
    let food: TopFood
    
    var body: some View {
        VStack(spacing: 8) {
            Text(food.icon)
                .font(.title)
            
            Text(food.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            Text("\(food.score)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(scoreColor(food.score))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 90...100: return Color(hex: "10B981")
        case 80...89: return Color(hex: "14B8A6")
        case 70...79: return Color(red: 0.608, green: 0.827, blue: 0.835)
        default: return .red
        }
    }
}

struct RecentMealCard: View {
    let meal: RecentMeal
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.meal)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(meal.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(meal.trend)
                    .font(.title3)
                Text("\(meal.score)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(meal.score))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 85...100: return Color(hex: "10B981")
        case 70...84: return Color(hex: "14B8A6")
        case 60...69: return Color(red: 0.608, green: 0.827, blue: 0.835)
        default: return .red
        }
    }
}

// MARK: - Data Models
struct ScoreData: Identifiable, Codable {
    let id = UUID()
    let day: String
    let score: Double
    
    enum CodingKeys: String, CodingKey {
        case day, score
    }
    
    init(day: String, score: Double) {
        self.day = day
        self.score = score
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(String.self, forKey: .day)
        score = try container.decode(Double.self, forKey: .score)
    }
}

struct NutrientBalance: Identifiable, Codable {
    let id = UUID()
    let name: String
    let value: Double
    let color: String // Store as string for JSON
    
    var colorValue: Color {
        switch color.lowercased() {
        case "green": return Color(hex: "10B981")
        case "blue": return Color(hex: "14B8A6")
        case "orange": return Color(red: 0.608, green: 0.827, blue: 0.835)
        case "purple": return Color(red: 0.608, green: 0.827, blue: 0.835)
        case "red": return .red
        default: return .gray
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name, value, color
    }
    
    init(name: String, value: Double, color: Color) {
        self.name = name
        self.value = value
        self.color = "green" // Default, will be overridden
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(Double.self, forKey: .value)
        color = try container.decode(String.self, forKey: .color)
    }
}

struct NutritionItem: Identifiable, Codable {
    let id = UUID()
    let name: String
    let icon: String
    let current: Double
    let recommended: Double
    let unit: String
    
    var percentage: Double {
        (current / recommended) * 100
    }
    
    var isOptimal: Bool {
        percentage >= 80 && percentage <= 120
    }
    
    var statusColor: Color {
        isOptimal ? Color(hex: "10B981") : (percentage > 100 ? .red : Color(red: 0.608, green: 0.827, blue: 0.835))
    }
    
    enum CodingKeys: String, CodingKey {
        case name, icon, current, recommended, unit
    }
    
    init(name: String, icon: String, current: Double, recommended: Double, unit: String) {
        self.name = name
        self.icon = icon
        self.current = current
        self.recommended = recommended
        self.unit = unit
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        current = try container.decode(Double.self, forKey: .current)
        recommended = try container.decode(Double.self, forKey: .recommended)
        unit = try container.decode(String.self, forKey: .unit)
    }
}

struct TopFood: Identifiable, Codable {
    let id = UUID()
    let name: String
    let score: Int
    let icon: String
    
    enum CodingKeys: String, CodingKey {
        case name, score, icon
    }
    
    init(name: String, score: Int, icon: String) {
        self.name = name
        self.score = score
        self.icon = icon
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        score = try container.decode(Int.self, forKey: .score)
        icon = try container.decode(String.self, forKey: .icon)
    }
}

struct RecentMeal: Identifiable, Codable {
    let id = UUID()
    let time: String
    let meal: String
    let score: Int
    let trend: String
    
    enum CodingKeys: String, CodingKey {
        case time, meal, score, trend
    }
    
    init(time: String, meal: String, score: Int, trend: String) {
        self.time = time
        self.meal = meal
        self.score = score
        self.trend = trend
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode(String.self, forKey: .time)
        meal = try container.decode(String.self, forKey: .meal)
        score = try container.decode(Int.self, forKey: .score)
        trend = try container.decode(String.self, forKey: .trend)
    }
}

// MARK: - Dashboard Data Model
struct DashboardData: Codable {
    let currentScore: Int
    let yesterdayScore: Int
    let scoreHistory: [ScoreData]
    let nutritionBalance: [NutrientBalance]
    let nutritionData: [NutritionItem]
    let topFoods: [TopFood]
    let recentMeals: [RecentMeal]
    let yearsAdded: String
    let dayStreak: String
    let goalProgress: String
}

// MARK: - Helper Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Personalized Recommendations Section
extension LongevityDashboardView {
    private var personalizedRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Personalized Recommendations")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                NavigationLink(destination: PersonalizedRecommendationsView()) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(generateQuickRecommendations(), id: \.id) { recommendation in
                        QuickRecommendationCard(recommendation: recommendation)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func generateQuickRecommendations() -> [QuickRecommendation] {
        return [
            QuickRecommendation(
                id: UUID(),
                title: "Salmon",
                subtitle: "Heart Health",
                score: 9.2,
                icon: "fish.fill",
                color: .blue
            ),
            QuickRecommendation(
                id: UUID(),
                title: "Blueberries",
                subtitle: "Brain Health",
                score: 8.8,
                icon: "leaf.fill",
                color: .purple
            ),
            QuickRecommendation(
                id: UUID(),
                title: "Quinoa",
                subtitle: "Energy",
                score: 8.5,
                icon: "grain.fill",
                color: .orange
            )
        ]
    }
}

struct QuickRecommendationCard: View {
    let recommendation: QuickRecommendation
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: recommendation.icon)
                .font(.title)
                .foregroundColor(recommendation.color)
            
            VStack(spacing: 4) {
                Text(recommendation.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(recommendation.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text(String(format: "%.1f", recommendation.score))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .frame(width: 120, height: 140)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct QuickRecommendation: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let score: Double
    let icon: String
    let color: Color
}



#Preview {
    LongevityDashboardView()
} 