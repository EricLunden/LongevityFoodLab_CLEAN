import SwiftUI

struct PetFoodCompareManualEntryView: View {
    let selectedPetType: PetFoodAnalysis.PetType
    let foodNumber: Int
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
                VStack {
                    Spacer()
                        .frame(height: 25)
                    
                    VStack(spacing: 12) {
                        // Logo Header
                        Image("LogoHorizontal")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 37)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .padding(.top, -8)
                        
                        // Header
                        Text("Enter Pet Food #\(foodNumber)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        // Pet Type Selection
                        HStack {
                            Text("Pet Type:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Pet Type", selection: .constant(selectedPetType)) {
                                Text("🐕 Dog").tag(PetFoodAnalysis.PetType.dog)
                                Text("🐱 Cat").tag(PetFoodAnalysis.PetType.cat)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .disabled(true) // Disabled since it's passed from parent
                        }
                        .padding(.horizontal)
                        
                        // Text Entry Box
                        VStack(alignment: .leading, spacing: 12) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $foodText)
                                    .font(.body)
                                    .frame(height: 80)
                                    .padding(12)
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(12)
                                    .focused($isTextFieldFocused)
                                
                                if foodText.isEmpty {
                                    Text("Example: Hill's Science Diet Adult, Royal Canin Indoor, Blue Buffalo Life Protection")
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
    PetFoodCompareManualEntryView(
        selectedPetType: .dog,
        foodNumber: 1,
        onFoodDetected: { _ in }
    )
}
