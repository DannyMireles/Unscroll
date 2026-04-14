import SwiftUI

struct RootView: View {
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @EnvironmentObject private var unlockCoordinator: UnlockCoordinator
    @State private var showSuccessAlert = false
    @State private var grantedMinutes = 0
    private let logPrefix = "[UnscrollDebug][RootView]"

    private func log(_ message: String) {
        NSLog("\(logPrefix) \(message)")
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
        .sheet(item: $unlockCoordinator.activeLock) { lock in
            UnlockFlowView(lock: lock) {
                Task {
                    let granted = await unlockCoordinator.completeUnlock(for: lock)
                    grantedMinutes = granted
                    Haptics.celebrationDing()
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        showSuccessAlert = true
                    }
                }
            }
            .interactiveDismissDisabled()
        }
        // Re-check for a pending unlock once the view hierarchy is fully mounted.
        // SwiftUI can silently drop a sheet that is set before the first render cycle
        // completes; deferring one tick via .task guarantees the sheet binding is live.
        .task {
            await Task.yield()
            log("initial .task fired; consumePendingUnlock")
            unlockCoordinator.consumePendingUnlock()
        }
        .onChange(of: unlockCoordinator.activeLock?.id) { lockID in
            log("activeLock changed -> \(lockID?.uuidString ?? "nil")")
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSuccessOverlay()
                }

            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(12)
                    .background(AppTheme.accent.opacity(0.12), in: Circle())

                Text("Great job!")
                    .font(.system(.title2, design: .rounded).weight(.semibold))

                Text("You unlocked \(grantedMinutes) minute\(grantedMinutes == 1 ? "" : "s"). Nice intentional choice.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(title: "Continue") {
                    dismissSuccessOverlay()
                }
            }
            .glassCard()
            .padding(.horizontal, 28)
        }
    }

    private func dismissSuccessOverlay() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showSuccessAlert = false
        }
    }
}
