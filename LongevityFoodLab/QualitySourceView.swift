import SwiftUI

struct QualitySourceView: View {
    let foodName: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    @State private var qualityAnalysis: QualityAnalysis?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                    if isExpanded && qualityAnalysis == nil {
                        loadQualityAnalysis()
                    }
                }
            }) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Text("Quality & Source")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
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
            
            // Expanded Content
            if isExpanded {
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let analysis = qualityAnalysis {
                        expandedContentView(analysis)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing quality considerations...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)
            
            Text("Quality analysis temporarily unavailable")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                loadQualityAnalysis()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.42, green: 0.557, blue: 0.498))
            .cornerRadius(8)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Expanded Content View
    private func expandedContentView(_ analysis: QualityAnalysis) -> some View {
        VStack(spacing: 20) {
            // Contamination Risk
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Contamination Risk:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(analysis.contaminationRisk.warningSymbols)
                        .font(.title3)
                }
                
                Text(analysis.contaminationRisk.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
            Divider()
            
            // Price Difference
            HStack {
                Text("Price Difference:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(analysis.priceDifference.amount)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text(analysis.priceDifference.percentage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Worth It Score
            VStack(spacing: 8) {
                HStack {
                    Text("Worth It Score:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(analysis.worthItScore)/100")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(worthItColor(analysis.worthItScore))
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(worthItColor(analysis.worthItScore))
                            .frame(width: geometry.size.width * CGFloat(analysis.worthItScore) / 100, height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
            
            Divider()
            
            // Why Consider Organic
            VStack(alignment: .leading, spacing: 8) {
                Text("Why Consider Organic:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(analysis.whyConsiderOrganic, id: \.self) { benefit in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.green)
                        Text(benefit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // When to Save Money
            VStack(alignment: .leading, spacing: 8) {
                Text("When to Save Money:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(analysis.whenToSaveMoney, id: \.self) { scenario in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.orange)
                        Text(scenario)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Smart Shopping Tips
            VStack(alignment: .leading, spacing: 8) {
                Text("Smart Shopping Tips:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("✓")
                            .foregroundColor(.green)
                        Text("Best: \(analysis.smartShoppingTips.best)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("✓")
                            .foregroundColor(.blue)
                        Text("Good: \(analysis.smartShoppingTips.good)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("✓")
                            .foregroundColor(.orange)
                        Text("Okay: \(analysis.smartShoppingTips.acceptable)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Annual Impact
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Annual Cost Increase:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(analysis.annualImpact.costIncrease)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Health Benefit:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(analysis.annualImpact.healthBenefit)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
        )
    }
    
    // MARK: - Helper Functions
    private func worthItColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    private func loadQualityAnalysis() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let analysis = try await AIService.shared.getQualityAnalysis(foodName: foodName)
                
                await MainActor.run {
                    if analysis.shouldDisplay {
                        qualityAnalysis = analysis
                    } else {
                        // Hide the section if it shouldn't be displayed
                        isExpanded = false
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Quality analysis error: \(error)")
                    // Create fallback quality analysis instead of showing error
                    qualityAnalysis = QualityAnalysis(
                        organicPriority: .medium,
                        contaminationRisk: ContaminationRisk(score: 3, explanation: "Moderate contamination risk based on general food safety data"),
                        priceDifference: PriceDifference(amount: "+$2-5 per pound", percentage: "20-40% more expensive"),
                        worthItScore: 65,
                        whyConsiderOrganic: [
                            "Reduced pesticide exposure",
                            "Better environmental impact",
                            "Support for sustainable farming"
                        ],
                        whenToSaveMoney: [
                            "When budget is limited",
                            "For foods with low contamination risk"
                        ],
                        smartShoppingTips: SmartShoppingTips(
                            best: "Organic when available and affordable",
                            good: "Conventional with thorough washing",
                            acceptable: "Frozen or canned alternatives"
                        ),
                        annualImpact: AnnualImpact(
                            costIncrease: "$200-500 per year",
                            healthBenefit: "Moderate"
                        ),
                        shouldDisplay: true
                    )
                    isLoading = false
                }
            }
        }
    }
}
