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
                            // CRITICAL: Copy suggestions from existing cache entry before saving
                            var analysisToSave = analysis
                            
                            // Try to get suggestions from the existing cache entry (by currentImageHash or foodName)
                            if let currentHash = currentImageHash,
                               let existingEntry = foodCacheManager.cachedAnalyses.first(where: { $0.imageHash == currentHash }),
                               let existingSuggestions = existingEntry.fullAnalysis.suggestions,
                               !existingSuggestions.isEmpty {
                                // Copy suggestions from existing entry
                                analysisToSave = FoodAnalysis(
                                    foodName: analysis.foodName,
                                    overallScore: analysis.overallScore,
                                    summary: analysis.summary,
                                    healthScores: analysis.healthScores,
                                    keyBenefits: analysis.keyBenefits,
                                    ingredients: analysis.ingredients,
                                    bestPreparation: analysis.bestPreparation,
                                    servingSize: analysis.servingSize,
                                    nutritionInfo: analysis.nutritionInfo,
                                    scanType: analysis.scanType,
                                    foodNames: analysis.foodNames,
                                    suggestions: existingSuggestions, // Copy suggestions!
                                    dataCompleteness: analysis.dataCompleteness,
                                    analysisTimestamp: analysis.analysisTimestamp,
                                    dataSource: analysis.dataSource,
                                    ingredientAnalyses: analysis.ingredientAnalyses,
                                    drugInteractions: analysis.drugInteractions,
                                    overallResearchScore: analysis.overallResearchScore,
                                    secondaryDetails: analysis.secondaryDetails,
                                    healthGoalsEvaluation: analysis.healthGoalsEvaluation
                                )
                                print("📦 SUPPLEMENT: Copied \(existingSuggestions.count) suggestions from existing cache entry (onTrack)")
                            } else if let existingSuggestions = analysis.suggestions, !existingSuggestions.isEmpty {
                                print("📦 SUPPLEMENT: Analysis already has \(existingSuggestions.count) suggestions (onTrack)")
                            } else {
                                // Try to find by foodName as fallback
                                let normalizedName = FoodAnalysis.normalizeInput(analysis.foodName)
                                if let existingEntry = foodCacheManager.cachedAnalyses.first(where: { 
                                    FoodAnalysis.normalizeInput($0.foodName) == normalizedName && 
                                    $0.fullAnalysis.suggestions != nil && 
                                    !($0.fullAnalysis.suggestions?.isEmpty ?? true)
                                }) {
                                    if let existingSuggestions = existingEntry.fullAnalysis.suggestions {
                                        analysisToSave = FoodAnalysis(
                                            foodName: analysis.foodName,
                                            overallScore: analysis.overallScore,
                                            summary: analysis.summary,
                                            healthScores: analysis.healthScores,
                                            keyBenefits: analysis.keyBenefits,
                                            ingredients: analysis.ingredients,
                                            bestPreparation: analysis.bestPreparation,
                                            servingSize: analysis.servingSize,
                                            nutritionInfo: analysis.nutritionInfo,
                                            scanType: analysis.scanType,
                                            foodNames: analysis.foodNames,
                                            suggestions: existingSuggestions, // Copy suggestions!
                                            dataCompleteness: analysis.dataCompleteness,
                                            analysisTimestamp: analysis.analysisTimestamp,
                                            dataSource: analysis.dataSource,
                                            ingredientAnalyses: analysis.ingredientAnalyses,
                                            drugInteractions: analysis.drugInteractions,
                                            overallResearchScore: analysis.overallResearchScore,
                                            secondaryDetails: analysis.secondaryDetails,
                                            healthGoalsEvaluation: analysis.healthGoalsEvaluation
                                        )
                                        print("📦 SUPPLEMENT: Copied \(existingSuggestions.count) suggestions from entry found by foodName (onTrack)")
                                    }
                                }
                            }
                            
                            // Store front label image (this is what appears in the grid)
                            foodCacheManager.saveImage(frontLabel, forHash: frontLabelHash)
                            // Cache analysis with front label image hash for grid display (now includes suggestions)
                            foodCacheManager.cacheAnalysis(analysisToSave, imageHash: frontLabelHash, scanType: scanType.rawValue, inputMethod: nil)
                            print("📦 SUPPLEMENT: Saved analysis with front label image to grid (onTrack, has suggestions: \(analysisToSave.suggestions?.count ?? 0))")
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
                            // CRITICAL: Copy suggestions from existing cache entry before saving
                            // The analysis was cached with imageHash (facts image), but suggestions were added later
                            // We need to preserve those suggestions when creating the new entry with frontLabelHash
                            var analysisToSave = analysis
                            
                            // Try to get suggestions from the existing cache entry (by currentImageHash or foodName)
                            if let currentHash = currentImageHash,
                               let existingEntry = foodCacheManager.cachedAnalyses.first(where: { $0.imageHash == currentHash }),
                               let existingSuggestions = existingEntry.fullAnalysis.suggestions,
                               !existingSuggestions.isEmpty {
                                // Copy suggestions from existing entry
                                analysisToSave = FoodAnalysis(
                                    foodName: analysis.foodName,
                                    overallScore: analysis.overallScore,
                                    summary: analysis.summary,
                                    healthScores: analysis.healthScores,
                                    keyBenefits: analysis.keyBenefits,
                                    ingredients: analysis.ingredients,
                                    bestPreparation: analysis.bestPreparation,
                                    servingSize: analysis.servingSize,
                                    nutritionInfo: analysis.nutritionInfo,
                                    scanType: analysis.scanType,
                                    foodNames: analysis.foodNames,
                                    suggestions: existingSuggestions, // Copy suggestions!
                                    dataCompleteness: analysis.dataCompleteness,
                                    analysisTimestamp: analysis.analysisTimestamp,
                                    dataSource: analysis.dataSource,
                                    ingredientAnalyses: analysis.ingredientAnalyses,
                                    drugInteractions: analysis.drugInteractions,
                                    overallResearchScore: analysis.overallResearchScore,
                                    secondaryDetails: analysis.secondaryDetails,
                                    healthGoalsEvaluation: analysis.healthGoalsEvaluation
                                )
                                print("📦 SUPPLEMENT: Copied \(existingSuggestions.count) suggestions from existing cache entry")
                            } else if let existingSuggestions = analysis.suggestions, !existingSuggestions.isEmpty {
                                // Analysis already has suggestions (loaded synchronously)
                                print("📦 SUPPLEMENT: Analysis already has \(existingSuggestions.count) suggestions")
                            } else {
                                // Try to find by foodName as fallback
                                let normalizedName = FoodAnalysis.normalizeInput(analysis.foodName)
                                if let existingEntry = foodCacheManager.cachedAnalyses.first(where: { 
                                    FoodAnalysis.normalizeInput($0.foodName) == normalizedName && 
                                    $0.fullAnalysis.suggestions != nil && 
                                    !($0.fullAnalysis.suggestions?.isEmpty ?? true)
                                }) {
                                    if let existingSuggestions = existingEntry.fullAnalysis.suggestions {
                                        analysisToSave = FoodAnalysis(
                                            foodName: analysis.foodName,
                                            overallScore: analysis.overallScore,
                                            summary: analysis.summary,
                                            healthScores: analysis.healthScores,
                                            keyBenefits: analysis.keyBenefits,
                                            ingredients: analysis.ingredients,
                                            bestPreparation: analysis.bestPreparation,
                                            servingSize: analysis.servingSize,
                                            nutritionInfo: analysis.nutritionInfo,
                                            scanType: analysis.scanType,
                                            foodNames: analysis.foodNames,
                                            suggestions: existingSuggestions, // Copy suggestions!
                                            dataCompleteness: analysis.dataCompleteness,
                                            analysisTimestamp: analysis.analysisTimestamp,
                                            dataSource: analysis.dataSource,
                                            ingredientAnalyses: analysis.ingredientAnalyses,
                                            drugInteractions: analysis.drugInteractions,
                                            overallResearchScore: analysis.overallResearchScore,
                                            secondaryDetails: analysis.secondaryDetails,
                                            healthGoalsEvaluation: analysis.healthGoalsEvaluation
                                        )
                                        print("📦 SUPPLEMENT: Copied \(existingSuggestions.count) suggestions from entry found by foodName")
                                    }
                                }
                            }
                            
                            // Store front label image (this is what appears in the grid)
                            foodCacheManager.saveImage(frontLabel, forHash: frontLabelHash)
                            // Cache analysis with front label image hash for grid display (now includes suggestions)
                            foodCacheManager.cacheAnalysis(analysisToSave, imageHash: frontLabelHash, scanType: scanType.rawValue, inputMethod: nil)
                            print("📦 SUPPLEMENT: Saved analysis with front label image to grid (has suggestions: \(analysisToSave.suggestions?.count ?? 0))")
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
        request.timeoutInterval = 45.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Get user health profile for personalization
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let top3Goals = Array(healthGoals.prefix(3))
        let healthGoalsText = top3Goals.isEmpty ? "general health and longevity" : top3Goals.joined(separator: ", ")
        
        print("📦 SUPPLEMENT: Sending simplified primary request")
        
        // Simplified prompt for fast response (8-12 seconds)
        let prompt = """
        You are a precision supplement analysis system. Analyze these supplement images and return ONLY valid JSON.

        🚫 CRITICAL PROHIBITION:
        NEVER mention age, gender, or demographics. Use ONLY "your", "you", "your body", "your goals".

        IMAGE INSTRUCTIONS:
        - Image 1 is the FRONT of the supplement bottle - extract the product name and brand
        - Image 2 is the SUPPLEMENT FACTS panel - extract all ingredients with amounts

        🚫 ACCURACY RULES:
        - ONLY list ingredients VISIBLE on the Supplement Facts panel
        - NEVER guess or add ingredients not shown on label
        - Include branded names if visible (e.g., "Hydro Q-Sorb®", "CalaMarine®", "Crominex® 3+")
        - Include exact amounts with units (e.g., "100mg", "680mcg DFE")
        - If you cannot read an ingredient clearly, do NOT include it

        📝 SUMMARY REQUIREMENTS (RESEARCH-BASED):
        Write a specific, research-based summary. Be precise about:
        - Exact ingredient forms and WHY they matter (e.g., "ubiquinone form for enhanced absorption")
        - Exact dosages compared to clinical ranges (e.g., "100mg is within the 100-200mg clinical range")
        - Specific research claims (e.g., "shown to support mitochondrial function in heart tissue")
        - What's good AND what's lacking (e.g., "Omega-3 dose is below the 1000-2000mg used in cardiovascular studies")

        DO NOT write generic statements like:
        - "provides strong support for heart health" ❌
        - "may interact with certain medications" ❌
        - "should be used with caution" ❌

        DO write specific statements like:
        - "CoQ10 (100mg ubiquinone, Hydro Q-Sorb® form) is within the clinical range shown to support mitochondrial ATP production" ✅
        - "Omega-3 dose (550mg) is below the 1000-2000mg typically used in cardiovascular outcome studies" ✅

        🎯 HEALTH GOALS EVALUATION:
        For each of the user's health goals (\(healthGoalsText)), evaluate if this supplement:
        - ✅ Strongly supports (score 70+)
        - ⚠️ Partially supports or has limitations (score 40-69)
        - ❌ Does not support (score below 40)

        Return ONLY this JSON structure:
        {
            "scanType": "supplement",
            "foodName": "Product Name from front label",
            "overallScore": 0-100,
            "summary": "Research-based summary as described above. 3-4 sentences covering: 1) Key ingredients with forms and amounts, 2) How dosages compare to clinical ranges, 3) Specific benefits with research basis, 4) Any limitations or concerns. End with: No known recalls or safety hazards (or state if there are any).",
            "healthScores": {
                "heartHealth": 0-100,
                "brainHealth": 0-100,
                "energy": 0-100,
                "sleep": 0-100,
                "immune": 0-100,
                "jointHealth": 0-100,
                "bloodSugar": 0-100,
                "antiInflammation": 0-100,
                "mood": 0-100,
                "stress": 0-100,
                "skin": 0-100,
                "eyeHealth": 0-100,
                "detoxLiver": 0-100,
                "kidneys": 0-100,
                "weightManagement": 0-100,
                "allergies": 0-100
            },
            "servingSize": "From label (e.g., 2 softgels)",
            "ingredients": [
                {"name": "CoQ10 (Hydro Q-Sorb®)", "amount": "100mg"},
                {"name": "Omega-3 (CalaMarine®)", "amount": "550mg"}
            ],
            "healthGoalsEvaluation": [
                {"goal": "Heart health", "status": "supports", "score": 92},
                {"goal": "Brain health", "status": "supports", "score": 88},
                {"goal": "Blood sugar control", "status": "limited", "score": 45}
            ]
        }

        IMPORTANT:
        - Keep response concise for speed
        - Do NOT include research scores per ingredient (loaded separately)
        - Do NOT include drug interactions (loaded separately)
        - Do NOT include key benefits array (loaded separately)
        - Focus on accurate ingredient extraction and SPECIFIC, RESEARCH-BASED summary
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
        
        print("📦 SUPPLEMENT: Primary analysis received")
        print("📦 SUPPLEMENT: Ingredients count: \(analysis.ingredients?.count ?? 0)")
        print("📦 SUPPLEMENT: Health goals evaluation count: \(analysis.healthGoalsEvaluation?.count ?? 0)")
        
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
