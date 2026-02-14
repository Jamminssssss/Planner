import SwiftUI

/// 카테고리 배지 컴포넌트 — 목록, 폼, 상세 뷰에서 재사용
struct CategoryBadge: View {
    let category: Category
    var showName: Bool = true
    var fontSize: CGFloat = 13
    
    var body: some View {
        HStack(spacing: 6) {
            // 카테고리 아이콘
            Image(systemName: category.iconName)
                .font(.system(size: fontSize - 1))
                .foregroundColor(category.color)
            
            // 카테고리 이름
            if showName {
                Text(category.name)
                    .font(.system(size: fontSize))
                    .foregroundColor(category.color)
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
        CategoryBadge(category: Category(name: "Dev", colorHex: "#3498DB", iconName: "chevron.code"))
        CategoryBadge(category: Category(name: "Workout", colorHex: "#E74C3C", iconName: "dumbbell.fill"))
        CategoryBadge(category: Category(name: "Reading", colorHex: "#9B59B6", iconName: "books.fill"))
        
        // Icon only
        HStack(spacing: 8) {
            CategoryBadge(category: Category(name: "YouTube", colorHex: "#FF0000", iconName: "play.rectangle.fill"), showName: false)
            CategoryBadge(category: Category(name: "Dev", colorHex: "#3498DB", iconName: "chevron.code"), showName: false)
        }
    }
    .padding()
}
