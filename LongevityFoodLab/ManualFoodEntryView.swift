import SwiftUI

struct ManualFoodEntryView: View {
    @State private var foodInput = ""
    @State private var isAnalyzing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let onFoodDetected: (FoodAnalysis) -> Void
    
    init(onFoodDetected: @escaping (FoodAnalysis) -> Void) {
        self.onFoodDetected = onFoodDetected
    }
    
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
                        .frame(height: 10)
                    
                    // Content in shadow box like Score It
                    VStack(spacing: 16) {
                        // Header
                        Text("Enter Your Food or Meal Here")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // Text Entry Box
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $foodInput)
                                    .font(.body)
                                    .frame(height: 80)
                                    .padding(12)
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(12)
                                    .focused($isTextFieldFocused)
                                
                                if foodInput.isEmpty {
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
                        
                        // Action Buttons (below text entry) with score screen gradients
                        HStack(spacing: 16) {
                            Button("Clear") {
                                foodInput = ""
                                isTextFieldFocused = false
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
                                isTextFieldFocused = false
                                analyzeFood()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .disabled(foodInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
                        }
                        
                        // Error Message
                        if showError {
                            errorView
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 30)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
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
        }
    }
    
    private func analyzeFood() {
        let trimmedInput = foodInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            showError(message: "Please enter a food to evaluate")
            return
        }
        
        guard trimmedInput.count <= 500 else {
            showError(message: "Food description is too long. Please use a shorter description.")
            return
        }
        
        isAnalyzing = true
        showError = false
        
        print("ManualFoodEntryView: Starting analysis for '\(trimmedInput)'")
        
        // Call AI Analysis with health profile
        let healthProfile = UserHealthProfileManager.shared.currentProfile
        AIService.shared.analyzeFoodWithProfile(trimmedInput, healthProfile: healthProfile) { result in
            DispatchQueue.main.async {
                isAnalyzing = false
                
                switch result {
                case .success(let analysis):
                    print("ManualFoodEntryView: Analysis successful for '\(trimmedInput)'")
                    onFoodDetected(analysis)
                case .failure(let error):
                    print("ManualFoodEntryView: Analysis failed for '\(trimmedInput)': \(error.localizedDescription)")
                    // Use fallback analysis if API fails
                    let fallbackAnalysis = AIService.shared.createFallbackAnalysis(for: trimmedInput)
                    print("ManualFoodEntryView: Using fallback analysis for '\(trimmedInput)'")
                    onFoodDetected(fallbackAnalysis)
                }
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    ManualFoodEntryView(
        onFoodDetected: { _ in }
    )
}
