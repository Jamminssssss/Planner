import SwiftUI
import SwiftData

// MARK: - DateDetailView

struct DateDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let date: Date

    private let calendar = Calendar.current

    private var year:  Int { calendar.component(.year,  from: date) }
    private var month: Int { calendar.component(.month, from: date) }
    private var day:   Int { calendar.component(.day,   from: date) }

    private var dateTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    // MARK: - Filtered Plans

    private var plansForDate: [Plan] {
        let descriptor = FetchDescriptor<Plan>()
        do {
            let all = try modelContext.fetch(descriptor)
            return all
                .filter { $0.year == year && $0.month == month && $0.day == day }
                .sorted {
                    let oA = statusOrder($0.status), oB = statusOrder($1.status)
                    if oA != oB { return oA < oB }
                    if $0.hasTime && $1.hasTime {
                        if $0.hour != $1.hour { return $0.hour < $1.hour }
                        return $0.minute < $1.minute
                    }
                    if $0.hasTime { return true }
                    if $1.hasTime { return false }
                    return $0.createdAt < $1.createdAt
                }
        } catch { return [] }
    }

    private var completedPlans: [Plan] { plansForDate.filter { $0.status == .completed } }
    private var plannedPlans:   [Plan] { plansForDate.filter { $0.status == .planned }   }
    private var canceledPlans:  [Plan] { plansForDate.filter { $0.status == .canceled }  }

    // MARK: - Body

    var body: some View {
        List {
            Section {
                dateHeader
            } header: {
                Text("Date").font(.headline)
            }

            if !completedPlans.isEmpty {
                Section {
                    ForEach(completedPlans) { plan in
                        planRow(plan)
                    }
                    .onDelete { idx in deletePlans(completedPlans, at: idx) }
                } header: {
                    Text("✅ Completed (\(completedPlans.count))").font(.subheadline)
                }
            }

            if !plannedPlans.isEmpty {
                Section {
                    ForEach(plannedPlans) { plan in
                        planRow(plan)
                    }
                    .onDelete { idx in deletePlans(plannedPlans, at: idx) }
                } header: {
                    Text("📋 Planned (\(plannedPlans.count))").font(.subheadline)
                }
            }

            if !canceledPlans.isEmpty {
                Section {
                    ForEach(canceledPlans) { plan in
                        planRow(plan)
                    }
                    .onDelete { idx in deletePlans(canceledPlans, at: idx) }
                } header: {
                    Text("🚫 Canceled (\(canceledPlans.count))").font(.subheadline)
                }
            }

            if plansForDate.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "leaf")
                            .font(.title) // Dynamic Type
                            .foregroundColor(.green.opacity(0.3))
                        Text("No plans for this day")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Add a plan from the home screen to grow grass here! 🌱")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(dateTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(grassColor(completedPlans.count))
                    .frame(width: 48, height: 48)
                if !completedPlans.isEmpty {
                    Text("🌱")
                        .font(.title2) // Dynamic Type
                } else {
                    Text("\(day)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(dateTitle)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                let summary: String = {
                    var parts: [String] = []
                    if !completedPlans.isEmpty { parts.append("\(completedPlans.count) completed") }
                    if !plannedPlans.isEmpty   { parts.append("\(plannedPlans.count) planned")   }
                    return parts.isEmpty ? "No plans" : parts.joined(separator: ", ")
                }()

                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Plan Row

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
                .fill(plan.category?.color ?? .gray)
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(titleColor(plan))
                    .strikethrough(plan.status != .planned)
                    .fixedSize(horizontal: false, vertical: true)

                if !plan.memo.isEmpty {
                    Text(plan.memo)
                        .font(.footnote)
                        .foregroundColor(.secondary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                metaRow(plan)

                if plan.status == .completed, let completedAt = plan.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("Completed on \(formattedDateTime(completedAt))")
                            .font(.caption2)
                            .foregroundColor(.green.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Meta Row

    private func metaRow(_ plan: Plan) -> some View {
        HStack(spacing: 6) {
            if let name = plan.category?.name {
                Text(name)
                    .font(.caption)
                    .foregroundColor(plan.category?.color ?? .gray)
            }
            if let time = plan.timeDisplay {
                Text("•").font(.caption2).foregroundColor(.secondary)
                Text(time).font(.caption).foregroundColor(.secondary)
            }
            if plan.notificationEnabled {
                Text("•").font(.caption2).foregroundColor(.secondary)
                Image(systemName: "bell.fill").font(.caption2).foregroundColor(.orange)
            }
            if plan.calendarSyncEnabled {
                Text("•").font(.caption2).foregroundColor(.secondary)
                Image(systemName: "calendar").font(.caption2).foregroundColor(.blue)
            }
        }
    }

    // MARK: - Actions

    private func toggleComplete(_ plan: Plan) {
        if plan.status == .completed {
            plan.status = .planned
            plan.completedAt = nil
            if plan.notificationEnabled && plan.hasTime {
                Task { await NotificationService.shared.schedule(for: plan) }
            }
        } else {
            NotificationService.shared.cancel(planId: plan.id)
            plan.status = .completed
            plan.completedAt = Date()
        }
        try? modelContext.save()
    }

    private func deletePlans(_ plans: [Plan], at offsets: IndexSet) {
        for i in offsets {
            let plan = plans[i]
            NotificationService.shared.cancel(planId: plan.id)
            if let eventId = plan.eventIdentifier {
                CalendarService.shared.deleteEvent(identifier: eventId)
            }
            modelContext.delete(plan)
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func statusOrder(_ s: PlanStatus) -> Int {
        switch s {
        case .completed: return 0
        case .planned:   return 1
        case .canceled:  return 2
        }
    }

    private func titleColor(_ plan: Plan) -> Color {
        switch plan.status {
        case .planned:   return .primary
        case .completed: return .secondary
        case .canceled:  return .secondary.opacity(0.6)
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
    
    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func formattedDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
