import SwiftUI

struct RecipeImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeManager = RecipeManager.shared
    @State private var urlText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Fully transparent background so recipe shows through
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
            
            // Green bordered box with all content inside
            VStack(spacing: 20) {
                Text("Import Recipe from URL")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                TextField("Paste recipe URL (e.g., allrecipes.com/recipe/...)", text: $urlText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onChange(of: urlText) { _, _ in
                        errorMessage = nil
                    }
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                    Button(action: importRecipe) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Text("Import Recipe")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isLoading ? Color.gray : Color(red: 0.42, green: 0.557, blue: 0.498))
                    .cornerRadius(12)
                    .disabled(isLoading || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 320)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(red: 0.608, green: 0.827, blue: 0.835), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .foregroundColor(.white)
                    
                    Text("Extracting recipe...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
    }
    
    private func importRecipe() {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🚀 RecipeImportSheet: Import button tapped with URL: \(trimmedURL)")
        
        guard !trimmedURL.isEmpty else {
            errorMessage = "Please enter a recipe URL"
            return
        }
        
        guard URL(string: trimmedURL) != nil else {
            errorMessage = "Invalid URL format"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                print("🔍 RecipeImportSheet: Calling recipeManager.importRecipeFromURL")
                let recipe = try await recipeManager.importRecipeFromURL(trimmedURL)
                print("✅ RecipeImportSheet: Import successful")
                
                await MainActor.run {
                    isLoading = false
                    
                    // Send notification to show recipe detail view
                    NotificationCenter.default.post(
                        name: .navigateToRecipesTab,
                        object: nil,
                        userInfo: ["importedRecipe": recipe]
                    )
                    
                    // Dismiss immediately since recipe detail view will appear
                    dismiss()
                }
            } catch {
                print("❌ RecipeImportSheet: Import failed with error: \(error)")
                await MainActor.run {
                    isLoading = false
                    
                    if let spoonacularError = error as? SpoonacularError {
                        switch spoonacularError {
                        case .httpError(let code):
                            if code == 404 {
                                errorMessage = "Could not extract recipe from this website"
                            } else {
                                errorMessage = "Network error - please try again"
                            }
                        case .invalidURL:
                            errorMessage = "Invalid URL format"
                        case .invalidResponse, .noData, .decodingError:
                            errorMessage = "Could not extract recipe from this website"
                        }
                    } else {
                        errorMessage = "Network error - please try again"
                    }
                }
            }
        }
    }
}

#Preview {
    RecipeImportSheet()
}
