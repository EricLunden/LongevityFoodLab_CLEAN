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
            
            // Verify match
            if let year = pubYear, year != citation.year {
                return .rejected("Year mismatch: expected \(citation.year), found \(year)")
            }
            
            if let authors = pubAuthors, !authorsMatch(authors, citation.authors) {
                return .rejected("Author mismatch")
            }
            
            if let journal = pubJournal, !journalMatches(journal, citation.journal) {
                return .rejected("Journal mismatch")
            }
            
            return .verified
            
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
    case verified
    case rejected(String)
    
    var isVerified: Bool {
        if case .verified = self {
            return true
        }
        return false
    }
}
