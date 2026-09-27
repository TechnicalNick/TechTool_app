import SwiftUI

struct MainMenuView: View {
    @Binding var selectedTool: Tool?
    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 20)]

    private var filteredTools: [Tool] {
        guard !searchText.isEmpty else { return Tool.allCases }
        return Tool.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        case 18..<23: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header

                Group {
                    if filteredTools.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredTools) { tool in
                                ToolCard(tool: tool) {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                        selectedTool = tool
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 900)
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AuroraBackground())
    }

    private var header: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text(greeting)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text("TechTool")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            searchField
        }
        .padding(.top, 56)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.4))
            TextField("Найти инструмент", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 280)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.3))
            Text("Ничего не нашлось")
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ToolCard: View {
    let tool: Tool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    iconBadge
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(isHovering ? 0.7 : 0))
                        .offset(x: isHovering ? 0 : -4)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tool.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(tool.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .padding(18)
            .frame(height: 160, alignment: .top)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: isHovering ? tool.tint.opacity(0.35) : .black.opacity(0.2),
                    radius: isHovering ? 20 : 10,
                    y: isHovering ? 10 : 6)
            .scaleEffect(isHovering ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isHovering = hovering
            }
        }
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(colors: [tool.tint, tool.tint.opacity(0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 42, height: 42)

            Image(systemName: tool.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        }
        .shadow(color: tool.tint.opacity(0.4), radius: 8, y: 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(colors: [tool.tint.opacity(isHovering ? 0.16 : 0.08), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(isHovering ? tool.tint.opacity(0.5) : .white.opacity(0.12), lineWidth: 1)
    }
}

private struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Theme.background

            Circle()
                .fill(Color.purple.opacity(0.35))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: -160, y: -220)

            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 380, height: 380)
                .blur(radius: 130)
                .offset(x: 200, y: 180)

            Circle()
                .fill(Color.teal.opacity(0.2))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 180, y: -260)
        }
        .ignoresSafeArea()
    }
}
