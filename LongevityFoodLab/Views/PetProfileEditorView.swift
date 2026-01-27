import SwiftUI
import PhotosUI
import UIKit

struct PetProfileEditorView: View {
    @EnvironmentObject var petProfileStore: PetProfileStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedPetID: UUID?
    @State private var name: String = ""
    @State private var sex: PetProfile.Sex = .male
    @State private var ageYears: String = ""
    @State private var breed: String = ""
    @State private var selectedConditions: Set<String> = []
    @State private var imageData: Data?
    @State private var showingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    private let commonConditions = [
        "Allergies",
        "Sensitive stomach",
        "Weight management",
        "Joint support",
        "Skin/coat support",
        "Renal support",
        "Cardiac support",
        "Diabetes",
        "Pancreatitis",
        "Urinary support",
        "Low-fat diet"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                if !petProfileStore.pets.isEmpty {
                    Section(header: Text("Pets")) {
                        ForEach(petProfileStore.pets, id: \.id) { pet in
                            HStack {
                                Text(pet.name.isEmpty ? "Untitled Pet" : pet.name)
                                Spacer()
                                if pet.id == petProfileStore.activePetID {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                loadPet(pet)
                            }
                        }
                    }
                }
                
                Section(header: Text("Pet Details")) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.08))
                                .frame(height: 220)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            
                            if let imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 220)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .cornerRadius(16)
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                    Text("Add Pet Photo")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    TextField("Name", text: $name)
                    Picker("Sex", selection: $sex) {
                        Text("Male").tag(PetProfile.Sex.male)
                        Text("Female").tag(PetProfile.Sex.female)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    TextField("Age (years)", text: $ageYears)
                        .keyboardType(.numberPad)
                    TextField("Breed", text: $breed)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conditions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ConditionsGrid(items: commonConditions, selection: $selectedConditions)
                    }
                }
                
                Section {
                    Button(action: savePet) {
                        Text(selectedPetID == nil ? "Add Pet" : "Save Changes")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Pet Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) { _, newPhoto in
                Task {
                    if let newPhoto = newPhoto,
                       let data = try? await newPhoto.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            imageData = data
                        }
                    }
                }
            }
            .onAppear {
                if let active = petProfileStore.activePet {
                    loadPet(active)
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func loadPet(_ pet: PetProfile) {
        selectedPetID = pet.id
        name = pet.name
        sex = pet.sex ?? .male
        ageYears = pet.ageYears.map { "\($0)" } ?? ""
        breed = pet.breed ?? ""
        selectedConditions = Set(pet.conditions ?? [])
        imageData = pet.imageData
    }
    
    private func savePet() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        let conditions = Array(selectedConditions)
        
        let age = Int(ageYears.trimmingCharacters(in: .whitespacesAndNewlines))
        
        if let id = selectedPetID {
            var updated = PetProfile(
                id: id,
                name: trimmedName,
                species: petProfileStore.pets.first(where: { $0.id == id })?.species ?? .dog,
                imageData: imageData,
                sex: sex,
                ageYears: age,
                breed: breed.isEmpty ? nil : breed,
                conditions: conditions.isEmpty ? nil : conditions,
                createdAt: petProfileStore.pets.first(where: { $0.id == id })?.createdAt ?? Date()
            )
            petProfileStore.updatePet(updated)
            petProfileStore.setActivePet(id: id)
        } else {
            let newPet = PetProfile(
                id: UUID(),
                name: trimmedName,
                species: .dog,
                imageData: imageData,
                sex: sex,
                ageYears: age,
                breed: breed.isEmpty ? nil : breed,
                conditions: conditions.isEmpty ? nil : conditions,
                createdAt: Date()
            )
            petProfileStore.addPet(newPet)
            petProfileStore.setActivePet(id: newPet.id)
        }
        
        dismiss()
    }
}

// MARK: - Conditions Grid
private struct ConditionsGrid: View {
    let items: [String]
    @Binding var selection: Set<String>
    
    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 10)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection.contains(item)
                Text(item)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Color.blue.opacity(0.15) : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .onTapGesture {
                        if isSelected {
                            selection.remove(item)
                        } else {
                            selection.insert(item)
                        }
                    }
            }
        }
    }
}
