import SwiftUI
import Foundation
import UIKit

struct SupplementsView: View {
    @State private var showingSideMenu = false
    @State private var showingScanner = false
    @State private var showingScanResult = false
    @State private var capturedImage: UIImage?
    @State private var scanResultAnalysis: FoodAnalysis?
    @State private var scanType: ScanType = .supplement
    @State private var needsBackScan = false
    @State private var currentImageHash: String?
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
            .toolbar {
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
            }
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
            ScannerViewController(isPresented: $showingScanner) { image in
                print("SupplementsView: Image captured callback received")
                
                // Store image IMMEDIATELY on main thread (before dismissing camera)
                capturedImage = image
                
                // Dismiss camera FIRST
                showingScanner = false
                
                // Wait for camera to dismiss, then show results sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Show results sheet with loading state (image is already set)
                    showingScanResult = true
                    // Start analysis
                    analyzeScannedImage(image)
                }
            }
        }
        .sheet(isPresented: $showingScanResult) {
            if let analysis = scanResultAnalysis {
                ScanResultView(
                    scanType: scanType,
                    analysis: analysis,
                    image: capturedImage,
                    isAnalyzing: false,
                    needsBackScan: needsBackScan,
                    onTrack: {
                        // Track supplement to meal tracker if needed
                        showingScanResult = false
                    },
                    onSave: {
                        // Save supplement analysis
                        showingScanResult = false
                    },
                    onScanAgain: {
                        showingScanResult = false
                        showingScanner = true
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
                    image: capturedImage,
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
    
    private func analyzeScannedImage(_ image: UIImage) {
        print("SupplementsView: Starting image analysis")
        
        // Reset state
        scanResultAnalysis = nil
        needsBackScan = false
        scanType = .supplement
        
        // Optimize image (resize + compress) for faster API uploads
        guard let imageData = image.optimizedForAPI() else {
            print("SupplementsView: Failed to optimize image")
            showingScanResult = false
            return
        }
        
        // Generate image hash for caching
        let imageHash = FoodCacheManager.hashImage(imageData)
        currentImageHash = imageHash
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
        - summary: Write exactly 3 sentences: 1) Strengths and benefits, 2) Weaknesses/concerns, 3) Recalls/safety warnings. End with impact on: \(healthGoalsText). Use 'your' not 'the user's'.
        - healthScores: Object with allergies, antiInflammation, bloodSugar, brainHealth, detoxLiver, energy, eyeHealth, heartHealth, immune, jointHealth, kidneys, mood, skin, sleep, stress, weightManagement (each 0-100)
        - servingSize: Typical serving size from label
        """
        
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 500,
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
                suggestions: analysis.suggestions
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
