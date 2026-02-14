import SwiftUI

// MARK: - Season Theme

enum SeasonTheme: String, CaseIterable, Codable {
    case spring = "spring"
    case summer = "summer"
    case autumn = "autumn"
    case winter = "winter"
    case classic = "classic"  // 기본 잔디
    
    var displayName: String {
        switch self {
        case .spring:  return "Spring Blossoms"
        case .summer:  return "Summer Rain"
        case .autumn:  return "Autumn Leaves"
        case .winter:  return "Winter Snow"
        case .classic: return "Classic Grass"
        }
    }
    
    var icon: String {
        switch self {
        case .spring:  return "🌸"
        case .summer:  return "🌧️"
        case .autumn:  return "🍁"
        case .winter:  return "❄️"
        case .classic: return "🌱"
        }
    }
    
    var productID: String {
        "com.grassplanner.theme.\(rawValue)"
    }
    
    /// 완료 횟수에 따른 색상 (계절별로 다름)
    func color(for count: Int, isCurrentMonth: Bool) -> Color {
        guard isCurrentMonth else { return .gray.opacity(0.1) }
        
        switch self {
        case .classic:
            // 기본 녹색 계열
            switch count {
            case 0:     return Color(red: 0.88, green: 0.92, blue: 0.88)
            case 1:     return Color(red: 0.56, green: 0.83, blue: 0.47)
            case 2...3: return Color(red: 0.25, green: 0.66, blue: 0.25)
            default:    return Color(red: 0.10, green: 0.45, blue: 0.10)
            }
            
        case .spring:
            // 분홍/핑크 계열
            switch count {
            case 0:     return Color(red: 0.95, green: 0.90, blue: 0.92)
            case 1:     return Color(red: 0.98, green: 0.75, blue: 0.83)
            case 2...3: return Color(red: 0.96, green: 0.55, blue: 0.72)
            default:    return Color(red: 0.88, green: 0.35, blue: 0.55)
            }
            
        case .summer:
            // 파란/하늘색 계열
            switch count {
            case 0:     return Color(red: 0.88, green: 0.93, blue: 0.98)
            case 1:     return Color(red: 0.60, green: 0.80, blue: 0.95)
            case 2...3: return Color(red: 0.30, green: 0.65, blue: 0.90)
            default:    return Color(red: 0.15, green: 0.45, blue: 0.75)
            }
            
        case .autumn:
            // 주황/빨강 계열
            switch count {
            case 0:     return Color(red: 0.98, green: 0.92, blue: 0.85)
            case 1:     return Color(red: 0.95, green: 0.75, blue: 0.45)
            case 2...3: return Color(red: 0.90, green: 0.50, blue: 0.25)
            default:    return Color(red: 0.75, green: 0.25, blue: 0.15)
            }
            
        case .winter:
            // 하얀/파란 계열
            switch count {
            case 0:     return Color(red: 0.95, green: 0.95, blue: 0.98)
            case 1:     return Color(red: 0.85, green: 0.90, blue: 0.98)
            case 2...3: return Color(red: 0.70, green: 0.80, blue: 0.95)
            default:    return Color(red: 0.50, green: 0.65, blue: 0.90)
            }
        }
    }
}
