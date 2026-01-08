import Foundation

/// Isolated service for verifying research citations
/// This service ONLY handles health outcome research citations
class ResearchEvidenceService {
    
    static let shared = ResearchEvidenceService()
    
    /// Feature flag to disable verification (for testing/rollback)
    /// Can be controlled via UserDefaults key: "ResearchEvidenceServiceEnabled"
    var isEnabled: Bool {
        get {
            // Default to enabled, but allow disabling via UserDefaults
            return UserDefaults.standard.object(forKey: "ResearchEvidenceServiceEnabled") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ResearchEvidenceServiceEnabled")
        }
    }
    
    private init() {}
    
    /// Processes raw citations from AI and returns only verified ones
    /// - Parameter rawCitations: Citations from AI (untrusted)
    /// - Returns: Array of verified citations only
    func verifyCitations(_ rawCitations: [ResearchCitationRaw]) async -> [ResearchCitation] {
        // If disabled, return empty array (fail-safe)
        guard isEnabled else {
            print("🔬 ResearchEvidenceService: Disabled, returning empty citations")
            return []
        }
        
        var verifiedCitations: [ResearchCitation] = []
        
        // Process each citation
        for rawCitation in rawCitations {
            let citation = rawCitation.toResearchCitation()
            
            // Step 1: Validate format
            let formatResult = CitationValidator.validateFormat(citation)
            guard formatResult.isValid else {
                print("🔬 ResearchEvidenceService: Rejected citation - \(formatResult)")
                continue
            }
            
            // Step 2: Verify via API
            var verificationResult: VerificationResult?
            
            // Try PMID first if available
            if let pmid = citation.pmid, !pmid.isEmpty {
                verificationResult = await PubMedValidator.verifyCitation(citation)
            }
            
            // If PMID verification failed or not available, try DOI
            if verificationResult?.isVerified != true, let doi = citation.doi, !doi.isEmpty {
                verificationResult = await CrossrefValidator.verifyCitation(citation)
            }
            
            // Step 3: Only add if verified
            if let result = verificationResult, result.isVerified {
                var verifiedCitation = citation
                verifiedCitation.verificationStatus = .verified
                verifiedCitations.append(verifiedCitation)
                print("🔬 ResearchEvidenceService: Verified citation - \(citation.ingredient) (\(citation.doi ?? citation.pmid ?? "unknown"))")
            } else {
                let reason = verificationResult?.rejectionReason ?? "Verification failed"
                print("🔬 ResearchEvidenceService: Rejected citation - \(reason)")
            }
        }
        
        return verifiedCitations
    }
    
    /// Processes AI response and extracts verified citations
    /// - Parameter aiResponse: Raw JSON string from AI
    /// - Returns: Array of verified citations, or empty array if none verify
    func processAIResponse(_ aiResponse: String) async -> [ResearchCitation] {
        // Extract JSON from response
        let jsonText = extractJSONFromText(aiResponse)
        
        guard let data = jsonText.data(using: .utf8) else {
            print("🔬 ResearchEvidenceService: Failed to convert response to data")
            return []
        }
        
        do {
            let response = try JSONDecoder().decode(ResearchEvidenceResponse.self, from: data)
            return await verifyCitations(response.researchEvidence)
        } catch {
            print("🔬 ResearchEvidenceService: Failed to decode response - \(error)")
            return []
        }
    }
    
    /// Extracts JSON from AI response text (handles markdown code blocks)
    private func extractJSONFromText(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: .newlines)
            var jsonLines = lines
            
            if let firstLine = jsonLines.first, firstLine.contains("json") {
                jsonLines.removeFirst()
            } else if let firstLine = jsonLines.first, firstLine.hasPrefix("```") {
                jsonLines.removeFirst()
            }
            
            if let lastLine = jsonLines.last, lastLine == "```" {
                jsonLines.removeLast()
            }
            
            cleaned = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Find JSON object boundaries
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            return String(cleaned[jsonRange])
        }
        
        return cleaned
    }
}

extension VerificationResult {
    var rejectionReason: String {
        switch self {
        case .rejected(let reason):
            return reason
        case .verified:
            return "Verified"
        }
    }
}
