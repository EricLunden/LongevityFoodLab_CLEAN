import Foundation
import SwiftUI

class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    
    @Published var pendingURL: URL?
    @Published var pendingText: String?
    
    
    private init() {}
    
    func handleURL(_ url: URL) {
        print("DeepLinkManager: handleURL called with: \(url)")
        print("DeepLinkManager: URL scheme: \(url.scheme ?? "nil")")
        print("DeepLinkManager: URL host: \(url.host ?? "nil")")
        
        guard url.scheme == "longevityfoodlab" else { 
            print("DeepLinkManager: URL scheme is not longevityfoodlab, returning")
            return 
        }
        
        print("DeepLinkManager: Handling URL: \(url)")
        
        if url.host == "recipe" {
            print("DeepLinkManager: Calling handleRecipeURL")
            handleRecipeURL(url: url)
        } else if url.host == "recipeimport" {
            print("DeepLinkManager: Calling handleRecipeImport")
            handleRecipeImport(url: url)
        } else {
            print("DeepLinkManager: Unknown host: \(url.host ?? "nil")")
        }
    }
    
    private func handleRecipeURL(url: URL) {
        print("DeepLinkManager: Handling recipe URL: \(url)")
        
        // Parse URL parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            for item in queryItems {
                if item.name == "url", let urlString = item.value {
                    print("DeepLinkManager: Found URL parameter: \(urlString)")
                    if let sharedURL = URL(string: urlString) {
                        pendingURL = sharedURL
                        print("DeepLinkManager: Setting pendingURL to: \(sharedURL.absoluteString)")
                        // Post notification with URL immediately - just showing a simple alert
                        NotificationCenter.default.post(name: .recipeImportRequested, object: nil, userInfo: ["url": sharedURL])
                        return
                    }
                }
            }
        }
        
        print("DeepLinkManager: No URL parameter found")
        // Note: Using URL scheme approach, no need to check UserDefaults
    }
    
    private func handleRecipeImport(url: URL) {
        print("DeepLinkManager: Handling recipe import URL: \(url)")
        
        // Parse URL parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            for item in queryItems {
                if item.name == "url", let urlString = item.value {
                    print("DeepLinkManager: Found URL parameter: \(urlString)")
                    if let sharedURL = URL(string: urlString) {
                        pendingURL = sharedURL
                        // Post notification with URL immediately - just showing a simple alert
                        NotificationCenter.default.post(name: .recipeImportRequested, object: nil, userInfo: ["url": sharedURL])
                        return
                    }
                } else if item.name == "text", let text = item.value {
                    print("DeepLinkManager: Found text parameter: \(text)")
                    pendingText = text
                    // Post notification with text
                    NotificationCenter.default.post(name: .recipeImportRequested, object: nil, userInfo: ["text": text])
                    return
                }
            }
        }
    }
    
}

extension Notification.Name {
    static let recipeImportRequested = Notification.Name("recipeImportRequested")
}
