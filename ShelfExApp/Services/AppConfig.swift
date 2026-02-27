import Foundation

// MARK: - App Configuration (port of config.js)

enum AppConfig {
    // In a real app, read these from a plist or environment
    static var supabaseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? ""
    }

    static var supabaseAnonKey: String {
        Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String ?? ""
    }

    static var backendEnabled: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty
    }

    static var ocrServerURL: String {
        "http://104.39.137.8:8000/analyze"
    }
}
