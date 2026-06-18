import Foundation
import RevenueCat

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isConfigured = false
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentOfferingIdentifier: String?
    @Published private(set) var lastErrorMessage: String?

    private var customerInfoTask: Task<Void, Never>?

    deinit {
        customerInfoTask?.cancel()
    }

    var activeLockLimit: Int {
        isPro ? Int.max : 1
    }

    func canCreateLock(activeLockCount: Int) -> Bool {
        isPro || activeLockCount < activeLockLimit
    }

    func configure() async {
        if Purchases.isConfigured {
            isConfigured = true
            beginCustomerInfoUpdates()
            await refreshCustomerInfo()
            await refreshOfferings()
            return
        }

        guard let apiKey = RevenueCatConfig.publicAPIKey else {
            lastErrorMessage = RevenueCatConfig.missingConfigurationMessage
            return
        }

        guard !RevenueCatConfig.isUsingSecretKey else {
            lastErrorMessage = RevenueCatConfig.secretKeyMessage
            return
        }

        #if !DEBUG
        guard !RevenueCatConfig.isUsingTestStoreKey else {
            lastErrorMessage = RevenueCatConfig.testStoreReleaseMessage
            return
        }
        #endif

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
        lastErrorMessage = nil

        beginCustomerInfoUpdates()
        await refreshCustomerInfo()
        await refreshOfferings()
    }

    func refreshCustomerInfo() async {
        guard isConfigured else { return }

        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            update(with: customerInfo)
        } catch {
            lastErrorMessage = "Could not refresh purchase status. Please try again."
        }
    }

    func refreshOfferings() async {
        guard isConfigured else { return }

        do {
            let offerings = try await Purchases.shared.offerings()
            currentOfferingIdentifier = offerings.current?.identifier
            if offerings.current == nil {
                lastErrorMessage = "RevenueCat is connected, but no current Offering is configured."
            } else {
                lastErrorMessage = nil
            }
        } catch {
            lastErrorMessage = "Could not load subscription options. Please try again."
        }
    }

    func restorePurchases() async -> Bool {
        guard isConfigured else {
            lastErrorMessage = RevenueCatConfig.missingConfigurationMessage
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            update(with: customerInfo)
            return isPro
        } catch {
            lastErrorMessage = "Could not restore purchases. Please try again."
            return false
        }
    }

    func update(with customerInfo: CustomerInfo) {
        let hasPro = RevenueCatConfig.entitlementIdentifiers.contains { identifier in
            customerInfo.entitlements[identifier]?.isActive == true
        }
        isPro = hasPro
        if hasPro {
            lastErrorMessage = nil
        }
    }

    private func beginCustomerInfoUpdates() {
        guard customerInfoTask == nil else { return }

        customerInfoTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                self?.update(with: customerInfo)
            }
        }
    }
}
