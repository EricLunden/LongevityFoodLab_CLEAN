import Foundation
import Combine

class PetProfileStore: ObservableObject {
    @Published private(set) var pets: [PetProfile] = []
    @Published var activePetID: UUID? {
        didSet { persistState() }
    }
    
    var activePet: PetProfile? {
        guard let activePetID else { return nil }
        return pets.first(where: { $0.id == activePetID })
    }
    
    private let storageKey = "PetProfilesStorage"
    private let activePetKey = "PetProfilesActiveID"
    
    init() {
        loadState()
    }
    
    // MARK: - CRUD
    
    func addPet(_ pet: PetProfile) {
        pets.append(pet)
        if activePetID == nil {
            activePetID = pet.id
        }
        persistState()
    }
    
    func updatePet(_ pet: PetProfile) {
        guard let index = pets.firstIndex(where: { $0.id == pet.id }) else { return }
        pets[index] = pet
        persistState()
    }
    
    func deletePet(id: UUID) {
        pets.removeAll { $0.id == id }
        if activePetID == id {
            activePetID = pets.first?.id
        }
        persistState()
    }
    
    func setActivePet(id: UUID?) {
        activePetID = id
        persistState()
    }
    
    // MARK: - Persistence
    
    private func persistState() {
        do {
            let data = try JSONEncoder().encode(pets)
            UserDefaults.standard.set(data, forKey: storageKey)
            UserDefaults.standard.set(activePetID?.uuidString, forKey: activePetKey)
        } catch {
            print("❌ PetProfileStore: Failed to persist state: \(error)")
        }
    }
    
    private func loadState() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            if let decoded = try? JSONDecoder().decode([PetProfile].self, from: data) {
                pets = decoded
            }
        }
        
        if let activeIDString = UserDefaults.standard.string(forKey: activePetKey),
           let uuid = UUID(uuidString: activeIDString) {
            activePetID = uuid
        }
    }
}
