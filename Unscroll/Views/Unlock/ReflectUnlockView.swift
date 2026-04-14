import SwiftUI

struct ReflectUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var card = SpanishWordEngine.randomCard(avoiding: nil)
    @State private var previousCardID: String?
    @State private var response = ""
    @State private var helperMessage = "Type the English meaning. If you do not know it, type 'learn'."
    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 12)

                UnlockHeader(
                    lock: lock,
                    title: "Learn one Spanish word.",
                    subtitle: "Translate it to continue. Type 'learn' anytime for help."
                )

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Spanish")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(card.spanish)
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if isRevealed {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Meaning")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(card.english)
                                .font(.headline.weight(.medium))
                                .foregroundStyle(AppTheme.accentDeep)
                        }
                        .padding(14)
                        .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    TextField("Type the English meaning", text: $response)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($isFocused)
                        .padding(10)
                        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onSubmit {
                            submit()
                        }

                    Text(helperMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if isRevealed {
                        PrimaryButton(title: "I Learned It") {
                            onComplete()
                        }
                    } else {
                        PrimaryButton(title: "Check") {
                            submit()
                        }
                    }

                    HStack(spacing: 10) {
                        SecondaryActionButton(title: "Learn", icon: "book.closed") {
                            response = SpanishWordEngine.learnCommand
                            submit()
                        }
                        SecondaryActionButton(title: "New Word", icon: "arrow.triangle.2.circlepath") {
                            loadNextCard()
                        }
                    }
                }
                .glassCard()
                .padding(.horizontal, 20)

                Spacer(minLength: 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .padding(.vertical, 24)
        .onAppear {
            previousCardID = card.id
            isFocused = true
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                isFocused = false
            }
        )
    }

    private func submit() {
        if SpanishWordEngine.isLearnCommand(response) {
            response = ""
            isRevealed = true
            helperMessage = "Great. Read it once, then tap 'I Learned It'."
            Haptics.softTap()
            return
        }

        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            helperMessage = "Type an answer, or type 'learn'."
            return
        }

        if SpanishWordEngine.isCorrectAnswer(response, for: card) {
            onComplete()
        } else {
            Haptics.retry()
            helperMessage = "Not yet. Try again, or type 'learn' for help."
        }
    }

    private func loadNextCard() {
        let next = SpanishWordEngine.randomCard(avoiding: previousCardID)
        previousCardID = next.id
        card = next
        response = ""
        isRevealed = false
        helperMessage = "Type the English meaning. If you do not know it, type 'learn'."
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
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AppTheme.accentDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
