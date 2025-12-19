//
//  SupabaseConfig.swift
//  LongevityFoodLab
//
//  Configuration for Supabase Edge Functions
//

import Foundation

struct SupabaseConfig {
    // Supabase Project URL
    static let projectURL = "https://pkiwadwqpygpikrvuvgx.supabase.co"
    
    // Supabase anon public key (safe to use in iOS app)
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBraXdhZHdxcHlncGlrcnZ1dmd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNTQ3OTYsImV4cCI6MjA4MDgzMDc5Nn0.fIzoHjP83UTpTa1G_MMr4UoQ6Vbn3G60eNjTlrTEOYA"
    
    // Edge Function endpoint for recipe extraction
    static var extractRecipeURL: URL {
        return URL(string: "\(projectURL)/functions/v1/extract-recipe")!
    }
    
    // Create authenticated request headers
    static func authenticatedHeaders() -> [String: String] {
        return [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(anonKey)",
            "apikey": anonKey
        ]
    }
}

