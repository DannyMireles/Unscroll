import SwiftUI

struct UnlockFlowView: View {
    let lock: AppLock
    let onComplete: () -> Void
    @State private var chosenMethod: UnlockMethod?

    init(lock: AppLock, onComplete: @escaping () -> Void) {
        self.lock = lock
        self.onComplete = onComplete
        // Skip the chooser when there's only one activity to do.
        _chosenMethod = State(initialValue: lock.unlockMethods.count == 1 ? lock.unlockMethods.first : nil)
    }

    /// The chooser is only meaningful when there's more than one activity to pick from.
    private var canChooseAnother: Bool {
        lock.unlockMethods.count > 1
    }

    var body: some View {
        ZStack {
            AppBackground()

            if let method = chosenMethod {
                activityView(for: method)
                    .transition(.opacity)
            } else {
                ActivityChooserView(lock: lock) { picked in
                    withAnimation(AppTheme.Motion.page) { chosenMethod = picked }
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if chosenMethod != nil, canChooseAnother {
                Button {
                    Haptics.softTap()
                    withAnimation(AppTheme.Motion.page) { chosenMethod = nil }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentOnChrome)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().stroke(AppTheme.chromeStroke, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .padding(.leading, 18)
                .padding(.top, 8)
                .accessibilityLabel("Choose a different activity")
            }
        }
    }

    @ViewBuilder
    private func activityView(for method: UnlockMethod) -> some View {
        switch method {
        case .read:
            ReadUnlockView(lock: lock, onComplete: onComplete)
        case .mindful:
            MindfulnessUnlockView(lock: lock, onComplete: onComplete)
        case .outside:
            OutsideUnlockView(lock: lock, onComplete: onComplete)
        case .pattern:
            PatternMemoryUnlockView(lock: lock, onComplete: onComplete)
        }
    }
}

struct UnlockHeader: View {
    let lock: AppLock
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            AppTokenIconView(lock: lock)
                .scaleEffect(1.1)
                .padding(.bottom, 2)
            Text(title)
                .font(AppTheme.Typography.title)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 18)
    }
}

struct UnlockScreenScaffold<Content: View>: View {
    let lock: AppLock
    let title: String
    let subtitle: String
    var screenSpacing: CGFloat = 26
    var cardPadding: CGFloat = 18
    private let content: Content

    init(
        lock: AppLock,
        title: String,
        subtitle: String,
        screenSpacing: CGFloat = 26,
        cardPadding: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.lock = lock
        self.title = title
        self.subtitle = subtitle
        self.screenSpacing = screenSpacing
        self.cardPadding = cardPadding
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: screenSpacing) {
                Spacer(minLength: 12)

                UnlockHeader(lock: lock, title: title, subtitle: subtitle)
                    .flowItem(0)

                content
                    .glassCard(padding: cardPadding)
                    .padding(.horizontal, 20)
                    .flowItem(1)

                Spacer(minLength: 24)
            }
        }
        .padding(.vertical, 24)
    }
}
