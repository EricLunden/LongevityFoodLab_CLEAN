//
//  Config.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 7/12/25.
//

import Foundation

struct Config {
    // MARK: - API Configuration
    static let anthropicBaseURL = "https://api.anthropic.com/v1/messages"
    static let anthropicVersion = "2023-06-01"
    
    static let spoonacularAPIKey = "cd30ace41b214b56878ab5d5521dc9ca" // Replace with your actual Spoonacular API key
    
    // USDA FoodData Central API Key (free registration at https://fdc.nal.usda.gov/api-guide.html)
    static let usdaAPIKey = "1L7ra7ckScxQZrVYXDZghymY7gE0V1dC3l1pnmam"
    
    // MARK: - App Configuration
    static let maxTokens = 1500
    static let modelName = "claude-3-sonnet-20240229"
    
    // MARK: - UI Configuration
    static let errorDisplayDuration: TimeInterval = 3.0
    static let animationDuration: Double = 1.0
} 
