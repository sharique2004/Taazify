import Foundation

// MARK: - Date Utilities (port of dateUtils.js)

enum DateUtils {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    static func daysFromNow(_ n: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: n, to: today()) ?? Date()
        return dateFormatter.string(from: date)
    }

    static func today() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    static func daysUntilExpiry(_ expiryDateStr: String) -> Int {
        guard let expiry = dateFormatter.date(from: expiryDateStr) else { return 0 }
        let expiryStart = Calendar.current.startOfDay(for: expiry)
        let todayStart = today()
        let diff = Calendar.current.dateComponents([.day], from: todayStart, to: expiryStart)
        return diff.day ?? 0
    }

    static func formatDate(_ dateStr: String) -> String {
        guard let date = dateFormatter.date(from: dateStr) else { return dateStr }
        return displayFormatter.string(from: date)
    }

    static func formatDateForInput(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func relativeDateString(_ dateStr: String) -> String {
        guard let date = dateFormatter.date(from: dateStr) else { return dateStr }
        let todayStart = today()
        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: todayStart)
        let days = diff.day ?? 0

        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2..<7: return "\(days) days ago"
        default:
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: date)
        }
    }

    static func expiryDateFromCategory(purchaseDate: String, category: String) -> String {
        let days = ShelfLifeDatabase.categoryDefaults[category] ?? ShelfLifeDatabase.categoryDefaults["other"] ?? 7
        return expiryDateFromShelfLife(purchaseDate: purchaseDate, shelfDays: days)
    }

    static func expiryDateFromShelfLife(purchaseDate: String, shelfDays: Int) -> String {
        let clampedDays = max(1, shelfDays)
        guard let date = dateFormatter.date(from: purchaseDate) else { return daysFromNow(clampedDays) }
        let expiry = Calendar.current.date(byAdding: .day, value: clampedDays, to: date) ?? Date()
        return dateFormatter.string(from: expiry)
    }

    static func daysBetween(startDate: String, endDate: String) -> Int? {
        guard let start = dateFormatter.date(from: startDate),
              let end = dateFormatter.date(from: endDate) else {
            return nil
        }

        let startDay = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)
        return Calendar.current.dateComponents([.day], from: startDay, to: endDay).day
    }
}
