import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

// MARK: - Cartoon Theme

enum CartoonTheme {
    static let primary = Color(hex: "2E9F57")
    static let primaryDeep = Color(hex: "1F7A41")
    static let accent = Color(hex: "BEEB74")
    static let pageTop = Color(hex: "F2FFE8")
    static let pageBottom = Color(hex: "DAF4C4")
    static let card = Color.white.opacity(0.92)
    static let cardStroke = Color(hex: "95C987").opacity(0.55)
    static let title = Color(hex: "1B3A26")

    static var pageGradient: LinearGradient {
        LinearGradient(colors: [pageTop, pageBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var buttonGradient: LinearGradient {
        LinearGradient(colors: [primary, primaryDeep], startPoint: .leading, endPoint: .trailing)
    }
}

struct CartoonPageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    CartoonTheme.pageGradient
                    Circle()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 220, height: 220)
                        .offset(x: -130, y: -300)
                    Circle()
                        .fill(CartoonTheme.accent.opacity(0.35))
                        .frame(width: 260, height: 260)
                        .offset(x: 160, y: 260)
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func cartoonPageBackground() -> some View {
        modifier(CartoonPageBackground())
    }
}

// MARK: - Pantry Item Image Resolver

#if canImport(UIKit)
enum PantryItemImageResolver {
    private static let fileAliases: [String: String] = [
        "wholemilk": "milk",
        "skimmilk": "milk",
        "almondmilk": "milk",
        "oatmilk": "milk",
        "cheddar": "cheese",
        "mozzarella": "cheese",
        "cheese": "cheese",
        "chickenbreast": "chicken",
        "groundbeef": "beef",
        "steak": "beef",
        "porkchops": "pork",
        "eggs": "eggs",
        "banana": "bananas",
        "bananas": "bananas",
        "strawberry": "strawberries",
        "strawberries": "strawberries",
        "blueberry": "blueberries",
        "blueberries": "blueberries",
        "berries": "berries",
        "lettuce": "lettus",
        "raspberry": "rassberries",
        "raspberries": "rassberries"
    ]

    private static let supportedExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp"]

    private static let imageFiles: [(key: String, url: URL)] = {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: "Images") else {
            return []
        }

        return urls.compactMap { url in
            let ext = url.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { return nil }
            let base = url.deletingPathExtension().lastPathComponent
            return (normalize(base), url)
        }
    }()

    static func image(for productName: String) -> UIImage? {
        guard !imageFiles.isEmpty else { return nil }

        let normalizedName = normalize(productName)
        let keys = candidateKeys(for: normalizedName)

        if let exact = firstMatch(for: keys) {
            return UIImage(contentsOfFile: exact.path)
        }

        guard let fuzzy = fuzzyMatch(for: keys) else { return nil }
        return UIImage(contentsOfFile: fuzzy.path)
    }

    private static func firstMatch(for keys: [String]) -> URL? {
        for key in keys {
            if let match = imageFiles.first(where: { $0.key == key }) {
                return match.url
            }
        }
        return nil
    }

    private static func fuzzyMatch(for keys: [String]) -> URL? {
        var best: (score: Int, url: URL)?

        for file in imageFiles {
            for key in keys {
                guard key.contains(file.key) || file.key.contains(key) else { continue }
                let score = min(key.count, file.key.count)
                if best == nil || score > best!.score {
                    best = (score, file.url)
                }
            }
        }

        return best?.url
    }

    private static func candidateKeys(for normalizedName: String) -> [String] {
        var keys = [normalizedName]

        for (from, to) in fileAliases where normalizedName.contains(from) {
            keys.append(to)
        }

        return Array(Set(keys)).filter { !$0.isEmpty }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

struct PantryItemIcon: View {
    let name: String
    let emoji: String
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 12
    var tint: Color = CartoonTheme.primary

    private var itemImage: UIImage? {
        PantryItemImageResolver.image(for: name)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(0.12))

            if let image = itemImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(emoji)
                    .font(.system(size: size * 0.52))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
#endif
