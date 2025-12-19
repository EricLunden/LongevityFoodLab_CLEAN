//
//  SceneDelegate.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 9/18/25.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        print("SceneDelegate: willConnectTo called")
        
        // Handle URL from cold launch
        if let urlContext = connectionOptions.urlContexts.first {
            print("SceneDelegate: Cold launch with URL: \(urlContext.url)")
            handleURL(urlContext.url)
        }
        
        // Create the SwiftUI view and set it as the root view
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            self.window = window
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        print("SceneDelegate: openURLContexts called with \(URLContexts.count) URLs")
        
        guard let urlContext = URLContexts.first else {
            print("SceneDelegate: No URL context found")
            return
        }
        
        let url = urlContext.url
        print("SceneDelegate: Received URL: \(url)")
        print("SceneDelegate: URL scheme: \(url.scheme ?? "nil")")
        print("SceneDelegate: URL host: \(url.host ?? "nil")")
        print("SceneDelegate: URL query: \(url.query ?? "nil")")
        
        handleURL(url)
    }
    
    private func handleURL(_ url: URL) {
        print("SceneDelegate: Handling URL: \(url)")
        
        // Handle recipe import URL
        if url.scheme == "longevityfoodlab" && url.host == "import" {
            print("SceneDelegate: Processing longevityfoodlab://import URL")
            
            if let query = url.query {
                print("SceneDelegate: Query string: \(query)")
                let components = query.components(separatedBy: "url=")
                print("SceneDelegate: Query components: \(components)")
                
                if components.count > 1 {
                    let recipeURLString = components[1].removingPercentEncoding ?? components[1]
                    print("SceneDelegate: Recipe URL string: \(recipeURLString)")
                    
                    if let recipeURL = URL(string: recipeURLString) {
                        print("SceneDelegate: Recipe URL extracted: \(recipeURL)")
                        
                        // Post notification to main app
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RecipeURLReceived"),
                            object: nil,
                            userInfo: ["recipeURL": recipeURL.absoluteString]
                        )
                    } else {
                        print("SceneDelegate: Failed to create URL from string: \(recipeURLString)")
                    }
                } else {
                    print("SceneDelegate: No url= parameter found in query")
                }
            } else {
                print("SceneDelegate: No query string found")
            }
        } else {
            print("SceneDelegate: Not a recipe import URL, scheme: \(url.scheme ?? "nil"), host: \(url.host ?? "nil")")
        }
    }
}
