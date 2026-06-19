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
    @State private var showSuccessConfetti = false
    @State private var successConfettiBurstID = 0
    @State private var grantedMinutes = 0
    @State private var completedLock: AppLock?
    @State private var unavailableLock: AppLock?
    @State private var linkSetupLock: AppLock?
    @State private var isPreparingOpenApp = false
    @State private var identityReportRefreshID = 0

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
                    .transition(.flowPopup)
                    .zIndex(10)
            }

            if let linkSetupLock {
                AppLinkSetupView(
                    lock: linkSetupLock,
                    onLinked: retryOpenAfterLink,
                    onCancel: { dismissLinkSetup() }
                )
                .id(linkSetupLock.id)
                .transition(.flowPopup)
                .zIndex(11)
            }

            if let unavailableLock {
                GlassNoticeOverlay(
                    title: unavailableTitle(for: unavailableLock),
                    message: unavailableMessage(for: unavailableLock)
                ) {
                    withAnimation(AppTheme.Motion.popup) {
                        self.unavailableLock = nil
                    }
                }
                .transition(.flowPopup)
                .zIndex(12)
            }
        }
        .dismissKeyboardOnBackgroundTap()
        .animation(AppTheme.Motion.popup, value: showSuccessAlert)
        .animation(AppTheme.Motion.popup, value: linkSetupLock?.id)
        .animation(AppTheme.Motion.popup, value: unavailableLock?.id)
        .sheet(item: $unlockCoordinator.activeLock) { lock in
            UnlockFlowView(lock: lock) {
                Task {
                    let granted = await unlockCoordinator.completeUnlock(for: lock)
                    await lockStore.load()
                    lockStore.reconcileDisplayNames()
                    grantedMinutes = granted
                    completedLock = lockStore.locks.first(where: { $0.id == lock.id }) ?? lock
                    Haptics.celebrationDing()
                    withAnimation(AppTheme.Motion.popup) {
                        showSuccessAlert = true
                    }
                    triggerSuccessConfetti()
                }
            }
            .interactiveDismissDisabled()
            .flowSheetPresentation(dragIndicator: .hidden)
        }
        .preferredColorScheme(preferredScheme)
        .task {
            await Task.yield()
            unlockCoordinator.consumePendingUnlock()
        }
        .task(id: lockStore.locks) {
            guard !lockStore.locks.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            lockStore.reconcileDisplayNames()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cuewellRefreshIdentityReport)) { _ in
            // Remount the hidden identity readers, then pick up anything Screen Time exposed.
            identityReportRefreshID += 1
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                lockStore.reconcileDisplayNames()
            }
        }
    }

    private var successOverlay: some View {
        ZStack {
            ModalBackdrop(onTap: dismissSuccessOverlay)

            if showSuccessConfetti {
                ConfettiView(pieceCount: 64, start: .point(UnitPoint(x: 0.5, y: 0.38)))
                    .id(successConfettiBurstID)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            ModalCard {
                VStack(spacing: 16) {
                    Button {
                        Haptics.celebrationDing()
                        triggerSuccessConfetti()
                    } label: {
                        BrandLogoView(size: 76)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Celebrate")

                    VStack(spacing: 4) {
                        Text("Great job")
                            .font(.headline.weight(.semibold))
                        Text(successMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 10) {
                        if let lock = completedLock, lock.canDeepLink {
                            openAppButton(for: lock)
                        }

                        ModalSecondaryButton(title: "Done") {
                            dismissSuccessOverlay()
                        }
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if let lock = completedLock,
                   lock.canDeepLink,
                   let token = lock.selection.applicationTokens.first {
                    ZStack(alignment: .topLeading) {
                        ApplicationTokenNameCapture(token: token) { token, name in
                            applyCapturedAppName(name, token: token, for: lock)
                        }
                        .id(token.hashValue)
                        .frame(width: 260, height: 44)

                        AppIdentityReportCapture(selection: lock.selection)
                    }
                    .id("\(token.hashValue)-\(identityReportRefreshID)")
                }
            }
        }
    }

    private var successMessage: String {
        if let completedLock, !completedLock.canDeepLink {
            if completedLock.unlockRewardMode == .unlockedRestOfDay {
                return "Your apps are unlocked for today."
            }
            return "Your apps are unlocked for \(grantedMinutes) more minute\(grantedMinutes == 1 ? "" : "s") of use."
        }

        if completedLock?.unlockRewardMode == .unlockedRestOfDay {
            return "Unlocked for the rest of today."
        }
        return "\(grantedMinutes) more minute\(grantedMinutes == 1 ? "" : "s") of use unlocked."
    }

    private func openAppButton(for lock: AppLock) -> some View {
        ModalPrimaryButton(
            title: isPreparingOpenApp ? "Linking..." : "Open App",
            systemImage: "arrow.up.right",
            isDisabled: isPreparingOpenApp
        ) {
            isPreparingOpenApp = true
            Task {
                await lockStore.load()
                lockStore.reconcileDisplayNames()
                openWhenReady(lock)
            }
        }
    }

    private func openWhenReady(_ lock: AppLock) {
        let currentLock = lockStore.locks.first(where: { $0.id == lock.id }) ?? lock
        guard currentLock.canDeepLink else {
            isPreparingOpenApp = false
            dismissSuccessOverlay()
            handleOpenUnavailable(for: currentLock)
            return
        }

        isPreparingOpenApp = true
        AppLaunchHelper.openTargetApp(for: currentLock) {
            DispatchQueue.main.async {
                isPreparingOpenApp = false
                dismissSuccessOverlay()
                handleOpenUnavailable(for: currentLock)
            }
        }
    }

    private func applyCapturedAppName(_ name: String, token: ApplicationToken, for lock: AppLock) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !LockStore.isGenericDisplayName(trimmed) else { return }

        AppIdentityStore.record(token: token, bundleID: nil, displayName: trimmed)
        let resolvedScheme = LockStore.launchSchemes(forName: trimmed).first
            ?? LockStore.normalizeScheme(lock.launchURLScheme)

        Task {
            var updated = lockStore.locks.first(where: { $0.id == lock.id }) ?? lock
            guard updated.appDisplayName != trimmed || updated.launchURLScheme != resolvedScheme else { return }
            updated.appDisplayName = trimmed
            updated.launchURLScheme = resolvedScheme
            await lockStore.update(updated)
            if completedLock?.id == lock.id {
                completedLock = updated
            }
            NSLog("🔗 Cuewell: captured unlock app label '%@' scheme=%@", trimmed, resolvedScheme ?? "")
            await lockStore.resolveAndApplyAppStoreIdentity(lockID: updated.id, token: token, name: trimmed)
            if completedLock?.id == lock.id,
               let refreshed = lockStore.locks.first(where: { $0.id == lock.id }) {
                completedLock = refreshed
            }
        }
    }

    private func dismissSuccessOverlay() {
        withAnimation(AppTheme.Motion.popup) {
            showSuccessAlert = false
            showSuccessConfetti = false
            isPreparingOpenApp = false
        }
    }

    private func triggerSuccessConfetti() {
        successConfettiBurstID += 1
        withAnimation(.easeIn(duration: 0.12)) {
            showSuccessConfetti = true
        }

        let currentID = successConfettiBurstID
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard currentID == successConfettiBurstID else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                showSuccessConfetti = false
            }
        }
    }

    private func handleOpenUnavailable(for lock: AppLock) {
        withAnimation(AppTheme.Motion.popup) {
            if lock.canDeepLink {
                linkSetupLock = lock
            } else {
                unavailableLock = lock
            }
        }
    }

    private func retryOpenAfterLink(_ lock: AppLock) {
        dismissLinkSetup()
        completedLock = lock
        isPreparingOpenApp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            openWhenReady(lock)
        }
    }

    private func dismissLinkSetup() {
        withAnimation(AppTheme.Motion.popup) {
            linkSetupLock = nil
        }
    }

    private func displayNameForAlert(_ lock: AppLock) -> String {
        LockStore.isGenericDisplayName(lock.appDisplayName) ? "the app" : lock.appDisplayName
    }

    private func unavailableTitle(for lock: AppLock) -> String {
        lock.canDeepLink ? "Couldn't open \(displayNameForAlert(lock))" : "Apps unlocked"
    }

    private func unavailableMessage(for lock: AppLock) -> String {
        if lock.canDeepLink {
            return "This link needs one quick setup step."
        }
        return "Your apps are unlocked. Open any of them from your Home Screen."
    }
}

/// A full-screen blurred + dimmed backdrop for modal popups. Tapping anywhere on it
/// triggers `onTap` (used to dismiss). Fills the whole screen regardless of where the
/// hosting overlay is attached.
struct ModalBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onTap: (() -> Void)? = nil
    @State private var isVisible = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(isVisible ? 1 : 0)
            AppTheme.modalScrim
                .opacity(isVisible ? 1 : 0)
        }
        .animation(reduceMotion ? AppTheme.Motion.quick : AppTheme.Motion.backdrop, value: isVisible)
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .onAppear { isVisible = true }
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
            .font(AppTheme.Typography.headline)
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
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.accentOnChrome)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                        .stroke(AppTheme.chromeStroke, lineWidth: 1)
                }
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
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.30))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.60), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.18), radius: 30, x: 0, y: 18)
            .padding(.horizontal, 24)
    }
}

struct GlassNoticeOverlay: View {
    let title: String
    let message: String
    var buttonTitle = "OK"
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            ModalBackdrop(onTap: onDismiss)

            ModalCard {
                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.accentOnChrome)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().stroke(Color.white.opacity(0.42), lineWidth: 1) }
                        .flowItem(0)

                    VStack(spacing: 5) {
                        Text(title)
                            .font(AppTheme.Typography.headline)
                            .multilineTextAlignment(.center)
                        Text(message)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .flowItem(1)

                    ModalPrimaryButton(title: buttonTitle, action: onDismiss)
                        .flowItem(2)
                }
            }
        }
    }
}

struct AppLinkSetupView: View {
    @EnvironmentObject private var lockStore: LockStore
    @FocusState private var isNameFieldFocused: Bool

    let lock: AppLock
    let onLinked: (AppLock) -> Void
    let onCancel: () -> Void

    @State private var appName: String
    @State private var isResolving = false
    @State private var errorMessage: String?

    private let chipColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]

    init(
        lock: AppLock,
        onLinked: @escaping (AppLock) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.lock = lock
        self.onLinked = onLinked
        self.onCancel = onCancel
        _appName = State(initialValue: Self.initialAppName(for: lock))
    }

    var body: some View {
        ZStack {
            ModalBackdrop(onTap: isResolving ? nil : onCancel)

            ModalCard(maxWidth: 370) {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "link.badge.plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppTheme.accentOnChrome)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay { Circle().stroke(Color.white.opacity(0.34), lineWidth: 1) }

                        VStack(spacing: 4) {
                            Text("Link this app")
                                .font(AppTheme.Typography.headline)
                            Text("Type the App Store name once. We'll remember it.")
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .flowItem(0)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("TikTok", text: $appName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($isNameFieldFocused)
                            .onSubmit(resolveAppLink)
                            .font(AppTheme.Typography.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                                    .stroke(AppTheme.accent.opacity(0.28), lineWidth: 1)
                            }

                        LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 8) {
                            ForEach(Array(LockStore.commonAppNames.prefix(12)), id: \.self) { name in
                                Button {
                                    Haptics.softTap()
                                    appName = name
                                    resolveAppLink()
                                } label: {
                                    Text(name)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.82)
                                        .foregroundStyle(AppTheme.accentOnChrome)
                                        .frame(maxWidth: .infinity, minHeight: 34)
                                        .padding(.horizontal, 8)
                                        .background(AppTheme.accentSoft, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(isResolving)
                            }
                        }
                    }
                    .flowItem(1)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppTheme.Typography.footnoteMedium)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .offset(y: 6)))
                    }

                    HStack(spacing: 10) {
                        ModalSecondaryButton(title: "Not Now") {
                            onCancel()
                        }
                        .disabled(isResolving)

                        ModalPrimaryButton(
                            title: isResolving ? "Setting..." : "Set Link",
                            systemImage: "link",
                            isDisabled: isResolving || appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            resolveAppLink()
                        }
                    }
                    .flowItem(2)
                }
            }
        }
        .animation(AppTheme.Motion.reveal, value: errorMessage)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isNameFieldFocused = true
            }
        }
    }

    private static func initialAppName(for lock: AppLock) -> String {
        LockStore.isGenericDisplayName(lock.appDisplayName) ? "" : lock.appDisplayName
    }

    private func resolveAppLink() {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isResolving else { return }
        guard lock.canDeepLink, let token = lock.selection.applicationTokens.first else {
            errorMessage = "This lock has more than one app."
            Haptics.retry()
            return
        }

        isResolving = true
        errorMessage = nil

        Task {
            let updated = await lockStore.resolveAndApplyAppStoreIdentity(
                lockID: lock.id,
                token: token,
                name: trimmed
            )

            await MainActor.run {
                isResolving = false
                guard let updated else {
                    errorMessage = "No match found. Try the App Store name."
                    Haptics.retry()
                    return
                }

                Haptics.success()
                onLinked(updated)
            }
        }
    }
}

extension Notification.Name {
    static let cuewellRefreshIdentityReport = Notification.Name("com.selerim.cuewell.refreshIdentityReport")
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
