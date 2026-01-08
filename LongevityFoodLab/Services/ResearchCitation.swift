import Foundation

/// Metadata extracted from verified registry (PubMed/Crossref)
struct RegistryMetadata {
    let journal: String
    let year: Int
    let title: String?
}

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
    let url: String?  // Resolvable URL for user verification
    let title: String?  // Study title for display (not used for Tier 1)
    var verificationStatus: VerificationStatus
    var citationTier: CitationTier?
    
    // Registry-sourced metadata (for Tier 1 only - overrides AI-provided data)
    let registryJournal: String?  // Journal name from PubMed/Crossref
    let registryYear: Int?  // Publication year from PubMed/Crossref
    
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
        url: String? = nil,
        title: String? = nil,
        verificationStatus: VerificationStatus = .pending,
        citationTier: CitationTier? = nil,
        registryJournal: String? = nil,
        registryYear: Int? = nil
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
        self.url = url
        self.title = title
        self.verificationStatus = verificationStatus
        self.citationTier = citationTier
        self.registryJournal = registryJournal
        self.registryYear = registryYear
    }
    
    /// Display journal name - use registry-sourced for Tier 1, otherwise AI-provided
    var displayJournal: String {
        if citationTier == .verifiedPrimary, let registryJournal = registryJournal {
            return registryJournal
        }
        return journal
    }
    
    /// Display year - use registry-sourced for Tier 1, otherwise AI-provided
    var displayYear: Int {
        if citationTier == .verifiedPrimary, let registryYear = registryYear {
            return registryYear
        }
        return year
    }
    
    /// A citation without DOI or PMID can never be verified as Tier 1
    var canBeVerified: Bool {
        return doi != nil || pmid != nil
    }
    
    /// Generate URL from DOI or PMID if not provided
    /// UNCHANGED for Tier 1 - preserves existing behavior
    var resolvedURL: String? {
        if let url = url, !url.isEmpty {
            return url
        }
        if let doi = doi, !doi.isEmpty {
            return "https://doi.org/\(doi)"
        }
        if let pmid = pmid, !pmid.isEmpty {
            return "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/"
        }
        return nil
    }
    
    /// Tier-aware URL for UI display
    /// Tier 1: Uses resolvedURL (DOI/PMID links)
    /// Tier 2: Uses PMID if available, else journal homepage, else nil (no broken DOI links)
    var displayURL: String? {
        guard let tier = citationTier else {
            // No tier assigned - use resolvedURL as fallback
            return resolvedURL
        }
        
        if tier == .verifiedPrimary {
            // Tier 1: UNCHANGED - use existing resolvedURL logic
            return resolvedURL
        }
        
        if tier == .authoritativeReview {
            // Tier 2: Non-clickable by default (App Store compliance)
            // Never link to DOI resolvers, PubMed abstracts, or journal homepages
            // Educational content should not have clickable links to avoid implied medical guidance
            return nil
        }
        
        // Other tiers - use resolvedURL
        return resolvedURL
    }
}

/// Maps journal names to their homepage URLs for Tier 2 citations
private struct JournalHomepageMapper {
    private static let journalHomepages: [String: String] = [
        "American Journal of Clinical Nutrition": "https://academic.oup.com/ajcn",
        "Nutrition Reviews": "https://academic.oup.com/nutritionreviews",
        "Nature Reviews": "https://www.nature.com/nri",
        "Nature Reviews Immunology": "https://www.nature.com/nri",
        "BMJ": "https://www.bmj.com",
        "The Lancet": "https://www.thelancet.com",
        "British Journal of Nutrition": "https://www.cambridge.org/core/journals/british-journal-of-nutrition"
    ]
    
    /// Returns homepage URL for a journal name (case-insensitive partial match)
    static func homepage(for journalName: String) -> String? {
        let journalLower = journalName.lowercased()
        
        // Try exact match first
        if let homepage = journalHomepages[journalName] {
            return homepage
        }
        
        // Try partial match (journal name contains key or vice versa)
        for (key, homepage) in journalHomepages {
            let keyLower = key.lowercased()
            if journalLower.contains(keyLower) || keyLower.contains(journalLower) {
                return homepage
            }
        }
        
        return nil
    }
}

/// Verification status for research citations
enum VerificationStatus: String, Codable {
    case verified
    case rejected
    case pending
}

/// Citation credibility tier - determines what claims can be supported
enum CitationTier: String, Codable {
    case verifiedPrimary = "VERIFIED_PRIMARY"
    case authoritativeReview = "AUTHORITATIVE_REVIEW"
    case contextualReference = "CONTEXTUAL_REFERENCE"
    
    var displayLabel: String {
        switch self {
        case .verifiedPrimary:
            return "Primary research (peer-reviewed)"
        case .authoritativeReview:
            return "Authoritative review (educational)"
        case .contextualReference:
            return "Contextual reference (non-clinical)"
        }
    }
    
    var canSupportCausalClaims: Bool {
        return self == .verifiedPrimary
    }
    
    var canSupportHealthOutcomes: Bool {
        return self == .verifiedPrimary || self == .authoritativeReview
    }
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
    let url: String?
    let title: String?
    
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
            url: url,
            title: title,
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
    let citations: [ResearchCitation]?  // Full citation data for clickable links
    
    /// Convert verified citations to legacy format
    init(summary: String, verifiedCitations: [ResearchCitation]) {
        self.summary = summary
        self.researchEvidence = verifiedCitations.map { citation in
            var text = "\(citation.ingredient)'s \(citation.nutrient) \(citation.outcome). (\(citation.authors), \(citation.year))"
            if let tier = citation.citationTier {
                text += " [\(tier.displayLabel)]"
            }
            return text
        }
        self.sources = verifiedCitations.map { citation in
            var source = "• \(citation.journal) (\(citation.year))"
            if let tier = citation.citationTier {
                source += " — \(tier.displayLabel)"
            }
            return source
        }
        self.isVerified = true  // Always verified when created from ResearchCitation
        self.citations = verifiedCitations  // Store full citation data
    }
    
    /// Legacy initializer for cached data (not verified)
    init(summary: String, researchEvidence: [String], sources: [String]) {
        self.summary = summary
        self.researchEvidence = researchEvidence
        self.sources = sources
        self.isVerified = false  // Legacy cached data is not verified
        self.citations = nil  // No citation data for legacy
    }
    
    /// Custom decoder to handle legacy cached data without isVerified field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        researchEvidence = try container.decode([String].self, forKey: .researchEvidence)
        sources = try container.decode([String].self, forKey: .sources)
        // Default to false for legacy cached data (not verified)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        citations = try container.decodeIfPresent([ResearchCitation].self, forKey: .citations)
    }
    
    enum CodingKeys: String, CodingKey {
        case summary, researchEvidence, sources, isVerified, citations
    }
}

/// Legacy structure for backward compatibility during transition
struct HealthInfo: Codable {
    let summary: String
    let researchEvidence: [String]
    let sources: [String]
    let isVerified: Bool  // Flag to indicate if research came from ResearchEvidenceService
    let citations: [ResearchCitation]?  // Full citation data for clickable links
    
    /// Convert verified citations to legacy format
    init(summary: String, verifiedCitations: [ResearchCitation]) {
        self.summary = summary
        self.researchEvidence = verifiedCitations.map { citation in
            var text = "\(citation.ingredient)'s \(citation.nutrient) \(citation.outcome). (\(citation.authors), \(citation.year))"
            if let tier = citation.citationTier {
                text += " [\(tier.displayLabel)]"
            }
            return text
        }
        self.sources = verifiedCitations.map { citation in
            var source = "• \(citation.journal) (\(citation.year))"
            if let tier = citation.citationTier {
                source += " — \(tier.displayLabel)"
            }
            return source
        }
        self.isVerified = true  // Always verified when created from ResearchCitation
        self.citations = verifiedCitations  // Store full citation data
    }
    
    /// Legacy initializer for cached data (not verified)
    init(summary: String, researchEvidence: [String], sources: [String]) {
        self.summary = summary
        self.researchEvidence = researchEvidence
        self.sources = sources
        self.isVerified = false  // Legacy cached data is not verified
        self.citations = nil  // No citation data for legacy
    }
    
    /// Custom decoder to handle legacy cached data without isVerified field
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(String.self, forKey: .summary)
        researchEvidence = try container.decode([String].self, forKey: .researchEvidence)
        sources = try container.decode([String].self, forKey: .sources)
        // Default to false for legacy cached data (not verified)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        citations = try container.decodeIfPresent([ResearchCitation].self, forKey: .citations)
    }
    
    enum CodingKeys: String, CodingKey {
        case summary, researchEvidence, sources, isVerified, citations
    }
}
