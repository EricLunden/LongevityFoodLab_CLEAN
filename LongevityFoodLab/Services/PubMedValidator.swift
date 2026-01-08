import Foundation

/// Validates citations via PubMed E-utilities API
class PubMedValidator {
    
    private static let baseURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi"
    
    /// Verifies a citation using PubMed PMID
    static func verifyCitation(_ citation: ResearchCitation) async -> VerificationResult {
        guard let pmid = citation.pmid, !pmid.isEmpty else {
            return .rejected("No PMID provided")
        }
        
        // Validate format first
        guard CitationValidator.isValidPMID(pmid) else {
            return .rejected("Invalid PMID format")
        }
        
        // Call PubMed API
        guard let url = URL(string: "\(baseURL)?db=pubmed&id=\(pmid)&retmode=json") else {
            return .rejected("Invalid API URL")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .rejected("PubMed API returned error")
            }
            
            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let pmidData = result[pmid] as? [String: Any] else {
                return .rejected("Study not found in PubMed")
            }
            
            // Verify study exists (check for error field - if present and non-empty, study not found)
            if let error = pmidData["error"] as? String, !error.isEmpty {
                return .rejected("Study not found in PubMed: \(error)")
            }
            
            // Extract and verify fields
            let pubYear = extractYear(from: pmidData)
            let pubAuthors = extractAuthors(from: pmidData)
            let pubJournal = extractJournal(from: pmidData)
            
            // Extract registry metadata (REQUIRED for Tier 1)
            guard let registryJournal = pubJournal, !registryJournal.isEmpty else {
                return .rejected("Registry metadata unavailable: journal name missing")
            }
            
            guard let registryYear = pubYear else {
                return .rejected("Registry metadata unavailable: publication year missing")
            }
            
            // Verify match (allow ±1 year tolerance) - but we'll use registry year
            let yearDiff = abs(registryYear - citation.year)
            if yearDiff > 1 {
                return .rejected("Year mismatch: expected \(citation.year)±1, found \(registryYear)")
            }
            
            // Verify author matches (for credibility check)
            if let authors = pubAuthors, !authorsMatch(authors, citation.authors) {
                return .rejected("Author mismatch")
            }
            
            // Extract title from registry
            let registryTitle = extractTitle(from: pmidData)
            let url = "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/"
            
            // Verify URL resolves (basic check)
            let urlResolves = await verifyURLResolves(url)
            if !urlResolves {
                return .rejected("PMID URL does not resolve")
            }
            
            // Create registry metadata
            let metadata = RegistryMetadata(
                journal: registryJournal,
                year: registryYear,
                title: registryTitle
            )
            
            // This is Tier 1: Verified Primary Research
            print("🔬 PubMedValidator: Citation VERIFIED as VERIFIED_PRIMARY - PMID: \(pmid), Registry Journal: \(registryJournal), Registry Year: \(registryYear)")
            print("🔬 PubMedValidator: Using registry-sourced metadata for verified citation")
            return .verified(.verifiedPrimary, metadata)
            
        } catch {
            return .rejected("API error: \(error.localizedDescription)")
        }
    }
    
    private static func extractYear(from data: [String: Any]) -> Int? {
        if let pubDate = data["pubdate"] as? String {
            // Extract year from date string (format: "2021 Jan 15" or "2021")
            let components = pubDate.components(separatedBy: " ")
            if let yearString = components.first, let year = Int(yearString) {
                return year
            }
        }
        return nil
    }
    
    private static func extractAuthors(from data: [String: Any]) -> String? {
        if let authors = data["authors"] as? [[String: Any]],
           let firstAuthor = authors.first,
           let lastName = firstAuthor["name"] as? String {
            return lastName
        }
        return nil
    }
    
    private static func extractJournal(from data: [String: Any]) -> String? {
        return data["source"] as? String
    }
    
    private static func extractTitle(from data: [String: Any]) -> String? {
        return data["title"] as? String
    }
    
    /// Verify URL resolves (basic HEAD request check)
    private static func verifyURLResolves(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            return false
        }
        
        return false
    }
    
    private static func authorsMatch(_ pubAuthors: String, _ citationAuthors: String) -> Bool {
        // Normalize and compare - allow partial matches
        let pubNormalized = pubAuthors.lowercased().trimmingCharacters(in: .whitespaces)
        let citationNormalized = citationAuthors.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check if citation author contains pub author or vice versa
        return citationNormalized.contains(pubNormalized) || pubNormalized.contains(citationNormalized)
    }
    
    private static func journalMatches(_ pubJournal: String, _ citationJournal: String) -> Bool {
        // Normalize and compare - allow partial matches
        let pubNormalized = pubJournal.lowercased().trimmingCharacters(in: .whitespaces)
        let citationNormalized = citationJournal.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check if citation journal contains pub journal or vice versa
        return citationNormalized.contains(pubNormalized) || pubNormalized.contains(citationNormalized)
    }
}

enum VerificationResult {
    case verified(CitationTier, RegistryMetadata?)
    case rejected(String)
    
    var isVerified: Bool {
        if case .verified = self {
            return true
        }
        return false
    }
    
    var tier: CitationTier? {
        if case .verified(let tier, _) = self {
            return tier
        }
        return nil
    }
    
    var metadata: RegistryMetadata? {
        if case .verified(_, let metadata) = self {
            return metadata
        }
        return nil
    }
}
