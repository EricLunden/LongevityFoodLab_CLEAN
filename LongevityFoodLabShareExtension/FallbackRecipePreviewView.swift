import SwiftUI

struct FallbackRecipePreviewView: View {
    let data: FallbackRecipeData
    let onCancel: () -> Void
    let onSave: () -> Void
    
    let colorScheme: ColorScheme
    
    // Computed property for foreground color based on color scheme
    private var foregroundColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    var body: some View {
        ZStack {
            // Dark mode: 100% black background, light mode: system grouped background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea(.container, edges: [.top, .bottom])
            
        VStack(spacing: 16) {
            // Title
            Text(data.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Image (if available)
            if let imageURL = data.imageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)  // Fit entire image (no cropping)
                        .frame(maxWidth: .infinity)  // Fill available width
                        .frame(height: 200)
                        .cornerRadius(8)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            // Site link
            if let siteLink = data.siteLink {
                Link(destination: URL(string: siteLink)!) {
                    Text("View Original Recipe")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                }
                .padding(.horizontal)
            }
            
            // Error message for YouTube (extraction failed)
            if data.isYouTube {
                VStack(spacing: 8) {
                    Text("Recipe extraction failed")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                    Text("This video may not contain a recipe, or the content couldn't be extracted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                if data.isYouTube {
                    // Disable Save button for YouTube URLs (extraction failed)
                    Button("Save") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(true)
                    .opacity(0.5)
                } else {
                    Button("Save") {
                        onSave()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
            .foregroundColor(foregroundColor)
        .padding()
        }
    }
}

#Preview {
    FallbackRecipePreviewView(
        data: FallbackRecipeData(
            title: "Sample Recipe",
            imageURL: nil,
            siteLink: "https://example.com",
            prepTime: nil,
            servings: nil,
            isYouTube: false
        ),
        onCancel: {},
        onSave: {},
        colorScheme: .dark
    )
}
