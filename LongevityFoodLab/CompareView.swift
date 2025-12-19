import SwiftUI
import AVFoundation
import PhotosUI
import Speech
import UIKit

struct CompareView: View {
    let onFoodsCompared: ([FoodAnalysis]) -> Void
    
    @State private var food1Text: String = ""
    @State private var food2Text: String = ""
    @State private var food1Image: UIImage?
    @State private var food2Image: UIImage?
    @State private var isLoading = false
    @State private var showingLoading = false
    @State private var showingLoadingScreen = false
    @State private var selectedImage: UIImage?
    @State private var currentImageUpload: Int = 0 // 0 = none, 1 = Food #1, 2 = Food #2
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var cacheManager = FoodCacheManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Black background for dark mode only
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo image (same size as Recipes screen)
                        Image("LogoHorizontal")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 37)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.top, 20)
                    
                        // Recently Analyzed Section in black shadow box (dark mode only)
                        if !cacheManager.cachedAnalyses.isEmpty {
                            VStack(alignment: .center, spacing: 16) {
                                Text("Recently Analyzed")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                Text("Pick two or enter new foods below")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(cacheManager.cachedAnalyses.prefix(10)) { entry in
                                            FoodCacheRow(entry: entry, onTap: { analysis in
                                                // Pre-fill food 1 or 2 if empty
                                                if food1Text.isEmpty {
                                                    food1Text = analysis.foodName
                                                } else if food2Text.isEmpty {
                                                    food2Text = analysis.foodName
                                                }
                                            }, onDelete: { cacheKey in
                                                cacheManager.deleteAnalysis(withCacheKey: cacheKey)
                                            }, isSelected: food1Text == entry.foodName || food2Text == entry.foodName)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.bottom, 20)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                            .padding(.horizontal, 30)
                            .background(colorScheme == .dark ? Color.black : Color.white)
                            .cornerRadius(16)
                            .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        }
                        
                        // Main content scrolls below header
                        VStack(spacing: 18) {
                        // Food 1 Section
                        VStack(alignment: .center, spacing: 16) {
                            Text("Food #1")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            
                            if !food1Text.isEmpty || food1Image != nil {
                                // Show entered text or image without repetitive buttons
                                VStack(alignment: .center, spacing: 8) {
                                    if !food1Text.isEmpty {
                                        Text(food1Text)
                                            .font(.body)
                                            .multilineTextAlignment(.center)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let image = food1Image {
                                        Text("Uploaded Image:")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 150)
                                            .cornerRadius(12)
                                    }
                                }
                                .padding()
                                .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
                                )
                            } else {
                                // Show input options
                                FoodInputSection(
                                    foodText: $food1Text,
                                    onFoodDetected: { text in
                                        food1Text = text
                                    },
                                    onImageUploaded: { image in
                                        print("🖼️ Food #1 image uploaded: \(image)")
                                        food1Image = image
                                        print("🖼️ food1Image set to: \(food1Image != nil ? "image" : "nil")")
                                    },
                                    onDismiss: {
                                        // Don't dismiss the compare view when uploading images
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
                            
                            if !food2Text.isEmpty || food2Image != nil {
                                // Show entered text or image without repetitive buttons
                                VStack(alignment: .center, spacing: 8) {
                                    if !food2Text.isEmpty {
                                        Text(food2Text)
                                            .font(.body)
                                            .multilineTextAlignment(.center)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let image = food2Image {
                                        Text("Uploaded Image:")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                        
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 150)
                                            .cornerRadius(12)
                                    }
                                }
                                .padding()
                                .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(colorScheme == .dark ? 1.0 : 0.6), lineWidth: colorScheme == .dark ? 1.0 : 0.5)
                                )
                            } else {
                                // Show input options
                                FoodInputSection(
                                    foodText: $food2Text,
                                    onFoodDetected: { text in
                                        food2Text = text
                                    },
                                    onImageUploaded: { image in
                                        print("🖼️ Food #2 image uploaded: \(image)")
                                        food2Image = image
                                        print("🖼️ food2Image set to: \(food2Image != nil ? "image" : "nil")")
                                    },
                                    onDismiss: {
                                        // Don't dismiss the compare view when uploading images
                                    }
                                )
                            }
                        }
                        
                        // Compare Button
                        if (!food1Text.isEmpty || food1Image != nil) && (!food2Text.isEmpty || food2Image != nil) {
                            Button(action: {
                                compareFoods()
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Analyzing...")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    } else {
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                        Text("Compare Foods")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                            Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private func compareFoods() {
        guard (!food1Text.isEmpty || food1Image != nil) && (!food2Text.isEmpty || food2Image != nil) else { return }
        
        // Handle image analysis for comparison
        if food1Image != nil || food2Image != nil {
            print("📸 Starting image analysis for comparison")
            isLoading = true
            
            Task {
                do {
                    var analyses: [FoodAnalysis] = []
                    
                    // Analyze Food #1 (image or text)
                    if let image1 = food1Image {
                        print("📸 Analyzing Food #1 image")
                        let foodNames = try await withCheckedThrowingContinuation { continuation in
                            ImageAnalysisService.shared.analyzeFoodImage(image1) { result in
                                continuation.resume(with: result)
                            }
                        }
                        let foodText = foodNames.joined(separator: ", ")
                        print("📸 Food #1 detected foods: \(foodText)")
                        let analysis1 = try await withCheckedThrowingContinuation { continuation in
                            AIService.shared.analyzeFood(foodText) { result in
                                continuation.resume(with: result)
                            }
                        }
                        analyses.append(analysis1)
                    } else if !food1Text.isEmpty {
                        print("📸 Analyzing Food #1 text: \(food1Text)")
                        let analysis1 = try await withCheckedThrowingContinuation { continuation in
                            AIService.shared.analyzeFood(food1Text) { result in
                                continuation.resume(with: result)
                            }
                        }
                        analyses.append(analysis1)
                    }
                    
                    // Analyze Food #2 (image or text)
                    if let image2 = food2Image {
                        print("📸 Analyzing Food #2 image")
                        let foodNames = try await withCheckedThrowingContinuation { continuation in
                            ImageAnalysisService.shared.analyzeFoodImage(image2) { result in
                                continuation.resume(with: result)
                            }
                        }
                        let foodText = foodNames.joined(separator: ", ")
                        print("📸 Food #2 detected foods: \(foodText)")
                        let analysis2 = try await withCheckedThrowingContinuation { continuation in
                            AIService.shared.analyzeFood(foodText) { result in
                                continuation.resume(with: result)
                            }
                        }
                        analyses.append(analysis2)
                    } else if !food2Text.isEmpty {
                        print("📸 Analyzing Food #2 text: \(food2Text)")
                        let analysis2 = try await withCheckedThrowingContinuation { continuation in
                            AIService.shared.analyzeFood(food2Text) { result in
                                continuation.resume(with: result)
                            }
                        }
                        analyses.append(analysis2)
                    }
                    
                    await MainActor.run {
                        isLoading = false
                        if analyses.count == 2 {
                            print("📸 Image comparison completed successfully")
                            onFoodsCompared(analyses)
                        }
                    }
                } catch {
                    print("📸 Image analysis error: \(error)")
                    await MainActor.run {
                        isLoading = false
                    }
                }
            }
            return
        }
        
        let normalizedFood1 = FoodAnalysis.normalizeInput(food1Text)
        let normalizedFood2 = FoodAnalysis.normalizeInput(food2Text)
        
        // Check cache for both foods first
        let cachedFood1 = cacheManager.getCachedAnalysis(for: normalizedFood1)
        let cachedFood2 = cacheManager.getCachedAnalysis(for: normalizedFood2)
        
        if let cached1 = cachedFood1, let cached2 = cachedFood2 {
            // Both foods are cached, use them immediately
            print("🔍 CompareView: Using cached analyses for both foods")
            onFoodsCompared([cached1, cached2])
            return
        }
        
        // At least one food needs API analysis
        isLoading = true
        
        Task {
            do {
                // Analyze foods in parallel, using cache when available
                let analysis1Task: Task<FoodAnalysis, Error>
                let analysis2Task: Task<FoodAnalysis, Error>
                
                if let cached1 = cachedFood1 {
                    analysis1Task = Task { cached1 }
                } else {
                    analysis1Task = Task {
                        let healthProfile = UserHealthProfileManager.shared.currentProfile
                        return try await withCheckedThrowingContinuation { continuation in
                            AIService.shared.analyzeFoodWithProfile(food1Text, healthProfile: healthProfile) { result in
                                switch result {
                                case .success(let analysis):
                                    continuation.resume(returning: analysis)
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    }
                }
                
                if let cached2 = cachedFood2 {
                    analysis2Task = Task { cached2 }
                } else {
                    analysis2Task = Task {
                        let healthProfile = UserHealthProfileManager.shared.currentProfile
                        return try await withCheckedThrowingContinuation { continuation in
                            AIService.shared.analyzeFoodWithProfile(food2Text, healthProfile: healthProfile) { result in
                                switch result {
                                case .success(let analysis):
                                    continuation.resume(returning: analysis)
                                case .failure(let error):
                                    continuation.resume(throwing: error)
                                }
                            }
                        }
                    }
                }
                
                let (food1Result, food2Result) = try await (analysis1Task.value, analysis2Task.value)
                
                await MainActor.run {
                    isLoading = false
                    onFoodsCompared([food1Result, food2Result])
                    
                    // Cache any new analyses
                    if cachedFood1 == nil {
                        cacheManager.cacheAnalysis(food1Result)
                        print("🔍 CompareView: Cached new analysis for food1: \(food1Result.foodName)")
                    }
                    if cachedFood2 == nil {
                        cacheManager.cacheAnalysis(food2Result)
                        print("🔍 CompareView: Cached new analysis for food2: \(food2Result.foodName)")
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("🔍 CompareView: Error comparing foods: \(error)")
                }
            }
        }
    }
}

struct FoodInputSection: View {
    @Binding var foodText: String
    let onFoodDetected: (String) -> Void
    let onImageUploaded: (UIImage) -> Void
    let onDismiss: () -> Void
    
    @State private var showingVoiceMode = false
    @State private var showingManualEntry = false
    @State private var showingImagePicker = false
    @State private var showingPhotoPicker = false
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var showingLoading = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // 2x2 Grid Layout - Order: Snap, Upload, Say, Type
        VStack(spacing: 16) {
            // Row 1: Snap It and Upload It
            HStack(spacing: 16) {
                // Snap It - matching Score screen design
                Button(action: {
                    showingPhotoPicker = true
                }) {
                    VStack(spacing: -5) {
                        // Camera Icon with Gradient - matching Score screen
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.0, green: 0.8, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        // Text
                        VStack(spacing: 2) {
                            Text("Snap It")
                                .font(.system(size: 24, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                .foregroundColor(colorScheme == .dark ? .white : .secondary)
                            
                            // Subtitle - Same size
                            Text("To Score Your Meal Or Food")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 12)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Upload It - exact Score screen design
                Button(action: {
                    showingImagePicker = true
                }) {
                    VStack(spacing: -5) {
                        // Photo Icon with Gradient - matching Score screen
                        Image(systemName: "photo.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        // Text
                        VStack(spacing: 2) {
                            Text("Upload It")
                                .font(.system(size: 24, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                .foregroundColor(colorScheme == .dark ? .white : .secondary)
                                .lineLimit(1)
                            
                            // Subtitle - Same size
                            Text("From Your Photo Library")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 12)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Row 2: Say It and Type It
            HStack(spacing: 16) {
                // Say It - exact Score screen design
                Button(action: {
                    showingVoiceMode = true
                }) {
                    VStack(spacing: -5) {
                        // Mic Icon with Gradient - matching Score screen
                        Image(systemName: "mic.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.42, green: 0.557, blue: 0.498),
                                        Color(red: 0.3, green: 0.7, blue: 0.6)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        // Text
                        VStack(spacing: 2) {
                            Text("Say It")
                                .font(.system(size: 24, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                .foregroundColor(colorScheme == .dark ? .white : .secondary)
                            
                            // Subtitle - Same size
                            Text("To Score Your Meal Or Food")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 12)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Type It - exact Score screen design
                Button(action: {
                    showingManualEntry = true
                }) {
                    VStack(spacing: -5) {
                        // Keyboard Icon with Gradient - matching Score screen
                        Image(systemName: "keyboard")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 70, height: 70)
                        
                        // Text
                        VStack(spacing: 2) {
                            Text("Type It")
                                .font(.system(size: 24, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                .foregroundColor(colorScheme == .dark ? .white : .secondary)
                            
                            // Subtitle - Same size
                            Text("To Score Your Meal Or Food")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 12)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingVoiceMode) {
            VoiceInputView { foodName in
                foodText = foodName
                showingVoiceMode = false
                onFoodDetected(foodName)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualFoodEntryView(
                onFoodDetected: { analysis in
                    foodText = analysis.foodName
                    showingManualEntry = false
                    onFoodDetected(analysis.foodName)
                }
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerWrapper(sourceType: .photoLibrary, onImageSelected: { image in
                print("🖼️ Sheet callback: Image received")
                onImageUploaded(image)
                print("🖼️ Sheet callback: Setting showingImagePicker = false")
                showingImagePicker = false
            }, isPresented: $showingImagePicker)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) { oldValue, newImage in
            if let image = newImage {
                onImageUploaded(image)
                showingPhotoPicker = false
                selectedImage = nil // Reset after processing
            }
        }
        .overlay(
            // Show loading overlay for individual food analysis
            Group {
                if showingLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.255, green: 0.643, blue: 0.655)))
                        
                        Text("Analyzing your food...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
            }
        )
    }
}

struct VoiceInputView: View {
    let onFoodDetected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var isRecording = false
    @State private var detectedText = ""
    @State private var audioRecorder: AVAudioRecorder?
    @State private var speechRecognizer = SFSpeechRecognizer()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Black background for dark mode only
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Logo image (same size as Recipes screen)
                    Image("LogoHorizontal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 37)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.top, 20)
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Voice recording interface in black box (dark mode only) like Score It
                    VStack(spacing: 15) {
                        Text("Voice Mode")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Tap the microphone and say the food you want to analyze")
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
                        
                        // Recording button with Upload It gradient
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            ZStack {
                                if isRecording {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 120, height: 120)
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 120, height: 120)
                                }
                                
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isRecording)
                        }
                        .disabled(authorizationStatus != .authorized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 30)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    
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
                                        Text("Optional: Include estimated portions. Example: Grilled salmon (6 oz), quinoa (1 cup), steamed broccoli (1 cup), olive oil (1 tbsp)")
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
                            
                            // Action Buttons with gradients
                            HStack(spacing: 16) {
                                Button("Clear") {
                                    detectedText = ""
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color.gray, Color(red: 0.4, green: 0.4, blue: 0.4)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
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
                                        colors: [Color(red: 0.42, green: 0.557, blue: 0.498), Color(red: 0.255, green: 0.643, blue: 0.655)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            requestSpeechAuthorization()
        }
        .alert("Voice Recognition Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
                print("Speech recognition authorization status: \(status.rawValue)")
                
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    self.errorMessage = "Speech recognition access denied. Please enable it in Settings."
                    self.showingError = true
                case .restricted:
                    self.errorMessage = "Speech recognition is restricted on this device."
                    self.showingError = true
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Unknown speech recognition authorization status")
                }
            }
        }
    }
    
    private func startRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            showingError = true
            return
        }
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isRecording = false
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
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
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

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            // Don't dismiss here - let SwiftUI handle it
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Don't dismiss here - let SwiftUI handle it
        }
    }
}

struct ImagePickerWrapper: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerWrapper
        
        init(_ parent: ImagePickerWrapper) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("🖼️ ImagePickerWrapper: Image selected")
            if let image = info[.originalImage] as? UIImage {
                print("🖼️ ImagePickerWrapper: Calling onImageSelected")
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }
        }
    }
}

struct HumanFoodCompareManualEntryView: View {
    let onFoodDetected: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var foodText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                VStack {
                    Spacer()
                        .frame(height: 25)
                    
                    VStack(spacing: 12) {
                        // Logo Header
                        VStack(spacing: 8) {
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 80)
                            
                            VStack(spacing: 0) {
                                Text("LONGEVITY")
                                    .font(.custom("Avenir-Light", size: 32))
                                    .fontWeight(.light)
                                    .tracking(6)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Rectangle()
                                        .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                        .frame(width: 40, height: 1)
                                    
                                    Text("FOOD LAB")
                                        .font(.custom("Avenir-Light", size: 16))
                                        .tracking(4)
                                        .foregroundColor(.secondary)
                                    
                                    Rectangle()
                                        .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                        .frame(width: 40, height: 1)
                                }
                            }
                        }
                        
                        // Header
                        Text("Enter Your Food Or Meal Here")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // Text Entry Box
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $foodText)
                                    .font(.body)
                                    .frame(height: 80)
                                    .padding(12)
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(12)
                                
                                if foodText.isEmpty {
                                    Text("Optional: Include estimated portions if you want more details on nutrition. (Then give an example)")
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
                        
                        // Action Buttons (below text entry)
                        HStack(spacing: 16) {
                            Button("Clear") {
                                foodText = ""
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)

                            Button("Confirm") {
                                onFoodDetected(foodText)
                                dismiss()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.255, green: 0.643, blue: 0.655))
                            .cornerRadius(12)
                            .disabled(foodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    CompareView(onFoodsCompared: { _ in })
}

