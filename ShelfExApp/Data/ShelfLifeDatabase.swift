import Foundation

// MARK: - USDA-based Shelf Life Database (port of shelfLife.js)

struct ShelfLifeEntry {
    let name: String
    let keywords: [String]
    let category: String
    let emoji: String
    let shelfDays: Int
}

struct ShelfLifeLookupResult {
    let name: String
    let category: String
    let emoji: String
    let shelfDays: Int
    let confidence: String
    let source: String
}

struct CategoryInfo: Identifiable {
    let name: String
    let shelfDays: Int
    var label: String { name.capitalized }
    var id: String { name }
}

enum ShelfLifeDatabase {
    // Category-level fallback shelf lives (days)
    static let categoryDefaults: [String: Int] = [
        "dairy": 7,
        "meat": 2,
        "seafood": 2,
        "fruit": 7,
        "vegetable": 7,
        "bakery": 5,
        "beverage": 10,
        "prepared": 5,
        "condiment": 60,
        "frozen": 90,
        "other": 7
    ]

    static let database: [ShelfLifeEntry] = [
        // ── Dairy ──
        ShelfLifeEntry(name: "Whole Milk", keywords: ["milk", "whole milk", "2% milk", "skim milk", "1% milk", "mlk", "pc milk", "2 pc milk"], category: "dairy", emoji: "🥛", shelfDays: 7),
        ShelfLifeEntry(name: "Heavy Cream", keywords: ["cream", "heavy cream", "whipping cream", "half and half"], category: "dairy", emoji: "🥛", shelfDays: 10),
        ShelfLifeEntry(name: "Butter", keywords: ["butter", "unsalted butter", "salted butter"], category: "dairy", emoji: "🧈", shelfDays: 30),
        ShelfLifeEntry(name: "Yogurt", keywords: ["yogurt", "greek yogurt", "yoghurt"], category: "dairy", emoji: "🥛", shelfDays: 14),
        ShelfLifeEntry(name: "Cheddar Cheese", keywords: ["cheddar", "cheddar cheese"], category: "dairy", emoji: "🧀", shelfDays: 28),
        ShelfLifeEntry(name: "Mozzarella", keywords: ["mozzarella", "fresh mozzarella"], category: "dairy", emoji: "🧀", shelfDays: 14),
        ShelfLifeEntry(name: "Cheese (Sliced)", keywords: ["cheese", "american cheese", "sliced cheese", "swiss"], category: "dairy", emoji: "🧀", shelfDays: 14),
        ShelfLifeEntry(name: "Cream Cheese", keywords: ["cream cheese", "philadelphia"], category: "dairy", emoji: "🧀", shelfDays: 14),
        ShelfLifeEntry(name: "Sour Cream", keywords: ["sour cream"], category: "dairy", emoji: "🥛", shelfDays: 14),
        ShelfLifeEntry(name: "Cottage Cheese", keywords: ["cottage cheese"], category: "dairy", emoji: "🧀", shelfDays: 7),
        ShelfLifeEntry(name: "Eggs", keywords: ["eggs", "large eggs", "egg", "dozen eggs", "egs", "wht eggs", "lg wht eggs", "mp eggs"], category: "dairy", emoji: "🥚", shelfDays: 21),

        // ── Meat & Poultry ──
        ShelfLifeEntry(name: "Chicken Breast", keywords: ["chicken", "chicken breast", "chkn", "chicken brst", "bnls sknls chkn", "ckn", "ckn brst", "rotis ckn"], category: "meat", emoji: "🍗", shelfDays: 2),
        ShelfLifeEntry(name: "Ground Beef", keywords: ["ground beef", "grnd beef", "hamburger", "beef"], category: "meat", emoji: "🥩", shelfDays: 2),
        ShelfLifeEntry(name: "Steak", keywords: ["steak", "ribeye", "sirloin", "ny strip", "filet"], category: "meat", emoji: "🥩", shelfDays: 3),
        ShelfLifeEntry(name: "Pork Chops", keywords: ["pork", "pork chops", "pork loin"], category: "meat", emoji: "🥩", shelfDays: 3),
        ShelfLifeEntry(name: "Bacon", keywords: ["bacon", "turkey bacon"], category: "meat", emoji: "🥓", shelfDays: 7),
        ShelfLifeEntry(name: "Deli Meat", keywords: ["deli", "deli meat", "turkey deli", "ham deli", "lunch meat", "salami", "prosciutto"], category: "meat", emoji: "🥩", shelfDays: 5),
        ShelfLifeEntry(name: "Hot Dogs", keywords: ["hot dog", "hot dogs", "franks", "sausage", "bratwurst"], category: "meat", emoji: "🌭", shelfDays: 7),
        ShelfLifeEntry(name: "Ground Turkey", keywords: ["ground turkey", "turkey"], category: "meat", emoji: "🍗", shelfDays: 2),

        // ── Seafood ──
        ShelfLifeEntry(name: "Fresh Salmon", keywords: ["salmon", "fresh salmon", "salmon fillet"], category: "seafood", emoji: "🐟", shelfDays: 2),
        ShelfLifeEntry(name: "Shrimp", keywords: ["shrimp", "prawns"], category: "seafood", emoji: "🦐", shelfDays: 2),
        ShelfLifeEntry(name: "Tilapia", keywords: ["tilapia", "fish", "fish fillet", "cod", "catfish"], category: "seafood", emoji: "🐟", shelfDays: 2),
        ShelfLifeEntry(name: "Crab Meat", keywords: ["crab", "crab meat"], category: "seafood", emoji: "🦀", shelfDays: 2),

        // ── Fruits ──
        ShelfLifeEntry(name: "Bananas", keywords: ["banana", "bananas", "org bnnas", "bnna", "bnn", "bnna ylw"], category: "fruit", emoji: "🍌", shelfDays: 5),
        ShelfLifeEntry(name: "Apples", keywords: ["apple", "apples", "gala", "fuji", "granny smith"], category: "fruit", emoji: "🍎", shelfDays: 21),
        ShelfLifeEntry(name: "Strawberries", keywords: ["strawberry", "strawberries", "berries"], category: "fruit", emoji: "🍓", shelfDays: 5),
        ShelfLifeEntry(name: "Blueberries", keywords: ["blueberry", "blueberries"], category: "fruit", emoji: "🫐", shelfDays: 7),
        ShelfLifeEntry(name: "Grapes", keywords: ["grape", "grapes"], category: "fruit", emoji: "🍇", shelfDays: 7),
        ShelfLifeEntry(name: "Oranges", keywords: ["orange", "oranges", "navel", "clementine", "mandarin"], category: "fruit", emoji: "🍊", shelfDays: 14),
        ShelfLifeEntry(name: "Lemons", keywords: ["lemon", "lemons", "lime", "limes"], category: "fruit", emoji: "🍋", shelfDays: 21),
        ShelfLifeEntry(name: "Avocados", keywords: ["avocado", "avocados"], category: "fruit", emoji: "🥑", shelfDays: 4),
        ShelfLifeEntry(name: "Watermelon", keywords: ["watermelon", "melon", "cantaloupe", "honeydew"], category: "fruit", emoji: "🍉", shelfDays: 5),
        ShelfLifeEntry(name: "Peaches", keywords: ["peach", "peaches", "nectarine", "plum"], category: "fruit", emoji: "🍑", shelfDays: 4),

        // ── Vegetables ──
        ShelfLifeEntry(name: "Lettuce", keywords: ["lettuce", "romaine", "iceberg", "spring mix", "salad mix", "greens"], category: "vegetable", emoji: "🥬", shelfDays: 7),
        ShelfLifeEntry(name: "Tomatoes", keywords: ["tomato", "tomatoes", "cherry tomato", "grape tomato"], category: "vegetable", emoji: "🍅", shelfDays: 7),
        ShelfLifeEntry(name: "Bell Peppers", keywords: ["bell pepper", "bell peppers", "pepper", "peppers"], category: "vegetable", emoji: "🫑", shelfDays: 10),
        ShelfLifeEntry(name: "Broccoli", keywords: ["broccoli", "broccoli florets"], category: "vegetable", emoji: "🥦", shelfDays: 5),
        ShelfLifeEntry(name: "Carrots", keywords: ["carrot", "carrots", "baby carrots"], category: "vegetable", emoji: "🥕", shelfDays: 21),
        ShelfLifeEntry(name: "Spinach", keywords: ["spinach", "baby spinach"], category: "vegetable", emoji: "🥬", shelfDays: 5),
        ShelfLifeEntry(name: "Onions", keywords: ["onion", "onions", "red onion", "yellow onion"], category: "vegetable", emoji: "🧅", shelfDays: 30),
        ShelfLifeEntry(name: "Potatoes", keywords: ["potato", "potatoes", "russet", "yukon"], category: "vegetable", emoji: "🥔", shelfDays: 21),
        ShelfLifeEntry(name: "Garlic", keywords: ["garlic"], category: "vegetable", emoji: "🧄", shelfDays: 30),
        ShelfLifeEntry(name: "Mushrooms", keywords: ["mushroom", "mushrooms", "baby bella"], category: "vegetable", emoji: "🍄", shelfDays: 5),
        ShelfLifeEntry(name: "Celery", keywords: ["celery"], category: "vegetable", emoji: "🥬", shelfDays: 14),
        ShelfLifeEntry(name: "Cucumbers", keywords: ["cucumber", "cucumbers"], category: "vegetable", emoji: "🥒", shelfDays: 7),
        ShelfLifeEntry(name: "Corn", keywords: ["corn", "corn on the cob", "sweet corn"], category: "vegetable", emoji: "🌽", shelfDays: 3),
        ShelfLifeEntry(name: "Green Beans", keywords: ["green bean", "green beans", "string beans"], category: "vegetable", emoji: "🫛", shelfDays: 5),
        ShelfLifeEntry(name: "Zucchini", keywords: ["zucchini", "squash", "yellow squash"], category: "vegetable", emoji: "🥒", shelfDays: 5),

        // ── Bakery ──
        ShelfLifeEntry(name: "White Bread", keywords: ["bread", "white bread", "wheat bread", "sandwich bread", "wonder bread", "brd", "brd wht", "wht brd"], category: "bakery", emoji: "🍞", shelfDays: 5),
        ShelfLifeEntry(name: "Tortillas", keywords: ["tortilla", "tortillas", "wraps", "flour tortilla"], category: "bakery", emoji: "🫓", shelfDays: 14),
        ShelfLifeEntry(name: "Bagels", keywords: ["bagel", "bagels"], category: "bakery", emoji: "🥯", shelfDays: 5),
        ShelfLifeEntry(name: "Muffins", keywords: ["muffin", "muffins"], category: "bakery", emoji: "🧁", shelfDays: 3),
        ShelfLifeEntry(name: "Croissants", keywords: ["croissant", "croissants", "pastry"], category: "bakery", emoji: "🥐", shelfDays: 3),

        // ── Beverages ──
        ShelfLifeEntry(name: "Orange Juice", keywords: ["orange juice", "oj", "juice"], category: "beverage", emoji: "🍊", shelfDays: 10),
        ShelfLifeEntry(name: "Almond Milk", keywords: ["almond milk", "oat milk", "soy milk", "plant milk"], category: "beverage", emoji: "🥛", shelfDays: 7),

        // ── Prepared / Deli ──
        ShelfLifeEntry(name: "Hummus", keywords: ["hummus"], category: "prepared", emoji: "🫘", shelfDays: 7),
        ShelfLifeEntry(name: "Guacamole", keywords: ["guacamole", "guac"], category: "prepared", emoji: "🥑", shelfDays: 3),
        ShelfLifeEntry(name: "Salsa (Fresh)", keywords: ["salsa", "pico de gallo", "fresh salsa"], category: "prepared", emoji: "🫙", shelfDays: 5),
        ShelfLifeEntry(name: "Tofu", keywords: ["tofu", "firm tofu", "silken tofu"], category: "prepared", emoji: "🧊", shelfDays: 5),
        ShelfLifeEntry(name: "Pasta (Fresh)", keywords: ["fresh pasta", "ravioli", "tortellini"], category: "prepared", emoji: "🍝", shelfDays: 3),

        // ── Condiments (opened) ──
        ShelfLifeEntry(name: "Ketchup", keywords: ["ketchup"], category: "condiment", emoji: "🍅", shelfDays: 60),
        ShelfLifeEntry(name: "Mayonnaise", keywords: ["mayo", "mayonnaise"], category: "condiment", emoji: "🫙", shelfDays: 60),
        ShelfLifeEntry(name: "Mustard", keywords: ["mustard"], category: "condiment", emoji: "🟡", shelfDays: 90),
    ]

    static func lookupProduct(_ receiptText: String) -> ShelfLifeLookupResult {
        let text = receiptText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var bestMatch: ShelfLifeEntry?
        var bestScore = 0

        for entry in database {
            for keyword in entry.keywords {
                if text.contains(keyword) {
                    let score = keyword.count
                    if score > bestScore {
                        bestScore = score
                        bestMatch = entry
                    }
                }
            }
        }

        if let match = bestMatch {
            return ShelfLifeLookupResult(
                name: match.name,
                category: match.category,
                emoji: match.emoji,
                shelfDays: match.shelfDays,
                confidence: "high",
                source: "USDA shelf life database"
            )
        }

        return ShelfLifeLookupResult(
            name: receiptText.trimmingCharacters(in: .whitespacesAndNewlines),
            category: "other",
            emoji: "📦",
            shelfDays: categoryDefaults["other"] ?? 7,
            confidence: "low",
            source: "default estimate"
        )
    }

    static func getCategories() -> [CategoryInfo] {
        categoryDefaults.map { CategoryInfo(name: $0.key, shelfDays: $0.value) }
            .sorted { $0.name < $1.name }
    }
}
