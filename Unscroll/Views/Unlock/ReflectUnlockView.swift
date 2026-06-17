import SwiftUI

struct ReflectUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var card = SpanishWordEngine.randomCard(avoiding: nil)
    @State private var choices: [String] = []
    @State private var previousCardID: String?
    @State private var selectedChoice: String?
    @State private var wrongChoices: Set<String> = []
    @State private var revealedAnswer = false
    @State private var helperMessage = "Tap the English meaning."

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Learn one Spanish word.",
            subtitle: "Pick the English meaning to continue."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spanish")
                        .font(AppTheme.Typography.captionSemibold)
                        .foregroundStyle(.secondary)
                    Text(card.spanish)
                        .font(AppTheme.Typography.display)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                }

                VStack(spacing: 10) {
                    ForEach(Array(choices.enumerated()), id: \.element) { index, choice in
                        ChoiceButton(
                            title: choice,
                            state: choiceState(for: choice)
                        ) {
                            select(choice)
                        }
                        .flowItem(index)
                    }
                }

                Text(helperMessage)
                    .font(AppTheme.Typography.footnoteMedium)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                HStack(spacing: 10) {
                    SecondaryActionButton(title: "Reveal", icon: "lightbulb") {
                        reveal()
                    }
                    SecondaryActionButton(title: "New Word", icon: "arrow.triangle.2.circlepath") {
                        loadNextCard()
                    }
                }
            }
        }
        .animation(AppTheme.Motion.reveal, value: card.id)
        .animation(AppTheme.Motion.quick, value: helperMessage)
        .onAppear {
            if choices.isEmpty {
                choices = SpanishWordEngine.choices(for: card)
            }
            previousCardID = card.id
        }
    }

    private func choiceState(for choice: String) -> ChoiceButton.SelectionState {
        let isCorrect = SpanishWordEngine.isCorrectAnswer(choice, for: card)
        // Once revealed (after a miss or "Reveal"), or once they pick correctly, the right
        // answer is highlighted green so they can see/learn it.
        if isCorrect, revealedAnswer || selectedChoice == choice {
            return .correct
        }
        if wrongChoices.contains(choice) {
            return .wrong
        }
        return .idle
    }

    private func select(_ choice: String) {
        let isCorrect = SpanishWordEngine.isCorrectAnswer(choice, for: card)

        // After the answer has been shown, tapping the highlighted correct choice continues.
        if revealedAnswer {
            if isCorrect {
                Haptics.success()
                onComplete()
            }
            return
        }

        guard selectedChoice == nil else { return }

        if isCorrect {
            selectedChoice = choice
            helperMessage = "¡Correcto!"
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onComplete()
            }
        } else {
            // Wrong: mark it, then reveal the right answer so they learn it before continuing.
            withAnimation(AppTheme.Motion.reveal) {
                wrongChoices.insert(choice)
                revealedAnswer = true
                helperMessage = "Not quite — “\(card.spanish)” means “\(card.english).” Tap it to continue."
            }
            Haptics.retry()
        }
    }

    private func reveal() {
        guard !revealedAnswer, selectedChoice == nil else { return }
        withAnimation(AppTheme.Motion.reveal) {
            revealedAnswer = true
            helperMessage = "“\(card.spanish)” means “\(card.english).” Tap it to continue."
        }
        Haptics.softTap()
    }

    private func loadNextCard() {
        let next = SpanishWordEngine.randomCard(avoiding: previousCardID)
        withAnimation(AppTheme.Motion.reveal) {
            previousCardID = next.id
            card = next
            choices = SpanishWordEngine.choices(for: next)
            selectedChoice = nil
            wrongChoices = []
            revealedAnswer = false
            helperMessage = "Tap the English meaning."
        }
    }
}

private struct ChoiceButton: View {
    enum SelectionState: Equatable {
        case idle
        case correct
        case wrong
    }

    let title: String
    let state: SelectionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(AppTheme.Typography.headlineMedium)
                    .foregroundStyle(foreground)
                Spacer()
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(foreground)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(background, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(AppTheme.Motion.selection, value: state)
    }

    private var icon: String? {
        switch state {
        case .idle: return nil
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }

    private var foreground: Color {
        switch state {
        case .idle: return .primary
        case .correct: return AppTheme.accentDeep
        case .wrong: return .red
        }
    }

    private var background: Color {
        switch state {
        case .idle: return Color.secondary.opacity(0.08)
        case .correct: return AppTheme.accent.opacity(0.16)
        case .wrong: return Color.red.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle: return Color.white.opacity(0.25)
        case .correct: return AppTheme.accent.opacity(0.6)
        case .wrong: return Color.red.opacity(0.4)
        }
    }
}

private struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(AppTheme.Typography.subheadlineMedium)
            .foregroundStyle(AppTheme.accentDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
