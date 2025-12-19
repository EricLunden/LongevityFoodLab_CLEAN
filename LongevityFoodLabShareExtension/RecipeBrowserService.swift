import Foundation

// Import NutritionInfo from main app (FoodData.swift should be accessible if included in ShareExtension target)
// If not accessible, we'll need to add FoodData.swift to ShareExtension target membership

// MARK: - Data Structures

enum RecipeExtractionResult {
    case success(ImportedRecipe)
    case fallbackMeta(title: String, imageURL: String?, siteLink: String?)
    case fallbackHostname(hostname: String)
}

struct FallbackRecipeData {
    let title: String
    let imageURL: String?
    let siteLink: String?
    let prepTime: Int?
    let servings: Int?
    let isYouTube: Bool  // Track if this is a YouTube URL that failed extraction
}

class RecipeBrowserService: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var extractedRecipe: ImportedRecipe?
    
    // Supabase Edge Function endpoint (with caching)
    private let SUPABASE_URL = "https://pkiwadwqpygpikrvuvgx.supabase.co/functions/v1/extract-recipe"
    private let SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBraXdhZHdxcHlncGlrcnZ1dmd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNTQ3OTYsImV4cCI6MjA4MDgzMDc5Nn0.fIzoHjP83UTpTa1G_MMr4UoQ6Vbn3G60eNjTlrTEOYA"
    
    // Keep LAMBDA_URL for backward compatibility (now points to Supabase)
    private var LAMBDA_URL: String { SUPABASE_URL }
    
    override init() {
        super.init()
        print("SE/CFG: supabase-edge-function=\(SUPABASE_URL)")
    }
    
    // MARK: - Public Methods
    
    func extractRecipeWithHTML(from url: URL, completion: @escaping (RecipeExtractionResult) -> Void) {
        print("SE/NET: html-fetch start url=\(url.absoluteString)")
        print("🔍 SE/RecipeBrowserService: Checking if URL is YouTube: \(url.absoluteString)")
        
        // Check if this is a YouTube URL
        if isYouTubeURL(url.absoluteString) {
            print("📺 SE/RecipeBrowserService: ✅ YouTube URL detected! Routing to YouTubeExtractor")
            extractYouTubeRecipe(from: url, completion: completion)
            return
        } else if isTikTokURL(url.absoluteString) {
            print("📱 SE/RecipeBrowserService: ✅ TikTok URL detected! Routing to Lambda via Edge Function (no HTML fetch)")
            // TikTok URLs go directly to Edge Function with empty HTML (like YouTube)
            // The Edge Function will route to Lambda's TikTok extraction
            extractTikTokRecipe(from: url, completion: completion)
            return
        } else {
            print("🌐 SE/RecipeBrowserService: Not a YouTube or TikTok URL, using Lambda extraction")
        }
        
        isLoading = true
        errorMessage = nil
        
        // Store completion handler
        self.extractionCompletionHandler = completion
        
        // Fetch HTML first, then send to Lambda
        fetchHTML(from: url) { [weak self] htmlResult in
            switch htmlResult {
            case .success(let html):
                self?.sendToLambdaWithHTML(url: url.absoluteString, html: html, completion: completion)
            case .failure(let error):
                print("SE/NET: html-fetch error=\(error.localizedDescription)")
                // Try to extract basic metadata from URL for fallback
                self?.extractBasicMetadataFromURL(url, completion: completion)
            }
        }
    }
    
    // MARK: - YouTube Extraction
    
    private func isYouTubeURL(_ urlString: String) -> Bool {
        let isYouTube = urlString.contains("youtube.com") || urlString.contains("youtu.be")
        print("🔍 SE/RecipeBrowserService: isYouTubeURL check for '\(urlString)': \(isYouTube)")
        return isYouTube
    }
    
    // MARK: - TikTok Detection
    
    private func isTikTokURL(_ urlString: String) -> Bool {
        let isTikTok = urlString.contains("tiktok.com") || urlString.contains("vm.tiktok.com") || urlString.contains("t.tiktok.com")
        print("🔍 SE/RecipeBrowserService: isTikTokURL check for '\(urlString)': \(isTikTok)")
        return isTikTok
    }
    
    private func extractYouTubeRecipe(from url: URL, completion: @escaping (RecipeExtractionResult) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // YouTube extraction is handled by Lambda, which has its own API keys
        // No need to check for keys in the iOS app
        Task {
            do {
                print("📺 SE/RecipeBrowserService: Starting YouTube extraction for: \(url.absoluteString)")
                let recipe = try await YouTubeExtractor.shared.extractRecipe(from: url.absoluteString)
                print("✅ SE/RecipeBrowserService: YouTube extraction successful - Title: \(recipe.title), Ingredients: \(recipe.ingredients.count), Instructions: \(recipe.instructions.components(separatedBy: "\n\n").count)")
                await MainActor.run {
                    self.isLoading = false
                    // Convert ImportedRecipe to RecipeExtractionResult
                    completion(.success(recipe))
                }
            } catch {
                print("❌ SE/RecipeBrowserService: YouTube extraction failed: \(error)")
                if let youtubeError = error as? YouTubeExtractorError {
                    print("   Error type: \(youtubeError)")
                    print("   Error description: \(youtubeError.localizedDescription)")
                    print("   Video URL: \(url.absoluteString)")
                } else {
                    print("   Unknown error: \(error.localizedDescription)")
                    print("   Video URL: \(url.absoluteString)")
                }
                await MainActor.run {
                    self.isLoading = false
                    // Fallback to hostname preview for YouTube (extraction failed)
                    let hostname = URL(string: url.absoluteString)?.host ?? "YouTube"
                    print("⚠️ SE/RecipeBrowserService: YouTube extraction failed - showing fallback preview (Save disabled)")
                    print("⚠️ SE/RecipeBrowserService: User will see error message and Save button will be disabled")
                    completion(.fallbackHostname(hostname: hostname))
                }
            }
        }
    }
    
    private func extractTikTokRecipe(from url: URL, completion: @escaping (RecipeExtractionResult) -> Void) {
        isLoading = true
        errorMessage = nil
        
        // TikTok extraction is handled by Lambda via Edge Function (same as YouTube)
        // Send empty HTML - Lambda will use Apify to fetch metadata
        print("📱 SE/RecipeBrowserService: Starting TikTok extraction for: \(url.absoluteString)")
        sendToLambdaWithHTML(url: url.absoluteString, html: "", completion: completion)
    }
    
    func extractRecipe(from url: URL, completion: @escaping (ImportedRecipe?) -> Void) {
        print("SE/NET: Lambda URL-only request started")
        
        isLoading = true
        errorMessage = nil
        
        // Store completion handler
        self.completionHandler = completion
        
        // Send URL-only request to Lambda
        sendToLambdaURLOnly(url: url.absoluteString, completion: completion)
    }
    
    private var completionHandler: ((ImportedRecipe?) -> Void)?
    private var extractionCompletionHandler: ((RecipeExtractionResult) -> Void)?
    
    // MARK: - HTML Fetching
    
    private func fetchHTML(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        print("SE/NET: html-fetch start url=\(url.absoluteString)")
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("SE/NET: html-fetch err=\(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("SE/NET: html-fetch err=invalid-response")
                completion(.failure(NSError(domain: "InvalidResponse", code: -1, userInfo: nil)))
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                print("SE/NET: html-fetch err=no-data")
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            print("SE/NET: html-fetch ok status=\(httpResponse.statusCode) bytes=\(data.count)")
            completion(.success(html))
        }.resume()
    }
    
    // MARK: - Lambda Communication
    
    private func sendToLambdaWithHTML(url: String, html: String, completion: @escaping (RecipeExtractionResult) -> Void) {
        print("SE/NET: supabase-post start payload={url:\(url), html_len:\(html.count)}")
        print("SE/NET: supabase-url=\(SUPABASE_URL)")
        print("SE/NET: supabase-key-length=\(SUPABASE_ANON_KEY.count)")
        
        guard let supabaseURL = URL(string: SUPABASE_URL) else {
            print("SE/NET: supabase error=invalid-url")
            completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
            return
        }
        
        // Prepare payload with both URL and HTML
        let payload: [String: Any] = [
            "url": url,
            "html": html
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("SE/NET: lambda error=json-serialization-failed")
            completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
            return
        }
        
        // Create URLSession configuration
        // Increased timeout for TikTok extraction (can take 20-30 seconds)
        let config = URLSessionConfiguration.ephemeral
        let isTikTok = url.contains("tiktok.com")
        config.timeoutIntervalForRequest = isTikTok ? 90 : 25  // 90s for TikTok, 25s for others
        config.timeoutIntervalForResource = isTikTok ? 90 : 25  // 90s for TikTok, 25s for others
        config.waitsForConnectivity = false
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        let session = URLSession(configuration: config)
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("SE/NET: supabase error=\(error.localizedDescription)")
                // Do diagnostic HEAD request
                self.performDiagnosticHEAD()
                completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("SE/NET: lambda error=invalid-response")
                self.performDiagnosticHEAD()
                completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
                return
            }
            
            guard let data = data else {
                print("SE/NET: lambda error=no-data")
                self.performDiagnosticHEAD()
                completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
                return
            }
            
            print("SE/NET: supabase-post ok status=\(httpResponse.statusCode) bytes=\(data.count)")
            
            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("SE/NET: supabase error=non-200-status response=\(responseString.prefix(200))")
                } else {
                    print("SE/NET: supabase error=non-200-status (no response body)")
                }
                self.performDiagnosticHEAD()
                completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
                return
            }
            
            // Log raw response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.prefix(500)
                print("SE/NET: supabase-raw-response (first 500 chars)=\(preview)")
                print("SE/NET: supabase-raw-response (total length)=\(responseString.count) chars")
                
                // Check for Supabase error format
                if responseString.contains("\"code\"") || responseString.contains("\"message\"") {
                    print("⚠️ SE/NET: Supabase returned an error response")
                }
                // Check if nutrition is in the raw response
                if responseString.contains("\"nutrition\"") {
                    print("✅ SE/NET: Raw response CONTAINS 'nutrition' key")
                } else {
                    print("❌ SE/NET: Raw response DOES NOT contain 'nutrition' key")
                }
            }
            
            // Parse Lambda response
            self.parseLambdaResponse(data: data, url: url, completion: completion)
        }.resume()
    }
    
    private func sendToLambdaURLOnly(url: String, completion: @escaping (ImportedRecipe?) -> Void) {
        print("SE/NET: lambda-post start payload={url:\(url), html_len:0}")
        
        guard let supabaseURL = URL(string: SUPABASE_URL) else {
            print("SE/NET: supabase error=invalid-url")
            completion(nil)
            return
        }
        
        // Prepare payload with URL only
        let payload: [String: Any] = [
            "url": url,
            "html": ""
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("SE/NET: lambda error=json-serialization-failed")
            completion(nil)
            return
        }
        
        // Create URLSession configuration
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        
        let session = URLSession(configuration: config)
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        request.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        request.httpBody = jsonData
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("SE/NET: lambda error=\(error.localizedDescription)")
                self.performDiagnosticHEAD()
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("SE/NET: lambda error=invalid-response")
                self.performDiagnosticHEAD()
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("SE/NET: lambda error=no-data")
                self.performDiagnosticHEAD()
                completion(nil)
                return
            }
            
            print("SE/NET: lambda-post ok status=\(httpResponse.statusCode) bytes=\(data.count)")
            
            if httpResponse.statusCode != 200 {
                print("SE/NET: lambda error=non-200-status")
                self.performDiagnosticHEAD()
                completion(nil)
                return
            }
            
            // Log raw response data for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                let preview = responseString.prefix(500)
                print("SE/NET: lambda-raw-response (first 500 chars)=\(preview)")
                print("SE/NET: lambda-raw-response (total length)=\(responseString.count) chars")
                // Check if nutrition is in the raw response
                if responseString.contains("\"nutrition\"") {
                    print("✅ SE/NET: Raw response CONTAINS 'nutrition' key")
                } else {
                    print("❌ SE/NET: Raw response DOES NOT contain 'nutrition' key")
                }
            }
            
            // Parse Lambda response
            self.parseLambdaResponse(data: data, url: url, completion: completion)
        }.resume()
    }
    
    private func performDiagnosticHEAD() {
        print("SE/NET: lambda-head diag start")
        
        guard let supabaseURL = URL(string: SUPABASE_URL) else {
            print("SE/NET: supabase-head diag error=invalid-url")
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 2
        
        let session = URLSession(configuration: config)
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "HEAD"
        
        session.dataTask(with: request) { _, response, error in
            if let error = error {
                print("SE/NET: lambda-head diag error=\(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("SE/NET: lambda-head diag status=\(httpResponse.statusCode)")
            } else {
                print("SE/NET: lambda-head diag status=unknown")
            }
        }.resume()
    }
    
    private func parseLambdaResponse(data: Data, url: String, completion: @escaping (RecipeExtractionResult) -> Void) {
        print("🔍 SE/NET: [METHOD 1] parseLambdaResponse(RecipeExtractionResult) called - data size: \(data.count) bytes")
        do {
            // First parse as generic JSON to handle field name mapping
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("SE/NET: lambda-parse error=invalid-json-structure")
                completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
                return
            }
            
            print("🔍 SE/NET: [METHOD 1] JSON parsed successfully - keys: \(json.keys.sorted())")
            
            // Check for error response first (quality validation failures, etc.)
            if let errorMessage = json["error"] as? String {
                print("SE/NET: lambda-error response=\(errorMessage)")
                if let reason = json["reason"] as? String {
                    print("SE/NET: lambda-error reason=\(reason)")
                }
                if let qualityScore = json["quality_score"] as? Double, qualityScore == 0.0 {
                    print("SE/NET: lambda-error quality_score=0.0")
                }
                // Quality validation failed or other error - show fallback
                completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
                return
            }
            
            // Extract and map fields from Lambda response
            let title = json["title"] as? String ?? "Untitled Recipe"
            
            // If title is still "Untitled Recipe" and no other data, likely an error
            if title == "Untitled Recipe" && json["ingredients"] == nil && json["instructions"] == nil {
                print("SE/NET: lambda-parse warning=insufficient-data")
                completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
                return
            }
            let sourceUrl = json["source_url"] as? String ?? json["sourceUrl"] as? String ?? url
            
            // DEBUG: Log Lambda servings response
            let servingsRaw = json["servings"]
            print("🍽️ Lambda returned servings (raw): \(servingsRaw ?? "nil")")
            let servings = (json["servings"] as? Int) ?? (json["servings"] as? String).flatMap { Int($0) } ?? 1
            print("🍽️ Parsed servings value: \(servings) (default: 1 if not found)")
            
            // Handle ingredients - could be array of strings
            var ingredients: [String] = []
            if let ingredientsArray = json["ingredients"] as? [String] {
                ingredients = ingredientsArray
            } else if let ingredientsArray = json["ingredients"] as? [Any] {
                ingredients = ingredientsArray.compactMap { $0 as? String }
            }
            
            // Filter out non-ingredient text (same comprehensive filter as RecipeManager)
            ingredients = ingredients.compactMap { ingredient in
                var cleaned = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove step numbers
                cleaned = cleaned.replacingOccurrences(
                    of: "^\\d+\\.\\s*",
                    with: "",
                    options: .regularExpression
                )
                
                // Remove bullets and dashes
                cleaned = cleaned.replacingOccurrences(
                    of: "^[•●*·-–—]\\s*",
                    with: "",
                    options: .regularExpression
                )
                
                // Remove common non-ingredient prefixes
                let unwantedPrefixes = [
                    "^Deselect All",
                    "^Select All",
                    "^Ingredients:",
                    "^Ingredient:",
                    "^For serving:",
                    "^For garnish:",
                    "^Optional:",
                    "^or\\s+",
                    "^plus\\s+more",
                    "^plus\\s+",
                ]
                for prefix in unwantedPrefixes {
                    cleaned = cleaned.replacingOccurrences(
                        of: prefix,
                        with: "",
                        options: [.regularExpression, .caseInsensitive]
                    )
                }
                
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Return nil if empty, otherwise return cleaned ingredient
                return cleaned.isEmpty ? nil : cleaned
            }
            
            // Handle instructions - Lambda returns array, but ImportedRecipe expects String
            var instructions: String = ""
            if let instructionsArray = json["instructions"] as? [String] {
                instructions = instructionsArray.joined(separator: "\n")
            } else if let instructionsString = json["instructions"] as? String {
                instructions = instructionsString
            }
            
            // Handle prep time - Lambda can return as Int (prep_time_minutes) or Int/String (prep_time)
            var prepTimeMinutes: Int = 0
            if let prepTimeInt = json["prep_time_minutes"] as? Int {
                prepTimeMinutes = prepTimeInt
            } else if let prepTimeInt = json["prep_time"] as? Int {
                // Handle prep_time as Int (direct minutes from Food Network parser)
                prepTimeMinutes = prepTimeInt
            } else if let prepTimeStr = json["prep_time"] as? String {
                prepTimeMinutes = parseTimeToMinutes(prepTimeStr)
            }
            
            // Handle image URL - check both possible field names
            let imageUrl = (json["image_url"] as? String) ?? (json["image"] as? String)
            
            // Extract nutrition from Lambda response
            var extractedNutrition: NutritionInfo? = nil
            var nutritionSource: String? = nil
            
            // Debug: Check if nutrition field exists
            print("🔍 SE/NET: [METHOD 1] Checking for nutrition field...")
            if let nutritionField = json["nutrition"] {
                print("🔍 SE/NET: [METHOD 1] Found 'nutrition' field - type: \(type(of: nutritionField))")
                print("🔍 SE/NET: [METHOD 1] Nutrition field value: \(nutritionField)")
            } else {
                print("⚠️ SE/NET: [METHOD 1] No 'nutrition' field in Lambda response")
                print("🔍 SE/NET: [METHOD 1] Available JSON keys: \(json.keys.sorted())")
            }
            
            if let nutritionDict = json["nutrition"] as? [String: Any],
               let caloriesStr = nutritionDict["calories"] as? String, !caloriesStr.isEmpty {
                print("🔍 SE/NET: Parsing nutrition dict - calories: \(caloriesStr)")
                print("🔍 SE/NET: Nutrition dict keys: \(nutritionDict.keys.sorted())")
                
                // Log calcium value specifically
                if let calciumRaw = nutritionDict["calcium"] {
                    print("🔍 SE/NET: Raw calcium value from Lambda: \(calciumRaw) (type: \(type(of: calciumRaw)))")
                } else {
                    print("⚠️ SE/NET: No 'calcium' key in nutrition dict")
                }
                
                // Helper function to format nutrition values
                func formatNutritionValue(_ value: Any?, unit: String, isInteger: Bool = false) -> String {
                    guard let val = value else { return isInteger ? "0" : "0\(unit)" }
                    let str = String(describing: val)
                    guard !str.isEmpty, let num = Double(str) else {
                        return isInteger ? "0" : "0\(unit)"
                    }
                    if isInteger {
                        return "\(Int(num))\(unit)"
                    }
                    return String(format: "%.1f\(unit)", num)
                }
                
                // Create NutritionInfo with properly formatted values
                let calciumFormatted = formatNutritionValue(nutritionDict["calcium"], unit: "mg", isInteger: true)
                print("🔍 SE/NET: Formatted calcium value: \(calciumFormatted)")
                
                extractedNutrition = NutritionInfo(
                    calories: caloriesStr,
                    protein: formatNutritionValue(nutritionDict["protein"], unit: "g"),
                    carbohydrates: formatNutritionValue(nutritionDict["carbohydrates"], unit: "g"),
                    fat: formatNutritionValue(nutritionDict["fat"], unit: "g"),
                    sugar: formatNutritionValue(nutritionDict["sugar"], unit: "g"),
                    fiber: formatNutritionValue(nutritionDict["fiber"], unit: "g"),
                    sodium: formatNutritionValue(nutritionDict["sodium"], unit: "mg", isInteger: true),
                    vitaminD: formatNutritionValue(nutritionDict["vitamin_d"], unit: "mcg"),
                    vitaminE: formatNutritionValue(nutritionDict["vitamin_e"], unit: "mg"),
                    potassium: formatNutritionValue(nutritionDict["potassium"], unit: "mg", isInteger: true),
                    vitaminK: formatNutritionValue(nutritionDict["vitamin_k"], unit: "mcg"),
                    magnesium: formatNutritionValue(nutritionDict["magnesium"], unit: "mg", isInteger: true),
                    vitaminA: formatNutritionValue(nutritionDict["vitamin_a"], unit: "mcg"),
                    calcium: calciumFormatted,
                    vitaminC: formatNutritionValue(nutritionDict["vitamin_c"], unit: "mg", isInteger: true),
                    choline: formatNutritionValue(nutritionDict["choline"], unit: "mg", isInteger: true),
                    iron: formatNutritionValue(nutritionDict["iron"], unit: "mg"),
                    iodine: formatNutritionValue(nutritionDict["iodine"], unit: "mcg"),
                    zinc: formatNutritionValue(nutritionDict["zinc"], unit: "mg"),
                    folate: formatNutritionValue(nutritionDict["folate"], unit: "mcg"),
                    vitaminB12: formatNutritionValue(nutritionDict["vitamin_b12"], unit: "mcg"),
                    vitaminB6: formatNutritionValue(nutritionDict["vitamin_b6"], unit: "mg"),
                    selenium: formatNutritionValue(nutritionDict["selenium"], unit: "mcg"),
                    copper: formatNutritionValue(nutritionDict["copper"], unit: "mg"),
                    manganese: formatNutritionValue(nutritionDict["manganese"], unit: "mg"),
                    thiamin: formatNutritionValue(nutritionDict["thiamin"], unit: "mg")
                )
                
                nutritionSource = json["nutrition_source"] as? String ?? "extracted"
                print("✅ RecipeBrowserService: Extracted nutrition from recipe page - \(caloriesStr) calories, calcium: \(calciumFormatted)")
            }
            
            // Create ImportedRecipe with mapped fields
            let recipe = ImportedRecipe(
                title: title,
                sourceUrl: sourceUrl,
                ingredients: ingredients,
                instructions: instructions,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                imageUrl: imageUrl,
                rawIngredients: ingredients,
                rawInstructions: instructions,
                extractedNutrition: extractedNutrition,
                nutritionSource: nutritionSource
            )
            
            print("SE/VIEW: preview-present (lambda) - title=\(recipe.title)")
            completion(.success(recipe))
            
        } catch {
            print("SE/NET: lambda-parse error=\(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("SE/NET: lambda-parse data=\(responseString)")
            }
            completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
        }
    }
    
    private func parseLambdaResponse(data: Data, url: String, completion: @escaping (ImportedRecipe?) -> Void) {
        print("🔍 SE/NET: [METHOD 2] parseLambdaResponse(ImportedRecipe?) called - data size: \(data.count) bytes")
        // Use the existing parseLambdaResponse that properly handles nutrition
        self.parseLambdaResponse(data: data, url: url) { result in
            print("🔍 SE/NET: [METHOD 2] Received result from Method 1")
            switch result {
            case .success(let recipe):
                print("🔍 SE/NET: [METHOD 2] Success - recipe has extractedNutrition: \(recipe.extractedNutrition != nil)")
                if let nutrition = recipe.extractedNutrition {
                    print("🔍 SE/NET: [METHOD 2] Extracted nutrition calories: \(nutrition.calories)")
                }
                completion(recipe)
            case .fallbackHostname:
                print("🔍 SE/NET: [METHOD 2] Fallback hostname")
                completion(nil)
            case .fallbackMeta:
                print("🔍 SE/NET: [METHOD 2] Fallback meta")
                completion(nil)
            }
        }
    }
    private var watchdogTimer: DispatchSourceTimer?
    private var hasFinished = false
    
    // MARK: - Fallback Metadata Extraction
    
    private func extractBasicMetadataFromURL(_ url: URL, completion: @escaping (RecipeExtractionResult) -> Void) {
        print("SE/VIEW: fallback-preview (lambda-fail)")
        
        let hostname = url.host ?? "Unknown Site"
        completion(.fallbackHostname(hostname: hostname))
    }
    
    // Helper function to parse time strings to minutes
    private func parseTimeToMinutes(_ timeStr: String) -> Int {
        let lowercased = timeStr.lowercased()
        let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        guard let value = Int(numbers) else { return 0 }
        
        if lowercased.contains("hour") || lowercased.contains("hr") {
            return value * 60
        } else if lowercased.contains("minute") || lowercased.contains("min") {
            return value
        }
        
        return value // Default assume minutes
    }
    
}
