import Foundation

// MARK: - Sample Products for Demo/Local Mode (port of sampleProducts.js)

enum SampleData {
    static let products: [Product] = [
        Product(name: "Whole Milk", category: "dairy", emoji: "🥛", purchaseDate: DateUtils.daysFromNow(-3), expiryDate: DateUtils.daysFromNow(4)),
        Product(name: "Chicken Breast", category: "meat", emoji: "🍗", purchaseDate: DateUtils.daysFromNow(-1), expiryDate: DateUtils.daysFromNow(1)),
        Product(name: "Bananas", category: "fruit", emoji: "🍌", quantity: 5, purchaseDate: DateUtils.daysFromNow(-2), expiryDate: DateUtils.daysFromNow(3)),
        Product(name: "Spinach", category: "vegetable", emoji: "🥬", purchaseDate: DateUtils.daysFromNow(-3), expiryDate: DateUtils.daysFromNow(2)),
        Product(name: "Yogurt", category: "dairy", emoji: "🥛", quantity: 4, purchaseDate: DateUtils.daysFromNow(-1), expiryDate: DateUtils.daysFromNow(13)),
        Product(name: "Ground Beef", category: "meat", emoji: "🥩", purchaseDate: DateUtils.daysFromNow(-2), expiryDate: DateUtils.daysFromNow(0)),
        Product(name: "White Bread", category: "bakery", emoji: "🍞", purchaseDate: DateUtils.daysFromNow(-4), expiryDate: DateUtils.daysFromNow(1)),
        Product(name: "Strawberries", category: "fruit", emoji: "🍓", purchaseDate: DateUtils.daysFromNow(-2), expiryDate: DateUtils.daysFromNow(3)),
        Product(name: "Eggs", category: "dairy", emoji: "🥚", quantity: 12, purchaseDate: DateUtils.daysFromNow(-1), expiryDate: DateUtils.daysFromNow(20)),
        Product(name: "Fresh Salmon", category: "seafood", emoji: "🐟", purchaseDate: DateUtils.daysFromNow(-1), expiryDate: DateUtils.daysFromNow(1)),
    ]
}
