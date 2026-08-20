import Combine
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    /// Create a matching non-consumable product in App Store Connect.
    static let premiumProductID = "JimWas.GhostEXIF.premium"

    @Published private(set) var premiumProduct: Product?
    @Published private(set) var hasPremium = false
    @Published private(set) var isWorking = false
    @Published private(set) var statusMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var hasPrepared = false

    private init() {
        updatesTask = observeTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true

        await refreshEntitlements()
        await loadProducts()
    }

    func purchasePremium() async {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            if premiumProduct == nil {
                await loadProducts()
            }
            guard let premiumProduct else {
                statusMessage = "PREMIUM_PRODUCT_UNAVAILABLE"
                return
            }

            switch try await premiumProduct.purchase() {
            case .success(let result):
                let transaction = try verified(result)
                guard transaction.productID == Self.premiumProductID else {
                    throw PurchaseError.unexpectedProduct
                }
                await transaction.finish()
                await refreshEntitlements()
                statusMessage = hasPremium ? "PURCHASE_VERIFIED" : "ENTITLEMENT_NOT_FOUND"

            case .pending:
                statusMessage = "PURCHASE_PENDING_APPROVAL"

            case .userCancelled:
                statusMessage = nil

            @unknown default:
                statusMessage = "PURCHASE_STATUS_UNKNOWN"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            // Apple requires this user-initiated action before forcing an App Store sync.
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasPremium ? "PURCHASE_RESTORED" : "NO_PREMIUM_PURCHASE_FOUND"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var ownsPremium = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.premiumProductID,
                  transaction.revocationDate == nil else {
                continue
            }
            ownsPremium = true
        }

        hasPremium = ownsPremium
    }

    private func loadProducts() async {
        do {
            premiumProduct = try await Product.products(for: [Self.premiumProductID]).first
            if premiumProduct == nil {
                statusMessage = "PREMIUM_PRODUCT_NOT_CONFIGURED"
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }
}

private enum PurchaseError: LocalizedError {
    case failedVerification
    case unexpectedProduct

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "PURCHASE_VERIFICATION_FAILED"
        case .unexpectedProduct:
            return "UNEXPECTED_STORE_PRODUCT"
        }
    }
}
