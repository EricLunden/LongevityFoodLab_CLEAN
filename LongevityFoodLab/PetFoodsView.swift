import SwiftUI
import UIKit

enum PetFoodSortOption: String, CaseIterable {
    case recency = "Most Recent"
    case scoreHighLow = "Score: High to Low"
    case scoreLowHigh = "Score: Low to High"
}

enum PetFoodViewMode {
    case list
    case grid
}

struct PetFoodsView: View {
    @StateObject private var cacheManager = PetFoodCacheManager.shared
    @State private var showingNewAnalysis = false
    @State private var showingCompare = false
    @State private var searchText = ""
    @State private var searchQuery: String = ""
    @State private var selectedCachedAnalysis: PetFoodAnalysis? = nil
    @State private var sortOption: PetFoodSortOption = .recency
    @State private var viewMode: PetFoodViewMode = .list
    @State private var isEditing = false
    @State private var selectedFoodIDs: Set<String> = []
    @State private var showingDeleteConfirmation = false
    @State private var displayedFoodCount = 6
    @State private var showingSearch = false
    @State private var showingPetProfileEditor = false
    @EnvironmentObject var petProfileStore: PetProfileStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    private var pets: [PetProfile] { petProfileStore.pets }
    private var activePet: PetProfile? { petProfileStore.activePet }
    private var hasActivePetImage: Bool {
        guard let data = activePet?.imageData else { return false }
        return UIImage(data: data) != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Black background in dark mode
                if colorScheme == .dark {
                    Color.black.ignoresSafeArea()
                } else {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        if hasActivePetImage {
                            petHeaderSection
                        }
                        
                        petConditionsSummarySection
                        
                        managementBar
                        
                        // Score New and Compare Buttons
                        actionButtonsSection
                        
                        // Recently Analyzed Section (list/grid view like Score screen)
                        if !cacheManager.cachedAnalyses.isEmpty {
                            recentlyAnalyzedSection
                        } else {
                            emptyStateSection
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss() // Dismiss the sheet
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                print("🔍 PetFoodsView: onAppear - loading cache")
                cacheManager.loadFromPersistentStorage()
                print("🔍 PetFoodsView: Cache loaded - \(cacheManager.cachedAnalyses.count) analyses")
                print("🔍 PetFoodsView: Cache contents: \(cacheManager.cachedAnalyses.map { "\($0.productName) (\($0.cacheKey))" })")
                // Set default view mode based on count
                if cacheManager.cachedAnalyses.count > 6 {
                    viewMode = .grid
                } else {
                    viewMode = .list
                }
            }
            .confirmationDialog("Delete Pet Foods", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteSelectedFoods()
                }
                Button("Cancel", role: .cancel) {
                    selectedFoodIDs.removeAll()
                    isEditing = false
                }
            } message: {
                Text("Are you sure you want to delete \(selectedFoodIDs.count) food\(selectedFoodIDs.count == 1 ? "" : "s")?")
            }
            .sheet(isPresented: $showingNewAnalysis) {
                PetFoodInputView()
            }
            .sheet(isPresented: $showingCompare) {
                PetFoodCompareView()
            }
            .sheet(item: $selectedCachedAnalysis) { analysis in
                PetFoodResultsView(analysis: analysis, isFromCache: true)
            }
            .sheet(isPresented: $showingSearch) {
                SimplePetFoodSearchView { query in
                    searchQuery = query
                }
                .presentationBackground(.clear)
            }
            .sheet(isPresented: $showingPetProfileEditor) {
                PetProfileEditorView()
            }
        }
    }
    
    // MARK: - Logo Header Section
    @ViewBuilder
    private var petHeaderSection: some View {
        if activePet != nil {
            PetHeaderView(pet: activePet)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            guard pets.count > 1 else { return }
                            
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            let isHorizontal = abs(horizontal) > abs(vertical)
                            let threshold: CGFloat = 40
                            
                            guard isHorizontal, abs(horizontal) > threshold else { return }
                            
                            if horizontal < 0 {
                                activateNextPet()
                            } else {
                                activatePreviousPet()
                            }
                        }
                )
        }
    }
    
    // MARK: - Pet Conditions Summary
    @ViewBuilder
    private var petConditionsSummarySection: some View {
        if let pet = activePet {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Health Conditions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Edit") {
                        showingPetProfileEditor = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                
                if let conditions = pet.conditions, !conditions.isEmpty {
                    Text(conditions.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("No conditions set")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Management Bar (Edit/Delete + Search)
    private var managementBar: some View {
        HStack {
            Button(action: {
                if !selectedFoodIDs.isEmpty {
                    showingDeleteConfirmation = true
                } else {
                    isEditing.toggle()
                    if !isEditing {
                        selectedFoodIDs.removeAll()
                    }
                }
            }) {
                Text(editButtonText)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            if searchQuery.isEmpty {
                Button(action: {
                    showingSearch = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                        Text("Search")
                            .font(.subheadline)
                    }
                }
                .foregroundColor(.blue)
            } else {
                Button(action: {
                    searchQuery = ""
                }) {
                    Text("Clear Search")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    // MARK: - Action Buttons Section (below box)
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Score New Pet Food Button - Purple gradient
            Button(action: {
                showingNewAnalysis = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Score New Pet Food")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                            Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
                .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 8, x: 0, y: 2)
            }
            
            // Compare Pet Foods Button - Orange gradient (Type It)
            Button(action: {
                showingCompare = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.subheadline)
                    Text("Compare Pet Foods")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
                .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 8, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Filter by Pet Type")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(spacing: 12) {
                ForEach(PetFoodAnalysis.PetType.allCases, id: \.self) { petType in
                    Button(action: {
                        // This action is no longer needed as filtering is removed
                    }) {
                        HStack(spacing: 8) {
                            Text(petType.emoji)
                            Text(petType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(Color.primary) // No longer selected
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Color(UIColor.systemBackground) // No longer selected
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    Color.gray.opacity(0.3), // No longer selected
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Recently Analyzed Section
    private var recentlyAnalyzedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title with Toggle Icons and Dropdown (same as Score screen)
            HStack {
                // List Icon (flush left)
                Button(action: {
                    viewMode = .list
                }) {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .foregroundColor(viewMode == .list ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                }
                .padding(.leading, 20)
                
                Spacer()
                
                // Most Recent Dropdown (center)
                Menu {
                    ForEach(PetFoodSortOption.allCases, id: \.self) { option in
                        Button(action: {
                            sortOption = option
                        }) {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(sortOption.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Grid Icon (flush right)
                Button(action: {
                    viewMode = .grid
                }) {
                    Image(systemName: "square.grid.3x3")
                        .font(.title3)
                        .foregroundColor(viewMode == .grid ? Color(red: 0.42, green: 0.557, blue: 0.498) : .secondary)
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
            
            // Content: List or Grid
            if viewMode == .list {
                petFoodsListView
            } else {
                petFoodsGridView
            }
        }
        .padding(.horizontal, 0)
    }
    
    // MARK: - List View (matching score screen horizontal cards)
    private var petFoodsListView: some View {
        VStack(spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(foodsToDisplay, id: \.cacheKey) { entry in
                    PetFoodRowView(
                        entry: entry,
                        isEditing: isEditing,
                        isSelected: selectedFoodIDs.contains(entry.cacheKey),
                        onTap: {
                            if isEditing {
                                // Toggle selection in edit mode
                                if selectedFoodIDs.contains(entry.cacheKey) {
                                    selectedFoodIDs.remove(entry.cacheKey)
                                } else {
                                    selectedFoodIDs.insert(entry.cacheKey)
                                }
                            } else {
                                print("🔍 PetFoodsView: Tapping on cached analysis for \(entry.brandName)")
                                selectedCachedAnalysis = entry.fullAnalysis
                                print("🔍 PetFoodsView: selectedCachedAnalysis set to: \(entry.brandName)")
                            }
                        },
                        onDelete: { cacheKey in
                            cacheManager.deleteAnalysis(withCacheKey: cacheKey)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            // View More/Show Less Buttons (only in list view)
            if cacheManager.cachedAnalyses.count > 6 {
                HStack(spacing: 12) {
                    // Show Less button (only if showing more than 6)
                    if displayedFoodCount > 6 {
                        Button(action: {
                            displayedFoodCount = max(6, displayedFoodCount - 6)
                        }) {
                            Text("Show Less")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                            Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                        }
                    }
                    
                    // View More button (only if more items available)
                    if cacheManager.cachedAnalyses.count > displayedFoodCount {
                        Button(action: {
                            displayedFoodCount = min(displayedFoodCount + 6, cacheManager.cachedAnalyses.count)
                        }) {
                            Text("View More")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                            Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
    
    // MARK: - Grid View (2x2 like favorites)
    private var petFoodsGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(foodsToDisplay, id: \.cacheKey) { entry in
                PetFoodGridCard(
                    entry: entry,
                    isEditing: isEditing,
                    isSelected: selectedFoodIDs.contains(entry.cacheKey),
                    onTap: {
                        if isEditing {
                            // Toggle selection in edit mode
                            if selectedFoodIDs.contains(entry.cacheKey) {
                                selectedFoodIDs.remove(entry.cacheKey)
                            } else {
                                selectedFoodIDs.insert(entry.cacheKey)
                            }
                        } else {
                            print("🔍 PetFoodsView: Tapping on cached analysis for \(entry.brandName)")
                            selectedCachedAnalysis = entry.fullAnalysis
                            print("🔍 PetFoodsView: selectedCachedAnalysis set to: \(entry.brandName)")
                        }
                    },
                    onToggleSelection: {
                        if selectedFoodIDs.contains(entry.cacheKey) {
                            selectedFoodIDs.remove(entry.cacheKey)
                        } else {
                            selectedFoodIDs.insert(entry.cacheKey)
                        }
                    },
                    scoreCircleSize: 56
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }
    
    // MARK: - Empty State Section
    @ViewBuilder
    private var emptyStateSection: some View {
        // Show different message if searching vs no foods
        if !searchQuery.isEmpty && filteredAnalyses.isEmpty {
            // Search results empty
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("No Search Results")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Try a different search term.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
        } else {
            // No foods at all
            VStack(spacing: 16) {
                Text("🐾")
                    .font(.system(size: 60))
                
                VStack(spacing: 8) {
                    Text("No Pet Foods Analyzed Yet")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Start by analyzing your first pet food to see how it scores for health and longevity.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Computed Properties
    private var filteredAnalyses: [PetFoodCacheEntry] {
        var analyses = cacheManager.cachedAnalyses
        
        // Filter by search query if provided
        if !searchQuery.isEmpty {
            analyses = cacheManager.searchCachedAnalyses(query: searchQuery)
        }
        
        // Apply sorting
        return getSortedPetFoods(from: analyses)
    }
    
    private var foodsToDisplay: [PetFoodCacheEntry] {
        let sorted = filteredAnalyses
        if viewMode == .list {
            // List view: limit to displayedFoodCount (for View More/Show Less)
            return Array(sorted.prefix(displayedFoodCount))
        } else {
            // Grid view: show all items (matching Score screen behavior)
            return sorted
        }
    }
    
    // MARK: - Sorting Logic
    private func getSortedPetFoods(from analyses: [PetFoodCacheEntry]) -> [PetFoodCacheEntry] {
        switch sortOption {
        case .recency:
            return analyses.sorted { $0.analysisDate > $1.analysisDate }
        case .scoreHighLow:
            return analyses.sorted { $0.fullAnalysis.overallScore > $1.fullAnalysis.overallScore }
        case .scoreLowHigh:
            return analyses.sorted { $0.fullAnalysis.overallScore < $1.fullAnalysis.overallScore }
        }
    }
    
    // MARK: - Pet Switching
    private func activateNextPet() {
        guard pets.count > 1 else { return }
        guard let currentID = activePet?.id,
              let currentIndex = pets.firstIndex(where: { $0.id == currentID }) else {
            petProfileStore.setActivePet(id: pets.first?.id)
            return
        }
        
        let nextIndex = (currentIndex + 1) % pets.count
        petProfileStore.setActivePet(id: pets[nextIndex].id)
    }
    
    private func activatePreviousPet() {
        guard pets.count > 1 else { return }
        guard let currentID = activePet?.id,
              let currentIndex = pets.firstIndex(where: { $0.id == currentID }) else {
            petProfileStore.setActivePet(id: pets.first?.id)
            return
        }
        
        let previousIndex = (currentIndex - 1 + pets.count) % pets.count
        petProfileStore.setActivePet(id: pets[previousIndex].id)
    }
    
    // MARK: - Edit Button Text
    private var editButtonText: String {
        if !selectedFoodIDs.isEmpty {
            return "Delete"
        } else if isEditing {
            return "Cancel"
        } else {
            return "Edit"
        }
    }
    
    // MARK: - Delete Selected Foods
    private func deleteSelectedFoods() {
        for cacheKey in selectedFoodIDs {
            cacheManager.deleteAnalysis(withCacheKey: cacheKey)
        }
        selectedFoodIDs.removeAll()
        // Stay in edit mode after deletion
        isEditing = true
    }
}

// MARK: - Pet Food Row View (horizontal card matching score screen)
struct PetFoodRowView: View {
    let entry: PetFoodCacheEntry
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: (String) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ZStack {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Pet Food Image Placeholder with Pet Icon
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.black : Color(.systemGray6))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .overlay(
                            // Green hairline border in dark mode only
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 0.5)
                                .opacity(colorScheme == .dark ? 1.0 : 0.0)
                        )
                    
                    // Product Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.brandName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(entry.productName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Score Circle
                    PetFoodScoreCircleCompact(score: entry.fullAnalysis.overallScore)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(colorScheme == .dark ? Color.black : Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.42, green: 0.557, blue: 0.498), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Top Right Corner: Selection Circle (when editing) or Delete Button (when not editing)
            VStack {
                HStack {
                    Spacer()
                    if isEditing {
                        // Selection Circle - same position as X button
                        Circle()
                            .fill(isSelected ? Color.red : Color.white)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(isSelected ? .white : .black)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(.top, -8)
                            .padding(.trailing, -8)
                    } else {
                        // Delete Button - X button
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                                .foregroundColor(colorScheme == .dark ? Color(.lightGray) : Color(red: 0.42, green: 0.557, blue: 0.498))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, -8)
                        .padding(.trailing, -8)
                    }
                }
                Spacer()
            }
            .zIndex(1)
            .allowsHitTesting(true)
        }
        .confirmationDialog("Delete Pet Food", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete(entry.cacheKey)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(entry.brandName) \(entry.productName)'?")
        }
    }
}

// MARK: - Pet Food Score Circle Compact
struct PetFoodScoreCircleCompact: View {
    let score: Int
    
    var body: some View {
        ZStack {
            // Background circle with gradient (red to green based on score)
            Circle()
                .fill(scoreGradient(score))
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
            
            // Score number and one-word summary (white text - reverse type)
            VStack(spacing: -4) {
                Text("\(score)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(scoreLabel(score).uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 90...100: return "Exceptional"
        case 80...89: return "Excellent"
        case 70...79: return "Very Good"
        case 60...69: return "Good"
        case 50...59: return "Moderate"
        case 40...49: return "Fair"
        default: return "Limited"
        }
    }
    
    private func scoreGradient(_ score: Int) -> LinearGradient {
        let progress = CGFloat(score) / 100.0
        
        let startColor: Color
        let endColor: Color
        
        if progress <= 0.4 {
            startColor = Color(red: 0.8, green: 0.1, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.4, blue: 0.1)
        } else if progress <= 0.6 {
            startColor = Color(red: 0.9, green: 0.5, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.7, blue: 0.2)
        } else if progress <= 0.8 {
            startColor = Color(red: 0.8, green: 0.7, blue: 0.2)
            endColor = Color(red: 0.4, green: 0.7, blue: 0.4)
        } else {
            startColor = Color(red: 0.3, green: 0.6, blue: 0.3)
            endColor = Color(red: 0.2, green: 0.5, blue: 0.2)
        }
        
        return LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Pet Food Grid Card (2x2 matching favorites)
struct PetFoodGridCard: View {
    let entry: PetFoodCacheEntry
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void
    let scoreCircleSize: CGFloat
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(entry: PetFoodCacheEntry, isEditing: Bool, isSelected: Bool, onTap: @escaping () -> Void, onToggleSelection: @escaping () -> Void, scoreCircleSize: CGFloat = 28) {
        self.entry = entry
        self.isEditing = isEditing
        self.isSelected = isSelected
        self.onTap = onTap
        self.onToggleSelection = onToggleSelection
        self.scoreCircleSize = scoreCircleSize
    }
    
    var body: some View {
        Button(action: {
            if isEditing {
                onToggleSelection()
            } else {
                onTap()
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                // Square Image with Score Circle Overlay
                GeometryReader { geometry in
                    ZStack(alignment: .bottomTrailing) {
                        // Pet Food Image Placeholder - black box with gradient pet icon
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.black : Color(.systemGray6))
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .overlay(
                                Image(systemName: "pawprint.fill")
                                    .font(.system(size: geometry.size.width * 0.3, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.orange, Color(red: 1.0, green: 0.6, blue: 0.0)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .overlay(
                                // Green hairline border in dark mode only
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(Color.green, lineWidth: 0.5)
                                    .opacity(colorScheme == .dark ? 1.0 : 0.0)
                            )
                        
                        // Score Circle (number only, no text) - lower right corner
                        Circle()
                            .fill(scoreGradient(entry.fullAnalysis.overallScore))
                            .frame(width: scoreCircleSize, height: scoreCircleSize)
                            .overlay(
                                Text("\(entry.fullAnalysis.overallScore)")
                                    .font(.system(size: scoreCircleSize == 56 ? 20 : 12, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                            .padding(4)
                        
                        // Selection Circle (when editing) - top right corner
                        if isEditing {
                            VStack {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .fill(isSelected ? Color.red : Color.white)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(isSelected ? .white : .black)
                                        )
                                }
                                Spacer()
                            }
                            .padding(4)
                            .allowsHitTesting(false)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                
                // Product Title (max 2 lines)
                Text("\(entry.brandName) \(entry.productName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 28, alignment: .topLeading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func scoreGradient(_ score: Int) -> LinearGradient {
        let progress = CGFloat(score) / 100.0
        
        let startColor: Color
        let endColor: Color
        
        if progress <= 0.4 {
            startColor = Color(red: 0.8, green: 0.1, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.4, blue: 0.1)
        } else if progress <= 0.6 {
            startColor = Color(red: 0.9, green: 0.5, blue: 0.1)
            endColor = Color(red: 0.9, green: 0.7, blue: 0.2)
        } else if progress <= 0.8 {
            startColor = Color(red: 0.8, green: 0.7, blue: 0.2)
            endColor = Color(red: 0.4, green: 0.7, blue: 0.4)
        } else {
            startColor = Color(red: 0.3, green: 0.6, blue: 0.3)
            endColor = Color(red: 0.2, green: 0.5, blue: 0.2)
        }
        
        return LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Pet Food Cache Row (kept for backward compatibility if needed)
struct PetFoodCacheRow: View {
    let entry: PetFoodCacheEntry
    let onTap: () -> Void
    let onDelete: (String) -> Void
    let isSelected: Bool
    
    @State private var showingDeleteConfirmation = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Button(action: onTap) {
                VStack(spacing: 12) {
                    // Pet Type Icon
                    Text(entry.petType.emoji)
                        .font(.title)
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(25)
                    
                    // Food Info
                    VStack(spacing: 6) {
                        Text(entry.brandName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text(entry.productName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Text("Analyzed \(entry.ageDescription)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Score Badge
                    VStack(spacing: 4) {
                        Text("\(entry.fullAnalysis.overallScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                        
                        Text("Score")
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? .black.opacity(0.8) : .white.opacity(0.8))
                    }
                    .frame(width: 80, height: 80)
                    .background(scoreColor(entry.fullAnalysis.overallScore))
                    .cornerRadius(40)
                }
                .frame(width: 140, height: 220)
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Delete Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(Color(red: 0.42, green: 0.557, blue: 0.498))
                            .padding(8)
                    }
                }
                Spacer()
            }
            
            // Selection Check Mark
            if isSelected {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .background(Color.white)
                            .clipShape(Circle())
                            .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .alert("Delete?", isPresented: $showingDeleteConfirmation) {
            Button("Yes", role: .destructive) {
                onDelete(entry.cacheKey)
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this analysis?")
        }
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60...79:
            return .orange
        case 40...59:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Simple Pet Food Search View (Popup)
struct SimplePetFoodSearchView: View {
    let onSearch: (String) -> Void
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Fully transparent background so pet foods show through
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
            
            // Green bordered box with all content inside
            VStack(spacing: 20) {
                Text("Search Pet Foods")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                TextField("Enter search term...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 20)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onSubmit {
                        if !searchText.isEmpty {
                            onSearch(searchText)
                            dismiss()
                        }
                    }
                
                HStack(spacing: 12) {
                    Button(action: {
                        onSearch("")
                        dismiss()
                    }) {
                        Text("Clear")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        onSearch(searchText)
                        dismiss()
                    }) {
                        Text("Search")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),  // Green #1D8B1F
                                        Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)  // Yellow-green #9FA90D
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                    }
                    .disabled(searchText.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 320)
            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(red: 0.42, green: 0.557, blue: 0.498), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
}
