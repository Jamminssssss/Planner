import SwiftData
import Foundation

// MARK: - Plan Status
enum PlanStatus: String, Codable, CaseIterable {
    case planned, completed, canceled
}

// MARK: - Notification Sound Option
enum NotificationSound: String, Codable, CaseIterable {
    case sound, vibration, silent
    
    var displayName: String {
        switch self {
        case .sound:     return "🔊 Sound"
        case .vibration: return "📳 Vibration only"
        case .silent:    return "🔕 Silent"
        }
    }
}

// MARK: - Work Units Option (수정된 범용 버전에 맞춰 옵션 유지 또는 제거)
// (AddPlanView와 WorkStatsView에서 수동 텍스트 입력 방식을 쓰기로 하셨다면 이 Enum은 삭제해도 무방하지만, 기존 코드를 위해 둡니다.)

// MARK: - Plan Model
@Model
final class Plan {
    // 💡 CloudKit 규칙: @Attribute를 제거하고 기본값 할당
    var id: UUID = UUID()
    var title: String = ""
    var memo: String = ""

    var year: Int = 0
    var month: Int = 0
    var day: Int = 0

    var hasTime: Bool = false
    var hour: Int = 0
    var minute: Int = 0

    var hasEndTime: Bool = false
    var endHour: Int = 0
    var endMinute: Int = 0

    var status: PlanStatus = PlanStatus.planned
    var completedAt: Date?

    var notificationEnabled: Bool = false
    var notificationSound: NotificationSound = NotificationSound.sound

    var calendarSyncEnabled: Bool = false
    var eventIdentifier: String?

    var category: Category?
    var createdAt: Date = Date()

    var isWorkSchedule: Bool = false
    var workUnits: Double = 1.0
    var dailyWage: Int = 0
    var siteName: String = ""
    var isPaid: Bool = false

    init(
        id: UUID = UUID(),
        title: String = "",
        memo: String = "",
        year: Int? = nil,
        month: Int? = nil,
        day: Int? = nil,
        hasTime: Bool = false,
        hour: Int = 0, minute: Int = 0,
        hasEndTime: Bool = false,
        endHour: Int = 0, endMinute: Int = 0,
        status: PlanStatus = .planned,
        completedAt: Date? = nil,
        notificationEnabled: Bool = false,
        notificationSound: NotificationSound = .sound,
        calendarSyncEnabled: Bool = false,
        eventIdentifier: String? = nil,
        category: Category? = nil,
        createdAt: Date = Date(),
        isWorkSchedule: Bool = false,
        workUnits: Double = 1.0,
        dailyWage: Int = 0,
        siteName: String = "",
        isPaid: Bool = false
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        
        let now = Date()
        let cal = Calendar.current
        self.year = year ?? cal.component(.year, from: now)
        self.month = month ?? cal.component(.month, from: now)
        self.day = day ?? cal.component(.day, from: now)
        
        self.hasTime = hasTime
        self.hour = hour
        self.minute = minute
        self.hasEndTime = hasEndTime
        self.endHour = endHour
        self.endMinute = endMinute
        self.status = status
        self.completedAt = completedAt
        self.notificationEnabled = notificationEnabled
        self.notificationSound = notificationSound
        self.calendarSyncEnabled = calendarSyncEnabled
        self.eventIdentifier = eventIdentifier
        self.category = category
        self.createdAt = createdAt
        self.isWorkSchedule = isWorkSchedule
        self.workUnits = workUnits
        self.dailyWage = dailyWage
        self.siteName = siteName
        self.isPaid = isPaid
    }

    // ... (Computed Properties 하단부는 기존 코드와 동일하게 유지) ...
    var scheduledDate: Date {
        var c = DateComponents(year: year, month: month, day: day)
        if hasTime { c.hour = hour; c.minute = minute }
        return Calendar.current.date(from: c) ?? Date()
    }

    var scheduledDateOnly: Date {
        let c = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: c) ?? Date()
    }

    var completedDateOnly: Date? {
        guard let ca = completedAt else { return nil }
        return Calendar.current.startOfDay(for: ca)
    }

    var timeDisplay: String? {
        guard hasTime else { return nil }
        let startString = scheduledDate.formatted(date: .omitted, time: .shortened)
        if hasEndTime {
            let endComponents = DateComponents(year: year, month: month, day: day, hour: endHour, minute: endMinute)
            let endDate = Calendar.current.date(from: endComponents) ?? Date()
            let endString = endDate.formatted(date: .omitted, time: .shortened)
            return "\(startString) – \(endString)"
        }
        return startString
    }

    var expectedIncome: Double {
        guard isWorkSchedule else { return 0 }
        return workUnits * Double(dailyWage)
    }

    var paidIncome: Double {
        guard isWorkSchedule && isPaid else { return 0 }
        return expectedIncome
    }
}
