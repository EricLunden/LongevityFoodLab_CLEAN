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
        
        // Fetch HTML first, then check for print page
        fetchHTML(from: url) { [weak self] htmlResult in
            guard let self = self else { return }
            
            switch htmlResult {
            case .success(let html):
                // Priority 1: Try Print Recipe page (cleanest HTML)
                if let printURL = self.detectPrintRecipeURL(in: html, baseURL: url) {
                    print("🖨️ SE/RecipeBrowserService: Print page detected, fetching...")
                    // Fetch print page HTML
                    self.fetchPrintPageHTML(from: printURL) { printResult in
                        switch printResult {
                        case .success(let printHTML):
                            print("✅ SE/RecipeBrowserService: Using print page HTML (length: \(printHTML.count))")
                            // Send print page HTML to Lambda with retry logic
                            self.sendToLambdaWithHTML(url: url.absoluteString, html: printHTML, htmlSource: "print", fullHTMLForImageExtraction: printHTML, completion: { result in
                                // Check if extraction was successful
                                switch result {
                                case .success(let recipe):
                                    // Validate that we got critical data
                                    // Only retry if ingredients are missing (most critical) or servings is invalid
                                    let hasIngredients = !recipe.ingredients.isEmpty
                                    let hasValidServings = recipe.servings > 0 && recipe.servings <= 50
                                    
                                    if !hasIngredients || !hasValidServings {
                                        print("⚠️ SE/RecipeBrowserService: Print page extraction incomplete (servings: \(recipe.servings), ingredients: \(recipe.ingredients.count)), trying Jump To Recipe")
                                        // Retry with Jump To Recipe
                                        self.tryJumpToRecipe(html: html, baseURL: url, originalURL: url, completion: completion)
                                    } else {
                                        // Success - use print page result
                                        completion(result)
                                    }
                                case .fallbackHostname, .fallbackMeta:
                                    // Print page failed completely, try Jump To Recipe
                                    print("⚠️ SE/RecipeBrowserService: Print page extraction failed, trying Jump To Recipe")
                                    self.tryJumpToRecipe(html: html, baseURL: url, originalURL: url, completion: completion)
                                }
                            })
                        case .failure(let printError):
                            print("⚠️ SE/RecipeBrowserService: Print page fetch failed: \(printError.localizedDescription), trying Jump To Recipe")
                            // Priority 2: Fallback to Jump To Recipe
                            self.tryJumpToRecipe(html: html, baseURL: url, originalURL: url, completion: completion)
                        }
                    }
                } else {
                    // Priority 2: Try Jump To Recipe (if no print page)
                    print("ℹ️ SE/RecipeBrowserService: No print page found, trying Jump To Recipe")
                    self.tryJumpToRecipe(html: html, baseURL: url, originalURL: url, completion: completion)
                }
            case .failure(let error):
                print("SE/NET: html-fetch error=\(error.localizedDescription)")
                // Try to extract basic metadata from URL for fallback
                self.extractBasicMetadataFromURL(url, completion: completion)
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
    
    // MARK: - Print Recipe Page Detection & Fetching
    
    /// Validates if a URL is actually a recipe print page (not an asset file)
    private func isValidPrintPageURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        
        // Reject non-HTML file extensions
        let nonHTMLExtensions = [".svg", ".css", ".js", ".png", ".jpg", ".jpeg", ".gif", ".ico", ".webp", ".woff", ".woff2", ".ttf", ".eot", ".json", ".xml"]
        for ext in nonHTMLExtensions {
            if path.hasSuffix(ext) {
                print("⚠️ SE/RecipeBrowserService: Rejected non-HTML file: \(url.absoluteString)")
                return false
            }
        }
        
        // Reject URLs in asset/static directories (unless they're actual print pages)
        let assetPaths = ["/static/", "/assets/", "/icons/", "/images/", "/img/", "/css/", "/js/", "/fonts/"]
        for assetPath in assetPaths {
            if path.contains(assetPath) && !path.contains("/print") {
                print("⚠️ SE/RecipeBrowserService: Rejected asset directory URL: \(url.absoluteString)")
                return false
            }
        }
        
        // Reject URLs that are just fragments (like #print in SVG sprites)
        if url.fragment != nil && path.isEmpty {
            print("⚠️ SE/RecipeBrowserService: Rejected fragment-only URL: \(url.absoluteString)")
            return false
        }
        
        // Accept URLs that contain /print/ in the path (most reliable indicator)
        if path.contains("/print") {
            return true
        }
        
        // Accept WordPress Recipe Maker print URLs
        if path.contains("/wprm_print/") {
            return true
        }
        
        // Accept URLs that end with /print or /print-recipe
        if path.hasSuffix("/print") || path.hasSuffix("/print-recipe") {
            return true
        }
        
        // Reject everything else (too risky)
        print("⚠️ SE/RecipeBrowserService: Rejected - doesn't match print page pattern: \(url.absoluteString)")
        return false
    }
    
    /// Detects print recipe page URL from HTML content
    /// Searches for common print link patterns and returns absolute URL if found
    private func detectPrintRecipeURL(in html: String, baseURL: URL) -> URL? {
        print("🔍 SE/RecipeBrowserService: Detecting print recipe URL...")
        
        // Pattern 1: href with print in path (case-insensitive)
        // Matches: <a href="/print/">, <a href="?print=true">, <a href="/recipe/123/print/">
        let hrefPattern = #"href=["']([^"']*print[^"']*)["']"#
        if let regex = try? NSRegularExpression(pattern: hrefPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let hrefRange = Range(match.range(at: 1), in: html)!
            var printPath = String(html[hrefRange])
            
            // Clean up the path (remove query params if it's a print parameter)
            if printPath.contains("?print=") || printPath.contains("&print=") {
                // This is a query parameter, not a path - skip it
            } else {
                // Resolve relative URL
                if let printURL = URL(string: printPath, relativeTo: baseURL), isValidPrintPageURL(printURL) {
                    print("✅ SE/RecipeBrowserService: Found print URL via href: \(printURL.absoluteString)")
                    return printURL
                }
            }
        }
        
        // Pattern 2: data-print-url attribute
        // Matches: <button data-print-url="/print/">Print</button>
        let dataPrintPattern = #"data-print-url=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: dataPrintPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let urlRange = Range(match.range(at: 1), in: html)!
            let printPath = String(html[urlRange])
            if let printURL = URL(string: printPath, relativeTo: baseURL), isValidPrintPageURL(printURL) {
                print("✅ SE/RecipeBrowserService: Found print URL via data-print-url: \(printURL.absoluteString)")
                return printURL
            }
        }
        
        // Pattern 3: link rel="alternate" media="print"
        // Matches: <link rel="alternate" media="print" href="/print/">
        let linkPattern = #"<link[^>]*rel=["']alternate["'][^>]*media=["']print["'][^>]*href=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let hrefRange = Range(match.range(at: 1), in: html)!
            let printPath = String(html[hrefRange])
            if let printURL = URL(string: printPath, relativeTo: baseURL), isValidPrintPageURL(printURL) {
                print("✅ SE/RecipeBrowserService: Found print URL via link rel: \(printURL.absoluteString)")
                return printURL
            }
        }
        
        // Pattern 4: Common print URL patterns in href (more specific)
        // Check for /print/, /print-recipe/, /recipe/{id}/print/ patterns
        let specificPattern = #"href=["']([^"']*(?:/print[/?]|/print-recipe[/?]|/recipe/[^/]+/print[/?]))"#
        if let regex = try? NSRegularExpression(pattern: specificPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let hrefRange = Range(match.range(at: 1), in: html)!
            var printPath = String(html[hrefRange])
            // Remove trailing ? if present
            if printPath.hasSuffix("?") {
                printPath = String(printPath.dropLast())
            }
            if let printURL = URL(string: printPath, relativeTo: baseURL), isValidPrintPageURL(printURL) {
                print("✅ SE/RecipeBrowserService: Found print URL via specific pattern: \(printURL.absoluteString)")
                return printURL
            }
        }
        
        print("⚠️ SE/RecipeBrowserService: No print recipe URL found")
        return nil
    }
    
    // MARK: - Jump To Recipe Detection & Fetching
    
    /// Detects "Jump To Recipe" link/button and returns either a URL or anchor ID
    /// Returns tuple: (url: URL?, anchorId: String?)
    private func detectJumpToRecipe(in html: String, baseURL: URL) -> (url: URL?, anchorId: String?) {
        print("🔍 SE/RecipeBrowserService: Detecting Jump To Recipe link...")
        
        // Pattern 1: Anchor links with common recipe anchor IDs
        // Matches: <a href="#recipe">, <a href="#recipe-card">, <a href="#jump-to-recipe">
        let anchorPattern = #"href=["']#([^"']*(?:recipe|jump|skip)[^"']*)["']"#
        if let regex = try? NSRegularExpression(pattern: anchorPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let anchorRange = Range(match.range(at: 1), in: html)!
            let anchorId = String(html[anchorRange])
            print("✅ SE/RecipeBrowserService: Found Jump To Recipe anchor: #\(anchorId)")
            return (nil, anchorId)
        }
        
        // Pattern 2: Links with "jump to recipe" or "skip to recipe" text
        // Matches: <a href="/recipe">Jump to Recipe</a>
        let jumpTextPattern = #"<a[^>]*href=["']([^"']+)["'][^>]*>(?:[^<]*jump[^<]*to[^<]*recipe|skip[^<]*to[^<]*recipe)[^<]*</a>"#
        if let regex = try? NSRegularExpression(pattern: jumpTextPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let hrefRange = Range(match.range(at: 1), in: html)!
            let hrefPath = String(html[hrefRange])
            if let jumpURL = URL(string: hrefPath, relativeTo: baseURL) {
                print("✅ SE/RecipeBrowserService: Found Jump To Recipe URL via text: \(jumpURL.absoluteString)")
                return (jumpURL, nil)
            }
        }
        
        // Pattern 3: Data attributes for jump to recipe
        // Matches: <button data-jump-to-recipe="#recipe">Jump</button>
        let dataJumpPattern = #"data-jump-to-recipe=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: dataJumpPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let dataRange = Range(match.range(at: 1), in: html)!
            let dataValue = String(html[dataRange])
            if dataValue.hasPrefix("#") {
                let anchorId = String(dataValue.dropFirst())
                print("✅ SE/RecipeBrowserService: Found Jump To Recipe anchor via data attribute: #\(anchorId)")
                return (nil, anchorId)
            } else if let jumpURL = URL(string: dataValue, relativeTo: baseURL) {
                print("✅ SE/RecipeBrowserService: Found Jump To Recipe URL via data attribute: \(jumpURL.absoluteString)")
                return (jumpURL, nil)
            }
        }
        
        // Pattern 4: Common recipe section IDs/classes in the HTML
        // Look for elements with id or class containing "recipe" that might be the target
        let recipeSectionPattern = #"<[^>]*(?:id|class)=["']([^"']*(?:recipe-card|recipe-content|recipe-section|recipe-body)[^"']*)["']"#
        if let regex = try? NSRegularExpression(pattern: recipeSectionPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let sectionRange = Range(match.range(at: 1), in: html)!
            let sectionId = String(html[sectionRange])
            // Extract just the ID part if it's a class with multiple values
            let cleanId = sectionId.components(separatedBy: " ").first { $0.contains("recipe") } ?? sectionId
            print("✅ SE/RecipeBrowserService: Found recipe section ID: \(cleanId)")
            return (nil, cleanId)
        }
        
        // Pattern 5: Buttons with recipe-related classes/IDs
        // Matches: <button class="jump-to-recipe">, <button id="recipe-button">
        let buttonPattern = #"<button[^>]*(?:class|id)=["']([^"']*(?:recipe|jump|skip)[^"']*)["'][^>]*>"#
        if let regex = try? NSRegularExpression(pattern: buttonPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let buttonRange = Range(match.range(at: 1), in: html)!
            let buttonId = String(html[buttonRange])
            // Check if it has a data attribute pointing to an anchor
            let dataAttrPattern = #"data-[^=]*=["']#([^"']+)"#
            if let dataRegex = try? NSRegularExpression(pattern: dataAttrPattern, options: [.caseInsensitive]),
               let dataMatch = dataRegex.firstMatch(in: html, options: [], range: match.range),
               dataMatch.numberOfRanges > 1 {
                let anchorRange = Range(dataMatch.range(at: 1), in: html)!
                let anchorId = String(html[anchorRange])
                print("✅ SE/RecipeBrowserService: Found Jump To Recipe anchor via button data attribute: #\(anchorId)")
                return (nil, anchorId)
            }
        }
        
        // Pattern 6: Data attributes for recipe sections
        // Matches: <div data-recipe-section="#recipe">, <section data-recipe-content>
        let dataRecipePattern = #"data-recipe[^=]*=["']#?([^"']+)"#
        if let regex = try? NSRegularExpression(pattern: dataRecipePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let dataRange = Range(match.range(at: 1), in: html)!
            let dataValue = String(html[dataRange])
            if dataValue.hasPrefix("#") {
                let anchorId = String(dataValue.dropFirst())
                print("✅ SE/RecipeBrowserService: Found recipe section via data-recipe attribute: #\(anchorId)")
                return (nil, anchorId)
            } else {
                // Could be a URL
                if let jumpURL = URL(string: dataValue, relativeTo: baseURL) {
                    print("✅ SE/RecipeBrowserService: Found recipe URL via data-recipe attribute: \(jumpURL.absoluteString)")
                    return (jumpURL, nil)
                }
            }
        }
        
        // Pattern 7: Common recipe anchor IDs (direct search)
        // Matches: id="recipe", id="recipe-content", id="recipe-card"
        let commonAnchors = ["recipe", "recipe-content", "recipe-card", "recipe-section", "recipe-body", "recipe-main", "main-recipe", "jump-to-recipe", "skip-to-recipe"]
        for anchorId in commonAnchors {
            let anchorPattern = #"id=["']\(NSRegularExpression.escapedPattern(for: anchorId))["']"#
            if let regex = try? NSRegularExpression(pattern: anchorPattern, options: [.caseInsensitive]),
               regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)) != nil {
                print("✅ SE/RecipeBrowserService: Found common recipe anchor ID: #\(anchorId)")
                return (nil, anchorId)
            }
        }
        
        print("⚠️ SE/RecipeBrowserService: No Jump To Recipe link found")
        return (nil, nil)
    }
    
    /// Extracts HTML section by anchor ID from the main HTML
    private func extractSectionByAnchor(anchorId: String, from html: String) -> String? {
        print("🔍 SE/RecipeBrowserService: Extracting section with anchor ID: \(anchorId)")
        
        // Escape special regex characters in anchorId
        let escapedAnchorId = NSRegularExpression.escapedPattern(for: anchorId)
        
        // Pattern to find element with matching id and extract its content
        let idPattern = "<[^>]*id=[\"']\(escapedAnchorId)[\"'][^>]*>([\\s\\S]*?)(?=</[^>]+>|$)"
        
        if let regex = try? NSRegularExpression(pattern: idPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let contentRange = Range(match.range(at: 1), in: html)!
            let sectionHTML = String(html[contentRange])
            print("✅ SE/RecipeBrowserService: Extracted section HTML (length: \(sectionHTML.count))")
            return sectionHTML
        }
        
        // Fallback: try to find the element and extract its entire subtree
        // Look for opening tag, then find matching closing tag
        let elementStartPattern = "<[^>]*id=[\"']\(escapedAnchorId)[\"'][^>]*>"
        if let startRegex = try? NSRegularExpression(pattern: elementStartPattern, options: [.caseInsensitive]),
           let startMatch = startRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)) {
            
            let startIndex = startMatch.range.location + startMatch.range.length
            let remainingHTML = String(html[html.index(html.startIndex, offsetBy: startIndex)...])
            
            // Try to find the matching closing tag (simplified - assumes same tag name)
            // For now, just extract a reasonable chunk (up to 50KB or next major section)
            let maxLength = min(50000, remainingHTML.count)
            let sectionHTML = String(remainingHTML.prefix(maxLength))
            print("✅ SE/RecipeBrowserService: Extracted section HTML from start tag (length: \(sectionHTML.count))")
            return sectionHTML
        }
        
        print("⚠️ SE/RecipeBrowserService: Could not extract section with anchor ID: \(anchorId)")
        return nil
    }
    
    /// Fetches HTML from print recipe page
    /// Uses same configuration as fetchHTML but specifically for print pages
    private func fetchPrintPageHTML(from url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        print("🖨️ SE/RecipeBrowserService: Fetching print page HTML from \(url.absoluteString)")
        
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
                print("⚠️ SE/RecipeBrowserService: Print page fetch error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ SE/RecipeBrowserService: Print page invalid response")
                completion(.failure(NSError(domain: "InvalidResponse", code: -1, userInfo: nil)))
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                print("⚠️ SE/RecipeBrowserService: Print page no data")
                completion(.failure(NSError(domain: "NoData", code: -1, userInfo: nil)))
                return
            }
            
            print("✅ SE/RecipeBrowserService: Print page fetched successfully - status=\(httpResponse.statusCode) bytes=\(data.count)")
            completion(.success(html))
        }.resume()
    }
    
    /// Helper function to try Jump To Recipe extraction
    /// fullHTML: The complete page HTML (for image extraction from meta tags)
    /// html: The HTML to send to Lambda (may be a section or full page)
    private func tryJumpToRecipe(html: String, baseURL: URL, originalURL: URL, completion: @escaping (RecipeExtractionResult) -> Void) {
        let jumpResult = detectJumpToRecipe(in: html, baseURL: baseURL)
        let fullHTML = html  // Store full HTML for image extraction
        
        if let jumpURL = jumpResult.url {
            // Jump To Recipe points to a separate URL - fetch it
            print("🔗 SE/RecipeBrowserService: Jump To Recipe URL detected, fetching...")
            fetchHTML(from: jumpURL) { htmlResult in
                switch htmlResult {
                case .success(let jumpHTML):
                    print("✅ SE/RecipeBrowserService: Using Jump To Recipe HTML (length: \(jumpHTML.count))")
                    // Use jumpHTML for both Lambda and image extraction (it's a full page)
                    self.sendToLambdaWithHTML(url: originalURL.absoluteString, html: jumpHTML, htmlSource: "jump-to-recipe", fullHTMLForImageExtraction: jumpHTML, completion: completion)
                case .failure(let jumpError):
                    print("⚠️ SE/RecipeBrowserService: Jump To Recipe fetch failed: \(jumpError.localizedDescription), falling back to main HTML")
                    // Fallback to main HTML
                    self.sendToLambdaWithHTML(url: originalURL.absoluteString, html: html, htmlSource: "main", fullHTMLForImageExtraction: fullHTML, completion: completion)
                }
            }
        } else if let anchorId = jumpResult.anchorId {
            // Jump To Recipe points to an anchor - extract that section
            if let sectionHTML = extractSectionByAnchor(anchorId: anchorId, from: html) {
                print("✅ SE/RecipeBrowserService: Using Jump To Recipe section HTML (length: \(sectionHTML.count))")
                
                // Validate extracted HTML size before sending
                if sectionHTML.count < 1000 || (sectionHTML.count < 2000 && (sectionHTML.contains("icon") || sectionHTML.contains("button") || sectionHTML.contains("<svg"))) {
                    print("⚠️ SE/RecipeBrowserService: Extracted section HTML too small (\(sectionHTML.count) bytes) or invalid, falling back to main HTML")
                    self.sendToLambdaWithHTML(url: originalURL.absoluteString, html: html, htmlSource: "main", fullHTMLForImageExtraction: fullHTML, completion: completion)
                    return
                }
                
                // Send section HTML to Lambda, but use full HTML for image extraction (has meta tags)
                self.sendToLambdaWithHTML(url: originalURL.absoluteString, html: sectionHTML, htmlSource: "jump-to-recipe-section", fullHTMLForImageExtraction: fullHTML, completion: completion)
            } else {
                print("⚠️ SE/RecipeBrowserService: Could not extract Jump To Recipe section, falling back to main HTML")
                // Fallback to main HTML
                self.sendToLambdaWithHTML(url: originalURL.absoluteString, html: html, htmlSource: "main", fullHTMLForImageExtraction: fullHTML, completion: completion)
            }
        } else {
            // No Jump To Recipe found, use main HTML
            print("ℹ️ SE/RecipeBrowserService: No Jump To Recipe found, using main HTML")
            self.sendToLambdaWithHTML(url: originalURL.absoluteString, html: html, htmlSource: "main", fullHTMLForImageExtraction: fullHTML, completion: completion)
        }
    }
    
    // MARK: - Lambda Communication
    
    private func sendToLambdaWithHTML(url: String, html: String, htmlSource: String = "main", fullHTMLForImageExtraction: String? = nil, completion: @escaping (RecipeExtractionResult) -> Void) {
        print("SE/NET: supabase-post start payload={url:\(url), html_len:\(html.count), source:\(htmlSource)}")
        print("SE/NET: supabase-url=\(SUPABASE_URL)")
        print("SE/NET: supabase-key-length=\(SUPABASE_ANON_KEY.count)")
        
        guard let supabaseURL = URL(string: SUPABASE_URL) else {
            print("SE/NET: supabase error=invalid-url")
            completion(.fallbackHostname(hostname: URL(string: url)?.host ?? "Unknown Site"))
            return
        }
        
        // Prepare payload with both URL and HTML, plus source for logging
        let payload: [String: Any] = [
            "url": url,
            "html": html,
            "html_source": htmlSource  // For Lambda logging: "print", "jump-to-recipe", "jump-to-recipe-section", or "main"
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
            
            // Parse Lambda response (pass htmlSource and fullHTML for image extraction)
            // Use fullHTMLForImageExtraction if provided (has meta tags), otherwise use html
            let htmlForImageExtraction = fullHTMLForImageExtraction ?? html
            self.parseLambdaResponse(data: data, url: url, htmlSource: htmlSource, html: htmlForImageExtraction, completion: completion)
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
            
            // Parse Lambda response (URL-only, no HTML source) - use ImportedRecipe? overload
            let importedRecipeCompletion: (ImportedRecipe?) -> Void = completion
            self.parseLambdaResponse(data: data, url: url, htmlSource: "url-only", html: nil, completion: importedRecipeCompletion)
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
    
    private func parseLambdaResponse(data: Data, url: String, htmlSource: String = "unknown", html: String? = nil, completion: @escaping (RecipeExtractionResult) -> Void) {
        print("🔍 SE/NET: [METHOD 1] parseLambdaResponse(RecipeExtractionResult) called - data size: \(data.count) bytes, htmlSource: \(htmlSource)")
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
            let yieldsRaw = json["yields"]
            print("🍽️ Lambda returned servings (raw): \(servingsRaw ?? "nil")")
            print("🍽️ Lambda returned yields (raw): \(yieldsRaw ?? "nil")")
            
            // Use htmlSource passed from client (Lambda doesn't return it)
            
            // Enhanced servings parsing - handles ranges, text, yields
            var servings: Int = 4  // Default to 4 (more common than 1)
            var yieldDescription: String? = nil
            var servingsSource = "default"
            
            // First, try to parse from servings field
            if let servingsInt = json["servings"] as? Int {
                servings = servingsInt
                servingsSource = "servings_field_int"
            } else if let servingsStr = json["servings"] as? String, !servingsStr.isEmpty {
                let parsed = parseServings(from: servingsStr)
                if parsed > 0 {
                    servings = parsed
                    servingsSource = "servings_field_string"
                }
            }
            
            // If servings is still default or invalid, try yields field
            if servings <= 0 || servings == 4 {
                if let yieldsStr = json["yields"] as? String, !yieldsStr.isEmpty {
                    let parsed = parseServings(from: yieldsStr)
                    if parsed > 0 {
                        servings = parsed
                        servingsSource = "yields_field"
                        // If yields contains descriptive text, save it
                        if yieldsStr.lowercased().contains("makes") || yieldsStr.lowercased().contains("cookies") || yieldsStr.lowercased().contains("pizzas") {
                            yieldDescription = yieldsStr
                        }
                    }
                }
            }
            
            // Final fallback: Extract servings directly from HTML if Lambda failed
            if (servings <= 0 || servings == 4) && servingsSource == "default", let htmlString = html {
                let extractedServings = extractServingsFromHTML(htmlString)
                if extractedServings > 0 {
                    servings = extractedServings
                    servingsSource = "html_fallback"
                    print("✅ SERVINGS FALLBACK: Extracted servings \(servings) directly from HTML")
                }
            }
            
            // Servings validation checkpoint
            print("🍽️ SERVINGS VALIDATION:")
            print("   HTML Source: \(htmlSource)")
            print("   Parsed servings: \(servings)")
            print("   Servings source: \(servingsSource)")
            print("   Raw servings value: \(servingsRaw ?? "nil")")
            print("   Raw yields value: \(yieldsRaw ?? "nil")")
            
            // Warn if servings seem suspicious
            if servings < 1 {
                print("⚠️ SERVINGS WARNING: Servings is less than 1 - may cause calculation errors")
            } else if servings > 50 {
                print("⚠️ SERVINGS WARNING: Servings is greater than 50 - may be incorrect")
            } else if servings == 4 && servingsSource == "default" {
                print("⚠️ SERVINGS WARNING: Using default value of 4 - servings may not have been parsed correctly")
            } else {
                print("✅ SERVINGS VALIDATION: Servings value appears valid")
            }
            
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
                
                // Fix missing "1" prefix for ingredients starting with unit words
                if !cleaned.isEmpty {
                    cleaned = addMissingOnePrefix(to: cleaned)
                }
                
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
            
            // Handle cook time - Lambda can return as Int (cook_time_minutes) or Int/String (cook_time)
            var cookTimeMinutes: Int? = nil
            if let cookTimeInt = json["cook_time_minutes"] as? Int {
                cookTimeMinutes = cookTimeInt
            } else if let cookTimeInt = json["cook_time"] as? Int {
                cookTimeMinutes = cookTimeInt
            } else if let cookTimeStr = json["cook_time"] as? String, !cookTimeStr.isEmpty {
                let parsed = parseTimeToMinutes(cookTimeStr)
                cookTimeMinutes = parsed > 0 ? parsed : nil
            }
            
            // Handle total time - Lambda can return as Int (total_time_minutes) or Int/String (total_time)
            var totalTimeMinutes: Int? = nil
            if let totalTimeInt = json["total_time_minutes"] as? Int {
                totalTimeMinutes = totalTimeInt
            } else if let totalTimeInt = json["total_time"] as? Int {
                totalTimeMinutes = totalTimeInt
            } else if let totalTimeStr = json["total_time"] as? String, !totalTimeStr.isEmpty {
                let parsed = parseTimeToMinutes(totalTimeStr)
                totalTimeMinutes = parsed > 0 ? parsed : nil
            }
            
            // If total time not available, calculate from prep + cook
            if totalTimeMinutes == nil && prepTimeMinutes > 0 {
                if let cookTime = cookTimeMinutes {
                    totalTimeMinutes = prepTimeMinutes + cookTime
                } else {
                    totalTimeMinutes = prepTimeMinutes
                }
            }
            
            // Handle image URL - check both possible field names
            var imageUrl = (json["image_url"] as? String) ?? (json["image"] as? String)
            
            // Log what Lambda returned for image
            if let lambdaImageUrl = imageUrl, !lambdaImageUrl.isEmpty {
                print("🖼️ SE/NET: Lambda returned image URL: \(lambdaImageUrl)")
            } else {
                print("⚠️ SE/NET: Lambda returned no image URL (nil or empty)")
            }
            
            // Always try HTML extraction as backup/validation
            // HTML meta tags (og:image, etc.) are often more reliable than Lambda's extraction
            if let htmlContent = html {
                if let htmlImageUrl = extractImageFromHTML(htmlContent, baseURL: url) {
                    // If Lambda didn't provide an image, use HTML extraction
                    if imageUrl == nil || imageUrl?.isEmpty == true || imageUrl == "N/A" {
                        imageUrl = htmlImageUrl
                        print("✅ SE/NET: Using HTML-extracted image (Lambda had none): \(htmlImageUrl)")
                    } else {
                        // Lambda provided an image, but HTML extraction found a different one
                        // Prefer HTML extraction as it's often more reliable (og:image, etc.)
                        let lambdaImageUrl = imageUrl  // Store Lambda's URL for logging
                        imageUrl = htmlImageUrl
                        print("✅ SE/NET: Using HTML-extracted image (preferred over Lambda): \(htmlImageUrl)")
                        print("ℹ️ SE/NET: Lambda's image URL was: \(lambdaImageUrl ?? "nil")")
                    }
                } else {
                    // HTML extraction failed, use Lambda's if available
                    if imageUrl == nil || imageUrl?.isEmpty == true || imageUrl == "N/A" {
                        print("⚠️ SE/NET: Both Lambda and HTML extraction failed to find image")
                    } else {
                        print("ℹ️ SE/NET: Using Lambda's image URL (HTML extraction found none): \(imageUrl ?? "nil")")
                    }
                }
            }
            
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
            
            // Parse difficulty from Lambda response (if available)
            let difficulty = json["difficulty"] as? String
            
            // Create ImportedRecipe with mapped fields
            let recipe = ImportedRecipe(
                title: title,
                sourceUrl: sourceUrl,
                ingredients: ingredients,
                instructions: instructions,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                cookTimeMinutes: cookTimeMinutes,
                totalTimeMinutes: totalTimeMinutes,
                difficulty: difficulty,
                yieldDescription: yieldDescription,
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
    
    private func parseLambdaResponse(data: Data, url: String, htmlSource: String = "unknown", html: String? = nil, completion: @escaping (ImportedRecipe?) -> Void) {
        print("🔍 SE/NET: [METHOD 2] parseLambdaResponse(ImportedRecipe?) called - data size: \(data.count) bytes, htmlSource: \(htmlSource)")
        // Use the existing parseLambdaResponse that properly handles nutrition (explicitly use RecipeExtractionResult overload)
        let recipeExtractionCompletion: (RecipeExtractionResult) -> Void = { result in
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
        self.parseLambdaResponse(data: data, url: url, htmlSource: htmlSource, html: html, completion: recipeExtractionCompletion)
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
    // Handles multiple formats: "15 minutes", "1 hour 30 minutes", "1h 30m", "1.5 hours", "PT1H30M"
    private func parseTimeToMinutes(_ timeStr: String) -> Int {
        let lowercased = timeStr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle ISO 8601 duration format: PT1H30M, PT45M, etc.
        if lowercased.hasPrefix("pt") {
            var hours = 0
            var minutes = 0
            
            // Extract hours: PT1H30M -> 1
            if let hourRange = lowercased.range(of: #"(\d+)h"#, options: .regularExpression) {
                let hourStr = String(lowercased[hourRange])
                if let hourValue = Int(hourStr.replacingOccurrences(of: "h", with: "", options: .caseInsensitive)) {
                    hours = hourValue
                }
            }
            
            // Extract minutes: PT1H30M -> 30
            if let minRange = lowercased.range(of: #"(\d+)m"#, options: .regularExpression) {
                let minStr = String(lowercased[minRange])
                if let minValue = Int(minStr.replacingOccurrences(of: "m", with: "", options: .caseInsensitive)) {
                    minutes = minValue
                }
            }
            
            return hours * 60 + minutes
        }
        
        // Handle formats with both hours and minutes: "1 hour 30 minutes", "1h 30m", "2 hrs 15 mins"
        let hoursMinutesPattern = #"(\d+(?:\.\d+)?)\s*(?:hour|hr|hrs|h)(?:\s+(\d+)\s*(?:minute|min|mins|m))?"#
        if let regex = try? NSRegularExpression(pattern: hoursMinutesPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.utf16.count)),
           match.numberOfRanges > 1 {
            
            // Extract hours (may be decimal)
            let hoursRange = Range(match.range(at: 1), in: lowercased)!
            let hoursStr = String(lowercased[hoursRange])
            let hours = Double(hoursStr) ?? 0
            
            // Extract minutes if present
            var minutes = 0
            if match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound {
                let minutesRange = Range(match.range(at: 2), in: lowercased)!
                let minutesStr = String(lowercased[minutesRange])
                minutes = Int(minutesStr) ?? 0
            }
            
            return Int(hours * 60) + minutes
        }
        
        // Handle formats with only minutes: "15 minutes", "90 min", "45 mins"
        let minutesPattern = #"(\d+)\s*(?:minute|min|mins|m)"#
        if let regex = try? NSRegularExpression(pattern: minutesPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.utf16.count)),
           match.numberOfRanges > 1 {
            let minutesRange = Range(match.range(at: 1), in: lowercased)!
            let minutesStr = String(lowercased[minutesRange])
            return Int(minutesStr) ?? 0
        }
        
        // Handle formats with only hours: "2 hours", "1.5 hrs", "3h"
        let hoursPattern = #"(\d+(?:\.\d+)?)\s*(?:hour|hr|hrs|h)"#
        if let regex = try? NSRegularExpression(pattern: hoursPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.utf16.count)),
           match.numberOfRanges > 1 {
            let hoursRange = Range(match.range(at: 1), in: lowercased)!
            let hoursStr = String(lowercased[hoursRange])
            let hours = Double(hoursStr) ?? 0
            return Int(hours * 60)
        }
        
        // Fallback: extract any number and assume minutes if no unit found
        let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let value = Int(numbers), value > 0 {
            return value
        }
        
        return 0
    }
    
    // Helper function to parse servings from text
    // Handles formats: "Serves 4", "Serves 4-6", "Makes 12 cookies", "Yield: 8", "4 servings"
    private func parseServings(from text: String) -> Int {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Pattern to match: (serves|makes|yield|servings)[:\s]*(\d+)(?:-(\d+))?
        // Handles: "Serves 4", "Serves 4-6", "Makes 12 cookies", "Yield: 8", "4 servings"
        let pattern = #"(?i)(serves|makes|yield|servings)[:\s]*(\d+)(?:-(\d+))?"#
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(location: 0, length: lowercased.utf16.count)),
           match.numberOfRanges > 2 {
            
            // Extract first number (lower bound)
            let firstNumberRange = Range(match.range(at: 2), in: lowercased)!
            let firstNumberStr = String(lowercased[firstNumberRange])
            guard let firstNumber = Int(firstNumberStr) else { return 0 }
            
            // If there's a range (e.g., "4-6"), extract second number
            if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                let secondNumberRange = Range(match.range(at: 3), in: lowercased)!
                let secondNumberStr = String(lowercased[secondNumberRange])
                if let secondNumber = Int(secondNumberStr) {
                    // Use lower bound (more conservative)
                    // Could also use average: (firstNumber + secondNumber) / 2
                    return firstNumber
                }
            }
            
            return firstNumber
        }
        
        // Fallback: extract any number from the text
        let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let value = Int(numbers), value > 0 {
            return value
        }
        
        return 0
    }
    
    /// Extracts servings directly from HTML using multiple patterns
    /// This is used as a fallback when Lambda fails to extract servings
    /// Extracts image URL from HTML meta tags (fallback when Lambda doesn't provide one)
    /// Checks og:image, twitter:image, schema.org image, and other common meta tags
    private func extractImageFromHTML(_ html: String, baseURL: String) -> String? {
        // Pattern 1: Open Graph image (most common)
        // Matches: <meta property="og:image" content="https://example.com/image.jpg">
        let ogImagePattern = #"<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: ogImagePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let contentRange = Range(match.range(at: 1), in: html)!
            var imageUrl = String(html[contentRange])
            // Resolve relative URLs
            if imageUrl.hasPrefix("//") {
                imageUrl = "https:" + imageUrl
            } else if !imageUrl.hasPrefix("http") {
                if let base = URL(string: baseURL), let resolved = URL(string: imageUrl, relativeTo: base) {
                    imageUrl = resolved.absoluteString
                }
            }
            if !imageUrl.isEmpty && imageUrl.hasPrefix("http") {
                return imageUrl
            }
        }
        
        // Pattern 2: Twitter Card image
        // Matches: <meta name="twitter:image" content="https://example.com/image.jpg">
        let twitterImagePattern = #"<meta[^>]*name=["']twitter:image["'][^>]*content=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: twitterImagePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let contentRange = Range(match.range(at: 1), in: html)!
            var imageUrl = String(html[contentRange])
            if imageUrl.hasPrefix("//") {
                imageUrl = "https:" + imageUrl
            } else if !imageUrl.hasPrefix("http") {
                if let base = URL(string: baseURL), let resolved = URL(string: imageUrl, relativeTo: base) {
                    imageUrl = resolved.absoluteString
                }
            }
            if !imageUrl.isEmpty && imageUrl.hasPrefix("http") {
                return imageUrl
            }
        }
        
        // Pattern 3: Schema.org image in JSON-LD
        // Matches: "image": "https://example.com/image.jpg" or "image": {"@type": "ImageObject", "url": "..."}
        let schemaImagePattern = #""image"\s*:\s*"([^"]+)"#
        if let regex = try? NSRegularExpression(pattern: schemaImagePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let urlRange = Range(match.range(at: 1), in: html)!
            var imageUrl = String(html[urlRange])
            if imageUrl.hasPrefix("//") {
                imageUrl = "https:" + imageUrl
            } else if !imageUrl.hasPrefix("http") {
                if let base = URL(string: baseURL), let resolved = URL(string: imageUrl, relativeTo: base) {
                    imageUrl = resolved.absoluteString
                }
            }
            if !imageUrl.isEmpty && imageUrl.hasPrefix("http") {
                return imageUrl
            }
        }
        
        // Pattern 4: Generic meta image tag
        // Matches: <meta name="image" content="https://example.com/image.jpg">
        let metaImagePattern = #"<meta[^>]*name=["']image["'][^>]*content=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: metaImagePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           match.numberOfRanges > 1 {
            let contentRange = Range(match.range(at: 1), in: html)!
            var imageUrl = String(html[contentRange])
            if imageUrl.hasPrefix("//") {
                imageUrl = "https:" + imageUrl
            } else if !imageUrl.hasPrefix("http") {
                if let base = URL(string: baseURL), let resolved = URL(string: imageUrl, relativeTo: base) {
                    imageUrl = resolved.absoluteString
                }
            }
            if !imageUrl.isEmpty && imageUrl.hasPrefix("http") {
                return imageUrl
            }
        }
        
        return nil
    }
    
    private func extractServingsFromHTML(_ html: String) -> Int {
        print("🔍 SE/RecipeBrowserService: Extracting servings from HTML (fallback)...")
        
        // Pattern 1: Look for structured data (JSON-LD, microdata)
        // Try to find recipe schema with servings/yield
        let schemaPatterns = [
            "(?i)\"servings\"[:\\s]*(\\d+)",
            "(?i)\"yield\"[:\\s]*\"?(\\d+)\"?",
            "(?i)\"recipeYield\"[:\\s]*\"?(\\d+)\"?",
            "(?i)\"servingSize\"[:\\s]*\"?(\\d+)\"?",
        ]
        
        for pattern in schemaPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               match.numberOfRanges > 1 {
                let numberRange = Range(match.range(at: 1), in: html)!
                let numberStr = String(html[numberRange])
                if let servings = Int(numberStr), servings > 0 && servings <= 50 {
                    print("✅ SE/RecipeBrowserService: Found servings in structured data: \(servings)")
                    return servings
                }
            }
        }
        
        // Pattern 2: Look for common HTML patterns with servings
        // Matches: <span>Serves 4</span>, <div>Servings: 6</div>, <p>Makes 8 servings</p>
        let htmlPatterns = [
            #"(?i)<[^>]*>(?:serves|servings|makes|yield)[:\s]*(\d+)(?:[-\s](\d+))?"#,
            #"(?i)(?:serves|servings|makes|yield)[:\s]*(\d+)(?:[-\s](\d+))?\s*(?:servings|people|portions)?"#
        ]
        
        for pattern in htmlPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: min(html.utf16.count, 50000))), // Limit search to first 50KB
               match.numberOfRanges > 1 {
                let numberRange = Range(match.range(at: 1), in: html)!
                let numberStr = String(html[numberRange])
                if let servings = Int(numberStr), servings > 0 && servings <= 50 {
                    print("✅ SE/RecipeBrowserService: Found servings in HTML text: \(servings)")
                    return servings
                }
            }
        }
        
        // Pattern 3: Look for meta tags or data attributes
        let metaPatterns = [
            ##"(?i)<meta[^>]*(?:property|name|itemprop)=["'](?:servings|yield|recipeYield)["'][^>]*content=["'](\d+)"##,
            ##"(?i)data-servings=["'](\d+)"##,
            ##"(?i)data-yield=["'](\d+)"##
        ]
        
        for pattern in metaPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               match.numberOfRanges > 1 {
                let numberRange = Range(match.range(at: 1), in: html)!
                let numberStr = String(html[numberRange])
                if let servings = Int(numberStr), servings > 0 && servings <= 50 {
                    print("✅ SE/RecipeBrowserService: Found servings in meta/data attribute: \(servings)")
                    return servings
                }
            }
        }
        
        print("⚠️ SE/RecipeBrowserService: Could not extract servings from HTML")
        return 0
    }
    
    /// Adds "1 " prefix to ingredients that start with unit words but don't have a number
    private func addMissingOnePrefix(to ingredient: String) -> String {
        let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        // Check if ingredient already starts with a number or fraction
        let startsWithNumberPattern = #"^(\d+|\d+\s*/\s*\d+|\d+\.\d+)"#
        if let regex = try? NSRegularExpression(pattern: startsWithNumberPattern, options: []),
           regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
            // Already has a number, return as-is
            return trimmed
        }
        
        // List of unit words that should have "1" prefix if missing
        let unitWords = ["cup", "cups", "teaspoon", "teaspoons", "tablespoon", "tablespoons",
                        "ounce", "ounces", "pound", "pounds", "gram", "grams", "kilogram", "kilograms",
                        "liter", "liters", "quart", "quarts", "pint", "pints", "gallon", "gallons",
                        "milliliter", "milliliters", "pinch", "pinches", "dash", "dashes",
                        "can", "cans", "package", "packages", "bunch", "bunches",
                        "bag", "bags", "bottle", "bottles", "box", "boxes", "jar", "jars",
                        "head", "heads", "clove", "cloves", "stalk", "stalks", "sprig", "sprigs",
                        "strip", "strips", "stick", "sticks"]
        
        // Check if ingredient starts with a unit word
        for unit in unitWords {
            if lowercased.hasPrefix(unit) {
                // Found unit word at start without number, add "1 " prefix
                return "1 \(trimmed)"
            }
        }
        
        // No unit word found at start, return as-is
        return trimmed
    }
    
}
