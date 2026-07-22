import SwiftUI
import SwiftData

// MARK: - Diary List View

struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme

    @ObservedObject private var storeManager = StoreKitManager.shared
    @ObservedObject private var lockManager  = DiaryLockManager.shared

    @Query(sort: \DiaryEntry.updatedAt, order: .reverse)
    private var allEntries: [DiaryEntry]

    @AppStorage("diaryTheme") private var diaryThemeRaw = SeasonTheme.classic.rawValue
    private var currentTheme: SeasonTheme { SeasonTheme(rawValue: diaryThemeRaw) ?? .classic }

    @State private var showNewEntry = false
    @State private var showThemePicker = false
    @State private var showDailyLimitPaywall = false

    private var isPremium: Bool { storeManager.isPremium }

    private var canAddNewDiaryToday: Bool {
        if isPremium { return true }
        return DiaryEntry.existingCount(onLocalDayOf: Date(), in: allEntries) < 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView(theme: currentTheme)

                VStack(spacing: 0) {
                    if !isPremium {
                        Text("Free plan: one entry saved per day. Delete it to add another.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                    }

                    if allEntries.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(allEntries) { entry in
                                entryListRow(entry)
                            }
                            .onDelete(perform: deleteEntries)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showThemePicker = true } label: {
                        HStack(spacing: 4) {
                            Text(currentTheme.icon).font(.system(size: 18))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if canAddNewDiaryToday { showNewEntry = true }
                        else { showDailyLimitPaywall = true }
                    } label: {
                        Image(systemName: "square.and.pencil").font(.system(size: 20))
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showNewEntry) {
            DiaryEditorView(entry: nil, theme: currentTheme)
        }
        .fullScreenCover(isPresented: $showDailyLimitPaywall) {
            PurchaseView()
        }
        .fullScreenCover(isPresented: $showThemePicker) {
            DiaryThemePickerView(
                currentTheme: currentTheme,
                onSelect: { theme in diaryThemeRaw = theme.rawValue }
            )
        }
    }

    @ViewBuilder
    private func entryListRow(_ entry: DiaryEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(currentTheme.diaryAccent.opacity(entry.isLocked ? 0.25 : 0.08), lineWidth: entry.isLocked ? 1.2 : 1)
                )
                .overlay(
                    LinearGradient(
                        colors: [currentTheme.diaryAccent.opacity(entry.isLocked ? 0.04 : 0.06), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 6, x: 0, y: 2)

            // 무료 사용자도 자유롭게 접근 가능하도록 조건문 단순화
            NavigationLink(destination: DiaryEditorView(entry: entry, theme: currentTheme)) {
                if entry.isLocked {
                    LockedRowView(accent: currentTheme.diaryAccent)
                        .padding(12)
                } else {
                    DiaryRowView(entry: entry, accent: currentTheme.diaryAccent)
                        .padding(12)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(currentTheme.particles.first ?? "📝")
                .font(.system(size: 64))
                .opacity(0.7)
            Text("No Notes Yet")
                .font(.title3.bold())
            Text("Tap ✏️ to write your first diary entry.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(allEntries[i]) }
        try? modelContext.save()
    }
}

// MARK: - Row Views
struct LockedRowView: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Protected Entry")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Rectangle()
                        .fill(accent.opacity(0.6))
                        .frame(width: 2, height: 14)
                        .cornerRadius(1)
                    Text("Encrypted — authenticate to view")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct DiaryRowView: View {
    let entry: DiaryEntry
    let accent: Color

    private var titleLine: String {
        let first = entry.text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "New Note" : trimmed
    }

    private var previewLine: String {
        let lines = entry.text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let body = lines.dropFirst().joined(separator: " ")
        
        if body.isEmpty {
            if let mood = entry.mood {
                return "\(mood.emoji) \(mood.label)"
            }
            return "No additional text"
        }
        
        return body
    }

    private var dateLabel: String {
        let comps = DateComponents(year: entry.year, month: entry.month, day: entry.day)
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let fmt = DateFormatter(); fmt.dateFormat = "h:mm a"
            return fmt.string(from: entry.updatedAt)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let fmt = DateFormatter(); fmt.dateStyle = .short; fmt.timeStyle = .none
            return fmt.string(from: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(titleLine).font(.system(size: 16, weight: .medium)).lineLimit(1)
                Spacer()
                Text(dateLabel).font(.system(size: 13)).foregroundStyle(.secondary).opacity(0.9)
            }
            HStack(spacing: 6) {
                Rectangle().fill(accent.opacity(0.85)).frame(width: 2, height: 14).cornerRadius(1)
                Text(previewLine).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(1)
                // 💡 옵셔널 배열 처리를 위해 닐 병합 연산자(?? []) 적용
                if !(entry.images ?? []).isEmpty {
                    Image(systemName: "photo").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2).padding(.horizontal, 2)
    }
}
