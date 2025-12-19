//
//  SupplementScanRowView.swift
//  LongevityFoodLab
//
//  List view card for supplement scans
//

import SwiftUI

struct SupplementScanRowView: View {
    let entry: FoodCacheEntry
    let onTap: (FoodAnalysis) -> Void
    let onDelete: (String) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var showingDeleteConfirmation = false
    @State private var cachedImage: UIImage?
    
    init(entry: FoodCacheEntry, onTap: @escaping (FoodAnalysis) -> Void, onDelete: @escaping (String) -> Void) {
        self.entry = entry
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack {
            Button(action: {
                onTap(entry.fullAnalysis)
            }) {
                HStack(spacing: 12) {
                    // Captured Supplement Image
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let image = cachedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .clipped()
                            } else if entry.imageHash != nil {
                                // Loading placeholder for image
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            } else {
                                // Text/voice entry - show black box with gradient icon
                                TextVoiceEntryIcon(inputMethod: entry.inputMethod, size: 60)
                            }
                        }
                        
                        // Heart icon (bottom left) - blue-purple to bright blue gradient, not tappable
                        if entry.isFavorite {
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
                    
                    // Supplement Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(supplementName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Score Circle
                    GroceryScoreCircleCompact(score: entry.fullAnalysis.overallScore)
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
            
            // Delete Button - Top Right Corner
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
        .onAppear {
            loadImage()
        }
        .confirmationDialog("Delete Supplement Scan", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete(entry.cacheKey)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(supplementName)'?")
        }
    }
    
    private var supplementName: String {
        return entry.foodName
    }
    
    private func loadImage() {
        cachedImage = FoodCacheManager.shared.loadImage(forHash: entry.imageHash)
    }
}

