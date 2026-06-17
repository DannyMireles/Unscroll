import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        recordIdentity(application)
        return makeConfiguration(application: application)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        recordIdentity(application)
        return makeConfiguration(application: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    /// `bundleIdentifier` and `localizedDisplayName` are only readable inside this
    /// extension. Persist whatever iOS exposes so the main app can resolve the launch
    /// target automatically, without asking the user to name the app.
    private func recordIdentity(_ application: Application) {
        NSLog(
            "🧾 Unscroll shield identity token=%@ bundle=%@ name=%@",
            application.token == nil ? "nil" : "present",
            application.bundleIdentifier ?? "nil",
            application.localizedDisplayName ?? "nil"
        )
        guard let token = application.token else { return }
        AppIdentityStore.record(
            token: token,
            bundleID: application.bundleIdentifier,
            displayName: application.localizedDisplayName
        )
    }

    private func makeConfiguration(application: Application? = nil) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.90, green: 0.95, blue: 0.93, alpha: 0.82),
            icon: UIImage(systemName: "hand.raised.fill"),
            title: ShieldConfiguration.Label(
                text: "Your limit is active",
                color: UIColor.label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Tap Go To Activity. We'll send a notification that opens your Unscroll activity.",
                color: UIColor.secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go To Activity",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.33, green: 0.55, blue: 0.52, alpha: 1),
            secondaryButtonLabel: nil
        )
    }
}
