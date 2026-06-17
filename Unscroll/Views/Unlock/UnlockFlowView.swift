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
                .font(.system(.title, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .padding(.horizontal, 18)
    }
}
