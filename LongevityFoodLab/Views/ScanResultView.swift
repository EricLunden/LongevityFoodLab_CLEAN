//
//  ScanResultView.swift
//  LongevityFoodLab
//
//  Universal Scanner Results View
//

import SwiftUI

enum ScanType: String {
    case meal
    case food
    case product
    case nutrition_label
    case supplement
    case supplement_facts
}

struct ScanResultView: View {
    let scanType: ScanType
    let analysis: FoodAnalysis?
    @Binding var bestPreparation: String?
    let image: UIImage?
    let isAnalyzing: Bool
    let needsBackScan: Bool
    let onTrack: () -> Void
    let onSave: () -> Void
    let onScanAgain: () -> Void
    let onDismiss: () -> Void
    
    @State private var animatedScore: Int = 0
    @State private var isAnimating: Bool = false
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    
    var body: some View {
        ZStack {
            // Captured image as background (visible around edges)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .blur(radius: 2) // Slight blur so card stands out
            } else {
                // Transparent background if no image
                Color.clear
                    .ignoresSafeArea()
            }
            
            // Tap gesture overlay
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }
            
            // Card content
            VStack(spacing: 0) {
                // Scrollable Section: Title + Circle + Health Goals + Healthier Choices
                // Only show when not analyzing
                if !isAnalyzing {
                    scrollableContentSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    // Bottom Actions (100pt)
                    bottomActions
                        .frame(height: 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Loading screen (not scrollable)
                    topFixedSection
                }
            }
            .frame(width: 360, height: isAnalyzing ? 390 : 640) // Fixed height, content scrolls inside
            .background(Color(UIColor.systemBackground)) // Solid background for card
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(red: 0.608, green: 0.827, blue: 0.835), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .animation(.easeOut(duration: 0.3), value: isAnalyzing)
        .onAppear {
            if isAnalyzing {
                isAnimating = true
            } else if let score = analysis?.overallScore {
                animateScore(to: score)
            }
        }
        .onChange(of: isAnalyzing) { oldValue, newValue in
            if newValue {
                // Analysis started - begin loading animation
                isAnimating = true
            } else {
                // Analysis completed - stop loading animation
                isAnimating = false
            }
        }
        .onChange(of: analysis?.overallScore) { oldValue, newValue in
            if let newValue = newValue, !isAnalyzing {
                // Analysis completed - animate to final score
                animateScore(to: newValue)
            }
        }
    }
    
    // MARK: - Top Fixed Section (Title + Score Circle)
    
    private var topFixedSection: some View {
        Group {
            if isAnalyzing {
                // Dashboard-style loading screen
                dashboardLoadingView
            } else {
                // Results view
                VStack(spacing: 4) {
                    // Title
                    Text(titleText)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Score Circle
                    ZStack {
                        if let score = analysis?.overallScore {
                            // Score exists - gradient background
                            Circle()
                                .fill(scoreGradient(score))
                                .frame(width: 140, height: 140)
                                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            VStack(spacing: -4) {
                                Text("\(score)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(scoreLabel(score).uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            // No score - red circle with "TAP to score recipe" text
                            Circle()
                                .fill(Color.red)
                                .frame(width: 140, height: 140)
                                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            VStack(spacing: 0) {
                                Text("TAP")
                                    .font(.system(size: 28, weight: .black))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                VStack(spacing: 0) {
                                    Text("to score")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("recipe")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Dashboard Loading View
    
    private var dashboardLoadingView: some View {
        VStack(spacing: 0) {
            // Logo and styled text at the top
            VStack(spacing: 6) {
                // Logo Image - reduced size
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50) // Reduced from 75
                
                VStack(spacing: 0) {
                    Text("LONGEVITY")
                        .font(.custom("Avenir-Light", size: 20)) // Reduced from 28
                        .fontWeight(.light)
                        .tracking(6)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Rectangle()
                            .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                            .frame(width: 30, height: 1) // Reduced from 40
                        
                        Text("FOOD LAB")
                            .font(.custom("Avenir-Light", size: 11)) // Reduced from 14
                            .tracking(4)
                            .foregroundColor(.secondary)
                        
                        Rectangle()
                            .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                            .frame(width: 30, height: 1) // Reduced from 40
                    }
                }
            }
            .padding(.top, 8) // 8pt padding above logo icon to top of square
            
            // Circular loading indicator
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
            .padding(.top, -18) // -18pt padding between logo text and circle (overlaps)
            .onAppear {
                isAnimating = true
            }
            
            // Loading message
            VStack(spacing: 8) {
                Text("Analyzing Now")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Just a sec while we gather your quick score and summary!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, -18) // -18pt padding between circle and text (overlaps)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 8) // 8pt bottom padding
    }
    
    // MARK: - Scrollable Content Section
    
    private var scrollableContentSection: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Title and Score Circle (now inside scroll)
                if let analysis = analysis {
                    VStack(spacing: 4) {
                        // Title
                        Text(titleText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Score Circle
                        ZStack {
                            let score = analysis.overallScore
                            // Score exists - gradient background
                            Circle()
                                .fill(scoreGradient(score))
                                .frame(width: 140, height: 140)
                                .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            VStack(spacing: -4) {
                                Text("\(score)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(scoreLabel(score).uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                
                // Content based on scan type
                Group {
                    if needsBackScan {
                        // Back scan prompt
                        backScanPrompt
                    } else if let analysis = analysis {
                        if scanType == .supplement || scanType == .supplement_facts {
                            // For supplements: Summary
                            supplementSummary(analysis: analysis)
                        } else {
                            // For ALL grocery items (products, foods, meals, etc.): Product format with summary + bullets + Healthier Choices
                            // This ensures consistent display for all items scanned from grocery scanner
                            VStack(spacing: 16) {
                                // Summary Section - renders immediately (text is already in analysis.summary)
                                if !analysis.summary.isEmpty {
                                    summarySection(analysis: analysis)
                                }
                                
                                // Health Goals Section - renders immediately (no async dependencies)
                                healthGoalsSection(analysis: analysis)
                                
                                // Healthier Choices Section - loads asynchronously after view appears
                                // Uses HealthierChoicesContainerView which handles all loading off main thread
                                HealthierChoicesContainerView(analysis: analysis, bestPreparation: $bestPreparation)
                            }
                        }
                    } else {
                        // No data
                        Text("Scan complete")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Health Goal Assessments
    
    private func healthGoalAssessments(analysis: FoodAnalysis) -> some View {
        let healthGoals = healthProfileManager.getHealthGoals()
        
        if healthGoals.isEmpty {
            return AnyView(commonWarningsPraise)
        }
        
        let assessments = generateAssessments(for: analysis, goals: healthGoals)
        
        return AnyView(
            VStack(spacing: 4) {
                ForEach(Array(assessments.prefix(4).enumerated()), id: \.offset) { index, assessment in
                    Text(assessment)
                        .font(.system(size: assessments.count <= 2 ? 18 : 16, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.horizontal, 20)
                }
            }
        )
    }
    
    private var commonWarningsPraise: some View {
        VStack(spacing: 4) {
            Text("✓ High fiber content")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .padding(.horizontal, 20)
            
            Text("⚠️ Check added sugars")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Middle Section
    
    private var middleSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                if needsBackScan {
                    // Back scan prompt
                    backScanPrompt
                } else if let analysis = analysis {
                    // Show Summary for supplements
                    if scanType == .supplement || scanType == .supplement_facts {
                        supplementSummary(analysis: analysis)
                    } else if scanType == .product || scanType == .nutrition_label {
                        // For products: Health Goals and Healthier Choice are in top section (scrollable)
                        // Middle section is empty for products
                        EmptyView()
                    } else {
                        // For food/meal: Show Quick Facts and ALL Health Goals
                        VStack(alignment: .leading, spacing: 12) {
                            quickFacts(analysis: analysis)
                            
                            // All Health Goals Section
                            allHealthGoalsSection(analysis: analysis)
                        }
                    }
                } else {
                    // No data
                    Text("Scan complete")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
    
    private var backScanPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text(scanType == .product ? "Scan the back for complete nutrition details" : "Scan the back for full ingredient list")
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
    }
    
    private func summarySection(analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Format summary as sentences
            ForEach(Array(formatSummaryIntoSentences(analysis.summary).enumerated()), id: \.offset) { index, sentence in
                Text(sentence)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func supplementSummary(analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Format summary as sentences
            ForEach(Array(formatSummaryIntoSentences(analysis.summary).enumerated()), id: \.offset) { index, sentence in
                Text(sentence)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func formatSummaryIntoSentences(_ summary: String) -> [String] {
        // Split summary into sentences
        let sentences = summary.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.hasSuffix(".") ? $0 : $0 + "." }
        
        // If we have 3 or fewer sentences, return them
        if sentences.count <= 3 {
            return sentences.isEmpty ? [summary] : sentences
        }
        
        // If we have more than 3, combine intelligently
        // Try to create 3 balanced sentences
        let chunkSize = max(1, sentences.count / 3)
        var result: [String] = []
        
        for i in 0..<3 {
            let start = i * chunkSize
            let end = min(start + chunkSize, sentences.count)
            if start < sentences.count {
                let combined = sentences[start..<end].joined(separator: " ")
                result.append(combined)
            }
        }
        
        return result.isEmpty ? [summary] : result
    }
    
    private func quickFacts(analysis: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Facts:")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Calories (no interpretive text) - rounded to whole number
            if let calories = parseNutritionValue(analysis.nutritionInfoOrDefault.calories) {
                Text("Calories: \(Int(round(calories)))")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Total Fat
            if let fat = parseNutritionValue(analysis.nutritionInfoOrDefault.fat) {
                Text("Total Fat: \(Int(round(fat)))g")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Total Carbohydrates
            if let carbs = parseNutritionValue(analysis.nutritionInfoOrDefault.carbohydrates) {
                Text("Total Carbs: \(Int(round(carbs)))g")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Added Sugar - rounded to whole number
            if let sugar = parseNutritionValue(analysis.nutritionInfoOrDefault.sugar), sugar > 0 {
                let context = sugarContext(sugar)
                Text("Added Sugar: \(Int(round(sugar)))g (\(context))")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Protein - rounded to whole number
            if let protein = parseNutritionValue(analysis.nutritionInfoOrDefault.protein) {
                let context = proteinContext(protein)
                Text("Protein: \(Int(round(protein)))g (\(context))")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Fiber - rounded to whole number
            if let fiber = parseNutritionValue(analysis.nutritionInfoOrDefault.fiber) {
                let context = fiberContext(fiber)
                Text("Fiber: \(Int(round(fiber)))g (\(context))")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Sodium - rounded to whole number
            if let sodium = parseNutritionValue(analysis.nutritionInfoOrDefault.sodium) {
                let percentDV = Int((sodium / 2300.0) * 100)
                Text("Sodium: \(Int(round(sodium)))mg (\(percentDV)% DV)")
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // Net Carbs (only if Keto preference selected) - rounded to whole number
            if hasKetoPreference(), let carbs = parseNutritionValue(analysis.nutritionInfoOrDefault.carbohydrates), let fiber = parseNutritionValue(analysis.nutritionInfoOrDefault.fiber) {
                let netCarbs = max(0, carbs - fiber)
                let context = netCarbsContext(netCarbs)
                Text("Net Carbs: \(Int(round(netCarbs)))g (\(context))")
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        HStack(spacing: 20) {
            // Save button (all grocery scanner items use Save)
            Button(action: {
                onSave()
            }) {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                    .cornerRadius(12)
            }
            
            // Scan Again button
            Button(action: {
                onScanAgain()
            }) {
                Text("Scan Again")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Helper Functions
    
    private var titleText: String {
        if isAnalyzing {
            return "Scanning"
        } else if let analysis = analysis, !analysis.foodName.isEmpty {
            return analysis.foodName
        } else if scanType == .product || scanType == .nutrition_label {
            return "Nutrition Facts"
        } else {
            return "Scan Analysis"
        }
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
            startColor = Color(red: 0.9, green: 0.5, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.7, blue: 0.2)
        } else if progress <= 0.8 {
            // Yellow to Green
            startColor = Color(red: 0.8, green: 0.7, blue: 0.2)
            endColor = Color(red: 0.4, green: 0.7, blue: 0.4)
        } else {
            // Green to Dark Green
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
    
    private func animateScore(to finalScore: Int) {
        // Animate score counting up from 0 to final score
        let duration: TimeInterval = 0.5
        let steps = 20
        let stepDuration = duration / Double(steps)
        
        animatedScore = 0
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                if step < steps {
                    // Count up gradually
                    let progress = Double(step) / Double(steps)
                    self.animatedScore = Int(progress * Double(finalScore))
                } else {
                    // Lock in final score
                    self.animatedScore = finalScore
                }
            }
        }
    }
    
    // MARK: - Health Goals Section (renders immediately)
    private func healthGoalsSection(analysis: FoodAnalysis) -> some View {
        let healthGoals = healthProfileManager.getHealthGoals()
        
        guard !healthGoals.isEmpty else {
            return AnyView(EmptyView())
        }
        
        var allAssessments = generateAllAssessmentsWithScores(for: analysis, goals: healthGoals)
        
        // Sort by bullet color: green first, then yellow, then red
        allAssessments.sort { item1, item2 in
            let color1 = item1.bulletColor
            let color2 = item2.bulletColor
            
            // Define color order: green (0), yellow (1), red (2)
            func colorOrder(_ color: Color) -> Int {
                // Compare colors by checking if they match green, yellow, or red
                if color == Color.green { return 0 }
                if color == Color.yellow { return 1 }
                if color == Color.red { return 2 }
                return 3 // Other colors go last
            }
            
            return colorOrder(color1) < colorOrder(color2)
        }
        
        // Header font (keep as is)
        let headerFont = Font.headline
        let headerWeight = Font.Weight.semibold
        
        // Body text font (regular weight, smaller size)
        let bodyFont = Font.body
        let bodyWeight = Font.Weight.regular
        
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Health Goals:")
                    .font(headerFont)
                    .fontWeight(headerWeight)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(allAssessments.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            // Icon (checkmark or X) instead of bullet
                            Text(item.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(item.bulletColor)
                                .padding(.top, 2)
                            
                            Text(item.text)
                                .font(bodyFont)
                                .fontWeight(bodyWeight)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        )
    }
    
    
    private func allHealthGoalsSection(analysis: FoodAnalysis) -> some View {
        let healthGoals = healthProfileManager.getHealthGoals()
        
        guard !healthGoals.isEmpty else {
            return AnyView(EmptyView())
        }
        
        let allAssessments = generateAllAssessments(for: analysis, goals: healthGoals)
        
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Health Goals:")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                ForEach(Array(allAssessments.enumerated()), id: \.offset) { index, assessment in
                    Text(assessment)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        )
    }
    
    private func healthierChoiceSection(analysis: FoodAnalysis) -> some View {
        // Calculate healthier alternative score (always show if current score < 100)
        let alternativeScore = min(100, analysis.overallScore + max(10, Int(Double(100 - analysis.overallScore) * 0.3)))
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Healthier Choice:")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // AI-generated healthier alternative
            HStack(spacing: 12) {
                // Smaller score circle (50pt diameter)
                ZStack {
                    Circle()
                        .fill(scoreGradient(alternativeScore))
                        .frame(width: 50, height: 50)
                    
                    VStack(spacing: -2) {
                        Text("\(alternativeScore)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(scoreLabel(alternativeScore).uppercased())
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Use bestPreparation directly - it should contain brand names and specific details
                    let healthierText = analysis.bestPreparationOrDefault.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !healthierText.isEmpty {
                        Text(healthierText)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        // Fallback only if bestPreparation is empty
                        Text("Try: \(generateHealthierAlternative(for: analysis))")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private struct AssessmentItem {
        let text: String
        let bulletColor: Color
        let icon: String
    }
    
    private func generateAllAssessmentsWithScores(for analysis: FoodAnalysis, goals: [String]) -> [AssessmentItem] {
        var assessments: [AssessmentItem] = []
        
        for goal in goals {
            let score: Int
            switch goal.lowercased() {
            case "heart health", "heart":
                score = analysis.healthScores.heartHealth
            case "weight loss", "weight management", "weight":
                score = analysis.healthScores.weightManagement
            case "longevity":
                score = analysis.overallScore
            case "diabetes", "blood sugar":
                score = analysis.healthScores.bloodSugar
            case "energy":
                score = analysis.healthScores.energy
            case "muscle building":
                score = analysis.healthScores.energy
            case "bone health", "bones":
                score = analysis.healthScores.jointHealth
            case "brain health", "brain":
                score = analysis.healthScores.brainHealth
            case "gut health", "microbiome":
                score = analysis.healthScores.immune
            case "sleep":
                score = analysis.healthScores.sleep
            case "skin":
                score = analysis.healthScores.skin
            case "stress":
                score = analysis.healthScores.stress
            case "anti-inflammation", "inflammation":
                score = analysis.healthScores.antiInflammation
            case "eye health", "eyes":
                score = analysis.healthScores.eyeHealth
            case "immune", "immunity":
                score = analysis.healthScores.immune
            default:
                score = analysis.overallScore
            }
            
            // Determine icon and text based on score
            let icon: String
            let iconColor: Color
            let assessmentText: String
            
            if score >= 70 {
                icon = "✓"
                iconColor = Color.green
                assessmentText = goal  // Just the goal name, no "Moderate" etc.
            } else if score < 50 {
                icon = "✗"
                iconColor = Color.red
                assessmentText = goal  // Just the goal name
            } else {
                icon = "⚠"
                iconColor = Color.yellow
                assessmentText = goal  // Just the goal name
            }
            
            assessments.append(AssessmentItem(text: assessmentText, bulletColor: iconColor, icon: icon))
        }
        
        return assessments
    }
    
    // MARK: - Suggestion Card (matching Pet Foods style)
    // NOTE: This function is kept for backward compatibility but is no longer used
    // HealthierChoicesContainerView now handles suggestion cards
    private func suggestionCard(_ suggestion: GrocerySuggestion) -> some View {
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
                .background(scoreGradient(suggestion.score))
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
    
    private func generateHealthierAlternative(for analysis: FoodAnalysis) -> String {
        // Use bestPreparation field to store healthier alternative brand name
        // If it contains brand-like text, use it; otherwise generate from keyBenefits or summary
        let bestPrep = analysis.bestPreparationOrDefault.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if bestPreparation contains a brand name (capitalized words, common brand patterns)
        if !bestPrep.isEmpty && bestPrep.count > 3 {
            // If it looks like a brand name (starts with capital, not a sentence)
            if bestPrep.first?.isUppercase == true && !bestPrep.contains(".") && bestPrep.count < 50 {
                return bestPrep
            }
        }
        
        // Fallback: Extract from keyBenefits if available
        if let firstBenefit = analysis.keyBenefitsOrDefault.first, firstBenefit.count < 50 {
            return firstBenefit
        }
        
        // Final fallback: Generate from product name
        let productName = analysis.foodName.lowercased()
        if productName.contains("white") || productName.contains("refined") {
            return "Dave's Killer Bread or Ezekiel Bread"
        } else if productName.contains("sugar") || productName.contains("sweet") {
            return "Lakanto or Swerve sweeteners"
        } else if productName.contains("fried") || productName.contains("crispy") {
            return "Baked alternatives from Simple Mills or Siete"
        } else if analysis.overallScore < 60 {
            return "Organic brands like Amy's or Annie's"
        } else {
            return "Fresh whole food alternatives"
        }
    }
    
    private func generateAssessments(for analysis: FoodAnalysis, goals: [String]) -> [String] {
        var assessments: [String] = []
        
        for goal in goals.prefix(4) {
            let score: Int
            switch goal.lowercased() {
            case "heart health", "heart":
                score = analysis.healthScores.heartHealth
            case "weight loss", "weight management", "weight":
                score = analysis.healthScores.weightManagement
            case "longevity":
                score = analysis.overallScore
            case "diabetes", "blood sugar":
                score = analysis.healthScores.bloodSugar
            case "energy":
                score = analysis.healthScores.energy
            case "muscle building":
                score = analysis.healthScores.energy
            case "bone health", "bones":
                score = analysis.healthScores.jointHealth
            case "brain health", "brain":
                score = analysis.healthScores.brainHealth
            case "gut health", "microbiome":
                score = analysis.healthScores.immune
            default:
                score = analysis.overallScore
            }
            
            if score >= 70 {
                assessments.append("✓ \(goal): Positive impact")
            } else if score < 50 {
                assessments.append("⚠️ \(goal): Concerns")
            } else {
                assessments.append("→ \(goal): Moderate")
            }
        }
        
        return assessments
    }
    
    private func generateAllAssessments(for analysis: FoodAnalysis, goals: [String]) -> [String] {
        var assessments: [String] = []
        
        // Process ALL goals, not just first 4
        for goal in goals {
            let score: Int
            switch goal.lowercased() {
            case "heart health", "heart":
                score = analysis.healthScores.heartHealth
            case "weight loss", "weight management", "weight":
                score = analysis.healthScores.weightManagement
            case "longevity":
                score = analysis.overallScore
            case "diabetes", "blood sugar":
                score = analysis.healthScores.bloodSugar
            case "energy":
                score = analysis.healthScores.energy
            case "muscle building":
                score = analysis.healthScores.energy
            case "bone health", "bones":
                score = analysis.healthScores.jointHealth
            case "brain health", "brain":
                score = analysis.healthScores.brainHealth
            case "gut health", "microbiome":
                score = analysis.healthScores.immune
            case "sleep":
                score = analysis.healthScores.sleep
            case "skin":
                score = analysis.healthScores.skin
            case "stress":
                score = analysis.healthScores.stress
            case "anti-inflammation", "inflammation":
                score = analysis.healthScores.antiInflammation
            case "eye health", "eyes":
                score = analysis.healthScores.eyeHealth
            case "immune", "immunity":
                score = analysis.healthScores.immune
            default:
                score = analysis.overallScore
            }
            
            if score >= 70 {
                assessments.append("✓ \(goal): Positive impact")
            } else if score < 50 {
                assessments.append("⚠️ \(goal): Concerns")
            } else {
                assessments.append("→ \(goal): Moderate")
            }
        }
        
        return assessments
    }
    
    private func parseNutritionValue(_ value: String) -> Double? {
        // Extract number from strings like "150 kcal", "8g", "200mg"
        let cleaned = value.lowercased()
            .replacingOccurrences(of: "kcal", with: "")
            .replacingOccurrences(of: "g", with: "")
            .replacingOccurrences(of: "mg", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(cleaned)
    }
    
    private func sugarContext(_ grams: Double) -> String {
        if grams == 0 {
            return "none"
        } else if grams <= 5 {
            return "low"
        } else if grams <= 15 {
            return "moderate"
        } else {
            return "high"
        }
    }
    
    private func proteinContext(_ grams: Double) -> String {
        if grams < 5 {
            return "low"
        } else if grams < 16 {
            return "moderate"
        } else if grams < 26 {
            return "good"
        } else {
            return "excellent"
        }
    }
    
    private func fiberContext(_ grams: Double) -> String {
        if grams < 3 {
            return "low"
        } else if grams < 6 {
            return "good source"
        } else {
            return "excellent source"
        }
    }
    
    private func netCarbsContext(_ grams: Double) -> String {
        if grams <= 10 {
            return "keto-friendly"
        } else if grams <= 20 {
            return "moderate for keto"
        } else {
            return "not keto"
        }
    }
    
    private func hasKetoPreference() -> Bool {
        guard let profile = healthProfileManager.currentProfile,
              let dietaryPreference = profile.dietaryPreference else {
            return false
        }
        return dietaryPreference.lowercased().contains("keto")
    }
}

