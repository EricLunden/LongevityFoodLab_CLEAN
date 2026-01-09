import Foundation

/// Validates Tier 2 (Authoritative Review) citations from approved journal/institutional sources
/// Tier 2 validation matches against journal or institution names, NOT URLs
class AuthoritativeReviewValidator {
    
    /// Whitelist of approved Tier 2 journal/institution names (exact list)
    /// Matching: case-insensitive, partial string match allowed
    private static let approvedSources: [String] = [
        // Journals (Tier 2 allowed)
        "American Journal of Clinical Nutrition",
        "Journal of Nutrition",
        "Nutrition Reviews",
        "British Journal of Nutrition",
        "BMJ",
        "The Lancet",
        "Nature Reviews",
        "Nutrients",
        "Diabetes Care",
        "Diabetes",
        "Phytotherapy Research",
        "Journal of Ethnopharmacology",
        "Free Radical Biology and Medicine",
        "Clinical Nutrition",
        "Advances in Nutrition",
        "Frontiers in Nutrition",
        // Institutions (Tier 2 allowed)
        "NIH",
        "National Library of Medicine",
        "Harvard T.H. Chan School of Public Health",
        "Mayo Clinic",
        "Linus Pauling Institute",
        "WHO",
        "CDC",
        "EFSA"
    ]
    
    /// Domains to ignore when validating Tier 2 (publisher redirects, DOI/PMID resolvers)
    private static let ignoredDomains: [String] = [
        "doi.org",
        "pubmed.ncbi.nlm.nih.gov",
        "ncbi.nlm.nih.gov",
        "springer.com",
        "elsevier.com",
        "wiley.com",
        "nature.com",
        "bmj.com",
        "thelancet.com"
    ]
    
    /// Verifies a citation qualifies as Tier 2 (Authoritative Review)
    /// - Parameter citation: Citation to verify
    /// - Returns: VerificationResult with tier if accepted, rejection reason if not
    static func verifyCitation(_ citation: ResearchCitation) async -> VerificationResult {
        // Must have journal or institution name
        guard !citation.journal.isEmpty else {
            return .rejected("No journal or institution name provided for Tier 2 verification")
        }
        
        // Must have valid year
        guard CitationValidator.isValidYear(citation.year) else {
            return .rejected("Invalid or missing publication year")
        }
        
        // Check if journal/institution matches approved sources (case-insensitive, partial match)
        let journalLower = citation.journal.lowercased()
        let isApprovedSource = approvedSources.contains { source in
            let sourceLower = source.lowercased()
            // Match exact or if journal contains source name or vice versa
            return journalLower == sourceLower ||
                   journalLower.contains(sourceLower) ||
                   sourceLower.contains(journalLower)
        }
        
        guard isApprovedSource else {
            return .rejected("Journal/institution not in Tier 2 whitelist: \(citation.journal)")
        }
        
        // If URL is present, check if it's from an ignored domain (DOI/PMID resolvers, publisher redirects)
        if let urlString = citation.url ?? citation.resolvedURL, !urlString.isEmpty {
            if let url = URL(string: urlString), let host = url.host?.lowercased() {
                let isIgnoredDomain = ignoredDomains.contains { domain in
                    host == domain || host.hasSuffix(".\(domain)")
                }
                if isIgnoredDomain {
                    // Ignore DOI/PMID resolver domains - they don't affect Tier 2 validation
                    // Continue with validation based on journal name only
                }
            }
        }
        
        // Check for prohibited claims (treatment, prevention, cure, efficacy, dosage)
        let prohibitedClaims = checkForProhibitedClaims(citation)
        if prohibitedClaims {
            return .rejected("Tier 2 citation contains prohibited treatment/prevention/dosage claims")
        }
        
        // Check for causal language (must be supportive/associative, not causal)
        let hasCausalLanguage = checkForCausalLanguage(citation)
        if hasCausalLanguage {
            return .rejected("Tier 2 citation contains causal claims (must be supportive/associative)")
        }
        
        // Accepted as Tier 2 (no registry metadata needed)
        print("🔬 AuthoritativeReviewValidator: Accepted Tier 2 authoritative review citation: \(citation.journal)")
        return .verified(.authoritativeReview, nil)
    }
    
    /// Checks citation for prohibited claims (treatment, prevention, cure, efficacy, dosage)
    private static func checkForProhibitedClaims(_ citation: ResearchCitation) -> Bool {
        let textToCheck = [
            citation.outcome.lowercased(),
            citation.title?.lowercased() ?? "",
            citation.journal.lowercased()
        ].joined(separator: " ")
        
        let prohibitedKeywords = [
            "treats", "treatment", "cures", "cure", "prevents", "prevention",
            "prevents disease", "treats disease", "cures disease",
            "effective for", "efficacy", "dosing", "dosage", "dose",
            "supplement efficacy", "mg", "mcg", "milligrams", "micrograms",
            "recommended dose", "daily dose"
        ]
        
        return prohibitedKeywords.contains { keyword in
            textToCheck.contains(keyword)
        }
    }
    
    /// Checks citation for causal language (must be supportive/associative, not causal)
    private static func checkForCausalLanguage(_ citation: ResearchCitation) -> Bool {
        let outcomeLower = citation.outcome.lowercased()
        
        // Causal language patterns (not allowed for Tier 2)
        let causalKeywords = [
            "causes", "caused by", "leads to", "results in", "produces",
            "induces", "triggers", "brings about", "creates", "generates"
        ]
        
        // Check if outcome contains causal language
        return causalKeywords.contains { keyword in
            outcomeLower.contains(keyword)
        }
    }
}
