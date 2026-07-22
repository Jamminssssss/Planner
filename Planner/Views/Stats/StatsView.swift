import SwiftUI
import SwiftData
import Charts

// MARK: - Stats View

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var allPlans:   [Plan]
    @Query private var allDiaries: [DiaryEntry]

    enum Period: String, CaseIterable {
        case day   = "Today"
        case week  = "This Week"
        case month = "This Month"
    }
    @State private var selectedPeriod: Period = .day
    @State private var showWorkStats = false
    @State private var showExport    = false

    // 기기 환경에 맞는 로컬 통화 기호 (예: $, €, ₩)
    private var currencySymbol: String { Locale.current.currencySymbol ?? "$" }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    workStatsBanner
                    periodPicker
                    summaryCards
                    completionChart
                    diarySection
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showExport = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                }
            }
            .fullScreenCover(isPresented: $showExport) {
                PDFExportView()
            }
            .navigationDestination(isPresented: $showWorkStats) {
                WorkStatsView()
            }
        }
    }

    // MARK: - Work stats banner (💡 글로벌 스탠다드로 수정된 부분)

    private var workStatsBanner: some View {
        let cal = Calendar.current
        let now = Date()
        let thisYear  = cal.component(.year,  from: now)
        let thisMonth = cal.component(.month, from: now)

        let monthWorkPlans = allPlans.filter {
            $0.isWorkSchedule && $0.year == thisYear && $0.month == thisMonth
        }
        let unpaid        = monthWorkPlans.filter { !$0.isPaid }.reduce(0.0) { $0 + $1.expectedIncome }
        let totalExpected = monthWorkPlans.reduce(0.0) { $0 + $1.expectedIncome }

        return Button(action: { showWorkStats = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.15)).frame(width: 44, height: 44)
                    // 망치(hammer) 대신 서류가방(briefcase) 아이콘 사용
                    Image(systemName: "briefcase.fill").font(.system(size: 20)).foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "work.this.month", defaultValue: "This Month's Work"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)

                    if monthWorkPlans.isEmpty {
                        Text(String(localized: "work.no.schedule", defaultValue: "No work schedules"))
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 6) {
                            // ₩ 하드코딩 제거 및 로컬 통화 기호(currencySymbol) 적용
                            Text("\(currencySymbol)\(Int(totalExpected).formatted())")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                            if unpaid > 0 {
                                Text(String(format: String(localized: "work.unpaid.summary", defaultValue: "Unpaid: %@"), "\(currencySymbol)\(Int(unpaid).formatted())"))
                                    .font(.system(size: 13, weight: .medium)).foregroundColor(.red)
                            } else {
                                Text(String(localized: "work.all.paid", defaultValue: "All Paid"))
                                    .font(.system(size: 13)).foregroundColor(.green)
                            }
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.secondary.opacity(0.5))
            }
            .padding(14)
            .background(unpaid > 0 ? Color.red.opacity(0.06) : Color.secondary.opacity(0.06))
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(unpaid > 0 ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(Period.allCases, id: \.self) { period in
                Button(action: { selectedPeriod = period }) {
                    Text(period.rawValue)
                        .font(.system(size: 14, weight: selectedPeriod == period ? .semibold : .medium))
                        .foregroundStyle(selectedPeriod == period ? Color.white : Color.secondary)
                        .padding(.vertical, 8).padding(.horizontal, 16)
                        .background(selectedPeriod == period ? Color.green : Color.clear)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondary.opacity(0.1)).cornerRadius(20).padding(.top, 4)
    }

    // MARK: - Summary Cards

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
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(Color.primary)
            Text(title).font(.system(size: 12)).foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color.secondary.opacity(0.06)).cornerRadius(14)
    }

    // MARK: - Completion Chart

    private var completionChart: some View {
        let chartData = buildChartData()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Completions").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.primary)
            if chartData.isEmpty {
                Text("No data yet").font(.system(size: 14)).foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity).frame(height: 140)
            } else {
                SwiftBarChart(data: chartData)
            }
        }
        .padding(16).background(Color.secondary.opacity(0.06)).cornerRadius(14)
    }

    // MARK: - Diary Section

    private var diarySection: some View {
        let ds = computeDiaryStats()
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                Text("📓")
                Text("Diary").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.primary)
            }
            HStack(spacing: 10) {
                statCard(title: "Days",    value: "\(ds.daysWritten)",  icon: "calendar",   color: .purple)
                statCard(title: "Entries", value: "\(ds.totalEntries)", icon: "book.pages", color: .indigo)
                statCard(title: "Streak",  value: "\(ds.streak)d",      icon: "flame",      color: .orange)
            }
            if !ds.moodCounts.isEmpty { moodDistribution(ds.moodCounts) }
            if !ds.weeklyBar.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.secondary)
                    SwiftBarChart(data: ds.weeklyBar, barColor: .purple)
                }
            }
        }
        .padding(16).background(Color.secondary.opacity(0.06)).cornerRadius(14)
    }

    private func moodDistribution(_ counts: [(Mood, Int)]) -> some View {
            let total = counts.reduce(0) { $0 + $1.1 }
            return VStack(alignment: .leading, spacing: 8) {
                Text("Mood Distribution").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.secondary)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // 💡 수정: (mood, count) 대신 item으로 받아서 처리
                        ForEach(counts, id: \.0) { item in
                            let ratio = total > 0 ? CGFloat(item.1) / CGFloat(total) : 0
                            ZStack {
                                Rectangle().fill(item.0.color).frame(width: geo.size.width * ratio)
                                if ratio > 0.1 { Text(item.0.emoji).font(.system(size: 14)) }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 24)

                HStack(spacing: 14) {
                    // 💡 수정: (mood, count) 대신 item으로 받아서 처리
                    ForEach(counts, id: \.0) { item in
                        HStack(spacing: 3) {
                            Text(item.0.emoji).font(.system(size: 14))
                            Text("\(item.1)").font(.system(size: 12)).foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
        }

    // MARK: - Plan Data Computation

    private var filteredPlans: [Plan] {
        let cal = Calendar.current; let today = Date()
        switch selectedPeriod {
        case .day:
            let comps = cal.dateComponents([.year, .month, .day], from: today)
            return allPlans.filter { $0.year == comps.year! && $0.month == comps.month! && $0.day == comps.day! && $0.status != .canceled }
        case .week:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? today
            return allPlans.filter { $0.status != .canceled && $0.scheduledDateOnly >= weekStart && $0.scheduledDateOnly < weekEnd }
        case .month:
            let comps = cal.dateComponents([.year, .month], from: today)
            return allPlans.filter { $0.year == comps.year! && $0.month == comps.month! && $0.status != .canceled }
        }
    }

    struct PeriodStats {
        let total: Int; let completed: Int
        var rateString: String { total == 0 ? "0%" : "\(Int(round(Double(completed) / Double(total) * 100)))%" }
    }

    private func computeStats() -> PeriodStats {
        let plans = filteredPlans
        return PeriodStats(total: plans.count, completed: plans.filter { $0.status == .completed }.count)
    }

    struct ChartItem: Identifiable {
        let id = UUID(); let label: String; let count: Int
    }

    private func buildChartData() -> [ChartItem] {
        let cal = Calendar.current; let today = Date()
        switch selectedPeriod {
        case .day:
            let blocks: [(label: String, hour: Int)] = [("12AM", 0), ("6AM", 6), ("12PM", 12), ("6PM", 18)]
            return blocks.map { block in
                let cnt = filteredPlans.filter {
                    guard $0.status == .completed, let ca = $0.completedAt else { return false }
                    let h = cal.component(.hour, from: ca)
                    return h >= block.hour && h < block.hour + 6
                }.count
                return ChartItem(label: block.label, count: cnt)
            }
        case .week:
            guard let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
            let labels = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            return (0..<7).map { offset in
                let day = cal.date(byAdding: .day, value: offset, to: weekStart)!
                let comps = cal.dateComponents([.year, .month, .day], from: day)
                let cnt = filteredPlans.filter { $0.status == .completed && $0.year == comps.year! && $0.month == comps.month! && $0.day == comps.day! }.count
                return ChartItem(label: labels[offset], count: cnt)
            }
        case .month:
            let range = cal.range(of: .day, in: .month, for: today) ?? 1..<31
            return range.map { d in
                let cnt = filteredPlans.filter { $0.status == .completed && $0.day == d }.count
                let label = (d % 5 == 1 || d == range.upperBound - 1) ? "\(d)" : ""
                return ChartItem(label: label, count: cnt)
            }
        }
    }

    // MARK: - Diary Data Computation

    struct DiaryStats {
        let daysWritten: Int; let totalEntries: Int; let streak: Int; let moodCounts: [(Mood, Int)]; let weeklyBar: [ChartItem]
    }

    private func computeDiaryStats() -> DiaryStats {
        let cal = Calendar.current; let today = Date()
        let filtered: [DiaryEntry]

        switch selectedPeriod {
        case .day:
            let c = cal.dateComponents([.year, .month, .day], from: today)
            filtered = allDiaries.filter { $0.year == c.year! && $0.month == c.month! && $0.day == c.day! }
        case .week:
            guard let ws = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return DiaryStats(daysWritten: 0, totalEntries: 0, streak: 0, moodCounts: [], weeklyBar: []) }
            let we = cal.date(byAdding: .day, value: 7, to: ws) ?? today
            filtered = allDiaries.filter { $0.dateValue >= ws && $0.dateValue < we }
        case .month:
            let c = cal.dateComponents([.year, .month], from: today)
            filtered = allDiaries.filter { $0.year == c.year! && $0.month == c.month! }
        }

        // 💡 최적화: 스트릭 연산 O(1) 해시 비교 처리
        let diaryDayHashes = Set(allDiaries.map { $0.year * 10000 + $0.month * 100 + $0.day })
        var streak = 0
        var check = today

        while true {
            let hash = cal.component(.year, from: check) * 10000 + cal.component(.month, from: check) * 100 + cal.component(.day, from: check)
            if diaryDayHashes.contains(hash) {
                streak += 1
                check = cal.date(byAdding: .day, value: -1, to: check) ?? check
            } else { break }
        }

        var moodMap: [Mood: Int] = [:]
        filtered.forEach { if let m = $0.mood { moodMap[m, default: 0] += 1 } }
        let moodCounts = moodMap.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }

        var weeklyBar: [ChartItem] = []
        if let ws = cal.dateInterval(of: .weekOfYear, for: today)?.start {
            let labels = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            weeklyBar = (0..<7).map { off in
                let day = cal.date(byAdding: .day, value: off, to: ws)!
                let hash = cal.component(.year, from: day) * 10000 + cal.component(.month, from: day) * 100 + cal.component(.day, from: day)
                let cnt = allDiaries.filter { ($0.year * 10000 + $0.month * 100 + $0.day) == hash }.count
                return ChartItem(label: labels[off], count: cnt)
            }
        }

        let dateSet = Set(filtered.map { $0.year * 10000 + $0.month * 100 + $0.day })
        return DiaryStats(daysWritten: dateSet.count, totalEntries: filtered.count, streak: streak, moodCounts: moodCounts, weeklyBar: weeklyBar)
    }
}

// MARK: - Swift Charts Bar Chart

struct SwiftBarChart: View {
    let data: [StatsView.ChartItem]
    var barColor: Color = .green

    var body: some View {
        Chart {
            ForEach(data) { item in
                BarMark(x: .value("Label", item.label), y: .value("Count", item.count))
                    .foregroundStyle(item.count > 0 ? barColor : .gray.opacity(0.3))
                    .annotation(position: .top) {
                        if item.count > 0 {
                            Text("\(item.count)").font(.system(size: 10, weight: .semibold)).foregroundStyle(barColor)
                        }
                    }
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis { AxisMarks(values: .automatic) }
        .frame(height: 160)
    }
}
