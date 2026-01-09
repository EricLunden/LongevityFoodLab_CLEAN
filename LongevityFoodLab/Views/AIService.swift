import Foundation

class AIService {
    static let shared = AIService()
    private init() {}
    
    // Rate limiting and request queue
    private let requestQueue = DispatchQueue(label: "ai.service.queue", qos: .userInitiated)
    private let semaphore = DispatchSemaphore(value: 1) // Allow only 1 concurrent request
    private var lastRequestTime: Date = Date.distantPast
    private let minimumRequestInterval: TimeInterval = 2.0 // 2 seconds between requests
    
    // Rate-limited request execution
    private func executeRateLimitedRequest(_ request: @escaping () -> Void) {
        requestQueue.async {
            // Wait for semaphore to ensure only one request at a time
            self.semaphore.wait()
            
            // Calculate delay needed to respect rate limits
            let timeSinceLastRequest = Date().timeIntervalSince(self.lastRequestTime)
            let delayNeeded = max(0, self.minimumRequestInterval - timeSinceLastRequest)
            
            if delayNeeded > 0 {
                print("AIService: Rate limiting - waiting \(delayNeeded) seconds before next request")
                Thread.sleep(forTimeInterval: delayNeeded)
            }
            
            // Update last request time
            self.lastRequestTime = Date()
            
            // Execute the request
            request()
            
            // Release semaphore
            self.semaphore.signal()
        }
    }
    
    // MARK: - Nutrition Component Extraction and Serving Size Estimation
    
    /// Extract main components/ingredients from a complex food name with estimated amounts per typical serving
    func extractFoodComponents(foodName: String, summary: String? = nil) async throws -> [(name: String, amountGrams: Double)] {
        let prompt = """
        Analyze this food item and extract its main ingredient components with estimated amounts for a typical serving.
        
        Food: \(foodName)
        \(summary != nil ? "Context: \(summary!)" : "")
        
        Estimate realistic amounts of each main ingredient in a typical serving (not the full recipe).
        Return a JSON array with ingredient names and their estimated weight in grams for ONE typical serving.
        
        Examples:
        - "Apple Pie" (1 slice) -> [{"name": "apples", "amountGrams": 80}, {"name": "flour", "amountGrams": 40}, {"name": "sugar", "amountGrams": 25}, {"name": "butter", "amountGrams": 15}, {"name": "cinnamon", "amountGrams": 2}]
        - "Spiced Pear Berry Crumble" (1 serving) -> [{"name": "pears", "amountGrams": 50}, {"name": "berries", "amountGrams": 30}, {"name": "flour", "amountGrams": 40}, {"name": "sugar", "amountGrams": 20}, {"name": "butter", "amountGrams": 15}, {"name": "spices", "amountGrams": 5}]
        - "Chicken Salad" (1 cup) -> [{"name": "chicken", "amountGrams": 60}, {"name": "lettuce", "amountGrams": 30}, {"name": "tomatoes", "amountGrams": 20}, {"name": "mayonnaise", "amountGrams": 15}, {"name": "onions", "amountGrams": 10}]
        
        Return ONLY this JSON format (no markdown, no explanation):
        [{"name": "ingredient1", "amountGrams": number}, {"name": "ingredient2", "amountGrams": number}]
        """
        
        do {
            let jsonString = try await makeOpenAIRequestAsync(prompt: prompt)
            
            // Clean JSON string
            var cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("```") {
                let lines = cleaned.components(separatedBy: .newlines)
                var jsonLines = lines
                if let firstLine = jsonLines.first, firstLine.contains("json") {
                    jsonLines.removeFirst()
                }
                if let lastLine = jsonLines.last, lastLine == "```" {
                    jsonLines.removeLast()
                }
                cleaned = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            guard let data = cleaned.data(using: .utf8),
                  let componentsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw NSError(domain: "Invalid JSON", code: 0, userInfo: nil)
            }
            
            var components: [(name: String, amountGrams: Double)] = []
            for item in componentsArray {
                if let name = item["name"] as? String,
                   let amount = item["amountGrams"] as? Double {
                    components.append((name: name, amountGrams: amount))
                }
            }
            
            let componentList = components.map { "\($0.name) (\(Int($0.amountGrams))g)" }.joined(separator: ", ")
            print("✅ AIService: Extracted \(components.count) components from '\(foodName)': \(componentList)")
            return components
        } catch {
            print("❌ AIService: Failed to extract components: \(error)")
            throw error
        }
    }
    
    /// Estimate typical serving size for a food or recipe
    func estimateTypicalServingSize(foodName: String, isRecipe: Bool = false, recipeType: String? = nil) async throws -> (size: String, weightGrams: Double) {
        let prompt = """
        Estimate a typical serving size for this food item.
        
        Food: \(foodName)
        \(isRecipe ? "Type: Recipe (\(recipeType ?? "general"))" : "Type: Single Food Item")
        
        Return ONLY a JSON object with:
        - "servingSize": A descriptive serving size (e.g., "1 slice", "1 cup", "1 piece", "1/8 of pie")
        - "weightGrams": Estimated weight in grams for that serving
        
        Examples:
        - Apple Pie -> {"servingSize": "1 slice (1/8 of pie)", "weightGrams": 150}
        - Soup -> {"servingSize": "1 cup", "weightGrams": 240}
        - Pizza -> {"servingSize": "1 slice", "weightGrams": 100}
        - Salad -> {"servingSize": "1 cup", "weightGrams": 150}
        
        Return ONLY this JSON format (no markdown, no explanation):
        {"servingSize": "description", "weightGrams": number}
        """
        
        do {
            let jsonString = try await makeOpenAIRequestAsync(prompt: prompt)
            
            // Clean JSON string
            var cleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("```") {
                let lines = cleaned.components(separatedBy: .newlines)
                var jsonLines = lines
                if let firstLine = jsonLines.first, firstLine.contains("json") {
                    jsonLines.removeFirst()
                }
                if let lastLine = jsonLines.last, lastLine == "```" {
                    jsonLines.removeLast()
                }
                cleaned = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if let data = cleaned.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let servingSize = dict["servingSize"] as? String,
               let weightGrams = dict["weightGrams"] as? Double {
                print("✅ AIService: Estimated serving size for '\(foodName)': \(servingSize) (\(weightGrams)g)")
                return (size: servingSize, weightGrams: weightGrams)
            } else {
                // Fallback to default
                print("⚠️ AIService: Failed to parse serving size JSON, using default")
                let defaultSize = isRecipe ? "1 serving" : "1 piece"
                let defaultWeight = isRecipe ? 200.0 : 100.0
                return (size: defaultSize, weightGrams: defaultWeight)
            }
        } catch {
            // Fallback to default on error
            print("⚠️ AIService: Failed to estimate serving size, using default: \(error)")
            let defaultSize = isRecipe ? "1 serving" : "1 piece"
            let defaultWeight = isRecipe ? 200.0 : 100.0
            return (size: defaultSize, weightGrams: defaultWeight)
        }
    }
    
    // MARK: - OpenAI Helper Function
    
    /// Makes an OpenAI API request and extracts the response text
    /// Returns the JSON string from the API response, ready for parsing
    private func makeOpenAIRequest(prompt: String, timeout: TimeInterval = 30.0, retryCount: Int = 0, maxRetries: Int = 1, completion: @escaping (Result<String, Error>) -> Void) {
        let startTime = Date()
        
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // OpenAI request format
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": SecureConfig.maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince(startTime)
            
            if let error = error {
                let nsError = error as NSError
                let isTransient = self.isTransientError(nsError)
                
                // Instrumentation log
                print("🔍 AIService: Request failed - errorType: \(nsError.domain), code: \(nsError.code), duration: \(String(format: "%.2f", duration))s, retryCount: \(retryCount), isTransient: \(isTransient)")
                
                // Retry logic for transient failures
                if isTransient && retryCount < maxRetries {
                    let jitteredDelay = Double.random(in: 0.5...1.5) // 0.5-1.5 second jitter
                    print("🔄 AIService: Retrying request after \(String(format: "%.2f", jitteredDelay))s delay (attempt \(retryCount + 1)/\(maxRetries + 1))")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + jitteredDelay) {
                        self.makeOpenAIRequest(prompt: prompt, timeout: timeout, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                    }
                    return
                }
                
                completion(.failure(error))
                return
            }
            
            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("AIService: OpenAI error response: \(errorString)")
                    }
                    
                    let httpError = NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: nil)
                    let isTransient = self.isTransientHTTPError(httpResponse.statusCode)
                    
                    // Instrumentation log
                    print("🔍 AIService: HTTP error - statusCode: \(httpResponse.statusCode), duration: \(String(format: "%.2f", duration))s, retryCount: \(retryCount), isTransient: \(isTransient)")
                    
                    // Retry logic for transient HTTP errors
                    if isTransient && retryCount < maxRetries {
                        let jitteredDelay = Double.random(in: 0.5...1.5)
                        print("🔄 AIService: Retrying HTTP request after \(String(format: "%.2f", jitteredDelay))s delay (attempt \(retryCount + 1)/\(maxRetries + 1))")
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + jitteredDelay) {
                            self.makeOpenAIRequest(prompt: prompt, timeout: timeout, retryCount: retryCount + 1, maxRetries: maxRetries, completion: completion)
                        }
                        return
                    }
                    
                    completion(.failure(httpError))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                return
            }
            
            do {
                // OpenAI response format: { "choices": [{"message": {"content": "..."}}] }
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let text = message["content"] as? String {
                    
                    // Strip markdown code blocks if present (OpenAI sometimes wraps JSON in ```json ... ```)
                    var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedText.hasPrefix("```") {
                        let lines = cleanedText.components(separatedBy: .newlines)
                        var jsonLines = lines
                        if let firstLine = jsonLines.first, firstLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                            jsonLines.removeFirst()
                        }
                        if let lastLine = jsonLines.last, lastLine.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                            jsonLines.removeLast()
                        }
                        cleanedText = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Success log
                    if retryCount > 0 {
                        print("✅ AIService: Request succeeded after retry - duration: \(String(format: "%.2f", duration))s, retryCount: \(retryCount)")
                    }
                    
                    completion(.success(cleanedText))
                } else {
                    // Decoding error - don't retry
                    print("🔍 AIService: Invalid response format - duration: \(String(format: "%.2f", duration))s, retryCount: \(retryCount)")
                    completion(.failure(NSError(domain: "Invalid response format", code: 0, userInfo: nil)))
                }
            } catch {
                // Decoding error - don't retry
                print("🔍 AIService: JSON parsing error - duration: \(String(format: "%.2f", duration))s, retryCount: \(retryCount), error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Helper to determine if an error is transient and should be retried
    private func isTransientError(_ error: NSError) -> Bool {
        // Network errors (timeout, connection lost, etc.)
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorDNSLookupFailed:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    // Helper to determine if an HTTP status code is transient and should be retried
    private func isTransientHTTPError(_ statusCode: Int) -> Bool {
        // 5xx server errors and 429 rate limit
        return statusCode >= 500 && statusCode < 600 || statusCode == 429
    }
    
    /// Sanitize JSON string by escaping unescaped control characters in string values
    /// This fixes "Unescaped control character '0xa'" errors from JSONDecoder
    private func sanitizeJSONString(_ jsonString: String) -> String {
        var result = ""
        var inString = false
        var escapeNext = false
        
        for char in jsonString {
            if escapeNext {
                result.append(char)
                escapeNext = false
                continue
            }
            
            if char == "\\" {
                result.append(char)
                escapeNext = true
                continue
            }
            
            if char == "\"" {
                inString.toggle()
                result.append(char)
                continue
            }
            
            if inString {
                // Escape control characters within string values
                switch char {
                case "\n":
                    result.append("\\n")
                case "\r":
                    result.append("\\r")
                case "\t":
                    result.append("\\t")
                case "\u{0000}"..."\u{001F}": // Control characters
                    let unicode = char.unicodeScalars.first?.value ?? 0
                    result.append(String(format: "\\u%04x", unicode))
                default:
                    result.append(char)
                }
            } else {
                result.append(char)
            }
        }
        
        return result
    }
    
    // Test function to verify API connectivity
    func testAPIConnection(completion: @escaping (Bool) -> Void) {
        print("AIService: Testing OpenAI API connection...")
        
        let testPrompt = "Return only the word 'test'"
        
        makeOpenAIRequest(prompt: testPrompt) { result in
            switch result {
            case .success:
                print("AIService: OpenAI API connection test successful")
                completion(true)
            case .failure(let error):
                print("AIService: OpenAI API test failed with error: \(error)")
                completion(false)
            }
        }
    }
    
    // Fallback function that creates a basic analysis when API fails
    func createFallbackAnalysis(for foodName: String) -> FoodAnalysis {
        return FoodAnalysis(
            foodName: foodName,
            overallScore: -1, // Use -1 to indicate unavailable
            summary: "Analysis temporarily unavailable. Please try again later.",
            healthScores: HealthScores(
                allergies: -1, // Use -1 to indicate unavailable
                antiInflammation: -1,
                bloodSugar: -1,
                brainHealth: -1,
                detoxLiver: -1,
                energy: -1,
                eyeHealth: -1,
                heartHealth: -1,
                immune: -1,
                jointHealth: -1,
                kidneys: -1,
                mood: -1,
                skin: -1,
                sleep: -1,
                stress: -1,
                weightManagement: -1
            ),
            keyBenefits: ["Analysis service temporarily unavailable"],
            ingredients: [
                FoodIngredient(
                    name: "Temporary",
                    impact: "neutral",
                    explanation: "Analysis service is currently unavailable"
                )
            ],
            bestPreparation: "Please try again later",
            servingSize: "Standard serving",
            nutritionInfo: NutritionInfo(
                calories: "Unavailable",
                protein: "Unavailable",
                carbohydrates: "Unavailable",
                fat: "Unavailable",
                sugar: "Unavailable",
                fiber: "Unavailable",
                sodium: "Unavailable",
                saturatedFat: nil
            ),
            scanType: nil,
            foodNames: nil,
            suggestions: nil,
            dataCompleteness: .unavailable,
            analysisTimestamp: nil,
            dataSource: .fallback
        )
    }
    
    func analyzeFood(_ foodName: String, completion: @escaping (Result<FoodAnalysis, Error>) -> Void) {
        analyzeFoodWithProfile(foodName, healthProfile: nil, completion: completion)
    }
    
    func analyzeFoodWithProfile(_ foodName: String, healthProfile: UserHealthProfile?, completion: @escaping (Result<FoodAnalysis, Error>) -> Void) {
        analyzeFoodWithProfile(foodName, healthProfile: healthProfile, timeout: 45.0, completion: completion)
    }
    
    func analyzeFoodWithProfile(_ foodName: String, healthProfile: UserHealthProfile?, timeout: TimeInterval, completion: @escaping (Result<FoodAnalysis, Error>) -> Void) {
        
        print("AIService: Starting personalized analysis for '\(foodName)'")
        
        // Use rate-limited request execution
        executeRateLimitedRequest({
            self.performAnalysis(foodName: foodName, healthProfile: healthProfile, timeout: timeout, completion: completion)
        })
    }
    
    private func performAnalysis(foodName: String, healthProfile: UserHealthProfile?, timeout: TimeInterval = 45.0, completion: @escaping (Result<FoodAnalysis, Error>) -> Void) {
        
        // Extract health goals text for personalization
        let healthGoalsText: String
        if let profile = healthProfile, let healthGoalsJSON = profile.healthGoals {
            do {
                if let data = healthGoalsJSON.data(using: .utf8),
                   let goals = try JSONSerialization.jsonObject(with: data) as? [String],
                   !goals.isEmpty {
                    let top3Goals = Array(goals.prefix(3))
                    healthGoalsText = top3Goals.joined(separator: ", ")
                } else {
                    healthGoalsText = "general health and longevity"
                }
            } catch {
                healthGoalsText = "general health and longevity"
            }
        } else {
            healthGoalsText = "general health and longevity"
        }
        
        // Build personalized prompt based on health profile
        var prompt = """
        Analyze "\(foodName)" for longevity and health benefits. Return ONLY valid JSON:
        
        🚫 CRITICAL PROHIBITION - READ THIS FIRST:
        NEVER mention age, gender, or demographics in the summary. Examples of FORBIDDEN phrases:
        - "young male", "young female", "adult", "elderly"
        - "men", "women", "males", "females"
        - "under 30", "over 50", any age reference
        - "particularly beneficial for a [demographic]"
        - "especially for [demographic]"
        
        If you see these terms in your response, DELETE THEM. Use ONLY "your", "you", "your body", "your goals" - never demographic terms.
        """
        
        // Add personalization if health profile exists (EXCLUDE age and sex)
        if let profile = healthProfile {
            let healthGoalsJSON = profile.healthGoals ?? "[]"
            let foodRestrictionsJSON = profile.foodRestrictions ?? "[]"
            let dietaryPreference = profile.dietaryPreference ?? "Not specified"
            
            prompt += """
            
            PERSONALIZATION CONTEXT:
            - Health Goals: \(healthGoalsJSON)
            - Dietary Preference: \(dietaryPreference)
            - Food Restrictions: \(foodRestrictionsJSON)
            
            PERSONALIZE YOUR ANALYSIS:
            - Focus on health benefits that align with their goals
            - Consider their dietary preferences and restrictions
            - Highlight specific benefits relevant to their health goals
            - NEVER mention age, gender, or demographics
            """
        }
        
        prompt += """
        
        ════════════════════════════════════════════════════════════════════════════
        SUMMARY GUIDELINES (CRITICAL - READ THIS FIRST BEFORE WRITING SUMMARY):
        ════════════════════════════════════════════════════════════════════════════

        You are writing a 1-2 sentence meal analysis for a longevity app. Build trust that healthy food is both good for you AND delicious. Reduce food fear, discourage perfectionism, and encourage confidence in eating whole, enjoyable foods.

        TONE PRINCIPLES:
        - Clarity over completeness
        - Encouragement over fear
        - Honesty over certainty
        - Never frame whole or minimally processed foods as "dangerous"
        - Tradeoffs are optimization opportunities, not warnings
        - Avoid alarmist or judgmental language
        - For foods scoring ≥80: Emphasize what's working, reinforce confidence, avoid scare framing

        RULES:

        1. MAX 40 words total

        2. Lead with the most specific/interesting fact about MAIN INGREDIENTS (largest portions)

        3. Focus on MAIN INGREDIENTS ONLY (largest portions on the plate). Ignore small garnishes, decorative elements, or tiny side items unless they significantly impact the meal's nutrition.

        4. Never lecture or use "should"

        5. Include ONE specific number (grams, calories, glucose spike, etc.) from the MAIN INGREDIENTS

        6. For scores ≥85: Include at least ONE experiential benefit (satiety, flavor satisfaction, ease of eating regularly, enjoyment). Reinforce that healthy eating can be pleasurable and sustainable.

        7. End with impact on their personal goal: \(healthGoalsText)

        BAD (mushy/preachy):
        "Apple pie with ice cream is a traditional dessert that provides enjoyment but should be consumed in moderation, especially for individuals focusing on blood sugar control."

        GOOD EXAMPLES:

        Apple Pie + Ice Cream (Score: 44):
        "This dessert packs 65g of sugar—triggering a glucose spike 3x higher than your body can efficiently process. Save it for special occasions if weight loss is your goal."

        Salmon Bowl (Score: 92):
        "Wild salmon's 3g omega-3s combined with kale's sulforaphane are nutrients commonly studied in relation to cellular function—part of dietary patterns researched for \(healthGoalsText). This satisfying combination keeps you full for hours while delivering exceptional flavor."

        McDonald's Big Mac (Score: 38):
        "With 563 calories and only 2g of fiber, this meal provides limited satiety, while the 33g of processed fat offers minimal nutrients associated with metabolic health."

        Green Smoothie (Score: 81):
        "Your smoothie's 8g of fiber supports normal digestion, while spinach's folate plays a role in energy metabolism—nutrients linked to \(healthGoalsText). This refreshing blend is easy to enjoy daily and keeps you satisfied."

        Pizza Slice (Score: 52):
        "Each slice delivers 285 calories but zero longevity nutrients, plus refined flour that ages your cells faster than whole grains would."

        FORMAT:
        [Specific fact with number about MAIN INGREDIENTS] + [Nutrient presence and research context] + [Connection to their goal if relevant]
        
        LANGUAGE CONSTRAINTS (CRITICAL - APP STORE COMPLIANCE):
        - Use educational, descriptive language only
        - Allowed: "supports normal function", "associated with", "contains nutrients linked to", "plays a role in", "commonly studied in relation to", "part of dietary patterns researched for"
        - Prohibited: "improves", "treats", "prevents", "reduces disease risk", "enhances", "suppresses", "activates pathways", "boosts production"
        - Do NOT describe biological mechanisms as outcomes
        - Frame benefits as nutrient presence, not functional performance

        PRIORITIZATION RULE:
        - Always focus on the largest/most substantial components of the meal
        - Ignore decorative elements, small garnishes, or tiny side items
        - If unsure, prioritize by visual size/portion in the image

        NEVER USE:
        - "Should be consumed"
        - "In moderation"
        - "Traditional"
        - "Provides enjoyment"
        - "It's important to"
        - "Individuals focusing on"
        - Generic health words (wholesome, nutritious, beneficial)
        - "the user's", "users", "people", "individuals", "adults", "young males", "women", "men" → ALWAYS use "your" or "you"
        - "particularly beneficial for a [demographic]" or "especially for [demographic]" → NEVER mention demographics
        - Age references: "under 30", "over 50", "young", "elderly" → NEVER mention age
        - Fear-based language: "dangerous", "harmful", "toxic", "avoid at all costs" (for whole foods)
        - Alarmist framing: "will destroy", "kills", "poisons" (use neutral language: "disrupts", "reduces", "limits")
        - Judgment: "bad choice", "terrible", "awful" (use factual language instead)

        SERVING SIZE ACCURACY:
        - All nutrition estimates and summaries must be per realistic serving size
        - Never extrapolate ingredient quantities beyond what is visible or standard
        - Avoid exaggerated or fear-inducing quantity language
        - Use standard serving sizes: 1 cup, 1 slice, 1 piece, 1/8 of pie, etc.
        - For meals, estimate based on typical restaurant/home portions, not oversized portions

        Keep it conversational but authoritative. Make them feel the immediate impact of their food choice while building confidence in healthy eating.

        ════════════════════════════════════════════════════════════════════════════
        Return ONLY this JSON structure (no markdown, no explanation):
        ════════════════════════════════════════════════════════════════════════════
        CRITICAL: You MUST calculate a unique overallScore (0-100) for THIS SPECIFIC FOOD based on its actual composition. Do NOT use placeholder values or copy example scores. Each food must have a different score.
        {
            "foodName": "\(foodName)",
            "overallScore": <CALCULATE_UNIQUE_SCORE_0_TO_100>,
            "summary": "Write 1-2 sentences, MAX 40 words. Lead with shocking/specific fact. Include ONE specific number. End with impact on: \(healthGoalsText). NO 'should', 'in moderation', 'traditional', 'provides enjoyment'. Use 'your' not 'the user's'.",
            "healthScores": {
                "allergies": 75,
                "antiInflammation": 82,
                "bloodSugar": 62,
                "brainHealth": 71,
                "detoxLiver": 76,
                "energy": 74,
                "eyeHealth": 58,
                "heartHealth": 78,
                "immune": 79,
                "jointHealth": 65,
                "kidneys": 72,
                "mood": 73,
                "skin": 76,
                "sleep": 69,
                "stress": 70,
                "weightManagement": 68
            },
            "keyBenefits": [
                "Health benefit 1 relevant to user's goals",
                "Health benefit 2 relevant to user's goals",
                "Health benefit 3 relevant to user's goals"
            ],
            "ingredients": [
                // CRITICAL: For complex foods/meals (e.g., "peach pie", "lasagna", "chicken parmesan"), you MUST list ALL major ingredients/components, not just the main food. Prioritize by portion size - focus on largest components first. Each ingredient must be a separate object in this array. For "peach pie", list: peaches, pie crust, sugar, butter, flour, etc. For "chicken parmesan", list: chicken, breadcrumbs, cheese, pasta, sauce, etc. For "grilled salmon with rice and lemon wedge", list: salmon, rice (ignore lemon wedge unless it's a significant portion). Do not omit any major components, but ignore small garnishes. For simple whole foods (e.g., "apple", "salmon"), list the main nutrients/compounds.
                {
                    "name": "Main nutrient/ingredient",
                    "impact": "positive/negative/neutral",
                    "explanation": "Why it's good/bad for you, considering user's profile"
                }
            ],
            "bestPreparation": "How to prepare it considering dietary preferences",
            "servingSize": "How much to eat based on user's profile",
            "nutritionInfo": null
        }
        
        CRITICAL: Do NOT provide nutritionInfo - it is loaded on-demand via Spoonacular API when the user taps the nutrition dropdown. This speeds up initial analysis. Set nutritionInfo to null.
        
        Score 0-100 based on real nutrition research. Personalize all content based on the user's health profile if provided.
        
        CRITICAL SCORING GUIDELINES:
        The score must reflect the COMPLETE food composition, not just the main ingredient. For complex foods, you MUST consider ALL ingredients when scoring.
        
        SCORING RANGES BY FOOD TYPE:
        - Whole, unprocessed foods (e.g., "apple", "salmon", "broccoli", "quinoa"): 70-95
          * Examples: Fresh apple = 82, Wild salmon = 91, Steamed broccoli = 88
        
        - Minimally processed foods (e.g., "whole grain bread", "plain yogurt"): 60-75
          * Examples: Whole grain bread = 68, Plain Greek yogurt = 73
        
        - Processed foods (e.g., "white bread", "crackers", "canned soup"): 40-60
          * Examples: White bread = 52, Saltine crackers = 45, Canned tomato soup = 58
        
        - Desserts and sweets (e.g., "apple cake", "chocolate cake", "cookies", "pie"): 30-50
          * CRITICAL: Even if the dessert contains healthy ingredients (e.g., apples in apple cake), the score must reflect the complete composition including added sugars, refined flour, butter/shortening, etc.
          * Examples: Apple cake = 42, Chocolate cake = 38, Chocolate chip cookies = 44, Peach pie = 41
        
        - Highly processed/fast foods (e.g., "fast food burger", "frozen pizza", "chips"): 20-40
          * Examples: Fast food hamburger = 32, Frozen pepperoni pizza = 28, Potato chips = 35
        
        SCORING PENALTIES:
        - Heavily penalize added sugars (reduce score by 15-25 points)
        - Penalize refined grains/flour (reduce score by 10-15 points)
        - Penalize processed ingredients, preservatives, artificial additives (reduce score by 5-15 points)
        - Penalize unhealthy fats (saturated/trans fats from processed sources) (reduce score by 5-10 points)
        - For desserts: The presence of healthy ingredients (e.g., fruit) should NOT offset the penalties from sugar, refined flour, and unhealthy fats
        
        SCORING BONUSES (Apply AFTER penalties, before calculating final score):
        
        BALANCED WHOLE-FOOD BONUS (+5 points):
        Add +5 to the overallScore if the meal meets 4 or more of these 5 criteria:
        - Contains at least 2 different vegetables or legumes
        - Includes a quality protein source (chicken, fish, eggs, beans, lentils, tofu, tempeh)
        - Is primarily whole foods (at least 70% of ingredients are whole, unprocessed foods - not fast food or ultra-processed)
        - Has minimal added sugars (<10g per serving)
        - Is home-cooked or restaurant-quality (not packaged/frozen convenience food)
        
        LONGEVITY SUPERFOODS BONUS (+3 additional points):
        Add +3 MORE to the overallScore if the meal contains 3 or more of these longevity-promoting foods:
        - Fatty fish (salmon, sardines, mackerel, anchovies, herring)
        - Leafy greens (spinach, kale, arugula, swiss chard, collard greens)
        - Legumes (lentils, chickpeas, black beans, split peas, kidney beans, navy beans)
        - Extra virgin olive oil as primary fat
        - Berries (blueberries, strawberries, raspberries, blackberries)
        - Cruciferous vegetables (broccoli, cauliflower, brussels sprouts, cabbage, bok choy)
        - Nuts and seeds (walnuts, almonds, chia, flax, hemp seeds, pumpkin seeds)
        - Whole grains (quinoa, oats, farro, brown rice, barley, bulgur)
        - Fermented foods (yogurt, kefir, kimchi, sauerkraut, miso, tempeh)
        - Alliums (garlic, onions, leeks, shallots, chives)
        - Mushrooms (shiitake, maitake, reishi, portobello, cremini)
        - Sweet potatoes or yams
        - Tomatoes (especially cooked, for lycopene)
        - Avocado
        - Herbs and spices (turmeric, ginger, cinnamon, rosemary, oregano, thyme)
        
        MEDITERRANEAN/PLANT-FORWARD PATTERN BONUS (+5 additional points):
        Add +5 MORE to the overallScore if the meal demonstrates a Mediterranean or plant-forward dietary pattern:
        - Primary fat source is extra virgin olive oil (not butter, margarine, or processed oils)
        - Plant-based proteins (legumes, nuts, seeds) OR fish/seafood (not red meat)
        - Abundant vegetables (at least 3 different types) OR leafy greens as a major component
        - Whole grains present (not refined flour)
        - Minimal or no processed ingredients
        - Herbs and spices used for flavor (not just salt)
        This bonus recognizes meals that align with Blue Zones and PREDIMED research patterns.
        
        MAXIMUM BONUS: +13 points (if all three bonuses are earned: balanced +5, superfoods +3, Mediterranean +5)
        
        MINIMUM SCORE FLOOR FOR WHOLE FOODS (CRITICAL):
        Meals that are primarily whole foods with minimal processing MUST receive a minimum score of 85-90, even if they have small amounts of cheese, olive oil, or grains. Apply this floor AFTER bonuses:
        - If a meal is primarily whole foods (≥80% whole, unprocessed ingredients)
        - AND has no refined flour
        - AND has no added sugar (or <5g)
        - AND has minimal processing
        THEN ensure the final score is AT LEAST 85, even if calculated score is lower.
        
        Examples of meals that should hit the floor:
        - Grilled salmon with roasted vegetables and quinoa: Should score ≥85
        - Mediterranean salad with chickpeas, feta, olive oil: Should score ≥85 (small amount of cheese doesn't penalize)
        - Lentil soup with vegetables and whole grain bread: Should score ≥85
        - Stir-fry with tofu, vegetables, brown rice: Should score ≥85
        
        SCORE CAP: Final overallScore cannot exceed 100. If bonuses would push score over 100, cap at 100.
        
        EXAMPLES:
        - Salmon with roasted broccoli and quinoa: +5 (balanced) +3 (salmon + cruciferous + whole grain) = +8 → Score 78 → 86
        - Chicken stir-fry with vegetables: +5 (balanced) +0 (only 2 longevity foods) = +5 → Score 68 → 73
        - Split pea soup with carrots and onions: +5 (balanced) +3 (legumes + alliums + whole food) = +8 → Score 73 → 81
        - Tomato pasta soup with chickpeas: +5 (balanced) +3 (legumes + tomatoes + whole grains) = +8 → Score 68 → 76
        - Cheeseburger with fries: +0 (not balanced, processed) +0 = +0 → Score unchanged
        - Dessert with berries: +0 (fails balanced criteria due to sugar) +0 = +0 → Score unchanged
        
        IMPORTANT: Bonuses do NOT apply to:
        - Desserts (even healthy ones like fruit-based desserts)
        - Fast food (McDonald's, Burger King, etc.)
        - Heavily processed convenience foods (frozen dinners, instant meals)
        - Meals with >15g added sugar per serving
        - Candy, cookies, cakes, pies (regardless of ingredients)
        
        INDIVIDUAL HEALTH SCORES CALCULATION (CRITICAL):
        Each individual health score (heartHealth, brainHealth, antiInflammation, etc.) MUST reflect the COMPLETE food/recipe composition, NOT just the positive ingredients.
        
        SCORING RULES FOR INDIVIDUAL HEALTH SCORES:
        - Start with the base score from positive ingredients (e.g., apples provide fiber → good for heart)
        - Then APPLY THE SAME PENALTIES as the overallScore:
          * Added sugars: Reduce heartHealth by 15-20 points, bloodSugar by 20-25 points, weightManagement by 15-20 points
          * Refined flour: Reduce heartHealth by 10-15 points, bloodSugar by 10-15 points, energy by 8-12 points
          * Unhealthy fats: Reduce heartHealth by 8-12 points, antiInflammation by 10-15 points
          * Processed ingredients: Reduce immune by 5-10 points, skin by 5-10 points
        
        EXAMPLES FOR DESSERTS:
        - Apple Pie (overallScore: 42):
          * heartHealth: Start with apples (fiber benefits) = 75, but subtract 15 for sugar + 12 for refined flour = 48
          * brainHealth: Start with apples (antioxidants) = 70, but subtract 10 for sugar + 8 for refined flour = 52
          * bloodSugar: Start with apples (fiber helps) = 60, but subtract 25 for sugar + 15 for refined flour = 20
          * weightManagement: Start with apples (fiber) = 65, but subtract 20 for sugar + 12 for refined flour = 33
          * antiInflammation: Start with apples (antioxidants) = 75, but subtract 12 for unhealthy fats + 8 for processed ingredients = 55
        
        - For complex meals (lasagna, pizza, etc.): Apply the same logic - consider ALL ingredients, not just the healthy ones
        
        CRITICAL: The individual health scores should be CONSISTENT with the overallScore and cluster near it. 
        
        HEALTH SCORE NORMALIZATION RULES:
        1. Most individual health scores should be within ±15 points of the overallScore
        2. Allow larger deviations (±20-25 points) ONLY when biologically justified:
           - bloodSugar can be much lower for high-sugar foods (e.g., overallScore 42, bloodSugar 20 is acceptable)
           - heartHealth can be higher for omega-3 rich foods (e.g., overallScore 75, heartHealth 88 is acceptable)
           - antiInflammation can be higher for antioxidant-rich foods (e.g., overallScore 80, antiInflammation 92 is acceptable)
        3. If overallScore is 42 (FAIR), individual scores should generally be in the 30-60 range, NOT 70-80
        4. If overallScore is 85 (EXCELLENT), individual scores should generally be in the 75-95 range, NOT 50-60
        5. Only whole, unprocessed foods should have individual scores in the 70-90 range
        6. Prevent random or confusing score patterns - scores should tell a coherent story about the food
        
        EXAMPLES OF GOOD SCORE COHERENCE:
        - Overall 42: heartHealth 48, brainHealth 45, bloodSugar 20, weightManagement 38, antiInflammation 50 (all cluster near 42, except bloodSugar which is justified)
        - Overall 87: heartHealth 89, brainHealth 85, bloodSugar 82, weightManagement 88, antiInflammation 91 (all cluster near 87)
        
        EXAMPLES OF BAD SCORE COHERENCE (DO NOT DO THIS):
        - Overall 42: heartHealth 75, brainHealth 70, bloodSugar 20, weightManagement 35 (heartHealth and brainHealth are too high)
        - Overall 87: heartHealth 50, brainHealth 45, bloodSugar 85, weightManagement 60 (heartHealth and brainHealth are too low)
        
        SCORING PRECISION REQUIREMENTS:
        - Scores must be precise integers from 0-100
        - Do NOT round to increments of 5 (e.g., use 42, 73, 87, not 45, 75, 85)
        - Use the full range for accurate differentiation between foods
        - Examples of good scoring: 42, 58, 73, 87, 91, 66, 94, 79, 82, 68, 96, 61, 88
        - Examples of bad scoring: 45, 75, 85, 90, 70, 95, 80, 85, 70, 95, 65, 90
        - Each health score should reflect precise assessment, not rounded estimates
        - CRITICAL: Each food MUST receive a UNIQUE score based on its specific composition. Never copy example values (like 73) or use the same score for different foods. Calculate the score based on the actual food being analyzed.
        
        IMPORTANT INGREDIENT REQUIREMENTS:
        - For simple whole foods (e.g., "apple", "salmon", "broccoli"): List the main nutritional components/compounds (vitamins, minerals, fatty acids, etc.)
        - For complex foods/meals (e.g., "peach pie", "lasagna", "chicken parmesan", "pizza"): You MUST analyze and list ALL major ingredients/components. For example:
          * "Peach pie" should include: peaches, pie crust, sugar, butter, flour, eggs (if in crust), spices, etc.
          * "Chicken parmesan" should include: chicken, breadcrumbs, cheese (parmesan, mozzarella), pasta, tomato sauce, oil, herbs, etc.
          * "Lasagna" should include: pasta, ground meat, cheese, tomato sauce, ricotta, vegetables, herbs, etc.
        - Each ingredient must be a separate object in the ingredients array
        - Do not omit any major components - the nutritional score should reflect the complete food/meal
        - For prepared foods, consider all ingredients including added sugars, fats, salt, preservatives, etc.
        """
        
        print("AIService: Using OpenAI model: '\(SecureConfig.openAIModelName)'")
        print("AIService: Request sent for '\(foodName)'")
        
        // Use OpenAI helper function with specified timeout
        makeOpenAIRequest(prompt: prompt, timeout: timeout) { result in
            switch result {
            case .success(let text):
                print("AIService: Received response for '\(foodName)'")
                
                // Sanitize JSON string to handle unescaped control characters
                let sanitizedText = self.sanitizeJSONString(text)
                
                guard let analysisData = sanitizedText.data(using: .utf8) else {
                    print("AIService: Invalid text encoding for '\(foodName)'")
                    completion(.failure(NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)))
                    return
                }
                
                do {
                    var analysis = try JSONDecoder().decode(FoodAnalysis.self, from: analysisData)
                    // Normalize health scores to ensure coherence with overall score
                    analysis = analysis.withNormalizedHealthScores()
                    print("AIService: Successfully decoded and normalized analysis for '\(foodName)'")
                    completion(.success(analysis))
                } catch {
                    print("AIService: JSON parsing error for '\(foodName)': \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                print("AIService: OpenAI request failed for '\(foodName)': \(error)")
                
                // Provide specific error messages for common issues
                if let nsError = error as NSError? {
                    let errorMessage: String
                    switch nsError.code {
                    case 429:
                        errorMessage = "Too many requests. Please wait a moment and try again."
                    case 401:
                        errorMessage = "Authentication failed. Please check your API key."
                    case 403:
                        errorMessage = "Access forbidden. Please check your API permissions."
                    case 500...599:
                        errorMessage = "Server error. Please try again later."
                    default:
                        errorMessage = "Unable to load data. Please try again later."
                    }
                    completion(.failure(NSError(domain: "HTTP Error", code: nsError.code, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func analyzeSupplement(_ supplementName: String, completion: @escaping (Result<FoodAnalysis, Error>) -> Void) {
        let prompt = """
        You are a JSON API. ONLY return valid JSON, no markdown, no explanations, no extra text. If you don't know, return an empty JSON object {}.
        Analyze the supplement named \"\(supplementName)\" for longevity and health benefits. Return ONLY valid JSON in the EXACT format below (do not add, remove, or rename any keys):
        CRITICAL: You MUST calculate a unique overallScore (0-100) based on the supplement's actual health benefits and safety. Do NOT use placeholder values.
        {
            \"foodName\": \"\(supplementName)\",
            \"overallScore\": <CALCULATE_UNIQUE_SCORE_0_TO_100>,
            \"summary\": \"Brief health explanation\",
            \"healthScores\": {
                \"heartHealth\": 78,
                \"brainHealth\": 71,
                \"antiInflammation\": 82,
                \"jointHealth\": 65,
                \"eyeHealth\": 58,
                \"weightManagement\": 68,
                \"bloodSugar\": 62,
                \"energy\": 74,
                \"immune\": 79,
                \"sleep\": 69,
                \"skin\": 76,
                \"stress\": 70
            },
            \"keyBenefits\": [
                \"Health benefit 1\",
                \"Health benefit 2\",
                \"Health benefit 3\"
            ],
            \"ingredients\": [
                // IMPORTANT: List EVERY main and active ingredient in the supplement, not just one. Each ingredient must be a separate object in this array. Do not omit any main or active ingredients. Example: [{name: "Vitamin D3", impact: "positive", explanation: "..."}, {name: "Magnesium", impact: "positive", explanation: "..."}]
                {
                    \"name\": \"Main nutrient\",
                    \"impact\": \"positive\",
                    \"explanation\": \"Why it's good for you\"
                }
            ],
            \"bestPreparation\": \"How to take it\",
            \"servingSize\": \"Recommended dose\",
            \"nutritionInfo\": {
                \"calories\": \"0 kcal\",
                \"protein\": \"0g\",
                \"carbohydrates\": \"0g\",
                \"fat\": \"0g\",
                \"sugar\": \"0g\",
                \"fiber\": \"0g\",
                \"sodium\": \"0mg\",
                \"vitaminD\": \"XXX IU\",
                \"vitaminE\": \"XX mg\",
                \"potassium\": \"XXX mg\",
                \"vitaminK\": \"XXX mcg\",
                \"magnesium\": \"XXX mg\",
                \"vitaminA\": \"XXX mcg\",
                \"calcium\": \"XXX mg\",
                \"vitaminC\": \"XXX mg\",
                \"choline\": \"XXX mg\",
                \"iron\": \"XX mg\",
                \"iodine\": \"XXX mcg\",
                \"zinc\": \"XX mg\",
                \"folate\": \"XXX mcg\",
                \"vitaminB12\": \"X.X mcg\",
                \"vitaminB6\": \"X.X mg\",
                \"selenium\": \"XXX mcg\",
                \"copper\": \"X.X mg\",
                \"manganese\": \"X.X mg\",
                \"thiamin\": \"X.X mg\"
            }
        }
        Score 0-100 based on real supplement research. Provide accurate information for a typical serving size.
        
        CRITICAL SCORING GUIDELINES:
        The score must reflect the COMPLETE supplement composition, including all active ingredients, fillers, and additives.
        
        SCORING RANGES BY SUPPLEMENT QUALITY:
        - High-quality supplements (research-backed, minimal fillers, proper dosages): 70-90
          * Examples: High-quality omega-3 = 84, Well-formulated multivitamin = 78, Quality vitamin D3 = 87
        
        - Standard supplements (some fillers, adequate dosages): 50-70
          * Examples: Standard multivitamin = 62, Basic omega-3 = 68
        
        - Low-quality supplements (many fillers, inadequate dosages, questionable ingredients): 30-50
          * Examples: Low-quality multivitamin with fillers = 45, Supplement with excessive additives = 38
        
        SCORING PENALTIES:
        - Penalize excessive fillers, binders, artificial colors/flavors (reduce score by 5-15 points)
        - Penalize inadequate dosages or poor bioavailability (reduce score by 10-20 points)
        - Penalize questionable or unproven ingredients (reduce score by 5-15 points)
        - Reward research-backed ingredients with proper dosages (increase score appropriately)
        
        INDIVIDUAL HEALTH SCORES CALCULATION (CRITICAL):
        Each individual health score (heartHealth, brainHealth, antiInflammation, etc.) MUST reflect the COMPLETE supplement composition, including all active ingredients, fillers, and additives.
        
        SCORING RULES FOR INDIVIDUAL HEALTH SCORES:
        - Start with the base score from beneficial active ingredients
        - Then APPLY PENALTIES for negative factors:
          * Excessive fillers/binders: Reduce immune by 5-10 points, digestive health by 5-10 points
          * Inadequate dosages: Reduce the relevant health score by 10-15 points (e.g., low vitamin D → reduce bone health)
          * Questionable ingredients: Reduce the relevant health score by 5-10 points
          * Artificial additives: Reduce immune by 5-8 points, skin by 5-8 points
        
        CRITICAL: The individual health scores should be CONSISTENT with the overallScore. If overallScore is 62 (standard quality), individual scores should generally align with that range, not be artificially high.
        
        SCORING PRECISION REQUIREMENTS:
        - Scores must be precise integers from 0-100
        - Do NOT round to increments of 5 (e.g., use 62, 78, 84, not 65, 80, 85)
        - Use the full range for accurate differentiation between supplements
        - Examples of good scoring: 62, 78, 84, 68, 87, 45, 91, 71, 82, 66, 88
        - Examples of bad scoring: 65, 80, 85, 70, 90, 50, 95, 75, 85, 70, 90
        - Each health score should reflect precise assessment, not rounded estimates
        """
        
        makeOpenAIRequest(prompt: prompt) { result in
            switch result {
            case .success(let text):
                // Sanitize JSON string to handle unescaped control characters
                let sanitizedText = self.sanitizeJSONString(text)
                
                guard let analysisData = sanitizedText.data(using: .utf8), !sanitizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    completion(.failure(NSError(domain: "No supplement data found. Please try a different name.", code: 0, userInfo: nil)))
                    return
                }
                do {
                    var analysis = try JSONDecoder().decode(FoodAnalysis.self, from: analysisData)
                    // Normalize health scores to ensure coherence with overall score
                    analysis = analysis.withNormalizedHealthScores()
                    completion(.success(analysis))
                } catch {
                    print("Decoding error: \(error)")
                    completion(.failure(NSError(domain: "Invalid supplement data format. Please try a different name.", code: 0, userInfo: nil)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Async version of makeOpenAIRequest for use with async/await
    func makeOpenAIRequestAsync(prompt: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            makeOpenAIRequest(prompt: prompt) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func getDashboardData(period: String, healthProfile: UserHealthProfile? = nil) async throws -> DashboardData {
        // Build personalized prompt
        var prompt = """
        Generate comprehensive dashboard data for a longevity food tracking app. Return ONLY valid JSON for \(period) period:
        
        🚫 CRITICAL PROHIBITION - READ THIS FIRST:
        NEVER mention age, gender, or demographics in any text. Examples of FORBIDDEN phrases:
        - "young male", "young female", "adult", "elderly"
        - "men", "women", "males", "females"
        - "under 30", "over 50", any age reference
        - "particularly beneficial for a [demographic]"
        - "especially for [demographic]"
        
        If you see these terms in your response, DELETE THEM. Use ONLY "your", "you", "your body", "your goals" - never demographic terms.
        """
        
        // Add personalization if health profile exists (EXCLUDE age and sex)
        if let profile = healthProfile {
            let healthGoalsJSON = profile.healthGoals ?? "[]"
            let foodRestrictionsJSON = profile.foodRestrictions ?? "[]"
            let dietaryPreference = profile.dietaryPreference ?? "Not specified"
            
            prompt += """
            
            PERSONALIZATION CONTEXT:
            - Health Goals: \(healthGoalsJSON)
            - Dietary Preference: \(dietaryPreference)
            - Food Restrictions: \(foodRestrictionsJSON)
            
            PERSONALIZE THE DASHBOARD:
            - Adjust nutrition recommendations based on their goals
            - Focus on foods that align with their dietary preferences
            - Highlight progress toward their specific health goals
            - NEVER mention age, gender, or demographics
            """
        }
        
        prompt += """
        
        {
            "currentScore": 89,
            "yesterdayScore": 86,
            "scoreHistory": [
                {"day": "Mon", "score": 82},
                {"day": "Tue", "score": 85},
                {"day": "Wed", "score": 79},
                {"day": "Thu", "score": 88},
                {"day": "Fri", "score": 86},
                {"day": "Sat", "score": 91},
                {"day": "Sun", "score": 89}
            ],
            "nutritionBalance": [
                {"name": "Antioxidants", "value": 85, "color": "green"},
                {"name": "Omega-3", "value": 65, "color": "blue"},
                {"name": "Fiber", "value": 78, "color": "orange"},
                {"name": "Polyphenols", "value": 92, "color": "purple"}
            ],
            "nutritionData": [
                {"name": "Calories", "icon": "🔥", "current": 1650, "recommended": 2000, "unit": "kcal"},
                {"name": "Protein", "icon": "💪", "current": 95, "recommended": 75, "unit": "g"},
                {"name": "Carbs", "icon": "🌾", "current": 180, "recommended": 225, "unit": "g"},
                {"name": "Fat", "icon": "🥑", "current": 58, "recommended": 65, "unit": "g"},
                {"name": "Sugar", "icon": "🍯", "current": 45, "recommended": 36, "unit": "g"},
                {"name": "Fiber", "icon": "🥦", "current": 22, "recommended": 30, "unit": "g"},
                {"name": "Sodium", "icon": "🧂", "current": 2800, "recommended": 2300, "unit": "mg"}
            ],
            "topFoods": [
                {"name": "Salmon", "score": 95, "icon": "🐟"},
                {"name": "Blueberries", "score": 92, "icon": "🫐"},
                {"name": "Spinach", "score": 88, "icon": "🥬"},
                {"name": "Avocado", "score": 85, "icon": "🥑"},
                {"name": "Nuts", "score": 82, "icon": "🥜"},
                {"name": "Broccoli", "score": 80, "icon": "🥦"}
            ],
            "recentMeals": [
                {"time": "2:30 PM", "meal": "Grilled Salmon Bowl", "score": 89, "trend": "↗️"},
                {"time": "12:15 PM", "meal": "Quinoa Salad", "score": 85, "trend": "→"},
                {"time": "9:45 AM", "meal": "Berry Smoothie", "score": 78, "trend": "↘️"},
                {"time": "Yesterday", "meal": "Mediterranean Pasta", "score": 82, "trend": "↗️"}
            ],
            "yearsAdded": "2.3",
            "dayStreak": "21",
            "goalProgress": "85%"
        }
        
        Generate realistic data based on typical healthy eating patterns. Scores should be 0-100, nutrition values should be realistic daily intake.
        """
        
        let text = try await makeOpenAIRequestAsync(prompt: prompt)
        
        // Sanitize JSON string to handle unescaped control characters
        let sanitizedText = sanitizeJSONString(text)
        
        guard let dashboardData = sanitizedText.data(using: .utf8) else {
            throw NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)
        }
        
        let dashboard = try JSONDecoder().decode(DashboardData.self, from: dashboardData)
        return dashboard
    }
    
    // Quality Analysis for organic vs conventional food
    func getQualityAnalysis(foodName: String) async throws -> QualityAnalysis {
        let prompt = """
        Analyze the organic vs conventional tradeoffs for \(foodName).
        
        Respond in this exact JSON format:
        {
          "organicPriority": "HIGH/MEDIUM/LOW",
          "contaminationRisk": {
            "score": 1-5,
            "explanation": "brief explanation"
          },
          "priceDifference": {
            "amount": "+$X per pound/unit",
            "percentage": "X% more expensive"
          },
          "worthItScore": 0-100,
          "whyConsiderOrganic": [
            "Benefit 1",
            "Benefit 2",
            "Benefit 3"
          ],
          "whenToSaveMoney": [
            "Scenario 1",
            "Scenario 2"
          ],
          "smartShoppingTips": {
            "best": "Best option description",
            "good": "Good alternative",
            "acceptable": "Budget option"
          },
          "annualImpact": {
            "costIncrease": "$X per year",
            "healthBenefit": "Significant/Moderate/Minimal"
          },
          "shouldDisplay": true/false
        }
        
        Base your analysis on current research about pesticide residues, contamination risks, nutritional differences, and cost-benefit considerations. If this food doesn't have meaningful organic vs conventional differences (like salt or water), set shouldDisplay to false.
        """
        
        let text = try await makeOpenAIRequestAsync(prompt: prompt)
        
        // Sanitize JSON string to handle unescaped control characters
        let sanitizedText = sanitizeJSONString(text)
        
        guard let qualityData = sanitizedText.data(using: .utf8) else {
            throw NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)
        }
        
        let qualityAnalysis = try JSONDecoder().decode(QualityAnalysis.self, from: qualityData)
        return qualityAnalysis
    }
    
    // Pet Food Analysis for dogs and cats
    func getPetFoodAnalysis(petType: PetFoodAnalysis.PetType, productName: String) async throws -> PetFoodAnalysis {
        
        let prompt = """
        Analyze this pet food for health and longevity:
        Pet Type: \(petType.displayName)
        Food Product: \(productName)
        
        Respond in this exact JSON format:
        {
          "petType": "\(petType.rawValue)",
          "brandName": "Unknown",
          "productName": "\(productName)",
          "overallScore": 0-100,
          "summary": "Brief summary of the pet food's health benefits and considerations",
          "healthScores": {
            "digestiveHealth": 0-100,
            "coatHealth": 0-100,
            "jointHealth": 0-100,
            "immuneHealth": 0-100,
            "energyLevel": 0-100,
            "weightManagement": 0-100,
            "dentalHealth": 0-100,
            "skinHealth": 0-100
          },
          "keyBenefits": [
            "Benefit 1",
            "Benefit 2",
            "Benefit 3"
          ],
          "ingredients": [
            {
              "name": "Ingredient Name",
              "impact": "Positive/Negative/Neutral",
              "explanation": "Brief explanation of impact",
              "isBeneficial": true/false
            }
          ],
          "fillersAndConcerns": {
            "fillers": [
              {
                "name": "Filler ingredient name",
                "description": "What this filler is",
                "whyUsed": "Why manufacturers use this filler",
                "impact": "How this filler affects pet health",
                "isConcerning": true/false
              }
            ],
            "potentialConcerns": [
              {
                "ingredient": "Concerning ingredient name",
                "concern": "What the concern is",
                "explanation": "Why this ingredient is concerning in simple terms",
                "severity": "Low/Moderate/High",
                "alternatives": "What to look for instead"
              }
            ],
            "overallRisk": "Overall risk assessment in simple language",
            "recommendations": "Simple recommendations for pet owners"
          },
          "bestPractices": {
            "feedingGuidelines": "General feeding guidelines",
            "portionSize": "Recommended portion size",
            "frequency": "Recommended feeding frequency",
            "specialConsiderations": "Any special considerations (e.g., age, breed, allergies)",
            "transitionTips": "Tips for transitioning to this food"
          },
          "nutritionInfo": {
            "protein": "X%",
            "fat": "X%",
            "carbohydrates": "X%",
            "fiber": "X%",
            "moisture": "X%",
            "calories": "X kcal/cup",
            "omega3": "X%",
            "omega6": "X%"
          }
        }
        
        Base your analysis on veterinary nutritional science, ingredient quality, and common pet health concerns.
        """
        
        let text = try await makeOpenAIRequestAsync(prompt: prompt)
        
        // Sanitize JSON string to handle unescaped control characters
        let sanitizedText = sanitizeJSONString(text)
        
        guard let petFoodData = sanitizedText.data(using: .utf8) else {
            throw NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)
        }
        
        let petFoodAnalysis = try JSONDecoder().decode(PetFoodAnalysis.self, from: petFoodData)
        
        // Add cache metadata
        let cacheKey = PetFoodAnalysis.generateCacheKey(petType: petType, productName: productName)
        let analysisDate = Date()
        let cacheVersion = "v1.0"
        
        // Create a new instance with cache metadata
        let finalAnalysis = PetFoodAnalysis(
            petType: petFoodAnalysis.petType,
            brandName: petFoodAnalysis.brandName,
            productName: petFoodAnalysis.productName,
            overallScore: petFoodAnalysis.overallScore,
            summary: petFoodAnalysis.summary,
            healthScores: petFoodAnalysis.healthScores,
            keyBenefits: petFoodAnalysis.keyBenefits,
            ingredients: petFoodAnalysis.ingredients,
            fillersAndConcerns: petFoodAnalysis.fillersAndConcerns,
            bestPractices: petFoodAnalysis.bestPractices,
            nutritionInfo: petFoodAnalysis.nutritionInfo,
            analysisDate: analysisDate,
            cacheKey: cacheKey,
            cacheVersion: cacheVersion,
            suggestions: petFoodAnalysis.suggestions
        )
        
        return finalAnalysis
    }
}

// MARK: - Similar Pet Food Suggestions
extension AIService {
    func findSimilarPetFoods(
        currentFood: String,
        currentScore: Int,
        petType: PetFoodAnalysis.PetType,
        completion: @escaping (Result<[PetFoodSuggestion], Error>) -> Void
    ) {
        print("AIService: Finding similar pet foods for \(currentFood) with score \(currentScore)")
        
        let prompt = """
        You are a pet nutrition expert. Find 3 similar pet food products that would have HIGHER scores than the current food.
        
        Current Food: \(currentFood)
        Current Score: \(currentScore)/100
        Pet Type: \(petType.displayName)
        
        Find 3 similar pet food products that:
        1. Are in the same category (dry/wet, life stage, special needs)
        2. Would score 10-30 points higher than the current food
        3. Are widely available in the US market
        4. Have better ingredient quality and nutritional profiles
        
        Respond in this exact JSON format:
        {
          "suggestions": [
            {
              "brandName": "Brand name",
              "productName": "Product name",
              "score": 85,
              "reason": "Brief explanation of why this scores higher",
              "keyBenefits": ["Benefit 1", "Benefit 2", "Benefit 3"],
              "priceRange": "$X-$Y per bag",
              "availability": "Widely available at pet stores and online"
            },
            {
              "brandName": "Brand name",
              "productName": "Product name",
              "score": 88,
              "reason": "Brief explanation of why this scores higher",
              "keyBenefits": ["Benefit 1", "Benefit 2", "Benefit 3"],
              "priceRange": "$X-$Y per bag",
              "availability": "Widely available at pet stores and online"
            },
            {
              "brandName": "Brand name",
              "productName": "Product name",
              "score": 92,
              "reason": "Brief explanation of why this scores higher",
              "keyBenefits": ["Benefit 1", "Benefit 2", "Benefit 3"],
              "priceRange": "$X-$Y per bag",
              "availability": "Widely available at pet stores and online"
            }
          ]
        }
        
        Base your suggestions on real pet food brands and products available in the US market. Focus on products that genuinely offer better nutrition and ingredient quality.
        """
        
        makeOpenAIRequest(prompt: prompt) { result in
            switch result {
            case .success(let text):
                // Sanitize JSON string to handle unescaped control characters
                let sanitizedText = self.sanitizeJSONString(text)
                
                guard let textData = sanitizedText.data(using: .utf8) else {
                    completion(.failure(NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(SimilarFoodsResponse.self, from: textData)
                    completion(.success(response.suggestions))
                } catch {
                    print("AIService: Failed to decode similar foods response: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Similar Grocery Suggestions (for Healthier Choices)
    func findSimilarGroceryProducts(
        currentProduct: String,
        currentScore: Int,
        nutritionInfo: NutritionInfo,
        completion: @escaping (Result<[GrocerySuggestion], Error>) -> Void
    ) {
        print("AIService: Finding similar grocery products for \(currentProduct) with score \(currentScore)")
        
        // Get user preferences
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let dietaryPreference = healthProfileManager.currentProfile?.dietaryPreference ?? ""
        let healthGoalsText = healthGoals.isEmpty ? "general health" : healthGoals.joined(separator: ", ")
        let dietaryPreferenceText = dietaryPreference.isEmpty ? "None" : dietaryPreference
        
        let prompt = """
        You are a nutrition expert. Find 2-3 healthier alternative products for this grocery item.
        
        Current Product: \(currentProduct)
        Current Score: \(currentScore)/100
        User's Health Goals: \(healthGoalsText)
        User's Dietary Preference: \(dietaryPreferenceText)
        
        Find healthier alternatives that:
        1. Are in the same product category
        2. Would score 10-30 points higher than the current product
        3. Are widely available in US stores (grocery stores, Target, Walmart, Whole Foods, etc.)
        4. Have better ingredient quality and nutritional profiles
        
        Respond in this exact JSON format:
        {
          "suggestions": [
            {
              "brandName": "Brand name",
              "productName": "Product name",
              "score": 85,
              "reason": "Brief explanation of why this scores higher (2 sentences max)",
              "keyBenefits": ["Benefit 1 with specific numbers", "Benefit 2", "Benefit 3"],
              "priceRange": "$X.XX-$Y.YY per unit",
              "availability": "Widely available at grocery stores and online"
            },
            {
              "brandName": "Brand name",
              "productName": "Product name",
              "score": 88,
              "reason": "Brief explanation of why this scores higher (2 sentences max)",
              "keyBenefits": ["Benefit 1 with specific numbers", "Benefit 2", "Benefit 3"],
              "priceRange": "$X.XX-$Y.YY per unit",
              "availability": "Widely available at grocery stores and online"
            }
          ]
        }
        
        REQUIREMENTS:
        - MUST include REAL brand names (e.g., "Kerrygold", "Organic Valley", "Dave's Killer Bread", "Rao's", "Simple Mills", "Siete", "Ezekiel", "Amy's", "Annie's", "Applegate", "Muir Glen", "Fage", "Siggi's", "365 Whole Foods", "Kashi", "Cascadian Farm", "Lundberg", "Bob's Red Mill")
        - MUST include specific numbers in keyBenefits (mg, g, %, etc.) - e.g., "50% more omega-3s (500mg)", "5g fiber per slice", "180mg sodium"
        - MUST reference the user's health goals directly in reason or benefits
        - keyBenefits should be 2-4 items, each with measurable benefits
        - priceRange should be realistic for US market
        - availability should mention specific store types or "widely available"
        
        Base your suggestions on real brands and products available in the US market. Focus on products that genuinely offer better nutrition and ingredient quality.
        """
        
        makeOpenAIRequest(prompt: prompt) { result in
            switch result {
            case .success(let text):
                // Sanitize JSON string to handle unescaped control characters
                let sanitizedText = self.sanitizeJSONString(text)
                
                guard let textData = sanitizedText.data(using: .utf8) else {
                    completion(.failure(NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(GrocerySuggestionsResponse.self, from: textData)
                    completion(.success(response.suggestions))
                } catch {
                    print("AIService: Failed to decode grocery suggestions response: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Similar Supplement Suggestions
    func findSimilarSupplements(
        currentSupplement: String,
        currentScore: Int,
        completion: @escaping (Result<[GrocerySuggestion], Error>) -> Void
    ) {
        print("AIService: Finding similar supplements for \(currentSupplement) with score \(currentScore)")
        
        // Get user preferences
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let healthGoalsText = healthGoals.isEmpty ? "general health" : healthGoals.joined(separator: ", ")
        
        let prompt = """
        You are a supplement and nutrition expert. Find 2-3 HIGHER SCORING alternatives for this supplement.
        
        SCANNED SUPPLEMENT:
        Name: \(currentSupplement)
        Score: \(currentScore)
        User's Health Goals: \(healthGoalsText)
        
        CRITICAL: Identify the supplement CATEGORY and suggest alternatives in the SAME category.
        
        Common categories:
        - Prostate health (saw palmetto, beta-sitosterol, pygeum, lycopene)
        - Heart/cardiovascular (CoQ10, omega-3, fish oil, hawthorn)
        - Brain/cognitive (lion's mane, ginkgo, phosphatidylserine, bacopa)
        - Joint health (glucosamine, chondroitin, MSM, turmeric)
        - Sleep (melatonin, magnesium, valerian, L-theanine)
        - Liver/detox (NAC, milk thistle, glutathione, dandelion)
        - Multivitamin (broad spectrum vitamins/minerals)
        - Energy (B vitamins, iron, adaptogenics, rhodiola)
        - Immune (vitamin C, zinc, elderberry, echinacea)
        - Digestive (probiotics, enzymes, fiber, digestive bitters)
        - Bone health (calcium, vitamin D, magnesium, K2)
        - Skin/hair (collagen, biotin, hyaluronic acid)
        - Eye health (lutein, zeaxanthin, bilberry)
        
        Determine which category this supplement belongs to based on its name and ingredients.
        Then suggest 2-3 alternatives in the SAME CATEGORY with scores HIGHER than \(currentScore).
        
        Respond in this exact JSON format:
        {
          "category": "identified category (e.g., Prostate health, Heart/cardiovascular, Brain/cognitive)",
          "suggestions": [
            {
              "brandName": "Brand name",
              "productName": "Product name",
              "score": 85,
              "reason": "Brief reason it scores higher (50-70 characters max)",
              "keyBenefits": ["Benefit 1", "Benefit 2", "Benefit 3"],
              "priceRange": "$X-$Y per bottle",
              "availability": "Widely available at health stores and online"
            },
            {
              "brandName": "Brand name",
              "productName": "Product name",
              "score": 88,
              "reason": "Brief reason it scores higher (50-70 characters max)",
              "keyBenefits": ["Benefit 1", "Benefit 2", "Benefit 3"],
              "priceRange": "$X-$Y per bottle",
              "availability": "Widely available at health stores and online"
            }
          ]
        }
        
        REQUIREMENTS:
        - MUST identify the correct category based on supplement name and typical ingredients
        - MUST suggest alternatives in the SAME category (e.g., prostate supplements should suggest other prostate supplements)
        - MUST include REAL supplement brand names (e.g., "Thorne", "Garden of Life", "NOW Foods", "Nature Made", "Solgar", "Nordic Naturals", "Jarrow Formulas", "Life Extension", "Doctor's Best", "Country Life", "MegaFood", "New Chapter", "Rainbow Light", "SmartyPants", "Ritual")
        - Scores must be HIGHER than \(currentScore)
        - keyBenefits should be 2-4 items highlighting specific advantages
        - priceRange should be realistic for US market (e.g., "$15-$25 per bottle", "$20-$30 per bottle")
        - availability should mention "health stores and online" or "widely available at health stores and online"
        - reason should be 50-70 characters max explaining why it scores higher
        
        Base your suggestions on real supplement brands and products available in the US market. Focus on products that genuinely offer better quality, bioavailability, and ingredient purity.
        """
        
        makeOpenAIRequest(prompt: prompt) { result in
            switch result {
            case .success(let text):
                // Sanitize JSON string to handle unescaped control characters
                let sanitizedText = self.sanitizeJSONString(text)
                
                guard let textData = sanitizedText.data(using: .utf8) else {
                    completion(.failure(NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(GrocerySuggestionsResponse.self, from: textData)
                    completion(.success(response.suggestions))
                } catch {
                    print("AIService: Failed to decode supplement suggestions response: \(error)")
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Meal Analysis Generation
    func generateMealAnalysis(
        meals: [TrackedMeal],
        averageScore: Double,
        healthGoals: [String],
        completion: @escaping (String) -> Void
    ) {
        let mealNames = meals.map { $0.name }
        let highScoringMeals = meals.filter { ($0.originalAnalysis?.overallScore ?? 0) >= 7 }
        let lowScoringMeals = meals.filter { ($0.originalAnalysis?.overallScore ?? 0) < 5 }
        
        let prompt = """
        Analyze the following meal data and generate a personalized 2-paragraph analysis for a longevity-focused nutrition app.
        
        MEAL DATA:
        - Total meals: \(meals.count)
        - Average longevity score: \(Int(averageScore * 10))/100
        - Meal names: \(mealNames.joined(separator: ", "))
        - High-scoring meals (7+): \(highScoringMeals.map { $0.name }.joined(separator: ", "))
        - Low-scoring meals (<5): \(lowScoringMeals.map { $0.name }.joined(separator: ", "))
        - User's health goals: \(healthGoals.joined(separator: ", "))
        
        REQUIREMENTS:
        1. FIRST PARAGRAPH: Analyze the day's meals and point out whether they are high or low in essential nutrients per the user's health goals. Be specific about which nutrients are strong/weak and how they relate to their health goals.
        
        2. SECOND PARAGRAPH: Provide specific, actionable recommendations to boost the average longevity score. Include 1-2 actual meal suggestions with specific foods.
        
        TONE: Encouraging, scientific, specific, and actionable. Avoid generic advice like "eat more vegetables."
        
        FORMAT: Two distinct paragraphs separated by a line break. Each paragraph should be 2-3 sentences.
        
        FOCUS: Connect nutrients to health goals, provide specific food recommendations, and be encouraging about progress.
        """
        
        // Use OpenAI helper function
        makeOpenAIRequest(prompt: prompt) { result in
            switch result {
            case .success(let text):
                completion(text)
            case .failure(let error):
                print("AIService: Meal analysis error: \(error)")
                completion("Unable to generate meal analysis at this time.")
            }
        }
    }
    
    // MARK: - Recipe Analysis
    func analyzeRecipe(_ recipe: Recipe, completion: @escaping (Result<FoodAnalysis, Error>) -> Void) {
        print("AIService: Starting recipe analysis for '\(recipe.title)'")
        
        // Convert recipe to analysis format: combine title + ingredients
        var recipeText = recipe.title
        
        // Add ingredients from ingredientsText if available
        if let ingredientsText = recipe.ingredientsText, !ingredientsText.isEmpty {
            recipeText += "\n\nIngredients:\n\(ingredientsText)"
        } else if !recipe.ingredients.isEmpty {
            // Fallback to structured ingredients
            let ingredientList = recipe.ingredients.flatMap { $0.ingredients }
                .map { "\($0.amount) \($0.unit ?? "") \($0.name)".trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
            recipeText += "\n\nIngredients:\n\(ingredientList)"
        }
        
        // Use analyzeFoodWithProfile with 45 second timeout for recipe analysis (longer due to complexity)
        analyzeFoodWithProfile(recipeText, healthProfile: nil, timeout: 45.0, completion: completion)
    }
    
    // MARK: - Motivational Message Generation
    func generateMotivationalMessage(
        averageScore: Int,
        category: MessageCategory,
        mealCount: Int,
        todayMeals: [TrackedMeal],
        suggestedMeal: TrackedMeal?,
        suggestedRecipe: Recipe?,
        timeFrameDescription: String,
        previousMessages: [String]
    ) async throws -> String {
        let bestMealToday = todayMeals.max(by: { $0.healthScore < $1.healthScore })
        let bestMealName = bestMealToday?.name ?? ""
        let bestMealScore = bestMealToday != nil ? Int(bestMealToday!.healthScore) : 0
        
        let suggestedMealText: String
        if let recipe = suggestedRecipe {
            // Use favorite recipe (4-5 stars)
            suggestedMealText = "Suggested favorite recipe: \(recipe.title) (rated \(Int(recipe.rating)) stars) - the user clearly loves this recipe"
        } else if let suggested = suggestedMeal {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            suggestedMealText = "Suggested meal: \(suggested.name) scored \(Int(suggested.healthScore)) on \(dateFormatter.string(from: suggested.timestamp))"
        } else {
            suggestedMealText = ""
        }
        
        let previousMessagesText = previousMessages.isEmpty ? "" : "Previous messages to avoid repeating: \(previousMessages.joined(separator: " | "))"
        
        var prompt = ""
        
        switch category {
        case .exceptional:
            prompt = """
            Generate an enthusiastic 2-3 sentence motivational message for someone who ate very healthily \(timeFrameDescription) (average score: \(averageScore)).
            
            Choose ONE approach:
            
            Option A - Use one of these verified quotes with correct attribution:
            - 'Let food be thy medicine and medicine be thy food.' —Hippocrates
            - 'Take care of your body. It's the only place you have to live.' —Jim Rohn  
            - 'The groundwork of all happiness is health.' —Leigh Hunt
            - 'He who takes medicine and neglects to diet wastes the skill of his doctors.' —Chinese Proverb
            
            Option B - Use warm, colloquial encouragement like:
            - 'You absolutely crushed it today! This is the kind of eating that makes your body feel amazing.'
            - 'Wow, you're on fire! These are the meals that fuel champions.'
            - 'This is what winning looks like! You treated your body like the temple it is.'
            - 'You're in the zone! Days like this are when your body repairs, rebuilds, and thrives.'
            - 'Look at you, making your kitchen your pharmacy! These choices are pure gold.'
            
            Option C - Reference Mediterranean/Blue Zone principles (WITHOUT inventing statistics):
            - 'Your eating pattern mirrors the Mediterranean approach that supports longevity'
            - 'You're eating like the world's healthiest populations'
            
            FORBIDDEN: Do NOT make up statistics, percentages, or specific health claims.
            Tone: Warm, supportive, encouraging, conversational. Use friendly language and understanding.
            Length: 2-3 sentences maximum
            \(previousMessagesText)
            """
            
        case .great:
            prompt = """
            Generate a supportive 2-3 sentence message for someone who ate moderately well \(timeFrameDescription) (average score: \(averageScore)).
            
            Use encouraging, realistic language like:
            - 'Pretty solid day! You're doing better than you think.'
            - 'You're on the right track! Not perfect, but honestly, who is?'
            - 'Hey, this is what real life looks like - some great choices mixed with some treats.'
            
            \(bestMealName.isEmpty ? "" : "Include reference to a high-scoring meal if available: \(bestMealName) scored \(bestMealScore)")
            
            Tone: Warm, supportive, encouraging, conversational. Use friendly language and understanding.
            Length: 2-3 sentences maximum
            \(previousMessagesText)
            """
            
        case .good:
            prompt = """
            Generate a supportive 2-3 sentence message for someone who ate moderately well \(timeFrameDescription) (average score: \(averageScore)).
            
            Use encouraging, realistic language like:
            - 'Pretty solid day! You're doing better than you think.'
            - 'You're on the right track! Not perfect, but honestly, who is?'
            - 'Hey, this is what real life looks like - some great choices mixed with some treats.'
            
            \(bestMealName.isEmpty ? "" : "Include reference to a high-scoring meal if available: \(bestMealName) scored \(bestMealScore)")
            
            Tone: Warm, supportive, encouraging, conversational. Use friendly language and understanding.
            Length: 2-3 sentences maximum
            \(previousMessagesText)
            """
            
        case .needsEncouragement:
            prompt = """
            Generate a compassionate 2-3 sentence message for someone who didn't eat well \(timeFrameDescription) (average score: \(averageScore)).
            
            Use understanding, non-judgmental language like:
            - 'Hey, rough food \(timeFrameDescription == "today" ? "day" : "period")? We've all been there. \(timeFrameDescription == "today" ? "Tomorrow's" : "Next time is") a clean slate!'
            - 'Life got in the way of perfect eating \(timeFrameDescription) - totally normal!'
            - 'Pizza happened? Ice cream called your name? No judgment here!'
            - '\(timeFrameDescription.capitalized) was about survival, not optimal nutrition - and that's perfectly valid!'
            - 'Sometimes you eat for your soul, not your cells - and that's part of being human.'
            
            MUST include reference to user's previous high-scoring meal: 
            \(suggestedMealText.isEmpty ? "No previous high-scoring meal available" : suggestedMealText)
            
            NEVER shame, lecture, or use guilt.
            Tone: Warm, supportive, encouraging, conversational. Use friendly language and understanding.
            Length: 2-3 sentences maximum
            \(previousMessagesText)
            """
        }
        
        let text = try await makeOpenAIRequestAsync(prompt: prompt)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Research Insights Generation
}

// MARK: - Message Category (shared between MealTrackingView and AIService)
enum MessageCategory {
    case exceptional // 80+
    case great // 70-79
    case good // 60-69
    case needsEncouragement // <60
}

// MARK: - Response Models
struct SimilarFoodsResponse: Codable {
    let suggestions: [PetFoodSuggestion]
}


