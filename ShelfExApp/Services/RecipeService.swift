import Foundation

// MARK: - Recipe Service — LangChain + Ollama Backend

struct Recipe: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let cookTime: String
    let difficulty: String
    let ingredients: [String]
    let steps: [String]

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
}

struct RecipeResponse: Codable {
    let recipes: [Recipe]?
    let error: String?
}

enum RecipeService {
    static func generateRecipes(items: [Product]) async throws -> [Recipe] {
        guard let url = URL(string: AppConfig.recipeServerURL) else {
            throw RecipeError.invalidURL
        }

        // Sort by urgency — expiring-soon items first
        let sorted = items.sorted { a, b in
            DateUtils.daysUntilExpiry(a.expiryDate) < DateUtils.daysUntilExpiry(b.expiryDate)
        }

        let allNames = sorted.map(\.name)
        let urgentNames = sorted
            .filter { DateUtils.daysUntilExpiry($0.expiryDate) <= 3 }
            .map(\.name)

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120 // LLM can be slow

        let body: [String: Any] = [
            "items": allNames,
            "urgent_items": urgentNames
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw RecipeError.serverError
        }

        let decoded = try JSONDecoder().decode(RecipeResponse.self, from: data)

        if let error = decoded.error, !error.isEmpty {
            throw RecipeError.llmError(error)
        }

        guard let recipes = decoded.recipes, !recipes.isEmpty else {
            throw RecipeError.noRecipes
        }

        return recipes
    }
}

enum RecipeError: LocalizedError {
    case invalidURL
    case serverError
    case noRecipes
    case llmError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid recipe server URL"
        case .serverError: return "Cannot reach recipe server. Make sure the Python server is running."
        case .noRecipes: return "No recipes generated. Try again."
        case .llmError(let msg): return msg
        }
    }
}
