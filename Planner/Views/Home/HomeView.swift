import SwiftUI
import SwiftData

/// 홈 화면 — 캘린더 테마 배경 적용
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme)  private var colorScheme

    @StateObject private var storeManager = StoreKitManager.shared

    // 캘린더 테마 (ThemeStoreView와 동일한 키 공유)
    @AppStorage(ThemeType.calendar.storageKey)
    private var calendarThemeRaw: String = SeasonTheme.classic.rawValue
    private var currentTheme: SeasonTheme {
        SeasonTheme(rawValue: calendarThemeRaw) ?? .classic
    }

    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        let today = Date()
        return cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
    }()
    @State private var selectedDate: Date? = nil
    @State private var showAddPlan  = false
    @State private var showPaywall  = false

    @Query private var allPlans: [Plan]

    // MARK: - 오늘 계획
    private var todayPlans: [Plan] {
        let cal = Calendar.current
        let today = Date()
        return allPlans.filter { plan in
            plan.year  == cal.component(.year,  from: today) &&
            plan.month == cal.component(.month, from: today) &&
            plan.day   == cal.component(.day,   from: today) &&
            plan.status != .canceled
        }
        .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var canAddMorePlans: Bool {
        storeManager.isPro || todayPlans.count < 1
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // ── 테마 배경 ──
                ThemeBackgroundView(theme: currentTheme)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        GrassCalendarView(
                            displayedMonth: $displayedMonth,
                            selectedDate: $selectedDate
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Divider()
                            .background(currentTheme.diaryAccent.opacity(0.3))
                            .padding(.horizontal, 16)

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
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        NavigationLink { CategoryListView() } label: {
                            Image(systemName: "tag.fill")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        NavigationLink {
                            ThemeStoreView(themeType: .calendar)
                        } label: {
                            Image(systemName: "paintpalette.fill")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedDate != nil },
                set: { if !$0 { selectedDate = nil } }
            )) {
                if let date = selectedDate {
                    DateDetailView(date: date)
                }
            }
            .sheet(isPresented: $showAddPlan) { AddPlanView() }
            .sheet(isPresented: $showPaywall) { PurchaseView() }
        }
    }

    // MARK: - Today Section

    @ViewBuilder
    private var todaySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                let completedCount = todayPlans.filter { $0.status == .completed }.count
                let totalCount     = todayPlans.count
                if totalCount > 0 {
                    Text("\(completedCount)/\(totalCount) completed")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            if todayPlans.isEmpty {
                emptyTodayView
            } else {
                List {
                    ForEach(todayPlans) { plan in
                        TodayPlanRow(plan: plan, onToggle: { toggleComplete(plan) })
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deletePlan(plan) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(todayPlans.count) * 80)
                .scrollDisabled(true)
            }
        }
    }

    // MARK: - Empty Today

    private var emptyTodayView: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.title)
                .foregroundColor(.green.opacity(0.4))
            Text("No plans for today")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Add a plan to grow your grass! 🌱")
                .font(.footnote)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Actions

    private func handleAddPlanTap() {
        if canAddMorePlans { showAddPlan = true }
        else               { showPaywall  = true }
    }

    private func toggleComplete(_ plan: Plan) {
        if plan.status == .completed {
            plan.status      = .planned
            plan.completedAt = nil
            if plan.notificationEnabled && plan.hasTime {
                Task { await NotificationService.shared.schedule(for: plan) }
            }
        } else {
            NotificationService.shared.cancel(planId: plan.id)
            plan.status      = .completed
            plan.completedAt = Date()
        }
        try? modelContext.save()
    }

    private func deletePlan(_ plan: Plan) {
        NotificationService.shared.cancel(planId: plan.id)
        modelContext.delete(plan)
        try? modelContext.save()
    }
}

// MARK: - TodayPlanRow (Dynamic Type, 글자 잘림 방지)
struct TodayPlanRow: View {
    let plan: Plan
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: plan.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(plan.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            Rectangle()
                .fill(plan.category?.color ?? .gray)
                .frame(width: 3)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(plan.status == .completed ? .secondary : .primary)
                    .strikethrough(plan.status == .completed)
                    .fixedSize(horizontal: false, vertical: true) // ✅ Dynamic Type 확대 시 줄 바꿈
                
                if !plan.memo.isEmpty {
                    Text(plan.memo)
                        .font(.footnote)
                        .foregroundColor(.secondary.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
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
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(10)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Category.self, Plan.self], inMemory: true)
}
