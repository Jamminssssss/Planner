import SwiftUI
import SwiftData
import Charts

// MARK: - Stats View

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var allPlans:   [Plan]
    @Query private var allDiaries: [DiaryEntry]

    // ── 기간 탭 ──
    enum Period: String, CaseIterable {
        case day   = "Today"
        case week  = "This Week"
        case month = "This Month"
    }
    @State private var selectedPeriod: Period = .day

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {

                    periodPicker
                    summaryCards
                    completionChart
                    categoryBreakdown

                    // ── 일기 통계 섹션 ──
                    diarySection

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // =========================================================
    // MARK: - Period Picker
    // =========================================================

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: selectedPeriod == period ? .semibold : .medium))
                        .foregroundStyle(selectedPeriod == period ? Color.white : Color.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(selectedPeriod == period ? Color.green : Color.clear)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(20)
        .padding(.top, 4)
    }

    // =========================================================
    // MARK: - Summary Cards
    // =========================================================

    private var summaryCards: some View {
        let stats = computeStats()

        return HStack(spacing: 10) {
            statCard(title: "Total",     value: "\(stats.total)",     icon: "list.bullet",           color: .blue)
            statCard(title: "Done",      value: "\(stats.completed)", icon: "checkmark.circle.fill", color: .green)
            statCard(title: "Rate",      value: stats.rateString,     icon: "percent",               color: .orange)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }

    // =========================================================
    // MARK: - Completion Chart
    // =========================================================

    private var completionChart: some View {
        let chartData = buildChartData()

        return VStack(alignment: .leading, spacing: 12) {
            Text("Completions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)

            if chartData.isEmpty {
                Text("No data yet")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
            } else {
                SwiftBarChart(data: chartData)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }

    // =========================================================
    // MARK: - Category Breakdown
    // =========================================================

    private var categoryBreakdown: some View {
        let catStats = computeCategoryStats()

        return VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)

            if catStats.isEmpty {
                Text("No categories yet")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(catStats, id: \.name) { item in
                        categoryRow(item)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }

    private func categoryRow(_ item: CatStat) -> some View {
        let maxCount = computeCategoryStats().map { $0.completed }.max() ?? 1
        let progress = maxCount > 0 ? Double(item.completed) / Double(maxCount) : 0

        return VStack(spacing: 6) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)

                    Text(item.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                Spacer()
                Text("\(item.completed) / \(item.total)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.color)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // =========================================================
    // MARK: - 📓 Diary Section
    // =========================================================

    private var diarySection: some View {
        let ds = computeDiaryStats()

        return VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 6) {
                Text("📓")
                Text("Diary")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }

            HStack(spacing: 10) {
                statCard(title: "Days",    value: "\(ds.daysWritten)",  icon: "calendar",   color: .purple)
                statCard(title: "Entries", value: "\(ds.totalEntries)", icon: "book.pages", color: .indigo)
                statCard(title: "Streak",  value: "\(ds.streak)d",     icon: "flame",      color: .orange)
            }

            if !ds.moodCounts.isEmpty {
                moodDistribution(ds.moodCounts)
            }

            if !ds.weeklyBar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    SwiftBarChart(data: ds.weeklyBar, barColor: .purple)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(14)
    }

    // ── 기분 분포 시각화 ──
    private func moodDistribution(_ counts: [(Mood, Int)]) -> some View {
        let total = counts.reduce(0) { $0 + $1.1 }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Mood Distribution")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondary)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(counts, id: \.0) { (mood, count) in
                        let ratio = total > 0 ? CGFloat(count) / CGFloat(total) : 0
                        ZStack {
                            Rectangle()
                                .fill(mood.color)
                                .frame(width: geo.size.width * ratio)

                            if ratio > 0.1 {
                                Text(mood.emoji).font(.system(size: 14))
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 24)

            HStack(spacing: 14) {
                ForEach(counts, id: \.0) { (mood, count) in
                    HStack(spacing: 3) {
                        Text(mood.emoji).font(.system(size: 14))
                        Text("\(count)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
    }

    // =========================================================
    // MARK: - Plan Data Computation
    // =========================================================

    private var filteredPlans: [Plan] {
        let cal   = Calendar.current
        let today = Date()

        switch selectedPeriod {
        case .day:
            let comps = cal.dateComponents([.year, .month, .day], from: today)
            return allPlans.filter {
                $0.year == comps.year! && $0.month == comps.month! && $0.day == comps.day! && $0.status != .canceled
            }

        case .week:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? today
            return allPlans.filter { plan in
                guard plan.status != .canceled else { return false }
                let d = plan.scheduledDateOnly
                return d >= weekStart && d < weekEnd
            }

        case .month:
            let comps = cal.dateComponents([.year, .month], from: today)
            return allPlans.filter {
                $0.year == comps.year! && $0.month == comps.month! && $0.status != .canceled
            }
        }
    }

    struct PeriodStats {
        let total:     Int
        let completed: Int
        var rateString: String {
            total == 0 ? "0%" : "\(Int(round(Double(completed) / Double(total) * 100)))%"
        }
    }

    private func computeStats() -> PeriodStats {
        let plans = filteredPlans
        return PeriodStats(
            total:     plans.count,
            completed: plans.filter { $0.status == .completed }.count
        )
    }

    struct ChartItem: Identifiable {
        let id    = UUID()
        let label: String
        let count: Int
    }

    private func buildChartData() -> [ChartItem] {
        let cal   = Calendar.current
        let today = Date()

        switch selectedPeriod {
        case .day:
            let blocks: [(label: String, hour: Int)] = [
                ("12AM", 0), ("6AM", 6), ("12PM", 12), ("6PM", 18)
            ]
            return blocks.map { block in
                let cnt = filteredPlans.filter { plan in
                    guard plan.status == .completed, let ca = plan.completedAt else { return false }
                    return cal.component(.hour, from: ca) >= block.hour &&
                           cal.component(.hour, from: ca) < block.hour + 6
                }.count
                return ChartItem(label: block.label, count: cnt)
            }

        case .week:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
            let labels = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            return (0..<7).map { offset in
                let day = cal.date(byAdding: .day, value: offset, to: weekStart)!
                let comps = cal.dateComponents([.year, .month, .day], from: day)
                let cnt = filteredPlans.filter {
                    $0.status == .completed && $0.year == comps.year! && $0.month == comps.month! && $0.day == comps.day!
                }.count
                return ChartItem(label: labels[offset], count: cnt)
            }

        case .month:
            let range = cal.range(of: .day, in: .month, for: today) ?? 1..<31
            return range.map { d in
                let cnt = filteredPlans.filter {
                    $0.status == .completed && $0.day == d
                }.count
                let label = (d % 5 == 1 || d == range.upperBound - 1) ? "\(d)" : ""
                return ChartItem(label: label, count: cnt)
            }
        }
    }

    struct CatStat {
        let name:      String
        let color:     Color
        let total:     Int
        let completed: Int
    }

    private func computeCategoryStats() -> [CatStat] {
        let plans = filteredPlans
        var dict: [UUID: (name: String, color: Color, total: Int, completed: Int)] = [:]

        for plan in plans {
            guard let cat = plan.category else { continue }
            let existing = dict[cat.id] ?? (name: cat.name, color: cat.color, total: 0, completed: 0)
            dict[cat.id] = (
                name:      existing.name,
                color:     existing.color,
                total:     existing.total + 1,
                completed: existing.completed + (plan.status == .completed ? 1 : 0)
            )
        }

        let noCat = plans.filter { $0.category == nil }
        if !noCat.isEmpty {
            dict[UUID()] = (
                name:      "Other",
                color:     .gray,
                total:     noCat.count,
                completed: noCat.filter { $0.status == .completed }.count
            )
        }

        return dict.values
            .map { CatStat(name: $0.name, color: $0.color, total: $0.total, completed: $0.completed) }
            .sorted { $0.completed > $1.completed }
    }

    // =========================================================
    // MARK: - Diary Data Computation
    // =========================================================

    struct DiaryStats {
        let daysWritten:  Int
        let totalEntries: Int
        let streak:       Int
        let moodCounts:   [(Mood, Int)]
        let weeklyBar:    [ChartItem]
    }

    private func computeDiaryStats() -> DiaryStats {
        let cal   = Calendar.current
        let today = Date()

        let filtered: [DiaryEntry]
        switch selectedPeriod {
        case .day:
            let c = cal.dateComponents([.year, .month, .day], from: today)
            filtered = allDiaries.filter {
                $0.year == c.year! && $0.month == c.month! && $0.day == c.day!
            }
        case .week:
            guard let ws = cal.dateInterval(of: .weekOfYear, for: today)?.start else {
                filtered = []
                break
            }
            let we = cal.date(byAdding: .day, value: 7, to: ws) ?? today
            filtered = allDiaries.filter { $0.dateValue >= ws && $0.dateValue < we }
        case .month:
            let c = cal.dateComponents([.year, .month], from: today)
            filtered = allDiaries.filter {
                $0.year == c.year! && $0.month == c.month!
            }
        }

        let dateSet = Set(filtered.map { "\($0.year)-\($0.month)-\($0.day)" })

        var streak = 0
        var check  = today
        outerLoop: while true {
            let c   = cal.dateComponents([.year, .month, .day], from: check)
            let key = "\(c.year!)-\(c.month!)-\(c.day!)"
            if allDiaries.contains(where: { "\($0.year)-\($0.month)-\($0.day)" == key }) {
                streak += 1
                check  = cal.date(byAdding: .day, value: -1, to: check) ?? check
            } else {
                break outerLoop
            }
        }

        var moodMap: [Mood: Int] = [:]
        for e in filtered {
            if let m = e.mood { moodMap[m, default: 0] += 1 }
        }
        let moodCounts = moodMap.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }

        var weeklyBar: [ChartItem] = []
        if let ws = cal.dateInterval(of: .weekOfYear, for: today)?.start {
            let labels = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            weeklyBar = (0..<7).map { off in
                let day = cal.date(byAdding: .day, value: off, to: ws)!
                let c   = cal.dateComponents([.year, .month, .day], from: day)
                let cnt = allDiaries.filter {
                    $0.year == c.year! && $0.month == c.month! && $0.day == c.day!
                }.count
                return ChartItem(label: labels[off], count: cnt)
            }
        }

        return DiaryStats(
            daysWritten:  dateSet.count,
            totalEntries: filtered.count,
            streak:       streak,
            moodCounts:   moodCounts,
            weeklyBar:    weeklyBar
        )
    }
}

// MARK: - Swift Charts Bar Chart

struct SwiftBarChart: View {
    let data:     [StatsView.ChartItem]
    var barColor: Color = .green

    var body: some View {
        Chart {
            ForEach(data) { item in
                BarMark(
                    x: .value("Label", item.label),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(item.count > 0 ? barColor : .gray.opacity(0.3))
                .annotation(position: .top) {
                    if item.count > 0 {
                        Text("\(item.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(barColor)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic)
        }
        .frame(height: 160)
    }
}

// MARK: - Preview

#Preview {
    StatsView()
        .modelContainer(for: [Category.self, Plan.self, DiaryEntry.self], inMemory: true)
}
