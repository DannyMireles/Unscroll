import SwiftUI

struct MathUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var problem = MathChallengeEngine.generate()
    @State private var answer = ""
    @State private var feedback: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 12)

                UnlockHeader(
                    lock: lock,
                    title: "A quick pause first.",
                    subtitle: "Solve one quick prompt before opening."
                )

                VStack(spacing: 18) {
                    Text(problem.prompt)
                        .font(.system(size: 52, weight: .light, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    TextField("Answer", text: $answer)
                        .keyboardType(.numberPad)
                        .focused($isFocused)
                        .font(.system(size: 30, weight: .light, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if let feedback {
                        Text(feedback)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    PrimaryButton(title: "Continue", isDisabled: answer.isEmpty) {
                        submit()
                    }
                }
                .glassCard()
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .padding(.vertical, 24)
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
            feedback = "Try once more."
            answer = ""
            problem = MathChallengeEngine.generate()
        }
    }
}
