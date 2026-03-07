import SwiftUI
import SwiftData

// MARK: - Work Plan Edit Sheet

struct WorkPlanEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let plan: Plan

    @State private var workUnitsOption: WorkUnitsOption = .full
    @State private var customWorkUnits: String = ""
    @State private var dailyWageText: String   = ""
    @State private var siteName: String        = ""
    @State private var isPaid: Bool            = false

    private var resolvedWorkUnits: Double {
        workUnitsOption == .custom ? (Double(customWorkUnits) ?? 1.0) : (workUnitsOption.value ?? 1.0)
    }
    private var resolvedDailyWage: Int {
        Int(dailyWageText.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    private var previewIncome: Double { resolvedWorkUnits * Double(resolvedDailyWage) }

    var body: some View {
        NavigationStack {
            Form {
                // Plan info (read-only)
                Section {
                    HStack {
                        Image(systemName: "hammer.fill").foregroundColor(.orange)
                        Text(plan.title).font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text("\(plan.year)/\(plan.month)/\(plan.day)")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    }
                } header: { Text(String(localized: "work.section.schedule")) }

                // Units
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            ForEach(WorkUnitsOption.allCases, id: \.self) { opt in
                                Button(action: { workUnitsOption = opt }) {
                                    Text(opt.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(workUnitsOption == opt ? Color.orange : Color.secondary.opacity(0.12))
                                        .foregroundColor(workUnitsOption == opt ? .white : .primary)
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if workUnitsOption == .custom {
                            HStack {
                                TextField(String(localized: "work.custom.units.placeholder"),
                                          text: $customWorkUnits).keyboardType(.decimalPad)
                                Text(String(localized: "work.stat.total.units"))
                                    .foregroundColor(.secondary).font(.system(size: 14))
                            }
                            .padding(10).background(Color.secondary.opacity(0.08)).cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                } header: { Text(String(localized: "work.section.units")) }

                // Wage
                Section {
                    HStack {
                        Text("₩").foregroundColor(.secondary)
                        TextField(String(localized: "work.wage.placeholder"),
                                  text: $dailyWageText).keyboardType(.numberPad)
                    }
                    if previewIncome > 0 {
                        HStack {
                            Text(String(localized: "work.income.preview")).foregroundColor(.secondary)
                            Spacer()
                            Text("₩\(Int(previewIncome).formatted())")
                                .font(.system(size: 15, weight: .bold)).foregroundColor(.orange)
                        }
                    }
                } header: { Text(String(localized: "work.section.wage")) }

                // Site
                Section {
                    HStack {
                        Image(systemName: "mappin.and.ellipse").foregroundColor(.secondary)
                        TextField(String(localized: "work.site.placeholder"), text: $siteName)
                    }
                } header: { Text(String(localized: "work.section.site")) }

                // Payment
                Section {
                    Toggle(isOn: $isPaid) {
                        HStack(spacing: 10) {
                            Image(systemName: isPaid ? "wonsign.circle.fill" : "wonsign.circle")
                                .font(.system(size: 20))
                                .foregroundColor(isPaid ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isPaid
                                     ? String(localized: "work.paid.toggle.label")
                                     : String(localized: "work.unpaid.toggle.label"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(isPaid ? .green : .red)
                                if previewIncome > 0 {
                                    Text("₩\(Int(previewIncome).formatted())")
                                        .font(.system(size: 13)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .tint(.green)
                } header: {
                    Text(String(localized: "work.section.payment"))
                } footer: {
                    Text(String(localized: "work.footer.payment")).foregroundColor(.secondary)
                }
            }
            .navigationTitle(String(localized: "work.edit.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(.orange)
                }
            }
            .onAppear { loadPlanData() }
        }
    }

    private func loadPlanData() {
        switch plan.workUnits {
        case 0.5:  workUnitsOption = .half
        case 1.0:  workUnitsOption = .full
        case 1.5:  workUnitsOption = .oneHalf
        default:
            workUnitsOption = .custom
            customWorkUnits = String(format: "%.1f", plan.workUnits)
        }
        dailyWageText = plan.dailyWage > 0 ? "\(plan.dailyWage)" : ""
        siteName      = plan.siteName
        isPaid        = plan.isPaid
    }

    private func save() {
        plan.workUnits = resolvedWorkUnits
        plan.dailyWage = resolvedDailyWage
        plan.siteName  = siteName
        plan.isPaid    = isPaid
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Work Stats View

struct WorkStatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPlans: [Plan]

    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var editingPlan: Plan? = nil

    private let calendar = Calendar.current

    private var currentYear:  Int { calendar.component(.year,  from: displayedMonth) }
    private var currentMonth: Int { calendar.component(.month, from: displayedMonth) }

    private var workPlans: [Plan] {
        allPlans.filter {
            $0.isWorkSchedule && $0.year == currentYear && $0.month == currentMonth
        }
        .sorted { $0.scheduledDateOnly < $1.scheduledDateOnly }
    }

    private var totalWorkDays:  Int    { workPlans.count }
    private var totalWorkUnits: Double { workPlans.reduce(0) { $0 + $1.workUnits } }
    private var expectedIncome: Double { workPlans.reduce(0) { $0 + $1.expectedIncome } }
    private var paidIncome:     Double { workPlans.filter { $0.isPaid }.reduce(0) { $0 + $1.expectedIncome } }
    private var unpaidIncome:   Double { expectedIncome - paidIncome }
    private var paidRate:       Double { expectedIncome > 0 ? paidIncome / expectedIncome : 0 }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func prevMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }
    private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    monthNavigator
                    summarySection
                    incomeProgressSection
                    workListSection
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .navigationTitle(String(localized: "work.stats.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingPlan) { WorkPlanEditSheet(plan: $0) }
        }
    }

    // MARK: - Month navigator

    private var monthNavigator: some View {
        HStack {
            Button(action: prevMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.orange)
                    .frame(width: 36, height: 36)
                    .background(Color.orange.opacity(0.10)).cornerRadius(10)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(monthTitle).font(.system(size: 18, weight: .bold))
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.orange)
                    .frame(width: 36, height: 36)
                    .background(Color.orange.opacity(0.10)).cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Summary cards

    private var summarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(icon: "calendar.badge.checkmark", iconColor: .blue,
                        label: String(localized: "work.stat.days"),
                        value: "\(totalWorkDays)")
            summaryCard(icon: "hammer.fill", iconColor: .orange,
                        label: String(localized: "work.stat.total.units"),
                        value: String(format: "%.1f", totalWorkUnits))
            summaryCard(icon: "wonsign.circle.fill", iconColor: .green,
                        label: String(localized: "work.stat.expected"),
                        value: "₩\(Int(expectedIncome).formatted())")
            summaryCard(icon: "exclamationmark.circle.fill",
                        iconColor: unpaidIncome > 0 ? .red : .secondary,
                        label: String(localized: "work.stat.unpaid"),
                        value: "₩\(Int(unpaidIncome).formatted())")
        }
    }

    private func summaryCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 24)).foregroundColor(iconColor)
            Text(value).font(.system(size: 18, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color.secondary.opacity(0.06)).cornerRadius(14)
    }

    // MARK: - Income progress

    private var incomeProgressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "work.stat.payment.status"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(String(format: String(localized: "work.payment.rate"), paidRate * 100))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(paidRate >= 1.0 ? .green : .orange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12)).frame(height: 14)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [.green, .green.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * paidRate, height: 14)
                        .animation(.easeInOut(duration: 0.4), value: paidRate)
                }
            }
            .frame(height: 14)
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text(String(format: String(localized: "work.paid.amount"),
                                Int(paidIncome).formatted()))
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8, height: 8)
                    Text(String(format: String(localized: "work.unpaid.amount"),
                                Int(unpaidIncome).formatted()))
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }
            }
        }
        .padding(16).background(Color.secondary.opacity(0.06)).cornerRadius(14)
    }

    // MARK: - Work list

    private var workListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "work.section.history"))
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(workPlans.count)")
                    .font(.system(size: 14)).foregroundColor(.secondary)
                Text(String(localized: "work.tap.edit"))
                    .font(.system(size: 12)).foregroundColor(.orange)
            }

            if workPlans.isEmpty {
                emptyWorkState
            } else {
                VStack(spacing: 10) {
                    ForEach(workPlans) { plan in
                        workRow(plan)
                            .contentShape(Rectangle())
                            .onTapGesture { editingPlan = plan }
                    }
                }
            }
        }
        .padding(16).background(Color.secondary.opacity(0.06)).cornerRadius(14)
    }

    private func workRow(_ plan: Plan) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(plan.day)").font(.system(size: 16, weight: .bold))
                Text(dayOfWeek(plan)).font(.system(size: 11)).foregroundColor(.secondary)
            }
            .frame(width: 36)

            Rectangle().fill(plan.isPaid ? Color.green : Color.orange)
                .frame(width: 3).cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title).font(.system(size: 14, weight: .medium))
                HStack(spacing: 6) {
                    if !plan.siteName.isEmpty {
                        Label(plan.siteName, systemImage: "mappin")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Text(String(format: String(localized: "work.units.label"), plan.workUnits))
                        .font(.system(size: 12)).foregroundColor(.orange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12)).cornerRadius(4)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("₩\(Int(plan.expectedIncome).formatted())")
                    .font(.system(size: 14, weight: .semibold))

                Button(action: { togglePaid(plan) }) {
                    HStack(spacing: 4) {
                        Image(systemName: plan.isPaid ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                        Text(plan.isPaid
                             ? String(localized: "work.paid")
                             : String(localized: "work.unpaid"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(plan.isPaid ? .green : .red)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((plan.isPaid ? Color.green : Color.red).opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Image(systemName: "pencil")
                .font(.system(size: 13)).foregroundColor(.secondary.opacity(0.4))
        }
        .padding(12).background(Color.secondary.opacity(0.04)).cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(plan.isPaid ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func togglePaid(_ plan: Plan) {
        plan.isPaid = !plan.isPaid
        try? modelContext.save()
    }

    private var emptyWorkState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer").font(.system(size: 36)).foregroundColor(.orange.opacity(0.3))
            Text(String(localized: "work.empty.title"))
                .font(.system(size: 15, weight: .medium))
            Text(String(localized: "work.empty.desc"))
                .font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
    }

    private func dayOfWeek(_ plan: Plan) -> String {
        var c = DateComponents()
        c.year = plan.year; c.month = plan.month; c.day = plan.day
        guard let date = calendar.date(from: c) else { return "" }
        // 시스템 로케일에 맞게 요일 표시
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale.current
        return f.string(from: date)
    }
}

#Preview {
    WorkStatsView()
        .modelContainer(for: [Category.self, Plan.self], inMemory: true)
}
