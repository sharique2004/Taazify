import SwiftUI

// MARK: - Root Content View — Direct to Dashboard (No Auth Gate)

struct ContentView: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var toastManager: ToastManager
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard, shopping, scan, profile
    }

    var body: some View {
        ZStack {
            mainTabView
                .onAppear { store.initialize() }

            // Toast overlay
            VStack {
                Spacer()
                ForEach(toastManager.toasts) { toast in
                    ToastView(toast: toast) {
                        toastManager.dismiss(toast)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 100)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastManager.toasts)
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(Tab.dashboard)

            ShoppingListView()
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Cart")
                }
                .tag(Tab.shopping)

            ScanFlowView(onProductsAdded: { selectedTab = .dashboard })
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Scan")
                }
                .tag(Tab.scan)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .tint(Color(hex: "6C63FF"))
    }
}
