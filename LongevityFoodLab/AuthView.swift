import SwiftUI

struct AuthView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background image
                Image("authBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea()
                
                // Optional: Overlay for better text readability
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo and header (same as home screen)
                    VStack(spacing: 8) {
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
                                .foregroundColor(.white)
                            
                            HStack {
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 40, height: 1)
                                
                                Text("FOOD LAB")
                                    .font(.custom("Avenir-Light", size: 14))
                                    .tracking(4)
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Rectangle()
                                    .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                                    .frame(width: 40, height: 1)
                            }
                        }
                    }
                    .padding(.vertical, 15)
                    .padding(.top, 60)
                    
                    Spacer()
                        .frame(height: 0)
                    
                    // Centered Auth form section
                    VStack(spacing: 20) {
                        // Toggle between login and signup
                        HStack(spacing: 0) {
                            Button(action: { isLogin = true }) {
                                Text("Sign In")
                                    .font(.headline)
                                    .foregroundColor(isLogin ? .white : .white.opacity(0.7))
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        isLogin ? Color.white.opacity(0.2) : Color.clear
                                    )
                                    .cornerRadius(12)
                            }
                            
                            Button(action: { isLogin = false }) {
                                Text("Sign Up")
                                    .font(.headline)
                                    .foregroundColor(!isLogin ? .white : .white.opacity(0.7))
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        !isLogin ? Color.white.opacity(0.2) : Color.clear
                                    )
                                    .cornerRadius(12)
                            }
                        }
                        .background(Color.white.opacity(0.25))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        
                        // Form fields
                        VStack(spacing: 16) {
                            if !isLogin {
                                // Name field for signup
                                AuthTextField(
                                    text: $name,
                                    placeholder: "Full Name",
                                    icon: "person.fill"
                                )
                            }
                            
                            AuthTextField(
                                text: $email,
                                placeholder: "Email",
                                icon: "envelope.fill",
                                keyboardType: .emailAddress
                            )
                            
                            AuthTextField(
                                text: $password,
                                placeholder: "Password",
                                icon: "lock.fill",
                                isSecure: true
                            )
                            
                            if !isLogin {
                                AuthTextField(
                                    text: $confirmPassword,
                                    placeholder: "Confirm Password",
                                    icon: "lock.fill",
                                    isSecure: true
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Action button
                        Button(action: handleAuthAction) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(isLogin ? "Sign In" : "Create Account")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                                                    .background(
                            isFormValid ? Color.white.opacity(0.4) : Color.white.opacity(0.25)
                        )
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || authManager.isLoading)
                        .padding(.horizontal, 20)
                        
                        // Forgot password (login only)
                        if isLogin {
                            Button("Forgot Password?") {
                                // Handle forgot password
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 40)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                }
            }
        }
        .alert("Authentication", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .fullScreenCover(isPresented: $authManager.isAuthenticated) {
            ContentView()
        }
    }
    
    private var isFormValid: Bool {
        if isLogin {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !name.isEmpty && !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
        }
    }
    
    private func handleAuthAction() {
        // Validate passwords match for signup
        if !isLogin && password != confirmPassword {
            alertMessage = "Passwords don't match"
            showAlert = true
            return
        }
        
        Task {
            do {
                if isLogin {
                    // Handle login
                    _ = try await authManager.login(email: email, password: password)
                } else {
                    // Handle signup
                    _ = try await authManager.signup(name: name, email: email, password: password)
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct AuthTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.black.opacity(0.7))
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
        }
        .foregroundColor(.black)
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView()
} 