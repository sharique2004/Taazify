import Foundation

// MARK: - App Configuration (port of config.js)

enum AppConfig {
    // Dev fallback so recipe generation works even when build settings are not configured.
    private static let defaultCohereAPIKey = "cr4Yy0FWjrvngxpD6jA9LpOoHEJFdpcjQgrdxT4w"

    private static func sanitizedInfoValue(_ key: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Treat unresolved Xcode placeholders like "$(COHERE_API_KEY)" as missing.
        if value.isEmpty || value.hasPrefix("$(") {
            return ""
        }
        return value
    }

    // In a real app, read these from a plist or environment
    static var supabaseURL: String {
        sanitizedInfoValue("SUPABASE_URL")
    }

    static var supabaseAnonKey: String {
        sanitizedInfoValue("SUPABASE_ANON_KEY")
    }

    static var backendEnabled: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }

    static var ocrServerURL: String {
        "http://104.39.137.8:8000/analyze"
    }

    static var recipeServerURL: String {
        "http://104.39.41.94:8001/recipes"
    }

    static var cohereAPIKey: String {
        let configured = sanitizedInfoValue("COHERE_API_KEY")
        return configured.isEmpty ? defaultCohereAPIKey : configured
    }

    static var cohereModel: String {
        sanitizedInfoValue("COHERE_MODEL").isEmpty ? "command-a-03-2025" : sanitizedInfoValue("COHERE_MODEL")
    }
}
