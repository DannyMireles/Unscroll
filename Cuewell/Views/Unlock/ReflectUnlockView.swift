import SwiftUI

struct LanguageUnlockView: View {
    let lock: AppLock
    let language: LearnableLanguage
    let onComplete: () -> Void

    @State private var card: LanguageCard?
    @State private var choices: [String] = []
    @State private var previousCardID: String?
    @State private var selectedChoice: String?
    @State private var wrongChoices: Set<String> = []
    @State private var revealedAnswer = false
    @State private var isLoading = true
    @State private var helperMessage = "Tap the English meaning."

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Learn one \(language.displayName) word.",
            subtitle: "Pick the English meaning to continue."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                wordCard

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding a word…")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
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
                            Task { await loadNextCard() }
                        }
                    }
                }
            }
        }
        .animation(AppTheme.Motion.reveal, value: card?.id)
        .animation(AppTheme.Motion.reveal, value: isLoading)
        .animation(AppTheme.Motion.quick, value: helperMessage)
        .task { await loadNextCard() }
    }

    @ViewBuilder
    private var wordCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language.displayName)
                .font(AppTheme.Typography.captionSemibold)
                .foregroundStyle(.secondary)
            Text(card?.word ?? "…")
                .font(AppTheme.Typography.display)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                .stroke(AppTheme.chromeStroke, lineWidth: 1)
        }
    }

    private func choiceState(for choice: String) -> ChoiceButton.SelectionState {
        guard let card else { return .idle }
        let isCorrect = LanguageEngine.isCorrectAnswer(choice, for: card)
        if isCorrect, revealedAnswer || selectedChoice == choice {
            return .correct
        }
        if wrongChoices.contains(choice) {
            return .wrong
        }
        return .idle
    }

    private func select(_ choice: String) {
        guard let card else { return }
        let isCorrect = LanguageEngine.isCorrectAnswer(choice, for: card)

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
            helperMessage = "Correct!"
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onComplete()
            }
        } else {
            withAnimation(AppTheme.Motion.reveal) {
                wrongChoices.insert(choice)
                revealedAnswer = true
                helperMessage = "Not quite — “\(card.word)” means “\(card.english).” Tap it to continue."
            }
            Haptics.retry()
        }
    }

    private func reveal() {
        guard let card, !revealedAnswer, selectedChoice == nil else { return }
        withAnimation(AppTheme.Motion.reveal) {
            revealedAnswer = true
            helperMessage = "“\(card.word)” means “\(card.english).” Tap it to continue."
        }
        Haptics.softTap()
    }

    @MainActor
    private func loadNextCard() async {
        isLoading = true
        selectedChoice = nil
        wrongChoices = []
        revealedAnswer = false
        helperMessage = "Tap the English meaning."

        let next = await LanguageEngine.card(for: language, avoiding: previousCardID)
        previousCardID = next.id
        card = next
        choices = LanguageEngine.choices(for: next)
        isLoading = false
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
        case .correct: return AppTheme.accentOnChrome
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
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(AppTheme.Typography.subheadlineMedium)
            .foregroundStyle(AppTheme.accentOnChrome)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                    .stroke(AppTheme.chromeStroke, lineWidth: 1)
            }
            .opacity(isDisabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Read Something (Wikipedia)

struct ReadUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var article: ReadArticle?
    @State private var isLoading = true
    @State private var canContinue = false
    @State private var secondsLeft = ReadUnlockView.readDwellSeconds
    @State private var dwellTask: Task<Void, Never>?

    private static let readDwellSeconds = 5

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Read something interesting.",
            subtitle: "A short read, then you're through."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding something interesting…")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else if let article {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(article.title)
                            .font(AppTheme.Typography.title2)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(article.extract)
                            .font(AppTheme.Typography.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                }

                SecondaryActionButton(
                    title: "New article",
                    icon: "arrow.triangle.2.circlepath",
                    isDisabled: isLoading
                ) {
                    Task { await load() }
                }

                PrimaryButton(
                    title: canContinue ? "Continue" : "Keep reading… \(secondsLeft)",
                    isDisabled: !canContinue
                ) {
                    Haptics.success()
                    onComplete()
                }
            }
        }
        .animation(AppTheme.Motion.reveal, value: isLoading)
        .animation(AppTheme.Motion.quick, value: canContinue)
        .task { await load() }
        .onDisappear { dwellTask?.cancel() }
    }

    @MainActor
    private func load() async {
        dwellTask?.cancel()
        canContinue = false
        secondsLeft = Self.readDwellSeconds
        isLoading = true

        let fetched = await WikipediaReadEngine.fetchRandomArticle() ?? WikipediaReadEngine.fallbackArticle()
        article = fetched
        isLoading = false
        startDwell()
    }

    private func startDwell() {
        dwellTask?.cancel()
        dwellTask = Task { @MainActor in
            var remaining = Self.readDwellSeconds
            while remaining > 0 {
                secondsLeft = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
            }
            secondsLeft = 0
            canContinue = true
            Haptics.success()
        }
    }
}

// MARK: - Journaling (Wellness)

struct JournalingUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var prompt: WellnessPrompt?
    @State private var isLoading = true
    @State private var canContinue = false
    @State private var secondsLeft = JournalingUnlockView.dwellSeconds
    @State private var dwellTask: Task<Void, Never>?

    private static let dwellSeconds = 5

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Take a moment.",
            subtitle: "Sit with this for a few seconds, then you're through."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding a prompt…")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                } else if let prompt {
                    Text(prompt.text)
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentTransition(.opacity)
                }

                SecondaryActionButton(
                    title: "New prompt",
                    icon: "arrow.triangle.2.circlepath",
                    isDisabled: isLoading
                ) {
                    Task { await load() }
                }

                PrimaryButton(
                    title: canContinue ? "Continue" : "Reflect… \(secondsLeft)",
                    isDisabled: !canContinue
                ) {
                    Haptics.success()
                    onComplete()
                }
            }
        }
        .animation(AppTheme.Motion.reveal, value: isLoading)
        .animation(AppTheme.Motion.quick, value: canContinue)
        .task { await load() }
        .onDisappear { dwellTask?.cancel() }
    }

    @MainActor
    private func load() async {
        dwellTask?.cancel()
        canContinue = false
        secondsLeft = Self.dwellSeconds
        isLoading = true
        prompt = await WellnessPromptEngine.prompt()
        isLoading = false
        startDwell()
    }

    private func startDwell() {
        dwellTask?.cancel()
        dwellTask = Task { @MainActor in
            var remaining = Self.dwellSeconds
            while remaining > 0 {
                secondsLeft = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                remaining -= 1
            }
            secondsLeft = 0
            canContinue = true
            Haptics.success()
        }
    }
}
