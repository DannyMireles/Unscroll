import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @EnvironmentObject private var unlockCoordinator: UnlockCoordinator
    @State private var showSuccessAlert = false
    @State private var grantedMinutes = 0
    @State private var completedLock: AppLock?

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
                    completedLock = lock
                    Haptics.celebrationDing()
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        showSuccessAlert = true
                    }
                }
            }
            .interactiveDismissDisabled()
        }
        .task {
            await Task.yield()
            unlockCoordinator.consumePendingUnlock()
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

                if let lock = completedLock {
                    openAppButton(for: lock)
                }

                PrimaryButton(title: "Continue") {
                    dismissSuccessOverlay()
                }
            }
            .glassCard()
            .padding(.horizontal, 28)
        }
    }

    private func openAppButton(for lock: AppLock) -> some View {
        Button {
            dismissSuccessOverlay()
            AppLaunchHelper.openTargetApp(for: lock)
        } label: {
            HStack(spacing: 6) {
                Text("Take Me to \(lock.appDisplayName)")
                Image(systemName: "arrow.up.right")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
        }
        .buttonStyle(.plain)
    }

    private func dismissSuccessOverlay() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            showSuccessAlert = false
        }
    }
}
