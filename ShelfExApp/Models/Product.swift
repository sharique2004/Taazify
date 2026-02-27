import Foundation

struct Product: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var category: String
    var emoji: String
    var barcode: String
    var quantity: Int
    var purchaseDate: String
    var expiryDate: String

    var consumed: Bool
    var thrownAway: Bool
    var addedToShoppingList: Bool
    var sourceReceiptScanId: String?
    var createdAt: String

    init(
        id: String = UUID().uuidString,
        name: String,
        category: String = "other",
        emoji: String = "📦",
        barcode: String = "",
        quantity: Int = 1,
        purchaseDate: String? = nil,
        expiryDate: String,

        consumed: Bool = false,
        thrownAway: Bool = false,
        addedToShoppingList: Bool = false,
        sourceReceiptScanId: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.emoji = emoji
        self.barcode = barcode
        self.quantity = quantity
        self.purchaseDate = purchaseDate ?? DateUtils.todayString()
        self.expiryDate = expiryDate

        self.consumed = consumed
        self.thrownAway = thrownAway
        self.addedToShoppingList = addedToShoppingList
        self.sourceReceiptScanId = sourceReceiptScanId
        self.createdAt = createdAt ?? ISO8601DateFormatter().string(from: Date())
    }

    var isActive: Bool {
        !consumed && !thrownAway
    }
}
