import SwiftUI

// MARK: - Diary Lock Overlay View

struct DiaryLockOverlayView: View {
    let theme: SeasonTheme
    let onUnlock: () async throws -> Void

    @State private var isAttempting = false
    @State private var shakeAmount: CGFloat = 0
    @State private var showUnlockFailedAlert = false
    @State private var unlockFailedMessage = ""
    @State private var lockScale: CGFloat = 1.0

    @ObservedObject private var lockManager = DiaryLockManager.shared

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 36) {
                ZStack {
                    Circle()
                        .fill(theme.diaryAccent.opacity(0.12))
                        .frame(width: 110, height: 110)
                    Circle()
                        .fill(theme.diaryAccent.opacity(0.06))
                        .frame(width: 88, height: 88)
                    Image(systemName: isAttempting ? lockManager.biometrySystemImage : "lock.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(theme.diaryAccent)
                        .contentTransition(.symbolEffect(.replace))
                }
                .scaleEffect(lockScale)
                .offset(x: shakeAmount)

                VStack(spacing: 10) {
                    Text("Protected Entry")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text("This entry is encrypted.\nAuthenticate to view its contents.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                Button {
                    Task { await attempt() }
                } label: {
                    Group {
                        if isAttempting {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.85)
                                Text("Authenticating…")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: lockManager.biometrySystemImage)
                                    .font(.system(size: 18))
                                Text("Unlock with \(lockManager.biometryName)")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(height: 54)
                    .frame(minWidth: 220)
                    .padding(.horizontal, 28)
                    .background(
                        isAttempting
                            ? AnyShapeStyle(theme.diaryAccent.opacity(0.7))
                            : AnyShapeStyle(theme.diaryAccent),
                        in: Capsule()
                    )
                    .shadow(color: theme.diaryAccent.opacity(0.35), radius: 12, y: 4)
                }
                .disabled(isAttempting)
                .animation(.easeInOut(duration: 0.2), value: isAttempting)
            }
            .padding(40)
        }
        .alert("Couldn’t unlock", isPresented: $showUnlockFailedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(unlockFailedMessage)
        }
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await attempt()
        }
    }

    private func attempt() async {
        guard !isAttempting else { return }
        await MainActor.run {
            isAttempting = true
            showUnlockFailedAlert = false
        }

        do {
            try await onUnlock()
            await pulseSuccess()
        } catch LockError.userCancelled {
            // Do nothing
        } catch {
            await shake()
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            await MainActor.run {
                unlockFailedMessage = msg
                showUnlockFailedAlert = true
            }
        }

        await MainActor.run {
            isAttempting = false
        }
    }

    private func shake() async {
        let offsets: [CGFloat] = [12, -10, 8, -6, 4, -2, 0]
        for offset in offsets {
            withAnimation(.easeInOut(duration: 0.055)) { shakeAmount = offset }
            try? await Task.sleep(nanoseconds: 55_000_000)
        }
    }

    private func pulseSuccess() async {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { lockScale = 1.15 }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { lockScale = 1.0 }
    }
}

// MARK: - Lock Status Badge

struct LockStatusBadge: View {
    let isLocked: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isLocked ? accentColor : .secondary)
                .padding(.horizontal, 16) // 넓이를 조금 조절하여 터치 영역 확보
                .padding(.vertical, 7)
                .background(
                    isLocked
                        ? AnyShapeStyle(accentColor.opacity(0.15))
                        : AnyShapeStyle(Color.secondary.opacity(0.1)),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isLocked ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLocked ? "Locked — tap to manage" : "Unlocked — tap to lock")
    }
}
