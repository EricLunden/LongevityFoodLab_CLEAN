import Foundation

/// Validates citation format and structure before API verification
class CitationValidator {
    
    /// Validates the format of a DOI
    static func isValidDOI(_ doi: String) -> Bool {
        // DOI format: 10.xxxx/xxxxx (where x is digit or character)
        let doiPattern = #"^10\.\d{4,}/.+$"#
        let regex = try? NSRegularExpression(pattern: doiPattern, options: [])
        let range = NSRange(location: 0, length: doi.utf16.count)
        return regex?.firstMatch(in: doi, options: [], range: range) != nil
    }
    
    /// Validates the format of a PMID
    static func isValidPMID(_ pmid: String) -> Bool {
        // PMID is numeric, typically 6-8 digits
        guard let numericValue = Int(pmid), numericValue > 0 else {
            return false
        }
        return pmid.count >= 6 && pmid.count <= 8
    }
    
    /// Validates year is within reasonable range
    static func isValidYear(_ year: Int) -> Bool {
        // PubMed contains studies from ~1800s to present
        return year >= 1800 && year <= Calendar.current.component(.year, from: Date())
    }
    
    /// Validates that citation has required fields
    static func hasRequiredFields(_ citation: ResearchCitation) -> Bool {
        return !citation.ingredient.isEmpty &&
               !citation.nutrient.isEmpty &&
               !citation.outcome.isEmpty &&
               !citation.authors.isEmpty &&
               !citation.journal.isEmpty &&
               isValidYear(citation.year)
    }
    
    /// Validates citation format before API verification
    /// For Tier 1: requires DOI or PMID
    /// For Tier 2: requires URL (DOI/PMID optional)
    static func validateFormat(_ citation: ResearchCitation) -> ValidationResult {
        // Check required fields
        guard hasRequiredFields(citation) else {
            return .invalid("Missing required fields")
        }
        
        // For Tier 1 verification: must have DOI or PMID
        // For Tier 2 verification: URL is sufficient (checked separately)
        // This validator only checks format, not tier assignment
        
        // Validate DOI format if present
        if let doi = citation.doi, !doi.isEmpty {
            guard isValidDOI(doi) else {
                return .invalid("Invalid DOI format: \(doi)")
            }
        }
        
        // Validate PMID format if present
        if let pmid = citation.pmid, !pmid.isEmpty {
            guard isValidPMID(pmid) else {
                return .invalid("Invalid PMID format: \(pmid)")
            }
        }
        
        return .valid
    }
    
    /// Validates citation has minimum requirements for any tier
    static func hasMinimumRequirements(_ citation: ResearchCitation) -> Bool {
        // Tier 1: Must have DOI or PMID
        let hasIdentifier = (citation.doi != nil && !citation.doi!.isEmpty) ||
                           (citation.pmid != nil && !citation.pmid!.isEmpty)
        
        // Tier 2: Must have journal or institution name (URL optional)
        let hasJournal = !citation.journal.isEmpty
        
        return hasIdentifier || hasJournal
    }
}

enum ValidationResult {
    case valid
    case invalid(String)
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
}
