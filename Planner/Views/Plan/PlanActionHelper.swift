import Foundation
import SwiftData

// MARK: - PlanActions Helper
// 완료 토글 / 삭제 시 캘린더 자동 동기화를 안전하게 수행합니다.

struct PlanActions {
    
    static func toggleComplete(_ plan: Plan, context: ModelContext) {
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

        do {
            try context.save()
        } catch {
            print("❌ PlanActionHelper: Save failed - \(error)")
        }

        if plan.calendarSyncEnabled {
            Task {
                let newId = await CalendarService.shared.updateEvent(for: plan)
                if let id = newId, id != plan.eventIdentifier {
                    await MainActor.run {
                        plan.eventIdentifier = id
                        try? context.save()
                    }
                }
            }
        }
    }

    static func delete(_ plan: Plan, context: ModelContext) {
        NotificationService.shared.cancel(planId: plan.id)

        // 💡 캘린더 삭제는 비동기 작업이므로, 모델에서 지우기 전에 식별자를 안전하게 복사해 둡니다.
        let eventId = plan.eventIdentifier
        
        context.delete(plan)
        
        do {
            try context.save()
        } catch {
            print("❌ PlanActionHelper: Delete failed - \(error)")
        }
        
        if let id = eventId {
            Task { await CalendarService.shared.deleteEvent(identifier: id) }
        }
    }
}
