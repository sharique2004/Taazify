import Foundation

// MARK: - Receipt Text Normalizer (port of receiptNormalizer.js)

enum ReceiptNormalizer {
    // Brand abbreviation map
    private static let brandMap: [String: String] = [
        "gv": "Great Value",
        "g&g": "Good & Gather",
        "eq": "Equate",
        "sam": "Sam's Choice",
        "mm": "Market Pantry",
        "mp": "Market Pantry",
        "up&up": "up & up",
        "cat&jack": "Cat & Jack",
        "thresh": "Threshold",
        "ol": "O'Organics",
        "sig sel": "Signature Select",
        "kcup": "K-Cup",
        "ev": "Essential Value",
    ]

    // Common POS abbreviations → full words
    private static let abbreviations: [String: String] = [
        // Proteins
        "ckn": "chicken", "chkn": "chicken", "chn": "chicken",
        "bfst": "breakfast", "bf": "beef", "grnd": "ground",
        "bnls": "boneless", "sknls": "skinless", "brst": "breast",
        "pork": "pork", "trky": "turkey", "ssg": "sausage",
        "bac": "bacon", "frnk": "franks", "hotdg": "hot dog",
        // Dairy
        "mlk": "milk", "eg": "eggs", "egs": "eggs",
        "chs": "cheese", "chz": "cheese",
        "ygt": "yogurt", "yogt": "yogurt",
        "btr": "butter", "marg": "margarine",
        "crm": "cream", "sr crm": "sour cream",
        "cttg": "cottage",
        // Produce
        "bnna": "banana", "bnn": "banana",
        "apl": "apple", "apls": "apples",
        "tmto": "tomato", "tom": "tomato",
        "ltc": "lettuce", "lett": "lettuce",
        "pot": "potato", "ptto": "potato",
        "onn": "onion", "oni": "onion",
        "grn": "green", "grns": "greens",
        "crrt": "carrot", "crts": "carrots",
        "brcc": "broccoli", "broc": "broccoli",
        "spnch": "spinach", "spn": "spinach",
        "celry": "celery", "cel": "celery",
        "cucu": "cucumber", "cuc": "cucumber",
        "avcd": "avocado", "avo": "avocado",
        "strw": "strawberry", "strwb": "strawberry",
        "blub": "blueberry", "blue": "blueberry",
        "grp": "grape", "grps": "grapes",
        "org": "organic", "orng": "orange",
        "lmn": "lemon", "wtmln": "watermelon",
        "mush": "mushroom", "mshrm": "mushroom",
        "ppr": "pepper", "pprs": "peppers",
        "zuch": "zucchini", "sqsh": "squash",
        "corn": "corn", "bn": "bean", "bns": "beans",
        // Bakery
        "brd": "bread", "wht": "white", "whl": "whole",
        "bgl": "bagel", "bgls": "bagels",
        "trtla": "tortilla", "tort": "tortilla",
        "mfn": "muffin", "crssnt": "croissant",
        "rl": "roll", "rls": "rolls", "bun": "bun", "buns": "buns",
        // Beverages
        "jc": "juice", "oj": "orange juice",
        "wtr": "water", "sda": "soda",
        "coff": "coffee", "cfe": "coffee",
        // Frozen
        "frz": "frozen", "frzn": "frozen",
        "ic crm": "ice cream", "pzza": "pizza",
        // Units
        "oz": "oz", "lb": "lb", "ct": "count",
        "pk": "pack", "ea": "each", "gal": "gallon",
        "qt": "quart", "pt": "pint", "dz": "dozen",
        // Sizes
        "sm": "small", "md": "medium", "lg": "large",
        "xl": "extra large",
        // Descriptors
        "frsh": "fresh", "nat": "natural", "lite": "light",
        "lo": "low", "ff": "fat free", "rf": "reduced fat",
        "ss": "seedless", "ripe": "ripe",
        "slcd": "sliced", "shrd": "shredded",
        "cnd": "canned", "dryd": "dried",
    ]

    static let nonFoodKeywords: [String] = [
        // Clothing & Apparel
        "clothing", "apparel", "shirt", "pants", "shorts", "cargo", "danskin", "dnzn",
        "shoes", "socks", "underwear", "bra", "jacket", "coat", "dress", "skirt",
        "hoodie", "sweater", "vest", "jeans", "blouse", "leggings",
        // Household & Cleaning
        "household", "cleaning", "detergent", "bleach", "wipes", "trash",
        "paper", "towel", "tissue", "napkin", "plate", "cup", "foil", "wrap",
        "sponge", "mop", "broom", "vacuum", "lysol", "clorox", "ajax",
        "glad", "hefty", "ziploc", "reynolds", "bounty", "charmin", "scott",
        // Electronics
        "batteries", "charger", "cable", "electronics", "phone", "hdmi",
        "usb", "adapter", "headphone", "earbuds", "speaker",
        // Health & Beauty
        "health", "beauty", "cosmetics", "shampoo", "conditioner", "lotion",
        "toothpaste", "toothbrush", "deodorant", "razor", "floss",
        "sonicare", "aquaf", "bissell", "tampax", "kotex", "always",
        "bandaid", "band-aid", "tylenol", "advil", "ibuprofen", "aspirin",
        "medicine", "supplement", "vitamin", "prescription",
        // Home & Decor
        "cat&jack", "thresh", "home", "decor", "furniture", "candle",
        "curtain", "pillow", "blanket", "rug", "frame", "lamp",
        // Toys & Entertainment
        "toy", "game", "book", "dvd", "cd", "puzzle", "lego",
        // Pet Supplies
        "dog food", "cat food", "pet", "purina", "pedigree", "meow mix",
        "cat litter", "kitty litter", "pet treat", "flea", "collar",
        // Auto & Hardware
        "motor oil", "antifreeze", "windshield", "auto", "hardware",
        "bolt", "screw", "nail", "tape measure", "drill",
        // Office
        "office", "pen", "pencil", "notebook", "folder", "staple",
        "printer", "ink", "toner", "envelope",
        // Sports & Outdoor
        "sports", "athletic", "fitness", "exercise", "weights",
        // Baby (non-food)
        "diaper", "wipes", "pacifier", "bottle nipple", "huggies", "pampers",
        // Garden
        "garden", "plant", "soil", "fertilizer", "seed", "pot",
        // Seasonal
        "halloween", "christmas", "easter", "valentine",
    ]

    struct NormalizeResult {
        let normalized: String
        let brand: String?
        let isNonFood: Bool
    }

    static func normalize(_ rawText: String) -> NormalizeResult {
        guard !rawText.isEmpty else {
            return NormalizeResult(normalized: "", brand: nil, isNonFood: false)
        }

        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove item numbers, UPCs at the start
        if let range = text.range(of: #"^\d{6,}"#, options: .regularExpression) {
            text = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Remove trailing price indicators
        if let range = text.range(of: #"\s+[FNCT]{1,2}\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        let tokens = text.split(separator: " ").map(String.init)
        var brand: String?
        var startIdx = 0

        // Check if first token(s) are a known brand
        if tokens.count >= 2 {
            let firstTwo = tokens[0...1].joined(separator: " ").lowercased()
            if let b = brandMap[firstTwo] {
                brand = b
                startIdx = 2
            }
        }
        if brand == nil, let first = tokens.first {
            let lower = first.lowercased()
            if let b = brandMap[lower] {
                brand = b
                startIdx = 1
            }
        }

        // Expand abbreviations
        let expanded = tokens[startIdx...].compactMap { token -> String? in
            let lower = token.lowercased()
            // Skip pure numeric tokens
            if Double(token) != nil { return nil }
            return abbreviations[lower] ?? token
        }

        let normalized = expanded.joined(separator: " ")

        // Check if non-food
        let fullLower = (rawText + " " + normalized).lowercased()
        let isNonFood = nonFoodKeywords.contains { fullLower.contains($0) }

        return NormalizeResult(normalized: normalized, brand: brand, isNonFood: isNonFood)
    }
}
