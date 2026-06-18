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
            "🧾 Cuewell shield identity token=%@ bundle=%@ name=%@",
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
            backgroundColor: Self.backgroundColor,
            icon: UIImage(systemName: "pause.circle.fill"),
            title: ShieldConfiguration.Label(
                text: "Think before you unlock",
                color: Self.titleColor
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Start a quick Cuewell challenge to earn your next window.",
                color: Self.subtitleColor
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Start Activity",
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: Self.accentColor,
            secondaryButtonLabel: nil
        )
    }

    private static let accentColor = UIColor(red: 0.18, green: 0.46, blue: 0.40, alpha: 1)

    private static let backgroundColor = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.06, green: 0.09, blue: 0.09, alpha: 0.88)
        }
        return UIColor(red: 0.92, green: 0.96, blue: 0.94, alpha: 0.86)
    }

    private static let titleColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor(red: 0.08, green: 0.22, blue: 0.20, alpha: 1)
    }

    private static let subtitleColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.72)
            : UIColor(red: 0.24, green: 0.34, blue: 0.32, alpha: 0.78)
    }
}
