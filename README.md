# Longevity Food Lab

An iOS app that analyzes foods for their longevity and health benefits using AI.

## Features

- **Food Analysis**: Get detailed health scores for any food
- **Image-Based Meal Logging**: Take photos of your meals for automatic food recognition and analysis
- **Health Metrics**: Heart health, brain health, anti-inflammation, joint health, eye health, and weight management scores
- **Nutritional Breakdown**: Detailed analysis of key ingredients and their impacts
- **Meal Scoring**: Overall meal longevity scores based on multiple foods
- **Best Practices**: Preparation and serving size recommendations
- **Modern UI**: Clean, intuitive interface with smooth animations

## Setup Instructions

### 1. API Key Configuration

Before running the app, you need to configure your Anthropic API key:

1. Open `LongevityFoodLab/Config.swift`
2. Replace `"YOUR_API_KEY_HERE"` with your actual Anthropic API key:
   ```swift
   static let anthropicAPIKey = "your-actual-api-key-here"
   ```

### 2. Build and Run

1. Open `LongevityFoodLab.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run the project (⌘+R)

## Architecture

- **SwiftUI**: Modern declarative UI framework
- **MVVM Pattern**: Clean separation of concerns
- **Network Layer**: Robust error handling with timeouts
- **Data Models**: Codable structs for type-safe data handling

## Files Structure

- `LongevityFoodLabApp.swift`: App entry point
- `ContentView.swift`: Main navigation controller with tab interface
- `SearchView.swift`: Food input and search interface
- `ResultsView.swift`: Detailed analysis results display
- `MealLogView.swift`: Image-based meal logging interface
- `MealResultsView.swift`: Multi-food meal analysis results
- `ImageAnalysisService.swift`: AI-powered food recognition service
- `ImagePicker.swift`: Camera and photo library picker
- `LoadingView.swift`: Loading animation component
- `AIService.swift`: API integration with Anthropic
- `FoodData.swift`: Data models (FoodAnalysis, HealthScores, Ingredient)
- `SecureConfig.swift`: Secure configuration constants

## Security Notes

- API keys should be stored securely in production
- Consider using environment variables or secure key storage
- Network requests include proper error handling and timeouts

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.3+
- Anthropic API access

## Troubleshooting

### Common Issues

1. **"Invalid response format" error**: Check your API key configuration
2. **Network timeout**: Verify internet connection and API key validity
3. **Build errors**: Ensure all files are included in the Xcode project

### API Key Issues

If you're getting API errors:
1. Verify your Anthropic API key is valid
2. Check your API usage limits
3. Ensure the API key has proper permissions

## Privacy

This app sends food names to Anthropic's API for analysis. No personal data is collected or stored locally. 