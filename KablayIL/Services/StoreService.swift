import Foundation
import StoreKit

/// In-app purchases for professional features.
///
/// Apple is the merchant of record: the app never sees payment details and
/// never grants anything itself. A purchase is only worth something after the
/// KABLAY server has checked the transaction with Apple, so a transaction is
/// finished only once the server confirms it. An interrupted purchase stays
/// unfinished and is retried on the next launch instead of being lost.
@MainActor
@Observable
final class StoreService {
    enum PurchaseOutcome: Equatable {
        case completed
        case pending
        case cancelled
    }

    enum StoreError: LocalizedError, Equatable {
        case productsUnavailable
        case notVerified
        case notRedeemed

        var errorDescription: String? {
            switch self {
            case .productsUnavailable: "The store is not available right now"
            case .notVerified: "The purchase could not be verified with the App Store"
            case .notRedeemed: "The purchase was not applied to your account"
            }
        }
    }

    static let creditProductIDs = [
        "il.co.kablay.app.credits.50",
        "il.co.kablay.app.credits.100",
        "il.co.kablay.app.credits.200",
    ]
    static let premiumProductID = "il.co.kablay.app.premium.monthly"

    /// Credits granted per pack. The server grants from Apple's own answer, so
    /// this is used only to describe a pack before it is bought.
    static let creditAmounts: [String: Int] = [
        "il.co.kablay.app.credits.50": 50,
        "il.co.kablay.app.credits.100": 100,
        "il.co.kablay.app.credits.200": 200,
    ]

    private(set) var creditProducts: [Product] = []
    private(set) var premiumProduct: Product?
    private(set) var isLoadingProducts = false
    private(set) var didLoadProducts = false
    var purchasingProductID: String?
    var isRestoring = false

    /// Hands a verified transaction id to the server. Returns true only when
    /// the entitlement was actually applied to the account.
    var redeem: ((String) async -> Bool)?

    /// Held for the whole app session. StoreKit delivers updates until the
    /// process ends, so the listener is never torn down while the app runs.
    private var updatesTask: Task<Void, Never>?

    var isAvailable: Bool { !creditProducts.isEmpty || premiumProduct != nil }

    func start() {
        guard updatesTask == nil else { return }
        // Purchases can also arrive outside a purchase call: Ask to Buy
        // approvals, a purchase made on another device, or a refund reversal.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task {
            await redeemUnfinishedTransactions()
            await syncCurrentSubscription()
        }
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            didLoadProducts = true
        }
        do {
            let identifiers = Set(Self.creditProductIDs + [Self.premiumProductID])
            let products = try await Product.products(for: identifiers)
            creditProducts = Self.creditProductIDs.compactMap { id in
                products.first { $0.id == id }
            }
            premiumProduct = products.first { $0.id == Self.premiumProductID }
        } catch {
            creditProducts = []
            premiumProduct = nil
        }
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                throw StoreError.notVerified
            }
            guard await redeemAndFinish(transaction) else { throw StoreError.notRedeemed }
            return .completed
        case .pending:
            // Ask to Buy and similar holds resolve later through Transaction.updates.
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Retry interrupted purchases and reconcile the latest subscription
    /// period with the server. The server's transaction-id ledger prevents a
    /// second grant when the same entitlement is reported again.
    @discardableResult
    func restorePurchases() async -> Int {
        isRestoring = true
        defer { isRestoring = false }
        try? await AppStore.sync()
        let applied = await redeemUnfinishedTransactions()
        await syncCurrentSubscription()
        return applied
    }

    @discardableResult
    private func redeemUnfinishedTransactions() async -> Int {
        var applied = 0
        for await update in Transaction.unfinished {
            guard case let .verified(transaction) = update else { continue }
            if await redeemAndFinish(transaction) { applied += 1 }
        }
        return applied
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = update else { return }
        _ = await redeemAndFinish(transaction)
    }

    private func syncCurrentSubscription() async {
        guard let redeem else { return }
        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  transaction.productID == Self.premiumProductID else { continue }
            _ = await redeem(String(transaction.id))
        }
    }

    private func redeemAndFinish(_ transaction: Transaction) async -> Bool {
        if transaction.revocationDate != nil {
            // Let the server verify Apple's revocation and reverse its grant.
            _ = await redeem?(String(transaction.id))
            await transaction.finish()
            return false
        }
        guard let redeem else { return false }
        guard await redeem(String(transaction.id)) else { return false }
        await transaction.finish()
        return true
    }
}
