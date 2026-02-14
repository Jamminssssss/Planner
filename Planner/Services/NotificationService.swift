import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[NotificationService] Permission request failed: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Schedule

    func schedule(for plan: Plan) async {
        guard plan.notificationEnabled, plan.hasTime else { return }

        // ── 콘텐츠 ──
        let content = UNMutableNotificationContent()

        // title → Plan 제목
        // body  → 카테고리 있으면 "카테고리: 메모 또는 제목", 없으면 "메모 또는 제목"
        content.title = plan.title

        let categoryPrefix = plan.category.map { "\($0.name): " } ?? ""
        let bodyText       = plan.memo.isEmpty ? plan.title : plan.memo
        content.body       = "\(categoryPrefix)\(bodyText)"

        // ── userInfo: planId + soundOption ──
        content.userInfo = [
            "planId":      plan.id.uuidString,
            "soundOption": plan.notificationSound.rawValue
        ]

        // ── 사운드 ──
        switch plan.notificationSound {
        case .sound:
            content.sound = .default
        case .vibration:
            content.sound = UNNotificationSound(named: UNNotificationSoundName(""))
        case .silent:
            content.sound = nil
        }

        // ── 트리거 ──
        var comps = DateComponents()
        comps.timeZone = TimeZone.current
        comps.year     = plan.year
        comps.month    = plan.month
        comps.day      = plan.day
        comps.hour     = plan.hour
        comps.minute   = plan.minute
        comps.second   = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        // ── 등록 ──
        let request = UNNotificationRequest(
            identifier: plan.id.uuidString,
            content:    content,
            trigger:    trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("[NotificationService] ✅ Scheduled: \(plan.title) → \(plan.hour):\(String(format: "%02d", plan.minute))")
        } catch {
            print("[NotificationService] ❌ Failed: \(error)")
        }
    }

    // MARK: - Cancel

    func cancel(planId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [planId.uuidString])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
