import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    BrandLogoView(size: 96)

                    VStack(spacing: 10) {
                        Text(AppTheme.tagline)
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(AppTheme.subtagline)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                VStack(spacing: 12) {
                    OnboardingRow(
                        icon: "brain.head.profile",
                        title: "Earn it with your mind",
                        text: "Past your daily limit, a quick mental challenge stands between you and the app."
                    )
                    OnboardingRow(
                        icon: "infinity",
                        title: "Keep what you love",
                        text: "Nothing is banned. You simply pause and sharpen up before diving back in."
                    )
                    OnboardingRow(
                        icon: "lock.shield",
                        title: "Private by design",
                        text: "Your locks and progress never leave this device."
                    )
                }

                VStack(spacing: 14) {
                    Text("Screen Time access: \(permissionManager.statusLabel)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    if let error = permissionManager.permissionErrorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }

                    PrimaryButton(
                        title: permissionManager.isRequesting ? "Checking access…" : "Enable Screen Time",
                        isDisabled: permissionManager.isRequesting
                    ) {
                        Task { await permissionManager.requestAuthorization() }
                    }

                    Text("Unscroll uses Apple Screen Time to apply your limits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 28)
        }
    }
}

private struct OnboardingRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.accentSoft)
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 16)
    }
}
