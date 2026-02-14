import SwiftUI

// MARK: - Diary Theme Helper
// 일기장 테마별 색상·그라디언트를 한 곳에서 정의 → View에서 참조

extension SeasonTheme {

    // ── 배경 그라디언트 (리스트·작성 화면) ──
    var diaryBackgroundGradient: LinearGradient {
        switch self {
        case .classic:
            return LinearGradient(colors: [
                Color(red: 0.91, green: 0.96, blue: 0.91),
                Color(red: 0.82, green: 0.92, blue: 0.82)
            ], startPoint: .top, endPoint: .bottom)
        case .spring:
            return LinearGradient(colors: [
                Color(red: 0.98, green: 0.93, blue: 0.96),
                Color(red: 0.95, green: 0.87, blue: 0.93)
            ], startPoint: .top, endPoint: .bottom)
        case .summer:
            return LinearGradient(colors: [
                Color(red: 0.91, green: 0.95, blue: 0.99),
                Color(red: 0.86, green: 0.93, blue: 0.98)
            ], startPoint: .top, endPoint: .bottom)
        case .autumn:
            return LinearGradient(colors: [
                Color(red: 0.99, green: 0.94, blue: 0.88),
                Color(red: 0.96, green: 0.88, blue: 0.78)
            ], startPoint: .top, endPoint: .bottom)
        case .winter:
            return LinearGradient(colors: [
                Color(red: 0.95, green: 0.96, blue: 0.99),
                Color(red: 0.90, green: 0.93, blue: 0.98)
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    // ── 카드 강조 색상 (날짜 구분선, 선택 반응 등) ──
    var diaryAccent: Color {
        switch self {
        case .classic: return Color(red: 0.25, green: 0.66, blue: 0.25)
        case .spring:  return Color(red: 0.96, green: 0.55, blue: 0.72)
        case .summer:  return Color(red: 0.30, green: 0.65, blue: 0.90)
        case .autumn:  return Color(red: 0.90, green: 0.50, blue: 0.25)
        case .winter:  return Color(red: 0.50, green: 0.65, blue: 0.90)
        }
    }

    // ── 카드 배경 (반투명) ──
    var diaryCardBackground: Color {
        switch self {
        case .classic: return Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.72)
        case .spring:  return Color(red: 1.0, green: 0.97, blue: 0.99).opacity(0.72)
        case .summer:  return Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.72)
        case .autumn:  return Color(red: 1.0, green: 0.97, blue: 0.93).opacity(0.72)
        case .winter:  return Color(red: 0.97, green: 0.98, blue: 1.0).opacity(0.72)
        }
    }
}
