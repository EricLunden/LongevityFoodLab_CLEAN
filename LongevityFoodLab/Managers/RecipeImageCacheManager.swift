import Foundation
import SwiftUI
import UIKit
import CryptoKit

/// Manages recipe image caching, prefetching, and download limiting for optimal cellular performance
class RecipeImageCacheManager: ObservableObject {
    static let shared = RecipeImageCacheManager()
    
    // MARK: - Configuration
    private let maxConcurrentDownloads = 3  // Limit concurrent downloads
    private let prefetchDistance = 5  // Prefetch images for items 5 positions ahead/behind viewport
    private let maxCacheSize: Int64 = 100 * 1024 * 1024  // 100MB max cache size
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var memoryCache: [String: UIImage] = [:]  // In-memory cache
    private var downloadQueue: [String: Task<Void, Never>] = [:]  // Track active downloads
    private let downloadSemaphore: DispatchSemaphore  // Limit concurrent downloads
    private let cacheQueue = DispatchQueue(label: "recipe.image.cache", attributes: .concurrent)
    
    private var cacheDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cachePath = documentsPath.appendingPathComponent("RecipeImageCache")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cachePath, withIntermediateDirectories: true)
        
        return cachePath
    }
    
    // MARK: - Initialization
    private init() {
        downloadSemaphore = DispatchSemaphore(value: maxConcurrentDownloads)
        setupCacheDirectory()
        loadMemoryCache()
        cleanupOldCache()
    }
    
    // MARK: - Setup
    private func setupCacheDirectory() {
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func loadMemoryCache() {
        // Load a limited set of recently used images into memory
        // This is handled lazily as images are requested
    }
    
    // MARK: - Cache Key Generation
    private func cacheKey(for url: String) -> String {
        // Use SHA256 hash of URL as cache key
        let data = Data(url.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func cacheFileURL(for url: String) -> URL {
        let key = cacheKey(for: url)
        return cacheDirectory.appendingPathComponent("\(key).jpg")
    }
    
    // MARK: - Image Loading
    /// Load image from cache or download if not cached
    func loadImage(from urlString: String) async -> UIImage? {
        let fixedUrl = urlString.hasPrefix("//") ? "https:" + urlString : urlString
        guard let url = URL(string: fixedUrl) else { return nil }
        
        let key = cacheKey(for: fixedUrl)
        
        // Check memory cache first (synchronized access)
        let cachedImage = cacheQueue.sync {
            return memoryCache[key]
        }
        if let cachedImage = cachedImage {
            print("IMG/Cache: Loaded from memory cache, size=\(cachedImage.size), url=\(fixedUrl.prefix(50))...")
            return cachedImage
        }
        
        // Check disk cache
        let cacheFile = cacheFileURL(for: fixedUrl)
        if let diskImage = loadFromDisk(cacheFile: cacheFile) {
            print("IMG/Cache: Loaded from disk cache, size=\(diskImage.size), url=\(fixedUrl.prefix(50))...")
            // Load into memory cache
            cacheQueue.async(flags: .barrier) {
                self.memoryCache[key] = diskImage
            }
            return diskImage
        }
        
        // Download if not cached
        return await downloadImage(from: url, cacheKey: key, cacheFile: cacheFile)
    }
    
    private func loadFromDisk(cacheFile: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: cacheFile),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func downloadImage(from url: URL, cacheKey: String, cacheFile: URL) async -> UIImage? {
        // Check if download is already in progress (synchronized access)
        let existingTask = cacheQueue.sync {
            return downloadQueue[cacheKey]
        }
        
        if existingTask != nil {
            // Wait for existing download
            while cacheQueue.sync(execute: { downloadQueue[cacheKey] != nil }) {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            // Try loading from cache again
            if let cachedImage = cacheQueue.sync(execute: { memoryCache[cacheKey] }) {
                return cachedImage
            }
            if let diskImage = loadFromDisk(cacheFile: cacheFile) {
                cacheQueue.async(flags: .barrier) {
                    self.memoryCache[cacheKey] = diskImage
                }
                return diskImage
            }
        }
        
        // Wait for semaphore (limits concurrent downloads)
        await withCheckedContinuation { continuation in
            cacheQueue.async {
                self.downloadSemaphore.wait()
                continuation.resume()
            }
        }
        
        // Create download task
        let downloadTask = Task {
            defer {
                self.downloadSemaphore.signal()
                self.cacheQueue.async(flags: .barrier) {
                    self.downloadQueue.removeValue(forKey: cacheKey)
                }
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                guard let image = UIImage(data: data) else {
                    print("⚠️ RecipeImageCacheManager: Failed to create image from data")
                    return
                }
                
                print("IMG/Cache: Downloaded image, size=\(image.size), url=\(url.absoluteString.prefix(50))...")
                
                // Save to disk cache
                try? data.write(to: cacheFile)
                
                // Save to memory cache
                self.cacheQueue.async(flags: .barrier) {
                    self.memoryCache[cacheKey] = image
                    
                    // Limit memory cache size (keep only last 50 images)
                    if self.memoryCache.count > 50 {
                        let keysToRemove = Array(self.memoryCache.keys.prefix(self.memoryCache.count - 50))
                        for key in keysToRemove {
                            self.memoryCache.removeValue(forKey: key)
                        }
                    }
                }
                
            } catch {
                print("⚠️ RecipeImageCacheManager: Failed to download image from \(url): \(error)")
            }
        }
        
        cacheQueue.async(flags: .barrier) {
            self.downloadQueue[cacheKey] = downloadTask
        }
        
        // Wait for download to complete
        await downloadTask.value
        
        // Return from cache
        if let cachedImage = cacheQueue.sync(execute: { memoryCache[cacheKey] }) {
            return cachedImage
        }
        return loadFromDisk(cacheFile: cacheFile)
    }
    
    // MARK: - Prefetching
    /// Prefetch images for recipes near the viewport
    func prefetchImages(for recipes: [Recipe], visibleIndices: Set<Int>) {
        guard !visibleIndices.isEmpty else { return }
        
        let minIndex = visibleIndices.min() ?? 0
        let maxIndex = visibleIndices.max() ?? recipes.count - 1
        
        // Prefetch range: visible indices ± prefetchDistance
        let prefetchStart = max(0, minIndex - prefetchDistance)
        let prefetchEnd = min(recipes.count - 1, maxIndex + prefetchDistance)
        
        Task {
            for index in prefetchStart...prefetchEnd {
                guard let recipe = recipes[safe: index],
                      let imageUrl = recipe.image,
                      !imageUrl.isEmpty else {
                    continue
                }
                
                let fixedUrl = imageUrl.hasPrefix("//") ? "https:" + imageUrl : imageUrl
                let key = cacheKey(for: fixedUrl)
                
                // Skip if already cached or downloading (synchronized check)
                let isCached = cacheQueue.sync {
                    return memoryCache[key] != nil || downloadQueue[key] != nil
                }
                if isCached {
                    continue
                }
                
                // Check disk cache
                let cacheFile = cacheFileURL(for: fixedUrl)
                if fileManager.fileExists(atPath: cacheFile.path) {
                    continue
                }
                
                // Prefetch (low priority)
                if let url = URL(string: fixedUrl) {
                    _ = await downloadImage(from: url, cacheKey: key, cacheFile: cacheFile)
                }
            }
        }
    }
    
    // MARK: - Cache Management
    private func cleanupOldCache() {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    // Calculate total cache size
                    var totalSize: Int64 = 0
                    var fileAttributes: [(url: URL, date: Date, size: Int64)] = []
                    
                    if let files = try? self.fileManager.contentsOfDirectory(
                        at: self.cacheDirectory,
                        includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
                    ) {
                        for file in files {
                            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                               let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                                totalSize += Int64(size)
                                fileAttributes.append((url: file, date: date, size: Int64(size)))
                            }
                        }
                    }
                    
                    // If cache exceeds max size, remove oldest files
                    if totalSize > self.maxCacheSize {
                        let sortedFiles = fileAttributes.sorted { $0.date < $1.date }
                        var sizeToRemove = totalSize - self.maxCacheSize
                        
                        for file in sortedFiles {
                            if sizeToRemove <= 0 { break }
                            try? self.fileManager.removeItem(at: file.url)
                            sizeToRemove -= file.size
                        }
                    }
                }
            }
        }
    }
    
    /// Clear all cached images
    func clearCache() {
        memoryCache.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
        setupCacheDirectory()
    }
}

// MARK: - Array Safe Index Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

