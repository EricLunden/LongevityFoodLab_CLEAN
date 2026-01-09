
import SwiftUI
import Speech
import AVFoundation
import Charts

enum SortOption: String, CaseIterable {
    case recency = "Most Recent"
    case scoreHighLow = "Score: High to Low"
    case scoreLowHigh = "Score: Low to High"
}

enum AnalyzedItemFilterOption: String, CaseIterable {
    case all = "All"
    case recipes = "Recipes"
    case meals = "Meals"
    case foods = "Foods"
    case groceries = "Groceries"
}

class DetectedFood: ObservableObject, Identifiable {
    let id = UUID()
    var name: String
    @Published var servingSize: Double? // in ounces
    
    init(name: String, servingSize: Double? = nil) {
        self.name = name
        self.servingSize = servingSize
    }
}

// Helper view to observe individual DetectedFood objects
struct DetectedFoodRow: View {
    @ObservedObject var food: DetectedFood
    let isSpice: (String) -> Bool
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isDragging = false
    @State private var dragValue: Double = 0.0
    
    private let sliderRange: ClosedRange<Double> = 0.0...16.0
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text(food.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                if !isSpice(food.name) {
                    // Horizontal slider for serving size - one per line
                    GeometryReader { geometry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Serving Size")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                // Now observes @Published property directly
                                Text("\(String(format: "%.1f", food.servingSize ?? 0.0)) oz")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            ZStack(alignment: .leading) {
                                // Slider
                                Slider(
                                    value: Binding(
                                        get: { food.servingSize ?? 0.0 },
                                        set: { newValue in
                                            food.servingSize = newValue
                                            dragValue = newValue
                                            isDragging = true
                                            // Hide popup after a delay when user stops dragging
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                // Only hide if value hasn't changed (user stopped dragging)
                                                if abs((food.servingSize ?? 0.0) - newValue) < 0.1 {
                                                    isDragging = false
                                                }
                                            }
                                        }
                                    ),
                                    in: sliderRange,
                                    step: 0.5
                                )
                                .accentColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                                
                                // Popup box that follows slider thumb
                                if isDragging {
                                    let currentValue = food.servingSize ?? dragValue
                                    // Calculate thumb position: slider has padding, so we need to account for that
                                    // Slider thumb is approximately 15% from left edge and 15% from right edge
                                    let sliderPadding: CGFloat = geometry.size.width * 0.15
                                    let usableWidth = geometry.size.width - (sliderPadding * 2)
                                    let normalizedValue = (currentValue - sliderRange.lowerBound) / (sliderRange.upperBound - sliderRange.lowerBound)
                                    let thumbPosition = sliderPadding + (normalizedValue * usableWidth)
                                    
                                    VStack(spacing: 0) {
                                        // Popup box with green gradient
                                        Text("\(String(format: "%.1f", currentValue)) oz")
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
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
                                            .cornerRadius(16)
                                            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                                        
                                        // Arrow pointing down
                                        Triangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                                        Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 16, height: 10)
                                            .offset(y: -1)
                                    }
                                    .offset(x: thumbPosition - 50, y: -70) // Position above thumb, centered (50 is half popup width)
                                    .id(currentValue) // Force update when value changes
                                }
                            }
                        }
                    }
                    .frame(height: 80) // Fixed height for GeometryReader
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color(UIColor.secondarySystemBackground))
            .foregroundColor(colorScheme == .dark ? .white : .primary)
            .cornerRadius(10)
            .overlay(
                colorScheme == .dark ?
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1) :
                nil
            )
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white : .secondary)
            }
            .padding(8)
        }
    }
}

struct SearchView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var foodInput = ""
    @State private var isAnalyzing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    @State private var selectedImage: UIImage?
    @State private var showingVoiceMode = false
    @State private var isVoiceInput = false // Track if current input is from voice
    @State private var detectedFoods: [DetectedFood] = []
    @State private var showingAddFoodAlert = false
    @State private var newFoodInput = ""
    @State private var isReadyToAnalyze = false
    @State private var showingManualEntry = false
    @State private var showingServingSizeInput = false
    @State private var selectedFoodForServingSize: DetectedFood?
    @State private var servingSizeInput = ""
    @State private var retryCount = 0
    @State private var lastAnalyzedImage: UIImage?
    @State private var currentAnalysisImage: UIImage? // Image being analyzed for display
    @State private var showingDetectedFoodsPopup = false // Control detected foods popup
    @FocusState private var isTextFieldFocused: Bool

    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var displayedFoodCount = 6
    @State private var displayedRecipeCount = 6
    @State private var sortOption: SortOption = .recency
    @State private var filterOption: AnalyzedItemFilterOption = .all
    
    // Quick Dashboard state
    @State private var quickDashboardExpanded = false
    @State private var addDataPointsExpanded = false
    @State private var showingMicronutrientSelection = false
    @State private var selectedMicronutrients: Set<String> = []
    @StateObject private var mealStorageManager = MealStorageManager.shared
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    
    let onFoodDetected: (FoodAnalysis, UIImage?, String?, String?) -> Void // Added inputMethod parameter
    let onFoodsCompared: ([FoodAnalysis]) -> Void
    let onShowCompareView: () -> Void
    let onRecipeTapped: ((Recipe) -> Void)?
    let onClearInput: (() -> Void)?
    let shouldClearInput: Bool
    
    init(onFoodDetected: @escaping (FoodAnalysis, UIImage?, String?, String?) -> Void, onFoodsCompared: @escaping ([FoodAnalysis]) -> Void, onShowCompareView: @escaping () -> Void, onRecipeTapped: ((Recipe) -> Void)? = nil, onClearInput: (() -> Void)? = nil, shouldClearInput: Bool = false) {
        self.onFoodDetected = onFoodDetected
        self.onFoodsCompared = onFoodsCompared
        self.onShowCompareView = onShowCompareView
        self.onRecipeTapped = onRecipeTapped
        self.onClearInput = onClearInput
        self.shouldClearInput = false
    }
    
    func clearInput() {
        foodInput = ""
        detectedFoods = []
        isReadyToAnalyze = false
        currentAnalysisImage = nil // Clear analysis image
        onClearInput?()
    }
    
    private func isSpice(_ foodName: String) -> Bool {
        let spices = [
            "salt", "pepper", "cinnamon", "nutmeg", "ginger", "turmeric", "cumin", 
            "paprika", "cayenne", "chili", "vanilla", "cardamom", "cloves", 
            "allspice", "star anise", "saffron"
        ]
        
        let lowercasedFood = foodName.lowercased()
        return spices.contains { lowercasedFood.contains($0) }
    }
    
    var body: some View {
        ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 24) {
                            // Header - Horizontal Logo (matching Tracker screen)
                            Image("LogoHorizontal")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 37)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.top, -8)
                    
                    // Subhead: Snap. Score. Thrive!
                    Text("Snap. Score. Thrive!")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.top, -12)
                        .padding(.bottom, 0)
                    
                    // Main Search Options
                    VStack(spacing: 16) {
                        // Take A Photo - Custom Large Vertical Button
                        Button(action: {
                            isShowingCamera = true
                        }) {
                            VStack(spacing: -10) {
                                // Camera Icon with Gradient
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 100, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.0, green: 0.478, blue: 1.0), // Blue
                                                Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 150, height: 150)
                                
                                // Text
                                VStack(spacing: 2) {
                                    Text("Snap It")
                                        .font(.system(size: 40, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                        .foregroundColor(colorScheme == .dark ? .white : .secondary)
                                    
                                    // Subtitle
                                    Text("To Score Your Meal Or Food")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, -2)
                            .padding(.bottom, 23)
                            .padding(.horizontal, 30)
                            .background(colorScheme == .dark ? Color.black : Color.white)
                            .cornerRadius(16)
                            .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 2x2 Grid for Upload Image, Voice Mode, Type It, Compare
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 10) {
                            // Upload An Image - Downsized for 2x2 grid
                            Button(action: {
                                isShowingImagePicker = true
                            }) {
                                VStack(spacing: -5) {
                                    // Photo Icon with Gradient - Downsized
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
                            
                            // Voice Mode - Downsized for 2x2 grid
                            Button(action: {
                                showingVoiceMode = true
                            }) {
                                VStack(spacing: -5) {
                                    // Mic Icon with Gradient - Downsized
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
                            
                            // Type It - Downsized for 2x2 grid
                            Button(action: {
                                showingManualEntry = true
                            }) {
                                VStack(spacing: -5) {
                                    // Keyboard Icon with Gradient - Downsized
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
                            
                            // Compare - Downsized for 2x2 grid
                            Button(action: {
                                onShowCompareView()
                            }) {
                                VStack(spacing: -5) {
                                    // Compare Icon with Gradient - Downsized
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 50, weight: .medium))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.255, green: 0.643, blue: 0.655),
                                                    Color(red: 0.0, green: 0.8, blue: 0.8)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 70, height: 70)
                                    
                                    // Text
                                    VStack(spacing: 2) {
                                        Text("Compare")
                                            .font(.system(size: 24, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                            .foregroundColor(colorScheme == .dark ? .white : .secondary)
                                            .lineLimit(1)
                                        
                                        // Subtitle - Same size
                                        Text("Two Foods Side By Side")
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 5)
                    
                    // Quick Dashboard Section
                    quickDashboardSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 5)
                    
                    // Recently Analyzed Section
                    recentlyAnalyzedSection
                    
                    // Recently Imported Section
                    recentlyImportedSection
                    
                    // Error View
                    if showError {
                        errorView
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
        .onAppear {
            loadQuickDashboardSelectedMicronutrients()
        }
        .sheet(isPresented: $showingVoiceMode) {
            VoiceInputView { foodName in
                foodInput = foodName
                isVoiceInput = true // Mark as voice input
                analyzeFood()
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .sheet(isPresented: $isShowingCamera) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) { oldValue, newImage in
            if let image = newImage {
                analyzeImage(image)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualFoodEntryView(
                onFoodDetected: { analysis in
                    showingManualEntry = false
                    isVoiceInput = false // Mark as text input
                    onFoodDetected(analysis, nil, nil, "text")
                }
            )
        }
        .fullScreenCover(isPresented: $showingDetectedFoodsPopup) {
            detectedFoodsPopupView
        }
        .sheet(isPresented: $showingServingSizeInput) {
            NavigationView {
                VStack(spacing: 0) {
                    // Logo section at the top
                    VStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 75)
                            .padding(.top, 10.0)
                        
                        VStack(spacing: 0) {
                            Text("LONGEVITY")
                                .font(.system(size: 28, weight: .light, design: .default))
                                .tracking(6)
                                .foregroundColor(.primary)
                                .dynamicTypeSize(.large)
                            
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 40, height: 1)
                                
                                Text("FOOD LAB")
                                    .font(.system(size: 14, weight: .light, design: .default))
                                    .tracking(4)
                                    .foregroundColor(.secondary)
                                    .dynamicTypeSize(.large)
                                
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 40, height: 1)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    
                    // Content in rectangular box with green frame
                    VStack(spacing: 20) {
                        Text("Enter Serving Size")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(selectedFoodForServingSize?.name ?? "")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Serving Size (ounces)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextField("e.g., 6.0 or 3.5", text: $servingSizeInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .focused($isTextFieldFocused)
                        }
                        .padding(.horizontal)
                        
                        Text("Enter the serving size in ounces (e.g., 6.0 for 6 ounces, 3.5 for 3.5 ounces)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // Buttons inside the box
                        HStack(spacing: 20) {
                            Button("Cancel") {
                                showingServingSizeInput = false
                                servingSizeInput = ""
                                selectedFoodForServingSize = nil
                            }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(8)
                            
                            Button("Save") {
                                if let food = selectedFoodForServingSize {
                                    if let index = detectedFoods.firstIndex(where: { $0.id == food.id }) {
                                        if servingSizeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            // Clear serving size
                                            detectedFoods[index].servingSize = nil
                                        } else if let servingSize = Double(servingSizeInput), servingSize > 0 {
                                            // Set serving size
                                            detectedFoods[index].servingSize = servingSize
                                        }
                                        
                                        // Force UI update by creating a new array
                                        let updatedFoods = detectedFoods
                                        detectedFoods = updatedFoods
                                    }
                                }
                                showingServingSizeInput = false
                                servingSizeInput = ""
                                selectedFoodForServingSize = nil
                            }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green, lineWidth: 2)
                    )
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .navigationTitle("Serving Size")
                .navigationBarTitleDisplayMode(.inline)
            }
        }

        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                analyzeImage(image)
            }
        }
        .onChange(of: shouldClearInput) { oldValue, newValue in
            if newValue {
                clearInput()
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
    
    private var detectedFoodsBackgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground)
    }
    
    private var detectedFoodsPopupView: some View {
        NavigationView {
            ZStack {
                detectedFoodsBackgroundColor
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo image (same size as Voice Mode screen)
                        Image("LogoHorizontal")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 37)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.top, 20)
                        
                        // Image in rounded corners box
                        if let analysisImage = currentAnalysisImage {
                            Image(uiImage: analysisImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                        }
                        
                        // Detected foods section
                        detectedFoodsSection
                            .background(detectedFoodsBackgroundColor)
                    }
                }
            }
            .background(detectedFoodsBackgroundColor)
            .navigationTitle("Detected Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(colorScheme == .dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingDetectedFoodsPopup = false
                        detectedFoods = []
                        isReadyToAnalyze = false
                        currentAnalysisImage = nil
                    }
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
            }
            .toolbarBackground(detectedFoodsBackgroundColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .background(detectedFoodsBackgroundColor)
        .ignoresSafeArea(.all)
    }
    
    private var detectedFoodsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
                Text("Delete or add foods if necessary")
                    .font(.caption)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
                .padding(.top, 8)
            
            // Single column layout - one food per line with horizontal slider
            VStack(spacing: 12) {
                ForEach(detectedFoods, id: \.id) { food in
                    DetectedFoodRow(
                        food: food,
                        isSpice: isSpice,
                        onDelete: {
                            removeDetectedFood(food)
                        }
                    )
                }
                
                // Add A Food Button
                Button(action: {
                    showingAddFoodAlert = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                        Text("Add A Food")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.42, green: 0.557, blue: 0.498), lineWidth: 1)
                    )
                }
            }
            
            // Analyze Button with recipes screen gradient
            if isReadyToAnalyze {
                Button(action: startAnalysis) {
                    VStack(spacing: 6) {
                        if isAnalyzing {
                            Text("Analyzing...")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                            ProgressBar(isAnimating: isAnalyzing)
                                .frame(height: 4)
                                .padding(.horizontal, 8)
                        } else {
                            Text("Analyze Meal")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .opacity(isAnalyzing ? 0.8 : 1.0)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isAnalyzing)
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .alert("Add A Food", isPresented: $showingAddFoodAlert) {
            TextField("Enter food name", text: $newFoodInput)
            Button("Cancel", role: .cancel) {
                newFoodInput = ""
            }
            Button("Add") {
                addFood()
            }
        } message: {
            Text("Enter the name of a food that wasn't detected")
        }

    }
    
    private var searchSectionWithoutTitle: some View {
        VStack(spacing: 20) {
            VStack(spacing: 20) {
                // Voice Mode Button
                Button(action: {
                    showingVoiceMode = true
                }) {
                    HStack(spacing: 8) {
                        Text("🎤")
                        Text("Voice Mode")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Snap It Button
                Button(action: {
                    isShowingCamera = true
                }) {
                    HStack(spacing: 8) {
                        Text("📸")
                        Text("Snap It")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Upload An Image Button
                Button(action: {
                    isShowingImagePicker = true
                }) {
                    HStack(spacing: 8) {
                        Text("📁")
                        Text("Upload An Image")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Enter Any Food Section
                VStack(spacing: 15) {
                    TextField("Enter any food...", text: $foodInput)
                        .font(.body)
                        .accentColor(.primary)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            analyzeFood()
                        }
                    
                    // Evaluate Button
                    Button(action: analyzeFood) {
                        Text("Evaluate")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                            .background(Color(red: 65/255, green: 164/255, blue: 167/255))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                    .disabled(isAnalyzing || foodInput.isEmpty)
                    .opacity(isAnalyzing || foodInput.isEmpty ? 0.6 : 1.0)
                }
            }
            .padding(25)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
    }
    
    private var errorView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(errorMessage)
                    .foregroundColor(.primary)
                    .font(.body)
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // Try Again button for API-related errors
            if errorMessage.contains("Unable to load data") || 
               errorMessage.contains("Too many requests") || 
               errorMessage.contains("Server error") ||
               errorMessage.contains("Authentication failed") ||
               errorMessage.contains("Access forbidden") {
                Button("Try Again") {
                    showError = false
                    // Retry the last action based on context
                    if !detectedFoods.isEmpty {
                        // Retry image analysis
                        if let image = selectedImage {
                            analyzeImage(image)
                        }
                    } else if !foodInput.isEmpty {
                        // Retry food analysis
                        analyzeFood()
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    private func analyzeFood() {
        let trimmedInput = foodInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            showError(message: "Please enter a food to evaluate")
            return
        }
        
        guard trimmedInput.count <= 100 else {
            showError(message: "Food name is too long. Please use a shorter name.")
            return
        }
        
        isAnalyzing = true
        showError = false
        
        print("SearchView: Starting analysis for '\(trimmedInput)'")
        
        // Call AI Analysis with health profile
        let healthProfile = UserHealthProfileManager.shared.currentProfile
        AIService.shared.analyzeFoodWithProfile(trimmedInput, healthProfile: healthProfile) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                
                switch result {
                case .success(let analysis):
                    print("SearchView: Analysis successful for '\(trimmedInput)'")
                    let inputMethod = self.isVoiceInput ? "voice" : "text"
                    self.isVoiceInput = false // Reset after use
                    onFoodDetected(analysis, nil, nil, inputMethod)
                case .failure(let error):
                    print("SearchView: Analysis failed for '\(trimmedInput)': \(error.localizedDescription)")
                    // Use fallback analysis if API fails
                    let fallbackAnalysis = AIService.shared.createFallbackAnalysis(for: trimmedInput)
                    print("SearchView: Using fallback analysis for '\(trimmedInput)'")
                    let inputMethod = self.isVoiceInput ? "voice" : "text"
                    self.isVoiceInput = false // Reset after use
                    onFoodDetected(fallbackAnalysis, nil, nil, inputMethod)
                }
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + SecureConfig.errorDisplayDuration) {
            showError = false
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        print("🔍 SearchView: Starting image analysis with full classification")
        isAnalyzing = true
        showError = false
        detectedFoods = [] // Clear previous detected foods
        isReadyToAnalyze = false
        lastAnalyzedImage = image // Store image for potential retry
        currentAnalysisImage = image // Store image for display
        
        // Optimize image (resize + compress) for faster API uploads
        guard let imageData = image.optimizedForAPI() else {
            print("🔍 SearchView: Failed to optimize image")
            isAnalyzing = false
            showError(message: "Failed to process image")
            return
        }
        
        // Generate image hash and encode base64
        let imageHash = FoodCacheManager.hashImage(imageData)
        let base64Image = imageData.base64EncodedString()
        
        // Pre-save image to disk cache immediately (before API call)
        // This ensures image is cached even if API call fails
        foodCacheManager.saveImage(image, forHash: imageHash)
        
        // Check cache first
        if let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
            print("🔍 SearchView: Found cached analysis, scanType: \(cachedAnalysis.scanType ?? "nil")")
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.routeBasedOnScanType(cachedAnalysis, image: image, imageHash: imageHash)
            }
            return
        }
        
        // Call OpenAI Vision API for full analysis with classification
        Task {
            do {
                print("🔍 SearchView: Calling OpenAI Vision API for classification")
                let analysis = try await analyzeImageWithOpenAI(base64Image: base64Image, imageHash: imageHash)
                
                await MainActor.run {
                    isAnalyzing = false
                    print("🔍 SearchView: Analysis received, scanType: \(analysis.scanType ?? "nil")")
                    // Clear lastAnalyzedImage on success (no longer needed for retry)
                    lastAnalyzedImage = nil
                    routeBasedOnScanType(analysis, image: image, imageHash: imageHash)
                }
            } catch {
                print("🔍 SearchView: Image analysis failed: \(error.localizedDescription)")
                await MainActor.run {
                    isAnalyzing = false
                    
                    // Check if it's a temporary server error (529 Overloaded) and retry
                    if (error.localizedDescription.contains("529") || error.localizedDescription.contains("Overloaded")) && retryCount < 2 {
                        retryCount += 1
                        print("🔍 SearchView: Retrying image analysis (attempt \(retryCount))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if let image = self.lastAnalyzedImage {
                                self.analyzeImage(image)
                            }
                        }
                    } else {
                        if error.localizedDescription.contains("529") || error.localizedDescription.contains("Overloaded") {
                            showError(message: "The analysis service is temporarily busy. Please try again in a moment.")
                        } else {
                            // Check if it's a timeout error
                            let isTimeout = error.localizedDescription.contains("timed out") || 
                                          error.localizedDescription.contains("-1001") ||
                                          (error as NSError).code == -1001
                            
                            if isTimeout {
                                showError(message: "The analysis is taking longer than expected. Please try again.")
                            } else {
                                showError(message: error.localizedDescription)
                            }
                        }
                        // Clear UI state but keep lastAnalyzedImage for retry
                        selectedImage = nil
                        currentAnalysisImage = nil
                        retryCount = 0
                        // Don't clear lastAnalyzedImage - keep it for "Try Again" button
                    }
                }
            }
        }
    }
    
    // Route based on scanType classification
    private func routeBasedOnScanType(_ analysis: FoodAnalysis, image: UIImage, imageHash: String) {
        let scanType = analysis.scanType ?? "food" // Default to "food" if not specified
        
        print("🔍 SearchView: Routing based on scanType: \(scanType)")
        
        switch scanType {
        case "meal":
            // Meal - show detected foods popup (extract food names from ingredients or use foodName)
            print("🔍 SearchView: Routing to meal flow - detected foods popup")
            
            // CRITICAL FIX: Save image and cache initial analysis BEFORE showing popup
            var hashToUse: String? = imageHash
            if hashToUse == nil, let imageData = image.optimizedForAPI() {
                hashToUse = FoodCacheManager.hashImage(imageData)
            }
            
            // Save image to disk cache and cache analysis
            if let hash = hashToUse {
                foodCacheManager.saveImage(image, forHash: hash)
                foodCacheManager.cacheAnalysis(analysis, imageHash: hash, scanType: scanType, inputMethod: nil) // Image entry
            } else {
                foodCacheManager.cacheAnalysis(analysis, scanType: scanType, inputMethod: nil) // Image entry
            }
            
            // Extract food names and portions from foodPortions (NEW) or foodNames (backward compatibility)
            let foodNames: [String]
            let foodPortions: [FoodPortion]?
            
            if let portions = analysis.foodPortions, !portions.isEmpty {
                // NEW: Use foodPortions array (preferred - includes portion estimates)
                foodNames = portions.map { $0.name }
                foodPortions = portions
            } else if let names = analysis.foodNames, !names.isEmpty {
                // Fallback: Use foodNames array (backward compatibility)
                foodNames = names
                foodPortions = nil
            } else if !analysis.ingredientsOrDefault.isEmpty {
                // Fallback: extract from ingredients array (for backward compatibility)
                foodNames = analysis.ingredientsOrDefault.map { $0.name }
                foodPortions = nil
            } else {
                // Final fallback: use foodName as single detected food
                foodNames = [analysis.foodName]
                foodPortions = nil
            }
            analyzeDetectedFoods(foodNames, foodPortions: foodPortions)
            // Don't clear selectedImage here - keep it for meal analysis flow
            
        case "food":
            // Single food - analyze directly, skip detected foods popup
            print("🔍 SearchView: Routing to food flow - direct analysis")
            // Generate image hash if we have the image
            var hashToUse: String? = imageHash
            if hashToUse == nil, let imageData = image.optimizedForAPI() {
                hashToUse = FoodCacheManager.hashImage(imageData)
            }
            
            // Save image and cache analysis, then show results
            if let hash = hashToUse {
                foodCacheManager.saveImage(image, forHash: hash)
                foodCacheManager.cacheAnalysis(analysis, imageHash: hash, scanType: scanType, inputMethod: nil) // Image entry
            } else {
                foodCacheManager.cacheAnalysis(analysis, scanType: scanType, inputMethod: nil) // Image entry
            }
            
            // Show results directly
            onFoodDetected(analysis, image, hashToUse, nil) // Image entry
            currentAnalysisImage = nil // Clear display image
            selectedImage = nil
            
        case "product", "nutrition_label":
            // Product - route to grocery scanner flow
            print("🔍 SearchView: Routing to grocery scanner flow")
            // For now, treat as food analysis but with product scanType
            // In the future, this could route to a dedicated grocery scanner handler
            var hashToUse: String? = imageHash
            if hashToUse == nil, let imageData = image.optimizedForAPI() {
                hashToUse = FoodCacheManager.hashImage(imageData)
            }
            
            if let hash = hashToUse {
                foodCacheManager.saveImage(image, forHash: hash)
                foodCacheManager.cacheAnalysis(analysis, imageHash: hash, scanType: scanType, inputMethod: nil) // Image entry
            } else {
                foodCacheManager.cacheAnalysis(analysis, scanType: scanType, inputMethod: nil) // Image entry
            }
            
            onFoodDetected(analysis, image, hashToUse, nil) // Image entry
            currentAnalysisImage = nil
            selectedImage = nil
            
        default:
            // Default to food flow
            print("🔍 SearchView: Unknown scanType '\(scanType)', defaulting to food flow")
            var hashToUse: String? = imageHash
            if hashToUse == nil, let imageData = image.optimizedForAPI() {
                hashToUse = FoodCacheManager.hashImage(imageData)
            }
            
            if let hash = hashToUse {
                foodCacheManager.saveImage(image, forHash: hash)
                foodCacheManager.cacheAnalysis(analysis, imageHash: hash, scanType: scanType, inputMethod: nil) // Image entry
            } else {
                foodCacheManager.cacheAnalysis(analysis, scanType: scanType, inputMethod: nil) // Image entry
            }
            
            onFoodDetected(analysis, image, hashToUse, nil) // Image entry
            currentAnalysisImage = nil
            selectedImage = nil
        }
    }
    
    // Helper function to call analyzeImageWithOpenAI (same as ContentView)
    private func analyzeImageWithOpenAI(base64Image: String, imageHash: String) async throws -> FoodAnalysis {
        // This will be a duplicate of ContentView's function, or we could extract it to a shared service
        // For now, let's create a simplified version that calls the same API
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0  // Increased to 60 seconds to prevent premature timeouts
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        // Get user health profile for personalization
        let healthProfileManager = UserHealthProfileManager.shared
        let healthGoals = healthProfileManager.getHealthGoals()
        let top3Goals = Array(healthGoals.prefix(3))
        let healthGoalsText = top3Goals.isEmpty ? "general health and longevity" : top3Goals.joined(separator: ", ")
        
        // Determine meal timing based on current time
        let hour = Calendar.current.component(.hour, from: Date())
        let mealTiming: String
        switch hour {
        case 5..<11: mealTiming = "breakfast"
        case 11..<15: mealTiming = "lunch"
        case 15..<20: mealTiming = "dinner"
        default: mealTiming = "meal"
        }
        
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
        - "meal" = prepared dishes eaten as meals (plated food with multiple components, sandwiches, salads with toppings, pizza, breakfast/lunch/dinner combinations, anything that looks like it's being eaten as a meal)
        - "food" = individual ready-to-eat items (single fruits like apple/banana/orange, individual snacks like cookie or handful of nuts, single beverages like glass of juice or cup of coffee, ready-to-eat single items)
        - "product" = packaged products requiring preparation (boxed/packaged items like box of pasta or cereal box, canned goods like can of beans or tomato sauce, raw ingredients like raw meat or bag of flour, anything in store packaging not yet prepared)
        - "supplement" = supplement bottle/package
        - "nutrition_label" = nutrition facts panel only
        - "supplement_facts" = supplement facts panel only
        
        CLASSIFICATION RULES:
        - If image shows a complete meal on a plate with multiple components → "meal"
        - If image shows a single ready-to-eat item (apple, cookie, glass of juice) → "food"
        - If image shows packaged/unprepared items (box, can, raw ingredients) → "product"
        - Default to "food" if classification is unclear

        STEP 2: Analyze the image and prioritize main ingredients:
        - Focus on ingredients with LARGER PORTIONS first (main proteins, starches, vegetables)
        - IGNORE small garnishes (lemon wedges, parsley sprigs, decorative herbs, small condiments)
        - Prioritize by visual size/portion: largest components → medium components → ignore tiny garnishes
        - Example: For a salmon bowl with rice, vegetables, and a lemon wedge → focus on salmon, rice, vegetables. Ignore the lemon wedge unless it's a main component.
        - Only mention garnishes if they significantly impact nutrition (e.g., large amounts of sauce, cheese, etc.)

        Extract nutritional data from the image:
        - For products/supplements: Read ALL values from visible nutrition labels
        - For foods/meals: Estimate based on standard serving sizes of MAIN INGREDIENTS
        - Use exact values from labels when visible, estimates when not

        STEP 3: Score using these EXACT ranges:
        - Whole foods (apple, salmon, broccoli): 70-95
        - Minimally processed (whole grain bread, plain yogurt): 60-75
        - Processed foods (white bread, crackers): 40-60
        - Desserts/sweets (cake, cookies, pie): 30-50 (penalize sugar/flour heavily)
        - Fast food/highly processed: 20-40

        SCORING RULES:
        - Use precise integers (42, 73, 87) NOT rounded (45, 75, 85)
        - Penalize added sugars: -15 to -25 points
        - Penalize refined flour: -10 to -15 points
        - Penalize processed ingredients: -5 to -15 points
        - For desserts: Healthy ingredients (fruit) do NOT offset sugar/flour penalties

        CRITICAL: For complex foods (pie, lasagna, pizza), you MUST:
        1. List ALL major ingredients in the ingredients array (prioritize by portion size)
        2. Score based on COMPLETE composition, not just main ingredient
        3. Focus on ingredients that make up the largest portions of the meal
        4. Example: "Peach pie" = peaches + crust + sugar + butter + flour (score ~41, not 80)
        5. Example: "Grilled salmon with rice and lemon wedge" → focus on salmon and rice, ignore lemon wedge unless it's a significant portion

        ════════════════════════════════════════════════════════════════════════════
        SUMMARY GUIDELINES (CRITICAL - READ THIS FIRST BEFORE WRITING SUMMARY):
        ════════════════════════════════════════════════════════════════════════════

        You are writing a 1-2 sentence meal analysis for a longevity app. Be brutally honest, specific, and SHORT.

        RULES:

        1. MAX 40 words total

        2. Lead with the most shocking/specific fact about MAIN INGREDIENTS (largest portions)

        3. Focus on MAIN INGREDIENTS ONLY (largest portions on the plate). Ignore small garnishes, decorative elements, or tiny side items unless they significantly impact the meal's nutrition.

        4. Never lecture or use "should"

        5. Include ONE specific number (grams, calories, glucose spike, etc.) from the MAIN INGREDIENTS

        6. End with impact on their personal goal: \(healthGoalsText)

        BAD (mushy/preachy):
        "Apple pie with ice cream is a traditional dessert that provides enjoyment but should be consumed in moderation, especially for individuals focusing on blood sugar control."

        GOOD EXAMPLES:

        Apple Pie + Ice Cream (Score: 44):
        "This dessert packs 65g of sugar—triggering a glucose spike 3x higher than your body can efficiently process. Save it for special occasions if weight loss is your goal."

        Salmon Bowl (Score: 92):
        "Wild salmon's 3g omega-3s combined with kale's sulforaphane activate cellular repair pathways that peak 4 hours after eating—perfect timing for your \(healthGoalsText) goals."

        McDonald's Big Mac (Score: 38):
        "With 563 calories and only 2g of fiber, this meal will leave you hungry again in 90 minutes while the 33g of processed fat disrupts your metabolic health targets."

        Green Smoothie (Score: 81):
        "Your smoothie's 8g of fiber slows sugar absorption by 40%, while spinach's folate boosts cellular energy production—directly supporting your \(healthGoalsText) goals."

        Pizza Slice (Score: 52):
        "Each slice delivers 285 calories but zero longevity nutrients, plus refined flour that ages your cells faster than whole grains would."

        FORMAT:
        [Specific fact with number about MAIN INGREDIENTS] + [Direct biological impact] + [Connection to their goal if relevant]

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

        Keep it conversational but authoritative. Make them feel the immediate impact of their food choice.

        ════════════════════════════════════════════════════════════════════════════
        VISUAL PORTION ESTIMATION - CRITICAL INSTRUCTIONS:
        ════════════════════════════════════════════════════════════════════════════

        **ESTIMATE WHAT YOU ACTUALLY SEE, NOT TYPICAL SERVING SIZES**

        You must analyze the ACTUAL food visible in the image and estimate its weight based on visual appearance, NOT what a "typical serving" would be.

        REFERENCE SIZES (use plate/utensils for scale):
        - Standard dinner plate: 10-11 inches diameter
        - Standard salad plate: 7-8 inches diameter
        - Fork length: ~7 inches
        - Smartphone size: ~3-4 oz of meat

        COUNT DISCRETE ITEMS WHEN POSSIBLE:
        - Olive: ~0.1 oz each (10 olives = 1 oz)
        - Cherry tomato: ~0.5-1 oz each
        - Broccoli floret (small): ~0.3 oz each
        - Broccoli floret (medium): ~0.5 oz each
        - Meat slice (thin, 3"x2"): ~0.5-0.75 oz each
        - Meat slice (thick, 3"x2"): ~1-1.5 oz each
        - Shrimp (medium): ~0.3 oz each
        - Meatball (golf ball size): ~1 oz each

        MEAT/PROTEIN BY VISUAL SIZE:
        - 2-3 thin slices of steak/beef: 1-2 oz
        - Small piece (deck of cards, 3"x2"x0.5"): 2-3 oz
        - Medium piece (palm size, 4"x3"x0.75"): 4-5 oz
        - Large piece (hand size, 5"x4"x1"): 6-8 oz
        - Very large (bigger than hand): 8-12 oz

        VEGETABLES BY VISUAL COVERAGE:
        - Scattered/garnish (few pieces): 0.5-1 oz
        - Small pile (covers ~5% of plate): 1-2 oz
        - Medium portion (covers ~10-15% of plate): 2-4 oz
        - Large portion (covers ~20-25% of plate): 4-6 oz
        - Very large (covers 1/3+ of plate): 6-10 oz

        LEAFY GREENS (very light):
        - Small handful of lettuce: 0.5-1 oz
        - Side salad portion: 1.5-2.5 oz
        - Large salad base: 3-4 oz

        GRAINS/STARCHES BY VISUAL SIZE:
        - Small scoop of rice/pasta: 2-3 oz
        - Medium portion (tennis ball): 4-5 oz
        - Large portion (baseball): 6-8 oz
        - Very large (covers 1/3 plate): 8-12 oz

        LIQUIDS/SAUCES:
        - Drizzle: 0.25-0.5 oz
        - Small pool: 1 oz
        - Generous pour: 2-3 oz

        ESTIMATION RULES:
        1. COUNT items when you can see discrete pieces (slices, florets, olives, etc.)
        2. COMPARE to plate size - estimate what percentage of the plate each food covers
        3. CONSIDER thickness/depth - a thin layer vs a pile
        4. BE PRECISE - "2 thin slices" is NOT the same as "a steak"
        5. When uncertain, use "medium" confidence and estimate conservatively

        IMPORTANT NOTES:
        - For meals (scanType="meal"), you MUST include a "foodPortions" array with estimated portion sizes based on VISUAL ANALYSIS of the actual food in the image. Each item should have:
          * "name": The specific food name (e.g., "Steak Slices" not just "Steak" if you see slices)
          * "estimatedOz": Estimated weight in ounces based on what you ACTUALLY SEE (count items, compare to plate size, assess thickness)
          * "confidence": "high" if clearly visible and countable, "medium" if somewhat visible, "low" if obscured or hard to estimate
        - For backward compatibility, also include "foodNames" array with just the names (e.g., ["Grilled Chicken", "Avocado", "Mixed Greens"])
        - For single foods (scanType="food"), "foodPortions" and "foodNames" can be omitted or contain just the single food name.
        - Do NOT include keyBenefits, ingredients, nutritionInfo, or bestPreparation in the initial response. These will be loaded on demand.

        ════════════════════════════════════════════════════════════════════════════
        Return ONLY this JSON structure (no markdown, no explanation):
        ════════════════════════════════════════════════════════════════════════════
        {
            "scanType": "food|meal|product|supplement|nutrition_label|supplement_facts",
            "foodName": "Exact name from image or standard name",
            "foodNames": ["Food 1", "Food 2", "Food 3"],
            "foodPortions": [
                {"name": "Food 1", "estimatedOz": 5.0, "confidence": "high"},
                {"name": "Food 2", "estimatedOz": 3.5, "confidence": "medium"},
                {"name": "Food 3", "estimatedOz": 2.0, "confidence": "high"}
            ],
            "needsBackScan": false,
            "overallScore": 0-100,
            "summary": "Write 1-2 sentences, MAX 40 words. Lead with shocking/specific fact. Include ONE specific number. End with impact on: \(healthGoalsText). NO 'should', 'in moderation', 'traditional', 'provides enjoyment'. Use 'your' not 'the user's'.",
            "healthScores": {
                "heartHealth": 0-100,
                "brainHealth": 0-100,
                "antiInflammation": 0-100,
                "jointHealth": 0-100,
                "eyeHealth": 0-100,
                "weightManagement": 0-100,
                "bloodSugar": 0-100,
                "energy": 0-100,
                "immune": 0-100,
                "sleep": 0-100,
                "skin": 0-100,
                "stress": 0-100
            },
            "servingSize": "Standard serving"
        }
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
                foodPortions: analysis.foodPortions,
                suggestions: analysis.suggestions
            )
        }
        
        return analysis
    }
    
    private func analyzeDetectedFoods(_ foods: [String], foodPortions: [FoodPortion]? = nil) {
        print("🔍 SearchView: Setting detected foods: \(foods)")
        if let portions = foodPortions {
            print("🔍 SearchView: Using foodPortions with portion estimates: \(portions.map { "\($0.name): \($0.estimatedOz)oz (\($0.confidence))" }.joined(separator: ", "))")
        }
        
        // Initialize with portion estimates from foodPortions if available, otherwise nil
        DispatchQueue.main.async {
            self.detectedFoods = foods.map { foodName in
                // Try to find matching FoodPortion for this food
                if let portions = foodPortions,
                   let portion = portions.first(where: { $0.name == foodName }) {
                    // Use AI's estimatedOz if confidence is "high" or "medium"
                    let initialServingSize: Double?
                    if portion.confidence == "high" || portion.confidence == "medium" {
                        // Cap at 16oz max (slider range)
                        initialServingSize = min(portion.estimatedOz, 16.0)
                        print("✅ SearchView: Using AI portion estimate for '\(foodName)': \(String(format: "%.1f", initialServingSize!)) oz (confidence: \(portion.confidence))")
                    } else {
                        // Low confidence - will estimate via AI fallback
                        initialServingSize = nil
                        print("⚠️ SearchView: Low confidence for '\(foodName)', will estimate via AI")
                    }
                    return DetectedFood(name: foodName, servingSize: initialServingSize)
                } else {
                    // No FoodPortion data - initialize with nil, will estimate via AI
                    return DetectedFood(name: foodName, servingSize: nil)
                }
            }
            self.isReadyToAnalyze = true
            self.showingDetectedFoodsPopup = true // Show popup when foods are detected
            print("🔍 SearchView: isReadyToAnalyze set to: \(self.isReadyToAnalyze)")
            print("🔍 SearchView: detectedFoods count after update: \(self.detectedFoods.count)")
        }
        
        // Estimate serving sizes using AI only for foods without portion estimates or with low confidence
        Task {
            for foodName in foods {
                // Skip spices
                if isSpice(foodName) {
                    continue
                }
                
                // Check if we already have a portion estimate from foodPortions
                let hasPortionEstimate: Bool
                if let portions = foodPortions,
                   let portion = portions.first(where: { $0.name == foodName }),
                   portion.confidence == "high" || portion.confidence == "medium" {
                    hasPortionEstimate = true
                    print("✅ SearchView: Skipping AI estimation for '\(foodName)' - already have portion estimate (\(portion.estimatedOz) oz, confidence: \(portion.confidence))")
                } else {
                    hasPortionEstimate = false
                }
                
                // Only estimate via AI if we don't have a good portion estimate
                if !hasPortionEstimate {
                    do {
                        let servingInfo = try await AIService.shared.estimateTypicalServingSize(foodName: foodName, isRecipe: false)
                        // Convert grams to ounces (1 oz = 28.35g)
                        let ounces = servingInfo.weightGrams / 28.35
                        print("✅ SearchView: Estimated serving size for '\(foodName)': \(servingInfo.size) (\(Int(servingInfo.weightGrams))g = \(String(format: "%.1f", ounces)) oz)")
                        
                        // Update the detected food with estimated serving size (find by name, not index)
                        DispatchQueue.main.async {
                            if let food = self.detectedFoods.first(where: { $0.name == foodName }) {
                                // Only update if servingSize is nil (not already set from foodPortions)
                                if food.servingSize == nil {
                                    // Cap at 16oz max (slider range)
                                    let cappedOunces = min(ounces, 16.0)
                                    food.servingSize = cappedOunces
                                    // @Published will trigger view update automatically via @ObservedObject in DetectedFoodRow
                                    print("✅ SearchView: Updated serving size for '\(foodName)' to \(String(format: "%.1f", cappedOunces)) oz (AI fallback)")
                                } else {
                                    print("✅ SearchView: Keeping existing serving size for '\(foodName)' (\(String(format: "%.1f", food.servingSize!)) oz)")
                                }
                            } else {
                                print("⚠️ SearchView: Could not find '\(foodName)' in detectedFoods array to update serving size")
                            }
                        }
                    } catch {
                        print("⚠️ SearchView: Failed to estimate serving size for '\(foodName)', using default 3.5 oz: \(error)")
                        // Default to 3.5 oz (approximately 100g) - capped at 16oz
                        DispatchQueue.main.async {
                            if let food = self.detectedFoods.first(where: { $0.name == foodName }) {
                                // Only set default if servingSize is nil
                                if food.servingSize == nil {
                                    food.servingSize = min(3.5, 16.0)
                                    // @Published will trigger view update automatically via @ObservedObject in DetectedFoodRow
                                    print("✅ SearchView: Set default serving size for '\(foodName)' to 3.5 oz")
                                }
                            } else {
                                print("⚠️ SearchView: Could not find '\(foodName)' in detectedFoods array to set default serving size")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func removeDetectedFood(_ food: DetectedFood) {
        detectedFoods.removeAll { $0.id == food.id }
        isReadyToAnalyze = !detectedFoods.isEmpty
    }
    
    private func startAnalysis() {
        guard !detectedFoods.isEmpty else { return }
        
        // Dismiss the detected foods popup immediately
        showingDetectedFoodsPopup = false
        
        isAnalyzing = true
        let combinedFoods = detectedFoods.map { food in
            if let servingSize = food.servingSize {
                return "\(food.name) (\(String(format: "%.1f", servingSize)) oz)"
            } else {
                return food.name
            }
        }.joined(separator: ", ")
        
        print("🔍 SearchView: Starting meal analysis for: \(combinedFoods)")
        
        // Generate image hash if we have a current analysis image
        var imageHash: String? = nil
        var imageToSave: UIImage? = nil
        if let image = currentAnalysisImage, let imageData = image.optimizedForAPI() {
            imageHash = FoodCacheManager.hashImage(imageData)
            imageToSave = image
            print("🔍 SearchView: Generated image hash for photo: \(imageHash ?? "failed")")
            print("🔍 SearchView: Image available for saving: \(imageToSave != nil)")
        } else {
            print("🔍 SearchView: No currentAnalysisImage available for hash generation")
        }
        
        // STEP 1: Calculate nutrition from USDA database first
        Task {
            do {
                print("🔍 SearchView: Step 1 - Calculating nutrition from database...")
                let calculatedNutrition = try await calculateNutritionFromDatabase()
                
                if let nutrition = calculatedNutrition {
                    print("✅ SearchView: Successfully calculated nutrition from database")
                    print("   Calories: \(nutrition.calories), Protein: \(nutrition.protein)")
                    
                    // STEP 2: Use AI for analysis/scoring with calculated nutrition
                    await MainActor.run {
                        self.performAIAnalysisWithNutrition(
                            combinedFoods: combinedFoods,
                            calculatedNutrition: nutrition,
                            imageHash: imageHash,
                            imageToSave: imageToSave
                        )
                    }
                } else {
                    print("⚠️ SearchView: Database lookup failed or insufficient foods found, falling back to full AI analysis")
                    // STEP 3: Fallback to full AI analysis
                    await MainActor.run {
                        self.performFullAIAnalysis(
                            combinedFoods: combinedFoods,
                            imageHash: imageHash,
                            imageToSave: imageToSave
                        )
                    }
                }
            } catch {
                print("❌ SearchView: Error calculating nutrition from database: \(error.localizedDescription)")
                // Fallback to full AI analysis
                await MainActor.run {
                    self.performFullAIAnalysis(
                        combinedFoods: combinedFoods,
                        imageHash: imageHash,
                        imageToSave: imageToSave
                    )
                }
            }
        }
        
        // Add a timeout to prevent infinite loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { // 1 minute timeout for single analysis
            if isAnalyzing {
                print("⚠️ SearchView: Meal analysis timeout reached")
                isAnalyzing = false
                let fallbackAnalysis = AIService.shared.createFallbackAnalysis(for: combinedFoods)
                let individualFoodNames = self.detectedFoods.map { $0.name }
                let mealFallbackAnalysis = FoodAnalysis(
                    foodName: fallbackAnalysis.foodName,
                    overallScore: fallbackAnalysis.overallScore,
                    summary: fallbackAnalysis.summary,
                    healthScores: fallbackAnalysis.healthScores,
                    keyBenefits: fallbackAnalysis.keyBenefits,
                    ingredients: fallbackAnalysis.ingredients,
                    bestPreparation: fallbackAnalysis.bestPreparation,
                    servingSize: fallbackAnalysis.servingSize,
                    nutritionInfo: fallbackAnalysis.nutritionInfo,
                    scanType: fallbackAnalysis.scanType,
                    foodNames: individualFoodNames,
                    foodPortions: nil,
                    suggestions: fallbackAnalysis.suggestions
                )
                onFoodDetected(mealFallbackAnalysis, self.selectedImage, imageHash, nil)
            }
        }
    }
    
    // MARK: - Nutrition Calculation from Database
    
    /// Calculate nutrition from USDA database using detected foods and serving sizes
    private func calculateNutritionFromDatabase() async throws -> NutritionInfo? {
        print("🔍 SearchView: Calculating nutrition for \(detectedFoods.count) detected foods")
        
        var aggregator = NutritionAggregator()
        var foundCount = 0
        var skippedCount = 0
        
        // Lookup nutrition for each detected food using tiered lookup (Local DB → USDA → Spoonacular)
        try await withThrowingTaskGroup(of: (String, NutritionInfo?).self) { group in
            for food in detectedFoods {
                // Skip spices (they don't contribute significant nutrition)
                if isSpice(food.name) {
                    skippedCount += 1
                    continue
                }
                
                group.addTask {
                    // Use actual serving size from slider, or default to 3.5 oz if nil
                    let servingSizeOz = food.servingSize ?? 3.5
                    
                    print("🔍 SearchView: Looking up '\(food.name)' at \(String(format: "%.1f", servingSizeOz)) oz")
                    
                    do {
                        // Use tiered lookup with actual serving size
                        if let nutrition = try await NutritionService.shared.getNutritionForFood(food.name, amount: servingSizeOz, unit: "oz") {
                            print("✅ SearchView: Found nutrition for '\(food.name)' at \(String(format: "%.1f", servingSizeOz)) oz")
                            return (food.name, nutrition)
                        } else {
                            print("⚠️ SearchView: No nutrition found for '\(food.name)'")
                            return (food.name, nil)
                        }
                    } catch {
                        print("❌ SearchView: Error looking up '\(food.name)': \(error.localizedDescription)")
                        return (food.name, nil)
                    }
                }
            }
            
            // Collect results
            for try await (foodName, nutrition) in group {
                if let nutrition = nutrition {
                    foundCount += 1
                    aggregator.add(nutrition)
                }
            }
        }
        
        let totalFoods = detectedFoods.count - skippedCount
        let successRate = totalFoods > 0 ? Double(foundCount) / Double(totalFoods) : 0.0
        
        print("📊 SearchView: Database lookup results:")
        print("   Found: \(foundCount)/\(totalFoods) foods (skipped \(skippedCount) spices)")
        print("   Success rate: \(Int(successRate * 100))%")
        
        // Require at least 50% of foods found, or at least 1 food found
        guard foundCount > 0 && successRate >= 0.5 else {
            print("⚠️ SearchView: Insufficient foods found in database (need ≥50% or ≥1 food)")
            return nil
        }
        
        print("✅ SearchView: Aggregated nutrition - Calories: \(aggregator.getTotal(for: "calories")), Protein: \(aggregator.getTotal(for: "protein"))")
        
        return aggregator.toNutritionInfo()
    }
    
    /// Parse nutrition value string to Double
    private func parseNutritionValueDouble(_ value: String?) -> Double? {
        guard let value = value, !value.isEmpty else { return nil }
        
        var cleaned = value.replacingOccurrences(of: "µg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mcg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "IU", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "N/A", with: "0")
            .replacingOccurrences(of: "nil", with: "0")
        
        return Double(cleaned)
    }
    
    // MARK: - AI Analysis Methods
    
    /// Perform AI analysis with pre-calculated nutrition data
    private func performAIAnalysisWithNutrition(combinedFoods: String, calculatedNutrition: NutritionInfo, imageHash: String?, imageToSave: UIImage?) {
        print("🔍 SearchView: Step 2 - Performing AI analysis with calculated nutrition...")
        
        // Create clean food name for title (just ingredient names, no serving sizes)
        let cleanFoodName = detectedFoods.map { $0.name }.joined(separator: ", ")
        
        // Test API connection first
        AIService.shared.testAPIConnection { isWorking in
            DispatchQueue.main.async {
                if isWorking {
                    let healthProfile = UserHealthProfileManager.shared.currentProfile
                    
                    // Create nutrition summary for AI prompt (for better scoring)
                    let nutritionSummary = """
                    NUTRITION DATA (calculated from USDA database):
                    - Calories: \(calculatedNutrition.calories)
                    - Protein: \(calculatedNutrition.protein)
                    - Carbohydrates: \(calculatedNutrition.carbohydrates)
                    - Fat: \(calculatedNutrition.fat)
                    - Sugar: \(calculatedNutrition.sugar)
                    - Fiber: \(calculatedNutrition.fiber)
                    - Sodium: \(calculatedNutrition.sodium)
                    """
                    
                    // Add nutrition summary to food name for AI context (use clean name, not with serving sizes)
                    let foodNameWithNutrition = "\(cleanFoodName)\n\n\(nutritionSummary)"
                    
                    AIService.shared.analyzeFoodWithProfile(foodNameWithNutrition, healthProfile: healthProfile) { result in
                        DispatchQueue.main.async {
                            self.isAnalyzing = false
                            switch result {
                            case .success(let analysis):
                                print("✅ SearchView: AI analysis successful")
                                
                                // Extract individual food names for meal aggregation
                                let individualFoodNames = self.detectedFoods.map { $0.name }
                                
                                // Create meal analysis with:
                                // - Clean food name (just ingredients, no serving sizes) for title
                                // - Calculated nutrition for dropdowns
                                let mealAnalysis = FoodAnalysis(
                                    foodName: cleanFoodName, // Use clean name (just ingredients) for title
                                    overallScore: analysis.overallScore,
                                    summary: analysis.summary,
                                    healthScores: analysis.healthScores,
                                    keyBenefits: analysis.keyBenefits,
                                    ingredients: analysis.ingredients,
                                    bestPreparation: analysis.bestPreparation,
                                    servingSize: analysis.servingSize,
                                    nutritionInfo: calculatedNutrition, // Use calculated nutrition for dropdowns
                                    scanType: analysis.scanType,
                                    foodNames: individualFoodNames,
                                    foodPortions: analysis.foodPortions,
                                    suggestions: analysis.suggestions
                                )
                                
                                self.onFoodDetected(mealAnalysis, imageToSave, imageHash, nil)
                                // Clear the analysis image and detected foods after saving
                                self.currentAnalysisImage = nil
                                self.detectedFoods = []
                                self.isReadyToAnalyze = false
                                
                            case .failure(let error):
                                print("❌ SearchView: AI analysis failed: \(error.localizedDescription)")
                                // Fallback to full AI analysis
                                self.performFullAIAnalysis(
                                    combinedFoods: combinedFoods,
                                    imageHash: imageHash,
                                    imageToSave: imageToSave
                                )
                            }
                        }
                    }
                } else {
                    print("⚠️ SearchView: API not working, using fallback analysis")
                    self.performFullAIAnalysis(
                        combinedFoods: combinedFoods,
                        imageHash: imageHash,
                        imageToSave: imageToSave
                    )
                }
            }
        }
    }
    
    /// Perform full AI analysis (fallback when database lookup fails)
    private func performFullAIAnalysis(combinedFoods: String, imageHash: String?, imageToSave: UIImage?) {
        print("🔍 SearchView: Performing full AI analysis (fallback)...")
        
        // Create clean food name for title (just ingredient names, no serving sizes)
        let cleanFoodName = detectedFoods.map { $0.name }.joined(separator: ", ")
        
        // Test API connection first
        AIService.shared.testAPIConnection { isWorking in
            DispatchQueue.main.async {
                if isWorking {
                    let healthProfile = UserHealthProfileManager.shared.currentProfile
                    // Use clean food name (without serving sizes) for AI analysis
                    AIService.shared.analyzeFoodWithProfile(cleanFoodName, healthProfile: healthProfile) { result in
                        DispatchQueue.main.async {
                            self.isAnalyzing = false
                            switch result {
                            case .success(let analysis):
                                print("✅ SearchView: Full AI analysis successful")
                                
                                let individualFoodNames = self.detectedFoods.map { $0.name }
                                
                                let mealAnalysis = FoodAnalysis(
                                    foodName: cleanFoodName, // Use clean name (just ingredients) for title
                                    overallScore: analysis.overallScore,
                                    summary: analysis.summary,
                                    healthScores: analysis.healthScores,
                                    keyBenefits: analysis.keyBenefits,
                                    ingredients: analysis.ingredients,
                                    bestPreparation: analysis.bestPreparation,
                                    servingSize: analysis.servingSize,
                                    nutritionInfo: analysis.nutritionInfo,
                                    scanType: analysis.scanType,
                                    foodNames: individualFoodNames,
                                    foodPortions: analysis.foodPortions,
                                    suggestions: analysis.suggestions
                                )
                                
                                self.onFoodDetected(mealAnalysis, imageToSave, imageHash, nil)
                                self.currentAnalysisImage = nil
                                self.detectedFoods = []
                                self.isReadyToAnalyze = false
                                
                            case .failure(let error):
                                print("❌ SearchView: Full AI analysis failed: \(error.localizedDescription)")
                                
                                let individualFoodNames = self.detectedFoods.map { $0.name }
                                let fallbackAnalysis = AIService.shared.createFallbackAnalysis(for: cleanFoodName)
                                
                                let mealFallbackAnalysis = FoodAnalysis(
                                    foodName: cleanFoodName, // Use clean name (just ingredients) for title
                                    overallScore: fallbackAnalysis.overallScore,
                                    summary: fallbackAnalysis.summary,
                                    healthScores: fallbackAnalysis.healthScores,
                                    keyBenefits: fallbackAnalysis.keyBenefits,
                                    ingredients: fallbackAnalysis.ingredients,
                                    bestPreparation: fallbackAnalysis.bestPreparation,
                                    servingSize: fallbackAnalysis.servingSize,
                                    nutritionInfo: fallbackAnalysis.nutritionInfo,
                                    scanType: fallbackAnalysis.scanType,
                                    foodNames: individualFoodNames,
                                    foodPortions: nil,
                                    suggestions: fallbackAnalysis.suggestions
                                )
                                
                                self.onFoodDetected(mealFallbackAnalysis, imageToSave, imageHash, nil)
                                self.currentAnalysisImage = nil
                                self.detectedFoods = []
                                self.isReadyToAnalyze = false
                            }
                        }
                    }
                } else {
                    print("⚠️ SearchView: API not working, using fallback analysis")
                    self.isAnalyzing = false
                    
                    let individualFoodNames = self.detectedFoods.map { $0.name }
                    let fallbackAnalysis = AIService.shared.createFallbackAnalysis(for: cleanFoodName)
                    
                    let mealFallbackAnalysis = FoodAnalysis(
                        foodName: cleanFoodName, // Use clean name (just ingredients) for title
                        overallScore: fallbackAnalysis.overallScore,
                        summary: fallbackAnalysis.summary,
                        healthScores: fallbackAnalysis.healthScores,
                        keyBenefits: fallbackAnalysis.keyBenefits,
                        ingredients: fallbackAnalysis.ingredients,
                        bestPreparation: fallbackAnalysis.bestPreparation,
                        servingSize: fallbackAnalysis.servingSize,
                        nutritionInfo: fallbackAnalysis.nutritionInfo,
                        scanType: fallbackAnalysis.scanType,
                        foodNames: individualFoodNames,
                        foodPortions: nil,
                        suggestions: fallbackAnalysis.suggestions
                    )
                    
                    self.onFoodDetected(mealFallbackAnalysis, imageToSave, imageHash, nil)
                    self.currentAnalysisImage = nil
                    self.detectedFoods = []
                    self.isReadyToAnalyze = false
                }
            }
        }
    }
    
    private func addFood() {
        let trimmedInput = newFoodInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        // Add to detected foods if not already present
        let newFood = DetectedFood(name: trimmedInput, servingSize: nil)
        if !detectedFoods.contains(where: { $0.name == trimmedInput }) {
            detectedFoods.append(newFood)
            isReadyToAnalyze = true
            
            // Estimate serving size using AI (convert grams to ounces)
            if !isSpice(trimmedInput) {
                Task {
                    do {
                        let servingInfo = try await AIService.shared.estimateTypicalServingSize(foodName: trimmedInput, isRecipe: false)
                        // Convert grams to ounces (1 oz = 28.35g)
                        let ounces = servingInfo.weightGrams / 28.35
                        print("✅ SearchView: Estimated serving size for manually added '\(trimmedInput)': \(servingInfo.size) (\(Int(servingInfo.weightGrams))g = \(String(format: "%.1f", ounces)) oz)")
                        
                        // Update the detected food with estimated serving size
                        DispatchQueue.main.async {
                            if let food = self.detectedFoods.first(where: { $0.name == trimmedInput }) {
                                // Cap at 16oz max (slider range)
                                let cappedOunces = min(ounces, 16.0)
                                food.servingSize = cappedOunces
                                // @Published will trigger view update automatically via @ObservedObject in DetectedFoodRow
                            }
                        }
                    } catch {
                        print("⚠️ SearchView: Failed to estimate serving size for manually added '\(trimmedInput)', using default 3.5 oz: \(error)")
                        // Default to 3.5 oz (approximately 100g) - capped at 16oz
                        DispatchQueue.main.async {
                            if let food = self.detectedFoods.first(where: { $0.name == trimmedInput }) {
                                food.servingSize = min(3.5, 16.0)
                                // @Published will trigger view update automatically via @ObservedObject in DetectedFoodRow
                            }
                        }
                    }
                }
            }
        }
        
        newFoodInput = ""
    }
    
    // MARK: - Quick Dashboard Helper Functions
    
    private var quickDashboardTodaysMeals: [TrackedMeal] {
        let calendar = Calendar.current
        let today = Date()
        return mealStorageManager.getAllMeals().filter { calendar.isDate($0.timestamp, inSameDayAs: today) }
    }
    
    private var quickDashboardDailyAverageScore: Double {
        guard !quickDashboardTodaysMeals.isEmpty else { return 0.0 }
        let totalScore = quickDashboardTodaysMeals.reduce(0) { $0 + $1.healthScore }
        return totalScore / Double(quickDashboardTodaysMeals.count)
    }
    
    private var quickDashboardMacros: (protein: Double, carbs: Double, fat: Double, saturatedFat: Double, fiber: Double, sugar: Double) {
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        let totalSaturatedFat: Double = 0
        var totalFiber: Double = 0
        var totalSugar: Double = 0
        
        for meal in quickDashboardTodaysMeals {
            var analysis: FoodAnalysis? = nil
            
            if let imageHash = meal.imageHash,
               let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
                analysis = cachedAnalysis
            } else if let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: meal.name) {
                analysis = cachedAnalysis
            } else if !meal.foods.isEmpty,
                      let firstFood = meal.foods.first,
                      let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: firstFood) {
                analysis = cachedAnalysis
            } else if let originalAnalysis = meal.originalAnalysis {
                analysis = originalAnalysis
            }
            
            if let analysis = analysis,
               let nutrition = analysis.nutritionInfo {
                totalProtein += quickDashboardParseNutritionValue(nutrition.protein)
                totalCarbs += quickDashboardParseNutritionValue(nutrition.carbohydrates)
                totalFat += quickDashboardParseNutritionValue(nutrition.fat)
                totalFiber += quickDashboardParseNutritionValue(nutrition.fiber)
                totalSugar += quickDashboardParseNutritionValue(nutrition.sugar)
            }
        }
        
        return (totalProtein, totalCarbs, totalFat, totalSaturatedFat, totalFiber, totalSugar)
    }
    
    private var quickDashboardMicronutrients: [String: Double] {
        var totals: [String: Double] = [:]
        
        for meal in quickDashboardTodaysMeals {
            var analysis: FoodAnalysis? = nil
            
            if let imageHash = meal.imageHash,
               let cachedAnalysis = foodCacheManager.getCachedAnalysis(forImageHash: imageHash) {
                analysis = cachedAnalysis
            } else if let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: meal.name) {
                analysis = cachedAnalysis
            } else if !meal.foods.isEmpty,
                      let firstFood = meal.foods.first,
                      let cachedAnalysis = foodCacheManager.getCachedAnalysis(for: firstFood) {
                analysis = cachedAnalysis
            } else if let originalAnalysis = meal.originalAnalysis {
                analysis = originalAnalysis
            }
            
            if let analysis = analysis,
               let nutrition = analysis.nutritionInfo {
                if let vitaminD = nutrition.vitaminD, !vitaminD.isEmpty {
                    totals["Vitamin D", default: 0] += quickDashboardParseNutritionValue(vitaminD)
                }
                if let vitaminE = nutrition.vitaminE, !vitaminE.isEmpty {
                    totals["Vitamin E", default: 0] += quickDashboardParseNutritionValue(vitaminE)
                }
                if let potassium = nutrition.potassium, !potassium.isEmpty {
                    totals["Potassium", default: 0] += quickDashboardParseNutritionValue(potassium)
                }
                if let vitaminK = nutrition.vitaminK, !vitaminK.isEmpty {
                    totals["Vitamin K", default: 0] += quickDashboardParseNutritionValue(vitaminK)
                }
                if let magnesium = nutrition.magnesium, !magnesium.isEmpty {
                    totals["Magnesium", default: 0] += quickDashboardParseNutritionValue(magnesium)
                }
                if let vitaminA = nutrition.vitaminA, !vitaminA.isEmpty {
                    totals["Vitamin A", default: 0] += quickDashboardParseNutritionValue(vitaminA)
                }
                if let calcium = nutrition.calcium, !calcium.isEmpty {
                    totals["Calcium", default: 0] += quickDashboardParseNutritionValue(calcium)
                }
                if let vitaminC = nutrition.vitaminC, !vitaminC.isEmpty {
                    totals["Vitamin C", default: 0] += quickDashboardParseNutritionValue(vitaminC)
                }
                if let choline = nutrition.choline, !choline.isEmpty {
                    totals["Choline", default: 0] += quickDashboardParseNutritionValue(choline)
                }
                if let iron = nutrition.iron, !iron.isEmpty {
                    totals["Iron", default: 0] += quickDashboardParseNutritionValue(iron)
                }
                if let zinc = nutrition.zinc, !zinc.isEmpty {
                    totals["Zinc", default: 0] += quickDashboardParseNutritionValue(zinc)
                }
                if let folate = nutrition.folate, !folate.isEmpty {
                    totals["Folate (B9)", default: 0] += quickDashboardParseNutritionValue(folate)
                }
                if let vitaminB12 = nutrition.vitaminB12, !vitaminB12.isEmpty {
                    totals["Vitamin B12", default: 0] += quickDashboardParseNutritionValue(vitaminB12)
                }
                if let vitaminB6 = nutrition.vitaminB6, !vitaminB6.isEmpty {
                    totals["Vitamin B6", default: 0] += quickDashboardParseNutritionValue(vitaminB6)
                }
                if let selenium = nutrition.selenium, !selenium.isEmpty {
                    totals["Selenium", default: 0] += quickDashboardParseNutritionValue(selenium)
                }
                if let copper = nutrition.copper, !copper.isEmpty {
                    totals["Copper", default: 0] += quickDashboardParseNutritionValue(copper)
                }
                if let manganese = nutrition.manganese, !manganese.isEmpty {
                    totals["Manganese", default: 0] += quickDashboardParseNutritionValue(manganese)
                }
                if let thiamin = nutrition.thiamin, !thiamin.isEmpty {
                    totals["Thiamin (B1)", default: 0] += quickDashboardParseNutritionValue(thiamin)
                }
            }
        }
        
        return totals
    }
    
    private func quickDashboardParseNutritionValue(_ value: String?) -> Double {
        guard let value = value, !value.isEmpty else { return 0.0 }
        
        var cleaned = value.replacingOccurrences(of: "µg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mcg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "mg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "IU", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "kcal", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "g", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "N/A", with: "0")
            .replacingOccurrences(of: "nil", with: "0")
        
        return Double(cleaned) ?? 0.0
    }
    
    private func quickDashboardGetMacroTargetValue(for macro: String) -> Double {
        // Default RDA values for macros
        let rdaValues: [String: Double] = [
            "Protein": 50.0,
            "Carbs": 250.0,
            "Fat": 65.0,
            "Fiber": 30.0,
            "Sugar": 50.0,
            "Kcal": 2000.0
        ]
        return rdaValues[macro] ?? 0.0
    }
    
    private func quickDashboardGetRDAValue(for micronutrient: String) -> Double {
        let ageRange = healthProfileManager.currentProfile?.ageRange
        let sex = healthProfileManager.currentProfile?.sex
        return RDALookupService.shared.getRDA(for: micronutrient, ageRange: ageRange, sex: sex) ?? 0.0
    }
    
    private func quickDashboardGetDailySummary() -> (line1: String, line2: String) {
        guard !quickDashboardTodaysMeals.isEmpty else {
            return ("No meals tracked today", "Add meals to see your daily summary")
        }
        
        let avgScore = quickDashboardDailyAverageScore
        let mealCount = quickDashboardTodaysMeals.count
        
        let line1: String
        let line2: String
        
        if avgScore >= 80 {
            line1 = "Great day! Your meals average \(Int(avgScore))"
            line2 = "Keep up the excellent choices"
        } else if avgScore >= 60 {
            line1 = "Good progress with \(mealCount) meals averaging \(Int(avgScore))"
            line2 = "Try adding more vegetables and whole foods"
        } else {
            line1 = "\(mealCount) meals tracked, averaging \(Int(avgScore))"
            line2 = "Focus on nutrient-dense, whole foods"
        }
        
        return (line1, line2)
    }
    
    // MARK: - Micronutrient Benefits Helper
    private func getMicronutrientBenefits(for name: String) -> String {
        switch name {
        case "Vitamin D":
            return "For bones, immunity, mood"
        case "Vitamin E":
            return "For skin, antioxidant, circulation"
        case "Potassium":
            return "For heart, blood pressure, muscles"
        case "Vitamin K":
            return "For blood clotting, bones, heart"
        case "Magnesium":
            return "For muscles, sleep, energy"
        case "Vitamin A":
            return "For vision, skin, immunity"
        case "Calcium":
            return "For bones, teeth, muscles"
        case "Vitamin C":
            return "For immunity, skin, antioxidant"
        case "Choline":
            return "For brain, memory, liver"
        case "Iron":
            return "For energy, blood, oxygen"
        case "Zinc":
            return "For immunity, healing, growth"
        case "Folate (B9)":
            return "For DNA, red blood cells, pregnancy"
        case "Vitamin B12":
            return "For energy, nerves, red blood cells"
        case "Vitamin B6":
            return "For metabolism, brain, mood"
        case "Selenium":
            return "For antioxidant, thyroid, immunity"
        case "Copper":
            return "For energy, bones, immunity"
        case "Manganese":
            return "For bones, metabolism, antioxidant"
        case "Thiamin (B1)":
            return "For energy, nerves, heart"
        default:
            return ""
        }
    }
    
    private func quickDashboardMicronutrientMetadata(for name: String) -> (icon: String, gradient: LinearGradient, unit: String) {
        switch name {
        case "Vitamin D":
            return ("sun.max.fill", LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing), "IU")
        case "Vitamin E":
            return ("leaf.fill", LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Potassium":
            return ("bolt.fill", LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Vitamin K":
            return ("drop.fill", LinearGradient(colors: [Color.red, Color.pink], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Magnesium":
            return ("waveform.path", LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Vitamin A":
            return ("eye.fill", LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Calcium":
            return ("figure.stand", LinearGradient(colors: [Color.gray, Color(red: 0.7, green: 0.7, blue: 0.7)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Vitamin C":
            return ("heart.fill", LinearGradient(colors: [Color.red, Color.pink], startPoint: .leading, endPoint: .trailing), "mg")
        case "Choline":
            return ("brain.head.profile", LinearGradient(colors: [Color.blue, Color(red: 0.0, green: 0.478, blue: 1.0)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Iron":
            return ("drop.fill", LinearGradient(colors: [Color.red, Color(red: 0.8, green: 0.2, blue: 0.2)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Zinc":
            return ("shield.fill", LinearGradient(colors: [Color(red: 0.42, green: 0.557, blue: 0.498), Color(red: 0.3, green: 0.7, blue: 0.6)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Folate (B9)":
            return ("heart.circle.fill", LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Vitamin B12":
            return ("bolt.fill", LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Vitamin B6":
            return ("brain.head.profile", LinearGradient(colors: [Color.blue, Color(red: 0.0, green: 0.478, blue: 1.0)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Selenium":
            return ("shield.checkered", LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing), "mcg")
        case "Copper":
            return ("circle.hexagongrid.fill", LinearGradient(colors: [Color(red: 0.8, green: 0.4, blue: 0.0), Color(red: 0.9, green: 0.6, blue: 0.2)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Manganese":
            return ("sparkles", LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), "mg")
        case "Thiamin (B1)":
            return ("bolt.heart.fill", LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color.red], startPoint: .leading, endPoint: .trailing), "mg")
        default:
            return ("pills.fill", LinearGradient(colors: [Color.gray, Color.gray], startPoint: .leading, endPoint: .trailing), "mg")
        }
    }
    
    private var quickDashboardAvailableMicronutrients: [String] {
        return ["Calcium", "Choline", "Copper", "Folate (B9)", "Iron", "Magnesium", "Manganese", "Potassium", "Selenium", "Thiamin (B1)", "Vitamin A", "Vitamin B12", "Vitamin B6", "Vitamin C", "Vitamin D", "Vitamin E", "Vitamin K", "Zinc"]
    }
    
    private func loadQuickDashboardSelectedMicronutrients() {
        if let data = UserDefaults.standard.data(forKey: "quickDashboardSelectedMicronutrients"),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            selectedMicronutrients = Set(array)
        }
    }
    
    private func saveQuickDashboardSelectedMicronutrients() {
        if let data = try? JSONEncoder().encode(Array(selectedMicronutrients)) {
            UserDefaults.standard.set(data, forKey: "quickDashboardSelectedMicronutrients")
        }
    }
    
    // MARK: - Quick Dashboard Section
    private var quickDashboardSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    quickDashboardExpanded.toggle()
                    if quickDashboardExpanded {
                        loadQuickDashboardSelectedMicronutrients()
                    }
                }
            }) {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 33, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 33, height: 33)
                        
                        Text("Quick Dashboard")
                            .font(.system(size: colorScheme == .dark ? 24 : 24, weight: .bold, design: .default))
                            .foregroundColor(colorScheme == .dark ? .white : .secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: quickDashboardExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .secondary)
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, quickDashboardExpanded ? 8 : 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            
            if quickDashboardExpanded {
                VStack(alignment: .leading, spacing: 0) {
                        // Donut Chart and Macros (same as Tracker)
                        quickDashboardMacroSection
                            .padding(.top, -30)
                            .padding(.bottom, -40)
                        
                        // Kcal subhead
                        let macros = quickDashboardMacros
                        let estimatedCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
                        let dailyCalorieTarget = quickDashboardGetMacroTargetValue(for: "Kcal")
                        let kcalDifference = dailyCalorieTarget - estimatedCalories
                        let kcalSubheadText: String = {
                            if abs(kcalDifference) < 10 {
                                return "On Target"
                            } else if kcalDifference > 0 {
                                return "\(Int(kcalDifference)) Kcals To Daily Target"
                            } else {
                                return "\(Int(abs(kcalDifference))) Kcals Over Daily Target"
                            }
                        }()
                        
                        Text(kcalSubheadText)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 0)
                            .padding(.bottom, 16)
                        
                        // Progress Bars Section
                        VStack(alignment: .leading, spacing: 16) {
                            // Kcal progress bar
                            quickDashboardMacroProgressBar(macroName: "Kcal", currentValue: estimatedCalories, gradient: LinearGradient(colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)], startPoint: .leading, endPoint: .trailing), targetValue: dailyCalorieTarget, unit: "Kcal")
                            
                            // Macro progress bars
                            quickDashboardMacroProgressBar(macroName: "Protein", currentValue: macros.protein, gradient: LinearGradient(colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.0, green: 0.8, blue: 0.8)], startPoint: .leading, endPoint: .trailing))
                            
                            quickDashboardMacroProgressBar(macroName: "Carbs", currentValue: macros.carbs, gradient: LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing))
                            
                            quickDashboardMacroProgressBar(macroName: "Fat", currentValue: macros.fat, gradient: LinearGradient(colors: [Color(red: 1.0, green: 0.843, blue: 0.0), Color(red: 0.678, green: 0.847, blue: 0.902)], startPoint: .leading, endPoint: .trailing))
                            
                            quickDashboardMacroProgressBar(macroName: "Fiber", currentValue: macros.fiber, gradient: LinearGradient(colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)], startPoint: .leading, endPoint: .trailing))
                            
                            quickDashboardMacroProgressBar(macroName: "Sugar", currentValue: macros.sugar, gradient: LinearGradient(colors: [Color.red, Color.orange], startPoint: .leading, endPoint: .trailing))
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                        
                        // Hairline
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        
                        // Daily Score Circle and Summary
                        HStack(alignment: .top, spacing: 16) {
                            // Score Circle (left)
                            ZStack {
                                Circle()
                                    .fill(quickDashboardScoreGradient(Int(quickDashboardDailyAverageScore)))
                                    .frame(width: 80, height: 80)
                                
                                VStack(spacing: 2) {
                                    Text("\(Int(quickDashboardDailyAverageScore))")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Score")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            
                            // Summary (right)
                            VStack(alignment: .leading, spacing: 8) {
                                let summary = quickDashboardGetDailySummary()
                                Text(summary.line1)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(summary.line2)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        
                        // Hairline
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        
                        // Add Data Points Dropdown
                        VStack(alignment: .leading, spacing: 0) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    addDataPointsExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Text("Add Micronutrients")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Image(systemName: addDataPointsExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(maxWidth: .infinity)
                            
                            if addDataPointsExpanded {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(quickDashboardAvailableMicronutrients, id: \.self) { micronutrient in
                                        HStack {
                                            Button(action: {
                                                if selectedMicronutrients.contains(micronutrient) {
                                                    selectedMicronutrients.remove(micronutrient)
                                                } else {
                                                    selectedMicronutrients.insert(micronutrient)
                                                }
                                                saveQuickDashboardSelectedMicronutrients()
                                            }) {
                                                Image(systemName: selectedMicronutrients.contains(micronutrient) ? "checkmark.square.fill" : "square")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(selectedMicronutrients.contains(micronutrient) ? .blue : .secondary)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            Text(micronutrient)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            
                            // Selected Micronutrient Progress Bars
                            if !selectedMicronutrients.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(selectedMicronutrients).sorted(), id: \.self) { micronutrientName in
                                        let metadata = quickDashboardMicronutrientMetadata(for: micronutrientName)
                                        let currentValue = quickDashboardMicronutrients[micronutrientName] ?? 0.0
                                        let targetValue = quickDashboardGetRDAValue(for: micronutrientName)
                                        
                                        VStack(spacing: 12) {
                                            HStack(spacing: 8) {
                                                Text(micronutrientName)
                                                    .font(.subheadline)
                                                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                                                
                                                Spacer()
                                                
                                                Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(metadata.unit) (RDA)")
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    let backgroundOpacity = colorScheme == .dark ? 0.2 : 0.4
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(metadata.gradient.opacity(backgroundOpacity))
                                                        .frame(height: 10)
                                                    
                                                    let progress = min(currentValue / targetValue, 1.0)
                                                    let fillWidth = geometry.size.width * CGFloat(progress)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(metadata.gradient)
                                                        .frame(width: fillWidth, height: 10)
                                                }
                                                .frame(height: 10)
                                            }
                                            
                                            // Benefit description under progress bar
                                            Text(getMicronutrientBenefits(for: micronutrientName))
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 12)
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
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
    
    // MARK: - Quick Dashboard Macros Section (Donut Chart)
    private var quickDashboardMacroSection: some View {
        let macros = quickDashboardMacros
        let total = macros.protein + macros.carbs + macros.fat + macros.fiber + macros.sugar
        
        guard total > 0 else {
            return AnyView(
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No nutritional data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            )
        }
        
        struct QuickDashboardMacroData: Identifiable {
            let id = UUID()
            let name: String
            let value: Double
            let gradient: LinearGradient
            let primaryColor: Color
        }
        
        let macroData: [QuickDashboardMacroData] = [
            QuickDashboardMacroData(
                name: "Protein",
                value: macros.protein,
                gradient: LinearGradient(colors: [Color(red: 0.0, green: 0.478, blue: 1.0), Color(red: 0.0, green: 0.8, blue: 0.8)], startPoint: .leading, endPoint: .trailing),
                primaryColor: Color(red: 0.0, green: 0.478, blue: 1.0)
            ),
            QuickDashboardMacroData(
                name: "Carbs",
                value: macros.carbs,
                gradient: LinearGradient(colors: [Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0), Color(red: 217/255.0, green: 233/255.0, blue: 33/255.0)], startPoint: .leading, endPoint: .trailing),
                primaryColor: Color(red: 231/255.0, green: 133/255.0, blue: 12/255.0)
            ),
            QuickDashboardMacroData(
                name: "Fat",
                value: macros.fat,
                gradient: LinearGradient(
                    colors: [
                        Color.purple, // Purple (Upload It photo)
                        Color(red: 0.6, green: 0.2, blue: 0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color.purple
            ),
            QuickDashboardMacroData(
                name: "Fiber",
                value: macros.fiber,
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.557, blue: 0.498), // Teal-green (Say It mic)
                        Color(red: 0.3, green: 0.7, blue: 0.6)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color(red: 0.42, green: 0.557, blue: 0.498)
            ),
            QuickDashboardMacroData(
                name: "Sugar",
                value: macros.sugar,
                gradient: LinearGradient(
                    colors: [
                        Color(red: 0.255, green: 0.643, blue: 0.655), // Teal (Compare arrow)
                        Color(red: 0.0, green: 0.8, blue: 0.8)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                primaryColor: Color(red: 0.255, green: 0.643, blue: 0.655)
            )
        ].filter { $0.value > 0 }
        
        let estimatedCalories = (macros.protein * 4) + (macros.carbs * 4) + (macros.fat * 9)
        
        return AnyView(
            VStack(spacing: 0) {
                ZStack {
                    Chart {
                        ForEach(macroData) { macro in
                            SectorMark(
                                angle: .value("Value", macro.value),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(macro.gradient)
                        }
                    }
                    .frame(height: 280)
                    .padding(.horizontal, 70)
                    .padding(.vertical, 60)
                    
                    GeometryReader { geometry in
                        let centerX = geometry.size.width / 2
                        let centerY = geometry.size.height / 2
                        
                        VStack(spacing: 2) {
                            Text("\(Int(estimatedCalories))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Kcal")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .position(x: centerX, y: centerY)
                    }
                    .frame(height: 280)
                    
                    // Callouts with hairlines overlay
                    GeometryReader { geometry in
                        let chartSize: CGFloat = 280 // Increased from 200
                        let centerX = geometry.size.width / 2
                        let centerY: CGFloat = geometry.size.height / 2 // Center vertically in available space
                        let radius: CGFloat = 110 // Increased from 80 to 110 (proportionally larger)
                        let calloutIndices = Array(0..<macroData.count)
                        
                        ZStack {
                            ForEach(calloutIndices, id: \.self) { index in
                                let macro = macroData[index]
                                let percentage = macro.value / total
                                // Calculate cumulative angle up to this slice (starting from top, clockwise)
                                let previousTotal = macroData.prefix(index).reduce(0.0) { $0 + $1.value }
                                let cumulativeAngle = -90.0 + (previousTotal / total) * 360.0 // Start at top (-90 degrees)
                                // Middle angle of this slice
                                let middleAngle = cumulativeAngle + (percentage * 360 / 2)
                                let angleInRadians = middleAngle * .pi / 180
                                
                                // Position on edge of pie chart (outer edge)
                                let sliceEdgeX = centerX + cos(angleInRadians) * radius
                                let sliceEdgeY = centerY + sin(angleInRadians) * radius
                                
                                // Position for label (further out)
                                let labelDistance: CGFloat = radius + 40
                                let labelX = centerX + cos(angleInRadians) * labelDistance
                                let labelY = centerY + sin(angleInRadians) * labelDistance
                                
                                // Hairline from slice to label
                                Path { path in
                                    path.move(to: CGPoint(x: sliceEdgeX, y: sliceEdgeY))
                                    path.addLine(to: CGPoint(x: labelX, y: labelY))
                                }
                                .stroke(macro.primaryColor.opacity(0.5), lineWidth: 1.5)
                                
                                // Label with value (current/target format)
                                let targetValue = quickDashboardGetMacroTargetValue(for: macro.name)
                                VStack(spacing: 2) {
                                    Text(macro.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("\(Int(macro.value))/\(Int(targetValue))g")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(colorScheme == .dark ? Color.black.opacity(0.9) : Color.white.opacity(0.95))
                                        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                                )
                                .position(x: labelX, y: labelY)
                            }
                        }
                    }
                }
                .frame(height: 380) // Increased from 300 to 380 to accommodate larger chart and callouts
                .clipped() // Prevent callouts from extending beyond bounds
            }
            .padding(.vertical, 8)
        )
    }
    
    // MARK: - Quick Dashboard Macro Progress Bar
    private func quickDashboardMacroProgressBar(macroName: String, currentValue: Double, gradient: LinearGradient, targetValue: Double? = nil, unit: String = "g") -> some View {
        let targetValue = targetValue ?? quickDashboardGetMacroTargetValue(for: macroName)
        
        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(macroName)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                Spacer()
                
                Text("\(Int(round(currentValue)))/\(Int(round(targetValue)))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    let backgroundOpacity = colorScheme == .dark ? 0.2 : 0.4
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gradient.opacity(backgroundOpacity))
                        .frame(height: 10)
                    
                    let progress = min(currentValue / targetValue, 1.0)
                    let fillWidth = geometry.size.width * CGFloat(progress)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gradient)
                        .frame(width: fillWidth, height: 10)
                }
                .frame(height: 10)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
    
    // MARK: - Quick Dashboard Score Gradient
    private func quickDashboardScoreGradient(_ score: Int) -> LinearGradient {
        let progress = CGFloat(score) / 100.0
        
        let startColor: Color
        let endColor: Color
        
        if progress <= 0.4 {
            startColor = Color(red: 0.8, green: 0.1, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.4, blue: 0.1)
        } else if progress <= 0.6 {
            startColor = Color(red: 0.9, green: 0.5, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.7, blue: 0.2)
        } else if progress <= 0.8 {
            startColor = Color(red: 0.8, green: 0.7, blue: 0.2)
            endColor = Color(red: 0.4, green: 0.7, blue: 0.4)
        } else {
            startColor = Color(red: 0.3, green: 0.6, blue: 0.3)
            endColor = Color(red: 0.2, green: 0.5, blue: 0.2)
        }
        
        return LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Recently Analyzed Section
    private var recentlyAnalyzedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recently Analyzed")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Sort and Filter Pickers
            let allItems = getAllAnalyzedItems()
            if !allItems.isEmpty {
                HStack {
                    Text("Sort by:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.caption)
                    
                    Spacer()
                    
                    Text("Filter:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Filter", selection: $filterOption) {
                        ForEach(AnalyzedItemFilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .font(.caption)
                }
                .padding(.horizontal, 4)
            }
            
            let filteredAndSortedItems = getFilteredAndSortedItems()
            if filteredAndSortedItems.isEmpty {
                Text("No recently analyzed items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                let displayCount = min(displayedFoodCount, filteredAndSortedItems.count)
                let itemsToShow = Array(filteredAndSortedItems.prefix(displayCount))
                
                LazyVStack(spacing: 12) {
                    ForEach(itemsToShow, id: \.id) { item in
                        UnifiedAnalyzedRowView(item: item, onTap: { item in
                            handleItemTap(item)
                        }, onDelete: { item in
                            handleItemDelete(item)
                        })
                    }
                }
                
                // View More/Show Less Buttons
                if filteredAndSortedItems.count > 6 {
                    HStack(spacing: 12) {
                        // Show Less button (only if showing more than 6)
                        if displayedFoodCount > 6 {
                            Button(action: {
                                displayedFoodCount = max(6, displayedFoodCount - 6)
                            }) {
                                Text("Show Less")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
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
                                    .cornerRadius(8)
                            }
                        }
                        
                        // View More button (only if more items available)
                        if filteredAndSortedItems.count > displayedFoodCount {
                            Button(action: {
                                displayedFoodCount = min(displayedFoodCount + 6, filteredAndSortedItems.count)
                            }) {
                                Text("View More")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
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
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Recently Imported Section
    private var recentlyImportedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Recipes")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            let importedRecipes = recipeManager.recipes.filter { !$0.isOriginal }
            
            if importedRecipes.isEmpty {
                Text("No imported recipes yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                let displayCount = min(displayedRecipeCount, importedRecipes.count)
                let recipesToShow = Array(importedRecipes.sorted { $0.dateAdded > $1.dateAdded }.prefix(displayCount))
                
                LazyVStack(spacing: 12) {
                    ForEach(recipesToShow, id: \.id) { recipe in
                        RecipeRowView(recipe: recipe, onTap: { selectedRecipe in
                            onRecipeTapped?(selectedRecipe)
                        }, onDelete: { recipeToDelete in
                            Task {
                                try await recipeManager.deleteRecipe(recipeToDelete)
                            }
                        })
                    }
                }
                
                // View More/Show Less Buttons
                if importedRecipes.count > 6 {
                    HStack(spacing: 12) {
                        // Show Less button (only if showing more than 6)
                        if displayedRecipeCount > 6 {
                            Button(action: {
                                displayedRecipeCount = max(6, displayedRecipeCount - 6)
                            }) {
                                Text("Show Less")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
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
                                    .cornerRadius(8)
                            }
                        }
                        
                        // View More button (only if more items available)
                        if importedRecipes.count > displayedRecipeCount {
                            Button(action: {
                                displayedRecipeCount = min(displayedRecipeCount + 6, importedRecipes.count)
                            }) {
                                Text("View More")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
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
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Unified Item Type
    enum UnifiedAnalyzedItem: Identifiable {
        case recipe(Recipe)
        case meal(FoodCacheEntry)
        case food(FoodCacheEntry)
        case grocery(FoodCacheEntry)
        
        var id: String {
            switch self {
            case .recipe(let recipe):
                return "recipe-\(recipe.id.uuidString)"
            case .meal(let entry), .food(let entry), .grocery(let entry):
                // Use imageHash if available for better deduplication, otherwise use cacheKey
                if let imageHash = entry.imageHash {
                    return "cache-\(imageHash)"
                }
                return "cache-\(entry.cacheKey)"
            }
        }
        
        var date: Date {
            switch self {
            case .recipe(let recipe):
                return recipe.dateAdded
            case .meal(let entry), .food(let entry), .grocery(let entry):
                return entry.analysisDate
            }
        }
        
        var score: Int? {
            switch self {
            case .recipe(let recipe):
                return recipe.longevityScore
            case .meal(let entry), .food(let entry), .grocery(let entry):
                return entry.fullAnalysis.overallScore
            }
        }
        
        var title: String {
            switch self {
            case .recipe(let recipe):
                return recipe.title
            case .meal(let entry), .food(let entry), .grocery(let entry):
                return entry.foodName
            }
        }
        
        var imageUrl: String? {
            switch self {
            case .recipe(let recipe):
                return recipe.image
            case .meal, .food, .grocery:
                return nil
            }
        }
        
        var imageHash: String? {
            switch self {
            case .recipe:
                return nil
            case .meal(let entry), .food(let entry), .grocery(let entry):
                return entry.imageHash
            }
        }
        
        var itemType: AnalyzedItemFilterOption {
            switch self {
            case .recipe:
                return .recipes
            case .meal:
                return .meals
            case .food:
                return .foods
            case .grocery:
                return .groceries
            }
        }
    }
    
    // MARK: - Data Aggregation
    private func getAllAnalyzedItems() -> [UnifiedAnalyzedItem] {
        var items: [UnifiedAnalyzedItem] = []
        var seenIds = Set<String>()
        
        // Add recipes with analysis
        let analyzedRecipes = recipeManager.recipes.filter { $0.longevityScore != nil }
        for recipe in analyzedRecipes {
            let item = UnifiedAnalyzedItem.recipe(recipe)
            if !seenIds.contains(item.id) {
                items.append(item)
                seenIds.insert(item.id)
            }
        }
        
        // Add meals (food cache entries that are meals)
        // Meals are entries with scanType == "meal"
        let meals = foodCacheManager.cachedAnalyses.filter { entry in
            let scanType = entry.scanType ?? ""
            return scanType == "meal"
        }
        for meal in meals {
            let item = UnifiedAnalyzedItem.meal(meal)
            if !seenIds.contains(item.id) {
                items.append(item)
                seenIds.insert(item.id)
            }
        }
        
        // Add foods (food cache entries that are single foods)
        // Foods are entries with scanType == "food" or entries without a scanType (legacy food analyses)
        let foods = foodCacheManager.cachedAnalyses.filter { entry in
            let scanType = entry.scanType ?? ""
            // Exclude groceries (product/nutrition_label) - those are handled separately
            if scanType == "product" || scanType == "nutrition_label" {
                return false
            }
            // Include explicit foods, or entries without a scanType (legacy food analyses)
            return scanType == "food" || scanType.isEmpty
        }
        for food in foods {
            let item = UnifiedAnalyzedItem.food(food)
            if !seenIds.contains(item.id) {
                items.append(item)
                seenIds.insert(item.id)
            }
        }
        
        // Add groceries (product or nutrition_label)
        let groceries = foodCacheManager.cachedAnalyses.filter { entry in
            let scanType = entry.scanType ?? ""
            return scanType == "product" || scanType == "nutrition_label"
        }
        for grocery in groceries {
            let item = UnifiedAnalyzedItem.grocery(grocery)
            if !seenIds.contains(item.id) {
                items.append(item)
                seenIds.insert(item.id)
            }
        }
        
        return items
    }
    
    private func getFilteredAndSortedItems() -> [UnifiedAnalyzedItem] {
        var items = getAllAnalyzedItems()
        
        // Apply filter
        if filterOption != .all {
            items = items.filter { $0.itemType == filterOption }
        }
        
        // Apply sort
        switch sortOption {
        case .recency:
            items.sort { $0.date > $1.date }
        case .scoreHighLow:
            items.sort { ($0.score ?? 0) > ($1.score ?? 0) }
        case .scoreLowHigh:
            items.sort { ($0.score ?? 0) < ($1.score ?? 0) }
        }
        
        return items
    }
    
    // MARK: - Item Actions
    private func handleItemTap(_ item: UnifiedAnalyzedItem) {
        switch item {
        case .recipe(let recipe):
            onRecipeTapped?(recipe)
        case .meal(let entry), .food(let entry), .grocery(let entry):
            // For cached items, pass the imageHash if available, but don't save again
            // The ContentView will check if it's already cached before saving
            onFoodDetected(entry.fullAnalysis, nil, entry.imageHash, entry.inputMethod) // Pass through inputMethod from cache
        }
    }
    
    private func handleItemDelete(_ item: UnifiedAnalyzedItem) {
        switch item {
        case .recipe(let recipe):
            Task {
                try? await recipeManager.deleteRecipe(recipe)
            }
        case .meal(let entry), .food(let entry), .grocery(let entry):
            foodCacheManager.deleteAnalysis(withCacheKey: entry.cacheKey)
        }
    }
    
    // MARK: - Sorting Logic (Legacy - kept for compatibility)
    private func getSortedFoods() -> [FoodCacheEntry] {
        switch sortOption {
        case .recency:
            return foodCacheManager.cachedAnalyses.sorted { $0.analysisDate > $1.analysisDate }
        case .scoreHighLow:
            return foodCacheManager.cachedAnalyses.sorted { $0.fullAnalysis.overallScore > $1.fullAnalysis.overallScore }
        case .scoreLowHigh:
            return foodCacheManager.cachedAnalyses.sorted { $0.fullAnalysis.overallScore < $1.fullAnalysis.overallScore }
        }
    }
}

struct ProgressBar: View {
    @State private var animationOffset: CGFloat = 0.0
    var isAnimating: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.white.opacity(0.25))
                
                // Barber pole stripes
                if isAnimating {
                    HStack(spacing: 0) {
                        ForEach(0..<20, id: \.self) { index in
                            Rectangle()
                                .fill(index % 2 == 0 ? Color.white : Color.clear)
                                .frame(width: 8)
                        }
                    }
                    .frame(width: geometry.size.width * 2)
                    .offset(x: animationOffset)
                    .clipped()
                    .mask(Capsule())
                }
            }
            .onAppear {
                if isAnimating {
                    startAnimation()
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    startAnimation()
                } else {
                    animationOffset = 0.0
                }
            }
        }
        .frame(height: 4)
    }
    
    private func startAnimation() {
        guard isAnimating else { return }
        withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            animationOffset = -40 // Move stripes to the left
        }
    }
}

struct SearchMenuButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let gradient: LinearGradient?
    let action: () -> Void
    
    init(title: String, subtitle: String, icon: String, color: Color, gradient: LinearGradient? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.gradient = gradient
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Group {
                            if let gradient = gradient {
                                gradient
                            } else {
                                color
                            }
                        }
                    )
                    .cornerRadius(12)
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SideMenuView: View {
    @Binding var isPresented: Bool
    @State private var showingDashboard = false
    @State private var showingProfile = false
    @State private var showingSupplements = false
    @State private var showingMealPlanner = false
    @State private var showingPetFoods = false
    @State private var showingAccount = false
    @State private var showingPrivacy = false
    
    var body: some View {
        ZStack {
            // Background overlay with larger tap area
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
            
            // Side menu content
            HStack {
                VStack(spacing: 0) {
                    // Header with logo
                    VStack(spacing: 12) {
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 50)
                            .padding(.top, 60)
                        
                        VStack(spacing: 0) {
                            Text("LONGEVITY")
                                .font(.system(size: 20, weight: .light, design: .default))
                                .tracking(6)
                                .foregroundColor(.primary)
                                .dynamicTypeSize(.large)
                            
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 25, height: 1)
                                
                                Text("FOOD LAB")
                                    .font(.system(size: 10, weight: .light, design: .default))
                                    .tracking(4)
                                    .foregroundColor(.secondary)
                                    .dynamicTypeSize(.large)
                                
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 25, height: 1)
                            }
                        }
                    }
                    .padding(.bottom, 25)
                    
                    // Menu Items
                    VStack(spacing: 12) {
                        SideMenuItem(
                            title: "Dashboard",
                            icon: "house.fill",
                            color: Color(red: 0.42, green: 0.557, blue: 0.498)
                        ) {
                            showingDashboard = true
                        }
                        
                        SideMenuItem(
                            title: "Profile",
                            icon: "person.fill",
                            color: Color(red: 0.42, green: 0.557, blue: 0.498)
                        ) {
                            showingProfile = true
                        }
                        
                        SideMenuItem(
                            title: "Supplements",
                            icon: "pills.fill",
                            color: Color(red: 0.42, green: 0.557, blue: 0.498)
                        ) {
                            showingSupplements = true
                        }
                        
                        SideMenuItem(
                            title: "Meal Planner",
                            icon: "fork.knife",
                            color: Color(red: 0.42, green: 0.557, blue: 0.498)
                        ) {
                            showingMealPlanner = true
                        }
                        
                        SideMenuItem(
                            title: "Pet Foods",
                            icon: "pawprint.fill",
                            color: Color.orange
                        ) {
                            showingPetFoods = true
                        }
                        
                        SideMenuItem(
                            title: "Account",
                            icon: "person.circle",
                            color: Color.blue
                        ) {
                            showingAccount = true
                        }
                        
                        SideMenuItem(
                            title: "Privacy",
                            icon: "lock.shield",
                            color: Color.gray
                        ) {
                            showingPrivacy = true
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 250)
                .padding(.horizontal, 20)
                .background(Color(UIColor.systemGroupedBackground))
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1),
                    alignment: .trailing
                )
                .offset(x: isPresented ? 0 : -250)
                .animation(.easeInOut(duration: 0.3), value: isPresented)
                
                Spacer()
            }
        }
        .ignoresSafeArea()
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // Swipe left to close (negative translation.width)
                    if value.translation.width < -50 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                }
        )
        .sheet(isPresented: $showingDashboard) {
            LongevityDashboardView()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingSupplements) {
            SupplementsView()
        }
        .sheet(isPresented: $showingMealPlanner) {
            MealPlannerHomeView()
        }
        .sheet(isPresented: $showingPetFoods) {
            PetFoodsView()
        }
        .sheet(isPresented: $showingAccount) {
            AccountView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyView()
        }
    }
}

struct SideMenuItem: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .cornerRadius(10)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AccountView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Account Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
                
                Text("Account management features will be implemented here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Privacy Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
                
                Text("Privacy and data management features will be implemented here.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Recipe Row View
struct RecipeRowView: View {
    let recipe: Recipe
    let onTap: (Recipe) -> Void
    let onDelete: (Recipe) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDeleteConfirmation = false
    @StateObject private var recipeManager = RecipeManager.shared
    
    var body: some View {
        ZStack {
            Button(action: {
                onTap(recipe)
            }) {
                HStack(spacing: 12) {
                    // Recipe Image (using cached image system like Shop screen)
                    ZStack(alignment: .bottomLeading) {
                        if let imageUrl = recipe.image, !imageUrl.isEmpty {
                            let fixedImageUrl = imageUrl.hasPrefix("//") ? "https:" + imageUrl : imageUrl
                            
                            CachedRecipeImageView(
                                urlString: fixedImageUrl,
                                placeholder: AnyView(
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        )
                                )
                            )
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        // Heart icon (bottom left) - blue-purple to bright blue gradient, not tappable
                        if recipe.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 64/255.0, green: 56/255.0, blue: 213/255.0),  // Blue-purple #4038D5
                                            Color(red: 12/255.0, green: 97/255.0, blue: 255/255.0)   // Bright blue #0C61FF
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .padding(4)
                        }
                    }
                    
                    // Recipe Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if recipe.servings > 0 {
                            // Calculate scaled servings
                            let scaledServings = Int(round(Double(recipe.servings) * recipe.scaleFactor))
                            let servingsText = recipe.scaleFactor != 1.0 
                                ? "\(scaledServings) servings (Scaled)"
                                : "\(recipe.servings) servings"
                            
                            Text(servingsText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if recipe.prepTime > 0 {
                            Text("\(recipe.prepTime) min prep")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Score Circle on Right Side
                    RecipeScoreCircleCompact(recipe: recipe)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.42, green: 0.557, blue: 0.498), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Delete Button - Top Right Corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(colorScheme == .dark ? Color(.lightGray) : Color(red: 0.42, green: 0.557, blue: 0.498))
                            .frame(width: 44, height: 44) // Larger tap area
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, -8) // Move much closer to top edge
                    .padding(.trailing, -8) // Move much closer to right edge
                }
                Spacer()
            }
            .zIndex(1) // Ensure X button is above card button
            .allowsHitTesting(true) // Explicitly enable hit testing
        }
        .confirmationDialog("Delete Recipe", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete(recipe)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(recipe.title)'?")
        }
    }
}

// MARK: - Recipe Score Circle Compact (for card view)
struct RecipeScoreCircleCompact: View {
    let recipe: Recipe
    
    var body: some View {
        ZStack {
            // Background circle with gradient (red to green based on score)
            if let score = recipe.longevityScore {
                // Score exists - gradient background (red to green)
                Circle()
                    .fill(scoreGradient(score))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                
                // Score number and one-word summary (white text - reverse type)
                VStack(spacing: -4) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(scoreLabel(score).uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            } else {
                // No score - trademark green background
                Circle()
                    .fill(Color(red: 0.42, green: 0.557, blue: 0.498))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                
                // "TAP to score recipe" text (white bold text)
                VStack(spacing: 0) {
                    Text("TAP")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 0) {
                        Text("to score")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("recipe")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // Gradient that runs from red to green based on score (darker gradations for better contrast)
    private func scoreGradient(_ score: Int) -> LinearGradient {
        let progress = CGFloat(score) / 100.0
        
        // Red to green gradient based on score with darker gradations for better text contrast
        // 0-40: Dark red to dark orange
        // 41-60: Dark orange to dark yellow
        // 61-80: Dark yellow to darker green
        // 81-100: Darker green to dark green
        
        let startColor: Color
        let endColor: Color
        
        if progress <= 0.4 {
            // Dark red to dark orange
            startColor = Color(red: 0.8, green: 0.1, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.4, blue: 0.1)
        } else if progress <= 0.6 {
            // Dark orange to dark yellow
            startColor = Color(red: 0.9, green: 0.5, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.7, blue: 0.2)
        } else if progress <= 0.8 {
            // Dark yellow to darker green
            startColor = Color(red: 0.8, green: 0.7, blue: 0.2)
            endColor = Color(red: 0.4, green: 0.7, blue: 0.4)
        } else {
            // Darker green to dark green
            startColor = Color(red: 0.3, green: 0.6, blue: 0.3)
            endColor = Color(red: 0.2, green: 0.5, blue: 0.2)
        }
        
        return LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 90...100: return "Exceptional"
        case 80...89: return "Excellent"
        case 70...79: return "Very Good"
        case 60...69: return "Good"
        case 50...59: return "Moderate"
        case 40...49: return "Fair"
        default: return "Limited"
        }
    }
}

// MARK: - Unified Analyzed Row View
struct UnifiedAnalyzedRowView: View {
    let item: SearchView.UnifiedAnalyzedItem
    let onTap: (SearchView.UnifiedAnalyzedItem) -> Void
    let onDelete: (SearchView.UnifiedAnalyzedItem) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDeleteConfirmation = false
    @State private var cachedImage: UIImage?
    @StateObject private var recipeManager = RecipeManager.shared
    
    init(item: SearchView.UnifiedAnalyzedItem, onTap: @escaping (SearchView.UnifiedAnalyzedItem) -> Void, onDelete: @escaping (SearchView.UnifiedAnalyzedItem) -> Void) {
        self.item = item
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack {
            Button(action: {
                onTap(item)
            }) {
                HStack(spacing: 12) {
                    // Image
                    Group {
                        if let imageUrl = item.imageUrl, !imageUrl.isEmpty {
                            let fixedImageUrl = imageUrl.hasPrefix("//") ? "https:" + imageUrl : imageUrl
                            AsyncImage(url: URL(string: fixedImageUrl)) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        .clipped()
                                case .failure:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.gray)
                                        )
                                @unknown default:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                }
                            }
                        } else if item.imageHash != nil {
                            if let image = cachedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .clipped()
                            } else {
                                // Loading placeholder for image
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                        } else {
                            // Text/voice entry - show black box with gradient icon
                            // Get inputMethod from cache entry if available
                            let inputMethod: String? = {
                                switch item {
                                case .meal(let entry), .food(let entry), .grocery(let entry):
                                    return entry.inputMethod
                                case .recipe:
                                    return nil
                                }
                            }()
                            TextVoiceEntryIcon(inputMethod: inputMethod, size: 60)
                        }
                    }
                    
                    // Title and Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        // Additional info based on type
                        if case .recipe(let recipe) = item {
                        if recipe.servings > 0 {
                                let scaledServings = Int(round(Double(recipe.servings) * recipe.scaleFactor))
                                let servingsText = recipe.scaleFactor != 1.0 
                                    ? "\(scaledServings) servings (Scaled)"
                                    : "\(recipe.servings) servings"
                                
                                Text(servingsText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if recipe.prepTime > 0 {
                            Text("\(recipe.prepTime) min prep")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Score Circle
                    if let score = item.score {
                        GroceryScoreCircleCompact(score: score)
                    } else if case .recipe(let recipe) = item {
                        RecipeScoreCircleCompact(recipe: recipe)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.42, green: 0.557, blue: 0.498), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Delete Button - Top Right Corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(colorScheme == .dark ? Color(.lightGray) : Color(red: 0.42, green: 0.557, blue: 0.498))
                            .frame(width: 44, height: 44) // Larger tap area
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, -8) // Move much closer to top edge
                    .padding(.trailing, -8) // Move much closer to right edge
                }
                Spacer()
            }
            .zIndex(1) // Ensure X button is above card button
            .allowsHitTesting(true) // Explicitly enable hit testing
        }
        .onAppear {
            loadImageIfNeeded()
        }
        .onChange(of: item.imageHash) { oldValue, newValue in
            loadImageIfNeeded()
        }
        .confirmationDialog("Delete?", isPresented: $showingDeleteConfirmation) {
            Button("Yes", role: .destructive) {
                onDelete(item)
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(item.title)'?")
        }
    }
    
    private func loadImageIfNeeded() {
        guard let imageHash = item.imageHash, cachedImage == nil else { return }
        
        // Load image asynchronously on background thread
        Task {
            let loadedImage = FoodCacheManager.shared.loadImage(forHash: imageHash)
            await MainActor.run {
                cachedImage = loadedImage
                print("🔍 UnifiedAnalyzedRowView: Loading image for hash: \(imageHash), result: \(loadedImage != nil ? "success" : "failed")")
            }
        }
    }
}

#Preview {
    SearchView(onFoodDetected: { _, _, _, _ in }, onFoodsCompared: { _ in }, onShowCompareView: {})
}
