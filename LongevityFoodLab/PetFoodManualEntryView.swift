import SwiftUI

struct PetFoodManualEntryView: View {
    let selectedPetType: PetFoodAnalysis.PetType
    let onFoodDetected: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var foodText = ""
    @State private var isAnalyzing = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 24) {
                    // Logo Header
                    Image("LogoHorizontal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 37)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.top, -8)
                    
                    // Header
                    Text("Enter Your Pet Food Here")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    
                    // Pet Type Display
                    HStack {
                        Text("Pet Type:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(selectedPetType == .dog ? "🐕 Dog" : "🐱 Cat")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    
                    // Action Buttons (above text entry box)
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
                        
                        Button("Evaluate") {
                            if !foodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onFoodDetected(foodText)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    dismiss()
                                }
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
                        .disabled(foodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    // Text Entry Box
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $foodText)
                                .font(.body)
                                .frame(minHeight: 120)
                                .padding(12)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .focused($isTextFieldFocused)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button("Analyze") {
                                            // Trigger analysis when Analyze button is pressed
                                            if !foodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                onFoodDetected(foodText)
                                                // Dismiss after a short delay to show loading state
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    dismiss()
                                                }
                                            }
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                            if foodText.isEmpty {
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
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
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
}

#Preview {
    PetFoodManualEntryView(
        selectedPetType: .dog,
        onFoodDetected: { _ in }
    )
}
