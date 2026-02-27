import Foundation
import SwiftUI

// MARK: - Toast System (port of Notification.js)

enum ToastType: String {
    case green, yellow, red, info

    var icon: String {
        switch self {
        case .green: return "✅"
        case .yellow: return "⚠️"
        case .red: return "🚫"
        case .info: return "ℹ️"
        }
    }

    var color: Color {
        switch self {
        case .green: return .green
        case .yellow: return .orange
        case .red: return .red
        case .info: return .blue
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let type: ToastType
    let duration: TimeInterval

    init(title: String, message: String = "", type: ToastType = .info, duration: TimeInterval = 5) {
        self.title = title
        self.message = message
        self.type = type
        self.duration = duration
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class ToastManager: ObservableObject {
    @Published var toasts: [ToastMessage] = []

    func show(_ toast: ToastMessage) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            toasts.append(toast)
        }
        if toast.duration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration) { [weak self] in
                self?.dismiss(toast)
            }
        }
    }

    func show(title: String, message: String = "", type: ToastType = .info, duration: TimeInterval = 5) {
        show(ToastMessage(title: title, message: message, type: type, duration: duration))
    }

    func dismiss(_ toast: ToastMessage) {
        withAnimation(.easeOut(duration: 0.3)) {
            toasts.removeAll { $0.id == toast.id }
        }
    }
}
