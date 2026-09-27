import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case valueCalculator
    case percentageCalculator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .valueCalculator: return "Выгодная покупка"
        case .percentageCalculator:
            return "Проценты и НДФЛ"
        }
    }

    var subtitle: String {
        switch self {
        case .valueCalculator: return "Что выгоднее купить"
        case .percentageCalculator:
            return "Проценты, изменения суммы и расчёт зарплаты до и после НДФЛ"
        }
    }

    var icon: String {
        switch self {
        case .valueCalculator: return "cart.badge.questionmark"
        case .percentageCalculator:
            return "percent"
        }
    }

    var tint: Color {
        switch self {
        case .valueCalculator: return .green
        case .percentageCalculator:
            return .orange
        }
    }
}
