import SwiftUI

struct RecipePreviewView: View {
    @ObservedObject var loadingState: RecipeLoadingState
    let onCancel: () -> Void
    let onSave: () -> Void
    
    let colorScheme: ColorScheme
    
    // Feature flag: toggle to use custom loader instead of AsyncImage
    fileprivate let USE_CUSTOM_IMAGE_LOADER = true
    
    // Legacy initializer for non-progressive loading
    init(recipe: ImportedRecipe, isLoading: Bool = false, colorScheme: ColorScheme, onCancel: @escaping () -> Void, onSave: @escaping () -> Void) {
        let state = RecipeLoadingState(sourceUrl: recipe.sourceUrl)
        state.updateWithRecipe(recipe)
        state.isLoading = isLoading
        self.loadingState = state
        self.colorScheme = colorScheme
        self.onCancel = onCancel
        self.onSave = onSave
    }
    
    // New initializer for progressive loading
    init(loadingState: RecipeLoadingState, colorScheme: ColorScheme, onCancel: @escaping () -> Void, onSave: @escaping () -> Void) {
        self.loadingState = loadingState
        self.colorScheme = colorScheme
        self.onCancel = onCancel
        self.onSave = onSave
    }
    
    // Helper function to extract domain from URL
    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        
        // Remove 'www.' prefix if present
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return domain
    }
    
    // Helper to format instructions with numbering
    private func formatInstructions(_ instructions: String) -> String {
        let steps = instructions.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return steps.enumerated().map { index, step in
            // Remove existing step prefixes before adding new numbers
            var cleanStep = step
            
            // Remove patterns like "Step 1:", "Step 1.", "1.", "1)", "Step one:", etc.
            let stepPrefixPatterns = [
                "^Step\\s+\\d+[:.]\\s*",  // "Step 1:" or "Step 1."
                "^\\d+[.)]\\s*",          // "1." or "1)"
                "^Step\\s+[Oo]ne[:.]\\s*", // "Step one:" or "Step One:"
                "^Step\\s+[Tt]wo[:.]\\s*", // "Step two:"
                "^Step\\s+[Tt]hree[:.]\\s*", // "Step three:"
                "^Step\\s+[Ff]our[:.]\\s*", // "Step four:"
                "^Step\\s+[Ff]ive[:.]\\s*", // "Step five:"
            ]
            
            for pattern in stepPrefixPatterns {
                cleanStep = cleanStep.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: .regularExpression
                )
            }
            
            // Trim any remaining whitespace
            cleanStep = cleanStep.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Add clean numbering
            return "\(index + 1). \(cleanStep)"
        }.joined(separator: "\n\n") // Use double newline for spacing between numbered steps
    }
    
    // Helper to format prep time (convert minutes > 60 to hours + minutes)
    private func formatPrepTime(_ minutes: Int) -> String {
        guard minutes > 0 && minutes <= 600 else { return "" }
        if minutes <= 60 {
            return "\(minutes) min\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            var parts: [String] = []
            if hours > 0 {
                parts.append("\(hours) hr\(hours == 1 ? "" : "s")")
            }
            if mins > 0 {
                parts.append("\(mins) min\(mins == 1 ? "" : "s")")
            }
            return parts.joined(separator: ", ")
        }
    }
    
    // Computed property for foreground color based on color scheme
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark mode: 100% black background, light mode: system grouped background
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea(.container, edges: .bottom)
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Recipe Header
                        VStack(alignment: .leading, spacing: 12) {
                            if loadingState.isLoading && !loadingState.hasTitle {
                                // Skeleton placeholder for title
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 32)
                                    .cornerRadius(8)
                                    .overlay(
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                    )
                            } else if loadingState.hasTitle {
                                Text(loadingState.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                                    .transition(.opacity)
                            }
                            
                            HStack {
                                // Only show prep time if valid (1-600 minutes)
                                if loadingState.prepTimeMinutes > 0 && loadingState.prepTimeMinutes <= 600 {
                                    Label(formatPrepTime(loadingState.prepTimeMinutes), systemImage: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : .secondary)
                                }
                                
                                // Only show servings if valid (2-50)
                                if loadingState.servings > 0 && loadingState.servings >= 2 && loadingState.servings <= 50 {
                                    Label("\(loadingState.servings) serving\(loadingState.servings == 1 ? "" : "s")", systemImage: "person.2")
                                        .font(.subheadline)
                                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : .secondary)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        
                        // Recipe Image (diagnostic first, custom loader optional)
                        // Show image placeholder when loading OR when imageUrl is available
                        if loadingState.isLoading && !loadingState.hasImage || loadingState.hasImage {
                            VStack(alignment: .leading, spacing: 8) {
                                VStack(spacing: 8) {
                                    if loadingState.isLoading && !loadingState.hasImage {
                                        // Skeleton placeholder for image
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 200)
                                            .cornerRadius(12)
                                            .overlay(
                                                ProgressView()
                                                    .scaleEffect(1.2)
                                            )
                                    } else if let imageURL = loadingState.imageUrl, !imageURL.isEmpty {
                                        // Fix malformed URLs that start with //
                                        let fixedImageUrl = imageURL.hasPrefix("//") ? "https:" + imageURL : imageURL
                                        
                                        // Check if this is a YouTube Shorts URL
                                        let isShorts = loadingState.sourceUrl.contains("youtube.com/shorts/") || loadingState.sourceUrl.contains("youtu.be/")
                                        
                                    if USE_CUSTOM_IMAGE_LOADER {
                                    // Custom loader path (feature-flagged)
                                            RecipeRemoteImage(urlString: fixedImageUrl, isShorts: isShorts)
                                                .frame(maxWidth: .infinity)  // Fill container width
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                        .clipped()
                                } else {
                                    // AsyncImage with diagnostics
                                    if let u = URL(string: fixedImageUrl) {
                                        Group {
                                            AsyncImage(url: u) { phase in
                                                switch phase {
                                                case .empty:
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(height: 200)
                                                        .overlay(ProgressView())
                                                        .cornerRadius(12)
                                                        .onAppear {
                                                            print("SE/IMG: AsyncImage empty \(fixedImageUrl)")
                                                        }
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                                .aspectRatio(contentMode: .fill)  // Fill entire frame
                                                                .frame(maxWidth: .infinity)  // Fill available width
                                                                .frame(height: 200)
                                                                .clipped()  // Crop to fill rectangle (no letterboxing)
                                                        .cornerRadius(12)
                                                        .onAppear {
                                                                    print("SE/IMG: AsyncImage success \(fixedImageUrl) isShorts=\(isShorts)")
                                                        }
                                                case .failure(let error):
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(height: 200)
                                                        .overlay(
                                                            VStack(spacing: 6) {
                                                                Image(systemName: "photo")
                                                                    .font(.title2)
                                                                    .foregroundColor(.gray)
                                                                Text("Image failed")
                                                                    .font(.footnote)
                                                                    .foregroundColor(.gray)
                                                            }
                                                        )
                                                        .cornerRadius(12)
                                                        .onAppear {
                                                            print("SE/IMG: AsyncImage failure \(fixedImageUrl) err=\(error.localizedDescription)")
                                                        }
                                                @unknown default:
                                                    EmptyView()
                                                        .onAppear {
                                                            print("SE/IMG: AsyncImage unknown state \(fixedImageUrl)")
                                                        }
                                                }
                                            }
                                        }
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 200)
                                            .cornerRadius(12)
                                            .onAppear {
                                                print("SE/IMG: Invalid URL string \(fixedImageUrl)")
                                                    }
                                            }
                                    }
                                }
                                
                                    // Source URL link and creator credit (only show when not loading and URL exists)
                                    if !loadingState.isLoading && !loadingState.sourceUrl.isEmpty {
                                    HStack {
                                            // Source domain link (left)
                                            Text(extractDomain(from: loadingState.sourceUrl))
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                            .underline()
                                            
                                        Spacer()
                                            
                                            // Creator credit (right) - only for YouTube and TikTok
                                            if let author = loadingState.author, !author.isEmpty,
                                               let authorUrl = loadingState.authorUrl, !authorUrl.isEmpty,
                                               (loadingState.sourceUrl.contains("youtube.com") || 
                                                loadingState.sourceUrl.contains("youtu.be") ||
                                                loadingState.sourceUrl.contains("tiktok.com")) {
                                                Link(destination: URL(string: authorUrl)!) {
                                                    Text("by \(author)")
                                                        .font(.subheadline)
                                                        .foregroundColor(.blue)
                                                        .underline()
                                                }
                                            }
                                    }
                                }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Ingredients
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingredients")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                            
                            if loadingState.isLoading && !loadingState.hasIngredients {
                                // Skeleton placeholders for ingredients
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(0..<3) { _ in
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 20)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.vertical, 12)
                            } else if loadingState.hasIngredients {
                                // Display each ingredient with spacing between lines
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(loadingState.ingredients.enumerated()), id: \.offset) { index, ingredient in
                                        Text(ingredient)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .transition(.opacity)
                                    }
                                }
                                .padding(.vertical, 12)
                            } else if !loadingState.isLoading {
                                Text("No ingredients available")
                                    .foregroundColor(.gray)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Instructions")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                            
                            if loadingState.isLoading && !loadingState.hasInstructions {
                                // Skeleton placeholders for instructions
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(0..<3) { _ in
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 24)
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.vertical, 12)
                            } else if loadingState.hasInstructions {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(formatInstructions(loadingState.instructions))
                                    .fixedSize(horizontal: false, vertical: true)
                                        .transition(.opacity)
                                    
                                    // AI enhancement disclaimer (small, at bottom)
                                    if loadingState.aiEnhanced {
                                        Text("Instructions enhanced with AI")
                                            .font(.caption2)
                                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : .secondary)
                                            .padding(.top, 4)
                                    }
                                }
                                    .padding(.vertical, 12)
                            } else if !loadingState.isLoading {
                                Text("No instructions available")
                                    .foregroundColor(.gray)
                                    .italic()
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                    }
                }
                .foregroundColor(foregroundColor)
            }
            .navigationTitle("Recipe Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.red),
                trailing: Button("Save") {
                    onSave()
                }
                .foregroundColor(.blue)
                .fontWeight(.semibold)
                .disabled(loadingState.isLoading) // Disable save during loading
                .opacity(loadingState.isLoading ? 0.5 : 1.0)
            )
        }
    }
}

#Preview {
    RecipePreviewView(
        recipe: ImportedRecipe(
            title: "Sample Recipe",
            sourceUrl: "https://example.com",
            ingredients: ["1 cup flour", "2 eggs", "1 cup milk"],
            instructions: "1. Mix ingredients\n\n2. Bake for 30 minutes",
            servings: 4,
            prepTimeMinutes: 15,
            imageUrl: nil
        ),
        isLoading: false,
        colorScheme: .dark,
        onCancel: {},
        onSave: {}
    )
}