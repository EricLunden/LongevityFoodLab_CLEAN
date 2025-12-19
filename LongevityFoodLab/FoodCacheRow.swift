import SwiftUI

struct FoodCacheRow: View {
    let entry: FoodCacheEntry
    let onTap: (FoodAnalysis) -> Void
    let onDelete: (String) -> Void
    let isSelected: Bool
    let selectionMode: Bool // New parameter to hide delete button in selection mode
    
    @State private var showingDeleteConfirmation = false
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var cachedImage: UIImage?
    @Environment(\.colorScheme) var colorScheme
    
    init(entry: FoodCacheEntry, onTap: @escaping (FoodAnalysis) -> Void, onDelete: @escaping (String) -> Void, isSelected: Bool, selectionMode: Bool = false) {
        self.entry = entry
        self.onTap = onTap
        self.onDelete = onDelete
        self.isSelected = isSelected
        self.selectionMode = selectionMode
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Square Image with Score Circle Overlay - matching tracker carousel style
            ZStack(alignment: .bottomTrailing) {
                // Food Image - ensure perfect square with fixed size
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
            
                // Score Circle - lower right corner (matching tracker carousel)
                Circle()
                    .fill(scoreGradient(entry.fullAnalysis.overallScore))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text("\(entry.fullAnalysis.overallScore)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding(4)
                
                // Delete Button - top right corner (only show if not in selection mode)
                if !selectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                Circle()
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.black.opacity(0.8))
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                        }
                        Spacer()
                    }
                    .padding(4)
                }
                
                // Selection Check Mark (show in selection mode when selected)
                if selectionMode && isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .background(Color.white)
                                .clipShape(Circle())
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 140, height: 140)
            .onTapGesture {
                onTap(entry.fullAnalysis)
            }
            
            // Food Name (max 2 lines) - matching tracker carousel
            Text(entry.foodName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 140, alignment: .leading)
            
            // Analysis Date - preserved at bottom
            Text(entry.daysSinceAnalysis == 0 ? "Today" : entry.daysSinceAnalysis == 1 ? "1 day ago" : "\(entry.daysSinceAnalysis) days ago")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
        }
        .alert("Delete?", isPresented: $showingDeleteConfirmation) {
            Button("Yes", role: .destructive) {
                onDelete(entry.cacheKey)
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this analysis?")
        }
    }
    
    private func loadImage() {
        // Use direct hash lookup (fast) if imageHash is available
        if let imageHash = entry.imageHash {
            // Direct lookup - instant load from disk
            if let image = foodCacheManager.loadImage(forHash: imageHash) {
                cachedImage = image
                return
            }
        }
        
        // Fallback: Try to find image using name matching
        DispatchQueue.global(qos: .userInitiated).async {
            let matchingEntry = foodCacheManager.cachedAnalyses.first { cachedEntry in
                cachedEntry.foodName == entry.foodName &&
                cachedEntry.fullAnalysis.overallScore == entry.fullAnalysis.overallScore
            }
            
            if let matchingEntry = matchingEntry, let imageHash = matchingEntry.imageHash {
                if let image = foodCacheManager.loadImage(forHash: imageHash) {
                    DispatchQueue.main.async {
                        cachedImage = image
                    }
                }
            }
        }
    }
    
    // Gradient that runs from red to green based on score (matching recipe cards)
    private func scoreGradient(_ score: Int) -> LinearGradient {
        let progress = CGFloat(score) / 100.0
        
        // Red to green gradient based on score with darker gradations for better text contrast
        // 0-40: Dark red to dark orange
        // 41-60: Dark orange to dark yellow
        // 61-80: Dark yellow to darker green
        // 81-100: Darker green to dark green
        
        let startColor: Color
        let endColor: Color
        
        if progress <= 0.4 {
            // Dark red to dark orange
            startColor = Color(red: 0.8, green: 0.1, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.4, blue: 0.1)
        } else if progress <= 0.6 {
            // Dark orange to dark yellow
            startColor = Color(red: 0.9, green: 0.5, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.7, blue: 0.2)
        } else if progress <= 0.8 {
            // Dark yellow to darker green
            startColor = Color(red: 0.8, green: 0.7, blue: 0.2)
            endColor = Color(red: 0.4, green: 0.7, blue: 0.4)
        } else {
            // Darker green to dark green
            startColor = Color(red: 0.3, green: 0.6, blue: 0.3)
            endColor = Color(red: 0.2, green: 0.5, blue: 0.2)
        }
        
        return LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Dynamic score label (matching recipe cards)
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
}
