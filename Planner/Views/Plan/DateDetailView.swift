import SwiftUI
import SwiftData

struct DateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let date: Date
    private let calendar = Calendar.current

    // 💡 최적화 포인트: modelContext.fetch()로 DB 전체를 로드하는 대신,
    // SwiftData의 @Query와 Predicate를 사용하여 해당 날짜의 데이터만 가볍게 가져옵니다.
    @Query private var dailyPlans: [Plan]

    // 기기 환경에 맞는 로컬 통화 기호 (예: $, €, ₩)
    private var currencySymbol: String { Locale.current.currencySymbol ?? "$" }

    init(date: Date) {
        self.date = date
        let cal = Calendar.current
        let y = cal.component(.year,  from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day,   from: date)
        
        // 메모리 절약과 렌더링 렉 방지를 위한 날짜 필터링
        let filter = #Predicate<Plan> { plan in
            plan.year == y && plan.month == m && plan.day == d
        }
        _dailyPlans = Query(filter: filter)
    }

    private var year:  Int { calendar.component(.year,  from: date) }
    private var month: Int { calendar.component(.month, from: date) }
    private var day:   Int { calendar.component(.day,   from: date) }

    private var dateTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: date)
    }

    // 메모리에서 정렬 처리 (SwiftData Enum Sort 버그 우회)
    private var plansForDate: [Plan] {
        dailyPlans.sorted {
            let oA = statusOrder($0.status), oB = statusOrder($1.status)
            if oA != oB { return oA < oB }
            if $0.hasTime && $1.hasTime {
                if $0.hour != $1.hour { return $0.hour < $1.hour }
                return $0.minute < $1.minute
            }
            if $0.hasTime { return true }; if $1.hasTime { return false }
            return $0.createdAt < $1.createdAt
        }
    }

    private var completedPlans: [Plan]   { plansForDate.filter { $0.status == .completed } }
    private var plannedPlans:   [Plan]   { plansForDate.filter { $0.status == .planned   } }
    private var canceledPlans:  [Plan]   { plansForDate.filter { $0.status == .canceled  } }
    private var workPlansForDate: [Plan] { plansForDate.filter { $0.isWorkSchedule } }

    private var dayTotalUnits:     Double { workPlansForDate.reduce(0) { $0 + $1.workUnits } }
    private var dayExpectedIncome: Double { workPlansForDate.reduce(0) { $0 + $1.expectedIncome } }

    var body: some View {
        List {
            Section { dateHeader } header: { Text("Date").font(.headline) }

            if !workPlansForDate.isEmpty {
                Section { workSummaryCard }
                header: { Text("💼 \(String(localized: "work.summary.card", defaultValue: "Work Summary"))").font(.subheadline) }
            }

            if !completedPlans.isEmpty {
                Section {
                    ForEach(completedPlans) { planRow($0) }.onDelete { deletePlans(completedPlans, at: $0) }
                } header: { Text("✅ Completed (\(completedPlans.count))").font(.subheadline) }
            }
            if !plannedPlans.isEmpty {
                Section {
                    ForEach(plannedPlans) { planRow($0) }.onDelete { deletePlans(plannedPlans, at: $0) }
                } header: { Text("📋 Planned (\(plannedPlans.count))").font(.subheadline) }
            }
            if !canceledPlans.isEmpty {
                Section {
                    ForEach(canceledPlans) { planRow($0) }.onDelete { deletePlans(canceledPlans, at: $0) }
                } header: { Text("🚫 Canceled (\(canceledPlans.count))").font(.subheadline) }
            }

            if plansForDate.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "leaf").font(.title).foregroundColor(.green.opacity(0.3))
                        Text("No plans for this day").font(.body).foregroundColor(.secondary)
                        Text("Add a plan from the home screen to grow grass here! 🌱")
                            .font(.subheadline).foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 32)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(dateTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // 💡 글로벌 스탠다드 적용: 총 일한 시간 표기 및 동적 통화 기호 적용
    private var workSummaryCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: "clock.fill").font(.system(size: 20)).foregroundColor(.orange)
                let totalDurationText = dayTotalUnits.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", dayTotalUnits) : String(format: "%.1f", dayTotalUnits)
                Text("\(totalDurationText)h")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.orange)
            }
            .frame(width: 64)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "work.income.expected.label", defaultValue: "Expected Pay")).font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    Text("\(currencySymbol)\(Int(dayExpectedIncome).formatted())").font(.system(size: 14, weight: .semibold))
                }
                let paidCount = workPlansForDate.filter { $0.isPaid }.count
                HStack {
                    Text(String(localized: "work.payment.status.label", defaultValue: "Payment Status")).font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: String(localized: "work.complete.count", defaultValue: "%d / %d Paid"), paidCount, workPlansForDate.count))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(paidCount == workPlansForDate.count ? .green : .red)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var dateHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(grassColor(completedPlans.count)).frame(width: 48, height: 48)
                if !completedPlans.isEmpty { Text("🌱").font(.title2) }
                else { Text("\(day)").font(.headline).foregroundColor(.secondary) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(dateTitle).font(.headline).fixedSize(horizontal: false, vertical: true)
                let summary: String = {
                    var p: [String] = []
                    if !completedPlans.isEmpty { p.append("\(completedPlans.count) completed") }
                    if !plannedPlans.isEmpty   { p.append("\(plannedPlans.count) planned") }
                    return p.isEmpty ? "No plans" : p.joined(separator: ", ")
                }()
                Text(summary).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func planRow(_ plan: Plan) -> some View {
        NavigationLink(destination: PlanDetailView(plan: plan)) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: { PlanActions.toggleComplete(plan, context: modelContext) }) {
                    Image(systemName: plan.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(plan.status == .completed ? .green : .secondary)
                        .padding(.trailing, 12)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(plan.isWorkSchedule ? Color.orange : (plan.category?.color ?? .gray))
                    .frame(width: 3).cornerRadius(2)

                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(titleColor(plan))
                        .strikethrough(plan.status != .planned)
                        .fixedSize(horizontal: false, vertical: true)

                    if !plan.memo.isEmpty {
                        Text(plan.memo).font(.footnote).foregroundColor(.secondary.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                    }

                    if let timeStr = plan.timeDisplay {
                        HStack(spacing: 4) {
                            Image(systemName: plan.hasEndTime ? "clock.arrow.2.circlepath" : "clock").font(.caption2)
                            Text(timeStr).font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(plan.isWorkSchedule ? .orange : .blue)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((plan.isWorkSchedule ? Color.orange : Color.blue).opacity(0.10)).cornerRadius(6)
                    }

                    if plan.isWorkSchedule { workInfoBadges(plan) } else { generalMeta(plan) }

                    if plan.status == .completed, let ca = plan.completedAt {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle").font(.caption2).foregroundColor(.green)
                            Text("Completed on \(formattedDateTime(ca))").font(.caption2).foregroundColor(.green.opacity(0.8))
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
        }
    }

    // 💡 글로벌 스탠다드 적용: 시간(h), 급여, 근무지 표시
    @ViewBuilder
    private func workInfoBadges(_ plan: Plan) -> some View {
        HStack(spacing: 6) {
            let durationText = plan.workUnits.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", plan.workUnits) : String(format: "%.1f", plan.workUnits)
            Label("\(durationText)h", systemImage: "clock.fill") // 망치 대신 시계로 변경
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.orange)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange.opacity(0.13)).cornerRadius(5)

            if plan.expectedIncome > 0 {
                Text("\(currencySymbol)\(Int(plan.expectedIncome).formatted())")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.10)).cornerRadius(5)
            }
        }

        HStack(spacing: 6) {
            Button(action: { togglePaid(plan) }) {
                HStack(spacing: 3) {
                    Image(systemName: plan.isPaid ? "checkmark.circle.fill" : "circle").font(.system(size: 10))
                    Text(plan.isPaid ? String(localized: "work.paid", defaultValue: "Paid") : String(localized: "work.unpaid", defaultValue: "Unpaid"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(plan.isPaid ? .green : .red)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background((plan.isPaid ? Color.green : Color.red).opacity(0.13)).cornerRadius(5)
            }.buttonStyle(.plain)

            if !plan.siteName.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "building.2").font(.system(size: 10)).foregroundColor(.secondary) // 핀 대신 빌딩으로 변경
                    Text(plan.siteName).font(.system(size: 11)).foregroundColor(.secondary)
                }.lineLimit(1)
            }
        }
    }

    private func generalMeta(_ plan: Plan) -> some View {
        HStack(spacing: 6) {
            if let name = plan.category?.name { Text(name).font(.caption).foregroundColor(plan.category?.color ?? .gray) }
            if plan.notificationEnabled { Image(systemName: "bell.fill").font(.caption2).foregroundColor(.orange) }
            if plan.calendarSyncEnabled { Image(systemName: "calendar").font(.caption2).foregroundColor(.blue) }
        }
    }

    // 💡 최적화: 완료/삭제 로직을 PlanActions Helper로 일원화
    private func togglePaid(_ plan: Plan) {
        plan.isPaid = !plan.isPaid
        try? modelContext.save()
        if plan.calendarSyncEnabled {
            Task {
                let newId = await CalendarService.shared.updateEvent(for: plan)
                if let id = newId, id != plan.eventIdentifier {
                    plan.eventIdentifier = id
                    try? modelContext.save()
                }
            }
        }
    }

    private func deletePlans(_ plans: [Plan], at offsets: IndexSet) {
        for i in offsets {
            PlanActions.delete(plans[i], context: modelContext)
        }
    }

    private func statusOrder(_ s: PlanStatus) -> Int { switch s { case .completed: return 0; case .planned: return 1; case .canceled: return 2 } }
    private func titleColor(_ plan: Plan) -> Color { switch plan.status { case .planned: return .primary; case .completed: return .secondary; case .canceled: return .secondary.opacity(0.6) } }
    private func grassColor(_ count: Int) -> Color {
        switch count {
        case 0: return Color(red: 0.88, green: 0.92, blue: 0.88)
        case 1: return Color(red: 0.56, green: 0.83, blue: 0.47)
        case 2...3: return Color(red: 0.25, green: 0.66, blue: 0.25)
        default: return Color(red: 0.10, green: 0.45, blue: 0.10)
        }
    }
    private func formattedDateTime(_ date: Date) -> String { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: date) }
}
