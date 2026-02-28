import SwiftUI

// MARK: - AI Recipe View — Shows LLM-generated recipes from pantry items

struct RecipeView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) var dismiss
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerSection

                    if isLoading {
                        loadingState
                    } else if let error = errorMessage {
                        errorState(error)
                    } else if recipes.isEmpty {
                        emptyState
                    } else {
                        recipesSection
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [CartoonTheme.pageTop, CartoonTheme.pageBottom.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("AI Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await loadRecipes() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(CartoonTheme.primary)
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadRecipes()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CartoonTheme.primary, CartoonTheme.primaryDeep],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("What can you cook?")
                    .font(.title3.weight(.bold))
            }

            let urgentCount = store.activeProducts.filter {
                DateUtils.daysUntilExpiry($0.expiryDate) <= 3
            }.count

            if urgentCount > 0 {
                Text("Prioritizing \(urgentCount) item\(urgentCount == 1 ? "" : "s") expiring soon")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Text("Based on \(store.activeProducts.count) items in your pantry")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { i in
                shimmerCard
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.2),
                        value: isLoading
                    )
            }

            Text("🧑‍🍳 Chef AI is thinking...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 12)
    }

    private var shimmerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 20)
                Spacer()
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(height: 14)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray5))
                .frame(width: 200, height: 14)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recipes

    private var recipesSection: some View {
        ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
            RecipeCard(recipe: recipe, index: index)
        }
    }

    // MARK: - Error State

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Text("😕").font(.system(size: 48))

            Text("Couldn't generate recipes")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                Task { await loadRecipes() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(CartoonTheme.buttonGradient)
                    .clipShape(Capsule())
            }

            Text("Make sure recipe server is running\nor COHERE_API_KEY is configured.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🛒").font(.system(size: 48))
            Text("Add items to your pantry first")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }

    // MARK: - Load

    private func loadRecipes() async {
        let items = store.activeProducts
        guard !items.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            recipes = try await RecipeService.generateRecipes(items: items)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Recipe Card

struct RecipeCard: View {
    let recipe: Recipe
    let index: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 10) {
                Text(recipe.emoji)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background(CartoonTheme.primary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Label(recipe.cookTime, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(recipe.difficulty)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(difficultyColor)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(CartoonTheme.primary)
                }
            }

            // Ingredients chips
            FlowLayout(spacing: 6) {
                ForEach(recipe.ingredients, id: \.self) { ingredient in
                    Text(ingredient)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CartoonTheme.primary.opacity(0.12))
                        .foregroundColor(CartoonTheme.primaryDeep)
                        .clipShape(Capsule())
                }
            }

            // Steps (expandable)
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Steps")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)

                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { stepIndex, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(stepIndex + 1)")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(CartoonTheme.primary)
                                .clipShape(Circle())

                            Text(step)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(CartoonTheme.primary.opacity(0.22), lineWidth: 1.2)
        )
        .shadow(color: CartoonTheme.primary.opacity(0.08), radius: 8, y: 4)
        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: recipe.id)
    }

    private var difficultyColor: Color {
        switch recipe.difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .secondary
        }
    }
}

// MARK: - Flow Layout for Ingredient Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
