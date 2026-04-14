import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 14) {
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(color: AppTheme.softShadow, radius: 16, x: 0, y: 10)

                    Text("Take a breath before jumping back in.")
                        .font(.system(.largeTitle, design: .rounded).weight(.light))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Unscroll uses Screen Time to add a small intentional pause after your chosen daily limit.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 28)

                VStack(alignment: .leading, spacing: 14) {
                    OnboardingRow(icon: "lock.shield", title: "Local only", text: "Your locks and prompts stay on this device.")
                    OnboardingRow(icon: "timer", title: "Daily limits", text: "Choose apps or categories and the total time you want for each day.")
                    OnboardingRow(icon: "sparkles", title: "Intentional unlocks", text: "Complete one brief unlock to continue.")
                }
                .glassCard()
                .padding(.horizontal, 20)

                Text("Screen Time: \(permissionManager.statusLabel)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                if let error = permissionManager.permissionErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 24)
                }

                PrimaryButton(title: permissionManager.isRequesting ? "Checking Access..." : "Enable Screen Time Access",
                              isDisabled: permissionManager.isRequesting) {
                    Task { await permissionManager.requestAuthorization() }
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.medium))
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
