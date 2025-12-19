//
//  TextVoiceEntryIcon.swift
//  LongevityFoodLab
//
//  Black box (dark mode) / Light gray box (light mode) with gradient icon for text/voice entries
//

import SwiftUI

struct TextVoiceEntryIcon: View {
    let inputMethod: String?
    let width: CGFloat?
    let height: CGFloat?
    let cornerRadius: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(inputMethod: String? = nil, size: CGFloat = 60, width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 8) {
        self.inputMethod = inputMethod
        // If width/height provided, use those; otherwise use size for both
        self.width = width ?? size
        self.height = height ?? size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(backgroundColor)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .overlay(
                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(iconGradient)
            )
            .overlay(
                // Green hairline border in dark mode only
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.green, lineWidth: 0.5)
                    .opacity(colorScheme == .dark ? 1.0 : 0.0)
            )
    }
    
    private var backgroundColor: Color {
        // Dark mode: black, Light mode: systemGray6 (matches dropdown backgrounds)
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    
    private var iconName: String {
        // Use inputMethod to determine icon
        if let inputMethod = inputMethod?.lowercased() {
            if inputMethod == "voice" {
                return "mic.fill"
            } else if inputMethod == "text" {
                return "keyboard"
            }
        }
        // Default to keyboard for backward compatibility
        return "keyboard"
    }
    
    private var iconSize: CGFloat {
        // Icon is 40% of the smaller dimension
        let minDimension = min(width ?? 60, height ?? 60)
        return minDimension * 0.4
    }
    
    private var iconGradient: LinearGradient {
        // Different gradients for text vs voice
        if let inputMethod = inputMethod?.lowercased(), inputMethod == "voice" {
            // Blue-purple gradient for voice entries
            return LinearGradient(
                colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.8),  // Purple
                    Color(red: 0.2, green: 0.4, blue: 1.0)   // Blue
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            // Orange gradient for text entries
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.6, blue: 0.0),  // Orange
                    Color(red: 1.0, green: 0.8, blue: 0.2)   // Light orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

