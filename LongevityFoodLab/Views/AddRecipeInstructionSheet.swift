import SwiftUI

struct AddRecipeInstructionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var urlText = ""
    @State private var showingManualEntry = false
    @State private var showingURLImport = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Recipe")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Choose how you'd like to add a recipe")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Method 1: Share from Web
                    method1Card
                    
                    // Method 2: Import from Social Media
                    method2Card
                    
                    // Method 3: Paste URL
                    method3Card
                    
                    // Method 4: Manual Entry
                    method4Card
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualRecipeEntryView()
        }
        .sheet(isPresented: $showingURLImport) {
            RecipeImportSheetWithURL(urlText: urlText)
        }
    }
    
    // MARK: - Method 1 Card: Share from Web
    private var method1Card: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color(red: 0.2, green: 0.6, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Method 1: Share from Web")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .center, spacing: 12) {
                Text("While browsing a recipe website:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color(red: 0.2, green: 0.6, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        Text("Share")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        Text("Food Lab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                
                Text("The recipe will be imported automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
    
    // MARK: - Method 2 Card: Import from Social Media
    private var method2Card: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                Spacer()
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Method 2: Import Recipe")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("From TikTok, YouTube, or Pinterest")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Social Media Logos (centered, bigger)
            HStack(spacing: 20) {
                Spacer()
                Image("TikTokLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                
                Image("YouTubeLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                
                Image("PinterestLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                Spacer()
            }
            .padding(.vertical, 8)
            
            // Share Icon → App Logo (centered)
            HStack(spacing: 16) {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.pink, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    Text("Share")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 6) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                    Text("Food Lab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            
            // Instructions (centered)
            VStack(alignment: .center, spacing: 8) {
                Text("Instructions:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                VStack(alignment: .center, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Open TikTok, YouTube, or Pinterest app")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Find a recipe video or pin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tap Share → Longevity Food Lab")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("4.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Recipe imports automatically")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
    
    // MARK: - Method 3 Card: Paste URL
    private var method3Card: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                Spacer()
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Method 3: Paste Recipe URL")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Copy a recipe URL from any website, then paste it below.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("Paste recipe URL here (e.g., allrecipes.com/recipe/...)", text: $urlText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            
            Button(action: {
                if !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showingURLImport = true
                }
            }) {
                Text("Import Recipe")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Color.gray
                            } else {
                                LinearGradient(
                                    colors: [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .cornerRadius(12)
            }
            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
    
    // MARK: - Method 4 Card: Manual Entry
    private var method4Card: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                Spacer()
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Method 4: Enter Manually")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Type in recipe details and add your own photo.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingManualEntry = true
            }) {
                Text("Enter Manually")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
    }
}

// MARK: - Recipe Import Sheet with Pre-filled URL
struct RecipeImportSheetWithURL: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeManager = RecipeManager.shared
    let urlText: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentURLText: String
    
    init(urlText: String) {
        self.urlText = urlText
        self._currentURLText = State(initialValue: urlText)
    }
    
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
                
                TextField("Paste recipe URL (e.g., allrecipes.com/recipe/...)", text: $currentURLText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onChange(of: currentURLText) { _, _ in
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
                    .disabled(isLoading || currentURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        let trimmedURL = currentURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🚀 RecipeImportSheetWithURL: Import button tapped with URL: \(trimmedURL)")
        
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
                print("🔍 RecipeImportSheetWithURL: Calling recipeManager.importRecipeFromURL")
                let recipe = try await recipeManager.importRecipeFromURL(trimmedURL)
                print("✅ RecipeImportSheetWithURL: Import successful")
                
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
                print("❌ RecipeImportSheetWithURL: Import failed with error: \(error)")
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
    AddRecipeInstructionSheet()
}

