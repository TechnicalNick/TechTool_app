import SwiftUI

struct ContentView: View {
    @State private var selectedTool: Tool? = nil

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            if let tool = selectedTool {
                ToolDetailView(
                    tool: tool,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTool = nil
                        }
                    }
                )
                .transition(
                    .move(edge: .trailing)
                    .combined(with: .opacity)
                )
            } else {
                MainMenuView(selectedTool: $selectedTool)
                    .transition(
                        .move(edge: .leading)
                        .combined(with: .opacity)
                    )
            }
        }
        .frame(
            minWidth: 720,
            minHeight: 420
        )
    }
}

// MARK: - Tool Detail

struct ToolDetailView: View {
    let tool: Tool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Compact navigation bar.
            HStack(spacing: 10) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))

                        Text("Меню")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .help("Вернуться в меню")

                Spacer()

                Text(tool.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                // Симметрия относительно кнопки слева.
                Color.clear
                    .frame(width: 54)
            }
            .frame(height: 30)
            .padding(.horizontal, 12)
            .background(
                Color.black.opacity(0.10)
            )

            Rectangle()
                .fill(Theme.separator)
                .frame(height: 1)

            // Сам инструмент занимает всё оставшееся пространство.
            Group {
                switch tool {
                case .valueCalculator:
                    ValueCalculatorView()

                case .percentageCalculator:
                    PercentageCalculatorView()
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
    }
}

// MARK: - Coming Soon

struct ComingSoonView: View {
    let tool: Tool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tool.icon)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(tool.tint)

            Text("Скоро здесь будет что-то полезное")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}

#Preview {
    ContentView()
}
