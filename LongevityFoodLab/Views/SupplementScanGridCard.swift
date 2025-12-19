//
//  SupplementScanGridCard.swift
//  LongevityFoodLab
//
//  Grid view card for supplement scans
//

import SwiftUI

struct SupplementScanGridCard: View {
    let entry: FoodCacheEntry
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void
    let scoreCircleSize: CGFloat
    
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var cachedImage: UIImage?
    
    init(entry: FoodCacheEntry, isEditing: Bool, isSelected: Bool, onTap: @escaping () -> Void, onToggleSelection: @escaping () -> Void, scoreCircleSize: CGFloat = 28) {
        self.entry = entry
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
                // Normal mode: open scan
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Square Image with Score Circle Overlay
                GeometryReader { geometry in
                    ZStack(alignment: .bottomTrailing) {
                        // Captured Supplement Image - ensure perfect square
                        Group {
                            if let image = cachedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.width)
                                    .clipped()
                                    .cornerRadius(0) // No rounded corners
                            } else if entry.imageHash != nil {
                                // Loading placeholder for image
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width, height: geometry.size.width)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 10))
                                    )
                                    .cornerRadius(0) // No rounded corners
                            } else {
                                // Text/voice entry - show black box with gradient icon
                                TextVoiceEntryIcon(inputMethod: entry.inputMethod, size: geometry.size.width)
                                    .cornerRadius(0) // No rounded corners
                            }
                        }
                    
                        // Heart icon (bottom left) - blue-purple to bright blue gradient, not tappable
                        if entry.isFavorite {
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
                            .fill(scoreGradient(entry.fullAnalysis.overallScore))
                            .frame(width: scoreCircleSize, height: scoreCircleSize)
                            .overlay(
                                Text("\(entry.fullAnalysis.overallScore)")
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
                
                // Supplement Title (max 2 lines) - smaller text
                Text(supplementName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 28, alignment: .topLeading)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
        }
    }
    
    private var supplementName: String {
        return entry.foodName
    }
    
    private func loadImage() {
        cachedImage = FoodCacheManager.shared.loadImage(forHash: entry.imageHash)
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
}

