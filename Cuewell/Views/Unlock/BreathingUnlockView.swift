import SwiftUI

struct BreathingUnlockView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let lock: AppLock
    let onComplete: () -> Void

    @State private var stepIndex = 0
    @State private var isExpanded = false
    @State private var completed = false

    private var currentStep: BreathingStep {
        BreathingEngine.steps[min(stepIndex, BreathingEngine.steps.count - 1)]
    }

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Take three deep breaths.",
            subtitle: "A quiet pause before continuing.",
            screenSpacing: 32
        ) {
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.14))
                        .frame(width: 220, height: 220)
                        .scaleEffect(reduceMotion ? 0.82 : (isExpanded ? 1.0 : 0.58))
                        .animation(reduceMotion ? nil : .easeInOut(duration: currentStep.duration), value: isExpanded)

                    Circle()
                        .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                        .frame(width: 224, height: 224)

                    VStack(spacing: 8) {
                        Text(currentStep.phase.rawValue)
                            .font(.system(size: 34, weight: .light, design: .rounded))
                            .contentTransition(.opacity)
                        Text("Breath \(currentStep.breathNumber) of 3")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Let the circle guide the pace.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(AppTheme.Motion.quick, value: stepIndex)
        .task {
            await runBreathing()
        }
    }

    private func runBreathing() async {
        guard !completed else { return }

        for index in BreathingEngine.steps.indices {
            stepIndex = index
            isExpanded = BreathingEngine.steps[index].phase == .inhale
            Haptics.softTap()
            let duration = BreathingEngine.steps[index].duration
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        }

        completed = true
        onComplete()
    }
}
