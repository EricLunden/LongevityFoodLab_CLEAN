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
            
            // Step 1: Check minimum requirements (DOI/PMID for Tier 1, or journal/institution name for Tier 2)
            guard CitationValidator.hasMinimumRequirements(citation) else {
                print("🔬 ResearchEvidenceService: Rejected citation - Missing DOI/PMID (Tier 1) or journal/institution name (Tier 2)")
                continue
            }
            
            // Step 2: Try Tier 1 verification first (VERIFIED_PRIMARY)
            var verificationResult: VerificationResult?
            var verifiedTier: CitationTier?
            var registryMetadata: RegistryMetadata?
            
            // Try PMID first if available (Tier 1)
            if let pmid = citation.pmid, !pmid.isEmpty {
                let formatResult = CitationValidator.validateFormat(citation)
                if formatResult.isValid {
                    verificationResult = await PubMedValidator.verifyCitation(citation)
                    if let result = verificationResult, result.isVerified, let tier = result.tier {
                        verifiedTier = tier
                        registryMetadata = result.metadata
                        
                        // For Tier 1, registry metadata is REQUIRED
                        if tier == .verifiedPrimary && registryMetadata == nil {
                            print("🔬 ResearchEvidenceService: Rejected verified citation — registry metadata unavailable")
                            verificationResult = .rejected("Registry metadata unavailable")
                            verifiedTier = nil
                        }
                    }
                }
            }
            
            // If PMID verification failed or not available, try DOI (Tier 1)
            if verificationResult?.isVerified != true, let doi = citation.doi, !doi.isEmpty {
                let formatResult = CitationValidator.validateFormat(citation)
                if formatResult.isValid {
                    verificationResult = await CrossrefValidator.verifyCitation(citation)
                    if let result = verificationResult, result.isVerified, let tier = result.tier {
                        verifiedTier = tier
                        registryMetadata = result.metadata
                        
                        // For Tier 1, registry metadata is REQUIRED
                        if tier == .verifiedPrimary && registryMetadata == nil {
                            print("🔬 ResearchEvidenceService: Rejected verified citation — registry metadata unavailable")
                            verificationResult = .rejected("Registry metadata unavailable")
                            verifiedTier = nil
                        }
                    }
                }
            }
            
            // Step 3: If Tier 1 failed, try Tier 2 (AUTHORITATIVE_REVIEW)
            if verificationResult?.isVerified != true {
                verificationResult = await AuthoritativeReviewValidator.verifyCitation(citation)
                if let result = verificationResult, result.isVerified, let tier = result.tier {
                    verifiedTier = tier
                    // Tier 2 doesn't require registry metadata
                } else {
                    let reason = verificationResult?.rejectionReason ?? "Tier 2 verification failed"
                    print("🔬 ResearchEvidenceService: Rejected Tier 2 citation — source not authorized or claim too strong: \(reason)")
                }
            }
            
            // Step 4: Only add if verified with a tier
            if let result = verificationResult, result.isVerified, let tier = verifiedTier {
                // Create verified citation with tier and URL
                let resolvedURL = citation.resolvedURL ?? citation.url
                
                // For Tier 1: Use registry-sourced journal and year
                // For Tier 2: Use AI-provided journal and year
                let finalJournal: String
                let finalYear: Int
                
                if tier == .verifiedPrimary, let metadata = registryMetadata {
                    finalJournal = metadata.journal
                    finalYear = metadata.year
                } else {
                    finalJournal = citation.journal
                    finalYear = citation.year
                }
                
                let verifiedCitation = ResearchCitation(
                    id: citation.id,
                    ingredient: citation.ingredient,
                    nutrient: citation.nutrient,
                    outcome: citation.outcome,
                    authors: citation.authors,
                    year: finalYear,
                    journal: finalJournal,
                    doi: citation.doi,
                    pmid: citation.pmid,
                    url: resolvedURL,
                    title: nil,  // Never display titles for Tier 1
                    verificationStatus: .verified,
                    citationTier: tier,
                    registryJournal: tier == .verifiedPrimary ? registryMetadata?.journal : nil,
                    registryYear: tier == .verifiedPrimary ? registryMetadata?.year : nil
                )
                
                verifiedCitations.append(verifiedCitation)
                print("🔬 ResearchEvidenceService: Citation ACCEPTED - Tier: \(tier.rawValue), Ingredient: \(citation.ingredient), Journal: \(finalJournal), Year: \(finalYear), URL: \(resolvedURL ?? "none")")
            } else {
                let reason = verificationResult?.rejectionReason ?? "Verification failed"
                print("🔬 ResearchEvidenceService: Citation REJECTED - Reason: \(reason), Ingredient: \(citation.ingredient)")
            }
        }
        
        // Priority: If Tier 1 citations exist, return only Tier 1
        // Otherwise, return Tier 2 citations
        let tier1Citations = verifiedCitations.filter { $0.citationTier == .verifiedPrimary }
        if !tier1Citations.isEmpty {
            print("🔬 ResearchEvidenceService: Returning \(tier1Citations.count) Tier 1 citations (Tier 2 filtered out)")
            return tier1Citations
        }
        
        // Return Tier 2 citations if no Tier 1 exists
        let tier2Citations = verifiedCitations.filter { $0.citationTier == .authoritativeReview }
        if !tier2Citations.isEmpty {
            print("🔬 ResearchEvidenceService: Returning \(tier2Citations.count) Tier 2 citations (no Tier 1 available)")
            return tier2Citations
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
        case .verified(let tier, _):
            return "Verified as \(tier.rawValue)"
        }
    }
}
