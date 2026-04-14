import SwiftUI

struct BreathingUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var stepIndex = 0
    @State private var isExpanded = false
    @State private var completed = false

    private var currentStep: BreathingStep {
        BreathingEngine.steps[min(stepIndex, BreathingEngine.steps.count - 1)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 12)

                UnlockHeader(
                    lock: lock,
                    title: "Take three deep breaths.",
                    subtitle: "A quiet pause before continuing."
                )

                VStack(spacing: 28) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.14))
                            .frame(width: 220, height: 220)
                            .scaleEffect(isExpanded ? 1.0 : 0.58)
                            .animation(.easeInOut(duration: currentStep.duration), value: isExpanded)

                        Circle()
                            .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                            .frame(width: 224, height: 224)

                        VStack(spacing: 8) {
                            Text(currentStep.phase.rawValue)
                                .font(.system(size: 34, weight: .light, design: .rounded))
                            Text("Breath \(currentStep.breathNumber) of 3")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Let the circle guide the pace.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .glassCard()
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
        }
        .padding(.vertical, 24)
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
