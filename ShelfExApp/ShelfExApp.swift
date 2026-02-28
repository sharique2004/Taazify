import SwiftUI

@main
struct ShelfExApp: App {
    @StateObject private var store = StoreManager()
    @StateObject private var toastManager = ToastManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(toastManager)
                // Cartoon theme is designed for light mode colors.
                .preferredColorScheme(.light)
        }
    }
}
