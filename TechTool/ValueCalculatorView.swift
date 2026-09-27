import SwiftUI
import Combine
import AppKit

// MARK: - Measure Unit

enum MeasureUnit: String, CaseIterable, Identifiable {
    case milliliters = "мл"
    case grams = "гр"
    case pieces = "шт"

    var id: String {
        rawValue
    }

    var quantityTitle: String {
        switch self {
        case .milliliters:
            return "Объём"
        case .grams:
            return "Вес"
        case .pieces:
            return "Количество"
        }
    }

    var defaultQuantity: String {
        switch self {
        case .milliliters, .grams:
            return "100"
        case .pieces:
            return "1"
        }
    }

    var perLabel: String {
        switch self {
        case .milliliters:
            return "Цена за литр"
        case .grams:
            return "Цена за кг"
        case .pieces:
            return "Цена за штуку"
        }
    }

    var scale: Double {
        switch self {
        case .milliliters, .grams:
            return 1000
        case .pieces:
            return 1
        }
    }
}

// MARK: - Discount

enum DiscountType: String, CaseIterable {
    case percent
    case fixed
}

// MARK: - Product

struct ValueProduct: Identifiable {
    let id: UUID
    var name: String
    var priceText: String
    var volumeText: String
    var usefulness: Double
    var discountText: String
    var discountType: DiscountType
    var deliveryText: String

    init(
        id: UUID = UUID(),
        name: String,
        volumeText: String = "100",
        priceText: String = "",
        usefulness: Double = 5,
        discountText: String = "",
        discountType: DiscountType = .percent,
        deliveryText: String = ""
    ) {
        self.id = id
        self.name = name
        self.priceText = priceText
        self.volumeText = volumeText
        self.usefulness = usefulness
        self.discountText = discountText
        self.discountType = discountType
        self.deliveryText = deliveryText
    }
}

// MARK: - Formatting

private func parsedDouble(_ text: String) -> Double? {
    let normalized = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ",", with: ".")
        .replacingOccurrences(of: " ", with: "")

    return Double(normalized)
}

private func sanitizedNumericText(
    _ text: String,
    allowsDecimal: Bool = true,
    maximum: Double? = nil
) -> String {
    var result = ""
    var hasSeparator = false

    for character in text {
        if character.isNumber {
            result.append(character)
            continue
        }

        if allowsDecimal,
           (character == "," || character == "."),
           !hasSeparator {
            if result.isEmpty {
                result.append("0")
            }

            result.append(",")
            hasSeparator = true
        }
    }

    if let maximum,
       let value = parsedDouble(result),
       value > maximum {
        if maximum.rounded() == maximum {
            return String(Int(maximum))
        }

        return String(maximum)
            .replacingOccurrences(
                of: ".",
                with: ","
            )
    }

    return result
}

func formattedMoney(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = " "

    return formatter.string(from: NSNumber(value: value))
        ?? String(format: "%.2f", value)
}

// MARK: - Numeric Input

private struct NumericTextField: NSViewRepresentable {
    @Binding var text: String

    let allowsDecimal: Bool
    let maximum: Double?
    let placeholder: String
    let fontSize: CGFloat
    @Binding var isFocused: Bool

    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()

        field.delegate = context.coordinator
        field.stringValue = text
        field.placeholderString = placeholder
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.drawsBackground = true
        field.backgroundColor = NSColor.controlBackgroundColor
        field.font = NSFont.systemFont(
            ofSize: fontSize,
            weight: .medium
        )
        field.alignment = .left
        field.lineBreakMode = .byTruncatingTail
        field.focusRingType = .default
        field.controlSize = .small

        return field
    }

    func updateNSView(
        _ nsView: NSTextField,
        context: Context
    ) {
        context.coordinator.parent = self

        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if isFocused {
            if nsView.window?.firstResponder !== nsView {
                nsView.window?.makeFirstResponder(nsView)
            }
        } else {
            if nsView.window?.firstResponder === nsView {
                nsView.window?.makeFirstResponder(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NumericTextField

        init(_ parent: NumericTextField) {
            self.parent = parent
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(
                NSText.insertNewline(_:)
            ) {
                parent.isFocused = false
                parent.onSubmit?()
                return true
            }

            if commandSelector == #selector(
                NSText.cancelOperation(_:)
            ) {
                parent.isFocused = false
                parent.onEscape?()
                return true
            }

            return false
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            shouldChangeCharactersIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard let replacementString else {
                return true
            }

            let current = textView.string

            guard let range = Range(
                affectedCharRange,
                in: current
            ) else {
                return false
            }

            let proposed = current.replacingCharacters(
                in: range,
                with: replacementString
            )

            let valid = Self.isValid(
                proposed,
                allowsDecimal: parent.allowsDecimal,
                maximum: parent.maximum
            )

            if valid {
                return true
            }

            return false
        }

        func controlTextDidChange(
            _ obj: Notification
        ) {
            guard
                let field = obj.object as? NSTextField
            else {
                return
            }

            let value = field.stringValue

            guard parent.text != value else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                guard self.parent.text != value else {
                    return
                }

                self.parent.text = value
            }
        }

        private static func isValid(
            _ text: String,
            allowsDecimal: Bool,
            maximum: Double?
        ) -> Bool {
            if text.isEmpty {
                return true
            }

            var separatorCount = 0

            for character in text {
                if character.isNumber {
                    continue
                }

                if allowsDecimal,
                   character == ",",
                   separatorCount == 0 {
                    separatorCount += 1
                    continue
                }

                if allowsDecimal,
                   character == ".",
                   separatorCount == 0 {
                    separatorCount += 1
                    continue
                }

                return false
            }

            if separatorCount > 1 {
                return false
            }

            if text == "," || text == "." {
                return true
            }

            guard let maximum else {
                return true
            }

            guard let value = parsedDouble(text) else {
                return true
            }

            return value <= maximum
        }
    }
}

// MARK: - Layout

private enum ValueLayout {
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 18

    static let cardWidth: CGFloat = 330
    static let cardSpacing: CGFloat = 16
    static let cardRadius: CGFloat = 16
}

// MARK: - Calculator Model

@MainActor
final class ValueCalculatorModel: ObservableObject {
    @Published var products: [ValueProduct] = [
        ValueProduct(
            name: "Товар 1",
            volumeText: "100"
        ),
        ValueProduct(
            name: "Товар 2",
            volumeText: "100"
        ),
        ValueProduct(
            name: "Товар 3",
            volumeText: "100"
        )
    ]

    @Published var unit: MeasureUnit = .milliliters {
        didSet {
            updateDefaultQuantities()
        }
    }

    @Published var considerUsefulness = false
    @Published var sortByValue = false

    // MARK: Products

    @discardableResult
    func addProduct() -> UUID {
        let number = products.count + 1

        let product = ValueProduct(
            name: "Товар \(number)",
            volumeText: unit.defaultQuantity
        )

        products.append(product)

        return product.id
    }

    func removeProduct(_ product: ValueProduct) {
        guard products.count > 3 else {
            return
        }

        products.removeAll {
            $0.id == product.id
        }
    }

    private func updateDefaultQuantities() {
        let quantity = unit.defaultQuantity

        for index in products.indices {
            products[index].volumeText = quantity
        }
    }

    func resetAll() {
        products = [
            ValueProduct(
                name: "Товар 1",
                volumeText: unit.defaultQuantity
            ),
            ValueProduct(
                name: "Товар 2",
                volumeText: unit.defaultQuantity
            ),
            ValueProduct(
                name: "Товар 3",
                volumeText: unit.defaultQuantity
            )
        ]

        considerUsefulness = false
        sortByValue = false
    }

    // MARK: Calculations

    private func discountAmount(
        for product: ValueProduct
    ) -> Double {
        guard
            let discount = parsedDouble(
                product.discountText
            ),
            discount > 0
        else {
            return 0
        }

        switch product.discountType {
        case .percent:
            guard
                let price = parsedDouble(
                    product.priceText
                ),
                price >= 0
            else {
                return 0
            }

            return price * discount / 100

        case .fixed:
            return discount
        }
    }

    func finalPrice(
        _ product: ValueProduct
    ) -> Double? {
        guard
            let price = parsedDouble(
                product.priceText
            ),
            price >= 0
        else {
            return nil
        }

        let delivery = parsedDouble(
            product.deliveryText
        ) ?? 0

        let discount = discountAmount(
            for: product
        )

        return max(price - discount, 0)
            + max(delivery, 0)
    }

    func effectiveValue(
        _ product: ValueProduct
    ) -> Double? {
        guard
            let final = finalPrice(product),
            let quantity = parsedDouble(
                product.volumeText
            ),
            quantity > 0
        else {
            return nil
        }

        let usefulnessFactor = considerUsefulness
            ? product.usefulness / 10
            : 1

        guard usefulnessFactor > 0 else {
            return nil
        }

        return final
            / (quantity * usefulnessFactor)
            * unit.scale
    }

    // MARK: Ranking

    var rankedIDs: [UUID] {
        var values: [(UUID, Double)] = []

        for product in products {
            if let value = effectiveValue(product) {
                values.append(
                    (
                        product.id,
                        value
                    )
                )
            }
        }

        values.sort {
            $0.1 < $1.1
        }

        return values.map {
            $0.0
        }
    }

    func rank(
        for product: ValueProduct
    ) -> Int? {
        rankedIDs.firstIndex(
            of: product.id
        )
    }

    var bestValue: Double? {
        guard let bestID = rankedIDs.first else {
            return nil
        }

        guard let bestProduct = products.first(
            where: {
                $0.id == bestID
            }
        ) else {
            return nil
        }

        return effectiveValue(bestProduct)
    }

    var maxValue: Double? {
        products
            .compactMap {
                effectiveValue($0)
            }
            .max()
    }

    func isBest(
        _ product: ValueProduct
    ) -> Bool {
        guard effectiveValue(product) != nil else {
            return false
        }

        return rank(for: product) == 0
    }

    var insight: String? {
        guard let bestID = rankedIDs.first else {
            return nil
        }

        guard let bestProduct = products.first(
            where: {
                $0.id == bestID
            }
        ) else {
            return nil
        }

        guard
            let best = effectiveValue(bestProduct),
            let maximum = maxValue,
            maximum > best
        else {
            return nil
        }

        let difference = maximum - best
        let percent = difference / maximum * 100

        let name = bestProduct.name
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !name.isEmpty else {
            return nil
        }

        return "«\(name)» выгоднее на \(formattedMoney(difference)) ₽ (\(String(format: "%.1f", percent))%)"
    }
}

// MARK: - Main View

struct ValueCalculatorView: View {
    @StateObject private var model = ValueCalculatorModel()

    @State private var focusedProductID: UUID?

    private var displayedProducts: [ValueProduct] {
        guard model.sortByValue else {
            return model.products
        }

        return model.products.sorted {
            let first = model.effectiveValue($0)
            let second = model.effectiveValue($1)

            switch (first, second) {
            case let (a?, b?):
                return a < b

            case (nil, _?):
                return false

            case (_?, nil):
                return true

            case (nil, nil):
                return false
            }
        }
    }

    private var sortAnimationKey: String {
        displayedProducts
            .map { product in
                let value = model.effectiveValue(
                    product
                ) ?? -1

                return "\(product.id.uuidString)-\(value)"
            }
            .joined(separator: "|")
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)

            ScrollView(
                [
                    .horizontal,
                    .vertical
                ]
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 16
                ) {
                    productGrid

                    if let insight = model.insight {
                        insightView(insight)
                    }
                }
                .padding(
                    .horizontal,
                    ValueLayout.horizontalPadding
                )
                .padding(
                    .vertical,
                    ValueLayout.verticalPadding
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .animation(
            .spring(
                response: 0.38,
                dampingFraction: 0.84
            ),
            value: sortAnimationKey
        )
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("Сравнение товаров")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Theme.primaryText
                    )

                Text(
                    "Стоимость одинакового количества"
                )
                .font(
                    .system(size: 10)
                )
                .foregroundStyle(
                    Theme.secondaryText
                )
            }

            Spacer()

            unitPicker

            Rectangle()
                .fill(Theme.separator)
                .frame(
                    width: 1,
                    height: 28
                )

            toolbarToggle(
                title: "Учитывать пользу",
                icon: "heart.text.square",
                isOn: $model.considerUsefulness
            )

            toolbarToggle(
                title: "Сортировать",
                icon: "arrow.up.arrow.down",
                isOn: $model.sortByValue
            )

            Button {
                withAnimation(
                    .spring(
                        response: 0.3,
                        dampingFraction: 0.85
                    )
                ) {
                    model.resetAll()
                    focusedProductID = nil
                }
            } label: {
                HStack(spacing: 6) {
                    Image(
                        systemName: "eraser"
                    )

                    Text("Обнулить")
                }
                .font(
                    .system(
                        size: 10,
                        weight: .medium
                    )
                )
                .padding(
                    .horizontal,
                    10
                )
                .frame(height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(
                "Очистить расчёт и вернуть 3 товара"
            )
        }
        .padding(.horizontal, 18)
        .frame(height: 62)
    }

    private func toolbarToggle(
        title: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(
            isOn: isOn
        ) {
            Label(
                title,
                systemImage: icon
            )
            .font(
                .system(
                    size: 10,
                    weight: .medium
                )
            )
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    // MARK: Unit Picker

    private var unitPicker: some View {
        HStack(spacing: 8) {
            Text("Единица")
                .font(
                    .system(
                        size: 10,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Theme.secondaryText
                )

            Picker(
                "",
                selection: $model.unit
            ) {
                ForEach(
                    MeasureUnit.allCases
                ) { unit in
                    Text(unit.rawValue)
                        .tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 125)
        }
    }

    // MARK: Product Grid

    private var productGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .fixed(
                        ValueLayout.cardWidth
                    ),
                    spacing: ValueLayout.cardSpacing
                ),
                GridItem(
                    .fixed(
                        ValueLayout.cardWidth
                    ),
                    spacing: ValueLayout.cardSpacing
                ),
                GridItem(
                    .fixed(
                        ValueLayout.cardWidth
                    ),
                    spacing: ValueLayout.cardSpacing
                )
            ],
            alignment: .leading,
            spacing: ValueLayout.cardSpacing
        ) {
            ForEach(
                Array(
                    displayedProducts.enumerated()
                ),
                id: \.element.id
            ) { index, product in
                ProductCard(
                    product: binding(
                        for: product
                    ),
                    unit: model.unit,
                    considerUsefulness:
                        model.considerUsefulness,
                    effectiveValue:
                        model.effectiveValue(product),
                    finalPriceValue:
                        model.finalPrice(product),
                    bestValue:
                        model.bestValue,
                    rank:
                        model.rank(for: product),
                    displayPosition:
                        position(for: product),
                    canRemove:
                        model.products.count > 3,
                    autoFocusName:
                        focusedProductID == product.id,
                    onRemove: {
                        withAnimation(
                            .spring(
                                response: 0.32,
                                dampingFraction: 0.85
                            )
                        ) {
                            model.removeProduct(
                                product
                            )

                            if focusedProductID
                                == product.id {
                                focusedProductID = nil
                            }
                        }
                    },
                    onNameFocusConsumed: {
                        if focusedProductID
                            == product.id {
                            focusedProductID = nil
                        }
                    }
                )
                .id(product.id)
                .transition(
                    .asymmetric(
                        insertion:
                            .scale(
                                scale: 0.96
                            )
                            .combined(
                                with: .opacity
                            ),
                        removal:
                            .scale(
                                scale: 0.96
                            )
                            .combined(
                                with: .opacity
                            )
                    )
                )
            }

            AddProductCard {
                withAnimation(
                    .spring(
                        response: 0.32,
                        dampingFraction: 0.84
                    )
                ) {
                    let id = model.addProduct()
                    focusedProductID = id
                }
            }
        }
    }

    private func position(
        for product: ValueProduct
    ) -> Int? {
        guard model.sortByValue else {
            return model.products.firstIndex(
                where: {
                    $0.id == product.id
                }
            ).map {
                $0 + 1
            }
        }

        return model.rank(
            for: product
        ).map {
            $0 + 1
        }
    }

    // MARK: Insight

    private func insightView(
        _ text: String
    ) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(
                        Color.green.opacity(
                            0.12
                        )
                    )
                    .frame(
                        width: 26,
                        height: 26
                    )

                Image(
                    systemName: "checkmark"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    .green
                )
            }

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    "Результат сравнения"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Theme.tertiaryText
                )

                Text(text)
                    .font(
                        .system(
                            size: 11,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Theme.primaryText
                    )
            }

            Spacer()
        }
        .padding(
            .horizontal,
            12
        )
        .frame(height: 48)
        .background(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(
                Color.green.opacity(
                    0.055
                )
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                Color.green.opacity(
                    0.16
                ),
                lineWidth: 0.8
            )
        )
    }

    // MARK: Binding

    private func binding(
        for product: ValueProduct
    ) -> Binding<ValueProduct> {
        Binding(
            get: {
                model.products.first {
                    $0.id == product.id
                } ?? product
            },
            set: { newValue in
                guard let index =
                    model.products.firstIndex(
                        where: {
                            $0.id == product.id
                        }
                    )
                else {
                    return
                }

                model.products[index] = newValue
            }
        )
    }
}

// MARK: - Product Card

private struct ProductCard: View {
    @Binding var product: ValueProduct

    let unit: MeasureUnit
    let considerUsefulness: Bool
    let effectiveValue: Double?
    let finalPriceValue: Double?
    let bestValue: Double?
    let rank: Int?
    let displayPosition: Int?
    let canRemove: Bool
    let autoFocusName: Bool

    let onRemove: () -> Void
    let onNameFocusConsumed: () -> Void

    @State private var hovering = false

    @FocusState private var focusedField:
        ProductField?

    private enum ProductField: Hashable {
        case name
        case price
        case quantity
        case discount
        case delivery
    }

    private var isBest: Bool {
        effectiveValue != nil
            && rank == 0
    }

    private var percentOverBest: Double? {
        guard
            !isBest,
            let value = effectiveValue,
            let best = bestValue,
            best > 0
        else {
            return nil
        }

        return (value - best) / best * 100
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 0
        ) {
            header
                .padding(16)

            sectionDivider

            priceAndQuantity
                .padding(
                    .horizontal,
                    16
                )
                .padding(
                    .vertical,
                    14
                )

            sectionDivider

            discountAndDelivery
                .padding(
                    .horizontal,
                    16
                )
                .padding(
                    .vertical,
                    14
                )

            if considerUsefulness {
                sectionDivider

                usefulness
                    .padding(
                        .horizontal,
                        16
                    )
                    .padding(
                        .vertical,
                        14
                    )
            }

            sectionDivider

            result
                .padding(16)
        }
        .frame(
            width: ValueLayout.cardWidth
        )
        .background(
            cardBackground
        )
        .overlay(
            cardBorder
        )
        .shadow(
            color: Color.black.opacity(
                isBest ? 0.20 : 0.11
            ),
            radius: isBest ? 14 : 8,
            y: 5
        )
        .onHover { value in
            hovering = value
        }
        .animation(
            .easeInOut(duration: 0.12),
            value: hovering
        )
        .onAppear {
            if autoFocusName {
                DispatchQueue.main.async {
                    focusedField = .name
                    onNameFocusConsumed()
                }
            }
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(
                Color.white.opacity(
                    0.065
                )
            )
            .frame(height: 1)
    }

    // MARK: Card Appearance

    private var cardBackground: some View {
        RoundedRectangle(
            cornerRadius:
                ValueLayout.cardRadius,
            style: .continuous
        )
        .fill(cardFill)
    }

    private var cardFill: Color {
        if isBest {
            return Color.green.opacity(
                0.065
            )
        }

        if hovering {
            return Color.white.opacity(
                0.070
            )
        }

        return Color.white.opacity(
            0.043
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(
            cornerRadius:
                ValueLayout.cardRadius,
            style: .continuous
        )
        .stroke(
            isBest
                ? Color.green.opacity(
                    0.32
                )
                : Color.white.opacity(
                    0.095
                ),
            lineWidth:
                isBest ? 1 : 0.7
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                HStack(spacing: 7) {
                    Text("ТОВАР")
                        .font(
                            .system(
                                size: 8,
                                weight: .bold
                            )
                        )
                        .tracking(0.8)
                        .foregroundStyle(
                            Theme.tertiaryText
                        )

                    if let position =
                        displayPosition {
                        positionBadge(position)
                    }
                }

                TextField(
                    "Название товара",
                    text: $product.name
                )
                .textFieldStyle(
                    .roundedBorder
                )
                .font(
                    .system(
                        size: 13,
                        weight: .medium
                    )
                )
                .focused(
                    $focusedField,
                    equals: .name
                )
                .onSubmit {
                    focusedField = .price
                }
            }

            Spacer(
                minLength: 0
            )

            VStack(
                alignment: .trailing,
                spacing: 6
            ) {
                if isBest {
                    bestBadge
                }

                if canRemove {
                    removeButton
                }
            }
        }
    }

    private func positionBadge(
        _ position: Int
    ) -> some View {
        Text(
            String(
                format: "%02d",
                position
            )
        )
        .font(
            .system(
                size: 8,
                weight: .bold
            )
        )
        .monospacedDigit()
        .foregroundStyle(
            Theme.secondaryText
        )
        .padding(
            .horizontal,
            5
        )
        .padding(
            .vertical,
            2
        )
        .background(
            Capsule()
                .fill(
                    Color.white.opacity(
                        0.055
                    )
                )
        )
    }

    private var bestBadge: some View {
        HStack(spacing: 4) {
            Image(
                systemName:
                    "checkmark"
            )

            Text("Выгоднее")
        }
        .font(
            .system(
                size: 9,
                weight: .semibold
            )
        )
        .foregroundStyle(
            .green
        )
        .padding(
            .horizontal,
            8
        )
        .padding(
            .vertical,
            5
        )
        .background(
            Capsule()
                .fill(
                    Color.green.opacity(
                        0.12
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    Color.green.opacity(
                        0.18
                    ),
                    lineWidth: 0.6
                )
        )
    }

    private var removeButton: some View {
        Button(
            action: onRemove
        ) {
            Image(
                systemName:
                    "trash"
            )
            .font(
                .system(
                    size: 10,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Theme.secondaryText
            )
            .frame(
                width: 25,
                height: 25
            )
            .background(
                Circle()
                    .fill(
                        Color.white.opacity(
                            0.045
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .help("Удалить товар")
    }

    // MARK: Price / Quantity

    private var priceAndQuantity: some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                fieldLabel("ЦЕНА")

                NumericTextField(
                    text:
                        numericBinding(
                            for: \.priceText
                        ),
                    allowsDecimal: true,
                    maximum: nil,
                    placeholder: "0",
                    fontSize: 12,
                    isFocused:
                        focusBinding(
                            .price
                        ),
                    onSubmit: {
                        focusedField =
                            .quantity
                    },
                    onEscape: {
                        focusedField = nil
                    }
                )
            }

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                fieldLabel(
                    unit.quantityTitle
                        .uppercased()
                )

                NumericTextField(
                    text:
                        numericBinding(
                            for: \.volumeText,
                            allowsDecimal:
                                unit != .pieces
                        ),
                    allowsDecimal:
                        unit != .pieces,
                    maximum: nil,
                    placeholder:
                        unit.defaultQuantity,
                    fontSize: 12,
                    isFocused:
                        focusBinding(
                            .quantity
                        ),
                    onSubmit: {
                        focusedField =
                            .discount
                    },
                    onEscape: {
                        focusedField = nil
                    }
                )
            }
        }
    }

    // MARK: Discount / Delivery

    private var discountAndDelivery: some View {
        HStack(spacing: 12) {
            discountInput

            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                fieldLabel("ДОСТАВКА")

                NumericTextField(
                    text:
                        numericBinding(
                            for: \.deliveryText
                        ),
                    allowsDecimal: true,
                    maximum: nil,
                    placeholder: "0",
                    fontSize: 12,
                    isFocused:
                        focusBinding(
                            .delivery
                        ),
                    onSubmit: {
                        focusedField = nil
                    },
                    onEscape: {
                        focusedField = nil
                    }
                )
            }
        }
    }

    private var discountInput: some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            fieldLabel("СКИДКА")

            HStack(spacing: 5) {
                NumericTextField(
                    text:
                        discountBinding,
                    allowsDecimal:
                        product.discountType
                            == .percent,
                    maximum:
                        product.discountType
                            == .percent
                            ? 100
                            : nil,
                    placeholder: "0",
                    fontSize: 12,
                    isFocused:
                        focusBinding(
                            .discount
                        ),
                    onSubmit: {
                        focusedField =
                            .delivery
                    },
                    onEscape: {
                        focusedField = nil
                    }
                )

                Picker(
                    "",
                    selection:
                        $product.discountType
                ) {
                    Text("%")
                        .tag(
                            DiscountType
                                .percent
                        )

                    Text("₽")
                        .tag(
                            DiscountType
                                .fixed
                        )
                }
                .pickerStyle(
                    .segmented
                )
                .frame(width: 58)
                .onChange(
                    of:
                        product.discountType
                ) {
                    let current =
                        product.discountText

                    product.discountText =
                        sanitizedNumericText(
                            current,
                            allowsDecimal:
                                product
                                    .discountType
                                    == .percent,
                            maximum:
                                product
                                    .discountType
                                    == .percent
                                    ? 100
                                    : nil
                        )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: Usefulness

    private var usefulness: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack {
                HStack(spacing: 6) {
                    Image(
                        systemName:
                            "heart.fill"
                    )
                    .font(
                        .system(
                            size: 9,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.pink.opacity(
                            0.85
                        )
                    )

                    Text("Польза")
                        .font(
                            .system(
                                size: 10,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Theme.secondaryText
                        )
                }

                Spacer()

                Text(
                    "\(Int(product.usefulness)) из 10"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Theme.primaryText
                )
            }

            Slider(
                value:
                    $product.usefulness,
                in: 1...10,
                step: 1
            )
        }
    }

    // MARK: Result

    private var result: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack(
                alignment: .bottom
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        unit.perLabel
                    )
                    .font(
                        .system(
                            size: 9,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Theme.secondaryText
                    )

                    resultValue
                }

                Spacer()

                resultStatus
            }

            if let value =
                effectiveValue,
               let best =
                bestValue,
               !isBest,
               best > 0 {
                let difference =
                    max(
                        value - best,
                        0
                    )

                Text(
                    "Переплата \(formattedMoney(difference)) ₽"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Theme.secondaryText
                )
            }

            if let final =
                finalPriceValue {
                resultDetails(
                    final
                )
            } else {
                Text(
                    "Введите цену, чтобы рассчитать стоимость"
                )
                .font(
                    .system(size: 9)
                )
                .foregroundStyle(
                    Theme.tertiaryText
                )
            }
        }
    }

    private var resultValue: some View {
        Group {
            if let value =
                effectiveValue {
                Text(
                    "\(formattedMoney(value)) ₽"
                )
                .font(
                    .system(
                        size: 21,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    isBest
                        ? Color.green
                        : Theme.primaryText
                )
            } else {
                Text("—")
                    .font(
                        .system(
                            size: 21,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Theme.tertiaryText
                    )
            }
        }
    }

    private func resultDetails(
        _ final: Double
    ) -> some View {
        HStack(spacing: 4) {
            Text(
                "Итого \(formattedMoney(final)) ₽"
            )

            if let quantity =
                parsedDouble(
                    product.volumeText
                ),
               quantity > 0 {
                Text("·")

                Text(
                    "\(formattedQuantity(quantity)) \(unit.rawValue)"
                )
            }
        }
        .font(
            .system(size: 9)
        )
        .foregroundStyle(
            Theme.tertiaryText
        )
    }

    private func formattedQuantity(
        _ value: Double
    ) -> String {
        if value.rounded() == value {
            return String(
                Int(value)
            )
        }

        return String(
            format: "%.2f",
            value
        )
        .replacingOccurrences(
            of: ".",
            with: ","
        )
    }

    private var resultStatus: some View {
        Group {
            if isBest {
                VStack(
                    alignment: .trailing,
                    spacing: 3
                ) {
                    Image(
                        systemName:
                            "checkmark.circle.fill"
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .green
                    )

                    Text("ЛУЧШИЙ")
                        .font(
                            .system(
                                size: 7,
                                weight: .bold
                            )
                        )
                        .tracking(0.7)
                        .foregroundStyle(
                            .green
                        )
                }
            } else if let percent =
                percentOverBest {
                VStack(
                    alignment: .trailing,
                    spacing: 3
                ) {
                    Text(
                        "+\(String(format: "%.0f", percent))%"
                    )
                    .font(
                        .system(
                            size: 11,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .orange
                    )

                    Text("к лучшему")
                        .font(
                            .system(size: 7)
                        )
                        .foregroundStyle(
                            Theme.tertiaryText
                        )
                }
            }
        }
    }

    // MARK: Bindings

    private func numericBinding(
        for keyPath:
            WritableKeyPath<
                ValueProduct,
                String
            >,
        allowsDecimal: Bool = true
    ) -> Binding<String> {
        Binding(
            get: {
                product[keyPath: keyPath]
            },
            set: { value in
                product[keyPath: keyPath] =
                    sanitizedNumericText(
                        value,
                        allowsDecimal:
                            allowsDecimal
                    )
            }
        )
    }

    private var discountBinding:
        Binding<String> {
        Binding(
            get: {
                product.discountText
            },
            set: { value in
                product.discountText =
                    sanitizedNumericText(
                        value,
                        allowsDecimal:
                            product.discountType
                            == .percent,
                        maximum:
                            product.discountType
                            == .percent
                            ? 100
                            : nil
                    )
            }
        )
    }

    private func focusBinding(
        _ field: ProductField
    ) -> Binding<Bool> {
        Binding(
            get: {
                focusedField == field
            },
            set: { focused in
                if focused {
                    focusedField = field
                } else if focusedField == field {
                    focusedField = nil
                }
            }
        )
    }

    // MARK: Helpers

    private func fieldLabel(
        _ text: String
    ) -> some View {
        Text(text)
            .font(
                .system(
                    size: 8,
                    weight: .bold
                )
            )
            .tracking(0.7)
            .foregroundStyle(
                Theme.tertiaryText
            )
    }
}

// MARK: - Add Product Card

private struct AddProductCard: View {
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(
            action: action
        ) {
            VStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(
                            Color.white.opacity(
                                hovering
                                    ? 0.09
                                    : 0.055
                            )
                        )
                        .frame(
                            width: 46,
                            height: 46
                        )

                    Image(
                        systemName:
                            "plus"
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .medium
                        )
                    )
                }

                Text(
                    "Добавить товар"
                )
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )

                Text(
                    "Ещё один вариант для сравнения"
                )
                .font(
                    .system(size: 9)
                )
                .foregroundStyle(
                    Theme.tertiaryText
                )
            }
            .foregroundStyle(
                hovering
                    ? Theme.primaryText
                    : Theme.secondaryText
            )
            .frame(
                width:
                    ValueLayout.cardWidth,
                height: 250
            )
            .background(
                RoundedRectangle(
                    cornerRadius:
                        ValueLayout.cardRadius,
                    style: .continuous
                )
                .fill(
                    hovering
                        ? Color.white.opacity(
                            0.065
                        )
                        : Color.white.opacity(
                            0.035
                        )
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius:
                        ValueLayout.cardRadius,
                    style: .continuous
                )
                .stroke(
                    hovering
                        ? Color.white.opacity(
                            0.18
                        )
                        : Color.white.opacity(
                            0.09
                        ),
                    style:
                        StrokeStyle(
                            lineWidth: 1,
                            dash: [5, 5]
                        )
                )
            )
        }
        .buttonStyle(.plain)
        .onHover { value in
            hovering = value
        }
        .animation(
            .easeInOut(
                duration: 0.12
            ),
            value: hovering
        )
    }
}
