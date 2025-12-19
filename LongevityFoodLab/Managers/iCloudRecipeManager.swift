import Foundation
import SwiftUI
import CloudKit

// MARK: - iCloud Recipe Manager
class iCloudRecipeManager: ObservableObject {
    static let shared = iCloudRecipeManager()
    
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var lastError: RecipeError?
    @Published var syncStatus: SyncStatus = .unknown
    @Published var isiCloudAvailable = false
    
    // MARK: - Private Properties
    private let fileManager = FileManager.default
    private var memoryCache: [String: Recipe] = [:]
    private var analysisCache: [String: CachedAnalysis] = [:]
    private let fileCoordinator = NSFileCoordinator()
    private let cacheQueue = DispatchQueue(label: "recipe.icloud.queue", attributes: .concurrent)
    
    // iCloud Properties
    private var iCloudContainer: CKContainer?
    private var iCloudDatabase: CKDatabase?
    private var metadataQuery: NSMetadataQuery?
    private var isMonitoringiCloud = false
    
    // Directory paths
    private var iCloudDocumentsDirectory: URL? {
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) else { return nil }
        return iCloudURL.appendingPathComponent("Documents")
    }
    
    private var localDocumentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var recipesDirectory: URL {
        let baseDir = iCloudDocumentsDirectory ?? localDocumentsDirectory
        return baseDir.appendingPathComponent("Recipes")
    }
    
    private var recipeImagesBaseDirectory: URL {
        let baseDir = iCloudDocumentsDirectory ?? localDocumentsDirectory
        return baseDir.appendingPathComponent("RecipeImages")
    }
    
    private var analysisCacheDirectory: URL {
        let baseDir = iCloudDocumentsDirectory ?? localDocumentsDirectory
        return baseDir.appendingPathComponent("AnalysisCache")
    }
    
    private var tempDirectory: URL {
        let baseDir = iCloudDocumentsDirectory ?? localDocumentsDirectory
        return baseDir.appendingPathComponent("temp")
    }
    
    private var indexFileURL: URL {
        recipesDirectory.appendingPathComponent("index.json")
    }
    
    private var analysisCacheFileURL: URL {
        analysisCacheDirectory.appendingPathComponent("analysisCache.json")
    }
    
    // MARK: - Initialization
    private init() {
        setupDirectories()
        // setupiCloud() // Temporarily disabled to fix CFPreferences error
        
        // Load initial data asynchronously without blocking UI
        Task.detached { [weak self] in
            await self?.loadInitialData()
        }
    }
    
    // MARK: - iCloud Setup
    private func setupiCloud() {
        iCloudContainer = CKContainer.default()
        iCloudDatabase = iCloudContainer?.privateCloudDatabase
        
        // Setup metadata query for monitoring changes
        setupMetadataQuery()
        
        // Check iCloud availability asynchronously
        Task.detached { [weak self] in
            await self?.checkiCloudAvailability()
        }
    }
    
    private func checkiCloudAvailability() async {
        guard let container = iCloudContainer else {
            await MainActor.run {
                isiCloudAvailable = false
                syncStatus = .unavailable
            }
            return
        }
        
        do {
            // Add timeout to prevent hanging
            let status = try await withTimeout(seconds: 3) {
                try await container.accountStatus()
            }
            
            await MainActor.run {
                isiCloudAvailable = (status == .available)
                syncStatus = isiCloudAvailable ? .syncing : .unavailable
            }
        } catch {
            await MainActor.run {
                isiCloudAvailable = false
                syncStatus = .error
            }
        }
    }
    
    // Helper function for timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    
    private func setupMetadataQuery() {
        metadataQuery = NSMetadataQuery()
        metadataQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery?.predicate = NSPredicate(format: "%K BEGINSWITH %@", 
                                             NSMetadataItemPathKey, 
                                             recipesDirectory.path)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery
        )
    }
    
    @objc private func metadataQueryDidUpdate() {
        Task {
            await handleiCloudChanges()
        }
    }
    
    @objc private func metadataQueryDidFinishGathering() {
        Task {
            await handleiCloudChanges()
        }
    }
    
    private func handleiCloudChanges() async {
        guard let query = metadataQuery else { return }
        
        // Process changes from iCloud
        let results = query.results as? [NSMetadataItem] ?? []
        
        for item in results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            
            // Check if this is a recipe file
            if url.pathExtension == "json" && url.lastPathComponent != "index.json" {
                await processiCloudFile(url: url)
            }
        }
        
        // Reload all recipes
        await loadAllRecipes()
    }
    
    private func processiCloudFile(url: URL) async {
        // Download file if needed
        do {
            _ = try url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            
            // Check if file is downloaded
            let resourceValues = try url.resourceValues(forKeys: [.isUbiquitousItemKey])
            if resourceValues.isUbiquitousItem == true {
                // For iCloud files, we'll assume they're available
                // In a production app, you'd want to check download status more carefully
            }
            
            // Load and process the recipe
            let data = try Data(contentsOf: url)
            let recipe = try JSONDecoder().decode(Recipe.self, from: data)
            
            await MainActor.run {
                // Update memory cache
                memoryCache[recipe.id.uuidString] = recipe
            }
            
        } catch {
            print("❌ iCloudRecipeManager: Error processing iCloud file \(url): \(error)")
        }
    }
    
    // MARK: - Directory Setup
    private func setupDirectories() {
        let directories = [
            recipesDirectory,
            recipeImagesBaseDirectory,
            analysisCacheDirectory,
            tempDirectory
        ]
        
        for directory in directories {
            do {
                if !fileManager.fileExists(atPath: directory.path) {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                }
            } catch {
                print("❌ iCloudRecipeManager: Failed to create directory \(directory): \(error)")
                lastError = .saveFailed(error)
            }
        }
    }
    
    // MARK: - Recipe Operations
    
    /// Save a recipe to iCloud and local storage
    func saveRecipe(_ recipe: Recipe) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        let recipeURL = recipesDirectory.appendingPathComponent("recipe_\(recipe.id.uuidString).json")
        
        do {
            let data = try JSONEncoder().encode(recipe)
            
            // Use file coordinator for thread-safe operations
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                var error: NSError?
                fileCoordinator.coordinate(writingItemAt: recipeURL, options: .forReplacing, error: &error) { (url) in
                    do {
                        try data.write(to: url)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                if let error = error {
                    continuation.resume(throwing: error)
                }
            }
            
            // Update memory cache
            await MainActor.run {
                memoryCache[recipe.id.uuidString] = recipe
            }
            
            // Update index
            await updateRecipeIndex()
            
        } catch {
            await MainActor.run {
                lastError = .saveFailed(error)
            }
            throw error
        }
    }
    
    /// Load a recipe by ID
    func loadRecipe(id: String) async throws -> Recipe? {
        // Check memory cache first
        if let cachedRecipe = memoryCache[id] {
            return cachedRecipe
        }
        
        let recipeURL = recipesDirectory.appendingPathComponent("recipe_\(id).json")
        
        guard fileManager.fileExists(atPath: recipeURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: recipeURL)
            let recipe = try JSONDecoder().decode(Recipe.self, from: data)
            
            // Update memory cache
            await MainActor.run {
                memoryCache[id] = recipe
            }
            
            return recipe
        } catch {
            await MainActor.run {
                lastError = .loadFailed(error)
            }
            throw error
        }
    }
    
    /// Delete a recipe
    func deleteRecipe(id: String) async throws {
        let recipeURL = recipesDirectory.appendingPathComponent("recipe_\(id).json")
        
        do {
            try fileManager.removeItem(at: recipeURL)
            
            // Update memory cache
            await MainActor.run {
                memoryCache.removeValue(forKey: id)
            }
            
            // Update index
            await updateRecipeIndex()
            
        } catch {
            await MainActor.run {
                lastError = .deleteFailed(error)
            }
            throw error
        }
    }
    
    /// Load all recipes
    func loadAllRecipes() async {
        await MainActor.run { isLoading = true }
        defer { Task { await MainActor.run { isLoading = false } } }
        
        do {
            let indexData = try Data(contentsOf: indexFileURL)
            let recipeIndex = try JSONDecoder().decode([String].self, from: indexData)
            
            var loadedRecipes: [Recipe] = []
            
            for recipeId in recipeIndex {
                if let recipe = try await loadRecipe(id: recipeId) {
                    loadedRecipes.append(recipe)
                }
            }
            
            await MainActor.run { [loadedRecipes] in
                self.recipes = loadedRecipes
            }
            
        } catch {
            // If index doesn't exist, try to load from directory
            await loadRecipesFromDirectory()
        }
    }
    
    private func loadRecipesFromDirectory() async {
        do {
            let recipeFiles = try fileManager.contentsOfDirectory(at: recipesDirectory, 
                                                                includingPropertiesForKeys: nil, 
                                                                options: [])
                .filter { $0.pathExtension == "json" && !$0.lastPathComponent.contains("index") }
            
            var loadedRecipes: [Recipe] = []
            
            for fileURL in recipeFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                    loadedRecipes.append(recipe)
                } catch {
                    print("❌ iCloudRecipeManager: Error loading recipe from \(fileURL): \(error)")
                }
            }
            
            await MainActor.run { [loadedRecipes] in
                self.recipes = loadedRecipes
            }
            
            // Create index
            await updateRecipeIndex()
            
        } catch {
            await MainActor.run {
                lastError = .loadFailed(error)
            }
        }
    }
    
    private func updateRecipeIndex() async {
        let recipeIds = recipes.map { $0.id.uuidString }
        
        do {
            let indexData = try JSONEncoder().encode(recipeIds)
            try indexData.write(to: indexFileURL)
        } catch {
            print("❌ iCloudRecipeManager: Error updating recipe index: \(error)")
        }
    }
    
    // MARK: - Initial Data Loading
    private func loadInitialData() async {
        do {
            await loadAllRecipes()
            
            // Start monitoring iCloud changes
            if isiCloudAvailable && !isMonitoringiCloud {
                await startMonitoringiCloud()
            }
        } catch {
            await MainActor.run {
                self.lastError = .loadFailed(error)
                self.syncStatus = .error
            }
        }
    }
    
    private func startMonitoringiCloud() async {
        guard let query = metadataQuery else { return }
        
        query.start()
        isMonitoringiCloud = true
        
        await MainActor.run {
            syncStatus = .syncing
        }
    }
    
    // MARK: - Search and Filter
    func searchRecipes(query: String, category: RecipeCategory? = nil, minScore: Int? = nil) -> [Recipe] {
        var filteredRecipes = recipes
        
        if !query.isEmpty {
            filteredRecipes = filteredRecipes.filter { recipe in
                recipe.title.localizedCaseInsensitiveContains(query) ||
                recipe.description.localizedCaseInsensitiveContains(query) ||
                recipe.ingredients.contains { group in
                    group.ingredients.contains { ingredient in
                        ingredient.name.localizedCaseInsensitiveContains(query)
                    }
                }
            }
        }
        
        if let category = category {
            filteredRecipes = filteredRecipes.filter { $0.categories.contains(category) }
        }
        
        if let minScore = minScore {
            filteredRecipes = filteredRecipes.filter { recipe in
                guard let score = recipe.longevityScore else { return false }
                return score >= minScore
            }
        }
        
        return filteredRecipes
    }
    
    // MARK: - Analysis Cache
    func getCachedAnalysis(fingerprint: String) -> CachedAnalysis? {
        return analysisCache[fingerprint]
    }
    
    func cacheAnalysis(_ analysis: CachedAnalysis) {
        analysisCache[analysis.fingerprint] = analysis
    }
}

// MARK: - Timeout Error
struct TimeoutError: Error {}

// MARK: - Sync Status
enum SyncStatus {
    case unknown
    case syncing
    case available
    case unavailable
    case error
    
    var displayText: String {
        switch self {
        case .unknown: return "Checking sync status..."
        case .syncing: return "Syncing with iCloud..."
        case .available: return "Synced with iCloud"
        case .unavailable: return "iCloud unavailable"
        case .error: return "Sync error"
        }
    }
    
    var icon: String {
        switch self {
        case .unknown: return "icloud"
        case .syncing: return "icloud.and.arrow.up"
        case .available: return "checkmark.icloud"
        case .unavailable: return "icloud.slash"
        case .error: return "exclamationmark.icloud"
        }
    }
}
