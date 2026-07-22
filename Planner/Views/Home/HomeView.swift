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

    // 데이터 조회 (성능 최적화를 위해 한 번만 로드)
    @Query private var allPlans: [Plan]

    // 자유 요금제 제한(무료 유저는 하루 1개)을 위한 오늘 날짜 생성 개수 체크
    private var todayPlansCount: Int {
        let cal = Calendar.current
        let today = Date()
        return allPlans.filter {
            $0.year  == cal.component(.year,  from: today) &&
            $0.month == cal.component(.month, from: today) &&
            $0.day   == cal.component(.day,   from: today) &&
            $0.status != .canceled
        }.count
    }

    private var canAddMorePlans: Bool { storeManager.isPro || todayPlansCount < 1 }

    // 하단에 표시할 기준 날짜 (달력에서 선택된 날짜가 없으면 기본값으로 오늘 날짜 사용)
    private var activeDate: Date {
        selectedDate ?? Date()
    }

    // 기준 날짜의 일정 필터링 및 정렬 적용
    private var activeDatePlans: [Plan] {
        let cal = Calendar.current
        let year = cal.component(.year, from: activeDate)
        let month = cal.component(.month, from: activeDate)
        let day = cal.component(.day, from: activeDate)
        
        return allPlans.filter {
            $0.year == year &&
            $0.month == month &&
            $0.day == day
        }.sorted {
            // 시간 설정된 일정을 먼저, 그 다음 시간순 정렬
            if $0.hasTime == $1.hasTime {
                if $0.hour == $1.hour {
                    return $0.minute < $1.minute
                }
                return $0.hour < $1.hour
            }
            return $0.hasTime && !$1.hasTime
        }
    }

    // 하단 일정 영역의 제목 포맷 (영어)
    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM d's Schedule" // 예: July 17's Schedule
        return formatter.string(from: activeDate)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 테마 배경
                ThemeBackgroundView(theme: currentTheme)
                
                VStack(spacing: 0) {
                    // 전체 화면을 꽉 채우는 캘린더
                    GrassCalendarView(displayedMonth: $displayedMonth, selectedDate: $selectedDate)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    
                    // 하단 여백 공간에 선택된 날짜의 일정 리스트 추가
                    VStack(alignment: .leading, spacing: 10) {
                        Text(dateTitle)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        
                        if activeDatePlans.isEmpty {
                            Spacer()
                            Text("No schedules added.")                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                        } else {
                            List {
                                ForEach(activeDatePlans) { plan in
                                    // 💡 ZStack을 통해 디자인을 해치지 않고 상세 화면 이동(NavigationLink) 적용
                                    ZStack {
                                        // 터치 영역을 담당하는 백그라운드 네비게이션 링크
                                        NavigationLink(value: plan) {
                                            Color.clear
                                        }
                                        .opacity(0)
                                        
                                        HStack(alignment: .top, spacing: 12) {
                                            // 💡 상태 아이콘 (완료 체크/해제 버튼) - 일반 터치 시 이 버튼이 우선 동작함
                                            Button(action: {
                                                withAnimation {
                                                    togglePlanStatus(plan)
                                                }
                                            }) {
                                                Image(systemName: plan.status == .completed ? "checkmark.circle.fill" : (plan.status == .canceled ? "xmark.circle.fill" : "circle"))
                                                    .foregroundColor(plan.status == .completed ? .green : (plan.status == .canceled ? .red : .gray))
                                                    .font(.title3)
                                                    .padding(.top, 2)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                // 제목 (취소/완료된 경우 취소선 표시)
                                                Text(plan.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .strikethrough(plan.status == .canceled || plan.status == .completed)
                                                    .foregroundColor(plan.status == .canceled ? .secondary : .primary)
                                                
                                                // 시간 표시
                                                if let timeString = plan.timeDisplay {
                                                    Text(timeString)
                                                        .font(.caption)
                                                        .foregroundColor(.blue)
                                                }
                                                
                                                // 메모 표시
                                                if !plan.memo.isEmpty {
                                                    Text(plan.memo)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                                
                                                // 근무일정 정보 표시
                                                if plan.isWorkSchedule {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "briefcase.fill")
                                                        Text(plan.siteName.isEmpty ? "근무" : plan.siteName)
                                                        Text("·")
                                                        Text(plan.workUnits.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f공수", plan.workUnits) : String(format: "%.1f공수", plan.workUnits))
                                                    }
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color.orange.opacity(0.15))
                                                    .foregroundColor(.orange)
                                                    .cornerRadius(4)
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemBackground).opacity(0.8))
                                        .cornerRadius(12)
                                    }
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    // 좌측 스와이프 삭제 기능
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deletePlan(plan)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                    // 꾹 눌러서(Context Menu) 삭제 기능
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deletePlan(plan)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Grass Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { handleAddPlanTap() }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink { ThemeStoreView(themeType: .calendar) } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            // 💡 Plan 데이터 선택 시 PlanDetailView로 이동하도록 목적지 추가
            .navigationDestination(for: Plan.self) { plan in
                PlanDetailView(plan: plan)
            }
            .fullScreenCover(isPresented: $showAddPlan) {
                // 사용자가 선택한 날짜가 없으면 오늘(Date())을 기준으로 일정 추가
                let targetDate = selectedDate ?? Date()
                AddPlanView(selectedDate: targetDate)
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PurchaseView()
            }
        }
    }

    // MARK: - Actions

    private func handleAddPlanTap() {
        if canAddMorePlans {
            showAddPlan = true
        } else {
            showPaywall = true
        }
    }

    // 일정 완료/미완료 상태 토글 함수
    private func togglePlanStatus(_ plan: Plan) {
        if plan.status == .completed {
            plan.status = .planned
            plan.completedAt = nil
        } else {
            plan.status = .completed
            plan.completedAt = Date()
        }
    }

    // 일정 삭제 함수
    private func deletePlan(_ plan: Plan) {
        withAnimation {
            modelContext.delete(plan)
        }
    }
}
