import SwiftUI
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthProfileManager = UserHealthProfileManager.shared
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportDataFile: Data?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                exportHeader
                
                // Data Summary
                dataSummarySection
                
                // Export Options
                exportOptionsSection
                
                Spacer()
                
                // Export Button
                exportButton
            }
            .padding()
            .background(Color(.systemGray6))
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportDataFile {
                    ShareSheet(activityItems: [data])
                }
            }
        }
    }
    
    private var exportHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Export Your Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Download a copy of your health profile and app data")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var dataSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DataSummaryRow(
                    title: "Health Profile",
                    description: "Your personal health information and preferences",
                    isAvailable: healthProfileManager.currentProfile != nil
                )
                
                DataSummaryRow(
                    title: "Food Analysis History",
                    description: "Previously analyzed foods and recommendations",
                    isAvailable: true // We'll implement this in future phases
                )
                
                DataSummaryRow(
                    title: "App Preferences",
                    description: "Your app settings and preferences",
                    isAvailable: true
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Options")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ExportOptionRow(
                    title: "JSON Format",
                    description: "Machine-readable format for data portability",
                    icon: "doc.text"
                )
                
                ExportOptionRow(
                    title: "PDF Report",
                    description: "Human-readable summary of your health profile",
                    icon: "doc.richtext"
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var exportButton: some View {
        Button(action: exportData) {
            HStack {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.white)
                }
                
                Text(isExporting ? "Preparing Export..." : "Export Data")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
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
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .disabled(isExporting)
    }
    
    private func exportData() {
        isExporting = true
        
        // Create export data
        let exportInfo = createExportData()
        
        // Convert to JSON
        if let jsonData = try? JSONEncoder().encode(exportInfo) {
            exportDataFile = jsonData
            showingShareSheet = true
        }
        
        isExporting = false
    }
    
    private func createExportData() -> ExportData {
        let profile = healthProfileManager.currentProfile
        
        // Parse health goals and restrictions
        var healthGoals: [String] = []
        var foodRestrictions: [String] = []
        
        if let healthGoalsData = profile?.healthGoals?.data(using: .utf8),
           let goals = try? JSONDecoder().decode([String].self, from: healthGoalsData) {
            healthGoals = goals
        }
        
        if let restrictionsData = profile?.foodRestrictions?.data(using: .utf8),
           let restrictions = try? JSONDecoder().decode([String].self, from: restrictionsData) {
            foodRestrictions = restrictions
        }
        
        return ExportData(
            exportDate: Date(),
            appVersion: "1.0.0",
            healthProfile: HealthProfileExport(
                ageRange: profile?.ageRange,
                sex: profile?.sex,
                healthGoals: healthGoals,
                dietaryPreference: profile?.dietaryPreference,
                foodRestrictions: foodRestrictions,
                createdAt: profile?.createdAt,
                lastModified: profile?.lastModified
            ),
            appPreferences: AppPreferencesExport(
                dailyReminders: true, // Default values for now
                weeklyReports: true,
                notificationsEnabled: true
            )
        )
    }
}

// MARK: - Supporting Views

struct DataSummaryRow: View {
    let title: String
    let description: String
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isAvailable ? .green : .gray)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ExportOptionRow: View {
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export Data Models

struct ExportData: Codable {
    let exportDate: Date
    let appVersion: String
    let healthProfile: HealthProfileExport
    let appPreferences: AppPreferencesExport
}

struct HealthProfileExport: Codable {
    let ageRange: String?
    let sex: String?
    let healthGoals: [String]
    let dietaryPreference: String?
    let foodRestrictions: [String]
    let createdAt: Date?
    let lastModified: Date?
}

struct AppPreferencesExport: Codable {
    let dailyReminders: Bool
    let weeklyReports: Bool
    let notificationsEnabled: Bool
}

#Preview {
    DataExportView()
}
