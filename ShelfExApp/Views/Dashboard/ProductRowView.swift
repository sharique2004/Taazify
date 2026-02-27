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
            // Emoji
            Text(product.emoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(productStatus.status.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(product.category.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if product.quantity > 1 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text("Qty \(product.quantity)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
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
                    .background(productStatus.status.color.opacity(0.12))
                    .clipShape(Capsule())

                HStack(spacing: 6) {
                    Button {
                        onConsume()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.green)
                            .frame(width: 28, height: 28)
                            .background(Color.green.opacity(0.1))
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
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(productStatus.status.color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: productStatus.status.color.opacity(0.08), radius: 4, y: 2)
        .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.04), value: product.id)
    }
}
