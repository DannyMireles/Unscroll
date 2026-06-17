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
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: pageIndex)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: isCompact ? 12 : 16) {
                    PageDots(count: pages.count, current: pageIndex)

                    if isLastPage {
                        permissionControls
                    } else {
                        HStack(spacing: 12) {
                            if pageIndex > 0 {
                                Button {
                                    Haptics.softTap()
                                    withAnimation(.easeInOut(duration: 0.25)) { pageIndex -= 1 }
                                } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppTheme.accentDeep)
                                        .frame(width: 54, height: 54)
                                        .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }

                            PrimaryButton(title: "Continue") {
                                Haptics.softTap()
                                withAnimation(.easeInOut(duration: 0.25)) { pageIndex += 1 }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom + 8, isCompact ? 12 : 18))
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
    let title: String
    let text: String

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Train your mind. Earn your scroll.",
            text: "Keep the apps. Add one clean pause."
        ),
        OnboardingPage(
            title: "Start with one app",
            text: "Choose one app. Set a limit."
        ),
        OnboardingPage(
            title: "When the shield appears",
            text: "Tap Go To Activity when shielded."
        ),
        OnboardingPage(
            title: "Earn the next window",
            text: "Finish a quick challenge. Scroll again."
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.height < 440

            VStack(spacing: isCompact ? 22 : 30) {
                Spacer(minLength: isCompact ? 8 : 22)

                BrandLogoView(size: isCompact ? 90 : 112)

                VStack(spacing: isCompact ? 9 : 12) {
                    Text(page.title)
                        .font(.system(isCompact ? .title2 : .title, design: .rounded).weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.text)
                        .font(isCompact ? .callout : .body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

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
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: current)
            }
        }
        .accessibilityLabel("Onboarding page \(current + 1) of \(count)")
    }
}
