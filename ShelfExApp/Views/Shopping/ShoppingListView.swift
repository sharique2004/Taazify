import SwiftUI

// MARK: - Shopping List View (port of ShoppingList.js)

struct ShoppingListView: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var toastManager: ToastManager
    @State private var newItemText = ""

    private var unpurchased: [ShoppingItem] {
        store.shopping.filter { !$0.purchased }
    }

    private var purchased: [ShoppingItem] {
        store.shopping.filter { $0.purchased }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Add Item Bar
                addItemBar
                    .padding()

                if unpurchased.isEmpty && purchased.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        // Unpurchased
                        if !unpurchased.isEmpty {
                            Section {
                                ForEach(unpurchased) { item in
                                    shoppingRow(item, isPurchased: false)
                                }
                                .onDelete { offsets in
                                    for idx in offsets {
                                        store.removeShoppingItem(id: unpurchased[idx].id)
                                    }
                                }
                            }
                        }

                        // Purchased
                        if !purchased.isEmpty {
                            Section("Purchased (\(purchased.count))") {
                                ForEach(purchased) { item in
                                    shoppingRow(item, isPurchased: true)
                                }
                                .onDelete { offsets in
                                    for idx in offsets {
                                        store.removeShoppingItem(id: purchased[idx].id)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.large)
            .cartoonPageBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(unpurchased.count) to buy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Add Item Bar

    private var addItemBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(CartoonTheme.primary)
                .font(.title3)

            TextField("Add an item...", text: $newItemText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addNewItem() }
        }
        .padding(12)
        .background(CartoonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CartoonTheme.cardStroke, lineWidth: 1.5)
        )
    }

    // MARK: - Shopping Row

    private func shoppingRow(_ item: ShoppingItem, isPurchased: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    store.toggleShoppingItem(id: item.id)
                }
            } label: {
                Image(systemName: isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isPurchased ? CartoonTheme.primary : Color(.systemGray3))
                    .font(.title3)
            }
            .buttonStyle(.plain)

            PantryItemIcon(
                name: item.productName,
                emoji: item.emoji,
                size: 34,
                cornerRadius: 10,
                tint: CartoonTheme.primary
            )

            Text(item.productName)
                .font(.subheadline)
                .strikethrough(isPurchased)
                .foregroundColor(isPurchased ? .secondary : .primary)

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(isPurchased ? 0.6 : 1)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🛒").font(.system(size: 48))
            Text("Your shopping list is empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Add Item

    private func addNewItem() {
        let name = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.addToShoppingList(ShoppingItem(productName: name, addedFrom: "manual"))
        newItemText = ""
    }
}
