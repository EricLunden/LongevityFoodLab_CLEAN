import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo and styled text at the top (matching main screen header)
            VStack(spacing: 8) {
                // Logo Image
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 75)
                    .padding(.top, 0)
                
                VStack(spacing: 0) {
                    Text("LONGEVITY")
                        .font(.custom("Avenir-Light", size: 28))
                        .fontWeight(.light)
                        .tracking(6)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Rectangle()
                            .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                            .frame(width: 40, height: 1)
                        
                        Text("FOOD LAB")
                            .font(.custom("Avenir-Light", size: 14))
                            .tracking(4)
                            .foregroundColor(.secondary)
                        
                        Rectangle()
                            .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                            .frame(width: 40, height: 1)
                    }
                }
            }
            .padding(.vertical, 15)
            .padding(.top, -85)
            
            // Simple SwiftUI Animation
            ZStack {
                Circle()
                    .stroke(Color(red: 0.608, green: 0.827, blue: 0.835).opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color(red: 0.608, green: 0.827, blue: 0.835), lineWidth: 4)
                    .frame(width: 100, height: 100)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .frame(width: 200, height: 200)
            .padding(.top, 5)
            .onAppear {
                isAnimating = true
            }
            
            // Analyzing message
            VStack(spacing: 8) {
                Text("Analyzing...")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Just a sec while the Longevity Food Lab Research Engine goes to work!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

#Preview {
    LoadingView()
}
