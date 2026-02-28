import Foundation

// MARK: - Recipe Service — Server-first with Cohere fallback

struct Recipe: Identifiable, Decodable {
    let id: String
    let name: String
    let emoji: String
    let cookTime: String
    let difficulty: String
    let ingredients: [String]
    let steps: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case cookTime
        case cook_time
        case difficulty
        case ingredients
        case steps
    }

    init(id: String = UUID().uuidString, name: String, emoji: String = "🍳",
         cookTime: String = "20 min", difficulty: String = "Easy",
         ingredients: [String] = [], steps: [String] = []) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.cookTime = cookTime
        self.difficulty = difficulty
        self.ingredients = ingredients
        self.steps = steps
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Quick Pantry Meal"
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "🍳"
        cookTime =
            try container.decodeIfPresent(String.self, forKey: .cookTime)
            ?? container.decodeIfPresent(String.self, forKey: .cook_time)
            ?? "20 min"
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty) ?? "Easy"
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []
    }
}

struct RecipeResponse: Decodable {
    let recipes: [Recipe]?
    let error: String?
}

enum RecipeService {
    private struct CohereMessage: Encodable {
        let role: String
        let content: String
    }

    private struct CohereChatRequest: Encodable {
        let model: String
        let messages: [CohereMessage]
        let temperature: Double
    }

    private static let recipeSystemPrompt = """
    You are a creative home cook AI. The user will give you a list of ingredients they have in their pantry. Some items are expiring soon and should be prioritized.

    Generate exactly 3 quick, practical recipes using ONLY the provided ingredients (plus common pantry staples like salt, pepper, oil, garlic, onion).

    You MUST respond with ONLY a valid JSON object in this exact format, no other text:
    {
      "recipes": [
        {
          "name": "Recipe Name",
          "emoji": "🍳",
          "cookTime": "15 min",
          "difficulty": "Easy",
          "ingredients": ["ingredient 1", "ingredient 2"],
          "steps": ["Step 1 description", "Step 2 description", "Step 3 description"]
        }
      ]
    }

    Rules:
    - Keep recipes simple and quick (under 30 minutes)
    - Use 2-5 of the provided ingredients per recipe
    - Prioritize ingredients marked as expiring soon
    - Give each recipe a fun, appetizing name
    - Include a relevant food emoji
    - Keep steps concise (1 sentence each, max 6 steps)
    - Difficulty is one of: Easy, Medium, Hard
    - Return ONLY the JSON, no markdown fences, no explanation
    """

    static func generateRecipes(items: [Product]) async throws -> [Recipe] {
        // Sort by urgency — expiring-soon items first
        let sorted = items.sorted { a, b in
            DateUtils.daysUntilExpiry(a.expiryDate) < DateUtils.daysUntilExpiry(b.expiryDate)
        }

        let allNames = sorted.map(\.name)
        let urgentNames = sorted
            .filter { DateUtils.daysUntilExpiry($0.expiryDate) <= 3 }
            .map(\.name)

        // First try existing recipe server for backward compatibility.
        do {
            return try await generateViaRecipeServer(items: allNames, urgentItems: urgentNames)
        } catch {
            // Fallback to direct Cohere call so recipes still work without a running Python server.
            guard !AppConfig.cohereAPIKey.isEmpty else {
                throw error
            }
            return try await generateViaCohere(items: allNames, urgentItems: urgentNames)
        }
    }

    private static func generateViaRecipeServer(items: [String], urgentItems: [String]) async throws -> [Recipe] {
        guard let url = URL(string: AppConfig.recipeServerURL) else {
            throw RecipeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "items": items,
            "urgent_items": urgentItems
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw RecipeError.serverError
        }

        return try parseRecipes(fromResponseData: data)
    }

    private static func generateViaCohere(items: [String], urgentItems: [String]) async throws -> [Recipe] {
        guard !AppConfig.cohereAPIKey.isEmpty else {
            throw RecipeError.missingCohereKey
        }

        guard let url = URL(string: "https://api.cohere.com/v2/chat") else {
            throw RecipeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConfig.cohereAPIKey)", forHTTPHeaderField: "Authorization")

        let userPrompt = """
        Here are my pantry items:

        \(items.joined(separator: ", "))

        Items expiring soon (USE THESE FIRST): \(urgentItems.isEmpty ? "None" : urgentItems.joined(separator: ", "))

        Generate 3 recipes using these ingredients.
        """

        let body = CohereChatRequest(
            model: AppConfig.cohereModel,
            messages: [
                CohereMessage(role: "system", content: recipeSystemPrompt),
                CohereMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.4
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecipeError.serverError
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = parseCohereError(data) ?? "Cohere request failed with status \(httpResponse.statusCode)."
            throw RecipeError.llmError(message)
        }

        let outputText = try extractCohereText(from: data)
        return try parseRecipes(fromLLMOutput: outputText)
    }

    private static func parseRecipes(fromResponseData data: Data) throws -> [Recipe] {
        let decoded = try JSONDecoder().decode(RecipeResponse.self, from: data)
        if let error = decoded.error, !error.isEmpty {
            throw RecipeError.llmError(error)
        }
        guard let recipes = decoded.recipes, !recipes.isEmpty else {
            throw RecipeError.noRecipes
        }
        return recipes
    }

    private static func parseRecipes(fromLLMOutput outputText: String) throws -> [Recipe] {
        guard let json = extractJSONObject(from: outputText), let data = json.data(using: .utf8) else {
            throw RecipeError.invalidResponse("Cohere response did not contain valid recipe JSON.")
        }
        return try parseRecipes(fromResponseData: data)
    }

    private static func extractJSONObject(from outputText: String) -> String? {
        var text = outputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if text.contains("```json"), let jsonPart = text.components(separatedBy: "```json").dropFirst().first {
            text = jsonPart
        } else if text.contains("```"), let fencedPart = text.components(separatedBy: "```").dropFirst().first {
            text = fencedPart
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }

    private static func extractCohereText(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [String: Any] else {
            throw RecipeError.invalidResponse("Unexpected Cohere response format.")
        }

        if let text = root["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        if let message = root["message"] as? [String: Any] {
            if let content = message["content"] as? [[String: Any]] {
                let combined = content
                    .compactMap { $0["text"] as? String }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !combined.isEmpty {
                    return combined
                }
            }

            if let contentText = message["content"] as? String,
               !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return contentText
            }
        }

        if let generations = root["generations"] as? [[String: Any]] {
            for generation in generations {
                if let text = generation["text"] as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
            }
        }

        throw RecipeError.invalidResponse("Cohere response did not include text content.")
    }

    private static func parseCohereError(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String, !message.isEmpty {
            return message
        }

        return nil
    }
}

enum RecipeError: LocalizedError {
    case invalidURL
    case serverError
    case noRecipes
    case missingCohereKey
    case invalidResponse(String)
    case llmError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid recipe server URL"
        case .serverError: return "Cannot reach recipe server."
        case .noRecipes: return "No recipes generated. Try again."
        case .missingCohereKey: return "Missing Cohere API key. Add COHERE_API_KEY to Info.plist build settings."
        case .invalidResponse(let message): return message
        case .llmError(let msg): return msg
        }
    }
}
