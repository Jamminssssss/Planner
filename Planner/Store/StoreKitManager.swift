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
    
    // MARK: - Computed Properties
    var isPro: Bool {
        purchasedProductIDs.contains(monthlyProductID) || purchasedProductIDs.contains(yearlyProductID)
    }

    var isPremium: Bool { isPro }
    
    var monthlyProduct: Product? { subscriptionProducts.first { $0.id == monthlyProductID } }
    var yearlyProduct: Product? { subscriptionProducts.first { $0.id == yearlyProductID } }
    
    func hasPurchased(theme: SeasonTheme) -> Bool {
        theme == .classic || purchasedProductIDs.contains(theme.productID)
    }
    
    func product(for theme: SeasonTheme) -> Product? {
        themeProducts.first { $0.id == theme.productID }
    }
    
    // MARK: - Listener
    private var updateListenerTask: Task<Void, Error>?
    
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
    
    // MARK: - Network / Setup
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: allProductIDs)
            
            subscriptionProducts = storeProducts
                .filter { [monthlyProductID, yearlyProductID].contains($0.id) }
                .sorted { p1, _ in p1.id == monthlyProductID }
            
            themeProducts = storeProducts
                .filter { themeProductIDs.contains($0.id) }
                .sorted { $0.id < $1.id }
                
        } catch {
            print("[StoreKit] ❌ Failed to load products: \(error)")
        }
    }
    
    // MARK: - Core Operations
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshPurchasedProducts()
                NotificationCenter.default.post(name: .purchaseSuccess, object: nil)
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("[StoreKit] ❌ Purchase failed: \(error)")
            return false
        }
    }
    
    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await AppStore.sync()
            await refreshPurchasedProducts()
            if isPremium {
                NotificationCenter.default.post(name: .purchaseSuccess, object: nil)
            }
        } catch {
            print("[StoreKit] ❌ Restore failed: \(error)")
        }
    }
    
    func refreshPurchasedProducts() async {
        await updatePurchasedProducts()
    }
    
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productType == .autoRenewable {
                    if transaction.revocationDate == nil,
                       let expirationDate = transaction.expirationDate, expirationDate > Date() {
                        purchased.insert(transaction.productID)
                    }
                } else if transaction.productType == .nonConsumable {
                    if transaction.revocationDate == nil {
                        purchased.insert(transaction.productID)
                    }
                }
            } catch {
                print("[StoreKit] ❌ Transaction verification failed: \(error)")
            }
        }
        
        purchasedProductIDs = purchased
    }
    
    // MARK: - Transaction Updates (Background)
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
    
    // MARK: - Helpers
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }
}

// MARK: - Enums & Extensions
enum StoreError: Error {
    case failedVerification
}

extension Notification.Name {
    static let purchaseSuccess = Notification.Name("purchaseSuccess")
}
