//
//  RecipeBrowserService.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 9/19/25.
//

import Foundation
import WebKit

class RecipeBrowserService: NSObject, ObservableObject {
    private var webView: WKWebView!
    private var completion: ((ImportedRecipe?) -> Void)?
    private var timeoutTimer: Timer?
    
    override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        // Initialize WKWebView on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            
            // Configure for headless operation
            self.webView = WKWebView(frame: .zero, configuration: configuration)
            self.webView.navigationDelegate = self
            self.webView.isHidden = true // Hide the webview since it's headless
            
            // Add to a window to ensure it's retained (iOS 15+ compatible)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(self.webView)
                print("RecipeBrowserService: WKWebView initialized and added to window")
            } else {
                print("❌ RecipeBrowserService: Could not find window to add webView")
            }
        }
    }
    
    func extractRecipe(from url: URL, completion: @escaping (ImportedRecipe?) -> Void) {
        print("🌐 RecipeBrowserService: Starting extraction from \(url.absoluteString)")
        
        // Check if this is a YouTube URL
        if isYouTubeURL(url.absoluteString) {
            print("📺 RecipeBrowserService: YouTube URL detected, routing to YouTubeService")
            Task {
                do {
                    let recipe = try await YouTubeService.shared.extractRecipe(from: url.absoluteString)
                    await MainActor.run {
                        completion(recipe)
                    }
                } catch {
                    print("❌ RecipeBrowserService: YouTube extraction failed: \(error.localizedDescription)")
                    // Try AI fallback for YouTube
                    await attemptAIFallback(for: url.absoluteString, completion: completion)
                }
            }
            return
        }
        
        self.completion = completion
        
        // Ensure webView is initialized before proceeding
        if webView == nil {
            print("❌ RecipeBrowserService: WebView not ready, waiting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.extractRecipe(from: url, completion: completion)
            }
            return
        }
        
        print("✅ RecipeBrowserService: WebView is ready, proceeding with extraction")
        
        // Set up timeout
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            print("⏰ RecipeBrowserService: Timeout reached for \(url.absoluteString)")
            self?.completion?(nil)
            self?.completion = nil
        }
        
        // Load the URL
        let request = URLRequest(url: url)
        print("🌐 RecipeBrowserService: Loading URL: \(url.absoluteString)")
        webView.load(request)
    }
    
    // MARK: - YouTube Detection
    
    private func isYouTubeURL(_ urlString: String) -> Bool {
        return urlString.contains("youtube.com") || urlString.contains("youtu.be")
    }
    
    // MARK: - AI Fallback for YouTube
    
    private func attemptAIFallback(for urlString: String, completion: @escaping (ImportedRecipe?) -> Void) async {
        print("🤖 RecipeBrowserService: Attempting AI fallback for YouTube")
        // TODO: Implement AI fallback
        // For now, return nil - will be implemented in next phase
        await MainActor.run {
            completion(nil)
        }
    }
    
    private func executeExtractionScript() {
        // Extract raw HTML and send to Lambda for parsing
        let javascript = "document.documentElement.outerHTML"
        
        webView.evaluateJavaScript(javascript) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ RecipeBrowserService: JavaScript error: \(error)")
                    self?.completion?(nil)
                    self?.completion = nil
                } else if let html = result as? String {
                    print("✅ RecipeBrowserService: HTML captured successfully, length: \(html.count)")
                    // Send HTML to Lambda for parsing
                    self?.sendToLambda(html: html, url: self?.webView?.url?.absoluteString ?? "")
                } else {
                    print("❌ RecipeBrowserService: Unexpected JavaScript result type: \(type(of: result))")
                    self?.completion?(nil)
                    self?.completion = nil
                }
            }
        }
    }
    
    private func sendToLambda(html: String, url: String) {
        print("🚀 RecipeBrowserService: Starting Supabase Edge Function request (with caching)")
        print("🚀 RecipeBrowserService: URL: \(url)")
        print("🚀 RecipeBrowserService: HTML length: \(html.count)")
        
        // Use Supabase Edge Function instead of Lambda directly (enables caching)
        let supabaseURL = SupabaseConfig.extractRecipeURL
        
        // Prepare the request payload
        let payload: [String: Any] = [
            "url": url,
            "html": html
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("❌ RecipeBrowserService: Failed to serialize JSON payload")
            completion?(nil)
            completion = nil
            return
        }
        
        var request = URLRequest(url: supabaseURL)
        request.httpMethod = "POST"
        
        // Add Supabase authentication headers
        let headers = SupabaseConfig.authenticatedHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        request.httpBody = jsonData
        
        print("🚀 RecipeBrowserService: Sending request to Lambda...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ RecipeBrowserService: Lambda request error: \(error)")
                    self?.completion?(nil)
                    self?.completion = nil
                    return
                }
                
                guard let data = data else {
                    print("❌ RecipeBrowserService: No data received from Lambda")
                    self?.completion?(nil)
                    self?.completion = nil
                    return
                }
                
                print("✅ RecipeBrowserService: Lambda response received: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("Lambda JSON response: \(json)")
                        
                        // Check for error response
                        if let error = json["error"] as? String {
                            print("❌ Lambda returned error: \(error)")
                            self?.completion?(nil)
                            self?.completion = nil
                            return
                        }
                        
                        // Check for success flag if Lambda returns one
                        if let success = json["success"] as? Bool, !success {
                            print("❌ Lambda indicated failure")
                            self?.completion?(nil)
                            self?.completion = nil
                            return
                        }
                        
                        // Parse successful response - could be nested in 'recipe' field or at root
                        let recipeData = (json["recipe"] as? [String: Any]) ?? json
                        let recipe = self?.parseLambdaResponse(recipeData)
                        self?.completion?(recipe)
                        self?.completion = nil
                    } else {
                        print("Invalid JSON response")
                        self?.completion?(nil)
                        self?.completion = nil
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                    self?.completion?(nil)
                    self?.completion = nil
                }
            }
        }.resume()
    }
    
    private func parseLambdaResponse(_ data: [String: Any]) -> ImportedRecipe? {
        let title = data["title"] as? String ?? "Untitled Recipe"
        
        // Parse ingredients from Lambda response
        let ingredients: [String]
        if let ingredientsArray = data["ingredients"] as? [String] {
            ingredients = ingredientsArray
        } else if let ingredientsArray = data["ingredients"] as? [[String: Any]] {
            // Handle structured ingredients
            ingredients = ingredientsArray.compactMap { ingredient in
                if let name = ingredient["name"] as? String,
                   let amount = ingredient["amount"] as? String,
                   let unit = ingredient["unit"] as? String {
                    return "\(amount) \(unit) \(name)"
                } else if let original = ingredient["original"] as? String {
                    return original
                }
                return nil
            }
        } else {
            ingredients = []
        }
        
        // Parse instructions from Lambda response
        let instructions: [String]
        if let instructionsArray = data["instructions"] as? [String] {
            instructions = instructionsArray
        } else if let instructionsArray = data["instructions"] as? [[String: Any]] {
            // Handle structured instructions
            instructions = instructionsArray.compactMap { instruction in
                if let text = instruction["text"] as? String {
                    return text
                } else if let instruction = instruction["instruction"] as? String {
                    return instruction
                }
                return nil
            }
        } else {
            instructions = []
        }
        
        let imageURL = data["image_url"] as? String ?? data["image"] as? String
        
        // Parse prep time - handle both string and int formats
        let prepTime: Int
        if let prepTimeInt = data["prep_time"] as? Int {
            prepTime = prepTimeInt
        } else if let prepTimeString = data["prep_time"] as? String {
            // Extract minutes from string like "15 mins"
            let numbers = prepTimeString.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            prepTime = numbers.first ?? 0
        } else {
            prepTime = 0
        }
        
        // Parse servings - handle both string and int formats
        let servings: Int
        if let servingsInt = data["servings"] as? Int {
            servings = servingsInt
        } else if let yieldsString = data["yields"] as? String {
            // Extract number from yields string like "12"
            let numbers = yieldsString.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            servings = numbers.first ?? 1
        } else {
            servings = 1
        }
        
        // Convert instructions to the expected format
        let formattedInstructions = instructions.enumerated().map { index, instruction in
            "\(index + 1). \(instruction)"
        }.joined(separator: "\n\n")
        
        return ImportedRecipe(
            title: title,
            sourceUrl: webView?.url?.absoluteString ?? "",
            ingredients: ingredients,
            instructions: formattedInstructions,
            servings: servings,
            prepTimeMinutes: prepTime,
            imageUrl: imageURL,
            rawIngredients: ingredients,
            rawInstructions: formattedInstructions
        )
    }
    
}

// MARK: - WKNavigationDelegate
extension RecipeBrowserService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🌐 RecipeBrowserService: Page loaded successfully")
        print("🌐 RecipeBrowserService: Current URL: \(webView.url?.absoluteString ?? "nil")")
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        // Wait a moment for any dynamic content to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🌐 RecipeBrowserService: Starting extraction after delay")
            self.executeExtractionScript()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ RecipeBrowserService: Navigation failed: \(error)")
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        completion?(nil)
        completion = nil
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ RecipeBrowserService: Provisional navigation failed: \(error)")
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        completion?(nil)
        completion = nil
    }
    
}
