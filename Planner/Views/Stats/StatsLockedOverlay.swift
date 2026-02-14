import SwiftUI

/// Stats 탭 잠금 오버레이 (구독 안 한 경우)
struct StatsLockedOverlay: View {
    let onUpgrade: () -> Void

    var body: some View {
        ZStack {
            // ── 블러 백드롭 ──
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            // ── 카드 ──
            VStack(spacing: 24) {
                lockIcon
                titleAndDescription
                upgradeButton
            }
            .padding(.horizontal, 32)
        }
    }

    // ── 잠금 아이콘 ──
    private var lockIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.15), Color.green.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 100, height: 100)

            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
        }
    }

    // ── 제목 + 설명 ──
    private var titleAndDescription: some View {
        VStack(spacing: 10) {
            Text("Statistics are Pro-only")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text("Subscribe to Pro to unlock daily, weekly, and monthly statistics with category breakdowns and completion trends.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1.4)

            // 기능 리스트
            VStack(spacing: 8) {
                featureLine(icon: "calendar",           text: "Today / Week / Month view")
                featureLine(icon: "chart.bar",          text: "Completion charts")
                featureLine(icon: "tag",                text: "Category breakdown")
                featureLine(icon: "percent",            text: "Achievement rate tracking")
            }
            .padding(.top, 4)
        }
    }

    private func featureLine(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)

            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // ── Upgrade 버튼 ──
    private var upgradeButton: some View {
        Button(action: onUpgrade) {
            Text("Upgrade to Pro")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [.green, .green.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    StatsLockedOverlay(onUpgrade: {})
}
