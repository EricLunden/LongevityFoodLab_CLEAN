//
//  ImageAnalysisService.swift
//  LongevityFoodLab
//
//  Created by Eric Betuel on 7/12/25.
//

import Foundation
import UIKit
import Vision

class ImageAnalysisService {
    static let shared = ImageAnalysisService()
    private init() {}
    
    // MARK: - Food Recognition
    func analyzeFoodImage(_ image: UIImage, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(NSError(domain: "Invalid image", code: 0, userInfo: nil)))
            return
        }
        
        // Use Vision framework for food recognition
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // For now, we'll use AI service to analyze the image
            // In a production app, you might want to use a dedicated food recognition API
            self.analyzeImageWithAI(image) { result in
                completion(result)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - AI Image Analysis
    private func analyzeImageWithAI(_ image: UIImage, completion: @escaping (Result<[String], Error>) -> Void) {
        print("🔍 ImageAnalysisService: Starting AI image analysis")
        
        // Compress image to meet API size requirements (5MB max for base64)
        // Base64 encoding adds ~33% overhead, so target 3.7MB for JPEG to stay under 5MB when base64 encoded
        let maxSizeBytes = Int(3.7 * 1024 * 1024) // 3.7MB in bytes
        var compressionQuality: CGFloat = 0.8
        var imageData: Data?
        var processedImage = image
        
        // First try compression
        while compressionQuality > 0.1 {
            if let data = processedImage.jpegData(compressionQuality: compressionQuality) {
                print("🔍 ImageAnalysisService: Trying compression quality \(compressionQuality), size: \(data.count) bytes")
                if data.count <= maxSizeBytes {
                    imageData = data
                    print("🔍 ImageAnalysisService: Image compressed successfully to \(data.count) bytes")
                    break
                }
            }
            compressionQuality -= 0.1
        }
        
        // If compression didn't work, try resizing the image
        if imageData == nil {
            print("🔍 ImageAnalysisService: Compression failed, trying image resizing")
            let maxDimension: CGFloat = 1024 // Resize to max 1024x1024
            let size = processedImage.size
            let aspectRatio = size.width / size.height
            
            var newSize: CGSize
            if size.width > size.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            processedImage.draw(in: CGRect(origin: .zero, size: newSize))
            if let resizedImage = UIGraphicsGetImageFromCurrentImageContext() {
                processedImage = resizedImage
                print("🔍 ImageAnalysisService: Image resized to \(newSize)")
                
                // Try compression again with resized image
                compressionQuality = 0.8
                while compressionQuality > 0.1 {
                    if let data = processedImage.jpegData(compressionQuality: compressionQuality) {
                        print("🔍 ImageAnalysisService: Trying resized image with compression \(compressionQuality), size: \(data.count) bytes")
                        if data.count <= maxSizeBytes {
                            imageData = data
                            print("🔍 ImageAnalysisService: Resized image compressed successfully to \(data.count) bytes")
                            break
                        }
                    }
                    compressionQuality -= 0.1
                }
            }
            UIGraphicsEndImageContext()
        }
        
        guard let finalImageData = imageData else {
            print("🔍 ImageAnalysisService: Failed to compress image to acceptable size")
            completion(.failure(NSError(domain: "Image too large", code: 0, userInfo: [NSLocalizedDescriptionKey: "Image is too large to process. Please try a smaller image."])))
            return
        }
        
        guard let url = URL(string: SecureConfig.openAIBaseURL) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(SecureConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        
        let base64Image = finalImageData.base64EncodedString()
        print("🔍 ImageAnalysisService: Final image size - JPEG: \(finalImageData.count) bytes, Base64: \(base64Image.count) bytes")
        
        let prompt = """
        Analyze this food image and identify all the foods/ingredients visible. Return ONLY a JSON array of food names:
        
        ["food1", "food2", "food3"]
        
        Be specific with food names (e.g., "Grilled Salmon" not just "fish", "Fresh Spinach" not just "vegetables").
        Only include foods that are clearly visible in the image.
        Focus on the main components of the meal, not every small ingredient.
        """
        
        // OpenAI vision API format
        let requestBody: [String: Any] = [
            "model": SecureConfig.openAIModelName,
            "max_tokens": 500,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔍 ImageAnalysisService: Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                print("🔍 ImageAnalysisService: HTTP error: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("🔍 ImageAnalysisService: Error response: \(errorString)")
                }
                completion(.failure(NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: nil)))
                return
            }
            
            guard let data = data else {
                print("🔍 ImageAnalysisService: No data received")
                completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                return
            }
            
            do {
                // OpenAI response format: { "choices": [{"message": {"content": "..."}}] }
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let text = message["content"] as? String {
                    
                    print("🔍 ImageAnalysisService: Received response text: \(text)")
                    
                    // Strip markdown code blocks if present (OpenAI sometimes wraps JSON in ```json ... ```)
                    var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleanedText.hasPrefix("```") {
                        // Remove markdown code block markers
                        let lines = cleanedText.components(separatedBy: .newlines)
                        var jsonLines = lines
                        // Remove first line if it's a code block marker (```json or ```)
                        if let firstLine = jsonLines.first, firstLine.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
                            jsonLines.removeFirst()
                        }
                        // Remove last line if it's a code block marker (```)
                        if let lastLine = jsonLines.last, lastLine.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
                            jsonLines.removeLast()
                        }
                        cleanedText = jsonLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        print("🔍 ImageAnalysisService: Stripped markdown code blocks from response")
                    }
                    
                    // Parse the JSON array from the response
                    if let foodData = cleanedText.data(using: .utf8),
                       let foods = try JSONSerialization.jsonObject(with: foodData) as? [String] {
                        print("🔍 ImageAnalysisService: Successfully parsed foods: \(foods)")
                        completion(.success(foods))
                    } else {
                        print("🔍 ImageAnalysisService: Failed to parse JSON from response")
                        completion(.failure(NSError(domain: "Invalid response format", code: 0, userInfo: nil)))
                    }
                } else {
                    print("🔍 ImageAnalysisService: Invalid response structure")
                    completion(.failure(NSError(domain: "Invalid response format", code: 0, userInfo: nil)))
                }
            } catch {
                print("🔍 ImageAnalysisService: JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
} 