import Foundation
import Vision
import UIKit

// MARK: - OCR Service (port of ocrService.js)
// Primary: Local Python server. Fallback: Apple Vision on-device OCR.

struct OCRItem {
    var originalText: String
    var name: String
    var category: String
    var emoji: String
    var confidence: String
    var isPerishable: Bool
    var quantity: Int
    var shelfDays: Int
    var price: Double?
}

struct OCRResult {
    let scanId: String
    let rawLines: [String]
    let items: [OCRItem]
}

enum OCRService {
    // MARK: - Primary: Local Python Server

    static func processWithServer(imageData: Data) async throws -> OCRResult {
        guard let url = URL(string: AppConfig.ocrServerURL) else {
            throw OCRError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180 // 3 minutes like the JS version

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OCRError.serverError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let serverItems = json["items"] as? [[String: Any]] else {
            throw OCRError.parseError
        }

        let rawLines = serverItems.compactMap { item in
            (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let items = serverItems.compactMap(mapServerItem)

        return OCRResult(
            scanId: "local-deepseek-\(Int(Date().timeIntervalSince1970))",
            rawLines: rawLines,
            items: items
        )
    }

    private static func mapServerItem(_ item: [String: Any]) -> OCRItem? {
        let name = (item["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 3 else { return nil }

        // FIRST: aggressively filter receipt junk — don't even process these
        if isReceiptJunkLine(name) { return nil }

        let result = ReceiptNormalizer.normalize(name)

        // Skip non-food items
        if result.isNonFood { return nil }

        let match = ShelfLifeDatabase.lookupProduct(result.normalized)
        let rawMatch = match.confidence != "high" ? ShelfLifeDatabase.lookupProduct(name) : match
        let bestMatch = rawMatch.confidence == "high" ? rawMatch : match

        let isKnownPantryItem = bestMatch.confidence == "high"

        // If not a known product, check if it at least looks like a product line
        // This filters out random receipt text that the server mistakenly returns
        if !isKnownPantryItem && !isLikelyProductLine(name) {
            return nil
        }

        let displayName: String
        if isKnownPantryItem {
            displayName = result.brand != nil ? "\(result.brand!) \(bestMatch.name)" : bestMatch.name
        } else if result.brand != nil && !result.normalized.isEmpty {
            displayName = "\(result.brand!) \(result.normalized)"
        } else if !result.normalized.isEmpty {
            displayName = result.normalized
        } else {
            displayName = name
        }

        let quantity = parseInt(item["quantity"]) ?? 1
        let price = parseDouble(item["price"])

        return OCRItem(
            originalText: name,
            name: displayName,
            category: isKnownPantryItem ? bestMatch.category : "other",
            emoji: isKnownPantryItem ? bestMatch.emoji : "📦",
            confidence: isKnownPantryItem ? "high" : "low",
            isPerishable: isKnownPantryItem,
            quantity: max(1, quantity),
            shelfDays: isKnownPantryItem ? bestMatch.shelfDays : (ShelfLifeDatabase.categoryDefaults["other"] ?? 7),
            price: price
        )
    }

    private static func parseInt(_ value: Any?) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let stringValue = value as? String {
            return Int(stringValue)
        }
        return nil
    }

    private static func parseDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let stringValue = value as? String {
            return Double(stringValue)
        }
        return nil
    }

    // MARK: - Fallback: Apple Vision On-Device OCR

    static func processWithVision(image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(scanId: "vision-\(Int(Date().timeIntervalSince1970))", rawLines: [], items: []))
                    return
                }

                let rawLines = observations.compactMap { $0.topCandidates(1).first?.string }
                var items: [OCRItem] = []

                for line in rawLines {
                    let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Skip short lines
                    guard cleaned.count >= 3 else { continue }

                    // AGGRESSIVE FILTERING: Skip receipt junk lines
                    if isReceiptJunkLine(cleaned) { continue }

                    // Normalize and try to match to a known product
                    let result = ReceiptNormalizer.normalize(cleaned)

                    // Skip non-food items detected by normalizer
                    if result.isNonFood { continue }

                    // Try to match against shelf-life database
                    let match = ShelfLifeDatabase.lookupProduct(result.normalized)

                    // Also try the raw text (some receipt lines match better un-normalized)
                    let rawMatch = match.confidence != "high" ? ShelfLifeDatabase.lookupProduct(cleaned) : match
                    let bestMatch = rawMatch.confidence == "high" ? rawMatch : match

                    // ONLY include items that matched a known product
                    // This is the key filter — if we don't recognize it, skip it
                    guard bestMatch.confidence == "high" else { continue }

                    let displayName = result.brand != nil ? "\(result.brand!) \(bestMatch.name)" : bestMatch.name

                    items.append(OCRItem(
                        originalText: cleaned,
                        name: displayName,
                        category: bestMatch.category,
                        emoji: bestMatch.emoji,
                        confidence: "high",
                        isPerishable: true,
                        quantity: 1,
                        shelfDays: bestMatch.shelfDays,
                        price: extractPrice(from: cleaned)
                    ))
                }

                continuation.resume(returning: OCRResult(
                    scanId: "vision-\(Int(Date().timeIntervalSince1970))",
                    rawLines: rawLines,
                    items: items
                ))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Receipt Line Filtering

    /// Returns true if the line is receipt metadata (not a product)
    private static func isReceiptJunkLine(_ line: String) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Store names and slogans
        let storePatterns = [
            "walmart", "wal-mart", "wal*mart", "target", "costco", "kroger",
            "safeway", "publix", "aldi", "trader joe", "whole foods", "sam's club",
            "meijer", "h-e-b", "heb", "winco", "food lion", "piggly wiggly",
            "wegmans", "giant eagle", "stop & shop", "stop and shop", "shoprite",
            "food city", "winn-dixie", "winn dixie", "bi-lo", "harris teeter",
            "sprouts", "fresh market", "lidl",
            "save money", "live better", "everyday low", "great prices",
            "thank you", "thanks for", "welcome to", "come again",
            "have a nice", "valued customer", "we appreciate",
            "shop smart", "low prices", "price match",
        ]
        if storePatterns.contains(where: { lower.contains($0) }) { return true }

        // 2. Addresses, cities, states, zip codes
        if lower.range(of: #"\b[A-Z]{2}\s+\d{5}"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"\d+\s+(main|elm|oak|maple|first|second|third|north|south|east|west|center|market|spring|lake|river|park|hill|valley|broad|high|church|mill|pine|cedar|washington|lincoln|jackson|jefferson)\s+(st|ave|rd|blvd|dr|ln|ct|way|pl|pkwy|hwy|cir)"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        if lower.range(of: #",\s*[a-z]{2}\s*\d{5}"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #",\s*[a-z]{2}\s*$"#, options: .regularExpression) != nil { return true }
        // Standalone zip code or state abbreviation
        if lower.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil { return true }

        // 3. Phone numbers and dates/times
        if lower.range(of: #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"\d{1,2}/\d{1,2}/\d{2,4}"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"\d{1,2}:\d{2}\s*(am|pm)?"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // ISO-style dates
        if lower.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil { return true }

        // 4. Transaction codes, store/register/receipt numbers
        let transactionPatterns = [
            "st#", "op#", "te#", "tr#", "tc#", "ref#", "seq#",
            "trn#", "reg#", "cshr", "cashier", "register",
            "receipt", "transaction", "terminal",
            "approval", "auth code", "auth#", "appr code",
            "chip read", "aid:", "tvr:", "tsi:",
            "merchant", "acct#", "card#",
        ]
        if transactionPatterns.contains(where: { lower.contains($0) }) { return true }

        // 5. Manager, clerk, associate names
        let staffPatterns = [
            "mgr", "manager", "clerk", "associate", "operator",
            "served by", "your cashier", "team member",
        ]
        if staffPatterns.contains(where: { lower.contains($0) }) { return true }

        // 6. UPC barcodes — lines that are mostly digits (>55% numeric)
        let digitCount = lower.filter(\.isNumber).count
        let totalChars = lower.filter { !$0.isWhitespace }.count
        if totalChars > 0 && Double(digitCount) / Double(totalChars) > 0.55 { return true }

        // 7. Totals, tax, payment, change
        let financialPatterns = [
            "subtotal", "sub total", "sub-total", "total", "tax", "change due",
            "tender", "cash", "credit", "debit", "visa", "mastercard",
            "amex", "discover", "ebt", "snap", "wic",
            "balance", "payment", "paid", "amount due",
            "items sold", "item(s)", "# items", "number of items",
            "change", "you saved", "your savings",
        ]
        if financialPatterns.contains(where: { lower.contains($0) }) { return true }

        // 8. Quantity/weight-only lines
        if lower.range(of: #"^[@xX]\s*\d"#, options: .regularExpression) != nil { return true }
        // Weight lines: "1.23 lb @ 2.99/lb" or "0.45 kg"
        if lower.range(of: #"\d+\.\d+\s*(lb|lbs|kg|oz)\s*(@|at)"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        // Pure weight lines: "NET WT 1.23 LB"
        if lower.range(of: #"net\s*w(t|eight)"#, options: [.regularExpression, .caseInsensitive]) != nil { return true }

        // 9. Lines with fewer than 2 letters
        let alphaCount = lower.filter(\.isLetter).count
        if alphaCount < 2 { return true }

        // 10. Very short lines (likely fragments)
        if lower.count < 4 { return true }

        // 11. Price-only lines
        if lower.range(of: #"^\$?\d+\.\d{2}$"#, options: .regularExpression) != nil { return true }
        // Negative price (refund)
        if lower.range(of: #"^-?\$?\d+\.\d{2}\s*[A-Z]?$"#, options: .regularExpression) != nil { return true }

        // 12. Lines with only special characters or codes
        if lower.range(of: #"^[*#\-=_\.]{3,}$"#, options: .regularExpression) != nil { return true }

        // 13. Loyalty cards, rewards, memberships
        let loyaltyPatterns = [
            "loyalty", "rewards", "member", "membership", "points",
            "bonus", "club card", "plus card", "advantage",
            "coupon", "promo", "promotion", "offer",
            "scan your", "download our", "download app",
        ]
        if loyaltyPatterns.contains(where: { lower.contains($0) }) { return true }

        // 14. Savings, discounts, rollbacks
        let savingsPatterns = [
            "savings", "saved", "discount", "rollback", "clearance",
            "markdown", "price reduced", "was ", "now ",
            "you save", "sale price", "reg price", "regular price",
            "price cut", "special", "% off",
        ]
        if savingsPatterns.contains(where: { lower.contains($0) }) { return true }

        // 15. Returns, refunds, voids
        let returnPatterns = [
            "return", "refund", "void", "cancel", "exchange",
            "price override", "price adj", "adjustment",
        ]
        if returnPatterns.contains(where: { lower.contains($0) }) { return true }

        // 16. URLs, email addresses
        if lower.contains("www.") || lower.contains(".com") || lower.contains(".org") || lower.contains("http") { return true }
        if lower.range(of: #"[a-z0-9]+@[a-z0-9]+\.[a-z]"#, options: .regularExpression) != nil { return true }

        // 17. Department headers and non-product labels
        let headerPatterns = [
            "department", "dept", "grocery", "produce",
            "bakery dept", "meat dept", "deli dept",
            "aisle", "shelf", "isle",
            "item not on file", "not found", "see store",
            "price inquiry", "price check",
        ]
        if headerPatterns.contains(where: { lower.contains($0) }) { return true }

        // 18. Survey, feedback
        let surveyPatterns = [
            "survey", "feedback", "tell us", "rate your",
            "how did we", "experience", "visit us",
            "enter to win", "sweepstakes", "contest",
        ]
        if surveyPatterns.contains(where: { lower.contains($0) }) { return true }

        // 19. Tax flags — lines ending with just a single tax flag letter
        // e.g. "3.99 F" or "2.49 T" or "1.00 N"
        if lower.range(of: #"^\$?\d+\.\d{2}\s+[a-z]$"#, options: .regularExpression) != nil { return true }

        // 20. Lines that are ALL CAPS single words that aren't food (likely headers)
        let words = line.trimmingCharacters(in: .whitespaces).split(separator: " ")
        if words.count == 1 && line == line.uppercased() && line.count > 3 {
            let singleWord = lower.trimmingCharacters(in: .whitespaces)
            let headerWords = ["grocery", "produce", "dairy", "frozen", "deli", "bakery",
                               "meat", "seafood", "beverages", "snacks", "household"]
            if headerWords.contains(singleWord) { return true }
        }

        return false
    }

    /// Heuristic: does this text look like a product name?
    /// Used as a last-chance filter for server OCR items that don't match the shelf-life database
    private static func isLikelyProductLine(_ line: String) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Must have at least 3 letters
        let letterCount = lower.filter(\.isLetter).count
        guard letterCount >= 3 else { return false }

        // Must have at least 2 words (most products do: "Whole Milk", "Ground Beef")
        // Single-word lines are more likely junk unless very specific
        let words = lower.split(separator: " ").filter { $0.count >= 2 }
        guard words.count >= 1 else { return false }

        // Check for food-related keywords as a positive signal
        let foodSignals = [
            "organic", "fresh", "frozen", "canned", "dried", "smoked",
            "roasted", "grilled", "baked", "fried", "steamed",
            "whole", "sliced", "diced", "chopped", "minced", "ground",
            "boneless", "skinless", "lean", "fat free", "low fat",
            "natural", "raw", "cooked", "ready to eat",
            "oz", "lb", "pack", "bag", "box", "can", "jar", "bottle",
            "ct", "count", "dozen", "bunch",
        ]
        if foodSignals.contains(where: { lower.contains($0) }) { return true }

        // Check for common brand prefixes (positive signal)
        let brandSignals = ["gv ", "mp ", "eq ", "ol ", "sg ", "gg ", "ss "]
        if brandSignals.contains(where: { lower.hasPrefix($0) }) { return true }

        // If it's mostly alpha characters (>70%) and reasonable length, allow it
        let totalNonSpace = lower.filter { !$0.isWhitespace }.count
        if totalNonSpace > 0 && Double(letterCount) / Double(totalNonSpace) > 0.7 && lower.count >= 4 {
            return true
        }

        return false
    }

    /// Try to extract a price from a receipt line
    private static func extractPrice(from line: String) -> Double? {
        // Look for patterns like "3.99", "$3.99", "3.99 F"
        guard let match = line.range(of: #"\$?(\d+\.\d{2})"#, options: .regularExpression) else { return nil }
        let priceStr = line[match].replacingOccurrences(of: "$", with: "")
        return Double(priceStr)
    }

    // MARK: - Combined: Try server first, fall back to Vision

    static func processReceipt(image: UIImage) async throws -> OCRResult {
        // Convert to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw OCRError.invalidImage
        }

        // Try Python server first
        do {
            return try await processWithServer(imageData: imageData)
        } catch {
            print("Server OCR failed, falling back to Vision: \(error)")
            // Fall back to Apple Vision
            return try await processWithVision(image: image)
        }
    }
}

enum OCRError: LocalizedError {
    case invalidURL
    case serverError
    case parseError
    case invalidImage
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid OCR server URL"
        case .serverError: return "Cannot reach OCR server. Make sure the Python server is running."
        case .parseError: return "Could not parse OCR response"
        case .invalidImage: return "Invalid image data"
        case .timeout: return "OCR timed out. Try a smaller or clearer photo."
        }
    }
}
