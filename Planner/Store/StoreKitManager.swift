import StoreKit
import SwiftUI
import Combine

/// StoreKit 2 기반 구독 + 비소모품 관리자
@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    // MARK: - Published State
    
    @Published private(set) var subscriptionProducts: [Product] = []
    @Published private(set) var themeProducts: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published var isPurchasing: Bool = false
    
    // MARK: - Product IDs
    
    private let monthlyProductID = "com.grassplanner.pro.monthly"
    private let yearlyProductID  = "com.grassplanner.pro.yearly"
    
    private let themeProductIDs = [
        "com.grassplanner.theme.spring",
        "com.grassplanner.theme.summer",
        "com.grassplanner.theme.autumn",
        "com.grassplanner.theme.winter"
    ]
    
    private var allProductIDs: [String] {
        [monthlyProductID, yearlyProductID] + themeProductIDs
    }
    
    // MARK: - Computed
    
    /// Pro 구독 활성화 여부
    var isPro: Bool {
        purchasedProductIDs.contains(monthlyProductID) ||
        purchasedProductIDs.contains(yearlyProductID)
    }
    
    /// 월간 구독
    var monthlyProduct: Product? {
        subscriptionProducts.first { $0.id == monthlyProductID }
    }
    
    /// 연간 구독
    var yearlyProduct: Product? {
        subscriptionProducts.first { $0.id == yearlyProductID }
    }
    
    /// 특정 테마 구매 여부
    func hasPurchased(theme: SeasonTheme) -> Bool {
        theme == .classic || purchasedProductIDs.contains(theme.productID)
    }
    
    /// 특정 테마 상품 가져오기
    func product(for theme: SeasonTheme) -> Product? {
        themeProducts.first { $0.id == theme.productID }
    }
    
    // MARK: - Transaction Listener
    
    private var updateListenerTask: Task<Void, Error>?
    
    // MARK: - Init
    
    private init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: allProductIDs)
            
            // 구독 상품 분리
            subscriptionProducts = storeProducts
                .filter { [monthlyProductID, yearlyProductID].contains($0.id) }
                .sorted { p1, _ in p1.id == monthlyProductID }
            
            // 테마 상품 분리
            themeProducts = storeProducts
                .filter { themeProductIDs.contains($0.id) }
                .sorted { $0.id < $1.id }
            
            print("[StoreKit] ✅ Loaded \(subscriptionProducts.count) subscription(s), \(themeProducts.count) theme(s)")
        } catch {
            print("[StoreKit] ❌ Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase
    
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                print("[StoreKit] ✅ Purchase successful: \(product.id)")
                return true
                
            case .userCancelled:
                print("[StoreKit] ⚠️ User cancelled")
                return false
                
            case .pending:
                print("[StoreKit] ⏳ Purchase pending")
                return false
                
            @unknown default:
                return false
            }
        } catch {
            print("[StoreKit] ❌ Purchase failed: \(error)")
            return false
        }
    }
    
    // MARK: - Restore
    
    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            print("[StoreKit] ✅ Restore complete")
        } catch {
            print("[StoreKit] ❌ Restore failed: \(error)")
        }
    }
    
    // MARK: - Update Purchased Products
    
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 구독: expirationDate 체크
                if transaction.productType == .autoRenewable {
                    if transaction.revocationDate == nil,
                       transaction.expirationDate == nil || transaction.expirationDate! > Date() {
                        purchased.insert(transaction.productID)
                    }
                }
                // 비소모품: revocationDate만 체크
                else if transaction.productType == .nonConsumable {
                    if transaction.revocationDate == nil {
                        purchased.insert(transaction.productID)
                    }
                }
            } catch {
                print("[StoreKit] ❌ Transaction verification failed: \(error)")
            }
        }
        
        purchasedProductIDs = purchased
        print("[StoreKit] 📦 Purchased: \(purchased)")
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    print("[StoreKit] ❌ Transaction update failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}


// MARK: - Store Error

enum StoreError: Error {
    case failedVerification
}
