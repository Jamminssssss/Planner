import SwiftData
import Foundation

// MARK: - Plan Status

enum PlanStatus: String, Codable, CaseIterable {
    case planned
    case completed
    case canceled
}

// MARK: - Notification Sound Option

enum NotificationSound: String, Codable, CaseIterable {
    case sound
    case vibration
    case silent
    
    var displayName: String {
        switch self {
        case .sound:     return "🔊 Sound"
        case .vibration: return "📳 Vibration only"
        case .silent:    return "🔕 Silent"
        }
    }
}

// MARK: - Plan Model

@Model
final class Plan {
    // ❌ CloudKit에서는 unique constraint 지원 안 함 → 제거
    @Attribute var id: UUID = UUID()
    var title: String = ""
    var memo: String = ""
    
    // 날짜: Year / Month / Day
    var year: Int = Calendar.current.component(.year, from: Date())
    var month: Int = Calendar.current.component(.month, from: Date())
    var day: Int = Calendar.current.component(.day, from: Date())
    
    // 시간: Hour / Minute
    var hasTime: Bool = false
    var hour: Int = 0
    var minute: Int = 0
    
    var status: PlanStatus = PlanStatus.planned        // ✅ 완전 qualified name
    var completedAt: Date? = nil
    
    // 알림
    var notificationEnabled: Bool = false
    var notificationSound: NotificationSound = NotificationSound.sound // ✅ 완전 qualified name

    // iOS 캘린더 연동
    var calendarSyncEnabled: Bool = false
    var eventIdentifier: String? = nil
    
    // 카테고리 관계
    var category: Category? = nil
    
    var createdAt: Date = Date()
    
    
    init(
        id: UUID = UUID(),
        title: String = "",
        memo: String = "",
        year: Int = Calendar.current.component(.year, from: Date()),
        month: Int = Calendar.current.component(.month, from: Date()),
        day: Int = Calendar.current.component(.day, from: Date()),
        hasTime: Bool = false,
        hour: Int = 0,
        minute: Int = 0,
        status: PlanStatus = PlanStatus.planned,                 // ← 완전 qualified
        completedAt: Date? = nil,
        notificationEnabled: Bool = false,
        notificationSound: NotificationSound = NotificationSound.sound, // ← 완전 qualified
        calendarSyncEnabled: Bool = false,
        eventIdentifier: String? = nil,
        category: Category? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.year = year
        self.month = month
        self.day = day
        self.hasTime = hasTime
        self.hour = hour
        self.minute = minute
        self.status = status
        self.completedAt = completedAt
        self.notificationEnabled = notificationEnabled
        self.notificationSound = notificationSound
        self.calendarSyncEnabled = calendarSyncEnabled
        self.eventIdentifier = eventIdentifier
        self.category = category
        self.createdAt = createdAt
    }
    
    // MARK: - Computed Properties
    
    var scheduledDate: Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        if hasTime {
            comps.hour = hour
            comps.minute = minute
        }
        return Calendar.current.date(from: comps) ?? Date()
    }
    
    var scheduledDateOnly: Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
    
    var completedDateOnly: Date? {
        guard let completedAt = completedAt else { return nil }
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: completedAt)
        return cal.date(from: comps)
    }
    
    var timeDisplay: String? {
        guard hasTime else { return nil }
        let h = hour < 12 ? (hour == 0 ? 12 : hour) : (hour == 12 ? 12 : hour - 12)
        let period = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, minute, period)
    }
}
