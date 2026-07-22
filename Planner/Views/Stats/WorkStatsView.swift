import SwiftUI
import SwiftData

// MARK: - Work Plan Edit Sheet

struct WorkPlanEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let plan: Plan
    
    // 💡 불필요한 옵션 버튼(WorkUnitsOption)을 제거하고 범용적인 입력 상태로 통일
    @State private var customWorkUnits: String = ""
    @State private var dailyWageText: String   = ""
    @State private var siteName: String        = ""
    @State private var isPaid: Bool            = false

    private var resolvedWorkUnits: Double { Double(customWorkUnits) ?? 1.0 }
    private var resolvedDailyWage: Int { Int(dailyWageText.replacingOccurrences(of: ",", with: "")) ?? 0 }
    private var previewIncome: Double { resolvedWorkUnits * Double(resolvedDailyWage) }

    // 기기 환경에 맞는 로컬 통화 기호 (예: $, €, ₩)
    private var currencySymbol: String { Locale.current.currencySymbol ?? "$" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "briefcase.fill").foregroundColor(.orange)
                        Text(plan.title).font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text("\(plan.year)/\(plan.month)/\(plan.day)").font(.system(size: 13)).foregroundColor(.secondary)
                    }
                } header: { Text(String(localized: "work.section.schedule", defaultValue: "Schedule")) }
                
                Section {
                    HStack {
                        Image(systemName: "building.2.fill").foregroundColor(.secondary)
                        TextField(String(localized: "work.location.placeholder", defaultValue: "Location or Client name"), text: $siteName)
                    }
                } header: { Text(String(localized: "work.section.location", defaultValue: "Workplace / Client")) }
                
                // 💡 글로벌 스탠다드에 맞춘 (시간/수량) × (단가) 입력 UI
                Section {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "work.duration.label", defaultValue: "Hours / Qty"))
                                .font(.caption).foregroundColor(.secondary)
                            HStack {
                                TextField("e.g. 8.5", text: $customWorkUnits)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 16, weight: .medium))
                                Text("×")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "work.rate.label", defaultValue: "Pay Rate"))
                                .font(.caption).foregroundColor(.secondary)
                            HStack {
                                Text(currencySymbol).foregroundColor(.secondary)
                                TextField("Rate", text: $dailyWageText)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if previewIncome > 0 {
                        HStack {
                            Text(String(localized: "work.income.preview", defaultValue: "Total Pay")).foregroundColor(.secondary)
                            Spacer()
                            Text("\(currencySymbol)\(Int(previewIncome).formatted())")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.orange)
                        }
                    }
                } header: { Text(String(localized: "work.section.earnings", defaultValue: "Earnings Calculation")) }
                  footer: { Text(String(localized: "work.footer.calc", defaultValue: "Enter hours worked and hourly rate, or days and daily rate.")).foregroundColor(.secondary) }
                
                Section {
                    Toggle(isOn: $isPaid) {
                        HStack(spacing: 10) {
                            Image(systemName: isPaid ? "checkmark.seal.fill" : "checkmark.seal").font(.system(size: 20)).foregroundColor(isPaid ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isPaid ? String(localized: "work.paid.toggle.label", defaultValue: "Paid") : String(localized: "work.unpaid.toggle.label", defaultValue: "Unpaid"))
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(isPaid ? .green : .red)
                            }
                        }
                    }.tint(.green)
                } header: { Text(String(localized: "work.section.payment", defaultValue: "Payment Status")) }
            }
            .navigationTitle(String(localized: "work.edit.nav.title", defaultValue: "Edit Work Schedule")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() }.foregroundColor(.secondary) }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Save") { save() }.font(.system(size: 15, weight: .semibold)).foregroundColor(.orange) }
            }.onAppear { loadPlanData() }
        }
    }
    
    private func loadPlanData() {
        // 기존 옵션 버튼 방식의 데이터가 남아있어도 자연스럽게 텍스트로 전환
        customWorkUnits = plan.workUnits.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", plan.workUnits) : String(format: "%.1f", plan.workUnits)
        dailyWageText = plan.dailyWage > 0 ? "\(plan.dailyWage)" : ""
        siteName = plan.siteName
        isPaid = plan.isPaid
    }
    
    private func save() {
        plan.workUnits = resolvedWorkUnits
        plan.dailyWage = resolvedDailyWage
        plan.siteName = siteName
        plan.isPaid = isPaid
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
    private var currencySymbol: String { Locale.current.currencySymbol ?? "$" }

    // 통계 계산용 튜플 타입
    typealias WorkMonthStats = (plans: [Plan], days: Int, units: Double, expected: Double, paid: Double, unpaid: Double, rate: Double)

    private var stats: WorkMonthStats {
        let y = calendar.component(.year, from: displayedMonth)
        let m = calendar.component(.month, from: displayedMonth)
        let workPlans = allPlans.filter { $0.isWorkSchedule && $0.year == y && $0.month == m }
                                .sorted { $0.scheduledDateOnly < $1.scheduledDateOnly }
        
        let days = workPlans.count
        let units = workPlans.reduce(0.0) { $0 + $1.workUnits }
        let expected = workPlans.reduce(0.0) { $0 + $1.expectedIncome }
        let paid = workPlans.filter { $0.isPaid }.reduce(0.0) { $0 + $1.expectedIncome }
        let unpaid = expected - paid
        let rate = expected > 0 ? paid / expected : 0.0
        
        return (workPlans, days, units, expected, paid, unpaid, rate)
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func prevMonth() { displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth }
    private func nextMonth() { displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth }

    var body: some View {
        let currentStats = stats
        
        return NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    monthNavigator
                    summarySection(currentStats)
                    incomeProgressSection(currentStats)
                    workListSection(currentStats)
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .navigationTitle(String(localized: "work.stats.nav.title", defaultValue: "Work & Earnings"))
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $editingPlan) { WorkPlanEditSheet(plan: $0) }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button(action: prevMonth) {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold)).foregroundColor(.orange)
                    .frame(width: 36, height: 36).background(Color.orange.opacity(0.10)).cornerRadius(10)
            }.buttonStyle(.plain)
            Spacer()
            Text(monthTitle).font(.system(size: 18, weight: .bold))
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)).foregroundColor(.orange)
                    .frame(width: 36, height: 36).background(Color.orange.opacity(0.10)).cornerRadius(10)
            }.buttonStyle(.plain)
        }.padding(.top, 4)
    }

    private func summarySection(_ currentStats: WorkMonthStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(icon: "calendar.badge.checkmark", iconColor: .blue, label: String(localized: "work.stat.days", defaultValue: "Shifts"), value: "\(currentStats.days)")
            summaryCard(icon: "clock.fill", iconColor: .orange, label: String(localized: "work.stat.total.duration", defaultValue: "Hours/Qty"), value: String(format: "%.1f", currentStats.units))
            summaryCard(icon: "banknote.fill", iconColor: .green, label: String(localized: "work.stat.expected", defaultValue: "Expected"), value: "\(currencySymbol)\(Int(currentStats.expected).formatted())")
            summaryCard(icon: "exclamationmark.circle.fill", iconColor: currentStats.unpaid > 0 ? .red : .secondary, label: String(localized: "work.stat.unpaid", defaultValue: "Unpaid"), value: "\(currencySymbol)\(Int(currentStats.unpaid).formatted())")
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

    private func incomeProgressSection(_ currentStats: WorkMonthStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "work.stat.payment.status", defaultValue: "Payment Status")).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text(String(format: String(localized: "work.payment.rate", defaultValue: "%.0f%% Paid"), currentStats.rate * 100))
                    .font(.system(size: 15, weight: .bold)).foregroundColor(currentStats.rate >= 1.0 ? .green : .orange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)).frame(height: 14)
                    RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * currentStats.rate, height: 14)
                        .animation(.easeInOut(duration: 0.4), value: currentStats.rate)
                }
            }.frame(height: 14)
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text(String(format: String(localized: "work.paid.amount", defaultValue: "Paid: %@"), "\(currencySymbol)\(Int(currentStats.paid).formatted())")).font(.system(size: 13)).foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.red.opacity(0.7)).frame(width: 8, height: 8)
                    Text(String(format: String(localized: "work.unpaid.amount", defaultValue: "Unpaid: %@"), "\(currencySymbol)\(Int(currentStats.unpaid).formatted())")).font(.system(size: 13)).foregroundColor(.secondary)
                }
            }
        }
        .padding(16).background(Color.secondary.opacity(0.06)).cornerRadius(14)
    }

    private func workListSection(_ currentStats: WorkMonthStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "work.section.history", defaultValue: "History")).font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(currentStats.plans.count)").font(.system(size: 14)).foregroundColor(.secondary)
                Text(String(localized: "work.tap.edit", defaultValue: "(Tap to edit)")).font(.system(size: 12)).foregroundColor(.orange)
            }
            if currentStats.plans.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "briefcase").font(.system(size: 36)).foregroundColor(.orange.opacity(0.3))
                    Text(String(localized: "work.empty.title", defaultValue: "No Work Records")).font(.system(size: 15, weight: .medium))
                    Text(String(localized: "work.empty.desc", defaultValue: "Add work schedules to see your stats here.")).font(.system(size: 13)).foregroundColor(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 32)
            } else {
                VStack(spacing: 10) {
                    ForEach(currentStats.plans) { plan in
                        workRow(plan).contentShape(Rectangle()).onTapGesture { editingPlan = plan }
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
                Text(dayOfWeek(for: plan.scheduledDateOnly)).font(.system(size: 11)).foregroundColor(.secondary)
            }.frame(width: 36)

            Rectangle().fill(plan.isPaid ? Color.green : Color.orange).frame(width: 3).cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title).font(.system(size: 14, weight: .medium))
                HStack(spacing: 6) {
                    if !plan.siteName.isEmpty { Label(plan.siteName, systemImage: "building.2").font(.system(size: 12)).foregroundColor(.secondary) }
                    
                    // 💡 "1.5h" 형태로 범용적이고 깔끔하게 표시
                    let durationText = plan.workUnits.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", plan.workUnits) : String(format: "%.1f", plan.workUnits)
                    Text("\(durationText)h")
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.orange)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Color.orange.opacity(0.12)).cornerRadius(4)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(currencySymbol)\(Int(plan.expectedIncome).formatted())").font(.system(size: 14, weight: .semibold))
                Button(action: { plan.isPaid.toggle(); try? modelContext.save() }) {
                    HStack(spacing: 4) {
                        Image(systemName: plan.isPaid ? "checkmark.circle.fill" : "circle").font(.system(size: 12))
                        Text(plan.isPaid ? String(localized: "work.paid", defaultValue: "Paid") : String(localized: "work.unpaid", defaultValue: "Unpaid")).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(plan.isPaid ? .green : .red).padding(.horizontal, 8).padding(.vertical, 4)
                    .background((plan.isPaid ? Color.green : Color.red).opacity(0.12)).cornerRadius(6)
                }.buttonStyle(.plain)
            }
            Image(systemName: "pencil").font(.system(size: 13)).foregroundColor(.secondary.opacity(0.4))
        }
        .padding(12).background(Color.secondary.opacity(0.04)).cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(plan.isPaid ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1))
    }

    private func dayOfWeek(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.locale = Locale.current
        return f.string(from: date)
    }
}
