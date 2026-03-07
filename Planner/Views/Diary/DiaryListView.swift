import SwiftUI
import SwiftData

// MARK: - Diary List View (iOS Notes Style + Theme)

struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme

    @StateObject private var storeManager = StoreKitManager.shared

    @Query(sort: \DiaryEntry.updatedAt, order: .reverse)
    private var allEntries: [DiaryEntry]

    @AppStorage("diaryTheme") private var diaryThemeRaw = SeasonTheme.classic.rawValue
    private var currentTheme: SeasonTheme {
        SeasonTheme(rawValue: diaryThemeRaw) ?? .classic
    }

    @State private var searchText      = ""
    @State private var showNewEntry    = false
    @State private var showThemePicker = false

    private var filteredEntries: [DiaryEntry] {
        guard !searchText.isEmpty else { return allEntries }
        let q = searchText.lowercased()
        return allEntries.filter { $0.text.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ── 테마 배경 ──
                ThemeBackgroundView(theme: currentTheme)

                Group {
                    if allEntries.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(filteredEntries) { entry in
                                ZStack {
                                    // Subtle glass material to blend with theme background
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(currentTheme.diaryAccent.opacity(0.08), lineWidth: 1)
                                        )
                                        .overlay(
                                            // very soft accent tint to merge with background
                                            LinearGradient(colors: [currentTheme.diaryAccent.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        )
                                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 6, x: 0, y: 2)

                                    NavigationLink(
                                        destination: DiaryEditorView(entry: entry, theme: currentTheme)
                                    ) {
                                        DiaryRowView(entry: entry, accent: currentTheme.diaryAccent)
                                            .padding(12)
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
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
                // 테마 선택 (왼쪽)
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
                // 새 노트 (오른쪽)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNewEntry = true } label: {
                        Image(systemName: "square.and.pencil").font(.system(size: 20))
                    }
                }
            }
        }
        .sheet(isPresented: $showNewEntry) {
            DiaryEditorView(entry: nil, theme: currentTheme)
        }
        .sheet(isPresented: $showThemePicker) {
            DiaryThemePickerView(
                currentTheme: currentTheme,
                onSelect: { theme in diaryThemeRaw = theme.rawValue }
            )
        }
    }

    // MARK: - Empty State

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

    // MARK: - Helpers

    private var countLabel: String {
        let n = allEntries.count
        return n == 1 ? "1 Note" : "\(n) Notes"
    }

    private func deleteEntries(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(filteredEntries[i]) }
        try? modelContext.save()
    }
}

// MARK: - Row View

struct DiaryRowView: View {
    let entry:  DiaryEntry
    let accent: Color

    private var titleLine: String {
        let first = entry.text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "New Note" : trimmed
    }

    private var previewLine: String {
        let lines = entry.text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let body  = lines.dropFirst().joined(separator: " ")
        if body.isEmpty {
            return entry.mood.map { $0.emoji + " " + $0.label } ?? "No additional text"
        }
        return body
    }

    private var dateLabel: String {
        var comps = DateComponents()
        comps.year = entry.year; comps.month = entry.month; comps.day = entry.day
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
                Text(titleLine)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(dateLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .opacity(0.9)
            }
            HStack(spacing: 6) {
                Rectangle()
                    .fill(accent.opacity(0.85))
                    .frame(width: 2, height: 14)
                    .cornerRadius(1)
                Text(previewLine)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !entry.images.isEmpty {
                    Image(systemName: "photo")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
    }
}
