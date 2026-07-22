import SwiftUI
import StoreKit

/// 구독 결제 화면
struct PurchaseView: View {
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    
    // 💡 최적화: 싱글톤 인스턴스는 @ObservedObject로 관찰
    @ObservedObject private var storeManager = StoreKitManager.shared

    @State private var selectedProduct: Product? = nil
    @State private var showRestoreAlert = false

    // MARK: - Animation States
    @State private var isButtonPressed = false
    @State private var isPurchaseSuccess = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var crownScale: CGFloat = 0.5
    @State private var crownOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    featuresSection
                    subscriptionPlansSection
                    purchaseButtonSection
                    footerLinksSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { finishPurchaseUI() }) {
                        Image(systemName: "xmark")
                            .imageScale(.medium)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Close")
                    }
                }
            }
            .alert("Restore Complete", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your purchases have been restored successfully.")
            }
            .onAppear {
                selectedProduct = storeManager.yearlyProduct
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.1)) {
                    crownScale = 1.0
                    crownOpacity = 1.0
                }
                startShimmer()
            }
        }
    }

    // MARK: - Shimmer Loop
    private func startShimmer() {
        shimmerOffset = -250
        withAnimation(.linear(duration: 2.2).delay(0.8).repeatForever(autoreverses: false)) {
            shimmerOffset = 400
        }
    }

    // MARK: - Sections (Header, Features, Plans)
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
                .scaleEffect(crownScale)
                .opacity(crownOpacity)

            Text("Grass Planner Pro")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text("Unlock unlimited plans and future reminders")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow(icon: "infinity", color: .blue, title: "Unlimited Daily Plans", description: "Add as many plans as you need each day")
            featureRow(icon: "calendar.badge.clock", color: .purple, title: "Future Reminders", description: "Schedule reminders for any future date")
            featureRow(icon: "star.fill", color: .yellow, title: "Cancel Anytime", description: "No commitments. Cancel subscription anytime.")
        }
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                Text(description).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var subscriptionPlansSection: some View {
        VStack(spacing: 10) {
            Text("Choose Your Plan")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let monthly = storeManager.monthlyProduct {
                planCard(product: monthly, badge: nil, isSelected: selectedProduct?.id == monthly.id)
            }
            if let yearly = storeManager.yearlyProduct {
                planCard(product: yearly, badge: "SAVE 17%", isSelected: selectedProduct?.id == yearly.id)
            }
        }
    }

    private func planCard(product: Product, badge: String?, isSelected: Bool) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                selectedProduct = product
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(isSelected ? Color.green : Color.secondary.opacity(0.3), lineWidth: 2).frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Color.green).frame(width: 12, height: 12).transition(.scale(scale: 0.1).combined(with: .opacity))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.displayName).font(.system(size: 15, weight: .semibold)).foregroundColor(.primary)
                        if let badge = badge {
                            Text(badge).font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2).background(Color.orange).cornerRadius(6)
                        }
                    }
                    Text(product.description).font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Text(product.displayPrice).font(.system(size: 16, weight: .bold)).foregroundColor(isSelected ? .green : .primary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(isSelected ? Color.green.opacity(0.08) : Color.secondary.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color.green : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase Button
    private var purchaseButtonSection: some View {
        VStack(spacing: 10) {
            if let product = selectedProduct {
                Button(action: { purchaseProduct(product) }) {
                    ZStack {
                        LinearGradient(colors: [Color.green, Color.green.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .cornerRadius(14)

                        if !storeManager.isPurchasing && !isPurchaseSuccess {
                            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25), Color.white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 80).offset(x: shimmerOffset).clipped().cornerRadius(14).allowsHitTesting(false)
                        }

                        Group {
                            if isPurchaseSuccess {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                                    Text("Purchase Complete!").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                            } else if storeManager.isPurchasing {
                                HStack(spacing: 8) {
                                    ProgressView().progressViewStyle(.circular).tint(.white)
                                    Text("Purchasing...").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                }
                                .transition(.opacity)
                            } else {
                                Text("Subscribe for \(product.displayPrice)").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPurchaseSuccess)
                        .animation(.easeInOut(duration: 0.25), value: storeManager.isPurchasing)
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .scaleEffect(isButtonPressed ? 0.96 : 1.0)
                    .shadow(color: Color.green.opacity(isButtonPressed ? 0.15 : 0.35), radius: isButtonPressed ? 4 : 10, y: isButtonPressed ? 2 : 5)
                }
                .disabled(storeManager.isPurchasing || isPurchaseSuccess)
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isButtonPressed { isButtonPressed = true; UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                        }
                        .onEnded { _ in isButtonPressed = false }
                )

                Text("Auto-renews. Cancel anytime.").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.7))
            } else {
                HStack(spacing: 8) { ProgressView(); Text("Loading...").foregroundColor(.secondary) }
                    .frame(maxWidth: .infinity).frame(height: 52).background(Color.secondary.opacity(0.1)).cornerRadius(14)
            }
        }
    }

    private var footerLinksSection: some View {
        VStack(spacing: 8) {
            Divider()
            HStack(spacing: 12) {
                Button(action: { restorePurchases() }) { Text("Restore Purchases").font(.footnote).foregroundColor(.secondary) }.disabled(storeManager.isPurchasing)
                Text("·").foregroundColor(.secondary)
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!).font(.footnote).foregroundColor(.secondary)
                Text("·").foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://sites.google.com/view/grassplanner/home")!).font(.footnote).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Actions
    private func finishPurchaseUI() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func purchaseProduct(_ product: Product) {
        Task {
            let success = await storeManager.purchase(product)
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation { isPurchaseSuccess = true }
                try? await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run { finishPurchaseUI() }
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func restorePurchases() {
        Task {
            await storeManager.restorePurchases()
            showRestoreAlert = true
        }
    }
}
