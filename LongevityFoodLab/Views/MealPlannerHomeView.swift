import SwiftUI

struct MealPlannerHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingSetup = false
    @State private var planMode: PlanMode = .auto
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 24) {
                    // Title
                    VStack(spacing: 8) {
                        Text("Meal Planner")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Longevity-optimized meals with minimal food waste")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    
                    // Card A: Auto Plan
                    StandardCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "bolt.heart.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.4, green: 0.2, blue: 0.8),  // Purple
                                                Color(red: 1.0, green: 0.6, blue: 0.0)  // Orange
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Build My Plan Automatically")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text("Optimized for longevity & ingredient reuse")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Button(action: {
                                planMode = .auto
                                showingSetup = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("Create Plan")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 29/255.0, green: 139/255.0, blue: 31/255.0),
                                            Color(red: 159/255.0, green: 169/255.0, blue: 13/255.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Card B: Manual Plan
                    StandardCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.grid.3x3")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.2, green: 0.4, blue: 1.0),  // Blue
                                                Color(red: 0.0, green: 0.8, blue: 0.8)   // Teal
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Build My Plan Manually")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text("Choose meals yourself")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Button(action: {
                                planMode = .manual
                                showingSetup = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("Build Manually")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                                .frame(maxWidth: .infinity)
                                .background(Color(red: 0.42, green: 0.557, blue: 0.498))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingSetup) {
            MealPlannerSetupView(planMode: planMode)
        }
    }
}

// MARK: - Standard Card Component
struct StandardCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color(red: 0.608, green: 0.827, blue: 0.835)
                            .opacity(colorScheme == .dark ? 1.0 : 0.6),
                        lineWidth: colorScheme == .dark ? 1.0 : 0.5
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

