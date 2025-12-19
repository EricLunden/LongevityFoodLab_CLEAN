import Foundation

// MARK: - LFI Engine
/// Lightweight Longevity Food Index (LFI) Fast-Pass Scoring Engine
/// 
/// This is a fast heuristic pass used ONLY for candidate evaluation.
/// It is NOT full LFI analysis - no nutrition API calls, no macro/micro calculations,
/// no network calls. Pure in-memory logic based on ingredients and categories.
///
/// Typical runtime: <5ms per recipe
/// Output: estimatedLongevityScore (0-100) with low confidence
///
/// Purpose: Enable Spoonacular recipes to be evaluated against health goals
/// without requiring full LFI analysis, while maintaining our proprietary scoring logic.
class LFIEngine {
    
    /// Fast-pass LFI scoring for recipe candidate evaluation
    /// 
    /// This is a lightweight heuristic that evaluates recipes based on:
    /// - Ingredients list and categories
    /// - Obvious ultra-processed signals
    /// - Known longevity-positive foods (olive oil, legumes, vegetables, fish, nuts)
    ///
    /// This is NOT full LFI - it's a fast pass for filtering purposes only.
    /// Full LFI scoring can happen later (v3+) if needed.
    ///
    /// - Parameter recipe: Recipe to score
    /// - Returns: Estimated longevity score (0-100) for filtering purposes
    static func fastScore(recipe: Recipe) -> Int {
        var score = 50 // Start at neutral (50)
        
        // Get all ingredient names (normalized to lowercase for matching)
        let allIngredients = recipe.allIngredients.map { $0.name.lowercased() }
        let ingredientsText = recipe.ingredientsText?.lowercased() ?? ""
        let description = recipe.description.lowercased()
        
        // Combine all text for ingredient detection
        let combinedText = (allIngredients.joined(separator: " ") + " " + ingredientsText + " " + description).lowercased()
        
        // MARK: - Longevity-Positive Foods (Add points)
        
        // Vegetables (high value)
        let vegetables = ["broccoli", "spinach", "kale", "cabbage", "brussels sprouts", "cauliflower", 
                         "carrot", "tomato", "bell pepper", "onion", "garlic", "mushroom", "zucchini",
                         "asparagus", "artichoke", "beet", "sweet potato", "butternut squash"]
        let vegetableCount = vegetables.filter { combinedText.contains($0) }.count
        score += min(vegetableCount * 3, 15) // Max +15 points
        
        // Legumes (high value)
        let legumes = ["lentil", "chickpea", "black bean", "kidney bean", "pinto bean", "navy bean",
                      "lima bean", "black-eyed pea", "split pea", "edamame", "soybean", "tofu", "tempeh"]
        let legumeCount = legumes.filter { combinedText.contains($0) }.count
        score += min(legumeCount * 4, 16) // Max +16 points
        
        // Fish and seafood (high value)
        let fish = ["salmon", "sardine", "mackerel", "tuna", "cod", "halibut", "trout", "anchovy",
                   "herring", "shrimp", "oyster", "mussel", "clam", "scallop"]
        let fishCount = fish.filter { combinedText.contains($0) }.count
        score += min(fishCount * 5, 20) // Max +20 points
        
        // Nuts and seeds (moderate value)
        let nuts = ["almond", "walnut", "pecan", "pistachio", "cashew", "hazelnut", "brazil nut",
                   "chia seed", "flax seed", "hemp seed", "pumpkin seed", "sunflower seed", "sesame seed"]
        let nutCount = nuts.filter { combinedText.contains($0) }.count
        score += min(nutCount * 2, 10) // Max +10 points
        
        // Olive oil (high value)
        if combinedText.contains("olive oil") || combinedText.contains("extra virgin olive oil") {
            score += 5
        }
        
        // Whole grains (moderate value)
        let wholeGrains = ["brown rice", "quinoa", "oats", "oatmeal", "barley", "bulgur", "farro",
                          "whole wheat", "whole grain", "buckwheat", "millet"]
        let grainCount = wholeGrains.filter { combinedText.contains($0) }.count
        score += min(grainCount * 2, 8) // Max +8 points
        
        // Berries (moderate value)
        let berries = ["blueberry", "strawberry", "raspberry", "blackberry", "cranberry", "goji berry"]
        let berryCount = berries.filter { combinedText.contains($0) }.count
        score += min(berryCount * 2, 6) // Max +6 points
        
        // MARK: - Ultra-Processed Signals (Subtract points)
        
        // Added sugars (heavy penalty)
        let sugarSignals = ["sugar", "cane sugar", "brown sugar", "powdered sugar", "corn syrup",
                           "high fructose", "honey", "maple syrup", "agave", "molasses"]
        let sugarCount = sugarSignals.filter { combinedText.contains($0) }.count
        score -= min(sugarCount * 8, 24) // Max -24 points
        
        // Refined flour (heavy penalty)
        let refinedFlour = ["white flour", "all-purpose flour", "bleached flour", "enriched flour",
                           "white bread", "white pasta", "white rice"]
        let flourCount = refinedFlour.filter { combinedText.contains($0) }.count
        score -= min(flourCount * 6, 18) // Max -18 points
        
        // Processed meats (moderate penalty)
        let processedMeats = ["bacon", "sausage", "hot dog", "deli meat", "pepperoni", "salami",
                             "ham", "lunch meat", "cured meat"]
        let meatCount = processedMeats.filter { combinedText.contains($0) }.count
        score -= min(meatCount * 4, 12) // Max -12 points
        
        // Artificial additives (moderate penalty)
        let additives = ["artificial", "preservative", "artificial flavor", "artificial color",
                        "high fructose corn syrup", "hydrogenated", "partially hydrogenated"]
        let additiveCount = additives.filter { combinedText.contains($0) }.count
        score -= min(additiveCount * 3, 9) // Max -9 points
        
        // Unhealthy fats (moderate penalty)
        let unhealthyFats = ["shortening", "lard", "margarine", "vegetable shortening"]
        let fatCount = unhealthyFats.filter { combinedText.contains($0) }.count
        score -= min(fatCount * 3, 9) // Max -9 points
        
        // MARK: - Category-Based Adjustments
        
        // Desserts and sweets (category-based penalty)
        if recipe.categories.contains(.dessert) {
            score -= 15 // Base penalty for desserts
        }
        
        // Fast food indicators (title/description)
        let fastFoodSignals = ["burger", "fries", "fried", "deep fried", "fast food", "takeout"]
        let fastFoodCount = fastFoodSignals.filter { combinedText.contains($0) }.count
        score -= min(fastFoodCount * 5, 15) // Max -15 points
        
        // MARK: - Positive Category Bonuses
        
        // Mediterranean diet alignment
        if recipe.categories.contains(.mediterranean) {
            score += 8
        }
        
        // Vegetarian/Vegan alignment (generally positive)
        if recipe.categories.contains(.vegetarian) {
            score += 3
        }
        if recipe.categories.contains(.vegan) {
            score += 5
        }
        
        // MARK: - Normalize Score
        
        // Clamp to 0-100 range
        score = max(0, min(100, score))
        
        // Fast LFI is intentionally lightweight to avoid UI delays.
        // This score is used only for candidate evaluation and filtering.
        // Full LFI scoring can happen later (v3+) if needed.
        
        return score
    }
    
    // MARK: - Meal Type Classification (Silent, Internal Only)
    
    /// Silent meal type classification for Meal Planner convenience
    /// 
    /// This is a heuristic classification, not authoritative.
    /// Used only for planning convenience - does not affect recipe ownership or editing.
    /// Recipes may qualify for multiple meal types.
    /// Classification is internal only - not exposed to users, not user-editable.
    ///
    /// Classification uses:
    /// - Recipe title keywords
    /// - Ingredient list patterns
    /// - Existing categories/tags (if present)
    /// - Prep time signals (optional)
    ///
    /// If classification fails or is ambiguous, defaults to [.lunch, .dinner]
    ///
    /// - Parameter recipe: Recipe to classify
    /// - Returns: Array of likely meal types (may be empty, defaults to [.lunch, .dinner] if classification fails)
    static func classifyMealTypes(recipe: Recipe) -> [MealType] {
        var hints: Set<MealType> = []
        
        // Get all text for analysis
        let allIngredients = recipe.allIngredients.map { $0.name.lowercased() }
        let ingredientsText = recipe.ingredientsText?.lowercased() ?? ""
        let title = recipe.title.lowercased()
        let description = recipe.description.lowercased()
        
        // Combine all text for pattern matching
        let combinedText = (title + " " + allIngredients.joined(separator: " ") + " " + ingredientsText + " " + description).lowercased()
        
        // MARK: - Breakfast Classification
        
        // Breakfast keywords in title
        let breakfastTitleKeywords = ["breakfast", "morning", "brunch", "pancake", "waffle", "french toast", 
                                     "omelet", "omelette", "scrambled", "fried egg", "poached egg", 
                                     "cereal", "granola", "muesli", "oatmeal", "porridge"]
        let hasBreakfastTitle = breakfastTitleKeywords.contains { title.contains($0) }
        
        // Breakfast ingredients
        let breakfastIngredients = ["egg", "eggs", "bacon", "sausage", "pancake", "waffle", "toast", 
                                   "bagel", "muffin", "croissant", "oatmeal", "oats", "cereal", 
                                   "granola", "yogurt", "greek yogurt", "cottage cheese", "quiche", 
                                   "frittata", "hash brown", "home fries"]
        let breakfastIngredientCount = breakfastIngredients.filter { combinedText.contains($0) }.count
        
        // Breakfast categories
        let hasBreakfastCategory = recipe.categories.contains(.breakfast)
        
        // Breakfast classification: strong title signal OR multiple breakfast ingredients OR category
        if hasBreakfastTitle || breakfastIngredientCount >= 2 || hasBreakfastCategory {
            hints.insert(.breakfast)
        }
        
        // MARK: - Lunch Classification
        
        // Lunch keywords in title
        let lunchTitleKeywords = ["lunch", "sandwich", "wrap", "panini", "salad", "soup", "bowl", 
                                 "burrito", "taco", "quesadilla", "pita", "sub", "hoagie"]
        let hasLunchTitle = lunchTitleKeywords.contains { title.contains($0) }
        
        // Lunch ingredients/patterns
        let lunchPatterns = ["salad", "soup", "sandwich", "wrap", "bowl", "burrito", "taco", 
                            "quesadilla", "pita", "hummus", "guacamole", "salsa"]
        let lunchPatternCount = lunchPatterns.filter { combinedText.contains($0) }.count
        
        // Lunch categories
        let hasLunchCategory = recipe.categories.contains(.lunch)
        let hasSaladCategory = recipe.categories.contains(.salad)
        let hasSoupCategory = recipe.categories.contains(.soup)
        
        // Lunch classification: title signal OR multiple lunch patterns OR category
        if hasLunchTitle || lunchPatternCount >= 2 || hasLunchCategory || hasSaladCategory || hasSoupCategory {
            hints.insert(.lunch)
        }
        
        // MARK: - Dinner Classification
        
        // Dinner keywords in title
        let dinnerTitleKeywords = ["dinner", "supper", "entree", "main course", "roast", "roasted", 
                                  "grilled", "baked", "braised", "stew", "casserole", "lasagna", 
                                  "pasta", "risotto", "paella", "curry", "stir fry", "stir-fry"]
        let hasDinnerTitle = dinnerTitleKeywords.contains { title.contains($0) }
        
        // Dinner ingredients/patterns (proteins, complex dishes)
        let dinnerProteins = ["chicken", "beef", "pork", "lamb", "fish", "salmon", "tuna", "shrimp", 
                             "steak", "chop", "cutlet", "fillet", "breast", "thigh", "leg"]
        let dinnerProteinCount = dinnerProteins.filter { combinedText.contains($0) }.count
        
        // Dinner patterns
        let dinnerPatterns = ["roast", "roasted", "grilled", "baked", "braised", "stew", "casserole", 
                             "lasagna", "pasta", "risotto", "paella", "curry", "stir fry"]
        let dinnerPatternCount = dinnerPatterns.filter { combinedText.contains($0) }.count
        
        // Dinner categories
        let hasDinnerCategory = recipe.categories.contains(.dinner)
        let hasMainCategory = recipe.categories.contains(.main)
        
        // Dinner classification: title signal OR protein + pattern OR category
        // Also consider prep time - longer prep times often indicate dinner
        let totalTime = recipe.prepTime + recipe.cookTime
        let hasLongPrepTime = totalTime > 30 // More than 30 minutes suggests dinner
        
        if hasDinnerTitle || (dinnerProteinCount >= 1 && dinnerPatternCount >= 1) || 
           hasDinnerCategory || hasMainCategory || hasLongPrepTime {
            hints.insert(.dinner)
        }
        
        // MARK: - Snack Classification
        
        // Snack keywords in title
        let snackTitleKeywords = ["snack", "dip", "spread", "cracker", "chip", "trail mix", 
                                 "energy bar", "protein bar", "nuts", "nuts and", "mix"]
        let hasSnackTitle = snackTitleKeywords.contains { title.contains($0) }
        
        // Snack patterns
        let snackPatterns = ["dip", "spread", "cracker", "chip", "trail mix", "energy bar", 
                            "protein bar", "nuts", "seeds", "popcorn", "pretzel"]
        let snackPatternCount = snackPatterns.filter { combinedText.contains($0) }.count
        
        // Snack categories
        let hasSnackCategory = recipe.categories.contains(.snack)
        
        // Snack classification: title signal OR multiple snack patterns OR category
        // Also consider small serving sizes
        let hasSmallServings = recipe.servings <= 4 && totalTime < 20 // Quick, small portions
        
        if hasSnackTitle || snackPatternCount >= 2 || hasSnackCategory || hasSmallServings {
            hints.insert(.snack)
        }
        
        // MARK: - Dessert Classification
        
        // Dessert keywords in title
        let dessertTitleKeywords = ["dessert", "cake", "cookie", "cookies", "pie", "brownie", "brownies",
                                   "pudding", "ice cream", "sorbet", "gelato", "mousse", "tart", "tarte",
                                   "cheesecake", "cupcake", "cupcakes", "muffin", "muffins", "donut", "donuts",
                                   "fudge", "candy", "chocolate", "sweet", "treat", "sundae", "parfait",
                                   "cobbler", "crisp", "crumble", "trifle", "tiramisu", "flan", "custard",
                                   "souffle", "soufflé", "creme brulee", "crème brûlée", "baklava", "cannoli"]
        let hasDessertTitle = dessertTitleKeywords.contains { title.contains($0) }
        
        // Dessert ingredients/patterns
        let dessertIngredients = ["sugar", "brown sugar", "powdered sugar", "confectioners sugar",
                                 "chocolate", "dark chocolate", "milk chocolate", "white chocolate",
                                 "cocoa", "cacao", "vanilla extract", "vanilla", "cinnamon",
                                 "flour", "all-purpose flour", "cake flour", "baking powder",
                                 "baking soda", "butter", "cream", "whipped cream", "heavy cream",
                                 "cream cheese", "mascarpone", "ricotta", "eggs", "egg yolks",
                                 "shortening", "lard", "frosting", "icing", "glaze", "syrup",
                                 "honey", "maple syrup", "caramel", "toffee", "nuts", "almonds",
                                 "walnuts", "pecans", "hazelnuts", "pistachios", "fruit", "berries",
                                 "strawberries", "blueberries", "raspberries", "cherries", "apples",
                                 "peaches", "bananas", "coconut", "coconut milk", "coconut cream"]
        let dessertIngredientCount = dessertIngredients.filter { combinedText.contains($0) }.count
        
        // Dessert patterns (cooking methods)
        let dessertPatterns = ["bake", "baked", "baking", "frost", "frosted", "frosting",
                              "glaze", "glazed", "sprinkle", "sprinkled", "decorate", "decorated",
                              "layer", "layered", "chill", "chilled", "freeze", "frozen"]
        let dessertPatternCount = dessertPatterns.filter { combinedText.contains($0) }.count
        
        // Dessert categories
        let hasDessertCategory = recipe.categories.contains(.dessert)
        
        // Dessert classification: title signal OR multiple dessert ingredients/patterns OR category
        // Also consider if it has high sugar content indicators
        let hasHighSugarContent = dessertIngredientCount >= 3 || dessertPatternCount >= 2
        
        if hasDessertTitle || hasHighSugarContent || hasDessertCategory {
            hints.insert(.dessert)
        }
        
        // MARK: - Default Fallback
        
        // If no hints found, default to lunch and dinner (most common meal types)
        // This ensures recipes are never completely excluded from meal planning
        if hints.isEmpty {
            hints = [.lunch, .dinner]
        }
        
        return Array(hints).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - Dietary Category Classification (Silent, Internal Only)
    
    /// Classifies dietary categories based on ingredients (silent classification)
    /// Called on recipe import to ensure filtering works immediately
    /// This is a heuristic classification, not authoritative
    /// Used only for filtering convenience - does not affect recipe ownership or editing
    static func classifyDietaryCategories(recipe: Recipe) -> [RecipeCategory] {
        var categories: [RecipeCategory] = []
        
        // Combine all text sources for analysis
        let ingredientsText = (recipe.ingredientsText ?? "").lowercased()
        let ingredientNames = recipe.allIngredients.map { $0.name.lowercased() }.joined(separator: " ")
        let titleText = recipe.title.lowercased()
        let combinedText = ingredientsText + " " + ingredientNames + " " + titleText
        
        // ═══════════════════════════════════════════════════════════════
        // MEDITERRANEAN DETECTION
        // ═══════════════════════════════════════════════════════════════
        let mediterraneanIngredients = [
            // Core Mediterranean ingredients
            "olive oil", "extra virgin", "evoo",
            // Vegetables
            "tomato", "tomatoes", "eggplant", "zucchini", "bell pepper", "artichoke",
            // Herbs & aromatics
            "garlic", "basil", "oregano", "rosemary", "thyme", "parsley",
            // Cheese & dairy
            "feta", "greek yogurt", "halloumi", "ricotta",
            // Legumes
            "chickpea", "lentil", "white bean", "cannellini", "hummus", "falafel",
            // Seafood
            "salmon", "sardine", "anchovy", "shrimp", "calamari", "sea bass", "branzino",
            // Grains
            "couscous", "bulgur", "farro", "pita",
            // Other
            "olive", "caper", "tahini", "za'atar", "sumac", "harissa"
        ]
        let mediterraneanCount = mediterraneanIngredients.filter { combinedText.contains($0) }.count
        
        // Also check title for Mediterranean indicators
        let mediterraneanTitleIndicators = ["mediterranean", "greek", "italian", "spanish", "moroccan", "turkish", "lebanese", "middle eastern"]
        let hasMediterraneanTitle = mediterraneanTitleIndicators.contains { titleText.contains($0) }
        
        if mediterraneanCount >= 3 || hasMediterraneanTitle {
            categories.append(.mediterranean)
        }
        
        // ═══════════════════════════════════════════════════════════════
        // VEGAN DETECTION
        // ═══════════════════════════════════════════════════════════════
        let animalProducts = [
            // Meat
            "chicken", "beef", "pork", "lamb", "turkey", "duck", "bacon", "sausage", "ham", "prosciutto",
            "steak", "ground beef", "ground turkey", "meatball",
            // Seafood
            "fish", "salmon", "tuna", "shrimp", "crab", "lobster", "scallop", "anchovy", "sardine",
            // Dairy
            "milk", "cheese", "butter", "cream", "yogurt", "sour cream", "whey", "casein",
            "parmesan", "cheddar", "mozzarella", "feta", "ricotta", "brie",
            // Eggs
            "egg", "eggs", "mayo", "mayonnaise",
            // Other
            "honey", "gelatin"
        ]
        let hasAnimalProducts = animalProducts.contains { combinedText.contains($0) }
        
        let veganIndicators = ["vegan", "plant-based", "plant based", "dairy-free", "dairy free"]
        let hasVeganIndicator = veganIndicators.contains { combinedText.contains($0) }
        
        if !hasAnimalProducts || hasVeganIndicator {
            categories.append(.vegan)
            categories.append(.vegetarian) // Vegan is also vegetarian
        }
        
        // ═══════════════════════════════════════════════════════════════
        // VEGETARIAN DETECTION (if not already vegan)
        // ═══════════════════════════════════════════════════════════════
        if !categories.contains(.vegetarian) {
            let meatProducts = [
                "chicken", "beef", "pork", "lamb", "turkey", "duck", "bacon", "sausage", "ham", "prosciutto",
                "steak", "ground beef", "ground turkey", "meatball",
                "fish", "salmon", "tuna", "shrimp", "crab", "lobster", "scallop", "anchovy", "sardine"
            ]
            let hasMeat = meatProducts.contains { combinedText.contains($0) }
            
            let vegetarianIndicators = ["vegetarian", "veggie", "meatless"]
            let hasVegetarianIndicator = vegetarianIndicators.contains { combinedText.contains($0) }
            
            if !hasMeat || hasVegetarianIndicator {
                categories.append(.vegetarian)
            }
        }
        
        // ═══════════════════════════════════════════════════════════════
        // KETO DETECTION
        // ═══════════════════════════════════════════════════════════════
        let ketoIngredients = [
            "avocado", "coconut oil", "mct oil", "butter", "ghee",
            "bacon", "egg", "eggs", "cheese", "cream cheese", "heavy cream",
            "almond flour", "coconut flour", "cauliflower rice",
            "olive oil", "fatty fish", "salmon"
        ]
        let highCarbIngredients = [
            "rice", "pasta", "bread", "flour", "potato", "potatoes",
            "sugar", "honey", "maple syrup", "corn", "cornstarch",
            "oat", "oats", "quinoa", "wheat", "tortilla", "noodle"
        ]
        let ketoCount = ketoIngredients.filter { combinedText.contains($0) }.count
        let carbCount = highCarbIngredients.filter { combinedText.contains($0) }.count
        
        let ketoIndicators = ["keto", "ketogenic", "low carb", "low-carb"]
        let hasKetoIndicator = ketoIndicators.contains { combinedText.contains($0) }
        
        if (ketoCount >= 2 && carbCount == 0) || hasKetoIndicator {
            categories.append(.keto)
        }
        
        // ═══════════════════════════════════════════════════════════════
        // PALEO DETECTION
        // ═══════════════════════════════════════════════════════════════
        let paleoIngredients = [
            "grass-fed", "grass fed", "wild-caught", "wild caught",
            "coconut oil", "avocado oil", "olive oil", "ghee",
            "sweet potato", "butternut squash", "cauliflower",
            "almond", "cashew", "walnut", "pecan"
        ]
        let nonPaleoIngredients = [
            "bread", "pasta", "rice", "oat", "wheat", "corn", "tortilla",
            "milk", "cheese", "yogurt", "cream", "butter",
            "soy", "tofu", "tempeh", "edamame",
            "bean", "lentil", "chickpea", "peanut",
            "sugar", "honey", "maple syrup"
        ]
        let paleoCount = paleoIngredients.filter { combinedText.contains($0) }.count
        let nonPaleoCount = nonPaleoIngredients.filter { combinedText.contains($0) }.count
        
        let paleoIndicators = ["paleo", "whole30", "whole 30", "primal"]
        let hasPaleoIndicator = paleoIndicators.contains { combinedText.contains($0) }
        
        if (paleoCount >= 2 && nonPaleoCount == 0) || hasPaleoIndicator {
            categories.append(.paleo)
        }
        
        // ═══════════════════════════════════════════════════════════════
        // PESCATARIAN DETECTION
        // ═══════════════════════════════════════════════════════════════
        let seafood = [
            "fish", "salmon", "tuna", "cod", "halibut", "tilapia", "trout",
            "shrimp", "crab", "lobster", "scallop", "mussel", "clam", "oyster",
            "anchovy", "sardine", "mackerel", "sea bass", "snapper"
        ]
        let landMeat = [
            "chicken", "beef", "pork", "lamb", "turkey", "duck",
            "bacon", "sausage", "ham", "prosciutto", "steak", "meatball"
        ]
        let hasSeafood = seafood.contains { combinedText.contains($0) }
        let hasLandMeat = landMeat.contains { combinedText.contains($0) }
        
        // Note: .pescatarian is not a RecipeCategory enum case
        // Pescatarian recipes will be identified by ingredient matching only
        // For filtering purposes, "pescatarian" preference can match recipes with seafood but no land meat
        
        // ═══════════════════════════════════════════════════════════════
        // LOW CARB DETECTION (broader than keto)
        // ═══════════════════════════════════════════════════════════════
        // Note: .lowCarb is not a RecipeCategory enum case
        // Low carb recipes will be classified as .keto if they meet keto criteria
        // For filtering purposes, "low carb" preference can match .keto recipes
        
        return categories
    }
}

