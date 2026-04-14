import Combine
import FamilyControls
import Foundation

@MainActor
final class ScreenTimePermissionManager: ObservableObject {
    @Published private(set) var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published private(set) var isRequesting = false
    @Published var permissionErrorMessage: String?

    private var authorizationObserver: AnyCancellable?
    private var authorizationRequestErrorMessage: String?

    init() {
        authorizationObserver = AuthorizationCenter.shared.$authorizationStatus
            .sink { [weak self] newStatus in
                Task { @MainActor in
                    self?.apply(status: newStatus)
                }
            }
    }

    var isAuthorized: Bool {
        status == .approved
    }

    var canEnterApp: Bool {
        isAuthorized
    }

    var statusLabel: String {
        switch status {
        case .approved:
            return "Allowed"
        case .denied:
            return "Not allowed"
        case .notDetermined:
            return "Waiting for approval"
        @unknown default:
            return "Unknown"
        }
    }

    func refreshStatus(reason: String = "manual") async {
        apply(status: AuthorizationCenter.shared.authorizationStatus)
    }

    func requestAuthorization() async {
        guard !isRequesting else { return }

        isRequesting = true
        permissionErrorMessage = nil
        authorizationRequestErrorMessage = nil

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await refreshStatusUntilSettled()
        } catch {
            authorizationRequestErrorMessage = message(forAuthorizationError: error)
            await refreshStatusUntilSettled()
        }

        updateMessageForCurrentStatus()
        isRequesting = false
    }

    private func refreshStatusUntilSettled() async {
        for _ in 1...10 {
            apply(status: AuthorizationCenter.shared.authorizationStatus)

            if status == .approved || status == .denied {
                return
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func apply(status newStatus: AuthorizationStatus) {
        status = newStatus

        if newStatus == .approved {
            permissionErrorMessage = nil
        }
    }

    private func updateMessageForCurrentStatus() {
        if let authorizationRequestErrorMessage {
            permissionErrorMessage = authorizationRequestErrorMessage
            return
        }

        switch status {
        case .approved:
            permissionErrorMessage = nil
        case .denied:
            permissionErrorMessage = "Screen Time access is off for Unscroll. Enable access to continue."
        case .notDetermined:
            permissionErrorMessage = "Screen Time has not approved access yet. Make sure Screen Time is turned on for this device, then try again."
        @unknown default:
            permissionErrorMessage = "Screen Time access is unavailable on this device right now."
        }
    }

    private func message(forAuthorizationError error: Error) -> String {
        let nsError = error as NSError

        if nsError.localizedDescription.localizedCaseInsensitiveContains("device passcode") {
            return "A device passcode is required before Screen Time access can be granted."
        }

        return "Screen Time could not grant access: \(nsError.localizedDescription)"
    }
}
