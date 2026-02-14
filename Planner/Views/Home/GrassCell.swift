import SwiftUI

struct GrassCell: View {
    let day: Int
    let completedCount: Int
    let isToday: Bool
    let isCurrentMonth: Bool
    let theme: SeasonTheme        // 🔥 부모에서 주입
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(grassColor)
                    .shadow(
                        color: hasGrass ? grassColor.opacity(0.4) : .clear,
                        radius: 2,
                        x: 0,
                        y: 1
                    )

                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(.system(size: 11, weight: isToday ? .bold : .medium))
                        .foregroundColor(
                            !isCurrentMonth ? .gray.opacity(0.4) :
                            isToday         ? .white             :
                            hasGrass        ? .white             : .secondary
                        )

                    if hasGrass {
                        Text(theme.icon)
                            .font(.system(size: 9))
                    }
                }

                if isToday && isCurrentMonth {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 2)
                }
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }
}
