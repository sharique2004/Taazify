import Foundation
import SwiftUI

// MARK: - Store Manager (port of store.js)
// Central state management with local persistence and optional Supabase sync

@MainActor
class StoreManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var shopping: [ShoppingItem] = []

    @Published var prefersDarkMode: Bool = false

    private let productsKey = "shelfex_products"
    private let shoppingKey = "shelfex_shopping"

    private let themeKey = "taazify_theme"

    init() {
        prefersDarkMode = UserDefaults.standard.string(forKey: themeKey) == "dark"
    }

    func toggleTheme() {
        prefersDarkMode.toggle()
        UserDefaults.standard.set(prefersDarkMode ? "dark" : "light", forKey: themeKey)
    }

    // MARK: - Initialization

    func initialize() {
        loadLocalState()
        if products.isEmpty {
            products = SampleData.products
        }
        saveLocalState()
    }

    // MARK: - Local Persistence

    private func loadLocalState() {
        products = load(productsKey) ?? []
        shopping = load(shoppingKey) ?? []
    }

    private func saveLocalState() {
        save(productsKey, data: products)
        save(shoppingKey, data: shopping)
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ key: String, data: T) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    // MARK: - Products

    var activeProducts: [Product] {
        products.filter { $0.isActive }
    }

    func addProducts(_ productList: [Product]) {
        for product in productList {
            if let idx = products.firstIndex(where: { $0.id == product.id }) {
                products[idx] = product
            } else {
                products.append(product)
            }
        }
        saveLocalState()
    }

    func updateProduct(id: String, updates: (inout Product) -> Void) {
        guard let idx = products.firstIndex(where: { $0.id == id }) else { return }
        updates(&products[idx])
        saveLocalState()
    }

    func removeProduct(id: String) {
        products.removeAll { $0.id == id }
        saveLocalState()
    }

    var groceryHistory: [(date: String, items: [Product])] {
        let historyProducts = products.filter { $0.consumed || $0.thrownAway }
        var grouped: [String: [Product]] = [:]
        for p in historyProducts {
            let date = p.purchaseDate
            grouped[date, default: []].append(p)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { ($0.key, $0.value) }
    }

    // MARK: - Stats

    var stats: (green: Int, yellow: Int, red: Int, total: Int) {
        var g = 0, y = 0, r = 0
        for p in activeProducts {
            switch StatusEngine.getProductStatus(p.expiryDate).status {
            case .green: g += 1
            case .yellow: y += 1
            case .red: r += 1
            }
        }
        return (g, y, r, activeProducts.count)
    }

    // MARK: - Shopping List

    func addToShoppingList(_ item: ShoppingItem) {
        if let idx = shopping.firstIndex(where: { $0.id == item.id }) {
            shopping[idx] = item
        } else {
            shopping.append(item)
        }
        saveLocalState()
    }

    func toggleShoppingItem(id: String) {
        guard let idx = shopping.firstIndex(where: { $0.id == id }) else { return }
        shopping[idx].purchased.toggle()
        saveLocalState()
    }

    func removeShoppingItem(id: String) {
        shopping.removeAll { $0.id == id }
        saveLocalState()
    }


}
