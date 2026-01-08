import Foundation

/// Validates citations via Crossref API
class CrossrefValidator {
    
    private static let baseURL = "https://api.crossref.org/works"
    
    /// Verifies a citation using DOI
    static func verifyCitation(_ citation: ResearchCitation) async -> VerificationResult {
        guard let doi = citation.doi, !doi.isEmpty else {
            return .rejected("No DOI provided")
        }
        
        // Validate format first
        guard CitationValidator.isValidDOI(doi) else {
            return .rejected("Invalid DOI format")
        }
        
        // URL encode DOI
        guard let encodedDOI = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(baseURL)/\(encodedDOI)") else {
            return .rejected("Invalid API URL")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .rejected("Invalid API response")
            }
            
            if httpResponse.statusCode == 404 {
                return .rejected("DOI not found in Crossref")
            }
            
            guard httpResponse.statusCode == 200 else {
                return .rejected("Crossref API returned error: \(httpResponse.statusCode)")
            }
            
            // Parse response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = json["message"] as? [String: Any] else {
                return .rejected("Invalid Crossref API response")
            }
            
            // Extract and verify fields
            let pubYear = extractYear(from: message)
            let pubAuthors = extractAuthors(from: message)
            let pubJournal = extractJournal(from: message)
            
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
        if let publishedDate = data["published-print"] as? [String: Any],
           let dateParts = publishedDate["date-parts"] as? [[Int]],
           let firstPart = dateParts.first,
           let year = firstPart.first {
            return year
        }
        
        // Fallback to published-online
        if let publishedDate = data["published-online"] as? [String: Any],
           let dateParts = publishedDate["date-parts"] as? [[Int]],
           let firstPart = dateParts.first,
           let year = firstPart.first {
            return year
        }
        
        return nil
    }
    
    private static func extractAuthors(from data: [String: Any]) -> String? {
        if let authors = data["author"] as? [[String: Any]],
           let firstAuthor = authors.first,
           let lastName = firstAuthor["family"] as? String {
            return lastName
        }
        return nil
    }
    
    private static func extractJournal(from data: [String: Any]) -> String? {
        if let container = data["container-title"] as? [String],
           let journal = container.first {
            return journal
        }
        return nil
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
