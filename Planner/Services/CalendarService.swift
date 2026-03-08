import Foundation
import EventKit
import SwiftUI

// MARK: - CalendarService

final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()
    private init() {}

    // MARK: - 권한

    func requestPermission() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        print("[Calendar] 권한 상태 rawValue: \(status.rawValue)")

        switch status.rawValue {
        case 3, 4: return true
        case 0:
            do {
                let granted: Bool
                if #available(iOS 17.0, *) {
                    granted = try await store.requestFullAccessToEvents()
                } else {
                    granted = try await store.requestAccess(to: .event)
                }
                print("[Calendar] 권한 요청 결과: \(granted)")
                return granted
            } catch {
                print("[Calendar] ❌ 권한 오류: \(error)")
                return false
            }
        default:
            print("[Calendar] ⚠️ 권한 거부 (rawValue=\(status.rawValue))")
            return false
        }
    }

    // MARK: - 생성

    @discardableResult
    func createEvent(for plan: Plan) async -> String? {
        guard await requestPermission() else {
            print("[Calendar] ❌ 권한 없음 → 생성 중단")
            return nil
        }
        guard let defaultCalendar = store.defaultCalendarForNewEvents else {
            print("[Calendar] ❌ 기본 캘린더 없음")
            return nil
        }

        let event = EKEvent(eventStore: store)
        fillEvent(event, from: plan)
        event.calendar = defaultCalendar

        do {
            try store.save(event, span: .thisEvent)
            print("[Calendar] ✅ 생성: '\(plan.title)' id=\(event.eventIdentifier ?? "-")")
            return event.eventIdentifier
        } catch {
            print("[Calendar] ❌ 생성 실패: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 업데이트 (기존 삭제 → 재생성으로 항상 1개 유지)

    @discardableResult
    func updateEvent(for plan: Plan) async -> String? {
        guard await requestPermission() else { return nil }

        // 기존 이벤트 삭제
        if let id = plan.eventIdentifier,
           let existing = store.event(withIdentifier: id) {
            do {
                try store.remove(existing, span: .thisEvent)
                print("[Calendar] 🗑 기존 제거 후 재생성")
            } catch {
                print("[Calendar] ⚠️ 기존 제거 실패: \(error)")
            }
        }

        return await createEvent(for: plan)
    }

    // MARK: - 삭제

    func deleteEvent(identifier: String) async {
        // 권한 재확인 없이 바로 시도 (이미 생성 시 권한 획득됨)
        // store를 refresh해서 최신 상태 반영
        store.refreshSourcesIfNecessary()

        guard let event = store.event(withIdentifier: identifier) else {
            print("[Calendar] ⚠️ 삭제할 이벤트 없음 (id=\(identifier))")
            return
        }
        do {
            try store.remove(event, span: .thisEvent)
            print("[Calendar] 🗑 삭제 완료")
        } catch {
            print("[Calendar] ❌ 삭제 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 캘린더 앱 열기

    func openCalendarApp(for plan: Plan) {
        var c = DateComponents()
        c.year = plan.year; c.month = plan.month; c.day = plan.day
        guard let date = Calendar.current.date(from: c) else { return }
        if let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)") {
            DispatchQueue.main.async { UIApplication.shared.open(url) }
        }
    }

    // MARK: - EKEvent 채우기

    private func fillEvent(_ event: EKEvent, from plan: Plan) {

        // ── 제목 ──
        // 근무: "🔨 8.0h · 현장명" 또는 "🔨 8.0h"  (공수 최우선)
        // 일반: 상태 접두사 + 제목
        if plan.isWorkSchedule {
            let unitStr = String(format: "%.1f", plan.workUnits)
            var workTitle = "🔨 \(unitStr)h"
            if !plan.siteName.isEmpty { workTitle += " · \(plan.siteName)" }
            switch plan.status {
            case .planned:   event.title = workTitle
            case .completed: event.title = "✅ \(workTitle)"
            case .canceled:  event.title = "🚫 \(workTitle)"
            }
        } else {
            switch plan.status {
            case .planned:   event.title = plan.title
            case .completed: event.title = "✅ \(plan.title)"
            case .canceled:  event.title = "🚫 \(plan.title)"
            }
        }

        // ── 날짜/시간 ──
        let cal = Calendar.current
        var c = DateComponents()
        c.year = plan.year; c.month = plan.month; c.day = plan.day

        if plan.hasTime {
            c.hour = plan.hour; c.minute = plan.minute
            let start = cal.date(from: c) ?? Date()
            event.startDate = start
            if plan.hasEndTime {
                var ec = c
                ec.hour = plan.endHour; ec.minute = plan.endMinute
                event.endDate = cal.date(from: ec) ?? start.addingTimeInterval(3600)
            } else {
                event.endDate = start.addingTimeInterval(3600)
            }
            event.isAllDay = false
        } else {
            let day = cal.date(from: c) ?? Date()
            event.startDate = day
            event.endDate   = day.addingTimeInterval(86400)
            event.isAllDay  = true
        }

        // ── 메모 ──
        var notes = ""

        if plan.isWorkSchedule {
            // 근무 정보 상세
            let unitStr = String(format: "%.1f", plan.workUnits)
            notes += "공수: \(unitStr)h"
            if !plan.siteName.isEmpty { notes += "\n현장: \(plan.siteName)" }
            if plan.dailyWage > 0 {
                notes += "\n일당: ₩\(plan.dailyWage.formatted())"
            }
            if plan.expectedIncome > 0 {
                notes += "\n예상 수입: ₩\(Int(plan.expectedIncome).formatted())"
            }
            notes += "\n지급: \(plan.isPaid ? "완료 ✅" : "미완료 ⚠️")"
        } else {
            if let cat = plan.category { notes += "[\(cat.name)]" }
        }

        if !plan.memo.isEmpty {
            if !notes.isEmpty { notes += "\n\n" }
            notes += plan.memo
        }

        if plan.status == .completed, let done = plan.completedAt {
            let fmt = DateFormatter()
            fmt.dateStyle = .short; fmt.timeStyle = .short
            if !notes.isEmpty { notes += "\n\n" }
            notes += "완료 시각: \(fmt.string(from: done))"
        }

        event.notes = notes.isEmpty ? nil : notes

        // ── 알림 ──
        event.alarms = nil
        if plan.notificationEnabled && plan.hasTime {
            event.addAlarm(EKAlarm(relativeOffset: 0))
        }
    }
}
