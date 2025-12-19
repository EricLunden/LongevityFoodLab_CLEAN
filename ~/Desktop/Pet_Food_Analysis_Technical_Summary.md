# Pet Food Analysis System - Technical Summary

## Overview
The Pet Food Analysis system is a comprehensive feature within the LongevityFoodLab iOS application that enables users to analyze pet food products (dogs and cats) for health and longevity metrics. The system uses AI-powered analysis via OpenAI's API, implements intelligent caching, and provides a rich UI for viewing, comparing, and managing pet food analyses.

---

## Architecture

### Core Components

1. **Data Models** (`PetFoodAnalysis.swift`)
2. **Cache Manager** (`PetFoodCacheManager.swift`)
3. **AI Service** (`AIService.swift`)
4. **UI Views** (Multiple SwiftUI views)
5. **Input Methods** (Voice, Manual Entry, Comparison)

---

## Data Models

### Primary Structure: `PetFoodAnalysis`

```swift
struct PetFoodAnalysis: Codable, Identifiable {
    var id: String { "\(petType.rawValue)_\(brandName)_\(productName)" }
    let petType: PetType                    // .dog or .cat
    let brandName: String
    let productName: String
    let overallScore: Int                   // 0-100
    let summary: String
    let healthScores: PetHealthScores
    let keyBenefits: [String]
    let ingredients: [PetFoodIngredient]
    let fillersAndConcerns: PetFoodFillersAndConcerns
    let bestPractices: PetFoodBestPractices
    let nutritionInfo: PetNutritionInfo
    let analysisDate: Date?
    let cacheKey: String?
    let cacheVersion: String?
    let suggestions: [PetFoodSuggestion]?
}
```

### Supporting Structures

#### `PetHealthScores`
Eight health metrics (0-100 scale):
- `digestiveHealth`
- `coatHealth`
- `jointHealth`
- `immuneHealth`
- `energyLevel`
- `weightManagement`
- `dentalHealth`
- `skinHealth`

#### `PetFoodIngredient`
```swift
struct PetFoodIngredient: Codable {
    let name: String
    let impact: String                    // "Positive/Negative/Neutral"
    let explanation: String
    let isBeneficial: Bool
}
```

#### `PetFoodFillersAndConcerns`
```swift
struct PetFoodFillersAndConcerns: Codable {
    let fillers: [PetFoodFiller]
    let potentialConcerns: [PetFoodConcern]
    let overallRisk: String
    let recommendations: String
}
```

#### `PetFoodBestPractices`
```swift
struct PetFoodBestPractices: Codable {
    let feedingGuidelines: String
    let portionSize: String
    let frequency: String
    let specialConsiderations: String
    let transitionTips: String
}
```

#### `PetNutritionInfo`
```swift
struct PetNutritionInfo: Codable {
    let protein: String
    let fat: String
    let carbohydrates: String
    let fiber: String
    let moisture: String
    let calories: String
    let omega3: String
    let omega6: String
}
```

### Cache Entry: `PetFoodCacheEntry`

```swift
struct PetFoodCacheEntry: Codable, Equatable, Identifiable {
    var id: String { cacheKey }
    let cacheKey: String
    let petType: PetFoodAnalysis.PetType
    let brandName: String
    let productName: String
    let analysisDate: Date
    let cacheVersion: String
    let fullAnalysis: PetFoodAnalysis
    
    var isExpired: Bool { /* 30-day expiration */ }
    var daysSinceAnalysis: Int
    var ageDescription: String
}
```

**Cache Expiration**: Entries expire after 30 days (`isExpired` computed property).

---

## API Integration

### Service: `AIService.getPetFoodAnalysis()`

**Method Signature:**
```swift
func getPetFoodAnalysis(
    petType: PetFoodAnalysis.PetType,
    productName: String
) async throws -> PetFoodAnalysis
```

**API Endpoint**: OpenAI GPT API (via `makeOpenAIRequestAsync()`)

**Request Flow:**
1. Constructs a detailed prompt with pet type and product name
2. Requests structured JSON response matching `PetFoodAnalysis` schema
3. Parses JSON response into `PetFoodAnalysis` object
4. Adds cache metadata (cacheKey, analysisDate, cacheVersion)
5. Returns complete analysis

**Prompt Structure:**
- Pet type specification (dog/cat)
- Product name
- Detailed JSON schema requirements
- Instructions for veterinary nutritional science-based analysis

**Response Format**: Strict JSON matching `PetFoodAnalysis` structure

**Error Handling**: Throws errors for invalid encoding or JSON parsing failures

---

## Caching System

### Manager: `PetFoodCacheManager`

**Singleton Pattern**: `static let shared = PetFoodCacheManager()`

**Key Features:**
- **Persistent Storage**: UserDefaults (key: `"PetFoodCache_v1.0"`)
- **Cache Size Limit**: Maximum 50 entries
- **Expiration**: 30-day TTL
- **Cache Version**: `v1.0`
- **Automatic Cleanup**: Expired entries removed on validation

**Core Methods:**

#### `getCachedAnalysis(for:productName:) -> PetFoodAnalysis?`
- Checks cache for non-expired entry
- Uses normalized cache key matching
- Returns `nil` if not found or expired

#### `cacheAnalysis(_ analysis: PetFoodAnalysis)`
- Creates `PetFoodCacheEntry` wrapper
- Removes existing entry with same cache key
- Adds new entry
- Sorts by most recent first
- Enforces 50-entry limit
- Persists to UserDefaults

#### `deleteAnalysis(withCacheKey:)`
- Removes entry by cache key
- Updates cache size
- Persists changes

#### `searchCachedAnalyses(query:) -> [PetFoodCacheEntry]`
- Normalizes query string
- Searches brand name and product name
- Case-insensitive matching
- Returns filtered array

#### `validateCacheIntegrity()`
- Validates all entries
- Removes invalid entries (empty fields, invalid scores, future dates, too old)
- Persists cleaned cache

**Cache Key Generation:**
```swift
static func generateCacheKey(petType: PetType, productName: String) -> String {
    let normalizedProduct = productName.lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "-", with: "_")
        .replacingOccurrences(of: ".", with: "")
        .replacingOccurrences(of: ",", with: "")
    
    return "\(petType.rawValue)_unknown_\(normalizedProduct)"
}
```

**Input Normalization:**
```swift
static func normalizeInput(_ input: String) -> String {
    return input.lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
}
```

---

## UI Components

### Main Views

#### 1. `PetFoodsView` (Main List/Grid View)
- **Purpose**: Display all cached pet food analyses
- **Features**:
  - List and grid view modes
  - Search functionality
  - Sort options (recency, score high-low, score low-high)
  - Edit mode with bulk deletion
  - "View More" pagination
- **State Management**: `@StateObject` for `PetFoodCacheManager`
- **Navigation**: Presents `PetFoodInputView` and `PetFoodCompareView` as sheets

#### 2. `PetFoodInputView` (Analysis Input)
- **Purpose**: Input pet food for analysis
- **Input Methods**:
  - Voice input (speech recognition)
  - Manual text entry
- **Pet Type Selection**: Dog/Cat picker
- **Cache Checking**: Real-time cache lookup as user types
- **Flow**: Input → Cache Check → API Call (if needed) → Results View

#### 3. `PetFoodResultsView` (Analysis Display)
- **Purpose**: Display detailed analysis results
- **Sections**:
  - Header with overall score
  - Health scores breakdown
  - Key benefits
  - Ingredients analysis
  - Fillers and concerns
  - Best practices
  - Nutrition info
  - Similar food suggestions
- **Cache Indicator**: Shows if result is from cache

#### 4. `PetFoodCompareView` (Comparison)
- **Purpose**: Compare two pet foods side-by-side
- **Features**:
  - Select from recently analyzed foods
  - Enter new foods for analysis
  - Parallel API calls for both foods
  - Cache-aware (uses cached if available)
- **Output**: `PetFoodComparisonResultsView`

#### 5. `PetFoodComparisonResultsView`
- **Purpose**: Side-by-side comparison display
- **Comparison Sections**:
  - Overall score comparison
  - Health scores comparison (8 metrics)
  - Key benefits comparison
  - Ingredients comparison
  - Best practices comparison
  - Nutrition comparison

### Supporting Views

- `PetFoodRowView`: Horizontal card for list view
- `PetFoodGridCard`: Grid card component
- `PetFoodScoreCircleCompact`: Score circle display
- `PetFoodCacheRow`: Cache entry row for comparison selection
- `SimplePetFoodSearchView`: Search popup modal

---

## Workflow & Data Flow

### Analysis Workflow

```
User Input (Voice/Manual)
    ↓
Normalize Input
    ↓
Check Cache (PetFoodCacheManager.getCachedAnalysis)
    ↓
[Cache Hit] → Display Results (PetFoodResultsView)
    ↓
[Cache Miss] → API Call (AIService.getPetFoodAnalysis)
    ↓
Parse JSON Response
    ↓
Create PetFoodAnalysis with Cache Metadata
    ↓
Cache Analysis (PetFoodCacheManager.cacheAnalysis)
    ↓
Display Results (PetFoodResultsView)
```

### Comparison Workflow

```
User Selects Food #1 & Food #2
    ↓
Check Cache for Both
    ↓
[Both Cached] → Show Comparison
    ↓
[One or Both Missing] → Parallel API Calls
    ↓
Cache New Analyses
    ↓
Show Comparison (PetFoodComparisonResultsView)
```

### Cache Management Flow

```
App Launch
    ↓
PetFoodCacheManager.loadFromPersistentStorage()
    ↓
Decode from UserDefaults
    ↓
Validate Cache Integrity
    ↓
Remove Expired/Invalid Entries
    ↓
Update Published Properties
    ↓
UI Updates via @Published
```

---

## Key Features

### 1. Intelligent Caching
- **30-day expiration**: Analyses expire after 30 days
- **Automatic cleanup**: Expired entries removed on validation
- **Size limit**: Maximum 50 cached analyses
- **Persistent storage**: Survives app restarts via UserDefaults
- **Cache-aware UI**: Shows cache status and age

### 2. Multiple Input Methods
- **Voice Input**: Speech recognition for hands-free entry
- **Manual Entry**: Text field for precise product names
- **Comparison Selection**: Tap-to-select from recently analyzed foods

### 3. Search & Filter
- **Real-time search**: Filters by brand name or product name
- **Case-insensitive**: Normalized matching
- **Sort options**: Recency, score (high-low), score (low-high)

### 4. Edit Mode
- **Bulk selection**: Select multiple foods for deletion
- **Visual indicators**: Selection circles in edit mode
- **Confirmation dialog**: Prevents accidental deletion

### 5. View Modes
- **List View**: Horizontal cards with detailed info
- **Grid View**: Compact cards for browsing
- **Auto-switch**: Grid view when >6 items

### 6. Comparison Feature
- **Side-by-side**: Visual comparison of two foods
- **Parallel processing**: Analyzes both foods simultaneously
- **Cache optimization**: Uses cached analyses when available

---

## Technical Details

### Concurrency
- **Async/Await**: All API calls use Swift concurrency
- **MainActor**: UI updates dispatched to main thread
- **Task Groups**: Parallel analysis for comparison feature

### State Management
- **ObservableObject**: `PetFoodCacheManager` uses `@Published` for reactive updates
- **@StateObject**: Views observe cache manager changes
- **@State**: Local view state for UI interactions

### Error Handling
- **Try/Catch**: API calls wrapped in error handling
- **User Feedback**: Error messages displayed to user
- **Graceful Degradation**: Cache fallback when API fails

### Performance Optimizations
- **Cache-first**: Always checks cache before API call
- **Normalized keys**: Consistent cache key generation
- **Lazy loading**: Pagination for large lists
- **Efficient filtering**: In-memory filtering for search

### Data Persistence
- **UserDefaults**: Simple key-value storage
- **JSON Encoding**: Codable protocol for serialization
- **Version Control**: Cache version tracking (`v1.0`)

### UI/UX Patterns
- **SwiftUI**: Modern declarative UI framework
- **Sheet Presentation**: Modal views for input/results
- **Navigation**: NavigationView for hierarchical navigation
- **Animations**: Smooth transitions and state changes

---

## File Structure

```
LongevityFoodLab/
├── Models/
│   └── PetFoodAnalysis.swift          # Data models
├── PetFoodCacheManager.swift          # Cache management
├── PetFoodInputView.swift             # Input interface
├── PetFoodResultsView.swift           # Results display
├── PetFoodsView.swift                 # Main list/grid view
├── PetFoodCompareView.swift            # Comparison interface
├── PetFoodComparisonResultsView.swift  # Comparison display
├── PetFoodManualEntryView.swift       # Manual entry view
├── PetFoodCompareManualEntryView.swift # Comparison manual entry
└── Views/
    └── AIService.swift                 # API integration
```

---

## API Response Schema

The system expects a JSON response matching this structure:

```json
{
  "petType": "dog" | "cat",
  "brandName": "string",
  "productName": "string",
  "overallScore": 0-100,
  "summary": "string",
  "healthScores": {
    "digestiveHealth": 0-100,
    "coatHealth": 0-100,
    "jointHealth": 0-100,
    "immuneHealth": 0-100,
    "energyLevel": 0-100,
    "weightManagement": 0-100,
    "dentalHealth": 0-100,
    "skinHealth": 0-100
  },
  "keyBenefits": ["string"],
  "ingredients": [
    {
      "name": "string",
      "impact": "string",
      "explanation": "string",
      "isBeneficial": boolean
    }
  ],
  "fillersAndConcerns": {
    "fillers": [
      {
        "name": "string",
        "description": "string",
        "whyUsed": "string",
        "impact": "string",
        "isConcerning": boolean
      }
    ],
    "potentialConcerns": [
      {
        "ingredient": "string",
        "concern": "string",
        "explanation": "string",
        "severity": "string",
        "alternatives": "string"
      }
    ],
    "overallRisk": "string",
    "recommendations": "string"
  },
  "bestPractices": {
    "feedingGuidelines": "string",
    "portionSize": "string",
    "frequency": "string",
    "specialConsiderations": "string",
    "transitionTips": "string"
  },
  "nutritionInfo": {
    "protein": "string",
    "fat": "string",
    "carbohydrates": "string",
    "fiber": "string",
    "moisture": "string",
    "calories": "string",
    "omega3": "string",
    "omega6": "string"
  },
  "suggestions": [
    {
      "brandName": "string",
      "productName": "string",
      "score": 0-100,
      "reason": "string",
      "keyBenefits": ["string"],
      "priceRange": "string",
      "availability": "string"
    }
  ]
}
```

---

## Dependencies

- **SwiftUI**: UI framework
- **Foundation**: Core data structures
- **Combine**: Reactive programming (via @Published)
- **OpenAI API**: AI analysis service
- **UserDefaults**: Persistent storage
- **Speech Framework**: Voice input (for voice mode)

---

## Future Considerations

1. **Migration to SwiftData**: Consider migrating from UserDefaults to SwiftData for better performance and relationships
2. **Cloud Sync**: Add iCloud sync for cross-device access
3. **Image Analysis**: Add ability to scan pet food labels
4. **Nutrition Database**: Integrate with pet nutrition databases for validation
5. **Batch Analysis**: Analyze multiple foods in one request
6. **Export/Share**: Allow exporting analyses as PDF or sharing
7. **Favorites**: Add favorites system for frequently referenced foods
8. **History**: Detailed analysis history with trends

---

## Notes for AI Reviewers

- **Cache Key Format**: `"{petType}_{brand}_{normalized_product}"` - brand defaults to "unknown" if not provided
- **Expiration Logic**: 30-day TTL calculated from `analysisDate`
- **Normalization**: All input is normalized (lowercase, trimmed, whitespace normalized) before cache lookup
- **Error Recovery**: System gracefully handles API failures and corrupted cache data
- **Thread Safety**: Cache operations should be performed on main thread (UI updates)
- **Memory Management**: Cache limit prevents unbounded growth
- **Versioning**: Cache version allows for future schema migrations

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**System Version**: v1.0

