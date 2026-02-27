import Foundation

struct AppUser: Codable, Equatable {
    var id: String
    var email: String
    var name: String
    var plan: String
    var createdAt: String?

    init(
        id: String = UUID().uuidString,
        email: String,
        name: String = "User",
        plan: String = "basic",
        createdAt: String? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.plan = plan
        self.createdAt = createdAt
    }

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined()
    }
}
