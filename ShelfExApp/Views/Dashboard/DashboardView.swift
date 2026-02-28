import SwiftUI

// MARK: - Dashboard View (port of ProductDashboard.js)

struct DashboardView: View {
    @EnvironmentObject var store: StoreManager
    @State private var currentFilter: String = "all"
    @State private var searchQuery: String = ""
    @State private var showConsumeAlert: Product?
    @State private var showTossAlert: Product?
    @State private var showRecipeSheet = false

    var filteredProducts: [Product] {
        var products = store.activeProducts

        // Apply status filter
        if currentFilter != "all" {
            products = products.filter { p in
                StatusEngine.getProductStatus(p.expiryDate).status.rawValue == currentFilter
            }
        }

        // Apply search
        if !searchQuery.isEmpty {
            products = products.filter { p in
                p.name.localizedCaseInsensitiveContains(searchQuery) ||
                p.category.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        // Sort: urgent first
        let statusOrder: [FreshnessStatus: Int] = [.red: 0, .yellow: 1, .green: 2]
        return products.sorted { a, b in
            let sa = StatusEngine.getProductStatus(a.expiryDate).status
            let sb = StatusEngine.getProductStatus(b.expiryDate).status
            return (statusOrder[sa] ?? 2) < (statusOrder[sb] ?? 2)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Stats Row
                    statsRow
                        .padding(.horizontal)

                    // Filter Chips
                    filterBar
                        .padding(.horizontal)

                    // Search
                    searchBar
                        .padding(.horizontal)

                    // Products List
                    if filteredProducts.isEmpty && store.activeProducts.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else if filteredProducts.isEmpty {
                        noMatchState
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(filteredProducts.enumerated()), id: \.element.id) { index, product in
                                ProductRowView(product: product, index: index) {
                                    showConsumeAlert = product
                                } onToss: {
                                    showTossAlert = product
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .navigationTitle("My Pantry")
            .navigationBarTitleDisplayMode(.large)
            .cartoonPageBackground()
            .alert("Consumed?", isPresented: .init(
                get: { showConsumeAlert != nil },
                set: { if !$0 { showConsumeAlert = nil } }
            )) {
                Button("🛒 Add to Shopping List") {
                    if let product = showConsumeAlert {
                        handleConsume(product, addToList: true)
                    }
                }
                Button("No thanks", role: .cancel) {
                    if let product = showConsumeAlert {
                        handleConsume(product, addToList: false)
                    }
                }
            } message: {
                if let product = showConsumeAlert {
                    Text("Add \(product.name) to your shopping list for next time?")
                }
            }
            .alert("Toss?", isPresented: .init(
                get: { showTossAlert != nil },
                set: { if !$0 { showTossAlert = nil } }
            )) {
                Button("🛒 Yes, repurchase") {
                    if let product = showTossAlert {
                        handleToss(product, addToList: true)
                    }
                }
                Button("Just remove", role: .destructive) {
                    if let product = showTossAlert {
                        handleToss(product, addToList: false)
                    }
                }
            } message: {
                if let product = showTossAlert {
                    Text("Would you like to add \(product.name) to your shopping list?")
                }
            }
        }
        .sheet(isPresented: $showRecipeSheet) {
            RecipeView()
                .environmentObject(store)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        let s = store.stats
        return HStack(spacing: 10) {
            StatPill(count: s.green, label: "Fresh", color: CartoonTheme.primary)
            StatPill(count: s.yellow, label: "Soon", color: .orange)
            StatPill(count: s.red, label: "Expired", color: .red)

            // AI Recipe Button
            Button {
                showRecipeSheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text("AI Recipe")
                        .font(.caption2.weight(.bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(CartoonTheme.buttonGradient)
                .clipShape(Capsule())
                .shadow(color: CartoonTheme.primary.opacity(0.3), radius: 4, y: 2)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isActive: currentFilter == "all") { currentFilter = "all" }
                FilterChip(label: "Fresh", isActive: currentFilter == "green") { currentFilter = "green" }
                FilterChip(label: "Use Soon", isActive: currentFilter == "yellow") { currentFilter = "yellow" }
                FilterChip(label: "Expired", isActive: currentFilter == "red") { currentFilter = "red" }
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CartoonTheme.title.opacity(0.5))
            TextField("Search products...", text: $searchQuery)
                .textInputAutocapitalization(.never)
                .foregroundStyle(CartoonTheme.title)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(CartoonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CartoonTheme.cardStroke, lineWidth: 1.5)
        )
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📦").font(.system(size: 48))
            Text("No products yet")
                .font(.headline)
                .foregroundColor(CartoonTheme.title)
            Text("Scan a receipt or add items manually")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var noMatchState: some View {
        VStack(spacing: 8) {
            Text("🔍").font(.system(size: 32))
            Text("No matches found")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func handleConsume(_ product: Product, addToList: Bool) {
        store.updateProduct(id: product.id) { $0.consumed = true }
        if addToList {
            store.addToShoppingList(ShoppingItem(
                productName: product.name,
                category: product.category,
                emoji: product.emoji,
                addedFrom: "consumed"
            ))
        }
        showConsumeAlert = nil
    }

    private func handleToss(_ product: Product, addToList: Bool) {
        store.updateProduct(id: product.id) { $0.thrownAway = true }
        if addToList {
            store.addToShoppingList(ShoppingItem(
                productName: product.name,
                category: product.category,
                emoji: product.emoji,
                addedFrom: "thrown"
            ))
        }
        showTossAlert = nil
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(CartoonTheme.title.opacity(0.65))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.16))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundColor(isActive ? .white : CartoonTheme.title.opacity(0.7))
                .background(isActive ? CartoonTheme.primary : Color.white.opacity(0.85))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.clear : CartoonTheme.cardStroke, lineWidth: 1)
                )
        }
    }
}
