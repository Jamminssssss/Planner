import SwiftUI
import StoreKit

/// 구독 결제 화면
struct PurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitManager.shared
    
    @State private var selectedProduct: Product? = nil
    @State private var showRestoreAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    featuresSection
                    subscriptionPlansSection
                    purchaseButtonSection
                    restoreSection
                    legalLinksSection // ✅ Terms / Privacy 링크 추가
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
            .alert("Restore Complete", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your purchases have been restored successfully.")
            }
            .onAppear {
                // 기본 선택: 연간 구독
                selectedProduct = storeManager.yearlyProduct
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundColor(.yellow)
            
            Text("Grass Planner Pro")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Unlock unlimited plans and future reminders")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Features
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow(icon: "infinity", color: .blue,
                       title: "Unlimited Daily Plans",
                       description: "Add as many plans as you need each day")
            
            featureRow(icon: "calendar.badge.clock", color: .purple,
                       title: "Future Reminders",
                       description: "Schedule reminders for any future date")
            
            featureRow(icon: "star.fill", color: .yellow,
                       title: "Cancel Anytime",
                       description: "No commitments. Cancel subscription anytime.")
        }
        .padding(.vertical, 8)
    }
    
    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Subscription Plans
    private var subscriptionPlansSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.system(size: 18, weight: .semibold))
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
        Button(action: { selectedProduct = product }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.green : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.orange)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text(product.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(product.displayPrice)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .green : .primary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.green.opacity(0.08) : Color.secondary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Purchase Button
    private var purchaseButtonSection: some View {
        VStack(spacing: 16) {
            if let product = selectedProduct {
                Button(action: { purchaseProduct(product) }) {
                    HStack(spacing: 8) {
                        if storeManager.isPurchasing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                            Text("Purchasing...")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Text("Subscribe for \(product.displayPrice)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                }
                .disabled(storeManager.isPurchasing)
                .buttonStyle(.plain)
                
                Text("Auto-renews. Cancel anytime.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(14)
            }
        }
    }
    
    // MARK: - Restore
    private var restoreSection: some View {
        VStack(spacing: 12) {
            Button(action: { restorePurchases() }) {
                HStack(spacing: 6) {
                    if storeManager.isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.secondary)
                    }
                    Text("Restore Purchases")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            .disabled(storeManager.isPurchasing)
            
            Text("Already subscribed? Tap here to restore.")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Legal Links (✅ 추가)
    private var legalLinksSection: some View {
        VStack(spacing: 8) {
            Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .font(.footnote)
                .foregroundColor(.blue)
            
            Link("Privacy Policy", destination: URL(string: "https://sites.google.com/view/grassplanner/home")!)
                .font(.footnote)
                .foregroundColor(.blue)
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Actions
    private func purchaseProduct(_ product: Product) {
        Task {
            let success = await storeManager.purchase(product)
            if success {
                dismiss()
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

// MARK: - Preview
#Preview {
    PurchaseView()
}
