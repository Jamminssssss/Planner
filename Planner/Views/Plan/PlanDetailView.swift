import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let plan: Plan

    var body: some View {
        VStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {

                    statusBanner
                        .padding(.top, 20)

                    detailContent
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)

        // ✅ 하단 버튼 고정
        .safeAreaInset(edge: .bottom) {
            actionButtons
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        let info = statusInfo

        return HStack {
            Label(info.label, systemImage: info.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(info.text)

            Spacer()

            if let category = plan.category {
                CategoryBadge(category: category)
            }
        }
        .padding()
        .background(info.bg)
    }

    private var statusInfo: (bg: Color, text: Color, icon: String, label: String) {
        switch plan.status {
        case .planned:
            return (.blue.opacity(0.08), .blue, "clock.fill", "Planned")
        case .completed:
            return (.green.opacity(0.08), .green, "checkmark.circle.fill", "Completed")
        case .canceled:
            return (.red.opacity(0.08), .red, "xmark.circle.fill", "Canceled")
        }
    }

    // MARK: - Detail Content

    private var detailContent: some View {
        VStack(spacing: 28) {

            Text(plan.title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .strikethrough(plan.status != .planned)

            if !plan.memo.isEmpty {
                Text(plan.memo)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                infoChip(
                    icon: "calendar",
                    color: .blue,
                    text: formattedDate
                )

                if let time = plan.timeDisplay {
                    infoChip(
                        icon: "clock",
                        color: .blue,
                        text: time
                    )
                }
            }

            if plan.notificationEnabled {
                infoChip(
                    icon: "bell.fill",
                    color: .orange,
                    text: plan.notificationSound.displayName
                )
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            switch plan.status {
            case .planned:
                fullWidthButton(
                    title: "Mark as Completed 🌱",
                    color: .green,
                    action: completePlan
                )

                fullWidthButton(
                    title: "Cancel Plan",
                    color: .red,
                    isOutlined: true,
                    action: cancelPlan
                )

            case .completed, .canceled:
                fullWidthButton(
                    title: "Revert to Planned",
                    color: .blue,
                    isOutlined: true,
                    action: revertPlan
                )
            }
        }
    }

    // MARK: - Actions

    private func completePlan() {
        NotificationService.shared.cancel(planId: plan.id)
        plan.status = .completed
        plan.completedAt = Date()
        try? modelContext.save()
    }

    private func cancelPlan() {
        NotificationService.shared.cancel(planId: plan.id)
        plan.status = .canceled
        plan.completedAt = nil
        try? modelContext.save()
    }

    private func revertPlan() {
        plan.status = .planned
        plan.completedAt = nil
        try? modelContext.save()
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: plan.scheduledDateOnly)
    }

    private func infoChip(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 15, weight: .semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    private func fullWidthButton(
        title: String,
        color: Color,
        isOutlined: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundColor(isOutlined ? color : .white)
                .background(isOutlined ? .clear : color)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color, lineWidth: isOutlined ? 1.5 : 0)
                )
                .cornerRadius(14)
        }
    }
}
