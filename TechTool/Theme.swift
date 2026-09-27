
import SwiftUI

enum Theme {
    // Общий фон приложения.
    // Используется только на уровне экранов, а не внутри отдельных карточек.
    static let background = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.09, blue: 0.15),
            Color(red: 0.14, green: 0.10, blue: 0.23),
            Color(red: 0.05, green: 0.14, blue: 0.21)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Основные цвета интерфейса.
    static let primaryText = Color.white.opacity(0.92)
    static let secondaryText = Color.white.opacity(0.58)
    static let tertiaryText = Color.white.opacity(0.36)

    // Тонкие разделители и границы.
    static let separator = Color.white.opacity(0.09)
    static let subtleBorder = Color.white.opacity(0.10)

    // Фон компактных элементов.
    static let controlBackground = Color.white.opacity(0.055)
    static let controlBackgroundHover = Color.white.opacity(0.085)

    // Акцент результата.
    static let accent = Color.green
}
