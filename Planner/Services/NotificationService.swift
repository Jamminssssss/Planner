import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private func startIdentifier(for planId: UUID) -> String { planId.uuidString }
    private func endIdentifier(for planId: UUID) -> String { planId.uuidString + "-end" }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("[NotificationService] Permission request failed: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func schedule(for plan: Plan) async {
        // 💡 버그 수정: 일정이 업데이트 될 때 중복 알림이 생기지 않도록 기존 알림을 먼저 취소합니다.
        cancel(planId: plan.id)
        
        guard plan.notificationEnabled, plan.hasTime else { return }

        await scheduleStartNotification(for: plan)

        if plan.hasEndTime {
            await scheduleEndNotification(for: plan)
        }
    }

    private func scheduleStartNotification(for plan: Plan) async {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.memo.isEmpty ? plan.title : plan.memo
        content.userInfo = ["planId": plan.id.uuidString, "soundOption": plan.notificationSound.rawValue]

        applySound(plan.notificationSound, to: content)

        let comps = DateComponents(timeZone: .current, year: plan.year, month: plan.month, day: plan.day, hour: plan.hour, minute: plan.minute, second: 0)

        await add(identifier: startIdentifier(for: plan.id), content: content, comps: comps, label: "시작")
    }

    private func scheduleEndNotification(for plan: Plan) async {
        let content = UNMutableNotificationContent()
        content.title = "\(plan.title) ✅"
        content.body = plan.memo.isEmpty ? plan.title : plan.memo
        content.userInfo = ["planId": plan.id.uuidString, "soundOption": plan.notificationSound.rawValue, "isEnd": true]

        applySound(plan.notificationSound, to: content)

        // 💡 버그 수정: 단순 day + 1이 아닌 Calendar 객체를 활용한 완벽한 다음 날짜 계산
        var comps = DateComponents(timeZone: .current, year: plan.year, month: plan.month, day: plan.day, hour: plan.endHour, minute: plan.endMinute, second: 0)
        
        let isOvernightEnd = (plan.endHour < plan.hour) || (plan.endHour == plan.hour && plan.endMinute <= plan.minute)
        
        if isOvernightEnd {
            let cal = Calendar.current
            if let baseDate = cal.date(from: comps),
               let nextDayDate = cal.date(byAdding: .day, value: 1, to: baseDate) {
                let nextDayComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: nextDayDate)
                comps.year = nextDayComps.year
                comps.month = nextDayComps.month
                comps.day = nextDayComps.day
            }
        }

        await add(identifier: endIdentifier(for: plan.id), content: content, comps: comps, label: "종료")
    }

    private func applySound(_ option: NotificationSound, to content: UNMutableNotificationContent) {
        switch option {
        case .sound:     content.sound = .default
        case .vibration: content.sound = UNNotificationSound(named: UNNotificationSoundName(""))
        case .silent:    content.sound = nil
        }
    }

    private func add(identifier: String, content: UNMutableNotificationContent, comps: DateComponents, label: String) async {
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("[NotificationService] ❌ Failed(\(label)): \(error)")
        }
    }

    func cancel(planId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            startIdentifier(for: planId), endIdentifier(for: planId)
        ])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
