import SwiftUI
import StoreKit

/// 계절 테마 스토어 (다이어리/캘린더 독립 적용)
struct ThemeStoreView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    
    let themeType: ThemeType
    @State private var selectedThemeRaw: String
    
    init(themeType: ThemeType) {
        self.themeType = themeType
        // UserDefaults에서 현재 테마 불러오기
        let key = themeType.storageKey
        let raw = UserDefaults.standard.string(forKey: key) ?? SeasonTheme.classic.rawValue
        _selectedThemeRaw = State(initialValue: raw)
    }
    
    private var selectedTheme: SeasonTheme {
        SeasonTheme(rawValue: selectedThemeRaw) ?? .classic
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    currentThemeSection
                    availableThemesSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle(themeType.storeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: themeType == .diary ? "book.fill" : "calendar")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Seasonal Themes")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(themeType.storeDescription)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Current Theme
    
    private var currentThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(themeType.currentThemeLabel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                Text(selectedTheme.icon)
                    .font(.system(size: 36))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTheme.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Active")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.green.opacity(0.08))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Available Themes
    
    private var availableThemesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Themes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                // Classic (무료)
                themeCard(theme: .classic)
                
                // 계절 테마 (유료)
                ForEach([SeasonTheme.spring, .summer, .autumn, .winter], id: \.self) { theme in
                    themeCard(theme: theme)
                }
            }
        }
    }
    
    private func themeCard(theme: SeasonTheme) -> some View {
        let isPurchased = storeManager.hasPurchased(theme: theme)
        let isSelected = selectedTheme == theme
        let product = storeManager.product(for: theme)
        
        return Button(action: {
            if isPurchased {
                selectTheme(theme)
            } else if let product = product {
                purchaseTheme(product)
            }
        }) {
            HStack(spacing: 16) {
                // 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.color(for: 3, isCurrentMonth: true).opacity(0.3))
                        .frame(width: 56, height: 56)
                    
                    Text(theme.icon)
                        .font(.system(size: 28))
                }
                
                // 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if theme == .classic {
                        Text("Free")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    } else if isPurchased {
                        Text("Purchased")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    } else if let product = product {
                        Text(product.displayPrice)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Loading...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 상태 표시
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else if isPurchased {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.5))
                } else if storeManager.isPurchasing {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "cart")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.green.opacity(0.08) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isPurchasing)
    }
    
    // MARK: - Actions
    
    private func selectTheme(_ theme: SeasonTheme) {
        selectedThemeRaw = theme.rawValue
        UserDefaults.standard.set(theme.rawValue, forKey: themeType.storageKey)
    }
    
    private func purchaseTheme(_ product: Product) {
        Task {
            let success = await storeManager.purchase(product)
            if success {
                // 구매 성공 시 자동 선택
                if let theme = SeasonTheme.allCases.first(where: { $0.productID == product.id }) {
                    selectTheme(theme)
                }
            }
        }
    }
}

#Preview {
    ThemeStoreView(themeType: .diary)
}
