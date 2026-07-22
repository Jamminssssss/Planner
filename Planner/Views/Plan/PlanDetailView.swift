import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let plan: Plan

    var body: some View {
        ZStack {
            // 💡 앱 전체 다크/라이트 모드 톤에 맞는 배경색 설정
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 1. 헤더 (상태 배지 및 제목)
                    headerSection
                    
                    // 2. 일정 시간 및 날짜
                    dateTimeSection
                    
                    // 3. 근무 일정 정보 (isWorkSchedule이 true일 때만 표시)
                    if plan.isWorkSchedule {
                        workInfoSection
                    }
                    
                    // 4. 메모
                    if !plan.memo.isEmpty {
                        memoSection
                    }
                    
                    // 5. 알림 정보
                    if plan.notificationEnabled {
                        notificationSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 100) // 하단 버튼 공간 확보
            }
        }
        .navigationTitle("일정 상세")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            actionButtons
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial) // 하단 버튼 영역 블러 처리
        }
    }

    // MARK: - UI Sections

    private var headerSection: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    // 상태 배지
                    statusBadge
                    Spacer()
                    if let category = plan.category {
                        // 카테고리가 있다면 우측에 표시 (기존 유지)
                        CategoryBadge(category: category)
                    }
                }
                
                Text(plan.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .strikethrough(plan.status == .canceled)
                    .foregroundColor(plan.status == .canceled ? .secondary : .primary)
            }
        }
    }

    private var dateTimeSection: some View {
        DetailCard {
            VStack(spacing: 16) {
                detailRow(icon: "calendar", iconColor: .blue, title: "날짜", value: formattedDate)
                
                if let time = plan.timeDisplay {
                    Divider()
                    detailRow(icon: "clock.fill", iconColor: .blue, title: "시간", value: time)
                }
            }
        }
    }

    private var workInfoSection: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("근무 정보", systemImage: "briefcase.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                    Spacer()
                    // 결제 여부 배지
                    Text(plan.isPaid ? "정산 완료" : "미정산")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(plan.isPaid ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .foregroundColor(plan.isPaid ? .green : .red)
                        .cornerRadius(6)
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    detailRow(icon: "mappin.and.ellipse", iconColor: .secondary, title: "현장명", value: plan.siteName.isEmpty ? "지정되지 않음" : plan.siteName)
                    detailRow(icon: "hammer.fill", iconColor: .orange, title: "공수", value: plan.workUnits.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f공수", plan.workUnits) : String(format: "%.1f공수", plan.workUnits))
                    detailRow(icon: "wonsign.circle.fill", iconColor: .secondary, title: "일당", value: "₩\(plan.dailyWage.formatted())")
                    
                    Divider()
                    
                    HStack {
                        Text("예상 수익")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("₩\(Int(plan.expectedIncome).formatted())")
                            .font(.headline)
                            .foregroundColor(plan.isPaid ? .green : .orange)
                    }
                }
            }
        }
    }

    private var memoSection: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("메모", systemImage: "doc.text.fill")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text(plan.memo)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            }
        }
    }

    private var notificationSection: some View {
        DetailCard {
            detailRow(icon: "bell.fill", iconColor: .orange, title: "알림", value: plan.notificationSound.displayName)
        }
    }

    // MARK: - Components

    private var statusBadge: some View {
        let info = statusInfo
        return HStack(spacing: 4) {
            Image(systemName: info.icon)
            Text(info.label)
        }
        .font(.caption)
        .fontWeight(.bold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(info.bg)
        .foregroundColor(info.text)
        .clipShape(Capsule())
    }

    private func detailRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            switch plan.status {
            case .planned:
                fullWidthButton(title: "일정 완료하기", icon: "checkmark.circle.fill", color: .green, action: completePlan)
                fullWidthButton(title: "일정 취소", icon: "xmark.circle.fill", color: .red, isOutlined: true, action: cancelPlan)

            case .completed:
                fullWidthButton(title: "계획됨으로 되돌리기", icon: "arrow.uturn.backward", color: .blue, isOutlined: true, action: revertPlan)
                
            case .canceled:
                fullWidthButton(title: "계획됨으로 복구", icon: "arrow.uturn.backward", color: .primary, isOutlined: true, action: revertPlan)
            }
        }
    }

    // MARK: - Helper Methods

    private var formattedDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월 d일 (EEEE)"
        return f.string(from: plan.scheduledDateOnly)
    }

    private var statusInfo: (bg: Color, text: Color, icon: String, label: String) {
        switch plan.status {
        case .planned:
            return (Color.gray.opacity(0.15), .secondary, "clock.fill", "진행 전")
        case .completed:
            return (Color.green.opacity(0.15), .green, "checkmark.circle.fill", "완료됨")
        case .canceled:
            return (Color.red.opacity(0.15), .red, "xmark.circle.fill", "취소됨")
        }
    }

    private func fullWidthButton(title: String, icon: String, color: Color, isOutlined: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundColor(isOutlined ? color : .white)
            .background(isOutlined ? Color(UIColor.secondarySystemGroupedBackground) : color)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(color, lineWidth: isOutlined ? 1.5 : 0))
            .cornerRadius(14)
        }
    }

    // MARK: - Actions

    private func completePlan() {
        PlanActions.toggleComplete(plan, context: modelContext)
        dismiss() // 완료 후 창 닫기 원하시면 추가, 아니면 제거
    }

    private func cancelPlan() {
        NotificationService.shared.cancel(planId: plan.id)
        plan.status = .canceled
        plan.completedAt = nil
        try? modelContext.save()
        
        if plan.calendarSyncEnabled, let id = plan.eventIdentifier {
            Task { await CalendarService.shared.deleteEvent(identifier: id) }
        }
    }

    private func revertPlan() {
        PlanActions.toggleComplete(plan, context: modelContext)
    }
}

// MARK: - Reusable Card Modifier

/// iOS 네이티브 느낌의 카드 형태를 만들어주는 재사용 뷰
struct DetailCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 다크모드/라이트모드에 자연스럽게 대응하는 카드 배경색
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
