import SwiftUI
import StoreKit

// MARK: - Diary Theme Picker

struct DiaryThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeManager = StoreKitManager.shared

    let currentTheme: SeasonTheme
    let onSelect: (SeasonTheme) -> Void

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
            .navigationTitle("Diary Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Seasonal Themes")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }

    private var currentThemeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Theme")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                Text(currentTheme.icon).font(.system(size: 36))
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTheme.displayName).font(.system(size: 16, weight: .medium)).foregroundColor(.primary)
                    Text("Active").font(.system(size: 13)).foregroundColor(.green)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.green.opacity(0.08))
            .cornerRadius(12)
        }
    }

    private var availableThemesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Themes")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            VStack(spacing: 12) {
                themeCard(.classic)
                ForEach([SeasonTheme.spring, .summer, .autumn, .winter], id: \.self) { theme in
                    themeCard(theme)
                }
            }
        }
    }

    private func themeCard(_ theme: SeasonTheme) -> some View {
        let owned  = storeManager.hasPurchased(theme: theme)
        let active = (currentTheme == theme)

        return Button(action: {
            if owned {
                onSelect(theme)
                dismiss()
            } else if let product = storeManager.product(for: theme) {
                Task {
                    let ok = await storeManager.purchase(product)
                    if ok {
                        onSelect(theme)
                        dismiss()
                    }
                }
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.color(for: 3, isCurrentMonth: true).opacity(0.3))
                        .frame(width: 56, height: 56)
                    Text(theme.icon).font(.system(size: 28))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.primary)
                    if theme == .classic {
                        Text("Free").font(.system(size: 13)).foregroundStyle(Color.green)
                    } else if owned {
                        Text("Purchased").font(.system(size: 13)).foregroundStyle(Color.green)
                    } else if let p = storeManager.product(for: theme) {
                        Text(p.displayPrice).font(.system(size: 13)).foregroundStyle(Color.secondary)
                    }
                }
                Spacer()

                if active {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Color.green)
                } else if owned {
                    Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(Color.secondary.opacity(0.5))
                } else if storeManager.isPurchasing {
                    ProgressView().progressViewStyle(.circular)
                } else {
                    Image(systemName: "cart.fill").font(.system(size: 18)).foregroundStyle(Color.green)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(active ? Color.green.opacity(0.08) : Color.secondary.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? Color.green : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isPurchasing)
    }
}
