//
//  APIKeyConfiguration.swift
//  LongevityFoodLab
//
//  Manages API keys stored in Keychain with automatic migration from hardcoded keys
//

import Foundation

class APIKeyConfiguration {
    static let shared = APIKeyConfiguration()
    
    private let keychain = KeychainManager.shared
    
    // Key names in Keychain
    private let openAIKeyName = "openai_api_key"
    private let anthropicKeyName = "anthropic_api_key"
    private let youtubeKeyName = "youtube_api_key"
    private let rapidAPIKeyName = "rapidapi_key"
    
    // Migration flag to prevent multiple migrations
    private let migrationKey = "api_keys_migrated"
    
    private init() {}
    
    // MARK: - Key Access
    
    /// Check if required API keys are configured
    var hasRequiredKeys: Bool {
        return keychain.exists(openAIKeyName) && keychain.exists(anthropicKeyName)
    }
    
    /// Get OpenAI API key from Keychain
    var openAIKey: String {
        if let key = keychain.get(openAIKeyName), !key.isEmpty {
            return key
        }
        
        print("⚠️ APIKeyConfiguration: OpenAI API key not found in Keychain")
        return ""
    }
    
    /// Get Anthropic API key from Keychain
    var anthropicKey: String {
        if let key = keychain.get(anthropicKeyName), !key.isEmpty {
            return key
        }
        
        print("⚠️ APIKeyConfiguration: Anthropic API key not found in Keychain")
        return ""
    }
    
    /// Get YouTube API key from Keychain
    var youtubeKey: String {
        if let key = keychain.get(youtubeKeyName), !key.isEmpty {
            // Also save to UserDefaults for Share Extension access
            UserDefaults(suiteName: "group.com.ericbetuel.longevityfoodlab")?.set(key, forKey: "youtube_api_key")
            UserDefaults.standard.set(key, forKey: "youtube_api_key")
            return key
        }
        
        print("⚠️ APIKeyConfiguration: YouTube API key not found in Keychain")
        return ""
    }
    
    /// Get RapidAPI key from Keychain
    var rapidAPIKey: String {
        if let key = keychain.get(rapidAPIKeyName), !key.isEmpty {
            return key
        }
        
        print("⚠️ APIKeyConfiguration: RapidAPI key not found in Keychain")
        return ""
    }
    
    // MARK: - Migration
    
    /// Migrate hardcoded keys from SecureConfig to Keychain (one-time operation)
    func migrateFromHardcodedKeys() {
        // Check if migration has already been performed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return  // Silent - migration already done
        }
        
        // Check if keys already exist in Keychain (from previous migration)
        if keychain.exists(openAIKeyName) && keychain.exists(anthropicKeyName) {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return  // Silent - keys already migrated
        }
        
        // On new devices, there are no hardcoded keys to migrate
        // Silently mark migration as complete (no warnings needed)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
    
    // MARK: - Manual Configuration
    
    /// Manually configure API keys (for future use if needed)
    func configureKeys(openAI: String? = nil, anthropic: String? = nil, youtube: String? = nil, rapidAPI: String? = nil) {
        if let key = openAI, !key.isEmpty {
            _ = keychain.save(key, for: openAIKeyName)
            print("✅ APIKeyConfiguration: Configured OpenAI key")
        }
        
        if let key = anthropic, !key.isEmpty {
            _ = keychain.save(key, for: anthropicKeyName)
            print("✅ APIKeyConfiguration: Configured Anthropic key")
        }
        
        if let key = youtube, !key.isEmpty {
            _ = keychain.save(key, for: youtubeKeyName)
            print("✅ APIKeyConfiguration: Configured YouTube key")
        }
        
        if let key = rapidAPI, !key.isEmpty {
            _ = keychain.save(key, for: rapidAPIKeyName)
            print("✅ APIKeyConfiguration: Configured RapidAPI key")
        }
        
        // Also save YouTube key to UserDefaults for Share Extension access
        if let key = youtube, !key.isEmpty {
            UserDefaults(suiteName: "group.com.ericbetuel.longevityfoodlab")?.set(key, forKey: "youtube_api_key")
            UserDefaults.standard.set(key, forKey: "youtube_api_key")
            print("✅ APIKeyConfiguration: Saved YouTube key to UserDefaults for Share Extension")
        }
    }
}

