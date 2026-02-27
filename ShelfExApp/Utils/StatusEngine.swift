import SwiftUI

// MARK: - Product Freshness Status (port of statusEngine.js)

enum FreshnessStatus: String {
    case green, yellow, red

    var color: Color {
        switch self {
        case .green: return .green
        case .yellow: return .orange
        case .red: return .red
        }
    }

    var label: String {
        switch self {
        case .green: return "Fresh"
        case .yellow: return "Use Soon"
        case .red: return "Expired"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .green:
            return LinearGradient(colors: [Color(hex: "00C853"), Color(hex: "69F0AE")], startPoint: .leading, endPoint: .trailing)
        case .yellow:
            return LinearGradient(colors: [Color(hex: "FF9100"), Color(hex: "FFD54F")], startPoint: .leading, endPoint: .trailing)
        case .red:
            return LinearGradient(colors: [Color(hex: "FF1744"), Color(hex: "FF8A80")], startPoint: .leading, endPoint: .trailing)
        }
    }
}

struct ProductStatus {
    let status: FreshnessStatus
    let daysRemaining: Int
    let label: String
}

enum StatusEngine {
    static func getProductStatus(_ expiryDateStr: String) -> ProductStatus {
        let days = DateUtils.daysUntilExpiry(expiryDateStr)

        if days > 3 {
            return ProductStatus(status: .green, daysRemaining: days, label: "Fresh")
        } else if days >= 0 {
            let label = days == 0 ? "Expires today" : "\(days) day\(days != 1 ? "s" : "") left"
            return ProductStatus(status: .yellow, daysRemaining: days, label: label)
        } else {
            let absDays = abs(days)
            return ProductStatus(status: .red, daysRemaining: days, label: "Expired \(absDays) day\(absDays != 1 ? "s" : "") ago")
        }
    }

    static func getDaysText(_ days: Int) -> String {
        switch days {
        case let d where d > 1: return "\(d) days left"
        case 1: return "1 day left"
        case 0: return "Expires today!"
        case -1: return "Expired yesterday"
        default: return "Expired \(abs(days)) days ago"
        }
    }

    static func getExpiryProgress(purchaseDate: String, expiryDate: String) -> Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let purchase = formatter.date(from: purchaseDate),
              let expiry = formatter.date(from: expiryDate) else { return 100 }

        let now = Date()
        let totalSpan = expiry.timeIntervalSince(purchase)
        let elapsed = now.timeIntervalSince(purchase)

        guard totalSpan > 0 else { return 100 }
        return min(100, max(0, (elapsed / totalSpan) * 100))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
