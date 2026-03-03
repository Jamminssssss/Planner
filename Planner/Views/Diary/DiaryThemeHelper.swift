import SwiftUI

// MARK: - Diary Theme Helper

extension SeasonTheme {

    // ── 다크 모드 배경 그라디언트 ──
    var diaryDarkBackgroundGradient: LinearGradient {
        switch self {
        case .classic:
            return LinearGradient(colors: [
                Color(red: 0.06, green: 0.14, blue: 0.06),
                Color(red: 0.04, green: 0.10, blue: 0.04)
            ], startPoint: .top, endPoint: .bottom)
        case .spring:
            return LinearGradient(colors: [
                Color(red: 0.18, green: 0.06, blue: 0.14),
                Color(red: 0.12, green: 0.04, blue: 0.10)
            ], startPoint: .top, endPoint: .bottom)
        case .summer:
            return LinearGradient(colors: [
                Color(red: 0.04, green: 0.10, blue: 0.22),
                Color(red: 0.03, green: 0.07, blue: 0.18)
            ], startPoint: .top, endPoint: .bottom)
        case .autumn:
            return LinearGradient(colors: [
                Color(red: 0.20, green: 0.10, blue: 0.02),
                Color(red: 0.15, green: 0.07, blue: 0.01)
            ], startPoint: .top, endPoint: .bottom)
        case .winter:
            return LinearGradient(colors: [
                Color(red: 0.06, green: 0.08, blue: 0.18),
                Color(red: 0.04, green: 0.06, blue: 0.14)
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    // ── 배경 그라디언트 ──
    var diaryBackgroundGradient: LinearGradient {
        switch self {
        case .classic:
            return LinearGradient(colors: [
                Color(red: 0.88, green: 0.95, blue: 0.88),
                Color(red: 0.76, green: 0.90, blue: 0.76)
            ], startPoint: .top, endPoint: .bottom)
        case .spring:
            return LinearGradient(colors: [
                Color(red: 0.99, green: 0.93, blue: 0.97),
                Color(red: 0.96, green: 0.85, blue: 0.93)
            ], startPoint: .top, endPoint: .bottom)
        case .summer:
            return LinearGradient(colors: [
                Color(red: 0.87, green: 0.95, blue: 1.00),
                Color(red: 0.72, green: 0.88, blue: 0.98)
            ], startPoint: .top, endPoint: .bottom)
        case .autumn:
            return LinearGradient(colors: [
                Color(red: 1.00, green: 0.93, blue: 0.82),
                Color(red: 0.97, green: 0.84, blue: 0.68)
            ], startPoint: .top, endPoint: .bottom)
        case .winter:
            return LinearGradient(colors: [
                Color(red: 0.93, green: 0.96, blue: 1.00),
                Color(red: 0.85, green: 0.91, blue: 0.98)
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    // ── 카드 강조 색상 ──
    var diaryAccent: Color {
        switch self {
        case .classic: return Color(red: 0.20, green: 0.62, blue: 0.20)
        case .spring:  return Color(red: 0.94, green: 0.45, blue: 0.68)
        case .summer:  return Color(red: 0.20, green: 0.55, blue: 0.88)
        case .autumn:  return Color(red: 0.88, green: 0.45, blue: 0.18)
        case .winter:  return Color(red: 0.40, green: 0.58, blue: 0.88)
        }
    }

    // ── 카드 배경 ──
    var diaryCardBackground: Color {
        switch self {
        case .classic: return Color.white.opacity(0.75)
        case .spring:  return Color(red: 1.0, green: 0.97, blue: 0.99).opacity(0.80)
        case .summer:  return Color(red: 0.95, green: 0.98, blue: 1.0).opacity(0.80)
        case .autumn:  return Color(red: 1.0, green: 0.97, blue: 0.92).opacity(0.80)
        case .winter:  return Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.80)
        }
    }

    // ── 파티클 이모지 ──
    var particles: [String] {
        switch self {
        case .classic: return ["🌱", "🍀", "🌿", "🍃", "🌾"]
        case .spring:  return ["🌸", "🌷", "🌺", "🌼", "🦋"]
        case .summer:  return ["☀️", "🌊", "🌴", "🐚", "⛱"]
        case .autumn:  return ["🍂", "🍁", "🌰", "🍄", "🌾"]
        case .winter:  return ["❄️", "⛄", "🌨", "✨", "🌙"]
        }
    }
}

// MARK: - Theme Background View

struct ThemeBackgroundView: View {
    let theme: SeasonTheme
    @Environment(\.colorScheme) private var colorScheme

    // 파티클 위치 데이터 (고정 seed로 일관성 유지)
    private let particleData: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double, index: Int)] = {
        var items: [(CGFloat, CGFloat, CGFloat, Double, Int)] = []
        let positions: [(CGFloat, CGFloat)] = [
            (0.08, 0.06), (0.88, 0.04), (0.22, 0.14), (0.70, 0.10),
            (0.45, 0.08), (0.92, 0.20), (0.05, 0.28), (0.78, 0.25),
            (0.35, 0.22), (0.60, 0.18), (0.15, 0.40), (0.85, 0.38),
            (0.50, 0.35), (0.28, 0.50), (0.72, 0.48), (0.10, 0.60),
            (0.90, 0.58), (0.40, 0.65), (0.65, 0.62), (0.20, 0.75),
            (0.80, 0.72), (0.55, 0.80), (0.30, 0.88), (0.75, 0.85)
        ]
        for (i, pos) in positions.enumerated() {
            let size = CGFloat([18, 22, 14, 26, 16][i % 5])
            let opacity = [0.18, 0.22, 0.14, 0.26, 0.16][i % 5]
            items.append((pos.0, pos.1, size, opacity, i % 5))
        }
        return items
    }()

    var body: some View {
        ZStack {
            // ── 배경 그라디언트 (라이트/다크 모두 테마 적용) ──
            (colorScheme == .dark ? theme.diaryDarkBackgroundGradient : theme.diaryBackgroundGradient)
                .ignoresSafeArea()

            GeometryReader { geo in
                ForEach(particleData.indices, id: \.self) { i in
                    let p = particleData[i]
                    Text(theme.particles[p.index])
                        .font(.system(size: p.size))
                        .opacity(colorScheme == .dark ? p.opacity * 0.6 : p.opacity)
                        .position(
                            x: p.x * geo.size.width,
                            y: p.y * geo.size.height
                        )
                }
            }
            .ignoresSafeArea()
        }
    }
}
