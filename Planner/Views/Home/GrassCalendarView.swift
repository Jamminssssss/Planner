import SwiftUI
import SwiftData

struct GrassCalendarView: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?

    @AppStorage(ThemeType.calendar.storageKey)
    private var calendarThemeRaw: String = SeasonTheme.classic.rawValue

    private var calendarTheme: SeasonTheme {
        SeasonTheme(rawValue: calendarThemeRaw) ?? .classic
    }

    // 💡 렌더링 렉 방지: 디스크 I/O 대신 메모리 상에서 데이터를 필터링하기 위해 전체 로드
    @Query private var allPlans: [Plan]

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.firstWeekday = 1
        return cal
    }()

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

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

    // 💡 최적화됨: 뷰를 그릴 때마다 Fetch하지 않고 메모리에서 개수 파악 (속도 대폭 향상)
    private func completedCount(for date: Date) -> Int {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        return allPlans.filter { plan in
            plan.status == .completed &&
            plan.year == year &&
            plan.month == month &&
            plan.day == day
        }.count
    }

    private func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)!
    }

    private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)!
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            header
            weekdayHeader
            grid
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Views

    private var header: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(8)
            }

            Spacer()

            Text(monthTitle)
                .font(.system(size: 22, weight: .bold))

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(8)
            }
        }
        .padding(.horizontal, 8)
    }

    private var weekdayHeader: some View {
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return HStack {
            ForEach(days, id: \.self) { day in
                Text(day)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
            spacing: 8
        ) {
            ForEach(calendarDays, id: \.self) { date in
                GrassCell(
                    day: calendar.component(.day, from: date),
                    completedCount: completedCount(for: date),
                    isToday: isToday(date),
                    isCurrentMonth: isCurrentMonth(date),
                    theme: calendarTheme
                ) {
                    selectedDate = date
                }
            }
        }
    }
}
