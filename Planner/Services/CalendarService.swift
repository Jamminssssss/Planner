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
        
        // 💡 하드코딩된 숫자 대신 안전한 Enum 비교 사용
        if status == .authorized { return true }
        if #available(iOS 17.0, *), status == .fullAccess { return true }
        
        if status == .notDetermined {
            do {
                let granted: Bool
                if #available(iOS 17.0, *) {
                    granted = try await store.requestFullAccessToEvents()
                } else {
                    granted = try await store.requestAccess(to: .event)
                }
                return granted
            } catch {
                print("[Calendar] ❌ 권한 오류: \(error)")
                return false
            }
        }
        
        print("[Calendar] ⚠️ 권한 거부")
        return false
    }
    
    // MARK: - 생성
    @discardableResult
    func createEvent(for plan: Plan) async -> String? {
        guard await requestPermission() else { return nil }
        guard let defaultCalendar = store.defaultCalendarForNewEvents else { return nil }
        
        let event = EKEvent(eventStore: store)
        fillEvent(event, from: plan)
        event.calendar = defaultCalendar
        
        do {
            try store.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("[Calendar] ❌ 생성 실패: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 업데이트
    @discardableResult
    func updateEvent(for plan: Plan) async -> String? {
        guard await requestPermission() else { return nil }
        
        if let id = plan.eventIdentifier,
           let existing = store.event(withIdentifier: id) {
            do { try store.remove(existing, span: .thisEvent) }
            catch { print("[Calendar] ⚠️ 기존 제거 실패: \(error)") }
        }
        
        return await createEvent(for: plan)
    }
    
    // MARK: - 삭제
    func deleteEvent(identifier: String) async {
        store.refreshSourcesIfNecessary()
        guard let event = store.event(withIdentifier: identifier) else { return }
        
        do {
            try store.remove(event, span: .thisEvent)
        } catch {
            print("[Calendar] ❌ 삭제 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 캘린더 앱 열기
    func openCalendarApp(for plan: Plan) {
        let c = DateComponents(year: plan.year, month: plan.month, day: plan.day)
        guard let date = Calendar.current.date(from: c) else { return }
        if let url = URL(string: "calshow:\(date.timeIntervalSinceReferenceDate)") {
            DispatchQueue.main.async { UIApplication.shared.open(url) }
        }
    }
    
    // MARK: - EKEvent 채우기
    private func fillEvent(_ event: EKEvent, from plan: Plan) {
        // 제목
        if plan.isWorkSchedule {
            let unitStr = String(format: "%.1f단위", plan.workUnits)
            event.title = plan.status == .completed ? "✅ \(unitStr)" : unitStr
        } else {
            event.title = plan.status == .completed ? "✅ \(plan.title)" : plan.title
        }
        
        // 날짜/시간
        let cal = Calendar.current
        var c = DateComponents(year: plan.year, month: plan.month, day: plan.day)
        
        if plan.hasTime {
            event.isAllDay = false
            c.hour = plan.hour; c.minute = plan.minute; c.second = 0
            guard let start = cal.date(from: c) else { return }
            event.startDate = start
            
            if plan.hasEndTime {
                let ec = DateComponents(year: plan.year, month: plan.month, day: plan.day, hour: plan.endHour, minute: plan.endMinute, second: 0)
                guard let end = cal.date(from: ec) else { return }
                
                // 💡 시작일보다 종료일이 앞서면(또는 같으면) 다음날로 간주
                event.endDate = end <= start ? (cal.date(byAdding: .day, value: 1, to: end) ?? end) : end
            } else {
                event.endDate = start.addingTimeInterval(3600)
            }
        } else {
            event.isAllDay = true
            guard let day = cal.date(from: c) else { return }
            let startOfDay = cal.startOfDay(for: day)
            event.startDate = startOfDay
            event.endDate = startOfDay
        }
        
        // 메모
        var notes = [String]()
        if plan.isWorkSchedule {
            notes.append("공수: \(String(format: "%.1f", plan.workUnits))h")
            if !plan.siteName.isEmpty { notes.append("현장: \(plan.siteName)") }
            if plan.dailyWage > 0 { notes.append("일당: ₩\(plan.dailyWage.formatted())") }
            if plan.expectedIncome > 0 { notes.append("예상 수입: ₩\(Int(plan.expectedIncome).formatted())") }
            notes.append("지급: \(plan.isPaid ? "완료 ✅" : "미완료 ⚠️")")
        }
        
        if !plan.memo.isEmpty { notes.append(plan.memo) }
        
        if plan.status == .completed, let done = plan.completedAt {
            let fmt = DateFormatter()
            fmt.dateStyle = .short; fmt.timeStyle = .short
            notes.append("완료 시각: \(fmt.string(from: done))")
        }
        
        event.notes = notes.isEmpty ? nil : notes.joined(separator: "\n\n")
        
        // 알림
        event.alarms = nil
        if plan.notificationEnabled && plan.hasTime {
            event.addAlarm(EKAlarm(relativeOffset: 0))
        }
    }
}
