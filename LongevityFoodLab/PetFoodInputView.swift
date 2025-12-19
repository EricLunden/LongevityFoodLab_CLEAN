import SwiftUI

struct PetFoodInputView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cacheManager = PetFoodCacheManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var productName = ""
    @State private var selectedPetType: PetFoodAnalysis.PetType = .dog
    @State private var isAnalyzing = false
    @State private var showingResults = false
    @State private var analysis: PetFoodAnalysis?
    @State private var errorMessage: String?
    @State private var showingCachedResult = false
    @State private var cachedAnalysis: PetFoodAnalysis?
    @State private var showingVoiceMode = false
    @State private var showingManualEntry = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo Header
                        logoHeaderSection
                        
                        // Pet Type Selection (moved above voice mode)
                        petTypeSelectionSection
                        
                        // Voice Mode Section
                        voiceModeSection
                        
                        // Manual Entry Section
                        manualEntrySection
                        
                        // Cache Status
                        if let cached = cachedAnalysis {
                            cacheStatusSection(cached)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Analyze Pet Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        clearForm()
                    }
                    .disabled(productName.isEmpty)
                }
            }
            .onChange(of: productName) { _, _ in checkCache() }
            .onChange(of: selectedPetType) { _, _ in checkCache() }
            .sheet(isPresented: $showingResults) {
                if let analysis = analysis {
                    PetFoodResultsView(analysis: analysis)
                }
            }
            .sheet(isPresented: $showingCachedResult) {
                if let cached = cachedAnalysis {
                    PetFoodResultsView(analysis: cached, isFromCache: true)
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
    
    // MARK: - Logo Header Section
    private var logoHeaderSection: some View {
        Image("LogoHorizontal")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 37)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.top, -8)
    }
    
    // MARK: - Pet Type Selection Section
    private var petTypeSelectionSection: some View {
        VStack(spacing: 15) {
            Text("Pet Type:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Pet Type", selection: $selectedPetType) {
                Text("🐕 Dog").tag(PetFoodAnalysis.PetType.dog)
                Text("🐱 Cat").tag(PetFoodAnalysis.PetType.cat)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Voice Mode Section
    private var voiceModeSection: some View {
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
        .sheet(isPresented: $showingVoiceMode) {
            PetFoodVoiceInputView { foodName in
                // Set product name from voice input
                productName = foodName
                showingVoiceMode = false
                // Trigger analysis after setting product name
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    analyzePetFood()
                }
            }
        }
    }
    
    // MARK: - Manual Entry Section
    private var manualEntrySection: some View {
        SearchMenuButton(
            title: "Text Your Pet Food",
            subtitle: "Enter brand and food to analyze",
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
        .sheet(isPresented: $showingManualEntry) {
            PetFoodManualEntryView(
                selectedPetType: selectedPetType,
                onFoodDetected: { foodName in
                    productName = foodName
                    showingManualEntry = false
                    // Trigger analysis after setting product name
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        analyzePetFood()
                    }
                }
            )
        }
    }
    
    // MARK: - Cache Status Section
    private func cacheStatusSection(_ cached: PetFoodAnalysis) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Previously Analyzed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                Spacer()
            }
            
            VStack(spacing: 8) {
                HStack {
                    Text("Score:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(cached.overallScore)/100")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(scoreColor(cached.overallScore))
                    Spacer()
                }
                
                HStack {
                    Text("Analyzed:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(cached.analysisDate ?? Date(), style: .date)
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding(.leading, 24)
        }
        .padding(16)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    private var isFormValid: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func checkCache() {
        let normalizedProduct = PetFoodAnalysis.normalizeInput(productName)
        
        guard !normalizedProduct.isEmpty else {
            cachedAnalysis = nil
            return
        }
        
        cachedAnalysis = cacheManager.getCachedAnalysis(
            for: selectedPetType,
            productName: normalizedProduct
        )
    }
    
    private func analyzePetFood() {
        guard isFormValid else { return }
        
        let normalizedProduct = PetFoodAnalysis.normalizeInput(productName)
        
        // Check cache first
        if let cachedAnalysis = cacheManager.getCachedAnalysis(
            for: selectedPetType,
            productName: normalizedProduct
        ) {
            print("🔍 PetFoodInputView: Using cached analysis for \(cachedAnalysis.productName)")
            analysis = cachedAnalysis
            showingResults = true
            return
        }
        
        // If not in cache, make API call
        isAnalyzing = true
        errorMessage = nil
        
        Task {
            do {
                let newAnalysis = try await AIService.shared.getPetFoodAnalysis(
                    petType: selectedPetType,
                    productName: normalizedProduct
                )
                
                await MainActor.run {
                    analysis = newAnalysis
                    isAnalyzing = false
                    
                    // Cache the analysis
                    cacheManager.cacheAnalysis(newAnalysis)
                    print("🔍 PetFoodInputView: Cached new analysis for \(newAnalysis.productName)")
                    
                    showingResults = true
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func clearForm() {
        productName = ""
        selectedPetType = .dog
        cachedAnalysis = nil
        errorMessage = nil
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return Color(red: 0.42, green: 0.557, blue: 0.498)
        case 60...79: return Color(red: 0.502, green: 0.706, blue: 0.627)
        case 40...59: return Color.orange
        default: return Color.red
        }
    }
}
