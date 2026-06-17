import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var lockStore: LockStore
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @EnvironmentObject private var unlockCoordinator: UnlockCoordinator
    @AppStorage("themePreference") private var themePreference = ThemePreference.system.rawValue
    @State private var showSuccessAlert = false
    @State private var grantedMinutes = 0
    @State private var completedLock: AppLock?
    @State private var unavailableAppName: String?

    private var preferredScheme: ColorScheme? {
        ThemePreference(rawValue: themePreference)?.colorScheme
    }

    var body: some View {
        ZStack {
            AppBackground()

            if permissionManager.canEnterApp {
                HomeView()
            } else {
                OnboardingView()
            }

            if showSuccessAlert {
                successOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(10)
            }
        }
        .dismissKeyboardOnBackgroundTap()
        .sheet(item: $unlockCoordinator.activeLock) { lock in
            UnlockFlowView(lock: lock) {
                Task {
                    let granted = await unlockCoordinator.completeUnlock(for: lock)
                    grantedMinutes = granted
                    completedLock = lock
                    Haptics.celebrationDing()
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        showSuccessAlert = true
                    }
                }
            }
            .interactiveDismissDisabled()
        }
        .preferredColorScheme(preferredScheme)
        .alert(
            "Couldn't open \(unavailableAppName ?? "the app")",
            isPresented: Binding(
                get: { unavailableAppName != nil },
                set: { if !$0 { unavailableAppName = nil } }
            )
        ) {
            Button("OK", role: .cancel) { unavailableAppName = nil }
        } message: {
            Text("You're all set — just open it from your Home Screen. We'll detect it automatically next time.")
        }
        .task {
            await Task.yield()
            unlockCoordinator.consumePendingUnlock()
        }
        .task(id: lockStore.locks) {
            guard !lockStore.locks.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            lockStore.reconcileDisplayNames()
        }
        .onReceive(NotificationCenter.default.publisher(for: .unscrollRefreshIdentityReport)) { _ in
            // After an open attempt, pick up any identity the Shield extension captured.
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                lockStore.reconcileDisplayNames()
            }
        }
    }

    private var successOverlay: some View {
        ZStack {
            ModalBackdrop(onTap: dismissSuccessOverlay)

            ModalCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.accent, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Great job")
                                .font(.headline.weight(.semibold))
                            Text(successMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 10) {
                        if let lock = completedLock {
                            openAppButton(for: lock)
                        }

                        ModalSecondaryButton(title: "Done") {
                            dismissSuccessOverlay()
                        }
                    }
                }
            }
        }
    }

    private var successMessage: String {
        if completedLock?.unlockRewardMode == .unlockedRestOfDay {
            return "Unlocked for the rest of today."
        }
        return "Unlocked \(grantedMinutes) minute\(grantedMinutes == 1 ? "" : "s")."
    }

    private func openAppButton(for lock: AppLock) -> some View {
        ModalPrimaryButton(title: "Open App", systemImage: "arrow.up.right") {
            dismissSuccessOverlay()
            let currentLock = lockStore.locks.first(where: { $0.id == lock.id }) ?? lock
            AppLaunchHelper.openTargetApp(for: currentLock) {
                handleOpenUnavailable(for: currentLock)
            }
        }
    }

    private func dismissSuccessOverlay() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showSuccessAlert = false
        }
    }

    private func handleOpenUnavailable(for lock: AppLock) {
        unavailableAppName = displayNameForAlert(lock)
    }

    private func displayNameForAlert(_ lock: AppLock) -> String {
        LockStore.isGenericDisplayName(lock.appDisplayName) ? "the app" : lock.appDisplayName
    }
}

/// A full-screen blurred + dimmed backdrop for modal popups. Tapping anywhere on it
/// triggers `onTap` (used to dismiss). Fills the whole screen regardless of where the
/// hosting overlay is attached.
struct ModalBackdrop: View {
    var onTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            Color.black.opacity(0.22)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

/// Primary action button for popups — matches the app's `PrimaryButton` (accent gradient,
/// `cornerMedium`, white text) so modals use the exact same button language as the app.
struct ModalPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            Group {
                if let systemImage {
                    Label(title, systemImage: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.headline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(isDisabled ? Color.secondary : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Group {
                    if isDisabled {
                        Color.secondary.opacity(0.18)
                    } else {
                        LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep], startPoint: .top, endPoint: .bottom)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            .shadow(color: isDisabled ? .clear : AppTheme.accent.opacity(0.28), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

/// Secondary popup button — the app's soft-accent chip style.
struct ModalSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.accentDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// A compact, centered glass card for modal popups. Caps its width so popups stay small
/// on every device and sizes its height to the content. Mirrors `GlassCard` styling so
/// popups visually match the rest of the app.
struct ModalCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    var maxWidth: CGFloat
    private let content: Content

    init(maxWidth: CGFloat = 330, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: maxWidth)
            .fixedSize(horizontal: false, vertical: true)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.45), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 26, x: 0, y: 14)
            .padding(.horizontal, 24)
    }
}

extension Notification.Name {
    static let unscrollRefreshIdentityReport = Notification.Name("com.selerim.unscroll.refreshIdentityReport")
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.install(in: uiView.window)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private var gesture: UITapGestureRecognizer?

        func install(in window: UIWindow?) {
            guard let window else { return }
            guard installedWindow !== window else { return }

            uninstall()

            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            window.addGestureRecognizer(gesture)

            self.gesture = gesture
            installedWindow = window
        }

        func uninstall() {
            if let gesture {
                gesture.view?.removeGestureRecognizer(gesture)
            }
            gesture = nil
            installedWindow = nil
        }

        @objc private func handleTap() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView {
                    return false
                }
                view = current.superview
            }
            return true
        }
    }
}

extension View {
    func dismissKeyboardOnBackgroundTap() -> some View {
        background(KeyboardDismissTapInstaller())
    }
}

/// A clean confirmation shown after a lock is created, and when an app can't be opened yet
/// (before its first limit). It shows the app's real icon + name and a short note. Opening
/// the specific app only becomes possible once the Shield has captured its identity — the
/// first time you go past your limit — so this popup never asks for any input.
struct LockReadyPopup: View {
    let lock: AppLock
    var message: String
    var buttonTitle: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            ModalBackdrop(onTap: onDismiss)

            ModalCard {
                VStack(spacing: 16) {
                    AppTokenIconView(lock: lock)
                        .scaleEffect(1.2)
                        .padding(.top, 4)

                    AppTokenTitleView(lock: lock)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)

                    ModalPrimaryButton(title: buttonTitle) {
                        onDismiss()
                    }
                }
            }
        }
    }
}
