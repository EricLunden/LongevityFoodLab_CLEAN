import SwiftUI
import UIKit

/// A SwiftUI view that displays recipe images with caching, prefetching, and download limiting
struct CachedRecipeImageView: View {
    let urlString: String
    let placeholder: AnyView
    let isShorts: Bool  // For YouTube Shorts - zoom to fill without letterboxing
    
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
                    .scaledToFill()  // Fill frame (will crop sides for Shorts)
            } else if isLoading {
                placeholder
            } else {
                placeholder
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .clipped()  // Crop sides for Shorts (zoom in), letterbox for regular videos
    }
    
    private func loadImage() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            let loadedImage = await cacheManager.loadImage(from: urlString)
            
            // Apply cropping for Shorts if needed
            var processedImage = loadedImage
            if let img = loadedImage {
                print("IMG/Cached: loaded image size=\(img.size) isShorts=\(isShorts)")
                
                if isShorts && img.size.height > img.size.width {
                    processedImage = cropVerticalToHorizontal(img)
                    print("IMG/Cached: cropped Shorts image from \(img.size) to \(processedImage?.size ?? .zero)")
                } else if isShorts {
                    print("IMG/Cached: Shorts image already horizontal, no crop needed")
                }
            }
            
            await MainActor.run {
                self.image = processedImage
                self.isLoading = false
            }
        }
    }
    
    /// Crops a vertical image to horizontal aspect ratio by taking center strip
    /// This removes letterboxing from YouTube Shorts thumbnails
    private func cropVerticalToHorizontal(_ image: UIImage) -> UIImage {
        // Only process if image is taller than wide (vertical)
        guard image.size.height > image.size.width else { 
            return image 
        }
        
        guard let cgImage = image.cgImage else { 
            return image 
        }
        
        // Calculate target height for ~16:9 horizontal crop
        let targetAspectRatio: CGFloat = 16.0 / 9.0
        let targetHeight = image.size.width / targetAspectRatio
        
        // If the image isn't tall enough, use gentler crop
        let actualTargetHeight = min(targetHeight, image.size.height * 0.8)
        
        // Center the crop vertically
        let cropY = (image.size.height - actualTargetHeight) / 2
        
        // Create crop rect (account for image scale)
        let scale = image.scale
        let cropRect = CGRect(
            x: 0,
            y: cropY * scale,
            width: image.size.width * scale,
            height: actualTargetHeight * scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { 
            return image 
        }
        
        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: image.imageOrientation)
    }
}

