import SwiftData
import SwiftUI
import Foundation

// MARK: - Mood
enum Mood: String, CaseIterable, Codable {
    case great = "great", good = "good", neutral = "neutral", bad = "bad", terrible = "terrible"

    // 💡 누락되었던 emoji 속성 복구
    var emoji: String {
        switch self {
        case .great: return "😄"
        case .good: return "🙂"
        case .neutral: return "😐"
        case .bad: return "😟"
        case .terrible: return "😢"
        }
    }

    // 💡 누락되었던 label 속성 복구
    var label: String {
        switch self {
        case .great: return "Great"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .bad: return "Bad"
        case .terrible: return "Terrible"
        }
    }

    // 💡 누락되었던 color 속성 복구
    var color: Color {
        switch self {
        case .great: return Color(red: 0.96, green: 0.84, blue: 0.18)
        case .good: return Color(red: 0.25, green: 0.80, blue: 0.45)
        case .neutral: return Color(red: 0.60, green: 0.60, blue: 0.60)
        case .bad: return Color(red: 1.00, green: 0.55, blue: 0.15)
        case .terrible: return Color(red: 0.95, green: 0.30, blue: 0.30)
        }
    }
}

// MARK: - DiaryImage
@Model
final class DiaryImage {
    @Attribute(.externalStorage) var imageData: Data = Data()
    @Attribute(.externalStorage) var encryptedData: Data?

    var order: Int = 0
    var createdAt: Date = Date()

    init(imageData: Data, order: Int = 0, createdAt: Date = Date()) {
        self.imageData = imageData
        self.encryptedData = nil
        self.order = order
        self.createdAt = createdAt
    }

    var uiImage: UIImage? { UIImage(data: imageData) }
}

// MARK: - DiaryEntry
@Model
final class DiaryEntry {
    var year: Int = 0
    var month: Int = 0
    var day: Int = 0
    var text: String = ""
    @Attribute(.externalStorage) var encryptedText: Data?
    var isLocked: Bool = false
    var moodRaw: String?
    
    // 💡 CloudKit 동기화를 위해 배열 관계는 반드시 옵셔널(?)이어야 합니다.
    @Relationship(deleteRule: .cascade) var images: [DiaryImage]? = []
    
    var themeName: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(year: Int, month: Int, day: Int, text: String = "", mood: Mood? = nil, images: [DiaryImage] = [], themeName: String = SeasonTheme.classic.rawValue, isLocked: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.year = year
        self.month = month
        self.day = day
        self.text = text
        self.moodRaw = mood?.rawValue
        self.images = images
        self.themeName = themeName
        self.isLocked = isLocked
        self.encryptedText = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var mood: Mood? {
        get { moodRaw.flatMap { Mood(rawValue: $0) } }
        set { moodRaw = newValue?.rawValue }
    }

    var theme: SeasonTheme { SeasonTheme(rawValue: themeName) ?? .classic }

    var dateValue: Date {
        let comps = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: comps) ?? Date()
    }

    // 💡 옵셔널 배열을 안전하게 푸는 로직 적용
    var sortedImages: [DiaryImage] { (images ?? []).sorted { $0.order < $1.order } }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && mood == nil && (images ?? []).isEmpty && encryptedText == nil
    }

    var previewTitle: String {
        guard !isLocked else { return "Diary Entry" }
        let first = text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Diary Entry" : trimmed
    }

    func isOnSameLocalDay(as date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return false }
        return year == y && month == m && day == d
    }

    static func existingCount(onLocalDayOf date: Date = Date(), in entries: [DiaryEntry], calendar: Calendar = .current) -> Int {
        entries.filter { $0.isOnSameLocalDay(as: date, calendar: calendar) }.count
    }
}
