import SwiftUI
import SwiftData

struct DateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let date: Date
    private let calendar = Calendar.current

    private var year:  Int { calendar.component(.year,  from: date) }
    private var month: Int { calendar.component(.month, from: date) }
    private var day:   Int { calendar.component(.day,   from: date) }

    private var dateTitle: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: date)
    }

    private var plansForDate: [Plan] {
        guard let all = try? modelContext.fetch(FetchDescriptor<Plan>()) else { return [] }
        return all.filter { $0.year == year && $0.month == month && $0.day == day }
            .sorted {
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
                header: { Text("🔨 \(String(localized: "work.summary.card"))").font(.subheadline) }
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

    // MARK: - Work summary card

    private var workSummaryCard: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Image(systemName: "hammer.fill").font(.system(size: 20)).foregroundColor(.orange)
                Text(String(format: String(localized: "work.units.label"), dayTotalUnits))
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.orange)
            }
            .frame(width: 64)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "work.income.expected.label"))
                        .font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    Text("₩\(Int(dayExpectedIncome).formatted())")
                        .font(.system(size: 14, weight: .semibold))
                }
                let paidCount = workPlansForDate.filter { $0.isPaid }.count
                HStack {
                    Text(String(localized: "work.payment.status.label"))
                        .font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: String(localized: "work.complete.count"),
                                paidCount, workPlansForDate.count))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(paidCount == workPlansForDate.count ? .green : .red)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Date header

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

    // MARK: - Plan row

    @ViewBuilder
    private func planRow(_ plan: Plan) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: { toggleComplete(plan) }) {
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
                    Text(plan.memo).font(.footnote).foregroundColor(.secondary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Time range badge
                if let timeStr = plan.timeDisplay {
                    HStack(spacing: 4) {
                        Image(systemName: plan.hasEndTime ? "clock.arrow.2.circlepath" : "clock")
                            .font(.caption2)
                        Text(timeStr).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(plan.isWorkSchedule ? .orange : .blue)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((plan.isWorkSchedule ? Color.orange : Color.blue).opacity(0.10))
                    .cornerRadius(6)
                }

                if plan.isWorkSchedule {
                    workInfoBadges(plan)
                } else {
                    generalMeta(plan)
                }

                if plan.status == .completed, let ca = plan.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle").font(.caption2).foregroundColor(.green)
                        Text("Completed on \(formattedDateTime(ca))")
                            .font(.caption2).foregroundColor(.green.opacity(0.8))
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Work badges (2-row layout)

    @ViewBuilder
    private func workInfoBadges(_ plan: Plan) -> some View {
        // Row 1: units + income
        HStack(spacing: 6) {
            Label(String(format: String(localized: "work.units.label"), plan.workUnits),
                  systemImage: "hammer.fill")
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.orange)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.orange.opacity(0.13)).cornerRadius(5)

            if plan.expectedIncome > 0 {
                Text("₩\(Int(plan.expectedIncome).formatted())")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.10)).cornerRadius(5)
            }
        }

        // Row 2: payment badge (tappable) + site name
        HStack(spacing: 6) {
            Button(action: { togglePaid(plan) }) {
                HStack(spacing: 3) {
                    Image(systemName: plan.isPaid ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                    Text(plan.isPaid
                         ? String(localized: "work.paid")
                         : String(localized: "work.unpaid"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(plan.isPaid ? .green : .red)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background((plan.isPaid ? Color.green : Color.red).opacity(0.13))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)

            if !plan.siteName.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "mappin").font(.system(size: 10)).foregroundColor(.secondary)
                    Text(plan.siteName).font(.system(size: 11)).foregroundColor(.secondary)
                }
                .lineLimit(1)
            }
        }
    }

    private func generalMeta(_ plan: Plan) -> some View {
        HStack(spacing: 6) {
            if let name = plan.category?.name {
                Text(name).font(.caption).foregroundColor(plan.category?.color ?? .gray)
            }
            if plan.notificationEnabled {
                Image(systemName: "bell.fill").font(.caption2).foregroundColor(.orange)
            }
            if plan.calendarSyncEnabled {
                Image(systemName: "calendar").font(.caption2).foregroundColor(.blue)
            }
        }
    }

    // MARK: - Actions

    private func toggleComplete(_ plan: Plan) {
        if plan.status == .completed {
            plan.status = .planned; plan.completedAt = nil
            if plan.notificationEnabled && plan.hasTime {
                Task { await NotificationService.shared.schedule(for: plan) }
            }
        } else {
            NotificationService.shared.cancel(planId: plan.id)
            plan.status = .completed; plan.completedAt = Date()
        }
        try? modelContext.save()
    }

    private func togglePaid(_ plan: Plan) {
        plan.isPaid = !plan.isPaid
        try? modelContext.save()
    }

    private func deletePlans(_ plans: [Plan], at offsets: IndexSet) {
        for i in offsets {
            let p = plans[i]
            NotificationService.shared.cancel(planId: p.id)
            if let eid = p.eventIdentifier { CalendarService.shared.deleteEvent(identifier: eid) }
            modelContext.delete(p)
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func statusOrder(_ s: PlanStatus) -> Int {
        switch s { case .completed: return 0; case .planned: return 1; case .canceled: return 2 }
    }
    private func titleColor(_ plan: Plan) -> Color {
        switch plan.status {
        case .planned: return .primary; case .completed: return .secondary; case .canceled: return .secondary.opacity(0.6)
        }
    }
    private func grassColor(_ count: Int) -> Color {
        switch count {
        case 0:     return Color(red: 0.88, green: 0.92, blue: 0.88)
        case 1:     return Color(red: 0.56, green: 0.83, blue: 0.47)
        case 2...3: return Color(red: 0.25, green: 0.66, blue: 0.25)
        default:    return Color(red: 0.10, green: 0.45, blue: 0.10)
        }
    }
    private func formattedDateTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: date)
    }
}
