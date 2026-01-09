//
//  LocalNutritionService.swift
//  LongevityFoodLab
//
//  Local SQLite database service for nutrition lookups (Tier 0)
//

import Foundation
import SQLite3

class LocalNutritionService {
    static let shared = LocalNutritionService()
    
    // SQLite constant: tells SQLite to copy the string immediately (Swift strings are temporary)
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "local.nutrition.db", qos: .userInitiated)
    private let dbReadyGroup = DispatchGroup()
    private var isDatabaseReady = false
    
    private init() {
        dbReadyGroup.enter()
        setupDatabase()
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.dbReadyGroup.leave() }
            
            // Copy database from bundle to Documents directory on first launch
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbPath = documentsPath.appendingPathComponent("nutrition.db")
            
            // Check if database exists in Documents
            if !fileManager.fileExists(atPath: dbPath.path) {
                // Copy from bundle
                if let bundlePath = Bundle.main.path(forResource: "nutrition", ofType: "db") {
                    do {
                        try fileManager.copyItem(at: URL(fileURLWithPath: bundlePath), to: dbPath)
                        print("✅ LocalNutritionService: Copied database from bundle to Documents")
                    } catch {
                        print("❌ LocalNutritionService: Failed to copy database: \(error)")
                        return
                    }
                } else {
                    print("⚠️ LocalNutritionService: Database not found in bundle, falling back to API")
                    return
                }
            }
            
            // Open database connection with FULLMUTEX mode for thread safety
            print("🔍 LocalNutritionService: Opening database at: \(dbPath.path)")
            if sqlite3_open_v2(dbPath.path, &self.db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(self.db))
                print("❌ LocalNutritionService: Failed to open database: \(error)")
                self.db = nil
                return
            }
            print("✅ LocalNutritionService: Database file opened successfully with FULLMUTEX mode")
            
            // Check database integrity
            if self.checkDatabaseIntegrity() {
                // Verify database has data
                var countStatement: OpaquePointer?
                let countQuery = "SELECT COUNT(*) FROM foods"
                if sqlite3_prepare_v2(self.db, countQuery, -1, &countStatement, nil) == SQLITE_OK {
                    if sqlite3_step(countStatement) == SQLITE_ROW {
                        let foodCount = sqlite3_column_int(countStatement, 0)
                        print("✅ LocalNutritionService: Database opened and verified - \(foodCount) foods loaded")
                        if foodCount == 0 {
                            print("⚠️ LocalNutritionService: WARNING - Database is empty!")
                        }
                    }
                    sqlite3_finalize(countStatement)
                }
                
                // Test direct query for bananas
                var testStatement: OpaquePointer?
                let testQuery = "SELECT name FROM foods WHERE name LIKE '%bananas%raw%' COLLATE NOCASE LIMIT 1"
                if sqlite3_prepare_v2(self.db, testQuery, -1, &testStatement, nil) == SQLITE_OK {
                    let testStepResult = sqlite3_step(testStatement)
                    if testStepResult == SQLITE_ROW {
                        let testName = String(cString: sqlite3_column_text(testStatement, 0))
                        print("✅ LocalNutritionService: TEST - Found '\(testName)' in database")
                    } else {
                        print("❌ LocalNutritionService: TEST - Direct query returned no rows (stepResult: \(testStepResult))")
                    }
                    sqlite3_finalize(testStatement)
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(self.db))
                    print("❌ LocalNutritionService: TEST - Failed to prepare test query: \(errorMsg)")
                }
                
                self.isDatabaseReady = true
            } else {
                print("⚠️ LocalNutritionService: Database integrity check failed")
            }
        }
    }
    
    /// Wait for database to be ready (with timeout)
    private func waitForDatabase() {
        let result = dbReadyGroup.wait(timeout: .now() + 5.0)
        if result == .timedOut {
            print("⚠️ LocalNutritionService: Database setup timed out")
        }
    }
    
    private func checkDatabaseIntegrity() -> Bool {
        guard let db = db else { return false }
        
        var statement: OpaquePointer?
        let query = "PRAGMA integrity_check;"
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let result = String(cString: sqlite3_column_text(statement, 0))
                sqlite3_finalize(statement)
                return result == "ok"
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    // MARK: - Unit Conversion
    
    /// Convert amount to grams (matches USDAService logic)
    private func convertToGrams(amount: Double, unit: String) -> Double {
        let unitLower = unit.lowercased()
        switch unitLower {
        case "kg", "kilogram", "kilograms":
            return amount * 1000
        case "g", "gram", "grams":
            return amount
        case "oz", "ounce", "ounces":
            return amount * 28.35
        case "lb", "pound", "pounds":
            return amount * 453.6
        case "mg", "milligram", "milligrams":
            return amount / 1000
        default:
            // Assume grams if unknown unit
            print("⚠️ LocalNutritionService: Unknown unit '\(unit)', assuming grams")
            return amount
        }
    }
    
    // MARK: - Search Foods
    
    /// Search for foods by name (with relevance scoring)
    func searchFoods(query: String, limit: Int = 20) -> [LocalFood] {
        waitForDatabase()
        
        // SQLite connections must be accessed from the same queue
        var finalResults: [LocalFood] = []
        
        dbQueue.sync {
            guard let db = self.db else { 
                print("⚠️ LocalNutritionService: Database not available for search")
                return
            }
            
            let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedQuery.isEmpty else { return }
            
            print("🔍 LocalNutritionService: Searching for '\(normalizedQuery)' (original: '\(query)')")
            
            var results: [(food: LocalFood, score: Int)] = []
        
        var statement: OpaquePointer?
        let exactPattern = normalizedQuery
        let startsWithPattern = "\(normalizedQuery)%"
        let containsPattern = "%\(normalizedQuery)%"
        
        // Also try plural/singular variations
        let pluralPattern: String
        let singularPattern: String
        if normalizedQuery.hasSuffix("s") {
            // Query is plural, also search singular
            pluralPattern = normalizedQuery
            singularPattern = String(normalizedQuery.dropLast())
        } else {
            // Query is singular, also search plural
            singularPattern = normalizedQuery
            pluralPattern = normalizedQuery + "s"
        }
        
        print("🔍 LocalNutritionService: Search patterns - exact: '\(exactPattern)', starts: '\(startsWithPattern)', contains: '\(containsPattern)'")
        print("🔍 LocalNutritionService: Also searching - singular: '\(singularPattern)', plural: '\(pluralPattern)'")
        
        // Simplified search query - use contains pattern for both singular and plural
        // This avoids complex parameter binding issues
        let searchPattern = "%\(normalizedQuery)%"
        let pluralSearchPattern = "%\(pluralPattern)%"
        
        // Use a simpler query without ORDER BY CASE to test
        let enhancedSearchQuery = """
            SELECT f.id, f.fdc_id, f.name, f.description, f.category, f.data_source, f.popularity_score
            FROM foods f
            WHERE f.name LIKE ? COLLATE NOCASE
               OR f.name LIKE ? COLLATE NOCASE
            ORDER BY f.popularity_score DESC
            LIMIT ?
        """
        
        let prepareResult = sqlite3_prepare_v2(db, enhancedSearchQuery, -1, &statement, nil)
        if prepareResult == SQLITE_OK {
            // Bind patterns: singular contains, plural contains
            sqlite3_bind_text(statement, 1, searchPattern, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, pluralSearchPattern, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 3, Int32(limit * 2)) // Get more for scoring
            
            print("🔍 LocalNutritionService: Binding parameters:")
            print("   Param 1 (singular): '\(searchPattern)'")
            print("   Param 2 (plural): '\(pluralSearchPattern)'")
            print("   Param 3 (limit): \(limit * 2)")
            print("🔍 LocalNutritionService: SQL prepared successfully, executing query...")
            
            // Test: Try a super simple query first
            var simpleTestStatement: OpaquePointer?
            let simpleTestQuery = "SELECT COUNT(*) FROM foods WHERE name LIKE ? COLLATE NOCASE"
            if sqlite3_prepare_v2(db, simpleTestQuery, -1, &simpleTestStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(simpleTestStatement, 1, "%bananas%", -1, SQLITE_TRANSIENT)
                let simpleStepResult = sqlite3_step(simpleTestStatement)
                if simpleStepResult == SQLITE_ROW {
                    let simpleCount = sqlite3_column_int(simpleTestStatement, 0)
                    print("🔍 LocalNutritionService: SIMPLE TEST - Found \(simpleCount) rows with bound '%bananas%'")
                } else {
                    print("🔍 LocalNutritionService: SIMPLE TEST - Failed with stepResult: \(simpleStepResult)")
                }
                sqlite3_finalize(simpleTestStatement)
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                print("🔍 LocalNutritionService: SIMPLE TEST - Failed to prepare: \(errorMsg)")
            }
            
            var rowCount = 0
            var stepResult: Int32
            while true {
                stepResult = sqlite3_step(statement)
                if stepResult == SQLITE_ROW {
                    rowCount += 1
                    let id = Int(sqlite3_column_int(statement, 0))
                    let fdcId = Int(sqlite3_column_int(statement, 1))
                    let name = String(cString: sqlite3_column_text(statement, 2))
                    let description = String(cString: sqlite3_column_text(statement, 3))
                    let category = String(cString: sqlite3_column_text(statement, 4))
                    let dataSource = String(cString: sqlite3_column_text(statement, 5))
                    let popularityScore = Int(sqlite3_column_int(statement, 6))
                    
                    let food = LocalFood(
                        id: id,
                        fdcId: fdcId,
                        name: name,
                        description: description,
                        category: category,
                        dataSource: dataSource,
                        popularityScore: popularityScore
                    )
                    
                    // Calculate relevance score
                    let score = calculateRelevanceScore(query: normalizedQuery, food: food)
                    results.append((food: food, score: score))
                    print("🔍 LocalNutritionService: Found food in name search: '\(name)' (score: \(score))")
                } else if stepResult == SQLITE_DONE {
                    break
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    print("⚠️ LocalNutritionService: SQL step error: \(stepResult) - \(errorMsg)")
                    break
                }
            }
            print("🔍 LocalNutritionService: Query returned \(rowCount) rows (stepResult: \(stepResult))")
        } else {
            let errorMsg = String(cString: sqlite3_errmsg(db))
            print("❌ LocalNutritionService: Failed to prepare search statement: \(prepareResult) - \(errorMsg)")
            print("❌ LocalNutritionService: Query was: \(enhancedSearchQuery)")
            }
            sqlite3_finalize(statement)
            
            print("🔍 LocalNutritionService: Found \(results.count) results from name search")
            
            // Search in aliases (case-insensitive)
            let aliasQuery = """
            SELECT f.id, f.fdc_id, f.name, f.description, f.category, f.data_source, f.popularity_score
            FROM foods f
            JOIN aliases a ON f.id = a.food_id
            WHERE a.alias LIKE ? COLLATE NOCASE
               OR a.alias LIKE ? COLLATE NOCASE
               OR a.alias LIKE ? COLLATE NOCASE
            ORDER BY 
                CASE 
                    WHEN a.alias = ? COLLATE NOCASE THEN 1
                    WHEN a.alias LIKE ? COLLATE NOCASE THEN 2
                    ELSE 3
                END,
                f.popularity_score DESC
            LIMIT ?
        """
        
            if sqlite3_prepare_v2(db, aliasQuery, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, exactPattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, startsWithPattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 3, containsPattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 4, exactPattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 5, startsWithPattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(statement, 6, Int32(limit * 2))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let fdcId = Int(sqlite3_column_int(statement, 1))
                let name = String(cString: sqlite3_column_text(statement, 2))
                let description = String(cString: sqlite3_column_text(statement, 3))
                let category = String(cString: sqlite3_column_text(statement, 4))
                let dataSource = String(cString: sqlite3_column_text(statement, 5))
                let popularityScore = Int(sqlite3_column_int(statement, 6))
                
                let food = LocalFood(
                    id: id,
                    fdcId: fdcId,
                    name: name,
                    description: description,
                    category: category,
                    dataSource: dataSource,
                    popularityScore: popularityScore
                )
                
                    // Check if already in results
                    if !results.contains(where: { $0.food.id == food.id }) {
                        let score = calculateRelevanceScore(query: normalizedQuery, food: food) - 30 // Alias match penalty
                        results.append((food: food, score: score))
                    }
                }
            }
            sqlite3_finalize(statement)
        
            // Sort by score and return top results
            results.sort { $0.score > $1.score }
            finalResults = Array(results.prefix(limit)).map { $0.food }
            print("🔍 LocalNutritionService: Returning \(finalResults.count) results (top score: \(results.first?.score ?? -1))")
            if let topResult = finalResults.first {
                print("🔍 LocalNutritionService: Top result: '\(topResult.name)'")
            }
        }
        
        return finalResults
    }
    
    private func calculateRelevanceScore(query: String, food: LocalFood) -> Int {
        var score = food.popularityScore // Start with popularity (typically 0-100)
        
        let nameLower = food.name.lowercased()
        let descLower = food.description.lowercased()
        let queryLower = query.lowercased()
        let queryWords = queryLower.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let combinedText = "\(nameLower) \(descLower)"
        
        // Detect if query is a simple, single-word food (like "apple", "banana", "salmon")
        let isSimpleFood = queryWords.count == 1 && queryLower.count < 15
        
        // EXACT match gets highest score (1000 points)
        if nameLower == queryLower {
            score += 1000
        }
        // STARTS WITH the search term gets high score (500 points)
        else if nameLower.hasPrefix(queryLower) {
            score += 500
        }
        // Word boundary match (search term is a complete word) gets medium score (200 points)
        else if nameLower.contains(" \(queryLower) ") || nameLower.hasSuffix(" \(queryLower)") || nameLower.hasPrefix("\(queryLower) ") {
            score += 200
        }
        // CONTAINS match gets lowest score (100 points)
        else if nameLower.contains(queryLower) {
            score += 100
        }
        
        // For simple foods, heavily penalize complex/processed foods
        if isSimpleFood {
            // Penalty for complex foods (contains multiple ingredients separated by commas)
            if nameLower.contains(",") || descLower.contains(",") {
                score -= 200 // Heavy penalty for complex foods when searching simple
            }
            
            // Penalty for processed foods (croissants, pie, cake, etc.)
            let processedKeywords = ["croissant", "pie", "cake", "cookie", "bread", "muffin", "pastry", "doughnut", "donut", "cooked", "prepared", "canned", "frozen"]
            for keyword in processedKeywords {
                if combinedText.contains(keyword) && !combinedText.hasPrefix(keyword) {
                    score -= 300 // Very heavy penalty - processed food when searching for simple food
                }
            }
        }
        
        // Check if query words appear in description/name
        for word in queryWords {
            if combinedText.contains(word) {
                score += 50
                
                // Bonus if word appears at the start (main ingredient)
                if nameLower.hasPrefix(word) || nameLower.hasPrefix("\(word) ") {
                    score += 50
                }
                
                // Penalty if word appears after a comma (likely a modifier)
                if let commaIndex = nameLower.firstIndex(of: ","),
                   nameLower[commaIndex...].contains(word) {
                    score -= 30
                }
            }
        }
        
        // Penalty for results that contain the query but as a modifier
        // e.g., "salt" should not match "Butter, salted"
        let queryIsModifier = nameLower.contains(", \(queryLower)") || 
                              nameLower.contains(" \(queryLower),") ||
                              descLower.contains(", \(queryLower)") ||
                              descLower.contains(" \(queryLower),")
        if queryIsModifier && !nameLower.hasPrefix(queryLower) {
            score -= 50
        }
        
        // Specific negative scoring for misleading matches
        // If searching for "steak" and result contains "fries" or "fry" → reduce score by 300
        if queryLower.contains("steak") && (combinedText.contains("fries") || combinedText.contains("fry")) {
            score -= 300
        }
        
        // If searching for "lettuce" and result contains "taco" or "burger" → reduce score by 300
        if queryLower.contains("lettuce") && (combinedText.contains("taco") || combinedText.contains("burger")) {
            score -= 300
        }
        
        // If searching for "tomato" and result contains "juice" or "sauce" or "dressing" → reduce score by 300
        if queryLower.contains("tomato") && (combinedText.contains("juice") || combinedText.contains("sauce") || combinedText.contains("dressing")) {
            score -= 300
        }
        
        // If searching for "carrot" and result contains "cake" or "canned" → reduce score by 200
        if queryLower.contains("carrot") && (combinedText.contains("cake") || combinedText.contains("canned")) {
            score -= 200
        }
        
        // VEGETABLE-SPECIFIC SCORING: Prefer fresh/raw over processed versions
        // This handles common vegetables that have many processed variants
        
        // Tomato/tomatoes: penalize processed forms, boost raw
        if queryLower.contains("tomato") {
            let processedPenalties = ["sun-dried", "sun dried", "juice", "sauce", "paste", "ketchup", "canned", "stewed"]
            for penalty in processedPenalties {
                if combinedText.contains(penalty) {
                    score -= 400 // Heavy penalty for processed tomatoes
                }
            }
            // Boost raw/ripe tomatoes
            if combinedText.contains("raw") || combinedText.contains("ripe") || combinedText.contains("fresh") {
                score += 200 // Bonus for fresh tomatoes
            }
        }
        
        // Pepper/peppers: penalize processed, boost raw
        if queryLower.contains("pepper") && !queryLower.contains("black") && !queryLower.contains("white") {
            let processedPenalties = ["pickled", "sauce", "dried", "roasted", "canned"]
            for penalty in processedPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Mushroom/mushrooms: penalize processed, boost raw
        if queryLower.contains("mushroom") {
            let processedPenalties = ["canned", "dried", "soup", "sauce"]
            for penalty in processedPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Spinach: penalize processed, boost raw (cooked is acceptable, lighter penalty)
        if queryLower.contains("spinach") {
            let heavyPenalties = ["canned", "creamed", "frozen"]
            for penalty in heavyPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            // Lighter penalty for cooked (common and healthy)
            if combinedText.contains("cooked") {
                score -= 100
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Corn: penalize processed, boost raw/sweet corn (cooked is acceptable, lighter penalty)
        if queryLower.contains("corn") && !queryLower.contains("cornmeal") {
            let heavyPenalties = ["syrup", "chips", "bread", "oil", "canned", "cream"]
            for penalty in heavyPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            // Lighter penalty for cooked (common and healthy)
            if combinedText.contains("cooked") {
                score -= 100
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") || combinedText.contains("sweet corn") {
                score += 200
            }
        }
        
        // Beans/green beans: penalize processed, boost raw/fresh (cooked is acceptable, lighter penalty)
        if queryLower.contains("bean") && (queryLower.contains("green") || queryLower == "beans" || queryLower == "bean") {
            let heavyPenalties = ["baked", "refried", "chili", "canned"]
            for penalty in heavyPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            // Lighter penalty for cooked (common and healthy)
            if combinedText.contains("cooked") {
                score -= 100
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") || combinedText.contains("green bean") {
                score += 200
            }
        }
        
        // Peas: penalize processed, boost raw/fresh (cooked is acceptable, lighter penalty)
        if queryLower.contains("pea") && !queryLower.contains("peanut") {
            let heavyPenalties = ["soup", "split", "canned", "frozen"]
            for penalty in heavyPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            // Lighter penalty for cooked (common and healthy)
            if combinedText.contains("cooked") {
                score -= 100
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Onion/onions: penalize processed, boost raw
        if queryLower.contains("onion") {
            let processedPenalties = ["rings", "fried", "powder", "flakes", "canned", "pickled"]
            for penalty in processedPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Cucumber: penalize processed, boost raw
        if queryLower.contains("cucumber") {
            let processedPenalties = ["pickled", "pickle"]
            for penalty in processedPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Celery: penalize processed, boost raw
        if queryLower.contains("celery") {
            let processedPenalties = ["soup", "salt", "flakes", "powder"]
            for penalty in processedPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Asparagus: penalize processed, boost raw (cooked is acceptable, lighter penalty)
        if queryLower.contains("asparagus") {
            let heavyPenalties = ["canned", "soup"]
            for penalty in heavyPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            // Lighter penalty for cooked (common and healthy)
            if combinedText.contains("cooked") {
                score -= 100
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // Zucchini/squash: penalize processed, boost raw (cooked is acceptable, lighter penalty)
        if queryLower.contains("zucchini") || queryLower.contains("squash") {
            let heavyPenalties = ["bread", "casserole", "cake"]
            for penalty in heavyPenalties {
                if combinedText.contains(penalty) {
                    score -= 400
                }
            }
            // Lighter penalty for cooked (common and healthy)
            if combinedText.contains("cooked") {
                score -= 100
            }
            if combinedText.contains("raw") || combinedText.contains("fresh") {
                score += 200
            }
        }
        
        // General simple vegetables: boost raw, penalize canned/pickled (cooked is acceptable for some)
        let simpleVegetables = ["lettuce", "cabbage", "kale", "broccoli", "cauliflower", "carrot", "radish", "turnip", "beet", "beetroot"]
        for veg in simpleVegetables {
            if queryLower == veg || queryLower == "\(veg)s" {
                if combinedText.contains("canned") || combinedText.contains("pickled") || combinedText.contains("preserved") {
                    score -= 300
                }
                // Lighter penalty for cooked (common and healthy for broccoli, cauliflower, etc.)
                if (veg == "broccoli" || veg == "cauliflower" || veg == "carrot" || veg == "beet" || veg == "beetroot") && combinedText.contains("cooked") {
                    score -= 100
                }
                if combinedText.contains("raw") || combinedText.contains("fresh") {
                    score += 150
                }
            }
        }
        
        // Penalty for branded products when searching for generic items
        if queryWords.count <= 2 && (nameLower.contains("brand") || descLower.contains("brand")) {
            score -= 20
        }
        
        return score
    }
    
    // MARK: - Get Food by ID
    
    func getFood(byId id: Int) -> LocalFood? {
        var food: LocalFood? = nil
        dbQueue.sync {
            guard let db = self.db else { return }
            
            let query = "SELECT id, fdc_id, name, description, category, data_source, popularity_score FROM foods WHERE id = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(id))
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    let foodId = Int(sqlite3_column_int(statement, 0))
                    let fdcId = Int(sqlite3_column_int(statement, 1))
                    let name = String(cString: sqlite3_column_text(statement, 2))
                    let description = String(cString: sqlite3_column_text(statement, 3))
                    let category = String(cString: sqlite3_column_text(statement, 4))
                    let dataSource = String(cString: sqlite3_column_text(statement, 5))
                    let popularityScore = Int(sqlite3_column_int(statement, 6))
                    
                    sqlite3_finalize(statement)
                    
                    food = LocalFood(
                        id: foodId,
                        fdcId: fdcId,
                        name: name,
                        description: description,
                        category: category,
                        dataSource: dataSource,
                        popularityScore: popularityScore
                    )
                    return
                }
            }
            
            sqlite3_finalize(statement)
        }
        return food
    }
    
    func getFood(byFdcId fdcId: Int) -> LocalFood? {
        var food: LocalFood? = nil
        dbQueue.sync {
            guard let db = self.db else { return }
            
            let query = "SELECT id, fdc_id, name, description, category, data_source, popularity_score FROM foods WHERE fdc_id = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(fdcId))
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    let foodId = Int(sqlite3_column_int(statement, 0))
                    let fdcId = Int(sqlite3_column_int(statement, 1))
                    let name = String(cString: sqlite3_column_text(statement, 2))
                    let description = String(cString: sqlite3_column_text(statement, 3))
                    let category = String(cString: sqlite3_column_text(statement, 4))
                    let dataSource = String(cString: sqlite3_column_text(statement, 5))
                    let popularityScore = Int(sqlite3_column_int(statement, 6))
                    
                    sqlite3_finalize(statement)
                    
                    food = LocalFood(
                        id: foodId,
                        fdcId: fdcId,
                        name: name,
                        description: description,
                        category: category,
                        dataSource: dataSource,
                        popularityScore: popularityScore
                    )
                    return
                }
            }
            
            sqlite3_finalize(statement)
        }
        return food
    }
    
    // MARK: - Get Nutrition
    
    func getNutrition(foodId: Int) -> LocalNutrition? {
        var nutrition: LocalNutrition? = nil
        dbQueue.sync {
            guard let db = self.db else { return }
            
            let query = """
                SELECT food_id, calories, protein, carbohydrates, fat, fiber, sugar, sodium,
                       saturated_fat, cholesterol, potassium, calcium, iron, magnesium, phosphorus,
                       zinc, copper, manganese, selenium, iodine,
                       vitamin_a, vitamin_c, vitamin_d, vitamin_e, vitamin_k,
                       vitamin_b1, vitamin_b2, vitamin_b3, vitamin_b5, vitamin_b6,
                       vitamin_b12, folate, choline, omega_3, omega_6
                FROM nutrition
                WHERE food_id = ?
            """
            
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(foodId))
                
                if sqlite3_step(statement) == SQLITE_ROW {
                    nutrition = LocalNutrition(
                        foodId: Int(sqlite3_column_int(statement, 0)),
                        calories: sqlite3_column_double(statement, 1) > 0 ? sqlite3_column_double(statement, 1) : nil,
                        protein: sqlite3_column_double(statement, 2) > 0 ? sqlite3_column_double(statement, 2) : nil,
                        carbohydrates: sqlite3_column_double(statement, 3) > 0 ? sqlite3_column_double(statement, 3) : nil,
                        fat: sqlite3_column_double(statement, 4) > 0 ? sqlite3_column_double(statement, 4) : nil,
                        fiber: sqlite3_column_double(statement, 5) > 0 ? sqlite3_column_double(statement, 5) : nil,
                        sugar: sqlite3_column_double(statement, 6) > 0 ? sqlite3_column_double(statement, 6) : nil,
                        sodium: sqlite3_column_double(statement, 7) > 0 ? sqlite3_column_double(statement, 7) : nil,
                        saturatedFat: sqlite3_column_double(statement, 8) > 0 ? sqlite3_column_double(statement, 8) : nil,
                        cholesterol: sqlite3_column_double(statement, 9) > 0 ? sqlite3_column_double(statement, 9) : nil,
                        potassium: sqlite3_column_double(statement, 10) > 0 ? sqlite3_column_double(statement, 10) : nil,
                        calcium: sqlite3_column_double(statement, 11) > 0 ? sqlite3_column_double(statement, 11) : nil,
                        iron: sqlite3_column_double(statement, 12) > 0 ? sqlite3_column_double(statement, 12) : nil,
                        magnesium: sqlite3_column_double(statement, 13) > 0 ? sqlite3_column_double(statement, 13) : nil,
                        phosphorus: sqlite3_column_double(statement, 14) > 0 ? sqlite3_column_double(statement, 14) : nil,
                        zinc: sqlite3_column_double(statement, 15) > 0 ? sqlite3_column_double(statement, 15) : nil,
                        copper: sqlite3_column_double(statement, 16) > 0 ? sqlite3_column_double(statement, 16) : nil,
                        manganese: sqlite3_column_double(statement, 17) > 0 ? sqlite3_column_double(statement, 17) : nil,
                        selenium: sqlite3_column_double(statement, 18) > 0 ? sqlite3_column_double(statement, 18) : nil,
                        iodine: sqlite3_column_double(statement, 19) > 0 ? sqlite3_column_double(statement, 19) : nil,
                        vitaminA: sqlite3_column_double(statement, 20) > 0 ? sqlite3_column_double(statement, 20) : nil,
                        vitaminC: sqlite3_column_double(statement, 21) > 0 ? sqlite3_column_double(statement, 21) : nil,
                        vitaminD: sqlite3_column_double(statement, 22) > 0 ? sqlite3_column_double(statement, 22) : nil,
                        vitaminE: sqlite3_column_double(statement, 23) > 0 ? sqlite3_column_double(statement, 23) : nil,
                        vitaminK: sqlite3_column_double(statement, 24) > 0 ? sqlite3_column_double(statement, 24) : nil,
                        vitaminB1: sqlite3_column_double(statement, 25) > 0 ? sqlite3_column_double(statement, 25) : nil,
                        vitaminB2: sqlite3_column_double(statement, 26) > 0 ? sqlite3_column_double(statement, 26) : nil,
                        vitaminB3: sqlite3_column_double(statement, 27) > 0 ? sqlite3_column_double(statement, 27) : nil,
                        vitaminB5: sqlite3_column_double(statement, 28) > 0 ? sqlite3_column_double(statement, 28) : nil,
                        vitaminB6: sqlite3_column_double(statement, 29) > 0 ? sqlite3_column_double(statement, 29) : nil,
                        vitaminB12: sqlite3_column_double(statement, 30) > 0 ? sqlite3_column_double(statement, 30) : nil,
                        folate: sqlite3_column_double(statement, 31) > 0 ? sqlite3_column_double(statement, 31) : nil,
                        choline: sqlite3_column_double(statement, 32) > 0 ? sqlite3_column_double(statement, 32) : nil,
                        omega3: sqlite3_column_double(statement, 33) > 0 ? sqlite3_column_double(statement, 33) : nil,
                        omega6: sqlite3_column_double(statement, 34) > 0 ? sqlite3_column_double(statement, 34) : nil
                    )
                }
            }
            
            sqlite3_finalize(statement)
        }
        return nutrition
    }
    
    func getNutritionForServing(foodId: Int, servingId: Int) -> LocalNutrition? {
        guard let nutrition = getNutrition(foodId: foodId),
              let serving = getServings(foodId: foodId).first(where: { $0.id == servingId }) else {
            return nil
        }
        
        return nutrition.scaled(to: serving.grams)
    }
    
    // MARK: - Get Servings
    
    func getServings(foodId: Int) -> [LocalServing] {
        var servings: [LocalServing] = []
        dbQueue.sync {
            guard let db = self.db else { return }
            
            let query = "SELECT id, food_id, description, grams, is_default FROM servings WHERE food_id = ? ORDER BY is_default DESC, grams ASC"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_int(statement, 1, Int32(foodId))
                
                while sqlite3_step(statement) == SQLITE_ROW {
                    let serving = LocalServing(
                        id: Int(sqlite3_column_int(statement, 0)),
                        foodId: Int(sqlite3_column_int(statement, 1)),
                        description: String(cString: sqlite3_column_text(statement, 2)),
                        grams: sqlite3_column_double(statement, 3),
                        isDefault: sqlite3_column_int(statement, 4) == 1
                    )
                    servings.append(serving)
                }
            }
            
            sqlite3_finalize(statement)
        }
        return servings
    }
    
    func getDefaultServing(foodId: Int) -> LocalServing? {
        return getServings(foodId: foodId).first(where: { $0.isDefault }) ?? getServings(foodId: foodId).first
    }
    
    // MARK: - Main Integration Method
    
    /// CRITICAL: This method bridges to existing code - returns NutritionInfo (formatted strings)
    /// Uses scoring function to select best match and rejects poor matches to allow fallback
    func getNutritionForFood(_ foodName: String, amount: Double = 100, unit: String = "g") -> NutritionInfo? {
        // Search for food (searchFoods will wait for database)
        // Get multiple results to score them properly
        let foods = searchFoods(query: foodName, limit: 5)
        guard !foods.isEmpty else {
            print("🔍 LocalNutritionService: No match found for '\(foodName)'")
            return nil
        }
        
        // Score all results and select the best match
        let normalizedQuery = foodName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let scoredResults = foods.map { food -> (food: LocalFood, score: Int) in
            let score = calculateRelevanceScore(query: normalizedQuery, food: food)
            return (food: food, score: score)
        }
        
        // Sort by score descending and get the best match
        let sortedResults = scoredResults.sorted { $0.score > $1.score }
        guard let bestMatch = sortedResults.first else {
            print("🔍 LocalNutritionService: No valid match found for '\(foodName)'")
            return nil
        }
        
        // Minimum score threshold - reject poor matches to allow fallback to USDA/Spoonacular
        let minimumScore = 50
        if bestMatch.score < minimumScore {
            print("⚠️ LocalNutritionService: Best match score (\(bestMatch.score)) below threshold (\(minimumScore)) for '\(foodName)'")
            print("⚠️ LocalNutritionService: Best match was '\(bestMatch.food.name)' - rejecting to allow fallback")
            return nil
        }
        
        print("✅ LocalNutritionService: Selected best match '\(bestMatch.food.name)' with score \(bestMatch.score) for '\(foodName)'")
        
        // Convert amount to grams
        let amountInGrams = convertToGrams(amount: amount, unit: unit)
        
        // Sanity check: reasonable amounts (10g to 2000g)
        let clampedAmount = max(10, min(2000, amountInGrams))
        
        // Get nutrition per 100g
        guard let nutrition = getNutrition(foodId: bestMatch.food.id) else {
            print("⚠️ LocalNutritionService: No nutrition data for '\(foodName)' (ID: \(bestMatch.food.id))")
            return nil
        }
        
        // Scale to requested amount
        let scaledNutrition = nutrition.scaled(to: clampedAmount)
        
        // Convert to NutritionInfo format
        print("✅ LocalNutritionService: Found nutrition for '\(foodName)' via Local DB (Tier 0)")
        return scaledNutrition.toNutritionInfo()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
}

