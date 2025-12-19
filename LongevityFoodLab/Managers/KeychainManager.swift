//
//  KeychainManager.swift
//  LongevityFoodLab
//
//  Created for API key security - stores keys in iOS Keychain
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service: String
    
    private init() {
        // Use bundle identifier for service name
        self.service = Bundle.main.bundleIdentifier ?? "com.ericbetuel.longevityfoodlab"
    }
    
    // MARK: - Save Key
    
    /// Save a string value to Keychain
    func save(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("❌ KeychainManager: Failed to convert value to data for key: \(key)")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ KeychainManager: Successfully saved key: \(key)")
            return true
        } else {
            print("❌ KeychainManager: Failed to save key: \(key), status: \(status)")
            return false
        }
    }
    
    // MARK: - Retrieve Key
    
    /// Retrieve a string value from Keychain
    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        if status != errSecItemNotFound {
            print("⚠️ KeychainManager: Error retrieving key: \(key), status: \(status)")
        }
        
        return nil
    }
    
    // MARK: - Delete Key
    
    /// Delete a value from Keychain
    func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound
        
        if success {
            print("✅ KeychainManager: Deleted key: \(key)")
        } else {
            print("❌ KeychainManager: Failed to delete key: \(key), status: \(status)")
        }
        
        return success
    }
    
    // MARK: - Check Existence
    
    /// Check if a key exists in Keychain
    func exists(_ key: String) -> Bool {
        return get(key) != nil
    }
    
    // MARK: - Clear All
    
    /// Clear all keys for this service (use carefully)
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound
        
        if success {
            print("✅ KeychainManager: Cleared all keys for service: \(service)")
        } else {
            print("❌ KeychainManager: Failed to clear keys, status: \(status)")
        }
        
        return success
    }
}





