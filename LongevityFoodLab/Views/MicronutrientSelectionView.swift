//
//  MicronutrientSelectionView.swift
//  LongevityFoodLab
//
//  View for selecting which micronutrients to track
//

import SwiftUI

struct MicronutrientSelectionView: View {
    @Binding var selectedMicronutrients: Set<String>
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private let allMicronutrients = [
        "Vitamin D", "Vitamin E", "Potassium", "Vitamin K", "Magnesium",
        "Vitamin A", "Calcium", "Vitamin C", "Choline", "Iron",
        "Iodine", "Zinc", "Folate (B9)", "Vitamin B12", "Vitamin B6",
        "Selenium", "Copper", "Manganese", "Thiamin (B1)"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select which micronutrients you want to track")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(allMicronutrients, id: \.self) { micro in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Button(action: {
                                        if selectedMicronutrients.contains(micro) {
                                            selectedMicronutrients.remove(micro)
                                        } else {
                                            selectedMicronutrients.insert(micro)
                                        }
                                    }) {
                                        Image(systemName: selectedMicronutrients.contains(micro) ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 20))
                                            .foregroundColor(selectedMicronutrients.contains(micro) ? .blue : .secondary)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Text(micro)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                                
                                // Benefit description
                                Text(getMicronutrientBenefits(for: micro))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.leading, 32) // Align with text above (checkbox + spacing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Select Micronutrients")
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
    
    // MARK: - Micronutrient Benefits Helper
    private func getMicronutrientBenefits(for name: String) -> String {
        switch name {
        case "Vitamin D":
            return "For bones, immunity, mood"
        case "Vitamin E":
            return "For skin, antioxidant, circulation"
        case "Potassium":
            return "For heart, blood pressure, muscles"
        case "Vitamin K":
            return "For blood clotting, bones, heart"
        case "Magnesium":
            return "For muscles, sleep, energy"
        case "Vitamin A":
            return "For vision, skin, immunity"
        case "Calcium":
            return "For bones, teeth, muscles"
        case "Vitamin C":
            return "For immunity, skin, antioxidant"
        case "Choline":
            return "For brain, memory, liver"
        case "Iron":
            return "For energy, blood, oxygen"
        case "Iodine":
            return "For thyroid, metabolism, growth"
        case "Zinc":
            return "For immunity, healing, growth"
        case "Folate (B9)":
            return "For DNA, red blood cells, pregnancy"
        case "Vitamin B12":
            return "For energy, nerves, red blood cells"
        case "Vitamin B6":
            return "For metabolism, brain, mood"
        case "Selenium":
            return "For antioxidant, thyroid, immunity"
        case "Copper":
            return "For energy, bones, immunity"
        case "Manganese":
            return "For bones, metabolism, antioxidant"
        case "Thiamin (B1)":
            return "For energy, nerves, heart"
        default:
            return ""
        }
    }
}

