import SwiftUI

// MARK: - Product Row View (port of ProductCard.js)

struct ProductRowView: View {
    let product: Product
    let index: Int
    let onConsume: () -> Void
    let onToss: () -> Void

    private var productStatus: ProductStatus {
        StatusEngine.getProductStatus(product.expiryDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            PantryItemIcon(
                name: product.name,
                emoji: product.emoji,
                size: 48,
                cornerRadius: 14,
                tint: productStatus.status.color
            )

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(CartoonTheme.title)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(product.category.capitalized)
                        .font(.caption2)
                        .foregroundColor(CartoonTheme.title.opacity(0.7))
                    if product.quantity > 1 {
                        Text("·")
                            .foregroundColor(CartoonTheme.title.opacity(0.6))
                        Text("Qty \(product.quantity)")
                            .font(.caption2)
                            .foregroundColor(CartoonTheme.title.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Days Badge + Actions
            VStack(alignment: .trailing, spacing: 6) {
                Text(StatusEngine.getDaysText(productStatus.daysRemaining))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(productStatus.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(productStatus.status.color.opacity(0.18))
                    .clipShape(Capsule())

                HStack(spacing: 6) {
                    Button {
                        onConsume()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(CartoonTheme.primaryDeep)
                            .frame(width: 28, height: 28)
                            .background(CartoonTheme.primary.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Button {
                        onToss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.red)
                            .frame(width: 28, height: 28)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(14)
        .background(CartoonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(productStatus.status.color.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: productStatus.status.color.opacity(0.14), radius: 8, y: 4)
        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.04), value: product.id)
    }
}
