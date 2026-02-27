import SwiftUI

// MARK: - Toast View (port of Notification.js toast)

struct ToastView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(toast.type.color)
                .frame(width: 4)
                .padding(.vertical, 6)

            // Icon
            Text(toast.type.icon)
                .font(.title3)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                if !toast.message.isEmpty {
                    Text(toast.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Dismiss
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }
}
