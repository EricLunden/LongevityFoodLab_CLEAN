//
//  MacroSelectionView.swift
//  LongevityFoodLab
//
//  View for selecting which macros to track
//

import SwiftUI

struct MacroSelectionView: View {
    @Binding var selectedMacros: Set<String>
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let allMacros = [
        "Kcal",
        "Protein",
        "Carbs",
        "Fat",
        "Fiber",
        "Sugar",
        "Sodium"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which macros you want to track")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    VStack(spacing: 12) {
                        ForEach(allMacros, id: \.self) { macro in
                            HStack {
                                Button(action: {
                                    if selectedMacros.contains(macro) {
                                        selectedMacros.remove(macro)
                                    } else {
                                        selectedMacros.insert(macro)
                                    }
                                }) {
                                    Image(systemName: selectedMacros.contains(macro) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedMacros.contains(macro) ? .blue : .secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Text(macro)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Select Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

