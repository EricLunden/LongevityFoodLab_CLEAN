import SwiftUI
import Foundation
import UIKit

struct SupplementsView: View {
    @State private var showingSideMenu = false
    @State private var showingScanner = false
    @State private var showingScanResult = false
    @State private var capturedImage: UIImage? // Barcode scan image (for analysis)
    @State private var frontLabelImage: UIImage? // Front label image (for grid display)
    @State private var scanResultAnalysis: FoodAnalysis?
    @State private var scanResultBestPreparation: String? = nil // Not used for supplements, but required for ScanResultView
    @State private var scanType: ScanType = .supplement
    @State private var needsBackScan = false
    @State private var currentImageHash: String? // Hash for barcode image (analysis)
    @State private var frontLabelImageHash: String? // Hash for front label image (grid)
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    
    var body: some View {
        NavigationView {
            SupplementsTabView(
                onScanTapped: {
                    showingScanner = true
                },
                showingSideMenu: $showingSideMenu
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSideMenu.toggle()
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title3)
                            .fontWeight(.light)
                            .foregroundColor(.primary)
                            .padding(.leading, 8)
                    }
                }
            })
            .overlay(
                Group {
                    if showingSideMenu {
                        SideMenuView(isPresented: $showingSideMenu)
                            .transition(.move(edge: .leading))
                            .animation(.easeInOut(duration: 0.3), value: showingSideMenu)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ScannerViewController(
                isPresented: $showingScanner,
                mode: .supplements,
                onBarcodeCaptured: { _, _ in },      // Not used for supplements
                onFrontLabelCaptured: { _ in },       // Not used for supplements
                onSupplementScanComplete: { frontImage, factsImage in
                    print("📦 SUPPLEMENT: Both images received")
                    
                    // Store front image for display in grid
                    self.frontLabelImage = frontImage
                    if let imageData = frontImage.jpegData(compressionQuality: 0.8) {
                        self.frontLabelImageHash = FoodCacheManager.hashImage(imageData)
                    }
                    print("💾 SUPPLEMENT: Front label saved for display")
                    
                    // Store supplement facts image for analysis
                    self.capturedImage = factsImage
                    
                    // Analyze with BOTH images
                    self.analyzeSupplementWithBothImages(frontImage: frontImage, factsImage: factsImage)
                    
                    self.showingScanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.showingScanResult = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingScanResult) {
            if let analysis = scanResultAnalysis {
                ScanResultView(
                    scanType: scanType,
                    analysis: analysis,
                    bestPreparation: $scanResultBestPreparation,
                    image: frontLabelImage ?? capturedImage, // Show front label if available, otherwise barcode image
                    isAnalyzing: false,
                    needsBackScan: needsBackScan,
                    onTrack: {
                        // Track supplement to meal tracker if needed
                        // Only save if front label image was captured (required for grid display)
                        if let analysis = scanResultAnalysis, let frontLabel = frontLabelImage, let frontLabelHash = frontLabelImageHash {
                            // Store front label image (this is what appears in the grid)
                            foodCacheManager.saveImage(frontLabel, forHash: frontLabelHash)
                            // Cache analysis with front label image hash for grid display
                            foodCacheManager.cacheAnalysis(analysis, imageHash: frontLabelHash, scanType: scanType.rawValue, inputMethod: nil)
                            print("SupplementsView: Saved analysis with front label image to grid")
                        } else {
                            print("SupplementsView: Cannot save - front label image not captured yet")
                        }
                        showingScanResult = false
                        currentImageHash = nil
                        frontLabelImageHash = nil
                        capturedImage = nil
                        frontLabelImage = nil
                    },
                    onSave: {
                        // Save supplement analysis - use front label image for grid display
                        // Only save if front label image was captured (required for grid display)
                        if let analysis = scanResultAnalysis, let frontLabel = frontLabelImage, let frontLabelHash = frontLabelImageHash {
                            // Store front label image (this is what appears in the grid)
                            foodCacheManager.saveImage(frontLabel, forHash: frontLabelHash)
                            // Cache analysis with front label image hash for grid display
                            foodCacheManager.cacheAnalysis(analysis, imageHash: frontLabelHash, scanType: scanType.rawValue, inputMethod: nil)
                            print("SupplementsView: Saved analysis with front label image to grid")
                        } else {
                            print("SupplementsView: Cannot save - front label image not captured yet")
                        }
                        showingScanResult = false
                        currentImageHash = nil
                        frontLabelImageHash = nil
                        capturedImage = nil
                        frontLabelImage = nil
                    },
                    onScanAgain: {
                        showingScanResult = false
                        scanResultAnalysis = nil
                        scanResultBestPreparation = nil
                        capturedImage = nil
                        frontLabelImage = nil
                        currentImageHash = nil
                        frontLabelImageHash = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingScanner = true
                        }
                    },
                    onDismiss: {
                        showingScanResult = false
                    }
                )
            } else {
                // Loading state
                ScanResultView(
                    scanType: scanType,
                    analysis: nil,
                    bestPreparation: $scanResultBestPreparation,
                    image: frontLabelImage ?? capturedImage, // Show front label if available, otherwise barcode image
                    isAnalyzing: true,
                    needsBackScan: false,
                    onTrack: { },
                    onSave: { },
                    onScanAgain: {
                        showingScanResult = false
                        showingScanner = true
                    },
                    onDismiss: {
                        showingScanResult = false
                    }
                )
            }
        }
    }
    
    // MARK: - Scanner Functions
    
    private func analyzeScannedImage(_ image: UIImage, barcode: String? = nil) {
        print("SupplementsView: Starting image analysis, barcode: \(barcode ?? "none")")
        
        // Reset state
        scanResultAnalysis = nil
        needsBackScan = false
        scanType = .supplement
        
        // Phase 1: Barcode detection complete - barcode is now available
        // Phase 2: Will use barcode if supplement lookup APIs are added
        
        // Optimize image for supplements (high quality: 1280px @ 0.85 quality)
        guard let imageData = image.optimizedForSupplements() else {
            print("SupplementsView: Failed to optimize image")
            showingScanResult = false
            return
        }
        
        // Generate image hash for caching
        let imageHash = FoodCacheManager.hashImage(imageData)
        currentImageHash = imageHash
        
        let sizeKB = Double(imageData.count) / 1024.0
        print("📦 SUPPLEMENT SCAN: Image size \(String(format: "%.1f", sizeKB)) KB, max_tokens: 2500")
        print("SupplementsView: Image hash: \(imageHash)")
        
        // Pre-save image to disk cache immediately (before API call)
        foodCacheManager.saveImage(image, forHash: imageHash)
        
        // Check cache first
        if let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
            print("SupplementsView: Found cached analysis, score: \(cachedAnalysis.overallScore)")
            scanResultAnalysis = cachedAnalysis
            determineScanTypeAndBackScanNeeded(analysis: cachedAnalysis)
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        print("SupplementsView: Image converted to base64, length: \(base64Image.count)")
        
        // Call OpenAI Vision API
        Task {
            do {
                print("SupplementsView: Calling OpenAI Vision API")
                let analysis = try await analyzeImageWithOpenAI(base64Image: base64Image, imageHash: imageHash)
                
                await MainActor.run {
                    print("SupplementsView: Analysis received, score: \(analysis.overallScore)")
                    scanResultAnalysis = analysis
                    determineScanTypeAndBackScanNeeded(analysis: analysis)
                    
                    // Cache the analysis with image hash
                    foodCacheManager.cacheAnalysis(analysis, imageHash: imageHash)
                }
            } catch {
                print("SupplementsView: Analysis failed: \(error.localizedDescription)")
                await MainActor.run {
                    showingScanResult = false
                }
            }
        }
    }
    
    private func analyzeImageWithOpenAI(base64Image: String, imageHash: String) async throws -> FoodAnalysis {
        // Use the same analysis approach as ContentView - it already handles supplements
        // We'll use the ImageAnalysisService or replicate the logic
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Get user health profile for personalization
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let top3Goals = Array(healthGoals.prefix(3))
        let healthGoalsText = top3Goals.isEmpty ? "general health and longevity" : top3Goals.joined(separator: ", ")
        
        // Use the exact same comprehensive prompt as ContentView (it handles all scan types including supplements)
        // This ensures consistent analysis quality
        let prompt = """
        You are a precision nutrition analysis system. Analyze this image and return ONLY valid JSON.

        🚫 CRITICAL PROHIBITION - READ THIS FIRST:
        NEVER mention age, gender, or demographics in the summary. Examples of FORBIDDEN phrases:
        - "young male", "young female", "adult", "elderly"
        - "men", "women", "males", "females"
        - "under 30", "over 50", any age reference
        - "particularly beneficial for a [demographic]"
        - "especially for [demographic]"
        
        If you see these terms in your response, DELETE THEM. Use ONLY "your", "you", "your body", "your goals" - never demographic terms.

        STEP 1: Identify the scan type (CRITICAL - determines how item is stored):
        - "supplement" = supplement bottle/package
        - "supplement_facts" = supplement facts panel only
        
        FOR SUPPLEMENTS (scanType = "supplement" or "supplement_facts"):
        - Read ALL values from visible supplement facts labels
        - Identify active ingredients and their dosages
        - Note any fillers, binders, or additives
        - Check for potential interactions or warnings
        - The "summary" field must be exactly 3 sentences:
          1. First sentence: Strengths and benefits for common health concerns
          2. Second sentence: Weaknesses, limitations, or concerns for health
          3. Third sentence: Any recalls, safety warnings, or hazards (if none, state "No known recalls or safety hazards")
        - Example: "This supplement provides strong antioxidant support and may benefit heart health. However, it may interact with blood-thinning medications and is not recommended during pregnancy. No known recalls or safety hazards have been reported."

        Extract nutritional data from the image:
        - For supplements: Read ALL values from visible supplement facts labels

        Return ONLY this JSON structure (no markdown, no explanation). The JSON should have these fields:
        - scanType: "supplement" or "supplement_facts"
        - foodName: Supplement name from label
        - needsBackScan: false
        - overallScore: 0-100
        - summary: Provide comprehensive analysis including: 1) Product overview and key ingredients with exact amounts, 2) Ingredient form quality assessment (e.g., magnesium citrate vs oxide), 3) Dosage evaluation compared to recommended daily values, 4) Bioavailability considerations, 5) Strengths and benefits, 6) Weaknesses or concerns, 7) Any recalls or warnings (if none, state so), 8) Impact on your health goals: \(healthGoalsText). Be thorough and detailed. Use 'your' not 'the user's'.
        - healthScores: Object with allergies, antiInflammation, bloodSugar, brainHealth, detoxLiver, energy, eyeHealth, heartHealth, immune, jointHealth, kidneys, mood, skin, sleep, stress, weightManagement (each 0-100)
        - servingSize: Typical serving size from label
        """
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 2500,
            "temperature": 0.1,
            "response_format": [
                "type": "json_object"
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: nil)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw NSError(domain: "Invalid response format", code: 0, userInfo: nil)
        }
        
        // Strip markdown code blocks if present
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
        
        guard let analysisData = cleanedText.data(using: .utf8) else {
            throw NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)
        }
        
        // Parse scan type from response and decode analysis
        let responseDict = try JSONSerialization.jsonObject(with: analysisData) as? [String: Any]
        let scanTypeString = responseDict?["scanType"] as? String
        let parsedNeedsBackScan = responseDict?["needsBackScan"] as? Bool ?? false
        
        print("SupplementsView: Step 1 complete - scanType: \(scanTypeString ?? "nil"), supplementName: \(responseDict?["foodName"] as? String ?? "unknown")")
        
        // Decode analysis with scanType
        var analysis = try JSONDecoder().decode(FoodAnalysis.self, from: analysisData)
        
        // If scanType wasn't in the decoded struct, add it manually
        if analysis.scanType == nil, let scanTypeString = scanTypeString {
            analysis = FoodAnalysis(
                foodName: analysis.foodName,
                overallScore: analysis.overallScore,
                summary: analysis.summary,
                healthScores: analysis.healthScores,
                keyBenefits: analysis.keyBenefits,
                ingredients: analysis.ingredients,
                bestPreparation: analysis.bestPreparation,
                servingSize: analysis.servingSize,
                nutritionInfo: analysis.nutritionInfo,
                scanType: scanTypeString,
                foodNames: analysis.foodNames,
                suggestions: analysis.suggestions,
                dataCompleteness: analysis.dataCompleteness,
                analysisTimestamp: analysis.analysisTimestamp,
                dataSource: analysis.dataSource,
                ingredientAnalyses: analysis.ingredientAnalyses,
                drugInteractions: analysis.drugInteractions,
                overallResearchScore: analysis.overallResearchScore,
                secondaryDetails: analysis.secondaryDetails
            )
        }
        
        needsBackScan = parsedNeedsBackScan
        
        return analysis
    }
    
    private func analyzeSupplementWithBothImages(frontImage: UIImage, factsImage: UIImage) {
        print("📦 SUPPLEMENT: Starting dual-image analysis")
        
        // Reset state
        scanResultAnalysis = nil
        needsBackScan = false
        scanType = .supplement
        
        // Optimize both images
        guard let frontData = frontImage.optimizedForSupplements(),
              let factsData = factsImage.optimizedForSupplements() else {
            print("❌ SUPPLEMENT: Failed to optimize images")
            showingScanResult = false
            return
        }
        
        let frontBase64 = frontData.base64EncodedString()
        let factsBase64 = factsData.base64EncodedString()
        
        let frontSizeKB = Double(frontData.count) / 1024.0
        let factsSizeKB = Double(factsData.count) / 1024.0
        print("📦 SUPPLEMENT: Front image \(String(format: "%.1f", frontSizeKB)) KB")
        print("📦 SUPPLEMENT: Facts image \(String(format: "%.1f", factsSizeKB)) KB")
        
        // Generate hash for caching (use facts image as primary key)
        let imageHash = FoodCacheManager.hashImage(factsData)
        currentImageHash = imageHash
        print("📦 SUPPLEMENT: Image hash: \(imageHash)")
        
        // Pre-save front image to disk cache for display
        if let frontLabelHash = frontLabelImageHash {
            foodCacheManager.saveImage(frontImage, forHash: frontLabelHash)
        }
        
        // Check cache first
        if let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
            print("📦 SUPPLEMENT: Found cached analysis, score: \(cachedAnalysis.overallScore)")
            scanResultAnalysis = cachedAnalysis
            determineScanTypeAndBackScanNeeded(analysis: cachedAnalysis)
            return
        }
        
        // Call API with both images
        Task {
            do {
                let analysis = try await analyzeWithOpenAI(frontBase64: frontBase64, factsBase64: factsBase64, imageHash: imageHash)
                
                await MainActor.run {
                    print("📦 SUPPLEMENT: Analysis received, score: \(analysis.overallScore)")
                    scanResultAnalysis = analysis
                    determineScanTypeAndBackScanNeeded(analysis: analysis)
                    
                    // Cache the analysis with image hash
                    foodCacheManager.cacheAnalysis(analysis, imageHash: imageHash, scanType: scanType.rawValue, inputMethod: nil)
                }
            } catch {
                print("📦 SUPPLEMENT: Analysis failed: \(error.localizedDescription)")
                await MainActor.run {
                    showingScanResult = false
                }
            }
        }
    }
    
    private func analyzeWithOpenAI(frontBase64: String, factsBase64: String, imageHash: String) async throws -> FoodAnalysis {
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Get user health profile for personalization
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let top3Goals = Array(healthGoals.prefix(3))
        let healthGoalsText = top3Goals.isEmpty ? "general health and longevity" : top3Goals.joined(separator: ", ")
        
        // Enhanced prompt for Stage 2 - requests ingredientAnalyses and drugInteractions
        let prompt = """
        You are a precision nutrition analysis system. Analyze these supplement images and return ONLY valid JSON.

        🚫 CRITICAL PROHIBITION:
        NEVER mention age, gender, or demographics. Use ONLY "your", "you", "your body", "your goals".

        IMAGE INSTRUCTIONS:
        - Image 1 is the FRONT of the supplement bottle - extract the product name and brand
        - Image 2 is the SUPPLEMENT FACTS panel - extract ALL ingredients with exact amounts and forms

        🚫 CRITICAL ACCURACY RULES:
        - ONLY list ingredients that are VISIBLE on the Supplement Facts panel
        - NEVER guess or assume ingredients that are not shown
        - Include branded/trademarked ingredient names exactly as shown (e.g., "Crominex® 3+", "CalaMarine®", "Hydro Q-Sorb®")
        - Include the specific form in parentheses if shown (e.g., "as ubiquinone", "as pyridoxine hydrochloride")
        - Include exact amounts from the label with units (e.g., "100mg", "680mcg DFE")
        - If you cannot read an ingredient clearly, do NOT include it
        - DO NOT add common supplements that are not on the label

        RESEARCH SCORE CRITERIA (1-100):
        Rate each ingredient based on quality and quantity of human research:
        - 90-100 (Gold Standard): Large high-quality RCT OR meta-analysis with clear positive findings OR extensive research (10+ quality studies) + long safety history
        - 75-89 (Strong Evidence): Multiple quality human studies with consistent results, OR one excellent RCT, OR centuries of traditional use + modern mechanistic understanding
        - 60-74 (Good Evidence): Several small human studies with positive results + plausible mechanism + good safety profile
        - 40-59 (Emerging Evidence): 1-2 small human studies with promising results, OR strong animal data + early human trials
        - 20-39 (Limited Evidence): Animal/cell studies only, but strong mechanistic rationale
        - 1-19 (Insufficient Evidence): Minimal research, theoretical benefits only

        Quality factors that INCREASE score:
        - Gold-standard RCT (double-blind, placebo-controlled)
        - Meta-analysis or systematic review
        - Long history of safe use (50+ years)
        - Well-understood mechanism
        - Large sample sizes (500+ participants)
        - Replicated by independent labs

        Quality factors that DECREASE score:
        - Only animal/cell studies
        - Conflicting results
        - Only small sample sizes
        - Industry-funded only
        - Short study durations

        DRUG INTERACTION RULES:
        - List drug categories that may interact with ANY ingredient
        - Include: category name, specific interaction risk, severity (moderate/serious)
        - Common categories to check: Blood thinners, Statins, Blood pressure meds, Diabetes meds, Thyroid meds, Immunosuppressants, Antidepressants, Sedatives
        - Only include interactions with clinical relevance
        - If no known interactions, return empty array

        Return ONLY this JSON structure:
        {
            "scanType": "supplement",
            "foodName": "Product Name from front label",
            "overallScore": 0-100,
            "summary": "Comprehensive analysis: 1) Product overview with key ingredients and amounts, 2) Ingredient form quality assessment, 3) Dosage evaluation vs clinical ranges, 4) Bioavailability considerations, 5) Strengths and benefits, 6) Weaknesses or concerns, 7) Any recalls or warnings, 8) Impact on health goals: \(healthGoalsText). Be thorough.",
            "healthScores": {
                "allergies": 0-100,
                "antiInflammation": 0-100,
                "bloodSugar": 0-100,
                "brainHealth": 0-100,
                "detoxLiver": 0-100,
                "energy": 0-100,
                "eyeHealth": 0-100,
                "heartHealth": 0-100,
                "immune": 0-100,
                "jointHealth": 0-100,
                "kidneys": 0-100,
                "mood": 0-100,
                "skin": 0-100,
                "sleep": 0-100,
                "stress": 0-100,
                "weightManagement": 0-100
            },
            "servingSize": "From label",
            "keyBenefits": ["benefit1", "benefit2", "benefit3"],
            "ingredientAnalyses": [
                {
                    "name": "Full ingredient name with brand (e.g., Coenzyme Q10 (Hydro Q-Sorb®))",
                    "amount": "100mg",
                    "form": "ubiquinone",
                    "researchScore": 92,
                    "briefSummary": "One sentence about what this ingredient does"
                }
            ],
            "drugInteractions": [
                {
                    "drugCategory": "Blood Thinners (Warfarin, Aspirin)",
                    "interaction": "May increase bleeding risk",
                    "severity": "moderate"
                }
            ],
            "overallResearchScore": 85
        }

        IMPORTANT:
        - ingredientAnalyses must include EVERY ingredient from the Supplement Facts panel
        - Each ingredient needs a researchScore based on the criteria above
        - drugInteractions should only include clinically relevant interactions
        - overallResearchScore is the weighted average of individual ingredient scores
        """
        
        // Build message content with TWO images
        let messageContent: [[String: Any]] = [
            [
                "type": "text",
                "text": prompt
            ],
            [
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(frontBase64)"]
            ],
            [
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(factsBase64)"]
            ]
        ]
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 2500,
            "temperature": 0.1,
            "response_format": [
                "type": "json_object"
            ],
            "messages": [
                [
                    "role": "user",
                    "content": messageContent
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "HTTP Error", code: (response as? HTTPURLResponse)?.statusCode ?? 0, userInfo: nil)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw NSError(domain: "Invalid response format", code: 0, userInfo: nil)
        }
        
        // Parse content (handle both string and array formats)
        var text: String
        if let contentArray = message["content"] as? [[String: Any]] {
            // Content is array of content blocks
            text = contentArray.compactMap { block in
                if block["type"] as? String == "text",
                   let textValue = block["text"] as? String {
                    return textValue
                }
                return nil
            }.joined(separator: "\n")
        } else if let contentString = message["content"] as? String {
            text = contentString
        } else {
            throw NSError(domain: "Invalid content format", code: 0, userInfo: nil)
        }
        
        // Strip markdown code blocks if present
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
        
        guard let analysisData = cleanedText.data(using: .utf8) else {
            throw NSError(domain: "Invalid text encoding", code: 0, userInfo: nil)
        }
        
        // Parse scan type from response and decode analysis
        let responseDict = try JSONSerialization.jsonObject(with: analysisData) as? [String: Any]
        let scanTypeString = responseDict?["scanType"] as? String
        let parsedNeedsBackScan = responseDict?["needsBackScan"] as? Bool ?? false
        
        print("📦 SUPPLEMENT: Step 1 complete - scanType: \(scanTypeString ?? "nil"), supplementName: \(responseDict?["foodName"] as? String ?? "unknown")")
        
        // Decode analysis with scanType
        var analysis = try JSONDecoder().decode(FoodAnalysis.self, from: analysisData)
        
        // Log new data fields
        print("📦 SUPPLEMENT: ingredientAnalyses count: \(analysis.ingredientAnalyses?.count ?? 0)")
        print("📦 SUPPLEMENT: drugInteractions count: \(analysis.drugInteractions?.count ?? 0)")
        print("📦 SUPPLEMENT: Overall research score: \(analysis.overallResearchScore ?? 0)")
        if let ingredients = analysis.ingredientAnalyses {
            for ing in ingredients {
                print("  - \(ing.name): \(ing.researchScore) (\(ing.researchRating))")
            }
        }
        
        // If scanType wasn't in the decoded struct, add it manually
        if analysis.scanType == nil, let scanTypeString = scanTypeString {
            analysis = FoodAnalysis(
                foodName: analysis.foodName,
                overallScore: analysis.overallScore,
                summary: analysis.summary,
                healthScores: analysis.healthScores,
                keyBenefits: analysis.keyBenefits,
                ingredients: analysis.ingredients,
                bestPreparation: analysis.bestPreparation,
                servingSize: analysis.servingSize,
                nutritionInfo: analysis.nutritionInfo,
                scanType: scanTypeString,
                foodNames: analysis.foodNames,
                suggestions: analysis.suggestions,
                dataCompleteness: analysis.dataCompleteness,
                analysisTimestamp: analysis.analysisTimestamp,
                dataSource: analysis.dataSource,
                ingredientAnalyses: analysis.ingredientAnalyses,
                drugInteractions: analysis.drugInteractions,
                overallResearchScore: analysis.overallResearchScore,
                secondaryDetails: analysis.secondaryDetails
            )
        }
        
        needsBackScan = parsedNeedsBackScan
        
        return analysis
    }
    
    private func determineScanTypeAndBackScanNeeded(analysis: FoodAnalysis) {
        if let scanTypeString = analysis.scanType {
            if scanTypeString == "supplement" || scanTypeString == "supplement_facts" {
                scanType = scanTypeString == "supplement" ? .supplement : .supplement_facts
                needsBackScan = false // Supplements typically don't need back scan
            }
        }
    }
}

#Preview {
    SupplementsView()
}
