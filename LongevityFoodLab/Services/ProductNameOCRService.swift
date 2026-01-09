import Foundation
import UIKit
import Vision

/// Service for extracting product names from product label images using OCR
class ProductNameOCRService {
    static let shared = ProductNameOCRService()
    
    private init() {}
    
    /// Extract product name from front label image using OCR
    /// - Parameters:
    ///   - image: The front label image
    ///   - brand: Optional brand name from OpenFoodFacts to help identify the product name
    ///   - completion: Completion handler with extracted product name (or nil if extraction fails)
    func extractProductName(from image: UIImage, brand: String? = nil, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            print("OCR: No CGImage available")
            completion(nil)
            return
        }
        
        // Create text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR: Text recognition error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("OCR: No text observations found")
                completion(nil)
                return
            }
            
            // Extract all recognized text
            var allText: [String] = []
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    allText.append(text)
                }
            }
            
            print("OCR: Extracted \(allText.count) text lines")
            
            // Find product name from extracted text
            let productName = self.findProductName(from: allText, brand: brand)
            
            if let name = productName {
                print("OCR: Extracted product name: '\(name)'")
            } else {
                print("OCR: Could not identify product name from extracted text")
            }
            
            completion(productName)
        }
        
        // Configure for accurate recognition (slower but more accurate)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Perform recognition
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("OCR: Failed to perform text recognition: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    /// Find product name from extracted text lines
    private func findProductName(from textLines: [String], brand: String?) -> String? {
        guard !textLines.isEmpty else { return nil }
        
        // Filter out noise lines (dates, codes, expiration info) before processing
        let filteredLines = textLines.filter { line in
            !isNoiseLine(line)
        }
        
        // Use filtered lines if we have any, otherwise fall back to original
        let linesToProcess = filteredLines.isEmpty ? textLines : filteredLines
        
        // Strategy 1: Look for lines that contain the brand name (if available)
        // But prefer lines that have MORE than just the brand (product name + brand)
        if let brand = brand, !brand.isEmpty {
            let brandLower = brand.lowercased()
            let brandWords = brandLower.components(separatedBy: .whitespaces).filter { $0.count > 2 }
            
            // First pass: Look for lines with brand + additional product name words
            var bestMatch: String?
            for line in linesToProcess.prefix(10) {
                let lineLower = line.lowercased()
                let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                
                // Skip noise lines
                if isNoiseLine(line) {
                    continue
                }
                
                // Check if line contains brand
                if lineLower.contains(brandLower) || brandWords.contains(where: { lineLower.contains($0) }) {
                    // Prefer lines that have more words than just the brand (indicates product name)
                    if words.count > brandWords.count + 1 {
                        let cleaned = cleanProductName(line, brand: brand)
                        if !cleaned.isEmpty && cleaned.lowercased() != brandLower {
                            bestMatch = cleaned
                            break // Found a good match with product name
                        }
                    }
                }
            }
            
            // If we found a good match with product name, return it
            if let match = bestMatch {
                return match
            }
            
            // Fallback: Return first line with brand (even if it's just the brand)
            for line in linesToProcess.prefix(5) {
                if isNoiseLine(line) {
                    continue
                }
                let lineLower = line.lowercased()
                if lineLower.contains(brandLower) || brandWords.contains(where: { lineLower.contains($0) }) {
                    let cleaned = cleanProductName(line, brand: brand)
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            }
        }
        
        // Strategy 2: Look for lines that look like product names
        // Product names are typically:
        // - In larger text (appear earlier in recognition, often top 3-5 lines)
        // - Contain product descriptors (Greek, Total, %, etc.)
        // - Not too long (usually 2-8 words)
        // - Don't contain common label text (Nutrition Facts, Ingredients, etc.)
        
        let excludedKeywords = ["nutrition", "facts", "ingredients", "serving", "calories", "protein", 
                              "carbohydrates", "fat", "sodium", "sugar", "fiber", "cholesterol",
                              "daily value", "percent", "per container", "net weight", "net wt"]
        
        for (index, line) in linesToProcess.prefix(10).enumerated() {
            // Skip noise lines
            if isNoiseLine(line) {
                continue
            }
            
            let lineLower = line.lowercased()
            let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Skip if contains excluded keywords
            if excludedKeywords.contains(where: { lineLower.contains($0) }) {
                continue
            }
            
            // Prefer lines that:
            // - Are in top 5 lines (likely product name)
            // - Have 2-8 words (typical product name length)
            // - Contain product descriptors (Greek, Total, %, etc.)
            if index < 5 && words.count >= 2 && words.count <= 8 {
                // Check for product descriptors
                let hasProductDescriptors = lineLower.contains("greek") || 
                                          lineLower.contains("total") ||
                                          lineLower.contains("%") ||
                                          lineLower.contains("yogurt") ||
                                          lineLower.contains("strain") ||
                                          lineLower.contains("organic") ||
                                          lineLower.contains("plain") ||
                                          lineLower.contains("vanilla") ||
                                          lineLower.contains("strawberry") ||
                                          lineLower.contains("half") ||
                                          lineLower.contains("cream") ||
                                          lineLower.contains("milk")
                
                if hasProductDescriptors || index < 3 {
                    let cleaned = cleanProductName(line, brand: brand)
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            }
        }
        
        // Strategy 3: Return first substantial line (fallback) - but skip noise
        for line in linesToProcess.prefix(5) {
            if isNoiseLine(line) {
                continue
            }
            let words = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if words.count >= 2 && words.count <= 10 {
                let cleaned = cleanProductName(line, brand: brand)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }
        
        return nil
    }
    
    /// Check if a line is noise (dates, codes, expiration info, etc.)
    private func isNoiseLine(_ line: String) -> Bool {
        let lineLower = line.lowercased()
        
        // Check for expiration date keywords
        let expirationKeywords = ["best by", "use by", "exp", "expires", "sell by", "best before", 
                                 "use before", "best if used by", "best if used before"]
        if expirationKeywords.contains(where: { lineLower.contains($0) }) {
            return true
        }
        
        // Check for date patterns (MM-DD-YY, MM/DD/YY, MM.DD.YY, etc.)
        let datePattern = #"(\d{1,2}[-/\.]\d{1,2}[-/\.]\d{2,4})"#
        if line.range(of: datePattern, options: .regularExpression) != nil {
            return true
        }
        
        // Check for lot code patterns (alphanumeric strings with colons, dashes, spaces)
        // Examples: "A81 0:04 36-5631", "LOT: ABC123", "BATCH: 12345"
        let lotCodePattern = #"([A-Z0-9]+\s*[:]\s*[A-Z0-9]+|LOT\s*[:]|BATCH\s*[:]|LOT\s*#|BATCH\s*#)"#
        if line.range(of: lotCodePattern, options: .regularExpression) != nil {
            return true
        }
        
        // Check for UPC/barcode patterns (long numeric strings)
        let upcPattern = #"\d{8,}"#
        if let range = line.range(of: upcPattern, options: .regularExpression),
           range.upperBound.utf16Offset(in: line) - range.lowerBound.utf16Offset(in: line) >= 8 {
            return true
        }
        
        // Check if line is mostly numbers and special characters (likely a code)
        let alphanumericOnly = line.components(separatedBy: .whitespaces).joined()
        let numericCount = alphanumericOnly.filter { $0.isNumber }.count
        let specialCharCount = alphanumericOnly.filter { !$0.isLetter && !$0.isNumber }.count
        let totalChars = alphanumericOnly.count
        if totalChars > 0 {
            let numericRatio = Double(numericCount) / Double(totalChars)
            let specialRatio = Double(specialCharCount) / Double(totalChars)
            // If more than 50% numbers or 40% special chars, it's likely a code
            if numericRatio > 0.5 || specialRatio > 0.4 {
                return true
            }
        }
        
        return false
    }
    
    /// Clean and format product name
    private func cleanProductName(_ name: String, brand: String?) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes/suffixes that aren't part of product name
        let prefixesToRemove = ["product name:", "name:", "brand:"]
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove expiration date patterns and keywords
        let expirationPatterns = [
            #"best\s+by\s+[^\s]+.*"#,
            #"use\s+by\s+[^\s]+.*"#,
            #"exp\s*[:]?\s*[^\s]+.*"#,
            #"expires\s+[^\s]+.*"#,
            #"sell\s+by\s+[^\s]+.*"#
        ]
        for pattern in expirationPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Remove date patterns (MM-DD-YY, MM/DD/YY, etc.)
        let datePattern = #"\s*\d{1,2}[-/\.]\d{1,2}[-/\.]\d{2,4}.*"#
        cleaned = cleaned.replacingOccurrences(of: datePattern, with: "", options: .regularExpression)
        
        // Remove lot code patterns
        let lotCodePattern = #"\s*(LOT|BATCH)\s*[:#]?\s*[A-Z0-9\s:.-]+"#
        cleaned = cleaned.replacingOccurrences(of: lotCodePattern, with: "", options: [.regularExpression, .caseInsensitive])
        
        // Remove company suffixes (LLC, Inc, Corp, etc.)
        let companySuffixes = [" LLC", ", LLC", " Inc", ", Inc", " Corp", ", Corp", " Corporation", ", Corporation",
                               " Ltd", ", Ltd", " Limited", ", Limited", " Co", ", Co", " Company", ", Company"]
        for suffix in companySuffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove standalone company names that are just legal entities
        // Example: "Hp Hood Llc" should become "Hood" if brand is "Hood"
        if let brand = brand, !brand.isEmpty {
            let brandWords = brand.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 2 }
            let cleanedLower = cleaned.lowercased()
            
            // If cleaned name is just company name variations, extract the main brand
            for brandWord in brandWords {
                if cleanedLower == brandWord || cleanedLower.contains(brandWord) {
                    // Check if there are other meaningful words
                    let words = cleaned.components(separatedBy: .whitespaces).filter { word in
                        let wordLower = word.lowercased()
                        return !wordLower.contains("llc") && 
                               !wordLower.contains("inc") && 
                               !wordLower.contains("corp") &&
                               word.count > 1
                    }
                    if !words.isEmpty {
                        cleaned = words.joined(separator: " ")
                    }
                    break
                }
            }
        }
        
        // Remove extra whitespace and clean up
        let components = cleaned.components(separatedBy: .whitespaces).filter { word in
            !word.isEmpty && 
            !word.lowercased().contains("llc") &&
            !word.lowercased().contains("inc") &&
            !word.lowercased().contains("corp")
        }
        cleaned = components.joined(separator: " ")
        
        // If brand is provided and not already in name, prepend it
        if let brand = brand, !brand.isEmpty {
            let brandLower = brand.lowercased()
            let nameLower = cleaned.lowercased()
            let brandWords = brandLower.components(separatedBy: .whitespaces).filter { $0.count > 2 }
            
            if !nameLower.contains(brandLower) && !brandWords.contains(where: { nameLower.contains($0) }) {
                cleaned = "\(brand) \(cleaned)"
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

