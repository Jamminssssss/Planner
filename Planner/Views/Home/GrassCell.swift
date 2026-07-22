import SwiftUI

struct GrassCell: View {
    let day: Int
    let completedCount: Int
    let isToday: Bool
    let isCurrentMonth: Bool
    let theme: SeasonTheme
    let onTap: () -> Void

    // MARK: - Computed

    private var grassColor: Color {
        theme.color(for: completedCount, isCurrentMonth: isCurrentMonth)
    }

    private var hasGrass: Bool {
        completedCount > 0 && isCurrentMonth
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(grassColor)
                    .shadow(
                        color: hasGrass ? grassColor.opacity(0.4) : .clear,
                        radius: 3,
                        x: 0,
                        y: 2
                    )

                VStack(spacing: 4) {
                    Text("\(day)")
                        .font(.system(size: 14, weight: isToday ? .bold : .medium))
                        .foregroundColor(
                            !isCurrentMonth ? .gray.opacity(0.4) :
                            isToday         ? .white             :
                            hasGrass        ? .white             : .secondary
                        )

                    if hasGrass {
                        Text(theme.icon)
                            .font(.system(size: 12))
                    }
                }

                if isToday && isCurrentMonth {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.8), lineWidth: 2.5)
                }
            }
            // 💡 고정 높이를 제거하고 무한히 늘어나되, 가로/세로 1:1 정사각형 비율을 유지하도록 설정
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}
