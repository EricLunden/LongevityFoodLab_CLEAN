//
//  UIImage+Optimization.swift
//  LongevityFoodLab
//
//  Image optimization for faster API uploads
//

import UIKit

extension UIImage {
    /// Optimizes image for API: resizes to max dimension on longest side, then compresses
    /// Reduced size for faster uploads on cell service (trial optimization)
    func optimizedForAPI() -> Data? {
        // CONSERVATIVE TRIAL (active):
        let maxDimension: CGFloat = 640
        let quality: CGFloat = 0.65
        
        // AGGRESSIVE TRIAL (uncomment to test):
        // let maxDimension: CGFloat = 512
        // let quality: CGFloat = 0.6
        
        // ORIGINAL (uncomment to revert):
        // let maxDimension: CGFloat = 1024
        // let quality: CGFloat = 0.7
        
        let size = self.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        
        print("📷 Image optimization: \(maxDimension)px @ \(quality) quality (scale: \(String(format: "%.2f", scale)))")
        
        // Only resize if needed
        guard scale < 1.0 else {
            // Already small enough, just compress
            if let imageData = self.jpegData(compressionQuality: quality) {
                let sizeKB = Double(imageData.count) / 1024.0
                print("📷 Final image size: \(String(format: "%.1f", sizeKB)) KB (no resize needed)")
                return imageData
            }
            return nil
        }
        
        // Resize image
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            // Fallback: compress original if resize fails
            if let imageData = self.jpegData(compressionQuality: quality) {
                let sizeKB = Double(imageData.count) / 1024.0
                print("📷 Final image size: \(String(format: "%.1f", sizeKB)) KB (resize failed, using original)")
                return imageData
            }
            return nil
        }
        
        // Compress resized image
        if let imageData = resizedImage.jpegData(compressionQuality: quality) {
            let sizeKB = Double(imageData.count) / 1024.0
            print("📷 Final image size: \(String(format: "%.1f", sizeKB)) KB")
            return imageData
        }
        
        return nil
    }
    
    /// High-quality optimization for supplements (1280px @ 0.85 quality)
    /// Used for investor-grade supplement analysis requiring fine print readability
    func optimizedForSupplements() -> Data? {
        let maxDimension: CGFloat = 1280
        let quality: CGFloat = 0.85
        
        let size = self.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        
        print("📦 Supplement image optimization: \(maxDimension)px @ \(quality) quality (scale: \(String(format: "%.2f", scale)))")
        
        // Only resize if needed
        guard scale < 1.0 else {
            // Already small enough, just compress
            if let imageData = self.jpegData(compressionQuality: quality) {
                let sizeKB = Double(imageData.count) / 1024.0
                print("📦 Final supplement image size: \(String(format: "%.1f", sizeKB)) KB (no resize needed)")
                return imageData
            }
            return nil
        }
        
        // Resize image
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: newSize))
        
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            // Fallback: compress original if resize fails
            if let imageData = self.jpegData(compressionQuality: quality) {
                let sizeKB = Double(imageData.count) / 1024.0
                print("📦 Final supplement image size: \(String(format: "%.1f", sizeKB)) KB (resize failed, using original)")
                return imageData
            }
            return nil
        }
        
        // Compress resized image
        if let imageData = resizedImage.jpegData(compressionQuality: quality) {
            let sizeKB = Double(imageData.count) / 1024.0
            print("📦 Final supplement image size: \(String(format: "%.1f", sizeKB)) KB")
            return imageData
        }
        
        return nil
    }
}

