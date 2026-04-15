import SwiftUI

struct LockCard: View {
    let lock: AppLock
    let onEdit: () -> Void
    let onPause: () -> Void
    let onDelete: () -> Void
    let onOpenApp: () -> Void

    var body: some View {
        let rewardText = lock.unlockRewardMode == .incrementalByLimit ? "Incremental time" : "Rest of day"

        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpenApp) {
                HStack(spacing: 14) {
                    AppTokenIconView(lock: lock)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(lock.appDisplayName)
                                .font(.headline.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.primary)

                            if lock.isPaused {
                                Text("Paused")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.16), in: Capsule())
                            }
                        }

                        Text("\(lock.limitLabel) daily - \(lock.unlockMethod.title) - \(rewardText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.accent.opacity(0.85))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(lock.appDisplayName)")

            HStack(spacing: 10) {
                LockActionButton(title: "Edit", systemImage: "slider.horizontal.3", action: onEdit)
                LockActionButton(title: lock.isPaused ? "Resume" : "Pause", systemImage: lock.isPaused ? "play.fill" : "pause.fill", action: onPause)
                LockActionButton(title: "Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
        }
        .glassCard()
    }
}

private struct LockActionButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : AppTheme.accentDeep)
    }
}
