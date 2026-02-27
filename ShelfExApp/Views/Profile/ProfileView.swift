import SwiftUI

// MARK: - Profile View (No Auth — Hardcoded Default User)

struct ProfileView: View {
    @EnvironmentObject var store: StoreManager

    private var user: AppUser {
        AppUser(email: "user@taazify.app", name: "Taazify User")
    }

    private var allProducts: [Product] { store.products }
    private var active: [Product] { store.activeProducts }
    private var consumed: Int { allProducts.filter(\.consumed).count }
    private var wasted: Int { allProducts.filter(\.thrownAway).count }
    private var total: Int { consumed + wasted + active.count }
    private var usageRate: Int {
        total > 0 ? Int(round(Double(consumed + active.count) / Double(total) * 100)) : 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Card
                    profileCard

                    // Stats Grid
                    statsGrid

                    // Theme Toggle
                    themeToggle

                    // Grocery History
                    historySection
                }
                .padding()
                .padding(.bottom, 80)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: 16) {
            // Avatar
            Text(user.initials)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "6C63FF"), Color(hex: "8B5CF6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Basic")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .foregroundColor(.secondary)
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            ProfileStatItem(value: "\(active.count)", label: "Active", color: Color(hex: "6C63FF"))
            ProfileStatItem(value: "\(consumed)", label: "Consumed", color: .green)
            ProfileStatItem(value: "\(wasted)", label: "Wasted", color: .red)
            ProfileStatItem(value: "\(usageRate)%", label: "Usage", color: .primary)
        }
    }

    // MARK: - Theme Toggle

    private var themeToggle: some View {
        HStack {
            Image(systemName: store.prefersDarkMode ? "sun.max.fill" : "moon.fill")
                .foregroundColor(store.prefersDarkMode ? .orange : .indigo)
            Text(store.prefersDarkMode ? "Light Mode" : "Dark Mode")
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.prefersDarkMode },
                set: { _ in store.toggleTheme() }
            ))
            .labelsHidden()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Grocery Lists")
                .font(.headline)

            let history = store.groceryHistory
            if history.isEmpty {
                HStack {
                    Text("📋")
                    Text("No history yet — items appear when consumed or tossed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(history, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DateUtils.relativeDateString(group.date))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        ForEach(group.items) { item in
                            HStack(spacing: 8) {
                                Text(item.emoji)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(item.consumed ? "Used" : "Tossed")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(item.consumed ? .green : .red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background((item.consumed ? Color.green : Color.red).opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Profile Stat Item

struct ProfileStatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
