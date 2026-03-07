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

// MARK: - Work Units Option

enum WorkUnitsOption: String, Codable, CaseIterable {
    case half    = "0.5"
    case full    = "1.0"
    case oneHalf = "1.5"
    case custom  = "custom"

    /// 로컬라이즈된 표시 이름
    var displayName: String {
        switch self {
        case .half:    return String(localized: "work.units.half",     bundle: .main)
        case .full:    return String(localized: "work.units.full",     bundle: .main)
        case .oneHalf: return String(localized: "work.units.one.half", bundle: .main)
        case .custom:  return String(localized: "work.units.custom",   bundle: .main)
        }
    }

    var value: Double? {
        switch self {
        case .half:    return 0.5
        case .full:    return 1.0
        case .oneHalf: return 1.5
        case .custom:  return nil
        }
    }
}

// MARK: - Plan Model

@Model
final class Plan {
    @Attribute var id: UUID = UUID()
    var title: String = ""
    var memo: String  = ""

    var year: Int  = Calendar.current.component(.year,  from: Date())
    var month: Int = Calendar.current.component(.month, from: Date())
    var day: Int   = Calendar.current.component(.day,   from: Date())

    // 시작 시간
    var hasTime: Bool = false
    var hour: Int     = 0
    var minute: Int   = 0

    // 종료 시간
    var hasEndTime: Bool = false
    var endHour: Int     = 0
    var endMinute: Int   = 0

    var status: PlanStatus = PlanStatus.planned
    var completedAt: Date? = nil

    var notificationEnabled: Bool = false
    var notificationSound: NotificationSound = NotificationSound.sound

    var calendarSyncEnabled: Bool = false
    var eventIdentifier: String?  = nil

    var category: Category? = nil
    var createdAt: Date = Date()

    // MARK: - Work Schedule Fields
    var isWorkSchedule: Bool = false
    var workUnits: Double    = 1.0
    var dailyWage: Int       = 0
    var siteName: String     = ""
    var isPaid: Bool         = false

    init(
        id: UUID = UUID(),
        title: String = "",
        memo: String = "",
        year: Int  = Calendar.current.component(.year,  from: Date()),
        month: Int = Calendar.current.component(.month, from: Date()),
        day: Int   = Calendar.current.component(.day,   from: Date()),
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
        self.id = id; self.title = title; self.memo = memo
        self.year = year; self.month = month; self.day = day
        self.hasTime = hasTime; self.hour = hour; self.minute = minute
        self.hasEndTime = hasEndTime; self.endHour = endHour; self.endMinute = endMinute
        self.status = status; self.completedAt = completedAt
        self.notificationEnabled = notificationEnabled
        self.notificationSound = notificationSound
        self.calendarSyncEnabled = calendarSyncEnabled
        self.eventIdentifier = eventIdentifier
        self.category = category; self.createdAt = createdAt
        self.isWorkSchedule = isWorkSchedule
        self.workUnits = workUnits; self.dailyWage = dailyWage
        self.siteName = siteName; self.isPaid = isPaid
    }

    // MARK: - Computed

    var scheduledDate: Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        if hasTime { c.hour = hour; c.minute = minute }
        return Calendar.current.date(from: c) ?? Date()
    }

    var scheduledDateOnly: Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = 0; c.minute = 0; c.second = 0
        return Calendar.current.date(from: c) ?? Date()
    }

    var completedDateOnly: Date? {
        guard let ca = completedAt else { return nil }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: ca)
        return Calendar.current.date(from: c)
    }

    private func timeString(h: Int, m: Int) -> String {
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        let period   = h < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", displayH, m, period)
    }

    var timeDisplay: String? {
        guard hasTime else { return nil }
        let start = timeString(h: hour, m: minute)
        return hasEndTime ? "\(start) – \(timeString(h: endHour, m: endMinute))" : start
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
