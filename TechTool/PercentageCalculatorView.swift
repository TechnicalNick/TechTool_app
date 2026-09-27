import SwiftUI
import AppKit

// MARK: - Calculator Mode

private enum PercentageCalculatorMode: String, CaseIterable, Identifiable {
    case percentage = "Процент"
    case change = "Изменение"
    case ndfl = "НДФЛ"

    var id: String {
        rawValue
    }
}

// MARK: - Change Direction

private enum ChangeDirection: String, CaseIterable, Identifiable {
    case increase = "Увеличить"
    case decrease = "Уменьшить"

    var id: String {
        rawValue
    }
}

// MARK: - NDFL Direction

private enum NDFLDirection: String, CaseIterable, Identifiable {
    case grossToNet = "До вычета → на руки"
    case netToGross = "На руки → до вычета"

    var id: String {
        rawValue
    }
}

// MARK: - NDFL Period

private enum NDFLPeriod: String, CaseIterable, Identifiable {
    case month = "Месяц"
    case year = "Год"

    var id: String {
        rawValue
    }
}

// MARK: - NDFL Calculation

private struct NDFLResult {
    let gross: Double
    let tax: Double
    let net: Double
    let effectiveRate: Double
}

// MARK: - Formatting

private func percentageParsedDouble(_ text: String) -> Double? {
    let normalized = text
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ",", with: ".")

    return Double(normalized)
}

private func percentageFormattedMoney(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = " "
    formatter.decimalSeparator = ","

    return formatter.string(
        from: NSNumber(value: value)
    ) ?? String(format: "%.2f", value)
}

private func percentageFormattedNumber(_ value: Double) -> String {
    if value.rounded() == value {
        return percentageFormattedMoney(value)
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = " "
    formatter.decimalSeparator = ","

    return formatter.string(
        from: NSNumber(value: value)
    ) ?? String(format: "%.2f", value)
}

// Форматирует текст поля:
// 1000 -> 1 000
// 10000 -> 10 000
// 1234567,89 -> 1 234 567,89
private func percentageFormattedInput(_ text: String) -> String {
    guard !text.isEmpty else {
        return ""
    }

    let cleaned = text
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: ".", with: ",")

    guard !cleaned.isEmpty else {
        return ""
    }

    let components = cleaned.split(
        separator: ",",
        omittingEmptySubsequences: false
    )

    let integerPart = String(components.first ?? "")
    let decimalPart: String? = components.count > 1
        ? String(components[1])
        : nil

    guard !integerPart.isEmpty else {
        if decimalPart != nil {
            return "0," + (decimalPart ?? "")
        }

        return ""
    }

    let integerNumber = Int(integerPart) ?? 0

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.groupingSeparator = " "
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0

    let formattedInteger = formatter.string(
        from: NSNumber(value: integerNumber)
    ) ?? integerPart

    if let decimalPart {
        return "\(formattedInteger),\(decimalPart)"
    }

    return formattedInteger
}

// MARK: - Native Numeric Field

private struct PercentageNumericField: NSViewRepresentable {
    @Binding var text: String

    let allowsDecimal: Bool
    let maximum: Double?
    let placeholder: String

    @Binding var isFocused: Bool

    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(
        context: Context
    ) -> NSTextField {
        let field = NSTextField()

        field.delegate = context.coordinator
        field.stringValue = text
        field.placeholderString = placeholder

        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.backgroundColor = NSColor.controlBackgroundColor

        field.font = NSFont.systemFont(
            ofSize: 13,
            weight: .medium
        )

        field.alignment = .left
        field.focusRingType = .default
        field.controlSize = .small

        return field
    }

    func updateNSView(
        _ nsView: NSTextField,
        context: Context
    ) {
        context.coordinator.parent = self

        let formattedText = percentageFormattedInput(text)

        if nsView.stringValue != formattedText {
            nsView.stringValue = formattedText
        }

        if isFocused {
            if nsView.window?.firstResponder !== nsView {
                DispatchQueue.main.async {
                    nsView.window?.makeFirstResponder(nsView)
                }
            }
        } else if nsView.window?.firstResponder === nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PercentageNumericField

        init(
            _ parent: PercentageNumericField
        ) {
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

            return Self.isValid(
                proposed,
                allowsDecimal: parent.allowsDecimal,
                maximum: parent.maximum
            )
        }

        func controlTextDidChange(
            _ obj: Notification
        ) {
            guard let field = obj.object as? NSTextField else {
                return
            }

            let rawValue = field.stringValue

            guard Self.isValid(
                rawValue,
                allowsDecimal: parent.allowsDecimal,
                maximum: parent.maximum
            ) else {
                return
            }

            let formattedValue = percentageFormattedInput(rawValue)

            if field.stringValue != formattedValue {
                let selectedRange = field.currentEditor()?.selectedRange

                field.stringValue = formattedValue

                // После автоматического форматирования
                // возвращаем курсор в конец.
                if let editor = field.currentEditor() {
                    let end = formattedValue.count

                    editor.setSelectedRange(
                        NSRange(
                            location: end,
                            length: 0
                        )
                    )

                    _ = selectedRange
                }
            }

            guard parent.text != formattedValue else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                guard self.parent.text != formattedValue else {
                    return
                }

                self.parent.text = formattedValue
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

                // Разрешаем пробелы как разделители тысяч.
                if character == " " {
                    continue
                }

                if allowsDecimal,
                   (character == "," || character == "."),
                   separatorCount == 0 {
                    separatorCount += 1
                    continue
                }

                return false
            }

            if separatorCount > 1 {
                return false
            }

            let normalized = text
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")

            if normalized == "." ||
                normalized.isEmpty {
                return true
            }

            guard
                let maximum,
                let value = Double(normalized)
            else {
                return true
            }

            return value <= maximum
        }
    }
}

// MARK: - Main View

struct PercentageCalculatorView: View {
    @State private var mode: PercentageCalculatorMode = .percentage

    @State private var percentageText = "10"

    @State private var numberText = "100 000"

    @State private var changeText = "10"

    @State private var changeDirection: ChangeDirection = .increase

    @State private var ndflText = "100 000"

    @State private var ndflDirection: NDFLDirection = .grossToNet

    @State private var ndflPeriod: NDFLPeriod = .month

    @State private var focusedField: Field?

    private enum Field: Hashable {
        case percentage
        case number
        case change
        case ndfl
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)

            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {
                    calculator
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            VStack(
                alignment: .leading,
                spacing: 3
            ) {
                Text("Проценты и НДФЛ")
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Theme.primaryText
                    )

                Text(toolbarSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(
                        Theme.secondaryText
                    )
            }

            Spacer()

            Button {
                reset()
            } label: {
                HStack(spacing: 6) {
                    Image(
                        systemName: "arrow.counterclockwise"
                    )

                    Text("Сбросить")
                }
                .font(
                    .system(
                        size: 10,
                        weight: .medium
                    )
                )
                .padding(.horizontal, 10)
                .frame(height: 30)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .frame(height: 62)
    }

    private var toolbarSubtitle: String {
        switch mode {
        case .percentage:
            return "Быстрый расчёт процентов от любой суммы"

        case .change:
            return "Увеличение и уменьшение суммы на процент"

        case .ndfl:
            return "Расчёт суммы до и после НДФЛ"
        }
    }

    // MARK: Calculator

    private var calculator: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            modePicker

            switch mode {
            case .percentage:
                percentageCalculator

            case .change:
                changeCalculator

            case .ndfl:
                ndflCalculator
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(
                PercentageCalculatorMode.allCases
            ) { item in
                Button {
                    withAnimation(
                        .easeInOut(duration: 0.16)
                    ) {
                        mode = item
                        focusedField = nil
                    }
                } label: {
                    Text(item.rawValue)
                        .font(
                            .system(
                                size: 11,
                                weight:
                                    mode == item
                                    ? .semibold
                                    : .medium
                            )
                        )
                        .foregroundStyle(
                            mode == item
                                ? Theme.primaryText
                                : Theme.secondaryText
                        )
                        .padding(
                            .horizontal,
                            13
                        )
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(
                                    mode == item
                                        ? Color.white.opacity(0.11)
                                        : Color.white.opacity(0.045)
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    mode == item
                                        ? Color.white.opacity(0.15)
                                        : Color.clear,
                                    lineWidth: 0.7
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Percentage

    private var percentageCalculator: some View {
        calculatorCard {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                cardTitle(
                    title: "Процент от числа",
                    subtitle:
                        "Узнай, сколько составляет заданный процент от любой суммы"
                )

                HStack(spacing: 14) {
                    inputBlock(
                        title: "ПРОЦЕНТ",
                        suffix: "%",
                        field: .percentage,
                        text: $percentageText,
                        allowsDecimal: true,
                        maximum: nil
                    )

                    inputBlock(
                        title: "ЧИСЛО",
                        suffix: "₽",
                        field: .number,
                        text: $numberText,
                        allowsDecimal: true,
                        maximum: nil
                    )
                }

                resultBlock(
                    label:
                        "\(percentageText.isEmpty ? "0" : percentageText)% от \(numberText.isEmpty ? "0" : numberText)",
                    value:
                        percentageResultText
                )

                formulaBlock(
                    percentageFormula
                )
            }
        }
    }

    private var percentageResultText: String {
        guard
            let percentage =
                percentageParsedDouble(
                    percentageText
                ),
            let number =
                percentageParsedDouble(
                    numberText
                )
        else {
            return "—"
        }

        let result =
            number * percentage / 100

        return "\(percentageFormattedMoney(result)) ₽"
    }

    private var percentageFormula: String {
        guard
            let percentage =
                percentageParsedDouble(
                    percentageText
                ),
            let number =
                percentageParsedDouble(
                    numberText
                )
        else {
            return "Процент × число ÷ 100"
        }

        let result =
            number * percentage / 100

        return "\(percentageFormattedNumber(percentage))% × \(percentageFormattedMoney(number)) ÷ 100 = \(percentageFormattedMoney(result))"
    }

    // MARK: Change

    private var changeCalculator: some View {
        calculatorCard {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                cardTitle(
                    title: "Изменение суммы",
                    subtitle:
                        "Увеличь или уменьши число на заданный процент"
                )

                HStack(spacing: 14) {
                    inputBlock(
                        title: "ЧИСЛО",
                        suffix: "₽",
                        field: .number,
                        text: $numberText,
                        allowsDecimal: true,
                        maximum: nil
                    )

                    VStack(
                        alignment: .leading,
                        spacing: 7
                    ) {
                        fieldLabel("ДЕЙСТВИЕ")

                        Picker(
                            "",
                            selection:
                                $changeDirection
                        ) {
                            ForEach(
                                ChangeDirection.allCases
                            ) { direction in
                                Text(
                                    direction.rawValue
                                )
                                .tag(direction)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 170)
                    }

                    inputBlock(
                        title: "ПРОЦЕНТ",
                        suffix: "%",
                        field: .change,
                        text: $changeText,
                        allowsDecimal: true,
                        maximum: nil
                    )
                }

                resultBlock(
                    label:
                        changeDirection == .increase
                        ? "После увеличения"
                        : "После уменьшения",
                    value:
                        changeResultText
                )

                if let details = changeDetails {
                    HStack(spacing: 6) {
                        Text(
                            changeDirection == .increase
                            ? "Прибавится"
                            : "Уменьшится"
                        )

                        Text(details)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(
                        Theme.secondaryText
                    )
                }
            }
        }
    }

    private var changeResultText: String {
        guard
            let number =
                percentageParsedDouble(
                    numberText
                ),
            let percentage =
                percentageParsedDouble(
                    changeText
                )
        else {
            return "—"
        }

        let delta =
            number * percentage / 100

        let result: Double

        switch changeDirection {
        case .increase:
            result = number + delta

        case .decrease:
            result = number - delta
        }

        return "\(percentageFormattedMoney(result)) ₽"
    }

    private var changeDetails: String? {
        guard
            let number =
                percentageParsedDouble(
                    numberText
                ),
            let percentage =
                percentageParsedDouble(
                    changeText
                )
        else {
            return nil
        }

        let delta =
            number * percentage / 100

        return "\(percentageFormattedMoney(delta)) ₽"
    }

    // MARK: NDFL

    private var ndflCalculator: some View {
        calculatorCard {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                cardTitle(
                    title: "НДФЛ",
                    subtitle:
                        "Расчёт зарплаты до и после налога по прогрессивной шкале"
                )

                HStack(spacing: 10) {
                    directionButton(
                        title:
                            "До вычета → на руки",
                        selected:
                            ndflDirection == .grossToNet
                    ) {
                        ndflDirection =
                            .grossToNet
                    }

                    directionButton(
                        title:
                            "На руки → до вычета",
                        selected:
                            ndflDirection == .netToGross
                    ) {
                        ndflDirection =
                            .netToGross
                    }

                    Spacer()

                    Picker(
                        "",
                        selection:
                            $ndflPeriod
                    ) {
                        ForEach(
                            NDFLPeriod.allCases
                        ) { period in
                            Text(
                                period.rawValue
                            )
                            .tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 145)
                }

                inputBlock(
                    title:
                        ndflDirection == .grossToNet
                        ? "СУММА ДО НДФЛ"
                        : "СУММА НА РУКИ",
                    suffix: "₽",
                    field: .ndfl,
                    text: $ndflText,
                    allowsDecimal: true,
                    maximum: nil
                )

                if let result = ndflResult {
                    ndflResultView(result)
                }

                ndflScale
            }
        }
    }

    private var ndflResult: NDFLResult? {
        guard
            let input =
                percentageParsedDouble(
                    ndflText
                ),
            input >= 0
        else {
            return nil
        }

        switch ndflDirection {
        case .grossToNet:
            return calculateGrossToNet(input)

        case .netToGross:
            return calculateNetToGross(input)
        }
    }

    // MARK: NDFL Math

    private func ndflForAnnualIncome(
        _ income: Double
    ) -> Double {
        guard income > 0 else {
            return 0
        }

        let firstLimit =
            2_400_000.0

        let secondLimit =
            5_000_000.0

        let thirdLimit =
            20_000_000.0

        let fourthLimit =
            50_000_000.0

        if income <= firstLimit {
            return income * 0.13
        }

        if income <= secondLimit {
            return 312_000
                + (income - firstLimit)
                * 0.15
        }

        if income <= thirdLimit {
            return 702_000
                + (income - secondLimit)
                * 0.18
        }

        if income <= fourthLimit {
            return 3_402_000
                + (income - thirdLimit)
                * 0.20
        }

        return 9_402_000
            + (income - fourthLimit)
            * 0.22
    }

    private func calculateGrossToNet(
        _ input: Double
    ) -> NDFLResult {
        let annualGross: Double

        switch ndflPeriod {
        case .month:
            annualGross =
                input * 12

        case .year:
            annualGross =
                input
        }

        let annualTax =
            ndflForAnnualIncome(
                annualGross
            )

        let annualNet =
            annualGross - annualTax

        let gross =
            ndflPeriod == .month
            ? annualGross / 12
            : annualGross

        let tax =
            ndflPeriod == .month
            ? annualTax / 12
            : annualTax

        let net =
            ndflPeriod == .month
            ? annualNet / 12
            : annualNet

        let effectiveRate =
            gross > 0
            ? tax / gross * 100
            : 0

        return NDFLResult(
            gross: gross,
            tax: tax,
            net: net,
            effectiveRate:
                effectiveRate
        )
    }

    private func calculateNetToGross(
        _ input: Double
    ) -> NDFLResult {
        let targetAnnualNet: Double

        switch ndflPeriod {
        case .month:
            targetAnnualNet =
                input * 12

        case .year:
            targetAnnualNet =
                input
        }

        var low =
            targetAnnualNet

        var high =
            targetAnnualNet / 0.78 + 1_000

        while true {
            let tax =
                ndflForAnnualIncome(
                    high
                )

            let net =
                high - tax

            if net >= targetAnnualNet {
                break
            }

            high *= 2
        }

        for _ in 0..<100 {
            let middle =
                (low + high) / 2

            let tax =
                ndflForAnnualIncome(
                    middle
                )

            let net =
                middle - tax

            if net < targetAnnualNet {
                low = middle
            } else {
                high = middle
            }
        }

        let annualGross =
            (low + high) / 2

        let annualTax =
            ndflForAnnualIncome(
                annualGross
            )

        let annualNet =
            annualGross - annualTax

        let gross =
            ndflPeriod == .month
            ? annualGross / 12
            : annualGross

        let tax =
            ndflPeriod == .month
            ? annualTax / 12
            : annualTax

        let net =
            ndflPeriod == .month
            ? annualNet / 12
            : annualNet

        let effectiveRate =
            gross > 0
            ? tax / gross * 100
            : 0

        return NDFLResult(
            gross: gross,
            tax: tax,
            net: net,
            effectiveRate:
                effectiveRate
        )
    }

    // MARK: NDFL Result

    private func ndflResultView(
        _ result: NDFLResult
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 12
        ) {
            HStack(
                alignment: .bottom
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        ndflDirection == .grossToNet
                        ? "НА РУКИ"
                        : "ДО НДФЛ"
                    )
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

                    Text(
                        percentageFormattedMoney(
                            ndflDirection == .grossToNet
                            ? result.net
                            : result.gross
                        )
                        + " ₽"
                    )
                    .font(
                        .system(
                            size: 26,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color.green
                    )
                }

                Spacer()

                VStack(
                    alignment: .trailing,
                    spacing: 4
                ) {
                    Text("НДФЛ")
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

                    Text(
                        percentageFormattedMoney(
                            result.tax
                        )
                        + " ₽"
                    )
                    .font(
                        .system(
                            size: 15,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Theme.primaryText
                    )
                }
            }

            Rectangle()
                .fill(
                    Color.white.opacity(0.07)
                )
                .frame(height: 1)

            HStack {
                resultRow(
                    title: "До НДФЛ",
                    value:
                        "\(percentageFormattedMoney(result.gross)) ₽"
                )

                Spacer()

                resultRow(
                    title: "Эффективная ставка",
                    value:
                        "\(String(format: "%.2f", result.effectiveRate))%"
                )
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(
                cornerRadius: 13,
                style: .continuous
            )
            .fill(
                Color.green.opacity(0.055)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 13,
                style: .continuous
            )
            .stroke(
                Color.green.opacity(0.16),
                lineWidth: 0.8
            )
        )
    }

    private func resultRow(
        title: String,
        value: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(
                    Theme.tertiaryText
                )

            Text(value)
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
    }

    private var ndflScale: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text(
                "Шкала НДФЛ для основной налоговой базы"
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

            HStack(spacing: 6) {
                ndflScaleItem(
                    "13%",
                    "до 2,4 млн"
                )

                ndflScaleItem(
                    "15%",
                    "2,4–5 млн"
                )

                ndflScaleItem(
                    "18%",
                    "5–20 млн"
                )

                ndflScaleItem(
                    "20%",
                    "20–50 млн"
                )

                ndflScaleItem(
                    "22%",
                    "свыше 50 млн"
                )
            }

            Text(
                "Расчёт использует годовую налоговую базу и прогрессивную шкалу. Для реальной зарплаты итог может отличаться из-за вычетов, других налоговых баз и особенностей расчёта работодателя."
            )
            .font(.system(size: 8))
            .foregroundStyle(
                Theme.tertiaryText
            )
        }
    }

    private func ndflScaleItem(
        _ rate: String,
        _ range: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 3
        ) {
            Text(rate)
                .font(
                    .system(
                        size: 10,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Theme.primaryText
                )

            Text(range)
                .font(.system(size: 7))
                .foregroundStyle(
                    Theme.tertiaryText
                )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(8)
        .background(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.035)
            )
        )
    }

    // MARK: Shared UI

    private func calculatorCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(18)
            .background(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .fill(
                    Color.white.opacity(0.045)
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
                .stroke(
                    Color.white.opacity(0.09),
                    lineWidth: 0.7
                )
            )
    }

    private func cardTitle(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(title)
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Theme.primaryText
                )

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(
                    Theme.secondaryText
                )
        }
    }

    private func inputBlock(
        title: String,
        suffix: String,
        field: Field,
        text: Binding<String>,
        allowsDecimal: Bool,
        maximum: Double?
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            fieldLabel(title)

            HStack(spacing: 7) {
                PercentageNumericField(
                    text: text,
                    allowsDecimal:
                        allowsDecimal,
                    maximum:
                        maximum,
                    placeholder: "0",
                    isFocused:
                        Binding(
                            get: {
                                focusedField ==
                                    field
                            },
                            set: { focused in
                                if focused {
                                    focusedField =
                                        field
                                } else if
                                    focusedField ==
                                        field
                                {
                                    focusedField =
                                        nil
                                }
                            }
                        ),
                    onSubmit: {
                        moveToNextField(
                            after: field
                        )
                    },
                    onEscape: {
                        focusedField = nil
                    }
                )

                Text(suffix)
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
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private func fieldLabel(
        _ title: String
    ) -> some View {
        Text(title)
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

    private func resultBlock(
        label: String,
        value: String
    ) -> some View {
        HStack(
            alignment: .bottom
        ) {
            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(label)
                    .font(
                        .system(
                            size: 9,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Theme.secondaryText
                    )

                Text(value)
                    .font(
                        .system(
                            size: 25,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        Color.green
                    )
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .fill(
                Color.green.opacity(0.055)
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
            .stroke(
                Color.green.opacity(0.14),
                lineWidth: 0.7
            )
        )
    }

    private func formulaBlock(
        _ formula: String
    ) -> some View {
        HStack(spacing: 7) {
            Image(
                systemName: "function"
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

            Text(formula)
                .font(
                    .system(
                        size: 9,
                        design: .monospaced
                    )
                )
                .foregroundStyle(
                    Theme.secondaryText
                )
        }
        .padding(
            .horizontal,
            11
        )
        .padding(
            .vertical,
            9
        )
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            RoundedRectangle(
                cornerRadius: 9,
                style: .continuous
            )
            .fill(
                Color.black.opacity(0.10)
            )
        )
    }

    private func directionButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action
        ) {
            Text(title)
                .font(
                    .system(
                        size: 9,
                        weight:
                            selected
                            ? .semibold
                            : .medium
                    )
                )
                .foregroundStyle(
                    selected
                        ? Theme.primaryText
                        : Theme.secondaryText
                )
                .padding(
                    .horizontal,
                    10
                )
                .frame(height: 30)
                .background(
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                    .fill(
                        selected
                            ? Color.white.opacity(0.10)
                            : Color.white.opacity(0.04)
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                    .stroke(
                        selected
                            ? Color.white.opacity(0.14)
                            : Color.clear,
                        lineWidth: 0.7
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Focus

    private func moveToNextField(
        after field: Field
    ) {
        switch mode {
        case .percentage:
            switch field {
            case .percentage:
                focusedField = .number

            case .number:
                focusedField = nil

            default:
                focusedField = nil
            }

        case .change:
            switch field {
            case .number:
                focusedField = .change

            case .change:
                focusedField = nil

            default:
                focusedField = nil
            }

        case .ndfl:
            focusedField = nil
        }
    }

    // MARK: Reset

    private func reset() {
        withAnimation(
            .easeInOut(duration: 0.15)
        ) {
            percentageText = "10"
            numberText = "100 000"

            changeText = "10"
            changeDirection =
                .increase

            ndflText = "100 000"
            ndflDirection =
                .grossToNet

            ndflPeriod =
                .month

            focusedField = nil
        }
    }
}
