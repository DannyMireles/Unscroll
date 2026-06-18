import Combine
import FamilyControls
import Foundation

@MainActor
final class ScreenTimePermissionManager: ObservableObject {
    @Published private(set) var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var isRequesting = false
    @Published var permissionErrorMessage: String?

    private var authorizationObserver: AnyCancellable?

    private let defaults = UserDefaults(suiteName: AppConstants.appGroupIdentifier)
    private let authorizedKey = "screenTime.authorizedOnce"

    /// Persisted "the user has successfully authorized us at least once" flag.
    ///
    /// `AuthorizationCenter.shared.authorizationStatus` is unreliable for individual
    /// authorization — it frequently reports `.notDetermined` even when access is granted
    /// (visible as "on" in Settings). Relying on it kicked authorized users back to the
    /// onboarding screen on every relaunch. We trust this flag instead, and only clear it
    /// when the system explicitly reports `.denied`.
    private var authorizedOnce: Bool {
        get { defaults?.bool(forKey: authorizedKey) ?? false }
        set { defaults?.set(newValue, forKey: authorizedKey) }
    }

    init() {
        if status == .approved {
            authorizedOnce = true
        }
        authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
            .sink { [weak self] newStatus in
                Task { @MainActor in
                    self?.apply(status: newStatus)
                }
            }
    }

    var isAuthorized: Bool {
        status == .approved || authorizedOnce
    }

    var canEnterApp: Bool {
        isAuthorized
    }

    var statusLabel: String {
        if isAuthorized { return "Allowed" }
        switch status {
        case .denied:
            return "Not allowed"
        default:
            return "Not set up yet"
        }
    }

    func refreshStatus(reason: String = "manual") async {
        apply(status: AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAuthorization() async {
        guard !isRequesting else { return }

        isRequesting = true
        permissionErrorMessage = nil
        defer { isRequesting = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            // A non-throwing return means the system granted access — it throws on
            // cancel/failure. Persist that and trust it; the cached status property can
            // lag (or never update) after a (re)install.
            authorizedOnce = true
            apply(status: .approved)
        } catch {
            apply(status: AuthorizationCenter.shared.authorizationStatus)
            if !isAuthorized {
                permissionErrorMessage = message(for: error)
            }
        }
    }

    private func apply(status newStatus: AuthorizationStatus) {
        switch newStatus {
        case .approved:
            status = .approved
            authorizedOnce = true
            permissionErrorMessage = nil
        case .denied:
            // Explicit denial is the only signal we trust to revoke access.
            status = .denied
            authorizedOnce = false
        default:
            // `.notDetermined` (and any future cases) are unreliable for individual
            // authorization, so never use them to downgrade a user we've seen approved.
            if !authorizedOnce {
                status = newStatus
            }
        }
    }

    /// Actionable message for the most common failure — a leftover authorization from a
    /// previous install. We never tell the user access is permanently "unavailable".
    private var recoveryMessage: String {
        "Screen Time didn't finish approving access. If you recently reinstalled Cuewell, restart your device (or turn Screen Time off and back on in Settings › Screen Time), then tap Enable Screen Time again."
    }

    private func message(for error: Error) -> String {
        let nsError = error as NSError
        let description = nsError.localizedDescription.lowercased()

        if description.contains("passcode") {
            return "Set a device passcode in Settings, then tap Enable Screen Time again."
        }

        if description.contains("cancel") {
            return "That request was canceled. Tap Enable Screen Time to try again."
        }

        if description.contains("network") || description.contains("internet") || description.contains("connection") {
            return "Screen Time couldn't reach Apple's servers. Check your connection, then tap Enable Screen Time again."
        }

        if description.contains("account") || description.contains("icloud") {
            return "Make sure you're signed in to iCloud and Screen Time is turned on in Settings, then tap Enable Screen Time again."
        }

        return recoveryMessage
    }
}
