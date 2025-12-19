//
//  SecureConfig.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 7/12/25.
//

import Foundation

struct SecureConfig {
    // MARK: - API Configuration
    
    // Claude API (for Lambda function only - recipe parsing)
    // Keys are now stored in iOS Keychain for security
    static var anthropicAPIKey: String {
        return APIKeyConfiguration.shared.anthropicKey
    }
    
    static let anthropicBaseURL = "https://api.anthropic.com/v1/messages"
    static let anthropicVersion = "2023-06-01"  // API version (works with all Claude models)
    
    // OpenAI API (for main app analysis functions)
    // Keys are now stored in iOS Keychain for security
    static var openAIAPIKey: String {
        return APIKeyConfiguration.shared.openAIKey
    }
    
    static let openAIBaseURL = "https://api.openai.com/v1/chat/completions"
    static let openAIModelName = "gpt-4o"  // OpenAI GPT-4o (recommended) or "gpt-4o-mini" for lower cost
    
    // MARK: - App Configuration
    static let maxTokens = 1500
    static let modelName = "claude-sonnet-4-5"  // Claude 4 Sonnet (latest) - kept for backward compatibility
    
    // MARK: - UI Configuration
    static let errorDisplayDuration: TimeInterval = 3.0
    static let animationDuration: Double = 1.0
} 
 
