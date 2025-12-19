import Foundation

struct QualityAnalysis: Codable {
    let organicPriority: OrganicPriority
    let contaminationRisk: ContaminationRisk
    let priceDifference: PriceDifference
    let worthItScore: Int
    let whyConsiderOrganic: [String]
    let whenToSaveMoney: [String]
    let smartShoppingTips: SmartShoppingTips
    let annualImpact: AnnualImpact
    let shouldDisplay: Bool
    
    enum OrganicPriority: String, Codable, CaseIterable {
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"
        
        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "yellow"
            case .low: return "gray"
            }
        }
        
        var emoji: String {
            switch self {
            case .high: return "🟢"
            case .medium: return "🟡"
            case .low: return "⚪"
            }
        }
    }
}

struct ContaminationRisk: Codable {
    let score: Int
    let explanation: String
    
    var warningSymbols: String {
        let symbols = ["⚠️", "⚠️", "⚠️", "⚠️", "⚠️"]
        return symbols.prefix(score).joined()
    }
}

struct PriceDifference: Codable {
    let amount: String
    let percentage: String
}

struct SmartShoppingTips: Codable {
    let best: String
    let good: String
    let acceptable: String
}

struct AnnualImpact: Codable {
    let costIncrease: String
    let healthBenefit: String
}
