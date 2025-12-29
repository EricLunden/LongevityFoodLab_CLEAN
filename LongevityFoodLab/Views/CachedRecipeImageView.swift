import SwiftUI
import UIKit

/// A SwiftUI view that displays recipe images with caching, prefetching, and download limiting
struct CachedRecipeImageView: View {
    let urlString: String
    let placeholder: AnyView
    let isShorts: Bool
    
    private let cacheManager = RecipeImageCacheManager.shared
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(urlString: String, placeholder: AnyView? = nil, isShorts: Bool = false) {
        self.urlString = urlString
        self.isShorts = isShorts
        self.placeholder = placeholder ?? AnyView(
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.system(size: 10))
                )
        )
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                placeholder
            } else {
                placeholder
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .clipped()
    }
    
    private func loadImage() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            let loadedImage = await cacheManager.loadImage(from: urlString)
            
            await MainActor.run {
                self.image = loadedImage
                self.isLoading = false
            }
        }
    }
}

