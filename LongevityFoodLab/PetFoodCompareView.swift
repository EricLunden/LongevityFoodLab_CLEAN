import SwiftUI
import AVFoundation
import PhotosUI
import Speech
import UIKit
import Foundation

struct PetFoodCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cacheManager = PetFoodCacheManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var food1Analysis: PetFoodAnalysis?
    @State private var food2Analysis: PetFoodAnalysis?
    @State private var food1Text: String = ""
    @State private var food2Text: String = ""
    @State private var showingComparison = false
    @State private var sortOption: PetFoodSortOption = .recency
    @State private var isAnalyzing = false
    @State private var selectedPetType: PetFoodAnalysis.PetType = .dog
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    headerView
                    
                    // Pet Type Selection
                    petTypeSelectionSection
                    
                    recentlyAnalyzedSection
                    
                    // Main content scrolls below header
                    VStack(spacing: 18) {
                        // Food 1 Section
                        VStack(alignment: .center, spacing: 16) {
                            Text("Food #1")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            if let analysis = food1Analysis {
                                // Show selected food
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(analysis.productName)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        
                                        Spacer()
                                        
                                        Button("Change") {
                                            food1Analysis = nil
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                    
                                    Text("Longevity Score: \(analysis.overallScore)/100")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            } else {
                                // Show input options
                                PetFoodInputSection(
                                    foodText: $food1Text,
                                    selectedPetType: $selectedPetType,
                                    foodNumber: 1,
                                    onFoodDetected: { text in
                                        food1Text = text
                                    },
                                    onDismiss: {
                                        dismiss()
                                    }
                                )
                            }
                        }
                        
                        // Food 2 Section
                        VStack(alignment: .center, spacing: 16) {
                            Text("Food #2")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            if let analysis = food2Analysis {
                                // Show selected food
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(analysis.productName)
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        
                                        Spacer()
                                        
                                        Button("Change") {
                                            food2Analysis = nil
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                    
                                    Text("Longevity Score: \(analysis.overallScore)/100")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                            } else {
                                // Show input options
                                PetFoodInputSection(
                                    foodText: $food2Text,
                                    selectedPetType: $selectedPetType,
                                    foodNumber: 2,
                                    onFoodDetected: { text in
                                        food2Text = text
                                    },
                                    onDismiss: {
                                        dismiss()
                                    }
                                )
                            }
                        }
                        
                        // Compare Button
                        if (food1Analysis != nil || !food1Text.isEmpty) && (food2Analysis != nil || !food2Text.isEmpty) {
                            Button(action: {
                                compareFoods()
                            }) {
                                HStack {
                                    if isAnalyzing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Analyzing...")
                                            .fontWeight(.semibold)
                                    } else {
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.title2)
                                        Text("Compare Pet Foods")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.42, green: 0.557, blue: 0.498),
                                            Color(red: 0.502, green: 0.706, blue: 0.627)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                            }
                            .disabled(isAnalyzing)
                        }
                    }
                    .padding(20)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .ignoresSafeArea(.container, edges: .top)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Compare Pet Foods")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingComparison) {
                if let food1 = food1Analysis, let food2 = food2Analysis {
                    PetFoodComparisonResultsView(food1: PetFoodCacheEntry(
                        cacheKey: "\(food1.petType.rawValue)_\(food1.brandName)_\(food1.productName)",
                        petType: food1.petType,
                        brandName: food1.brandName,
                        productName: food1.productName,
                        analysisDate: food1.analysisDate ?? Date(),
                        cacheVersion: "1.0",
                        fullAnalysis: food1
                    ), food2: PetFoodCacheEntry(
                        cacheKey: "\(food2.petType.rawValue)_\(food2.brandName)_\(food2.productName)",
                        petType: food2.petType,
                        brandName: food2.brandName,
                        productName: food2.productName,
                        analysisDate: food2.analysisDate ?? Date(),
                        cacheVersion: "1.0",
                        fullAnalysis: food2
                    ))
                }
            }
            .overlay(
                // Full-screen loading overlay
                Group {
                    if isAnalyzing {
                        LoadingView()
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: isAnalyzing)
                    }
                }
            )
        }
    }
    
    private func compareFoods() {
        // Check if we have both foods selected (either from cache or text input)
        guard (food1Analysis != nil || !food1Text.isEmpty) && (food2Analysis != nil || !food2Text.isEmpty) else { return }
        
        // If both analyses are already available, show comparison immediately
        if let analysis1 = food1Analysis, let analysis2 = food2Analysis {
            showingComparison = true
            return
        }
        
        // Get food names from either analysis or text input
        let food1Name = food1Analysis?.productName ?? food1Text
        let food2Name = food2Analysis?.productName ?? food2Text
        
        let normalizedFood1 = PetFoodAnalysis.normalizeInput(food1Name)
        let normalizedFood2 = PetFoodAnalysis.normalizeInput(food2Name)
        
        // Check cache for both foods first
        let cachedFood1 = cacheManager.getCachedAnalysis(for: selectedPetType, productName: normalizedFood1)
        let cachedFood2 = cacheManager.getCachedAnalysis(for: selectedPetType, productName: normalizedFood2)
        
        if let cached1 = cachedFood1, let cached2 = cachedFood2 {
            // Both foods are cached, use them immediately
            print("🔍 PetFoodCompareView: Using cached analyses for both foods")
            food1Analysis = cached1
            food2Analysis = cached2
            showingComparison = true
            return
        }
        
        // If we already have one analysis, use it and only analyze the other
        if let existingAnalysis1 = food1Analysis {
            food2Analysis = cachedFood2 ?? nil
            if food2Analysis != nil {
                showingComparison = true
                return
            }
        }
        
        if let existingAnalysis2 = food2Analysis {
            food1Analysis = cachedFood1 ?? nil
            if food1Analysis != nil {
                showingComparison = true
                return
            }
        }
        
        // At least one food needs API analysis
        isAnalyzing = true
        
        Task {
            do {
                // Analyze foods in parallel, using cache or existing analysis when available
                let analysis1Task: Task<PetFoodAnalysis, Error>
                let analysis2Task: Task<PetFoodAnalysis, Error>
                
                if let existing1 = food1Analysis {
                    analysis1Task = Task { existing1 }
                } else if let cached1 = cachedFood1 {
                    analysis1Task = Task { cached1 }
                } else {
                    analysis1Task = Task {
                        try await AIService.shared.getPetFoodAnalysis(
                            petType: selectedPetType,
                            productName: normalizedFood1
                        )
                    }
                }
                
                if let existing2 = food2Analysis {
                    analysis2Task = Task { existing2 }
                } else if let cached2 = cachedFood2 {
                    analysis2Task = Task { cached2 }
                } else {
                    analysis2Task = Task {
                        try await AIService.shared.getPetFoodAnalysis(
                            petType: selectedPetType,
                            productName: normalizedFood2
                        )
                    }
                }
                
                let (food1Result, food2Result) = try await (analysis1Task.value, analysis2Task.value)
                
                await MainActor.run {
                    food1Analysis = food1Result
                    food2Analysis = food2Result
                    isAnalyzing = false
                    showingComparison = true
                    
                    // Cache any new analyses
                    if cachedFood1 == nil {
                        cacheManager.cacheAnalysis(food1Result)
                        print("🔍 PetFoodCompareView: Cached new analysis for food1: \(food1Result.productName)")
                    }
                    if cachedFood2 == nil {
                        cacheManager.cacheAnalysis(food2Result)
                        print("🔍 PetFoodCompareView: Cached new analysis for food2: \(food2Result.productName)")
                    }
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    print("🔍 PetFoodCompareView: Error comparing foods: \(error)")
                }
            }
        }
    }
    
    // MARK: - Pet Type Selection Section
    private var petTypeSelectionSection: some View {
        VStack(spacing: 12) {
            Text("Select Pet Type")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Picker("Pet Type", selection: $selectedPetType) {
                Text("🐕 Dog").tag(PetFoodAnalysis.PetType.dog)
                Text("🐱 Cat").tag(PetFoodAnalysis.PetType.cat)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recently Analyzed Section
    @ViewBuilder
    private var recentlyAnalyzedSection: some View {
        if !cacheManager.cachedAnalyses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recently Analyzed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Pick two or enter new foods below")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
                
                // Sort Picker
                HStack {
                    Text("Sort by:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Sort", selection: $sortOption) {
                        ForEach(PetFoodSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.caption)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(getSortedPetFoods().prefix(10)) { entry in
                                PetFoodCacheRow(entry: entry, onTap: {
                                    // Pre-fill food 1 or 2 if empty
                                    if food1Analysis == nil {
                                        food1Analysis = entry.fullAnalysis
                                    } else if food2Analysis == nil {
                                        food2Analysis = entry.fullAnalysis
                                    }
                                }, onDelete: { cacheKey in
                                    cacheManager.deleteAnalysis(withCacheKey: cacheKey)
                                }, isSelected: (food1Analysis?.productName == entry.productName && food1Analysis?.brandName == entry.brandName) || (food2Analysis?.productName == entry.productName && food2Analysis?.brandName == entry.brandName))
                            }
                            
                            // Right arrow indicator
                            if getSortedPetFoods().count > 2 {
                                VStack {
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                        .padding(.trailing, 20)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Sorting Logic
    private func getSortedPetFoods() -> [PetFoodCacheEntry] {
        switch sortOption {
        case .recency:
            return cacheManager.cachedAnalyses.sorted { $0.analysisDate > $1.analysisDate }
        case .scoreHighLow:
            return cacheManager.cachedAnalyses.sorted { $0.fullAnalysis.overallScore > $1.fullAnalysis.overallScore }
        case .scoreLowHigh:
            return cacheManager.cachedAnalyses.sorted { $0.fullAnalysis.overallScore < $1.fullAnalysis.overallScore }
        }
    }
    
    // Header view matching the home screen
    private var headerView: some View {
        Image("LogoHorizontal")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 37)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.top, -8)
    }
}

struct PetFoodInputSection: View {
    @Binding var foodText: String
    @Binding var selectedPetType: PetFoodAnalysis.PetType
    let foodNumber: Int
    let onFoodDetected: (String) -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingVoiceMode = false
    @State private var showingManualEntry = false
    
    var body: some View {
        VStack(spacing: 16) {
            if foodText.isEmpty {
                // Voice Mode
                SearchMenuButton(
                    title: "Voice Mode",
                    subtitle: "Speak the brand name and specific food choice",
                    icon: "mic.fill",
                    color: Color(red: 0.42, green: 0.557, blue: 0.498),
                    gradient: LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.557, blue: 0.498),
                            Color(red: 0.502, green: 0.706, blue: 0.627)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ) {
                    showingVoiceMode = true
                }
                
                // Manual Entry Section
                SearchMenuButton(
                    title: "Text Your Pet Food",
                    subtitle: "Type brand name and specific food choice",
                    icon: "keyboard",
                    color: Color.orange,
                    gradient: LinearGradient(
                        colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ) {
                    showingManualEntry = true
                }
            } else {
                // Show entered text without repetitive buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Entered Text:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Text(foodText)
                        .font(.body)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingVoiceMode) {
            PetFoodVoiceInputView { foodName in
                foodText = foodName
                showingVoiceMode = false
                onFoodDetected(foodName)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            PetFoodCompareManualEntryView(
                selectedPetType: selectedPetType,
                foodNumber: foodNumber,
                onFoodDetected: { foodName in
                    foodText = foodName
                    showingManualEntry = false
                    onFoodDetected(foodName)
                }
            )
        }
    }
}

struct PetFoodVoiceInputView: View {
    let onFoodDetected: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var isRecording = false
    @State private var detectedText = ""
    @State private var audioEngine = AVAudioEngine()
    @State private var speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                // Logo Header
                Image("LogoHorizontal")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 37)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.top, -8)
                
                // Voice recording interface
                VStack(spacing: 15) {
                    Text("Voice Mode")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Tap the microphone and say the pet food you want to analyze")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // Authorization status
                    if authorizationStatus != .authorized {
                        VStack(spacing: 8) {
                            Text("Microphone Access Required")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("Please enable microphone access in Settings to use voice mode")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Recording button
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color(red: 0.255, green: 0.643, blue: 0.655))
                                .frame(width: 120, height: 120)
                                .scaleEffect(isRecording ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isRecording)
                            
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(authorizationStatus != .authorized)
                    
                    if !detectedText.isEmpty {
                        VStack(spacing: 16) {
                            Text("Detected Text")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            // Text Entry Box (same as Manual Food Entry)
                            VStack(alignment: .leading, spacing: 12) {
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $detectedText)
                                        .font(.body)
                                        .frame(height: 120)
                                        .padding(12)
                                        .background(Color(UIColor.systemBackground))
                                        .cornerRadius(12)
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Spacer()
                                                Button("Analyze") {
                                                    // Trigger analysis when Analyze button is pressed
                                                    if !detectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                        onFoodDetected(detectedText)
                                                        // Dismiss after a short delay to show loading state
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                            dismiss()
                                                        }
                                                    }
                                                }
                                                .foregroundColor(.blue)
                                            }
                                        }
                                    
                                    if detectedText.isEmpty {
                                        Text("Example: Purina Pro Plan Adult Sensitive Skin & Stomach, Royal Canin Indoor Adult")
                                            .foregroundColor(.secondary)
                                            .font(.body)
                                            .multilineTextAlignment(.leading)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(red: 0.255, green: 0.643, blue: 0.655), lineWidth: 1)
                                )
                            }
                            
                            // Action Buttons (same as Manual Food Entry)
                            HStack(spacing: 16) {
                                Button("Clear") {
                                    detectedText = ""
                                }
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                                
                                Button("Confirm") {
                                    onFoodDetected(detectedText)
                                    // Dismiss after a short delay to show loading state
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        dismiss()
                                    }
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.42, green: 0.557, blue: 0.498),
                                            Color(red: 0.502, green: 0.706, blue: 0.627)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                            }
                        }
                    }
                }
                
                Spacer()
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                requestSpeechAuthorization()
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                authorizationStatus = status
            }
        }
    }
    
    private func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available."
            showingError = true
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                errorMessage = "Failed to create recognition request."
                showingError = true
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Speech recognition error: \(error)")
                        self.errorMessage = "Speech recognition error: \(error.localizedDescription)"
                        self.showingError = true
                        self.stopRecording()
                        return
                    }
                    
                    if let result = result {
                        self.detectedText = result.bestTranscription.formattedString
                    }
                }
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            print("Recording started successfully")
            
        } catch {
            print("Error starting recording: \(error)")
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        print("Recording stopped")
    }
}

#Preview {
    PetFoodCompareView()
}
