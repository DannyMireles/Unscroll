import SwiftUI

struct MathUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var problem = MathChallengeEngine.generate()
    @State private var answer = ""
    @State private var feedback: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "A quick pause first.",
            subtitle: "Solve one quick prompt before opening."
        ) {
            VStack(spacing: 18) {
                Text(problem.prompt)
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(AppTheme.Motion.quick, value: problem.prompt)

                TextField("Answer", text: $answer)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                            .stroke(Color.white.opacity(0.30), lineWidth: 1)
                    }

                if let feedback {
                    Text(feedback)
                        .font(AppTheme.Typography.subheadlineMedium)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                }

                PrimaryButton(title: "Continue", isDisabled: answer.isEmpty) {
                    submit()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(AppTheme.Motion.reveal, value: feedback)
        .simultaneousGesture(
            TapGesture().onEnded {
                isFocused = false
            }
        )
    }

    private func submit() {
        if MathChallengeEngine.validate(answer, problem: problem) {
            onComplete()
        } else {
            Haptics.retry()
            // Show the correct answer for the prompt they just missed, then give a fresh one.
            withAnimation(AppTheme.Motion.reveal) {
                feedback = "Not quite — \(problem.prompt) = \(problem.answer). Here's a new one."
                answer = ""
                problem = MathChallengeEngine.generate()
            }
        }
    }
}
