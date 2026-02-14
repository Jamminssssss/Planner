import SwiftData
import SwiftUI
import Foundation

// MARK: - Mood

enum Mood: String, CaseIterable, Codable {
    case great    = "great"
    case good     = "good"
    case neutral  = "neutral"
    case bad      = "bad"
    case terrible = "terrible"

    var emoji: String {
        switch self {
        case .great:    return "😄"
        case .good:     return "🙂"
        case .neutral:  return "😐"
        case .bad:      return "😟"
        case .terrible: return "😢"
        }
    }

    var label: String {
        switch self {
        case .great:    return "Great"
        case .good:     return "Good"
        case .neutral:  return "Neutral"
        case .bad:      return "Bad"
        case .terrible: return "Terrible"
        }
    }

    var color: Color {
        switch self {
        case .great:    return Color(red: 0.96, green: 0.84, blue: 0.18)  // 밝은 노랑
        case .good:     return Color(red: 0.25, green: 0.80, blue: 0.45)  // 그린
        case .neutral:  return Color(red: 0.60, green: 0.60, blue: 0.60)  // 회색
        case .bad:      return Color(red: 1.00, green: 0.55, blue: 0.15)  // 오랑주
        case .terrible: return Color(red: 0.95, green: 0.30, blue: 0.30)  // 레드
        }
    }
}

// MARK: - DiaryImage (CloudKit 호환)

@Model
final class DiaryImage {
    
    /// ✅ CloudKit 동기화를 위해 실제 이미지 데이터를 저장
    /// externalStorage: 큰 데이터를 별도 저장소에 보관 (iCloud 효율)
    @Attribute(.externalStorage) var imageData: Data
    
    var order: Int
    var createdAt: Date

    init(
        imageData: Data,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.imageData = imageData
        self.order = order
        self.createdAt = createdAt
    }
    
    /// UIImage 변환 헬퍼
    var uiImage: UIImage? {
        UIImage(data: imageData)
    }
}

// MARK: - DiaryEntry

@Model
final class DiaryEntry {

    var year: Int
    var month: Int
    var day: Int

    var text: String
    
    /// ✅ CloudKit는 enum을 직접 지원 안함 → String으로 저장
    var moodRaw: String?

    /// ✅ CloudKit 동기화 시 관계(Relationship)도 자동으로 전송됨
    @Relationship(deleteRule: .cascade)
    var images: [DiaryImage]

    var themeName: String
    var createdAt: Date
    var updatedAt: Date

    init(
        year: Int,
        month: Int,
        day: Int,
        text: String = "",
        mood: Mood? = nil,
        images: [DiaryImage] = [],
        themeName: String = SeasonTheme.classic.rawValue,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.text = text
        self.moodRaw = mood?.rawValue
        self.images = images
        self.themeName = themeName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    var mood: Mood? {
        get { moodRaw.flatMap { Mood(rawValue: $0) } }
        set { moodRaw = newValue?.rawValue }
    }

    var theme: SeasonTheme {
        SeasonTheme(rawValue: themeName) ?? .classic
    }

    var dateValue: Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps) ?? Date()
    }

    var sortedImages: [DiaryImage] {
        images.sorted { $0.order < $1.order }
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        mood == nil &&
        images.isEmpty
    }
}
