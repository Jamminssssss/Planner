import SwiftUI
import SwiftData

// MARK: - Diary List View
struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var storeManager = StoreKitManager.shared

    @Query(sort: \DiaryEntry.createdAt, order: .reverse)
    private var allEntries: [DiaryEntry]

    @AppStorage("diaryTheme") private var diaryThemeRaw = SeasonTheme.classic.rawValue
    private var currentTheme: SeasonTheme {
        SeasonTheme(rawValue: diaryThemeRaw) ?? .classic
    }

    private let todayY: Int = Calendar.current.component(.year,  from: Date())
    private let todayM: Int = Calendar.current.component(.month, from: Date())
    private let todayD: Int = Calendar.current.component(.day,   from: Date())

    private var todayEntries: [DiaryEntry] {
        allEntries.filter { $0.year == todayY && $0.month == todayM && $0.day == todayD }
    }
    private var pastEntries: [DiaryEntry] {
        allEntries.filter { !($0.year == todayY && $0.month == todayM && $0.day == todayD) }
    }

    private var pastGrouped: [(key: String, dateKey: (Int,Int,Int), entries: [DiaryEntry])] {
        let sortedEntries = pastEntries.sorted {
            if $0.year != $1.year { return $0.year > $1.year }
            if $0.month != $1.month { return $0.month > $1.month }
            return $0.day > $1.day
        }
        
        var groups: [(String, (Int,Int,Int), [DiaryEntry])] = []
        var lastKey: (Int,Int,Int)? = nil
        
        for entry in sortedEntries {
            let k = (entry.year, entry.month, entry.day)
            if lastKey == nil || k != lastKey! {
                groups.append((formatDate(k.0, k.1, k.2), k, [entry]))
                lastKey = k
            } else {
                groups[groups.count - 1].2.append(entry)
            }
        }
        
        return groups
    }

    @State private var showThemeStore = false
    @State private var showWriteView  = false

    private var adaptiveCardBackground: Color {
        colorScheme == .dark
            ? Color(white: 0.15)
            : currentTheme.diaryCardBackground
    }
    
    private var adaptiveTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark
                    ? LinearGradient(colors: [Color.black, Color(white: 0.1)],
                                   startPoint: .top, endPoint: .bottom)
                    : currentTheme.diaryBackgroundGradient
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        if allEntries.isEmpty {
                            emptyDiaryState
                        } else {
                            todaySection

                            ForEach(pastGrouped, id: \.key) { group in
                                pastDayCard(label: group.key, entries: group.entries)
                            }
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showThemeStore) {
                ThemeStoreView(themeType: .diary)
            }
            .sheet(isPresented: $showWriteView) {
                NavigationStack {
                    DiaryWriteView(existingEntry: nil, theme: currentTheme)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Empty State
    private var emptyDiaryState: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(currentTheme.diaryAccent.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Text(currentTheme.icon)
                        .font(.system(size: 50))
                }
                
                VStack(spacing: 6) {
                    Text("Start Your Diary Journey")
                        .font(.title3.bold())
                        .foregroundStyle(adaptiveTextColor)
                    
                    Text("Capture your thoughts, moods, and memories")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { showThemeStore = true }) {
                Image(systemName: "paintpalette")
                    .foregroundStyle(Color.secondary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showWriteView = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.green)
            }
        }
    }

    // MARK: - Today Section
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Text(formatDate(todayY, todayM, todayD))
                        .font(.title3.bold())
                        .foregroundStyle(adaptiveTextColor)
                }
                Spacer()
                Text(currentTheme.icon)
                    .font(.title2)
            }

            Divider()

            if todayEntries.isEmpty {
                emptyTodayPlaceholder
            } else {
                VStack(spacing: 8) {
                    ForEach(todayEntries) { entry in
                        NavigationLink(
                            destination: DiaryWriteView(existingEntry: entry, theme: currentTheme)
                        ) {
                            EntryPreviewRow(entry: entry, accent: currentTheme.diaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: { showWriteView = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption)
                    Text("Add today's diary")
                        .font(.callout)
                }
                .foregroundStyle(currentTheme.diaryAccent)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(adaptiveCardBackground)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var emptyTodayPlaceholder: some View {
        VStack(spacing: 6) {
            Text("No diary yet today")
                .font(.body)
                .foregroundStyle(Color.secondary)
            Text("Write something or just leave a mood ✨")
                .font(.subheadline)
                .foregroundStyle(Color.secondary.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Past Day Card
    private func pastDayCard(label: String, entries: [DiaryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .padding(.leading, 4)

            VStack(spacing: 6) {
                ForEach(entries) { entry in
                    NavigationLink(
                        destination: DiaryWriteView(existingEntry: entry, theme: entry.theme)
                    ) {
                        EntryPreviewRow(entry: entry, accent: entry.theme.diaryAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(adaptiveCardBackground)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - Helpers
    private func formatDate(_ y: Int, _ m: Int, _ d: Int) -> String {
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        guard let date = Calendar.current.date(from: comps) else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d, yyyy"
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: date)
    }
}

// MARK: - Entry Preview Row
struct EntryPreviewRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let entry: DiaryEntry
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(accent)
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let mood = entry.mood {
                        Text(mood.emoji)
                            .font(.title2)
                    }
                    if !entry.text.isEmpty {
                        Text(entry.text)
                            .font(.body)
                            .foregroundStyle(colorScheme == .dark ? .white : .primary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    if !entry.images.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "photo")
                                .font(.caption)
                            Text("\(entry.images.count)")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.secondary)
                    }
                    Text(entry.theme.icon)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(0.4))
        }
        .padding(.vertical, 8)
    }
}
