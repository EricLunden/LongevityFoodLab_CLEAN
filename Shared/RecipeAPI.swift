import Foundation

public struct ParsedRecipe: Codable {
    public let title: String
    public let ingredients: [String]
    public let instructions: [String]
    public let servings: String?
    public let prep_time: String?
    public let cook_time: String?
    public let total_time: String?
    public let image: String?
    public let site_link: String?
    public let source_url: String?
    public let site_name: String?
    public let quality_score: Double?
}

public final class RecipeAPI {
    public static let shared = RecipeAPI()
    private init() {}

    // Real Lambda URL
    private let lambdaURL = URL(string: "https://75gu2r32syfuqogbcn7nugmfm40oywqn.lambda-url.us-east-2.on.aws/")!

    public func parseViaLambda(url: URL, completion: @escaping (Result<ParsedRecipe, Error>) -> Void) {
        var req = URLRequest(url: lambdaURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["url": url.absoluteString, "html": ""] // Lambda expects both url and html
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        let session = URLSession(configuration: cfg)

        session.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data = data else {
                completion(.failure(NSError(domain: "LambdaError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad response"])))
                return
            }
            do {
                // Parse the Lambda response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success,
                   let recipeDict = json["recipe"] as? [String: Any] {
                    
                    // Convert to ParsedRecipe
                    let parsed = ParsedRecipe(
                        title: recipeDict["title"] as? String ?? "Unknown Recipe",
                        ingredients: recipeDict["ingredients"] as? [String] ?? [],
                        instructions: recipeDict["instructions"] as? [String] ?? [],
                        servings: recipeDict["servings"] as? String,
                        prep_time: recipeDict["prep_time"] as? String,
                        cook_time: recipeDict["cook_time"] as? String,
                        total_time: recipeDict["total_time"] as? String,
                        image: recipeDict["image"] as? String,
                        site_link: recipeDict["site_link"] as? String,
                        source_url: recipeDict["source_url"] as? String,
                        site_name: recipeDict["site_name"] as? String,
                        quality_score: recipeDict["quality_score"] as? Double
                    )
                    completion(.success(parsed))
                } else {
                    completion(.failure(NSError(domain: "LambdaError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}