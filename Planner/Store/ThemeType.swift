import Foundation

/// 테마 적용 타입 (다이어리 vs 캘린더)
enum ThemeType {
    case diary
    case calendar
    
    var displayName: String {
        switch self {
        case .diary:
            return "Diary Theme"
        case .calendar:
            return "Calendar Theme"
        }
    }
    
    var storageKey: String {
        switch self {
        case .diary:
            return "diaryTheme"
        case .calendar:
            return "calendarTheme"
        }
    }
    
    var storeTitle: String {
        switch self {
        case .diary:
            return "Diary Themes"
        case .calendar:
            return "Grass Calendar Themes"
        }
    }
    
    var storeDescription: String {
        switch self {
        case .diary:
            return "Purchase seasonal themes to personalize your diary with beautiful colors and moods"
        case .calendar:
            return "Purchase seasonal themes to customize your grass calendar with vibrant seasonal colors"
        }
    }
    
    var currentThemeLabel: String {
        switch self {
        case .diary:
            return "Current Diary Theme"
        case .calendar:
            return "Current Calendar Theme"
        }
    }
}
