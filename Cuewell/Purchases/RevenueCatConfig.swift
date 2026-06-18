import Foundation

enum RevenueCatConfig {
    static let entitlementIdentifier = "Cuewell Pro"
    static let legacyEntitlementIdentifier = "pro"
    static let entitlementIdentifiers = [entitlementIdentifier, legacyEntitlementIdentifier]

    private static let apiKeyInfoPlistKey = "RevenueCatAPIKey"

    static var publicAPIKey: String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: apiKeyInfoPlistKey) as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.hasPrefix("$("),
              !value.localizedCaseInsensitiveContains("YOUR_")
        else {
            return nil
        }

        return value
    }

    static var isUsingSecretKey: Bool {
        publicAPIKey?.hasPrefix("sk_") == true
    }

    static var isUsingTestStoreKey: Bool {
        publicAPIKey?.hasPrefix("test_") == true
    }

    static var missingConfigurationMessage: String {
        "RevenueCat is not connected yet. Add the public iOS SDK key to REVENUECAT_API_KEY to test purchases."
    }

    static var secretKeyMessage: String {
        "A RevenueCat secret key was provided. Secret keys must never ship in the app. Use the public iOS SDK key instead."
    }

    static var testStoreReleaseMessage: String {
        "A RevenueCat Test Store key is configured for a release build. Use the production public iOS SDK key before shipping."
    }
}
