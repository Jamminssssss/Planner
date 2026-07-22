import SwiftData
import SwiftUI

// UIColor 사용을 위한 프레임워크 안전 임포트
#if canImport(UIKit)
import UIKit
#endif

@Model
final class Category {
    @Attribute var id: UUID
    var name: String
    var colorHex: String
    var iconName: String
    var createdAt: Date

    // 💡 최적화: inverse를 명시하여 Plan의 category와 완벽한 양방향 동기화 보장
    // 카테고리 삭제 시 Plan들의 category를 nil로 만들고 싶다면 deleteRule: .nullify 추가
    @Relationship(deleteRule: .nullify, inverse: \Plan.category)
    var plans: [Plan]?

    init(
        id: UUID = UUID(),
        name: String = "",
        colorHex: String = "#4CAF50",
        iconName: String = "square.fill",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties
    var color: Color {
        Color(hex: colorHex) ?? .green
    }
}

// MARK: - Color Hex Extension
extension Color {
    init?(hex: String) {
        // 공백 및 줄바꿈 제거 등 방어 로직 추가
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6,
              let value = UInt32(hexSanitized, radix: 16) else { return nil }

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        // UIColor가 RGB 색상 공간으로 변환 가능한지 확인 후 값 추출
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // 0.0 ~ 1.0 사이의 값으로 안전하게 제한(Clamping)
        return String(
            format: "#%02X%02X%02X",
            Int(max(0, min(r, 1)) * 255),
            Int(max(0, min(g, 1)) * 255),
            Int(max(0, min(b, 1)) * 255)
        )
        #else
        // macOS 등의 환경을 위한 기본 폴백
        return "#4CAF50"
        #endif
    }
}
