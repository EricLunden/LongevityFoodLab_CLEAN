import SwiftUI

struct RecipeImportView: View {
    @StateObject private var iCloudManager = iCloudRecipeManager.shared
    @State private var sharedURL: URL?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSuccess = false
    
    init(sharedURL: URL? = nil) {
        self._sharedURL = State(initialValue: sharedURL)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo Header
                VStack(spacing: 12) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 50)
                        .padding(.top, 20)
                    
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
                .padding(.bottom, 20)
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Importing recipe...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                } else if showingSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Recipe Imported!")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("The recipe has been added to your collection and synced with iCloud.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "link.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Import Recipe")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let url = sharedURL {
                            VStack(spacing: 8) {
                                Text("URL:")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        Button("Import Recipe") {
                            Task {
                                await importRecipe()
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(NotificationCenter.default.publisher(for: .recipeImportRequested)) { notification in
                if let url = notification.object as? URL {
                    sharedURL = url
                }
            }
        }
    }
    
    private func importRecipe() async {
        guard let url = sharedURL else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Create a basic recipe from the URL
            let recipe = Recipe(
                title: "Imported Recipe",
                photos: [],
                rating: 0,
                prepTime: 0,
                cookTime: 0,
                servings: 1,
                categories: [.main],
                description: "Recipe imported from \(url.host ?? "web")",
                ingredients: [],
                directions: [],
                sourceURL: url.absoluteString,
                longevityScore: nil,
                analysisReport: nil,
                improvementSuggestions: [],
                isFavorite: false,
                analysisType: .cached,
                isOriginal: false
            )
            
            try await iCloudManager.saveRecipe(recipe)
            
            await MainActor.run {
                isLoading = false
                showingSuccess = true
            }
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to import recipe: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    RecipeImportView()
}
