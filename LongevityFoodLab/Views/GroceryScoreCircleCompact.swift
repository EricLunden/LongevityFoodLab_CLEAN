//
//  GroceryScoreCircleCompact.swift
//  LongevityFoodLab
//
//  Compact score circle for grocery scan list view
//

import SwiftUI

struct GroceryScoreCircleCompact: View {
    let score: Int
    
    var body: some View {
        ZStack {
            // Background circle with gradient (red to green based on score)
            Circle()
                .fill(scoreGradient(score))
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
            
            // Score number and one-word summary (white text - reverse type)
            VStack(spacing: -4) {
                Text("\(score)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(scoreLabel(score).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
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
    
    // Dynamic score label
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

