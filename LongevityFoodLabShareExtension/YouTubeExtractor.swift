//
//  YouTubeExtractor.swift
//  LongevityFoodLabShareExtension
//
//  YouTube recipe extraction for Share Extension
//

import Foundation

class YouTubeExtractor {
    static let shared = YouTubeExtractor()
    
    private let baseURL = "https://www.googleapis.com/youtube/v3"
    
    private init() {}
    
    // MARK: - Extract Video ID from URL
    
    func extractVideoID(from urlString: String) -> String? {
        // Handle various YouTube URL formats
        // Pattern 1: youtube.com/watch?v=VIDEO_ID
        if let range = urlString.range(of: #"youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})"#, options: .regularExpression),
           let match = urlString[range].range(of: #"[a-zA-Z0-9_-]{11}"#, options: .regularExpression) {
            return String(urlString[match])
        }
        
        // Pattern 2: youtu.be/VIDEO_ID
        if let range = urlString.range(of: #"youtu\.be/([a-zA-Z0-9_-]{11})"#, options: .regularExpression),
           let match = urlString[range].range(of: #"[a-zA-Z0-9_-]{11}"#, options: .regularExpression) {
            return String(urlString[match])
        }
        
        // Pattern 3: youtube.com/shorts/VIDEO_ID
        if let range = urlString.range(of: #"youtube\.com/shorts/([a-zA-Z0-9_-]{11})"#, options: .regularExpression),
           let match = urlString[range].range(of: #"[a-zA-Z0-9_-]{11}"#, options: .regularExpression) {
            return String(urlString[match])
        }
        
        // Pattern 4: youtube.com/embed/VIDEO_ID
        if let range = urlString.range(of: #"youtube\.com/embed/([a-zA-Z0-9_-]{11})"#, options: .regularExpression),
           let match = urlString[range].range(of: #"[a-zA-Z0-9_-]{11}"#, options: .regularExpression) {
            return String(urlString[match])
        }
        
        return nil
    }
    
    // MARK: - Extract Recipe from YouTube URL
    
    func extractRecipe(from urlString: String) async throws -> ImportedRecipe {
        print("📺 YouTubeExtractor: extractRecipe called for: \(urlString)")
        print("📺 YouTubeExtractor: Routing to Lambda for extraction")
        
        guard let videoID = extractVideoID(from: urlString) else {
            print("❌ YouTubeExtractor: Failed to extract video ID from: \(urlString)")
            throw YouTubeExtractorError.invalidURL
        }
        
        print("✅ YouTubeExtractor: Extracted video ID: \(videoID)")
        
        // Call Lambda endpoint for YouTube extraction (Lambda has its own API keys)
        return try await extractRecipeFromLambda(urlString: urlString)
    }
    
    // MARK: - Lambda Extraction
    
    private func extractRecipeFromLambda(urlString: String) async throws -> ImportedRecipe {
        print("📺 YouTubeExtractor: Calling Supabase Edge Function (with caching)...")
        
        // Use Supabase Edge Function instead of Lambda directly (enables caching)
        let supabaseURL = URL(string: "https://pkiwadwqpygpikrvuvgx.supabase.co/functions/v1/extract-recipe")!
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBraXdhZHdxcHlncGlrcnZ1dmd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNTQ3OTYsImV4cCI6MjA4MDgzMDc5Nn0.fIzoHjP83UTpTa1G_MMr4UoQ6Vbn3G60eNjTlrTEOYA"
        
        // Prepare payload
        let payload: [String: Any] = [
            "url": urlString,
            "html": ""  // Empty HTML for YouTube URLs
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("❌ YouTubeExtractor: Failed to serialize JSON payload")
            throw YouTubeExtractorError.networkError
        }
        
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        request.timeoutInterval = 25  // 25 second timeout to match network timeout and allow slow extractions
        
        print("📺 YouTubeExtractor: Sending request to Lambda...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ YouTubeExtractor: Invalid HTTP response")
            throw YouTubeExtractorError.networkError
        }
        
        print("📺 YouTubeExtractor: Lambda response status: \(httpResponse.statusCode)")
        
        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📺 YouTubeExtractor: Raw response (first 1000 chars): \(jsonString.prefix(1000))")
        }
        
        // Check for error response BEFORE trying to decode as recipe
        // Lambda can return 200 status with an error object in the body
        if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📺 YouTubeExtractor: Parsed response keys: \(errorData.keys.joined(separator: ", "))")
            if let errorMessage = errorData["error"] as? String {
                print("❌ YouTubeExtractor: Lambda returned error: \(errorMessage)")
                
                // Check for specific error types
                if errorMessage.contains("not a recipe") || errorMessage.contains("notARecipe") || errorMessage.contains("no usable content") {
                    throw YouTubeExtractorError.notARecipe
                } else if errorMessage.contains("empty") || errorMessage.contains("description") {
                    throw YouTubeExtractorError.emptyDescription
                } else {
                    throw YouTubeExtractorError.networkError
                }
            }
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorData["error"] as? String {
                print("❌ YouTubeExtractor: Lambda HTTP error: \(errorMessage)")
                
                // Check for specific error types
                if errorMessage.contains("not a recipe") || errorMessage.contains("notARecipe") || errorMessage.contains("no usable content") {
                    throw YouTubeExtractorError.notARecipe
                } else if errorMessage.contains("empty") || errorMessage.contains("description") {
                    throw YouTubeExtractorError.emptyDescription
                }
            }
            throw YouTubeExtractorError.networkError
        }
        
        // Parse Lambda response (only if no error)
        do {
            let decoder = JSONDecoder()
            let recipe = try decoder.decode(ImportedRecipe.self, from: data)
            
            print("✅ YouTubeExtractor: Lambda extraction successful!")
            print("   Title: \(recipe.title)")
            print("   Ingredients: \(recipe.ingredients.count)")
            print("   Instructions: \(recipe.instructions.components(separatedBy: "\n\n").count) steps")
            
            return recipe
        } catch {
            print("❌ YouTubeExtractor: Failed to decode Lambda response: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Response: \(jsonString.prefix(500))")
            }
            throw YouTubeExtractorError.networkError
        }
    }
    
    // MARK: - Fetch Video Metadata
    
    private func fetchVideoMetadata(videoID: String, apiKey: String) async throws -> VideoMetadata {
        let urlString = "\(baseURL)/videos?id=\(videoID)&part=snippet&key=\(apiKey)"
        print("📺 YouTubeExtractor: API URL: \(baseURL)/videos?id=\(videoID)&part=snippet&key=\(String(apiKey.prefix(10)))...")
        
        guard let url = URL(string: urlString) else {
            print("❌ YouTubeExtractor: Invalid API URL")
            throw YouTubeExtractorError.invalidURL
        }
        
        print("📺 YouTubeExtractor: Making API request...")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ YouTubeExtractor: Invalid HTTP response")
            throw YouTubeExtractorError.networkError
        }
        
        print("📺 YouTubeExtractor: API response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 403 {
            print("❌ YouTubeExtractor: API quota exceeded or invalid key")
            throw YouTubeExtractorError.quotaExceeded
        }
        
        if httpResponse.statusCode != 200 {
            print("❌ YouTubeExtractor: API error - status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Response: \(responseString.prefix(200))")
            }
            throw YouTubeExtractorError.apiError(statusCode: httpResponse.statusCode)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let items = json?["items"] as? [[String: Any]],
              let firstItem = items.first,
              let snippet = firstItem["snippet"] as? [String: Any] else {
            throw YouTubeExtractorError.videoNotFound
        }
        
        let title = snippet["title"] as? String ?? "Untitled"
        let description = snippet["description"] as? String ?? ""
        
        // Get highest quality thumbnail (prioritize maxres for best quality)
        var thumbnailURL: String?
        if let thumbnails = snippet["thumbnails"] as? [String: Any] {
            // Try maxres first (1280x720) - best quality
            if let maxres = thumbnails["maxres"] as? [String: Any],
               let url = maxres["url"] as? String {
                thumbnailURL = url
                print("📺 YouTubeExtractor: Using maxres thumbnail (1280x720)")
            } 
            // Fallback to high (480x360)
            else if let high = thumbnails["high"] as? [String: Any],
                      let url = high["url"] as? String {
                thumbnailURL = url
                print("📺 YouTubeExtractor: Using high thumbnail (480x360)")
            } 
            // Fallback to medium (320x180)
            else if let medium = thumbnails["medium"] as? [String: Any],
                      let url = medium["url"] as? String {
                thumbnailURL = url
                print("📺 YouTubeExtractor: Using medium thumbnail (320x180)")
            } 
            // Last resort: default (120x90)
            else if let defaultThumb = thumbnails["default"] as? [String: Any],
                      let url = defaultThumb["url"] as? String {
                thumbnailURL = url
                print("📺 YouTubeExtractor: Using default thumbnail (120x90)")
            }
        }
        
        return VideoMetadata(
            title: title,
            description: description,
            thumbnailURL: thumbnailURL ?? ""
        )
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
        
        // Find where ingredients section ends (at Method/Instructions)
        var ingredientsEndIndex: String.Index? = nil
        
        print("📺 YouTubeExtractor: Looking for Ingredients section...")
        // Look for Ingredients section (expanded keywords including dash format)
        let ingredientKeywords = [
            "INGREDIENTS:", "Ingredients:", "INGREDIENTS", "Ingredients",
            "INGREDIENTS -", "Ingredients -", "INGREDIENTS-", "Ingredients-",
            "INGREDIENT LIST:", "Ingredient List:", "INGREDIENT LIST", "Ingredient List",
            "WHAT YOU NEED:", "What You Need:", "WHAT YOU NEED", "What You Need",
            "FOR THE", "For The"
        ]
        if let ingredientsRange = findSection(in: description, keywords: ingredientKeywords) {
            let ingredientsText = String(description[ingredientsRange.upperBound...])
            print("   Found ingredients section, parsing...")
            
            // Find where Method/Instructions section starts to stop ingredients parsing
            let stopKeywords = ["METHOD:", "Method:", "METHOD -", "Method -", "METHOD-", "Method-", "INSTRUCTIONS:", "Instructions:", "DIRECTIONS:", "Directions:", "STEPS:", "Steps:"]
            var stopIndex = ingredientsText.endIndex
            for keyword in stopKeywords {
                if let range = ingredientsText.range(of: keyword, options: [.caseInsensitive]) {
                    if range.lowerBound < stopIndex {
                        stopIndex = range.lowerBound
                        ingredientsEndIndex = description.index(ingredientsRange.upperBound, offsetBy: ingredientsText.distance(from: ingredientsText.startIndex, to: stopIndex))
                    }
                }
            }
            
            let ingredientsToParse = String(ingredientsText[..<stopIndex])
            ingredients = parseList(from: ingredientsToParse, untilKeywords: [])
            print("   Parsed \(ingredients.count) ingredients")
        } else {
            print("   No ingredients section found with standard keywords")
            // Try to find ingredients in a more flexible way - look for common patterns
            if let ingredientsRange = description.range(of: #"(?i)(ingredients?\s*[-:])"#, options: .regularExpression) {
                let startIndex = description.index(ingredientsRange.upperBound, offsetBy: 0)
                // Skip whitespace and newlines
                var actualStart = startIndex
                while actualStart < description.endIndex && (description[actualStart].isWhitespace || description[actualStart].isNewline) {
                    actualStart = description.index(after: actualStart)
                }
                let ingredientsText = String(description[actualStart...])
                
                // Find where Method/Instructions section starts
                let stopKeywords = ["METHOD:", "Method:", "METHOD -", "Method -", "METHOD-", "Method-", "INSTRUCTIONS:", "Instructions:", "DIRECTIONS:", "Directions:", "STEPS:", "Steps:"]
                var stopIndex = ingredientsText.endIndex
                for keyword in stopKeywords {
                    if let range = ingredientsText.range(of: keyword, options: [.caseInsensitive]) {
                        if range.lowerBound < stopIndex {
                            stopIndex = range.lowerBound
                            ingredientsEndIndex = description.index(actualStart, offsetBy: ingredientsText.distance(from: ingredientsText.startIndex, to: stopIndex))
                        }
                    }
                }
                
                let ingredientsToParse = String(ingredientsText[..<stopIndex])
                ingredients = parseList(from: ingredientsToParse, untilKeywords: [])
                print("   Found ingredients with flexible search: \(ingredients.count) items")
            }
        }
        
        print("📺 YouTubeExtractor: Looking for Instructions section...")
        // Look for Instructions/Directions section (expanded keywords including dash format)
        // Prioritize "Method" as it's the most common in YouTube recipes
        let instructionKeywords = [
            "METHOD:", "Method:", "METHOD -", "Method -", "METHOD-", "Method-", "METHOD", "Method",
            "INSTRUCTIONS:", "Instructions:", "INSTRUCTIONS -", "Instructions -", "INSTRUCTIONS-", "Instructions-", "INSTRUCTIONS", "Instructions",
            "DIRECTIONS:", "Directions:", "DIRECTIONS -", "Directions -", "DIRECTIONS-", "Directions-", "DIRECTIONS", "Directions",
            "STEPS:", "Steps:", "STEPS", "Steps",
            "HOW TO MAKE:", "How To Make:", "HOW TO MAKE", "How To Make",
            "PREPARATION:", "Preparation:", "PREPARATION", "Preparation"
        ]
        
        // Only search for instructions AFTER the ingredients section ends
        let searchStartIndex = ingredientsEndIndex ?? description.startIndex
        let searchText = String(description[searchStartIndex...])
        
        if let instructionsRange = findSection(in: searchText, keywords: instructionKeywords) {
            let instructionsText = String(searchText[instructionsRange.upperBound...])
            print("   Found instructions section, parsing...")
            instructions = parseList(from: instructionsText, untilKeywords: [])
            print("   Parsed \(instructions.count) instruction items")
        } else {
            print("   No instructions section found with standard keywords")
            // Try flexible search for instructions - look for numbered steps
            // Many YouTube recipes don't have a header, just numbered steps
            // Only search AFTER ingredients section ends
            let searchStartIndex = ingredientsEndIndex ?? description.startIndex
            let searchText = String(description[searchStartIndex...])
            
            // Check if searchText contains numbered steps (1., 2., etc.)
            let lines = searchText.components(separatedBy: .newlines)
            var hasNumberedSteps = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                    hasNumberedSteps = true
                    break
                }
            }
            if hasNumberedSteps {
                print("   Found numbered steps after ingredients, parsing as instructions...")
                instructions = parseList(from: searchText, untilKeywords: [])
                print("   Parsed \(instructions.count) instruction items from numbered steps")
            } else if let instructionsRange = searchText.range(of: #"(?i)(instructions?\s*[-:]|directions?\s*[-:]|method\s*[-:]|steps\s*[-:])"#, options: .regularExpression) {
                let startIndex = searchText.index(instructionsRange.upperBound, offsetBy: 0)
                // Skip whitespace and newlines
                var actualStart = startIndex
                while actualStart < searchText.endIndex && (searchText[actualStart].isWhitespace || searchText[actualStart].isNewline) {
                    actualStart = searchText.index(after: actualStart)
                }
                let instructionsText = String(searchText[actualStart...])
                instructions = parseList(from: instructionsText, untilKeywords: [])
                print("   Found instructions with flexible search: \(instructions.count) items")
            }
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
        
        // Format instructions: join with double newline for proper step separation
        let instructionsText = instructions.joined(separator: "\n\n")
        
        return ImportedRecipe(
            title: cleanedTitle,
            sourceUrl: sourceURL,
            ingredients: ingredients,
            instructions: instructionsText,
            servings: servings,
            prepTimeMinutes: 0,
            imageUrl: thumbnailURL,
            rawIngredients: ingredients,
            rawInstructions: instructionsText
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
                // If we have a current item, save it and start fresh
                if !currentItem.isEmpty {
                    items.append(currentItem.trimmingCharacters(in: .whitespaces))
                    currentItem = ""
                }
                continue
            }
            
            // Check if this is a new item (starts with number, bullet, dash, or common prefixes)
            // Pattern: number at start (1, 1., 1), bullet (-, •, *), or measurement-like patterns
            let isNewItem = trimmed.range(of: #"^(\d+[\.\)]\s+|\d+\s+[-•\*]\s+|[-•\*]\s+|[A-Z]\d+)"#, options: .regularExpression) != nil ||
                           trimmed.range(of: #"^\d+\s*[-–—]\s+"#, options: .regularExpression) != nil
            
            if isNewItem {
                // Save previous item if not empty
                if !currentItem.isEmpty {
                    items.append(currentItem.trimmingCharacters(in: .whitespaces))
                }
                // Start new item (remove leading number/bullet/dash)
                currentItem = trimmed.replacingOccurrences(of: #"^(\d+[\.\)]\s+|\d+\s+[-•\*]\s+|[-•\*]\s+)"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^\d+\s*[-–—]\s+"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            } else if !currentItem.isEmpty {
                // Continue current item (multi-line ingredient/instruction)
                currentItem += " " + trimmed
            } else {
                // New item without bullet (might be first item or continuation)
                // Only treat as new item if it looks like a list item (short, specific format)
                if trimmed.count < 100 && (trimmed.contains("-") || trimmed.contains("(") || trimmed.contains("/")) {
                    currentItem = trimmed
                } else {
                    // Likely continuation or description text, skip
                    continue
                }
            }
        }
        
        // Add last item
        if !currentItem.isEmpty {
            items.append(currentItem.trimmingCharacters(in: .whitespaces))
        }
        
        return items.filter { !$0.isEmpty && $0.count > 3 } // Filter out very short items
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
            print("   ❌ Recipe validation: Title contains negative indicator")
            return false
        }
        
        // Must have ingredients and instructions
        // Relaxed requirement: at least 2 ingredients and 2 instruction lines
        // (Some recipes might be simpler)
        if recipeData.ingredients.count < 2 {
            print("   ❌ Recipe validation: Not enough ingredients (\(recipeData.ingredients.count) < 2)")
            return false
        }
        
        let instructionLines = recipeData.instructions.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        // Also check if instructions string has meaningful content (at least 50 chars)
        let hasMeaningfulInstructions = recipeData.instructions.trimmingCharacters(in: .whitespaces).count > 50
        
        if instructionLines.count < 2 && !hasMeaningfulInstructions {
            print("   ❌ Recipe validation: Not enough instructions (\(instructionLines.count) lines, \(recipeData.instructions.count) chars)")
            return false
        }
        
        print("   ✅ Recipe validation: Passed (ingredients: \(recipeData.ingredients.count), instructions: \(instructionLines.count) lines)")
        return true
    }
}

// MARK: - Data Structures

private struct VideoMetadata {
    let title: String
    let description: String
    let thumbnailURL: String
}

// MARK: - Errors

enum YouTubeExtractorError: LocalizedError {
    case invalidURL
    case apiKeyMissing
    case videoNotFound
    case quotaExceeded
    case networkError
    case apiError(statusCode: Int)
    case notARecipe
    case emptyDescription
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid YouTube URL"
        case .apiKeyMissing:
            return "YouTube API key not configured"
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
        case .emptyDescription:
            return "Video description is empty (common with YouTube Shorts)"
        }
    }
}

