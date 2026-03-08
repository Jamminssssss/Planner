// ============================================================
// PlanActionHelper.swift
// 완료 토글 / 삭제 시 캘린더 자동 동기화
//
// ⚠️ 별도 파일로 추가하거나, 각 View 파일 안에 함수로 복붙하세요.
// HomeView / DateDetailView / 어디서든 동일하게 사용 가능합니다.
// ============================================================

import Foundation
import SwiftData

// MARK: - 완료 ↔ 미완료 전환

/// toggleComplete 함수 (View 안에서 사용)
/// 기존 toggle 로직을 이 함수로 교체하세요.
///
/// 예시:
///   Button { PlanActions.toggleComplete(plan, context: modelContext) }
///   스와이프: .swipeActions { Button { PlanActions.toggleComplete(plan, context: modelContext) } }

struct PlanActions {

    static func toggleComplete(_ plan: Plan, context: ModelContext) {
        if plan.status == .completed {
            // 완료 → 미완료
            plan.status      = .planned
            plan.completedAt = nil
            // 알림 재등록
            if plan.notificationEnabled && plan.hasTime {
                Task { await NotificationService.shared.schedule(for: plan) }
            }
        } else {
            // 미완료 → 완료
            NotificationService.shared.cancel(planId: plan.id)
            plan.status      = .completed
            plan.completedAt = Date()
        }

        try? context.save()

        // ✅ 캘린더 연동 중이면 이벤트 업데이트 (상태 변경 반영)
        if plan.calendarSyncEnabled {
            Task {
                let newId = await CalendarService.shared.updateEvent(for: plan)
                // createEvent로 재생성된 경우 id 업데이트
                if let id = newId, id != plan.eventIdentifier {
                    plan.eventIdentifier = id
                    try? context.save()
                }
            }
        }
    }

    // MARK: - 삭제

    static func delete(_ plan: Plan, context: ModelContext) {
        // 알림 취소
        NotificationService.shared.cancel(planId: plan.id)

        // ✅ 캘린더 이벤트 삭제 (async)
        if let id = plan.eventIdentifier {
            Task { await CalendarService.shared.deleteEvent(identifier: id) }
        }

        context.delete(plan)
        try? context.save()
    }
}

// ============================================================
// 사용 예시 (HomeView, DateDetailView 등에 적용)
// ============================================================
//
// [완료 토글 버튼]
//   Button { PlanActions.toggleComplete(plan, context: modelContext) } label: {
//       Image(systemName: plan.status == .completed ? "checkmark.circle.fill" : "circle")
//   }
//
// [스와이프 삭제]
//   .swipeActions(edge: .trailing) {
//       Button(role: .destructive) {
//           PlanActions.delete(plan, context: modelContext)
//       } label: {
//           Label("삭제", systemImage: "trash")
//       }
//   }
//
// ============================================================
