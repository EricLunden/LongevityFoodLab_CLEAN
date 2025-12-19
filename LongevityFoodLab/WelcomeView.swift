import SwiftUI

struct WelcomeView: View {
    @State private var showingQuiz = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // App Logo
                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Text("Longevity Food Lab")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                // Welcome Content
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Welcome to Longevity Food Lab")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("Science-backed foods personalized for YOUR health")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Benefits
                    VStack(spacing: 16) {
                        BenefitRow(
                            icon: "heart.fill",
                            title: "Personalized Health Scores",
                            description: "Get food recommendations tailored to your specific health goals"
                        )
                        
                        BenefitRow(
                            icon: "brain.head.profile",
                            title: "Science-Based Analysis",
                            description: "Powered by AI and longevity research for accurate insights"
                        )
                        
                        BenefitRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Track Your Progress",
                            description: "Monitor your health journey with detailed analytics"
                        )
                    }
                }
                
                Spacer()
                
                // Set Up Button
                Button(action: {
                    showingQuiz = true
                }) {
                    HStack {
                        Text("Set Up My Profile")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color(hex: "10B981").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .padding()
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            HealthQuizView()
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color(hex: "10B981"))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    WelcomeView()
}
