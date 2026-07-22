import SwiftUI

// MARK: - App Privacy Overlay

struct PrivacyOverlayModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay {
                if scenePhase != .active {
                    PrivacyScreenView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: scenePhase)
    }
}

// MARK: - Privacy Screen (shown in App Switcher)

private struct PrivacyScreenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary.opacity(0.5))

                Text("Diary")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
    }
}

// MARK: - Auto-Lock on Background

struct AutoLockModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var lockManager = DiaryLockManager.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    lockManager.clearAllSessions()
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func protectedFromBackground() -> some View {
        modifier(PrivacyOverlayModifier())
    }

    func autoLockOnBackground() -> some View {
        modifier(AutoLockModifier())
    }
}
