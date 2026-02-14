import SwiftUI
import StoreKit

// MARK: - Diary Theme Picker

struct DiaryThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared

    let currentTheme: SeasonTheme
    let onSelect: (SeasonTheme) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(SeasonTheme.allCases, id: \.self) { theme in
                    themeRow(theme)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Diary Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.green)
                }
            }
        }
    }

    // â”€â”€ í–‰ â”€â”€
    private func themeRow(_ theme: SeasonTheme) -> some View {
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
            HStack(spacing: 14) {
                // í…Œë§ˆ ì•„ì´ì½˜ íƒ€ì¼
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.color(for: 3, isCurrentMonth: true).opacity(0.25))
                        .frame(width: 48, height: 48)
                    Text(theme.icon).font(.system(size: 26))
                }

                // ì´ë¦„ + ìƒíƒœ
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary)

                    if theme == .classic {
                        Text("Free").font(.system(size: 13)).foregroundStyle(Color.green)
                    } else if owned {
                        Text("Purchased").font(.system(size: 13)).foregroundStyle(Color.green)
                    } else if let p = storeManager.product(for: theme) {
                        Text(p.displayPrice).font(.system(size: 13)).foregroundStyle(Color.secondary)
                    }
                }

                Spacer()

                // ì˜¤ë¥¸ìª½ ì•„ì´ì½˜
                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20)).foregroundStyle(Color.green)
                } else if !owned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16)).foregroundStyle(Color.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14)).foregroundStyle(Color.secondary.opacity(0.4))
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .listRowBackground(active ? Color.green.opacity(0.08) : nil)
    }
}
