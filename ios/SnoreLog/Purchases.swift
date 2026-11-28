import StoreKit
import Combine

/// The one-time "Unlock all nights" purchase.
///
/// Builds you run yourself from Xcode (Debug) are always unlocked: the code is open source,
/// so the purchase only applies to the App Store version. In Debug builds, Settings has a
/// "Simulate free version" switch for testing the purchase flow with the StoreKit test file.
@MainActor
final class Purchases: ObservableObject {
    nonisolated static let unlockID = "com.insanum.snorelog.unlock"
    nonisolated static let simulateFreeKey = "debugSimulateFree"

    @Published private(set) var purchased = false
    @Published private(set) var product: Product?
    @Published private(set) var busy = false
    @Published var message: String?

    private var updates: Task<Void, Never>?
    private var defaultsObserver: NSObjectProtocol?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refresh() }
        #if DEBUG
        // Refresh screens when "Simulate free version" is switched.
        defaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                  object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
        #endif
    }

    var isUnlocked: Bool {
        #if DEBUG
        if !UserDefaults.standard.bool(forKey: Self.simulateFreeKey) { return true }
        #endif
        return purchased
    }

    var priceText: String { product?.displayPrice ?? "$2.99" }

    func refresh() async {
        if product == nil {
            product = try? await Product.products(for: [Self.unlockID]).first
        }
        for await result in Transaction.currentEntitlements {
            await handle(result)
        }
    }

    func buy() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            if product == nil { product = try await Product.products(for: [Self.unlockID]).first }
            guard let product else {
                message = "The App Store isn't available right now. Try again later."
                return
            }
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                if purchased { message = "Thank you! Every night is now kept." }
            case .pending:
                message = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through (\(error.localizedDescription))."
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            message = purchased ? "Your purchase was restored." : "No earlier purchase was found for this Apple Account."
        } catch {
            message = "Couldn't reach the App Store (\(error.localizedDescription))."
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result, transaction.productID == Self.unlockID else { return }
        purchased = transaction.revocationDate == nil
        objectWillChange.send()
        await transaction.finish()
    }
}
