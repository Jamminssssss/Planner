import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme
    @StateObject private var storeManager = StoreKitManager.shared

    @AppStorage(ThemeType.calendar.storageKey)
    private var calendarThemeRaw: String = SeasonTheme.classic.rawValue
    private var currentTheme: SeasonTheme { SeasonTheme(rawValue: calendarThemeRaw) ?? .classic }

    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()
    @State private var selectedDate: Date? = nil
    @State private var showAddPlan  = false
    @State private var showPaywall  = false

    @Query private var allPlans: [Plan]

    private var todayPlans: [Plan] {
        let cal = Calendar.current; let today = Date()
        return allPlans.filter {
            $0.year  == cal.component(.year,  from: today) &&
            $0.month == cal.component(.month, from: today) &&
            $0.day   == cal.component(.day,   from: today) &&
            $0.status != .canceled
        }
        .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var canAddMorePlans: Bool { storeManager.isPro || todayPlans.count < 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView(theme: currentTheme)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        GrassCalendarView(displayedMonth: $displayedMonth, selectedDate: $selectedDate)
                            .padding(.horizontal, 16).padding(.top, 8)
                        Divider().background(currentTheme.diaryAccent.opacity(0.3)).padding(.horizontal, 16)
                        todaySection.padding(.horizontal, 16)
                        Spacer(minLength: 80)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { handleAddPlanTap() }) {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.green)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        NavigationLink { CategoryListView() } label: {
                            Image(systemName: "tag.fill").font(.body).foregroundColor(.secondary)
                        }
                        NavigationLink { ThemeStoreView(themeType: .calendar) } label: {
                            Image(systemName: "paintpalette.fill").font(.body).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedDate != nil },
                set: { if !$0 { selectedDate = nil } }
            )) {
                if let date = selectedDate { DateDetailView(date: date) }
            }
            .fullScreenCover(isPresented: $showAddPlan) { AddPlanView() }
            .sheet(isPresented: $showPaywall)  { PurchaseView() }
        }
    }

    // MARK: - Today section

    @ViewBuilder
    private var todaySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today").font(.callout.weight(.semibold))
                Spacer()
                let done  = todayPlans.filter { $0.status == .completed }.count
                let total = todayPlans.count
                if total > 0 {
                    Text("\(done)/\(total) completed").font(.footnote).foregroundColor(.secondary)
                }
            }
            if todayPlans.isEmpty {
                emptyTodayView
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(todayPlans) { plan in
                        TodayPlanRow(
                            plan:         plan,
                            onToggle:     { toggleComplete(plan) },
                            onTogglePaid: { togglePaid(plan) },
                            onDelete:     { deletePlan(plan) }
                        )
                    }
                }
            }
        }
    }

    private var emptyTodayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf").font(.title).foregroundColor(.green.opacity(0.4))
            Text("No plans for today").font(.subheadline).foregroundColor(.secondary)
            Text("Add a plan to grow your grass! 🌱").font(.footnote).foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    // MARK: - Actions

    private func handleAddPlanTap() {
        if canAddMorePlans { showAddPlan = true } else { showPaywall = true }
    }
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

        // ✅ 캘린더 연동 중이면 완료/미완료 상태 업데이트
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
    private func togglePaid(_ plan: Plan) {
        guard plan.isWorkSchedule else { return }
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
    private func deletePlan(_ plan: Plan) {
        NotificationService.shared.cancel(planId: plan.id)
        // identifier를 먼저 캡처 (delete 후엔 접근 불가)
        let eventId = plan.eventIdentifier
        modelContext.delete(plan)
        try? modelContext.save()
        // 캘린더 삭제는 modelContext 저장 후 async로 실행
        if let id = eventId {
            Task { await CalendarService.shared.deleteEvent(identifier: id) }
        }
    }
}

// MARK: - TodayPlanRow

struct TodayPlanRow: View {
    let plan: Plan
    let onToggle:     () -> Void
    let onTogglePaid: () -> Void
    let onDelete:     () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // 삭제 버튼
            if showDelete {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red)
                    .overlay(
                        Button {
                            withAnimation { offset = 0; showDelete = false }
                            onDelete()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash").font(.system(size: 16, weight: .medium))
                                Text("삭제").font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 72)
                        }
                        .frame(maxHeight: .infinity),
                        alignment: .trailing
                    )
            }

            // 메인 카드
            HStack(alignment: .top, spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: plan.status == .completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(plan.status == .completed ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Rectangle()
                    .fill(plan.isWorkSchedule ? Color.orange : (plan.category?.color ?? .gray))
                    .frame(width: 3).cornerRadius(2)

                VStack(alignment: .leading, spacing: 5) {
                    // Title
                    Text(plan.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(plan.status == .completed ? .secondary : .primary)
                        .strikethrough(plan.status == .completed)
                        .fixedSize(horizontal: false, vertical: true)

                    // Memo
                    if !plan.memo.isEmpty {
                        Text(plan.memo).font(.footnote).foregroundColor(.secondary.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Time range badge
                    if let timeStr = plan.timeDisplay {
                        timeRangeBadge(timeStr)
                    }

                    // Work meta or general meta
                    if plan.isWorkSchedule {
                        workMetaRow
                    } else {
                        generalMetaRow
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(10)
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { v in
                        if v.translation.width > 0 {
                            if showDelete { withAnimation { offset = 0; showDelete = false } }
                        } else {
                            offset = max(v.translation.width, -80)
                        }
                    }
                    .onEnded { v in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if v.translation.width < -40 {
                                offset = -80; showDelete = true
                            } else {
                                offset = 0; showDelete = false
                            }
                        }
                    }
            )
        }
    }

    private func timeRangeBadge(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: plan.hasEndTime ? "clock.arrow.2.circlepath" : "clock")
                .font(.caption2)
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(plan.isWorkSchedule ? .orange : .blue)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background((plan.isWorkSchedule ? Color.orange : Color.blue).opacity(0.10))
        .cornerRadius(6)
    }

    private var workMetaRow: some View {
        HStack(spacing: 6) {
            // Units badge
            Text(String(format: "%.1f단위", plan.workUnits))
                .font(.system(size: 11, weight: .semibold)).foregroundColor(.orange)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Color.orange.opacity(0.13)).cornerRadius(5)

            // Expected income
            if plan.expectedIncome > 0 {
                Text("₩\(Int(plan.expectedIncome).formatted())")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.10)).cornerRadius(5)
            }

            // Payment badge — tap to toggle
            Button(action: onTogglePaid) {
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
        }
    }

    private var generalMetaRow: some View {
        HStack(spacing: 6) {
            if let name = plan.category?.name {
                Text(name).font(.caption).foregroundColor(plan.category?.color ?? .gray)
            }
            if plan.notificationEnabled {
                Image(systemName: "bell.fill").font(.caption2).foregroundColor(.orange)
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Category.self, Plan.self], inMemory: true)
}
