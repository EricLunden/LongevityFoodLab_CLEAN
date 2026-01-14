import Foundation

struct PetProfile: Identifiable, Codable, Equatable {
    enum Species: String, Codable, CaseIterable {
        case dog
        case cat
    }
    
    enum Sex: String, Codable, CaseIterable {
        case male
        case female
        case unknown
    }
    
    let id: UUID
    var name: String
    var species: Species
    var imageData: Data?
    var sex: Sex?
    var ageYears: Int?
    var breed: String?
    var conditions: [String]?
    var createdAt: Date
}
