//
//  UIImage+Optimization.swift
//  LongevityFoodLab
//
//  Image optimization for faster API uploads
//

import UIKit

extension UIImage {
    /// Optimizes image for API: resizes to max 1024px on longest side, then compresses
    /// OpenAI Vision API works well with 1024px images and processes them faster
    func optimizedForAPI() -> Data? {
        let maxDimension: CGFloat = 1024
        let size = self.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        
        // Only resize if needed
        guard scale < 1.0 else {
            // Already small enough, just compress
            return self.jpegData(compressionQuality: 0.7)
        }
        
        // Resize image
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self.jpegData(compressionQuality: 0.7)
        }
        
        // Compress to 0.7 quality (good balance of size vs quality for API)
        return resizedImage.jpegData(compressionQuality: 0.7)
    }
}

