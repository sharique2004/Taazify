import SwiftUI
import PhotosUI

// MARK: - Scan Flow View (port of ScanFlow.js)

struct ScanFlowView: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var toastManager: ToastManager
    let onProductsAdded: () -> Void

    @State private var activeTab: ScanTab = .scan
    @State private var isProcessing = false
    @State private var processingStage = ""
    @State private var capturedImage: UIImage?
    @State private var allDetectedItems: [ReviewItem] = []
    @State private var detectedItems: [ReviewItem] = []
    @State private var purchaseDateStr: String = DateUtils.todayString()
    @State private var includeAll = false
    @State private var showImagePicker = false

    // Manual add
    @State private var manualName = ""
    @State private var manualCategory = "dairy"
    @State private var manualQuantity = 1
    @State private var manualPurchase = DateUtils.todayString()
    @State private var manualExpiry = DateUtils.daysFromNow(7)
    @State private var matchHint = ""
    @State private var shelfLifeHint = "💡 Estimated shelf life: 7 days (default)"

    enum ScanTab { case scan, manual }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Tab Toggle
                    tabToggle
                        .padding(.horizontal)

                    if activeTab == .scan {
                        scanTabContent
                    } else {
                        manualTabContent
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .navigationTitle("Add Products")
            .navigationBarTitleDisplayMode(.large)
            .cartoonPageBackground()
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage {
                    Task { await processImage(image) }
                }
            }
            .onChange(of: purchaseDateStr) { _, newPurchaseDate in
                refreshDetectedItemsForPurchaseDate(newPurchaseDate)
            }
        }
    }

    // MARK: - Tab Toggle

    private var tabToggle: some View {
        HStack(spacing: 0) {
            scanTabButton("📷 Scan Receipt", tab: .scan)
            scanTabButton("✏️ Add Manually", tab: .manual)
        }
        .background(CartoonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CartoonTheme.cardStroke, lineWidth: 1.2)
        )
    }

    private func scanTabButton(_ title: String, tab: ScanTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { activeTab = tab }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(activeTab == tab ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(activeTab == tab ? CartoonTheme.primary : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Scan Tab

    private var scanTabContent: some View {
        VStack(spacing: 16) {
            // Camera button / preview
            if capturedImage == nil && !isProcessing {
                cameraButton
                    .padding(.horizontal)
            }

            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .padding(.horizontal)
            }

            if isProcessing {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(processingStage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // Purchase Date
            HStack {
                Text("Purchase Date")
                    .font(.subheadline.weight(.medium))
                Spacer()
                DatePicker("", selection: Binding(
                    get: {
                        let f = DateFormatter()
                        f.dateFormat = "yyyy-MM-dd"
                        return f.date(from: purchaseDateStr) ?? Date()
                    },
                    set: { date in
                        purchaseDateStr = DateUtils.formatDateForInput(date)
                    }
                ), displayedComponents: .date)
                .labelsHidden()
            }
            .padding(.horizontal)

            // Include all toggle
            Toggle(isOn: $includeAll) {
                Text("Include all receipt lines (not just perishables)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .onChange(of: includeAll) { _, _ in
                applyFilter()
            }

            // Review items
            if !detectedItems.isEmpty {
                reviewSection
            }

            if !isProcessing && capturedImage != nil && detectedItems.isEmpty {
                noItemsState
                    .padding(.horizontal)
            }
        }
    }

    private var cameraButton: some View {
        Button {
            showImagePicker = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(CartoonTheme.primary)
                Text("Tap to take a photo of your receipt")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text("Smart Scan (OCR)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(CartoonTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(CartoonTheme.primary.opacity(0.35))
            )
        }
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Review Detected Items")
                    .font(.headline)
                Text("(\(detectedItems.count) items)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ForEach($detectedItems) { $item in
                ReviewItemRow(item: $item)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                Button {
                    addSelectedItems()
                } label: {
                    Label("Add to Dashboard", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CartoonTheme.buttonGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    resetScan()
                } label: {
                    Label("Scan Again", systemImage: "camera")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CartoonTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.horizontal)
        }
    }

    private var noItemsState: some View {
        VStack(spacing: 12) {
            Text("Did not find any pantry items")
                .font(.subheadline.weight(.semibold))
            Text("Try a clearer photo, or enable \"Include all receipt lines\"")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Show All Lines") {
                    includeAll = true
                    applyFilter()
                }
                .font(.caption.weight(.medium))

                Button("Scan Again") {
                    resetScan()
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(CartoonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(CartoonTheme.cardStroke, lineWidth: 1.2)
        )
    }

    // MARK: - Manual Tab

    private var manualTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a Product")
                .font(.headline)
                .padding(.horizontal)

            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Product Name").font(.caption.weight(.medium)).foregroundColor(.secondary)
                TextField("e.g. Whole Milk, Chicken Breast...", text: $manualName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: manualName) { _, newValue in
                        updateManualMatch(newValue)
                    }
                if !matchHint.isEmpty {
                    Text(matchHint)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // Category + Quantity
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category").font(.caption.weight(.medium)).foregroundColor(.secondary)
                    Picker("Category", selection: $manualCategory) {
                        ForEach(ShelfLifeDatabase.getCategories()) { cat in
                            Text("\(cat.label) (\(cat.shelfDays)d)").tag(cat.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: manualCategory) { _, newCat in
                        let days = ShelfLifeDatabase.categoryDefaults[newCat] ?? 7
                        manualExpiry = DateUtils.expiryDateFromCategory(purchaseDate: manualPurchase, category: newCat)
                        shelfLifeHint = "💡 Estimated shelf life: \(days) days (category default)"
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quantity").font(.caption.weight(.medium)).foregroundColor(.secondary)
                    Stepper("\(manualQuantity)", value: $manualQuantity, in: 1...99)
                }
            }
            .padding(.horizontal)

            // Dates
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Purchase Date").font(.caption.weight(.medium)).foregroundColor(.secondary)
                    DatePicker("", selection: Binding(
                        get: { dateFromString(manualPurchase) },
                        set: { newDate in
                            let purchase = DateUtils.formatDateForInput(newDate)
                            manualPurchase = purchase
                            let match = ShelfLifeDatabase.lookupProduct(manualName)
                            let shelfDays = match.confidence == "high"
                                ? match.shelfDays
                                : (ShelfLifeDatabase.categoryDefaults[manualCategory] ?? 7)
                            manualExpiry = DateUtils.expiryDateFromShelfLife(purchaseDate: purchase, shelfDays: shelfDays)
                        }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Estimated Expiry").font(.caption.weight(.medium)).foregroundColor(.secondary)
                    DatePicker("", selection: Binding(
                        get: { dateFromString(manualExpiry) },
                        set: { manualExpiry = DateUtils.formatDateForInput($0) }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }
            }
            .padding(.horizontal)

            Text(shelfLifeHint)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Add button
            Button {
                addManualProduct()
            } label: {
                Label("Add to Pantry", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(CartoonTheme.buttonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Logic

    private func processImage(_ image: UIImage) async {
        isProcessing = true
        processingStage = "Uploading image..."

        do {
            processingStage = "Running OCR..."
            let result = try await OCRService.processReceipt(image: image)

            processingStage = "Parsing items..."
            let mapped = result.items.map { item in
                let shelfDays = resolvedShelfDays(for: item)
                return ReviewItem(
                    originalText: item.originalText,
                    name: item.name,
                    category: item.category,
                    emoji: item.emoji,
                    quantity: item.quantity,
                    isPerishable: item.isPerishable,
                    confidence: item.confidence,
                    shelfDays: shelfDays,
                    purchaseDate: purchaseDateStr,
                    expiryDate: DateUtils.expiryDateFromShelfLife(purchaseDate: purchaseDateStr, shelfDays: shelfDays),
                    selected: item.isPerishable
                )
            }
            allDetectedItems = mapped
            applyFilter()

            if detectedItems.isEmpty {
                toastManager.show(title: "No pantry items found", message: "Include all lines or scan again", type: .yellow)
            } else {
                toastManager.show(title: "Scan completed", message: "\(detectedItems.count) item(s) ready for review", type: .green)
            }
        } catch {
            toastManager.show(title: "Scan failed", message: error.localizedDescription, type: .red, duration: 4)
        }

        isProcessing = false
    }

    private func applyFilter() {
        syncVisibleEditsIntoAllItems()
        detectedItems = includeAll
            ? allDetectedItems
            : allDetectedItems.filter { $0.isPerishable }
    }

    private func syncVisibleEditsIntoAllItems() {
        guard !allDetectedItems.isEmpty, !detectedItems.isEmpty else { return }
        let visibleById = Dictionary(uniqueKeysWithValues: detectedItems.map { ($0.id, $0) })
        allDetectedItems = allDetectedItems.map { visibleById[$0.id] ?? $0 }
    }

    private func resetScan() {
        capturedImage = nil
        allDetectedItems = []
        detectedItems = []
        isProcessing = false
        processingStage = ""
    }

    private func addSelectedItems() {
        let selected = detectedItems.filter { $0.selected }
        guard !selected.isEmpty else {
            toastManager.show(title: "No items selected", message: "Select at least one item to add", type: .yellow)
            return
        }

        let products = selected.map { item in
            let shelfDays = resolvedShelfDays(for: item)
            let accurateExpiry = DateUtils.expiryDateFromShelfLife(purchaseDate: item.purchaseDate, shelfDays: shelfDays)
            return Product(
                name: item.name,
                category: item.category,
                emoji: item.emoji,
                quantity: item.quantity,
                purchaseDate: item.purchaseDate,
                expiryDate: accurateExpiry
            )
        }

        store.addProducts(products)
        toastManager.show(title: "Items added", message: "\(products.count) item(s) added to dashboard", type: .green)
        let selectedIDs = Set(selected.map(\.id))
        allDetectedItems.removeAll { selectedIDs.contains($0.id) }
        detectedItems.removeAll { selectedIDs.contains($0.id) }
        if allDetectedItems.isEmpty {
            resetScan()
        } else {
            applyFilter()
        }
        onProductsAdded()
    }

    private func addManualProduct() {
        let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            toastManager.show(title: "Enter a name", message: "Product name is required", type: .red)
            return
        }

        let match = ShelfLifeDatabase.lookupProduct(name)
        let product = Product(
            name: match.confidence == "high" ? match.name : name,
            category: manualCategory,
            emoji: match.confidence == "high" ? match.emoji : "📦",
            quantity: manualQuantity,
            purchaseDate: manualPurchase,
            expiryDate: manualExpiry
        )

        store.addProducts([product])
        toastManager.show(title: "\(product.emoji) \(product.name) added", message: "Expiry: \(product.expiryDate)", type: .green)

        // Reset form
        manualName = ""
        manualQuantity = 1
        manualCategory = "dairy"
        manualPurchase = DateUtils.todayString()
        manualExpiry = DateUtils.expiryDateFromCategory(purchaseDate: manualPurchase, category: manualCategory)
        matchHint = ""
        shelfLifeHint = "💡 Estimated shelf life: 7 days (default)"
    }

    private func updateManualMatch(_ value: String) {
        guard value.count >= 2 else { matchHint = ""; return }
        let match = ShelfLifeDatabase.lookupProduct(value)
        if match.confidence != "low" {
            let prefix = match.confidence == "high" ? "✅" : "🟡"
            matchHint = "\(prefix) Matched: \(match.emoji) \(match.name) — \(match.category), ~\(match.shelfDays) days"
            manualCategory = match.category
            manualExpiry = DateUtils.expiryDateFromShelfLife(purchaseDate: manualPurchase, shelfDays: match.shelfDays)
            shelfLifeHint = "💡 Estimated shelf life: \(match.shelfDays) days (\(match.source))"
        } else {
            matchHint = "⚠️ No exact match — using category default shelf life"
        }
    }

    private func resolvedShelfDays(for item: OCRItem) -> Int {
        let byName = ShelfLifeDatabase.lookupProduct(item.name)
        if byName.confidence != "low" {
            return byName.shelfDays
        }

        let byOriginal = ShelfLifeDatabase.lookupProduct(item.originalText)
        if byOriginal.confidence != "low" {
            return byOriginal.shelfDays
        }

        if item.shelfDays > 0 {
            return item.shelfDays
        }

        return ShelfLifeDatabase.categoryDefaults[item.category] ?? (ShelfLifeDatabase.categoryDefaults["other"] ?? 7)
    }

    private func resolvedShelfDays(for item: ReviewItem) -> Int {
        let byName = ShelfLifeDatabase.lookupProduct(item.name)
        if byName.confidence != "low" {
            return byName.shelfDays
        }

        let byOriginal = ShelfLifeDatabase.lookupProduct(item.originalText)
        if byOriginal.confidence != "low" {
            return byOriginal.shelfDays
        }

        if item.shelfDays > 0 {
            return item.shelfDays
        }

        return ShelfLifeDatabase.categoryDefaults[item.category] ?? (ShelfLifeDatabase.categoryDefaults["other"] ?? 7)
    }

    private func refreshDetectedItemsForPurchaseDate(_ purchaseDate: String) {
        guard !allDetectedItems.isEmpty else { return }

        syncVisibleEditsIntoAllItems()
        allDetectedItems = allDetectedItems.map { item in
            var updated = item
            updated.purchaseDate = purchaseDate
            updated.expiryDate = DateUtils.expiryDateFromShelfLife(
                purchaseDate: purchaseDate,
                shelfDays: resolvedShelfDays(for: updated)
            )
            return updated
        }
        detectedItems = includeAll
            ? allDetectedItems
            : allDetectedItems.filter { $0.isPerishable }
    }

    private func dateFromString(_ str: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str) ?? Date()
    }
}

// MARK: - Review Item Model

struct ReviewItem: Identifiable {
    let id = UUID()
    var originalText: String
    var name: String
    var category: String
    var emoji: String
    var quantity: Int
    var isPerishable: Bool
    var confidence: String
    var shelfDays: Int
    var purchaseDate: String
    var expiryDate: String
    var selected: Bool
}

// MARK: - Review Item Row

struct ReviewItemRow: View {
    @Binding var item: ReviewItem

    private var status: ProductStatus {
        StatusEngine.getProductStatus(item.expiryDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Checkbox + Emoji + Name
            HStack(spacing: 10) {
                Button {
                    item.selected.toggle()
                } label: {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.selected ? CartoonTheme.primary : .secondary)
                        .font(.title3)
                }

                PantryItemIcon(
                    name: item.name,
                    emoji: item.emoji,
                    size: 36,
                    cornerRadius: 10,
                    tint: status.status.color
                )

                TextField("Name", text: $item.name)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
            }

            // Row 2: Category + Quantity
            HStack(spacing: 8) {
                Picker("", selection: $item.category) {
                    ForEach(ShelfLifeDatabase.getCategories()) { cat in
                        Text(cat.label).tag(cat.name)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: item.category) { _, newCat in
                    item.shelfDays = ShelfLifeDatabase.categoryDefaults[newCat] ?? 7
                    item.expiryDate = DateUtils.expiryDateFromShelfLife(
                        purchaseDate: item.purchaseDate,
                        shelfDays: item.shelfDays
                    )
                }

                Stepper("Qty: \(item.quantity)", value: $item.quantity, in: 1...99)
                    .font(.caption)
            }

            // Row 3: EXPIRY DATE — the key info the user wants
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(status.status.color)
                    .font(.caption)

                Text("Expires:")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)

                Text(DateUtils.formatDate(item.expiryDate))
                    .font(.caption.weight(.bold))
                    .foregroundColor(status.status.color)

                Text("(\(item.shelfDays) day shelf life)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                // Color-coded days remaining badge
                Text(StatusEngine.getDaysText(status.daysRemaining))
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(status.status.color.opacity(0.85))
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(CartoonTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(status.status.color.opacity(0.35), lineWidth: 1.2)
        )
        .opacity(item.selected ? 1 : 0.6)
    }
}

// MARK: - Image Picker (UIKit Bridge)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
