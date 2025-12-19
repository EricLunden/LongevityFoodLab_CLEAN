import SwiftUI

struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let mealPlan: MealPlan
    
    // Stub: Generate shopping list from planned meals
    private var shoppingList: ShoppingList {
        // COMMENT: This would aggregate ingredients from all recipes in the meal plan
        // Group by grocery category (produce, meat, dairy, pantry, etc.)
        // Count how many meals use each ingredient
        // Return grouped ShoppingList
        
        // Placeholder implementation
        return ShoppingList(items: [])
    }
    
    // Group items by category for display
    private var groupedItems: [String: [ShoppingListItem]] {
        Dictionary(grouping: shoppingList.items) { $0.category }
    }
    
    private let categories = ["Produce", "Meat & Seafood", "Dairy", "Pantry", "Other"]
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                    .ignoresSafeArea()
                
                ScrollView {
                VStack(spacing: 20) {
                    // Optional top callout card
                    StandardCard {
                        HStack(spacing: 12) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.2, green: 0.7, blue: 0.4),  // Green
                                            Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            
                            Text("Designed to minimize leftover ingredients")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Grouped shopping list
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(categories, id: \.self) { category in
                            if let items = groupedItems[category], !items.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 20)
                                    
                                    VStack(spacing: 8) {
                                        ForEach(items) { item in
                                            shoppingListItemRow(item: item)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - Shopping List Item Row
    private func shoppingListItemRow(item: ShoppingListItem) -> some View {
        HStack {
            // Checkbox
            Image(systemName: "circle")
                .font(.body)
                .foregroundColor(.secondary)
            
            // Name and quantity
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(item.quantity)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Used in X meals caption
            if item.usedInMeals > 1 {
                Text("Used in \(item.usedInMeals) meals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(colorScheme == .dark ? Color.black : Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}

