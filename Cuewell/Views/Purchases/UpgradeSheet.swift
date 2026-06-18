import RevenueCat
import RevenueCatUI
import SwiftUI

struct UpgradeSheet: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var showRevenueCatPaywall = false
    @State private var showCustomerCenter = false
    @State private var restoreMessage: String?

    var body: some View {
        Group {
            if purchaseManager.isConfigured {
                // Straight to the RevenueCat paywall — no extra intro step, and no navigation bar
                // pushing the paywall down. RevenueCat's own close button dismisses it.
                PaywallView(displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        purchaseManager.update(with: customerInfo)
                        Haptics.success()
                        dismiss()
                    }
                    .onRestoreCompleted { customerInfo in
                        purchaseManager.update(with: customerInfo)
                        if purchaseManager.isPro {
                            Haptics.success()
                            dismiss()
                        }
                    }
                    .task {
                        await purchaseManager.refreshOfferings()
                    }
            } else {
                setupFallback
            }
        }
    }

    /// Shown only when RevenueCat isn't configured yet — keeps the setup notice and the
    /// close button. Once a key + offering exist, we go straight to the paywall above.
    private var setupFallback: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                intro
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.softTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accentOnChrome)
                    .accessibilityLabel("Close")
                }
            }
            .presentCustomerCenter(
                isPresented: $showCustomerCenter,
                restoreCompleted: { customerInfo in
                    purchaseManager.update(with: customerInfo)
                    if purchaseManager.isPro {
                        Haptics.success()
                    }
                },
                restoreFailed: { error in
                    restoreMessage = error.localizedDescription
                },
                onDismiss: {
                    showCustomerCenter = false
                    Task { await purchaseManager.refreshCustomerInfo() }
                }
            )
        }
    }

    private var intro: some View {
        ScrollView {
            VStack(spacing: 18) {
                BrandLogoView(size: 88)
                    .flowItem(0)

                VStack(spacing: 7) {
                    Text("Add another lock")
                        .font(AppTheme.Typography.title2)
                        .multilineTextAlignment(.center)

                    Text("Your first lock stays free. Pro lets Cuewell protect every app that pulls you in.")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .flowItem(1)

                VStack(spacing: 10) {
                    UpgradeBenefitRow(systemImage: "lock.stack.fill", title: "Unlimited active locks", subtitle: "Protect every app and category without changing your flow.")
                    UpgradeBenefitRow(systemImage: "slider.horizontal.3", title: "Flexible plans", subtitle: "The options shown here come from RevenueCat, so offers can change without an app update.")
                    UpgradeBenefitRow(systemImage: "checkmark.shield.fill", title: "Private by design", subtitle: "Only RevenueCat purchase status is checked. Your lock details stay in Cuewell.")
                }
                .flowItem(2)

                if let setupMessage {
                    SetupNotice(message: setupMessage)
                        .flowItem(3)
                }

                VStack(spacing: 10) {
                    PrimaryButton(
                        title: purchaseManager.isConfigured ? "See Pro Options" : "Connect RevenueCat",
                        isDisabled: !purchaseManager.isConfigured
                    ) {
                        showRevenueCatPaywall = true
                    }

                    Button {
                        Task { await restorePurchases() }
                    } label: {
                        HStack(spacing: 8) {
                            if purchaseManager.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(purchaseManager.isLoading ? "Restoring..." : "Restore Purchases")
                        }
                        .font(AppTheme.Typography.headlineMedium)
                        .foregroundStyle(AppTheme.accentOnChrome)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                                .stroke(Color.white.opacity(0.40), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(purchaseManager.isLoading || !purchaseManager.isConfigured)

                    Button {
                        Haptics.softTap()
                        showCustomerCenter = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text("Manage Purchases")
                        }
                        .font(AppTheme.Typography.subheadlineMedium)
                        .foregroundStyle(AppTheme.accentOnChrome)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!purchaseManager.isConfigured)

                    Button {
                        Haptics.softTap()
                        dismiss()
                    } label: {
                        Text("Not now")
                            .font(AppTheme.Typography.subheadlineMedium)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .flowItem(4)

                if let restoreMessage {
                    Text(restoreMessage)
                        .font(AppTheme.Typography.footnoteMedium)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .flowItem(5)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
    }

    private var setupMessage: String? {
        if let message = purchaseManager.lastErrorMessage {
            return message
        }
        if !purchaseManager.isConfigured {
            return RevenueCatConfig.missingConfigurationMessage
        }
        return nil
    }

    private func restorePurchases() async {
        let restored = await purchaseManager.restorePurchases()
        if restored {
            Haptics.success()
            dismiss()
        } else {
            restoreMessage = purchaseManager.lastErrorMessage ?? "No active Pro purchase was found for this account."
        }
    }
}

private struct UpgradeBenefitRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.accentOnChrome)
                .frame(width: 38, height: 38)
                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppTheme.Typography.subheadlineMedium)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                .stroke(Color.white.opacity(0.38), lineWidth: 1)
        }
    }
}

private struct SetupNotice: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accentOnChrome)

            Text(message)
                .font(AppTheme.Typography.footnoteMedium)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: AppTheme.cornerSmall, style: .continuous))
    }
}
