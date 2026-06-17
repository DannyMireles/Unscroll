import SwiftUI

struct UnlockFlowView: View {
    let lock: AppLock
    let onComplete: () -> Void
    @State private var resolvedMethod: UnlockMethod

    init(lock: AppLock, onComplete: @escaping () -> Void) {
        self.lock = lock
        self.onComplete = onComplete
        _resolvedMethod = State(initialValue: lock.unlockMethod.resolvedForUnlock())
    }

    var body: some View {
        ZStack {
            AppBackground()

            switch resolvedMethod {
            case .mentalMath:
                MathUnlockView(lock: lock, onComplete: onComplete)
            case .patternMemory:
                PatternMemoryUnlockView(lock: lock, onComplete: onComplete)
            case .breathing:
                BreathingUnlockView(lock: lock, onComplete: onComplete)
            case .reflect:
                ReflectUnlockView(lock: lock, onComplete: onComplete)
            case .random:
                MathUnlockView(lock: lock, onComplete: onComplete)
            }
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
