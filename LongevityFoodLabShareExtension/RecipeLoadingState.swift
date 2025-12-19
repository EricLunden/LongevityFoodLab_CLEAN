import Foundation
import SwiftUI

/// Observable state for progressive recipe loading
class RecipeLoadingState: ObservableObject {
    @Published var title: String = ""
    @Published var imageUrl: String? = nil
    @Published var ingredients: [String] = []
    @Published var instructions: String = ""
    @Published var servings: Int = 0
    @Published var prepTimeMinutes: Int = 0
    @Published var sourceUrl: String = ""
    @Published var aiEnhanced: Bool = false
    @Published var author: String? = nil
    @Published var authorUrl: String? = nil
    
    @Published var isLoading: Bool = true
    @Published var hasTitle: Bool = false
    @Published var hasImage: Bool = false
    @Published var hasIngredients: Bool = false
    @Published var hasInstructions: Bool = false
    
    init(sourceUrl: String) {
        self.sourceUrl = sourceUrl
    }
    
    /// Update with complete recipe (for non-progressive updates)
    func updateWithRecipe(_ recipe: ImportedRecipe) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.title = recipe.title
            self.imageUrl = recipe.imageUrl
            self.ingredients = recipe.ingredients
            self.instructions = recipe.instructions
            self.servings = recipe.servings
            self.prepTimeMinutes = recipe.prepTimeMinutes
            self.sourceUrl = recipe.sourceUrl
            self.aiEnhanced = recipe.aiEnhanced
            self.author = recipe.author
            self.authorUrl = recipe.authorUrl
            
            self.hasTitle = !recipe.title.isEmpty
            self.hasImage = recipe.imageUrl != nil && !recipe.imageUrl!.isEmpty
            self.hasIngredients = !recipe.ingredients.isEmpty
            self.hasInstructions = !recipe.instructions.isEmpty
            self.isLoading = false
        }
    }
    
    /// Progressive updates - update individual fields as they become available
    func updateTitle(_ title: String) {
        DispatchQueue.main.async { [weak self] in
            self?.title = title
            self?.hasTitle = !title.isEmpty
        }
    }
    
    func updateImage(_ imageUrl: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.imageUrl = imageUrl
            self?.hasImage = imageUrl != nil && !imageUrl!.isEmpty
        }
    }
    
    func updateIngredients(_ ingredients: [String]) {
        DispatchQueue.main.async { [weak self] in
            self?.ingredients = ingredients
            self?.hasIngredients = !ingredients.isEmpty
        }
    }
    
    func updateInstructions(_ instructions: String) {
        DispatchQueue.main.async { [weak self] in
            self?.instructions = instructions
            self?.hasInstructions = !instructions.isEmpty
        }
    }
    
    func updateMetadata(servings: Int, prepTimeMinutes: Int, aiEnhanced: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.servings = servings
            self?.prepTimeMinutes = prepTimeMinutes
            self?.aiEnhanced = aiEnhanced
        }
    }
    
    func finishLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
        }
    }
}

