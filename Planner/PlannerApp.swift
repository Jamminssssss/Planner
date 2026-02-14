import SwiftUI
import SwiftData
import UserNotifications

@main
struct PlannerApp: App {

    // MARK: - ModelContainer 생성
    let modelContainer: ModelContainer

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        do {
            let schema = Schema([
                Category.self,
                Plan.self,
                DiaryEntry.self,
                DiaryImage.self
            ])

            let config = ModelConfiguration(schema: schema)

            modelContainer = try ModelContainer(
                for: Category.self,
                    Plan.self,
                    DiaryEntry.self,
                    DiaryImage.self,
                configurations: config
            )

            print("✅ ModelContainer 생성 완료 (CloudKit OFF)")
        } catch {
            fatalError("[PlannerApp] ModelContainer 생성 실패: \(error)")
        }
    }


    // MARK: - TabView 상태
    @State private var selectedTab: Int = 0

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                // Tab 0 — Home
                HomeView()
                    .tag(0)
                    .tabItem {
                        Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                    }
                
                // Tab 1 — Diary
                DiaryListView()
                    .tag(1)
                    .tabItem {
                        Label("Diary", systemImage: selectedTab == 1 ? "book.fill" : "book")
                    }

                // Tab 2 — Stats
                StatsView()
                    .tag(2)
                    .tabItem {
                        Label("Stats", systemImage: selectedTab == 2 ? "chart.bar.fill" : "chart.bar")
                    }
            }
            .tint(.green)
            .modelContainer(modelContainer) // SwiftData 연결
        }
    }
}

// MARK: - Notification Delegate
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private override init() { super.init() }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let soundOption = userInfo["soundOption"] as? String ?? NotificationSound.sound.rawValue

        switch NotificationSound(rawValue: soundOption) {
        case .sound:
            completionHandler([.banner, .sound])
        case .vibration:
            completionHandler([.banner])
        case .silent:
            completionHandler([.banner])
        case .none:
            completionHandler([.banner, .sound])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let planId = response.notification.request.content.userInfo["planId"] as? String {
            print("[NotificationDelegate] Tapped → planId: \(planId)")
        }
        completionHandler()
    }
}
