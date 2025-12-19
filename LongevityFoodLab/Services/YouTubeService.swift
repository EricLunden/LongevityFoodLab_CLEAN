//
//  YouTubeService.swift
//  LongevityFoodLab
//
//  YouTube recipe extraction service
//

import Foundation

class YouTubeService {
    static let shared = YouTubeService()
    
    // Note: API keys are handled by Lambda, not needed in iOS app
    
    private init() {}
    
    // MARK: - Extract Video ID from URL
    
    func extractVideoID(from urlString: String) -> String? {
        // Handle various YouTube URL formats
        let patterns = [
            "youtube.com/watch\\?v=([a-zA-Z0-9_-]{11})",
            "youtu.be/([a-zA-Z0-9_-]{11})",
            "youtube.com/shorts/([a-zA-Z0-9_-]{11})",
            "youtube.com/embed/([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: urlString, options: [], range: NSRange(location: 0, length: urlString.utf16.count)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: urlString) {
                return String(urlString[range])
            }
        }
        
        return nil
    }
    
    // MARK: - Extract Recipe from YouTube URL
    
    func extractRecipe(from urlString: String) async throws -> ImportedRecipe {
        guard let videoID = extractVideoID(from: urlString) else {
            throw YouTubeError.invalidURL
        }
        
        // Call Lambda endpoint for YouTube extraction
        return try await extractRecipeFromLambda(urlString: urlString)
    }
    
    // MARK: - Supabase Edge Function Extraction (with caching)
    
    private func extractRecipeFromLambda(urlString: String) async throws -> ImportedRecipe {
        // Use Supabase Edge Function instead of Lambda directly (enables caching)
        let supabaseURL = SupabaseConfig.extractRecipeURL
        
        // Prepare payload
        let payload: [String: Any] = [
            "url": urlString,
            "html": ""  // Empty HTML for YouTube URLs
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw YouTubeError.networkError
        }
        
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "POST"
        
        // Add Supabase authentication headers
        let headers = SupabaseConfig.authenticatedHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = jsonData
        request.timeoutInterval = 15  // 15 second timeout
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeError.networkError
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                // Check for specific error types
                if errorMessage.contains("not a recipe") || errorMessage.contains("notARecipe") {
                    throw YouTubeError.notARecipe
                }
            }
            throw YouTubeError.networkError
        }
        
        // Parse Lambda response
        let decoder = JSONDecoder()
        let recipe = try decoder.decode(ImportedRecipe.self, from: data)
        
        return recipe
    }
    
    // MARK: - Parse Recipe from Description
    
    private func parseRecipeFromDescription(
        title: String,
        description: String,
        thumbnailURL: String,
        sourceURL: String
    ) -> ImportedRecipe {
        var ingredients: [String] = []
        var instructions: [String] = []
        var servings: Int = 4 // Default
        
        // Look for Ingredients section
        if let ingredientsRange = findSection(in: description, keywords: ["INGREDIENTS:", "Ingredients:", "INGREDIENTS", "Ingredients"]) {
            let ingredientsText = String(description[ingredientsRange.upperBound...])
            ingredients = parseList(from: ingredientsText, untilKeywords: ["INSTRUCTIONS:", "Instructions:", "DIRECTIONS:", "Directions:", "METHOD:", "Method:"])
        }
        
        // Look for Instructions/Directions section
        if let instructionsRange = findSection(in: description, keywords: ["INSTRUCTIONS:", "Instructions:", "DIRECTIONS:", "Directions:", "METHOD:", "Method:"]) {
            let instructionsText = String(description[instructionsRange.upperBound...])
            instructions = parseList(from: instructionsText, untilKeywords: [])
        }
        
        // Look for Servings
        if let servingsMatch = description.range(of: #"(?i)(serves|servings|makes|yield)[:\s]*(\d+)"#, options: .regularExpression) {
            let servingsText = String(description[servingsMatch])
            if let number = Int(servingsText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                servings = number
            }
        }
        
        // Clean title
        let cleanedTitle = cleanTitle(title)
        
        return ImportedRecipe(
            title: cleanedTitle,
            sourceUrl: sourceURL,
            ingredients: ingredients,
            instructions: instructions.joined(separator: "\n"),
            servings: servings,
            prepTimeMinutes: 0,
            imageUrl: thumbnailURL,
            rawIngredients: ingredients,
            rawInstructions: instructions.joined(separator: "\n")
        )
    }
    
    // MARK: - Helper Methods
    
    private func findSection(in text: String, keywords: [String]) -> Range<String.Index>? {
        for keyword in keywords {
            if let range = text.range(of: keyword, options: [.caseInsensitive, .anchored]) {
                // Find the end of the keyword
                let startIndex = text.index(range.upperBound, offsetBy: 0)
                // Skip whitespace and newlines
                var endIndex = startIndex
                while endIndex < text.endIndex && (text[endIndex].isWhitespace || text[endIndex].isNewline) {
                    endIndex = text.index(after: endIndex)
                }
                return endIndex..<text.endIndex
            }
        }
        return nil
    }
    
    private func parseList(from text: String, untilKeywords: [String]) -> [String] {
        var items: [String] = []
        var currentItem = ""
        
        // Find where to stop parsing
        var stopIndex = text.endIndex
        for keyword in untilKeywords {
            if let range = text.range(of: keyword, options: [.caseInsensitive]) {
                if range.lowerBound < stopIndex {
                    stopIndex = range.lowerBound
                }
            }
        }
        
        let textToParse = String(text[..<stopIndex])
        let lines = textToParse.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines
            if trimmed.isEmpty {
                continue
            }
            
            // Check if this is a new item (starts with number, bullet, or dash)
            if trimmed.range(of: #"^[\d\-•\*]\s+"#, options: .regularExpression) != nil {
                // Save previous item if not empty
                if !currentItem.isEmpty {
                    items.append(currentItem.trimmingCharacters(in: .whitespaces))
                }
                // Start new item (remove leading number/bullet)
                currentItem = trimmed.replacingOccurrences(of: #"^[\d\-•\*]\s+"#, with: "", options: .regularExpression)
            } else if !currentItem.isEmpty {
                // Continue current item
                currentItem += " " + trimmed
            } else {
                // New item without bullet
                currentItem = trimmed
            }
        }
        
        // Add last item
        if !currentItem.isEmpty {
            items.append(currentItem.trimmingCharacters(in: .whitespaces))
        }
        
        return items.filter { !$0.isEmpty }
    }
    
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        
        // Remove common suffixes
        cleaned = cleaned.replacingOccurrences(of: #"\s*-\s*YouTube$"#, with: "", options: [.regularExpression, .caseInsensitive])
        cleaned = cleaned.replacingOccurrences(of: #"\s*\|.*$"#, with: "", options: .regularExpression)
        
        // Remove emojis
        cleaned = cleaned.unicodeScalars.filter { !$0.properties.isEmoji }.reduce("") { $0 + String($1) }
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        return cleaned
    }
    
    // MARK: - Recipe Detection
    
    private func isRecipe(recipeData: ImportedRecipe) -> Bool {
        // Check for negative indicators
        let title = recipeData.title.lowercased()
        if title.contains("review") || title.contains("taste test") || title.contains("ranking") {
            return false
        }
        
        // Must have ingredients and instructions
        if recipeData.ingredients.count < 3 {
            return false
        }
        
        let instructionLines = recipeData.instructions.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if instructionLines.count < 3 {
            return false
        }
        
        return true
    }
}

// MARK: - Errors

enum YouTubeError: LocalizedError {
    case invalidURL
    case videoNotFound
    case quotaExceeded
    case networkError
    case apiError(statusCode: Int)
    case notARecipe
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid YouTube URL"
        case .videoNotFound:
            return "Video not found"
        case .quotaExceeded:
            return "YouTube API quota exceeded"
        case .networkError:
            return "Network error"
        case .apiError(let code):
            return "YouTube API error: \(code)"
        case .notARecipe:
            return "This doesn't appear to be a recipe video"
        }
    }
}

