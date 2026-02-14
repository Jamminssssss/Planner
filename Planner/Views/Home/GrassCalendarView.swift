import SwiftUI
import SwiftData

struct GrassCalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?

    // ✅ 캘린더 테마를 실시간으로 감시
    @AppStorage(ThemeType.calendar.storageKey)
    private var calendarThemeRaw: String = SeasonTheme.classic.rawValue

    private var calendarTheme: SeasonTheme {
        SeasonTheme(rawValue: calendarThemeRaw) ?? .classic
    }

    // MARK: - Calendar (절대 건드리지 않음)

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.firstWeekday = 1
        return cal
    }()

    // MARK: - Month Info

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    // MARK: - 핵심 로직

    private var calendarDays: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(
                of: .weekOfMonth,
                for: calendar.date(byAdding: .day, value: -1, to: monthInterval.end)!
            )
        else { return [] }

        var days: [Date] = []
        var date = firstWeek.start

        while date < lastWeek.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return days
    }

    // MARK: - Helpers

    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func completedCount(for date: Date) -> Int {
        let descriptor = FetchDescriptor<Plan>(
            predicate: #Predicate { $0.completedAt != nil }
        )

        guard let plans = try? modelContext.fetch(descriptor) else { return 0 }

        return plans.filter {
            calendar.isDate($0.completedAt!, inSameDayAs: date)
        }.count
    }

    // MARK: - Month Navigation

    private func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
    }

    private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            grid
        }
    }

    // MARK: - Views

    private var header: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle)
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    private var weekdayHeader: some View {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return HStack {
            ForEach(days, id: \.self) {
                Text($0)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
            spacing: 6
        ) {
            ForEach(calendarDays, id: \.self) { date in
                GrassCell(
                    day: calendar.component(.day, from: date),
                    completedCount: completedCount(for: date),
                    isToday: isToday(date),
                    isCurrentMonth: isCurrentMonth(date),
                    theme: calendarTheme        // 🔥 핵심
                ) {
                    selectedDate = date
                }
            }
        }
    }
}
