import Foundation

struct ShoppingItem: Identifiable, Codable, Equatable {
    var id: String
    var productName: String
    var category: String
    var emoji: String
    var addedFrom: String
    var addedDate: String
    var purchased: Bool

    init(
        id: String = UUID().uuidString,
        productName: String,
        category: String = "other",
        emoji: String = "📦",
        addedFrom: String = "manual",
        addedDate: String? = nil,
        purchased: Bool = false
    ) {
        self.id = id
        self.productName = productName
        self.category = category
        self.emoji = emoji
        self.addedFrom = addedFrom
        self.addedDate = addedDate ?? DateUtils.todayString()
        self.purchased = purchased
    }
}
