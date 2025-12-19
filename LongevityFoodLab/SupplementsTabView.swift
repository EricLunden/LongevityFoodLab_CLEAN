//
//  SupplementsTabView.swift
//  LongevityFoodLab
//
//  Supplements screen - exact copy of Shop screen adapted for supplements
//

import SwiftUI

enum SupplementSortOption: String, CaseIterable {
    case allSupplements = "All Supplements"
    case mostRecent = "Most Recent"
    case highestScore = "Highest Score"
    case lowestScore = "Lowest Score"
    case alphabetical = "Alphabetical"
}

enum SupplementViewMode {
    case list
    case grid
}

struct SupplementsTabView: View {
    let onScanTapped: () -> Void
    @Binding var showingSideMenu: Bool
    @StateObject private var foodCacheManager = FoodCacheManager.shared
    @State private var viewMode: SupplementViewMode = .list
    @State private var sortOption: SupplementSortOption = .allSupplements
    @State private var isEditing = false
    @State private var selectedScanIDs: Set<String> = []
    @State private var showingDeleteConfirmation = false
    @State private var displayedScanCount = 6
    @State private var selectedAnalysisItem: AnalysisItem?
    @Environment(\.colorScheme) var colorScheme
    
    // Wrapper for sheet presentation
    private struct AnalysisItem: Identifiable {
        let id = UUID()
        let analysis: FoodAnalysis
    }
    
    // Filter supplement scans (supplement or supplement_facts)
    private var supplementScans: [FoodCacheEntry] {
        foodCacheManager.cachedAnalyses.filter { entry in
            entry.scanType == "supplement" || entry.scanType == "supplement_facts"
        }
    }
    
    // Sorted supplement scans
    private var sortedSupplementScans: [FoodCacheEntry] {
        let scans = supplementScans
        switch sortOption {
        case .allSupplements, .mostRecent:
            return scans.sorted { $0.analysisDate > $1.analysisDate }
        case .highestScore:
            return scans.sorted { $0.fullAnalysis.overallScore > $1.fullAnalysis.overallScore }
        case .lowestScore:
            return scans.sorted { $0.fullAnalysis.overallScore < $1.fullAnalysis.overallScore }
        case .alphabetical:
            return scans.sorted { $0.foodName < $1.foodName }
        }
    }
    
    // Scans to display
    private var scansToDisplay: [FoodCacheEntry] {
        let sorted = sortedSupplementScans
        if viewMode == .grid {
            return sorted
        } else {
            return Array(sorted.prefix(displayedScanCount))
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header - Horizontal Logo (centered)
                    Image("LogoHorizontal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 37)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.top, -8)
                    
                    // Supplements Box
                    VStack(spacing: 16) {
                        // Title with Icon (centered) - Button for scanning
                        Button(action: onScanTapped) {
                            VStack(spacing: 8) {
                                // Title with Icon (centered)
                                HStack(spacing: 12) {
                                    // Supplements Icon with Gradient (left of title) - reduced size
                                    Image(systemName: "pills.fill")
                                        .font(.system(size: 40, weight: .medium))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.purple, Color(red: 0.6, green: 0.2, blue: 0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                    
                                    Text("Supplements")
                                        .font(.system(size: 36, weight: colorScheme == .dark ? .bold : .heavy, design: .default))
                                        .foregroundColor(colorScheme == .dark ? .white : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Subtitle
                                Text("Tap here to scan supplement labels to get personalized analysis based on your health needs and goals")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Hairline separator
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                            .padding(.horizontal, -30) // Extend to box edges
                        
                        // Edit and All Supplements Dropdown (inside box at bottom)
                        HStack {
                            // Edit/Cancel/Delete Button (left) - only show in grid view
                            if viewMode == .grid {
                                Button(action: {
                                    if !selectedScanIDs.isEmpty {
                                        showingDeleteConfirmation = true
                                    } else {
                                        isEditing.toggle()
                                        if !isEditing {
                                            selectedScanIDs.removeAll()
                                        }
                                    }
                                }) {
                                    Text(editButtonText)
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            // All Supplements Dropdown (right)
                            Menu {
                                ForEach(SupplementSortOption.allCases, id: \.self) { option in
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
                        }
                        .padding(.horizontal, 10) // Padding for buttons within the box
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .padding(.horizontal, 30)
                    .background(Color.black)
                    .cornerRadius(16)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.15), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Recent Supplement Scans Section
                    if !supplementScans.isEmpty {
                        recentSupplementScansSection
                    }
                }
            }
        }
        .onAppear {
            // Cache is already loaded in FoodCacheManager.init()
            // Set default view mode based on count
            if supplementScans.count > 6 {
                viewMode = .grid
            } else {
                viewMode = .list
            }
        }
        .sheet(item: $selectedAnalysisItem) { item in
            ResultsView(
                analysis: item.analysis,
                onNewSearch: {
                    selectedAnalysisItem = nil
                },
                isSupplement: true,
                onMealAdded: {
                    selectedAnalysisItem = nil
                }
            )
        }
    }
    
    // MARK: - Recent Supplement Scans Section
    private var recentSupplementScansSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title with Toggle Icons and Sort Dropdown
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
                
                // Sort Dropdown (center) - between list and grid icons
                Menu {
                    ForEach(SupplementSortOption.allCases, id: \.self) { option in
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
            .padding(.top, 16)  // Increased padding above for easier tapping
            .padding(.bottom, 16)  // Increased padding below for easier tapping
            
            // Content: List or Grid
            if viewMode == .list {
                supplementScansListView
            } else {
                supplementScansGridView
            }
        }
        .padding(.horizontal, 0)
        .confirmationDialog("Delete Supplement Scans", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedScans()
            }
            Button("Cancel", role: .cancel) {
                // Deselect all items and exit edit mode
                selectedScanIDs.removeAll()
                isEditing = false
            }
        } message: {
            Text("Are you sure you want to delete \(selectedScanIDs.count) scan\(selectedScanIDs.count == 1 ? "" : "s")?")
        }
    }
    
    // MARK: - List View
    private var supplementScansListView: some View {
        VStack(spacing: 12) {
            LazyVStack(spacing: 12) {
                ForEach(scansToDisplay, id: \.cacheKey) { entry in
                    SupplementScanRowView(entry: entry, onTap: { analysis in
                        selectedAnalysisItem = AnalysisItem(analysis: analysis)
                    }, onDelete: { cacheKey in
                        foodCacheManager.deleteAnalysis(withCacheKey: cacheKey)
                    })
                }
            }
            .padding(.horizontal, 20)
            
            // View More/Show Less Buttons (only in list view)
            if supplementScans.count > 6 {
                HStack(spacing: 12) {
                    // Show Less button (only if showing more than 6)
                    if displayedScanCount > 6 {
                        Button(action: {
                            displayedScanCount = max(6, displayedScanCount - 6)
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
                    if supplementScans.count > displayedScanCount {
                        Button(action: {
                            displayedScanCount = min(displayedScanCount + 6, supplementScans.count)
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
    
    // MARK: - Grid View
    private var supplementScansGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(scansToDisplay, id: \.cacheKey) { entry in
                SupplementScanGridCard(
                    entry: entry,
                    isEditing: isEditing,
                    isSelected: selectedScanIDs.contains(entry.cacheKey),
                    onTap: {
                        selectedAnalysisItem = AnalysisItem(analysis: entry.fullAnalysis)
                    },
                    onToggleSelection: {
                        if selectedScanIDs.contains(entry.cacheKey) {
                            selectedScanIDs.remove(entry.cacheKey)
                        } else {
                            selectedScanIDs.insert(entry.cacheKey)
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
    
    // MARK: - Edit Button Text
    private var editButtonText: String {
        if !selectedScanIDs.isEmpty {
            return "Delete"
        } else if isEditing {
            return "Cancel"
        } else {
            return "Edit"
        }
    }
    
    // MARK: - Delete Selected Scans
    private func deleteSelectedScans() {
        for cacheKey in selectedScanIDs {
            foodCacheManager.deleteAnalysis(withCacheKey: cacheKey)
        }
        selectedScanIDs.removeAll()
        // Stay in edit mode after deletion
        isEditing = true
    }
}

