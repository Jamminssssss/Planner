import SwiftUI

/// 카테고리 배지 컴포넌트 — 목록, 폼, 상세 뷰에서 재사용
struct CategoryBadge: View {
    let category: Category
    var showName: Bool = true
    var fontSize: CGFloat = 13
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.iconName)
                .font(.system(size: fontSize - 1))
                .foregroundColor(category.color)
            
            if showName {
                Text(category.name)
                    .font(.system(size: fontSize))
                    .foregroundColor(category.color)
                    // 💡 UI 안정성: 이름이 너무 길어질 경우 말줄임표 처리하여 레이아웃 붕괴 방지
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, showName ? 10 : 6)
        .padding(.vertical, 5)
        .background(category.color.opacity(0.12))
        .cornerRadius(20)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        CategoryBadge(category: Category(name: "YouTube", colorHex: "#FF0000", iconName: "play.rectangle.fill"))
        CategoryBadge(category: Category(name: "Development Work", colorHex: "#3498DB", iconName: "chevron.code"))
        
        // Icon only
        HStack(spacing: 8) {
            CategoryBadge(category: Category(name: "YouTube", colorHex: "#FF0000", iconName: "play.rectangle.fill"), showName: false)
            CategoryBadge(category: Category(name: "Dev", colorHex: "#3498DB", iconName: "chevron.code"), showName: false)
        }
    }
    .padding()
}
