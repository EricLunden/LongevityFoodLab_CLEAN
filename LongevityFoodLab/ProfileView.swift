import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @EnvironmentObject var petProfileStore: PetProfileStore
    @State private var showingLogoutAlert = false
    @State private var showingProfileSettings = false
    @State private var showingDataExport = false
    @State private var showingPetProfileEditor = false
    @State private var showingImagePicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var refreshTrigger = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Logo Header
                    logoHeaderSection
                    
                    // Profile Header
                    profileHeader
                    
                    // Health Profile Section
                    healthProfileSection
                    
                    // Account Info
                    accountInfoSection
                    
                    // Preferences
                    preferencesSection
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .background(Color(.systemGray6))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Sign Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showingProfileSettings) {
                ProfileSettingsView()
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .sheet(isPresented: $showingPetProfileEditor) {
                PetProfileEditorView()
            }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { oldValue, newPhoto in
                Task {
                    if let newPhoto = newPhoto {
                        await loadImage(from: newPhoto)
                    }
                }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            Button(action: {
                showingImagePicker = true
            }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "10B981"), Color(hex: "14B8A6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)
                    
                    Group {
                        if let photoData = authManager.currentUser?.profilePhotoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Text(authManager.currentUser?.displayName.prefix(1).uppercased() ?? "U")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .id(refreshTrigger) // Force view refresh when photo changes
                    
                    // Add photo icon overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 28, height: 28)
                                )
                                .offset(x: 8, y: 8)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(spacing: 4) {
                if isEditingName {
                    HStack {
                        TextField("Enter name", text: $editedName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isNameFieldFocused)
                            .onSubmit {
                                saveName()
                            }
                        
                        Button("Save") {
                            saveName()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Button("Cancel") {
                            cancelEditing()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                } else {
                    HStack {
                        Text(authManager.currentUser?.name ?? "User")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Button(action: {
                            startEditing()
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Text(authManager.currentUser?.email ?? "user@example.com")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var healthProfileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Health Profile")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Edit") {
                    showingProfileSettings = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if let profile = healthProfileManager.currentProfile {
                VStack(spacing: 12) {
                    ProfileRow(
                        title: "Age Range",
                        value: profile.ageRange ?? "Not set"
                    )
                    ProfileRow(
                        title: "Sex",
                        value: profile.sex ?? "Not set"
                    )
                    ProfileRow(
                        title: "Dietary Preference",
                        value: profile.dietaryPreference ?? "Not set"
                    )
                    
                    // Health Goals
                    VStack(spacing: 8) {
                        Text("Health Goals")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if let healthGoalsData = profile.healthGoals?.data(using: .utf8),
                           let goals = try? JSONDecoder().decode([String].self, from: healthGoalsData) {
                            Text(goals.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Not set")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Food Restrictions
                    VStack(spacing: 8) {
                        Text("Food Restrictions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        if let restrictionsData = profile.foodRestrictions?.data(using: .utf8),
                           let restrictions = try? JSONDecoder().decode([String].self, from: restrictionsData) {
                            Text(restrictions.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("None")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Text("No health profile found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Create Health Profile") {
                        showingProfileSettings = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var accountInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ProfileRow(title: "Member Since", value: formatDate(authManager.currentUser?.joinDate))
                ProfileRow(title: "User ID", value: authManager.currentUser?.id ?? "N/A")
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                PreferenceRow(
                    title: "Daily Reminders",
                    subtitle: "Get reminded to log your meals",
                    isEnabled: authManager.currentUser?.preferences.dailyReminders ?? true
                )
                
                PreferenceRow(
                    title: "Weekly Reports",
                    subtitle: "Receive weekly longevity insights",
                    isEnabled: authManager.currentUser?.preferences.weeklyReports ?? true
                )
                
                PreferenceRow(
                    title: "Push Notifications",
                    subtitle: "Stay updated with app notifications",
                    isEnabled: authManager.currentUser?.preferences.notificationsEnabled ?? true
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingProfileSettings = true
            }) {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.blue)
                    Text("Edit Health Profile")
                        .foregroundColor(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
                )
            }
            
            Button(action: {
                showingPetProfileEditor = true
            }) {
                HStack {
                    Image(systemName: "pawprint.circle")
                        .foregroundColor(.orange)
                    Text("Edit Pet(s) Health Profile")
                        .foregroundColor(.orange)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
                )
            }
            
            Button(action: {
                showingDataExport = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.green)
                    Text("Export Data")
                        .foregroundColor(.green)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
                )
            }
            
            Button(action: {
                showingLogoutAlert = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Text("Sign Out")
                        .foregroundColor(.red)
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.6), lineWidth: 0.5)
                )
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func loadImage(from photo: PhotosPickerItem) async {
        do {
            if let data = try await photo.loadTransferable(type: Data.self) {
                await MainActor.run {
                    authManager.updateProfilePhoto(data)
                    // Force view refresh
                    refreshTrigger.toggle()
                }
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
    
    private func startEditing() {
        editedName = authManager.currentUser?.name ?? ""
        isEditingName = true
        isNameFieldFocused = true
    }
    
    private func saveName() {
        guard !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelEditing()
            return
        }
        
        authManager.updateUserName(editedName.trimmingCharacters(in: .whitespacesAndNewlines))
        isEditingName = false
        isNameFieldFocused = false
        refreshTrigger.toggle()
    }
    
    private func cancelEditing() {
        isEditingName = false
        isNameFieldFocused = false
        editedName = ""
    }
    
    private var logoHeaderSection: some View {
        VStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 75)
                .padding(.top, 10.0)
            
            VStack(spacing: 0) {
                Text("LONGEVITY")
                    .font(.system(size: 28, weight: .light, design: .default))
                    .tracking(6)
                    .foregroundColor(.primary)
                    .dynamicTypeSize(.large)
                
                HStack {
                    Rectangle()
                        .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                        .frame(width: 40, height: 1)
                    
                    Text("FOOD LAB")
                        .font(.system(size: 14, weight: .light, design: .default))
                        .tracking(4)
                        .foregroundColor(.secondary)
                        .dynamicTypeSize(.large)
                    
                    Rectangle()
                        .fill(Color(red: 0.608, green: 0.827, blue: 0.835))
                        .frame(width: 40, height: 1)
                }
            }
        }
        .padding(.vertical, 16)
    }
}

struct ProfileRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct PreferenceRow: View {
    let title: String
    let subtitle: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: .constant(isEnabled))
                .labelsHidden()
        }
    }
}


#Preview {
    ProfileView()
}