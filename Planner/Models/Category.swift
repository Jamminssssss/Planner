import SwiftData
import SwiftUI

@Model
final class Category {
    // ❌ CloudKit에서 unique constraint 사용 불가 → 제거
    @Attribute var id: UUID = UUID()           // 기본값 추가
    var name: String = ""                       // 기본값 추가
    var colorHex: String = "#4CAF50"           // 기본값 유지
    var iconName: String = "square.fill"       // 기본값 유지
    var createdAt: Date = Date()               // 기본값 유지

    // Relationship: one category has many plans
    @Relationship var plans: [Plan]?           // optional 그대로

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

    // MARK: - Computed

    var color: Color {
        Color(hex: colorHex) ?? .green
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6,
              let value = UInt32(hex, radix: 16) else { return nil }

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}
