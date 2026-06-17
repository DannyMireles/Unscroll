import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @State private var pageIndex = 0

    private let pages = OnboardingPage.pages

    private var isLastPage: Bool {
        pageIndex == pages.count - 1
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.height < 620

            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, isActive: pageIndex == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(AppTheme.Motion.page, value: pageIndex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: isCompact ? 12 : 16) {
                    PageDots(count: pages.count, current: pageIndex)

                    if isLastPage {
                        permissionControls
                    } else {
                        HStack(spacing: 12) {
                            Button {
                                guard pageIndex > 0 else { return }
                                Haptics.softTap()
                                withAnimation(AppTheme.Motion.page) { pageIndex -= 1 }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(AppTheme.Typography.headline)
                                    .foregroundStyle(AppTheme.accentDeep)
                                    .frame(width: 54, height: 54)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                                            .stroke(Color.white.opacity(0.42), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .opacity(pageIndex > 0 ? 1 : 0)
                            .allowsHitTesting(pageIndex > 0)

                            PrimaryButton(title: "Continue") {
                                Haptics.softTap()
                                withAnimation(AppTheme.Motion.page) { pageIndex += 1 }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 8, isCompact ? 12 : 18))
                .frame(minHeight: isCompact ? 114 : 136, alignment: .top)
                .animation(AppTheme.Motion.reveal, value: isLastPage)
            }
            .padding(.top, isCompact ? 8 : 16)
        }
    }

    private var permissionControls: some View {
        VStack(spacing: 12) {
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
                title: permissionManager.isRequesting ? "Checking access..." : "Enable Screen Time",
                isDisabled: permissionManager.isRequesting
            ) {
                Task { await permissionManager.requestAuthorization() }
            }

            Text("Then set up your first lock.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingPage {
    let lead: String
    let emphasis: String
    let text: String

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            lead: "Train your mind.",
            emphasis: "Earn your scroll.",
            text: "Keep the apps. Add one clean pause."
        ),
        OnboardingPage(
            lead: "Start with",
            emphasis: "one app",
            text: "Choose one app. Set a limit."
        ),
        OnboardingPage(
            lead: "When the shield appears",
            emphasis: "Go To Activity",
            text: "Tap Go To Activity when shielded."
        ),
        OnboardingPage(
            lead: "Finish a quick challenge.",
            emphasis: "Scroll again.",
            text: "Finish a quick challenge. Scroll again."
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.height < 440
            let logoSize: CGFloat = isCompact ? 90 : 112
            let headlineHeight: CGFloat = isCompact ? 88 : 108
            let bodyHeight: CGFloat = isCompact ? 42 : 48

            VStack(spacing: isCompact ? 22 : 30) {
                Spacer(minLength: isCompact ? 8 : 22)

                BrandLogoView(size: logoSize)
                    .frame(width: logoSize, height: logoSize)
                    .flowAppear(delay: isActive ? 0.02 : 0)

                VStack(spacing: isCompact ? 9 : 12) {
                    FlowHeadlineText(
                        lead: page.lead,
                        emphasis: page.emphasis,
                        isActive: isActive,
                        isCompact: isCompact
                    )
                    .frame(maxWidth: .infinity, minHeight: headlineHeight, alignment: .center)

                    Text(page.text)
                        .font(isCompact ? AppTheme.Typography.subheadline : AppTheme.Typography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: bodyHeight, alignment: .top)
                        .opacity(isActive ? 1 : 0.74)
                        .animation(AppTheme.Motion.reveal, value: isActive)
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)

                Spacer(minLength: isCompact ? 12 : 34)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 28)
        }
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AppTheme.accent : Color.secondary.opacity(0.22))
                    .frame(width: index == current ? 22 : 7, height: 7)
                    .animation(AppTheme.Motion.selection, value: current)
            }
        }
        .accessibilityLabel("Onboarding page \(current + 1) of \(count)")
    }
}
