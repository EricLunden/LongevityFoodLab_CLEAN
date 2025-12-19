import SwiftUI

struct SyncStatusView: View {
    @ObservedObject var iCloudManager: iCloudRecipeManager
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iCloudManager.syncStatus.icon)
                .foregroundColor(syncStatusColor)
                .font(.caption)
            
            Text(iCloudManager.syncStatus.displayText)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if iCloudManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemGray6))
        )
    }
    
    private var syncStatusColor: Color {
        switch iCloudManager.syncStatus {
        case .unknown:
            return .secondary
        case .syncing:
            return .blue
        case .available:
            return .green
        case .unavailable:
            return .orange
        case .error:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SyncStatusView(iCloudManager: iCloudRecipeManager.shared)
        
        // Preview different states
        HStack {
            Text("Available:")
            Image(systemName: "checkmark.icloud")
                .foregroundColor(.green)
            Text("Synced with iCloud")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        HStack {
            Text("Syncing:")
            Image(systemName: "icloud.and.arrow.up")
                .foregroundColor(.blue)
            Text("Syncing with iCloud...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        HStack {
            Text("Unavailable:")
            Image(systemName: "icloud.slash")
                .foregroundColor(.orange)
            Text("iCloud unavailable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .padding()
}
