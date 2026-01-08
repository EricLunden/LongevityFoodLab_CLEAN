import Foundation

/// Represents a single research citation with verification requirements
struct ResearchCitation: Codable, Identifiable, Equatable {
    let id: UUID
    let ingredient: String
    let nutrient: String
    let outcome: String
    let authors: String
    let year: Int
    let journal: String
    let doi: String?
    let pmid: String?
    var verificationStatus: VerificationStatus
    
    init(
        id: UUID = UUID(),
        ingredient: String,
        nutrient: String,
        outcome: String,
        authors: String,
        year: Int,
        journal: String,
        doi: String? = nil,
        pmid: String? = nil,
        verificationStatus: VerificationStatus = .pending
    ) {
        self.id = id
        self.ingredient = ingredient
        self.nutrient = nutrient
        self.outcome = outcome
        self.authors = authors
        self.year = year
        self.journal = journal
        self.doi = doi
        self.pmid = pmid
        self.verificationStatus = verificationStatus
    }
    
    /// A citation without DOI or PMID can never be verified
    var canBeVerified: Bool {
        return doi != nil || pmid != nil
    }
}

/// Verification status for research citations
enum VerificationStatus: String, Codable {
    case verified
    case rejected
    case pending
}

/// Response structure from AI for research evidence
struct ResearchEvidenceResponse: Codable {
    let researchEvidence: [ResearchCitationRaw]
}

/// Raw citation structure from AI (before verification)
struct ResearchCitationRaw: Codable {
    let ingredient: String
    let nutrient: String
    let outcome: String
    let authors: String
    let year: Int
    let journal: String
    let doi: String?
    let pmid: String?
    
    /// Convert to ResearchCitation with pending status
    func toResearchCitation() -> ResearchCitation {
        return ResearchCitation(
            ingredient: ingredient,
            nutrient: nutrient,
            outcome: outcome,
            authors: authors,
            year: year,
            journal: journal,
            doi: doi,
            pmid: pmid,
            verificationStatus: .pending
        )
    }
}

/// Legacy structure for backward compatibility during transition
struct HealthGoalResearchInfo: Codable {
    let summary: String
    let researchEvidence: [String]
    let sources: [String]
    let isVerified: Bool  // Flag to indicate if research came from ResearchEvidenceService
    
    /// Convert verified citations to legacy format
    init(summary: String, verifiedCitations: [ResearchCitation]) {
        self.summary = summary
        self.researchEvidence = verifiedCitations.map { citation in
            "\(citation.ingredient)'s \(citation.nutrient) \(citation.outcome). (\(citation.authors), \(citation.year))"
        }
        self.sources = verifiedCitations.map { citation in
            "• \(citation.journal) (\(citation.year))"
        }
        self.isVerified = true  // Always verified when created from ResearchCitation
    }
    
    /// Legacy initializer for cached data (not verified)
    init(summary: String, researchEvidence: [String], sources: [String]) {
        self.summary = summary
        self.researchEvidence = researchEvidence
        self.sources = sources
        self.isVerified = false  // Legacy cached data is not verified
    }
    
    /// Custom decoder to handle legacy cached data without isVerified field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        researchEvidence = try container.decode([String].self, forKey: .researchEvidence)
        sources = try container.decode([String].self, forKey: .sources)
        // Default to false for legacy cached data (not verified)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
    }
    
    enum CodingKeys: String, CodingKey {
        case summary, researchEvidence, sources, isVerified
    }
}

/// Legacy structure for backward compatibility during transition
struct HealthInfo: Codable {
    let summary: String
    let researchEvidence: [String]
    let sources: [String]
    let isVerified: Bool  // Flag to indicate if research came from ResearchEvidenceService
    
    /// Convert verified citations to legacy format
    init(summary: String, verifiedCitations: [ResearchCitation]) {
        self.summary = summary
        self.researchEvidence = verifiedCitations.map { citation in
            "\(citation.ingredient)'s \(citation.nutrient) \(citation.outcome). (\(citation.authors), \(citation.year))"
        }
        self.sources = verifiedCitations.map { citation in
            "• \(citation.journal) (\(citation.year))"
        }
        self.isVerified = true  // Always verified when created from ResearchCitation
    }
    
    /// Legacy initializer for cached data (not verified)
    init(summary: String, researchEvidence: [String], sources: [String]) {
        self.summary = summary
        self.researchEvidence = researchEvidence
        self.sources = sources
        self.isVerified = false  // Legacy cached data is not verified
    }
    
    /// Custom decoder to handle legacy cached data without isVerified field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        researchEvidence = try container.decode([String].self, forKey: .researchEvidence)
        sources = try container.decode([String].self, forKey: .sources)
        // Default to false for legacy cached data (not verified)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
    }
    
    enum CodingKeys: String, CodingKey {
        case summary, researchEvidence, sources, isVerified
    }
}
