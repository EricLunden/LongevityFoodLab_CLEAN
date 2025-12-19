//
//  RDALookupService.swift
//  LongevityFoodLab
//
//  USDA 2020-2025 Dietary Guidelines RDA Lookup Service
//

import Foundation

class RDALookupService {
    static let shared = RDALookupService()
    
    private init() {}
    
    // MARK: - RDA Data Structure
    // Based on USDA 2020-2025 Dietary Guidelines
    // Values are for adults (ages 19-70) unless otherwise specified
    // Units: mg, mcg, IU, g as appropriate
    
    private let rdaValues: [String: [String: Double]] = [
        // Vitamin D (IU) - varies by age
        "Vitamin D": [
            "19-70": 600,
            "71+": 800
        ],
        
        // Vitamin E (mg) - same for all adults
        "Vitamin E": [
            "all": 15
        ],
        
        // Potassium (mg) - varies by sex
        "Potassium": [
            "male": 3400,
            "female": 2600
        ],
        
        // Vitamin K (mcg) - varies by sex
        "Vitamin K": [
            "male": 120,
            "female": 90
        ],
        
        // Magnesium (mg) - varies by sex and age
        "Magnesium": [
            "male_19-30": 400,
            "male_31+": 420,
            "female_19-30": 310,
            "female_31+": 320
        ],
        
        // Vitamin A (mcg RAE) - varies by sex
        "Vitamin A": [
            "male": 900,
            "female": 700
        ],
        
        // Calcium (mg) - varies by age and sex
        "Calcium": [
            "19-50": 1000,
            "male_51-70": 1000,
            "female_51-70": 1200,
            "71+": 1200
        ],
        
        // Vitamin C (mg) - varies by sex
        "Vitamin C": [
            "male": 90,
            "female": 75
        ],
        
        // Choline (mg) - varies by sex
        "Choline": [
            "male": 550,
            "female": 425
        ],
        
        // Iron (mg) - varies significantly by sex and age
        "Iron": [
            "male_19-50": 8,
            "male_51+": 8,
            "female_19-50": 18,
            "female_51+": 8
        ],
        
        // Iodine (mcg) - same for all adults
        "Iodine": [
            "all": 150
        ],
        
        // Zinc (mg) - varies by sex
        "Zinc": [
            "male": 11,
            "female": 8
        ],
        
        // Folate (B9) (mcg) - same for all adults
        "Folate (B9)": [
            "all": 400
        ],
        
        // Vitamin B12 (mcg) - same for all adults
        "Vitamin B12": [
            "all": 2.4
        ],
        
        // Vitamin B6 (mg) - varies by age and sex
        "Vitamin B6": [
            "male_19-50": 1.3,
            "male_51+": 1.7,
            "female_19-50": 1.3,
            "female_51+": 1.5
        ],
        
        // Selenium (mcg) - same for all adults
        "Selenium": [
            "all": 55
        ],
        
        // Copper (mg) - same for all adults
        "Copper": [
            "all": 0.9
        ],
        
        // Manganese (mg) - varies by sex
        "Manganese": [
            "male": 2.3,
            "female": 1.8
        ],
        
        // Thiamin (B1) (mg) - varies by sex
        "Thiamin (B1)": [
            "male": 1.2,
            "female": 1.1
        ]
    ]
    
    // MARK: - Public Methods
    
    /// Get RDA value for a micronutrient based on user profile
    func getRDA(for micronutrient: String, ageRange: String?, sex: String?) -> Double? {
        guard let nutrientData = rdaValues[micronutrient] else {
            print("⚠️ RDALookupService: No RDA data found for \(micronutrient)")
            return nil
        }
        
        // Determine lookup key based on nutrient and user profile
        let lookupKey = determineLookupKey(for: micronutrient, ageRange: ageRange, sex: sex)
        
        // Try specific key first
        if let value = nutrientData[lookupKey] {
            return value
        }
        
        // Try "all" fallback
        if let value = nutrientData["all"] {
            return value
        }
        
        // Try sex-based fallback
        if let sex = sex?.lowercased() {
            if sex.contains("male"), let value = nutrientData["male"] {
                return value
            }
            if sex.contains("female"), let value = nutrientData["female"] {
                return value
            }
        }
        
        // Try age-based fallback
        if let ageRange = ageRange {
            if ageRange.contains("30") || ageRange.contains("50"), let value = nutrientData["19-50"] {
                return value
            }
            if ageRange.contains("70") || ageRange.contains("+"), let value = nutrientData["71+"] {
                return value
            }
        }
        
        print("⚠️ RDALookupService: Could not determine RDA for \(micronutrient) with ageRange: \(ageRange ?? "nil"), sex: \(sex ?? "nil")")
        return nil
    }
    
    /// Get RDA value with unit string
    func getRDAWithUnit(for micronutrient: String, ageRange: String?, sex: String?) -> String? {
        guard let value = getRDA(for: micronutrient, ageRange: ageRange, sex: sex) else {
            return nil
        }
        
        let unit = getUnit(for: micronutrient)
        return "\(Int(value)) \(unit)"
    }
    
    /// Get unit for a micronutrient
    func getUnit(for micronutrient: String) -> String {
        // Map micronutrient names to their units
        let unitMap: [String: String] = [
            "Vitamin D": "IU",
            "Vitamin E": "mg",
            "Potassium": "mg",
            "Vitamin K": "mcg",
            "Magnesium": "mg",
            "Vitamin A": "mcg",
            "Calcium": "mg",
            "Vitamin C": "mg",
            "Choline": "mg",
            "Iron": "mg",
            "Iodine": "mcg",
            "Zinc": "mg",
            "Folate (B9)": "mcg",
            "Vitamin B12": "mcg",
            "Vitamin B6": "mg",
            "Selenium": "mcg",
            "Copper": "mg",
            "Manganese": "mg",
            "Thiamin (B1)": "mg"
        ]
        
        return unitMap[micronutrient] ?? "mg"
    }
    
    // MARK: - Private Helpers
    
    private func determineLookupKey(for micronutrient: String, ageRange: String?, sex: String?) -> String {
        let sexLower = sex?.lowercased() ?? ""
        let ageRangeLower = ageRange?.lowercased() ?? ""
        
        // Special handling for Magnesium which uses 19-30 and 31+ ranges
        if micronutrient == "Magnesium" {
            if sexLower.contains("male") {
                // Check if age range is specifically "30-50" or contains "30" but not "31" or "50"
                if ageRangeLower.contains("30") && !ageRangeLower.contains("31") && !ageRangeLower.contains("50") {
                    return "male_19-30"
                } else {
                    // For "30-50", "50-70", "70+", or any range above 30, use 31+
                    return "male_31+"
                }
            }
            
            if sexLower.contains("female") {
                if ageRangeLower.contains("30") && !ageRangeLower.contains("31") && !ageRangeLower.contains("50") {
                    return "female_19-30"
                } else {
                    return "female_31+"
                }
            }
        }
        
        // Special handling for Vitamin D which uses 19-70 range
        if micronutrient == "Vitamin D" {
            if ageRangeLower.contains("70") || ageRangeLower.contains("+") {
                return "71+"
            } else {
                // For any age range below 70, use 19-70
                return "19-70"
            }
        }
        
        // Special handling for Calcium which uses 19-50, male_51-70, female_51-70, and 71+
        if micronutrient == "Calcium" {
            if sexLower.contains("male") {
                if ageRangeLower.contains("70") && !ageRangeLower.contains("71") && !ageRangeLower.contains("+") {
                    // Specifically 51-70 range
                    return "male_51-70"
                } else if ageRangeLower.contains("71") || ageRangeLower.contains("+") {
                    return "71+"
                } else if ageRangeLower.contains("30") || ageRangeLower.contains("50") {
                    return "19-50"
                }
            }
            
            if sexLower.contains("female") {
                if ageRangeLower.contains("70") && !ageRangeLower.contains("71") && !ageRangeLower.contains("+") {
                    return "female_51-70"
                } else if ageRangeLower.contains("71") || ageRangeLower.contains("+") {
                    return "71+"
                } else if ageRangeLower.contains("30") || ageRangeLower.contains("50") {
                    return "19-50"
                }
            }
            
            // Fallback for no sex specified - use age-based keys
            if ageRangeLower.contains("70") && !ageRangeLower.contains("71") && !ageRangeLower.contains("+") {
                // Default to male for 51-70 if sex not specified
                return "male_51-70"
            } else if ageRangeLower.contains("71") || ageRangeLower.contains("+") {
                return "71+"
            } else {
                return "19-50"
            }
        }
        
        // Check for sex-specific keys (for other nutrients)
        if sexLower.contains("male") {
            if ageRangeLower.contains("30") || ageRangeLower.contains("50") {
                return "male_19-50"
            } else if ageRangeLower.contains("70") || ageRangeLower.contains("+") {
                return "male_51+"
            }
            return "male"
        }
        
        if sexLower.contains("female") {
            if ageRangeLower.contains("30") || ageRangeLower.contains("50") {
                return "female_19-50"
            } else if ageRangeLower.contains("70") || ageRangeLower.contains("+") {
                return "female_51+"
            }
            return "female"
        }
        
        // Check for age-specific keys
        if ageRangeLower.contains("30") || ageRangeLower.contains("50") {
            return "19-50"
        } else if ageRangeLower.contains("70") || ageRangeLower.contains("+") {
            return "71+"
        }
        
        return "all"
    }
}

