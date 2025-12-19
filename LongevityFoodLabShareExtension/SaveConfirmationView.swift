import SwiftUI

struct SaveConfirmationView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay - 10% transparency to show saved recipe behind
            Color.black.opacity(0.1)
                .ignoresSafeArea(.all)
            
            // Confirmation popup - matching downloading screen design
            VStack(spacing: 0) {
                // Create a container for checkmark and text to center them together
                VStack(spacing: 15) {
                    // Checkmark matching button color - reduced weight
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Color(red: 65/255, green: 164/255, blue: 167/255))
                    
                    // Text - regular weight and larger box
                    Text("Saved to Longevity Food Lab")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    // OK Button - matching app style
                    Button(action: onDismiss) {
                        Text("OK")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                            .background(Color(red: 65/255, green: 164/255, blue: 167/255))
                            .cornerRadius(12)
                    }
                    .padding(.top, 10)
                }
            }
            .padding(30)
            .frame(width: 300, height: 250)
            .background(Color.black)
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
        }
    }
}

#Preview {
    SaveConfirmationView {
        print("Dismissed")
    }
}
