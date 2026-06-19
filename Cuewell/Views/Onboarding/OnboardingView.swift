import Foundation
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .welcome
    @State private var firstName = ""
    @State private var ageText = ""
    @State private var selectedAppCategories: Set<LockedAppCategory> = []
    @State private var selectedDailyBucket: DailyHoursBucket?
    @State private var selectedCategories: Set<ExerciseCategory> = []
    /// Persisted so the Add Lock screen can pre-select the user's chosen areas.
    @AppStorage("preferredCategories") private var preferredCategoriesRaw = ""
    @FocusState private var focusedField: OnboardingField?

    private var projection: TimeProjection {
        TimeProjection.projectFixedWindow(
            dailyHours: selectedDailyBucket?.value ?? DailyHoursBucket.defaultBucket.value,
            years: projectionYears
        )
    }

    private var projectionYears: Int {
        guard let age, age < 18 else { return 10 }
        return 3
    }

    private var age: Int? {
        Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
            }
        }
        .animation(AppTheme.Motion.page, value: step)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if step.showsInputProgress {
                InputProgressBar(current: inputProgressIndex, total: OnboardingConstants.inputStepCount)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            if step.canSkip {
                Button("Skip") {
                    Haptics.softTap()
                    focusedField = nil
                    withAnimation(AppTheme.Motion.page) {
                        step = .setup
                    }
                }
                .font(AppTheme.Typography.captionSemibold)
                .foregroundStyle(OnboardingPalette.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(OnboardingPalette.controlFill, in: Capsule())
                .overlay { Capsule().stroke(OnboardingPalette.controlStroke, lineWidth: 1) }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip onboarding")
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeScreen()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .name:
                NameScreen(firstName: $firstName, focusedField: $focusedField)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .age:
                AgeScreen(ageText: $ageText, focusedField: $focusedField)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .apps:
                AppCategoryScreen(selectedCategories: $selectedAppCategories)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .dailyTime:
                DailyTimeScreen(selectedBucket: $selectedDailyBucket)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .goal:
                CategoryScreen(selectedCategories: $selectedCategories)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .projection:
                ProjectionScreen(
                    projection: projection,
                    bucket: selectedDailyBucket ?? .defaultBucket,
                    appsLabel: appsLabel,
                    isLightUser: selectedDailyBucket?.isLightUse == true
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .reclaim:
                ReclaimScreen(projection: projection)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .solution:
                SolutionScreen(
                    categories: selectedCategories,
                    permissionControls: { permissionControls }
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .setup:
                SetupScreen(permissionControls: { permissionControls })
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if step.usesPermissionControls {
            // The Screen Time button lives in the same spot as every other primary button.
            PrimaryButton(
                title: permissionManager.isRequesting ? "Checking access..." : "Enable Screen Time",
                isDisabled: permissionManager.isRequesting
            ) {
                Task { await permissionManager.requestAuthorization() }
            }
        } else if step.showsBackButton {
            HStack(spacing: 12) {
                backButton
                PrimaryButton(
                    title: primaryButtonTitle,
                    isDisabled: isPrimaryDisabled,
                    action: advance
                )
            }
        } else {
            // No back button on the first screen — let the primary button fill the width.
            PrimaryButton(
                title: primaryButtonTitle,
                isDisabled: isPrimaryDisabled,
                action: advance
            )
        }
    }

    private var backButton: some View {
        Button {
            Haptics.softTap()
            focusedField = nil
            withAnimation(AppTheme.Motion.page) {
                step = previousStep
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.primary)
                .frame(width: 54, height: 54)
                .background(OnboardingPalette.controlFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                        .stroke(OnboardingPalette.controlStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var permissionControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(OnboardingPalette.accentText)
                Text("Screen Time access: \(permissionManager.statusLabel)")
                    .font(AppTheme.Typography.subheadlineMedium)
                    .foregroundStyle(OnboardingPalette.secondaryText)
            }

            if let error = permissionManager.permissionErrorMessage {
                Text(error)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("We'll ask iOS for permission, then you choose the exact apps to lock.")
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(OnboardingPalette.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome:
            return "Begin"
        case .goal:
            return "See what's possible"
        case .projection:
            return "Reclaim it"
        case .reclaim:
            return "Make it real"
        default:
            return "Continue"
        }
    }

    private var isPrimaryDisabled: Bool {
        switch step {
        case .age:
            return !ageText.isEmpty && age == nil
        case .apps:
            return selectedAppCategories.isEmpty
        case .dailyTime:
            return selectedDailyBucket == nil
        case .goal:
            return selectedCategories.isEmpty
        default:
            return false
        }
    }

    private var previousStep: OnboardingStep {
        switch step {
        case .welcome:
            return .welcome
        case .name:
            return .welcome
        case .age:
            return .name
        case .apps:
            return .age
        case .dailyTime:
            return .apps
        case .goal:
            return .dailyTime
        case .projection:
            return .goal
        case .reclaim:
            return .projection
        case .solution:
            return .reclaim
        case .setup:
            return selectedCategories.isEmpty ? .welcome : .goal
        }
    }

    private var inputProgressIndex: Int {
        switch step {
        case .name:
            return 1
        case .age:
            return 2
        case .apps:
            return 3
        case .dailyTime:
            return 4
        case .goal:
            return 5
        default:
            return 0
        }
    }

    private var appsLabel: String {
        let labels = LockedAppCategory.allCases
            .filter { selectedAppCategories.contains($0) }
            .map(\.projectionLabel)

        guard !labels.isEmpty else { return "these apps" }
        if labels.count == 1 { return labels[0] }
        return labels.dropLast().joined(separator: ", ") + " and " + labels.last!
    }

    private func advance() {
        guard !isPrimaryDisabled else { return }
        focusedField = nil
        Haptics.softTap()

        withAnimation(AppTheme.Motion.page) {
            switch step {
            case .welcome:
                step = .name
            case .name:
                step = .age
            case .age:
                step = .apps
            case .apps:
                step = .dailyTime
            case .dailyTime:
                step = .goal
            case .goal:
                // Remember the chosen areas so new locks pre-select them.
                preferredCategoriesRaw = ExerciseCategory.allCases
                    .filter { selectedCategories.contains($0) }
                    .map(\.rawValue)
                    .joined(separator: ",")
                step = .projection
            case .projection:
                step = .reclaim
            case .reclaim:
                step = .solution
            case .solution, .setup:
                break
            }
        }
    }
}

// MARK: - Screens

private struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                BrandLogoView(size: 72)
                    .flowAppear(delay: 0.02)

                VStack(spacing: 14) {
                    (Text("You don't have a screen-time problem.\nYou have a ")
                        + Text("time")
                        .italic()
                        .foregroundColor(OnboardingPalette.accentText)
                        + Text(" problem."))
                        .font(AppTheme.Typography.display)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(OnboardingConstants.appName) helps you protect minutes for the life you keep meaning to live.")
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .flowAppear(delay: 0.10)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }
}

private struct NameScreen: View {
    @Binding var firstName: String
    var focusedField: FocusState<OnboardingField?>.Binding

    var body: some View {
        OnboardingScaffold {
            QuestionHeader(
                title: "What should we call you?",
                subtitle: "Optional, just for the next few screens."
            )

            TextField("First name", text: $firstName)
                .focused(focusedField, equals: .name)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .font(.system(.title2, design: .rounded))
                .padding(.horizontal, 18)
                .frame(height: 60)
                .background(OnboardingPalette.cardFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                        .stroke(OnboardingPalette.controlStroke, lineWidth: 1)
                }
                .foregroundStyle(.primary)
                .tint(OnboardingPalette.accent)
                .flowItem(1)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focusedField.wrappedValue = .name
            }
        }
    }
}

private struct AgeScreen: View {
    @Binding var ageText: String
    var focusedField: FocusState<OnboardingField?>.Binding

    var body: some View {
        OnboardingScaffold {
            QuestionHeader(
                title: "How old are you?",
                subtitle: "This keeps the framing age-safe. You can leave it blank."
            )

            VStack(spacing: 12) {
                TextField("Age", text: $ageText)
                    .focused(focusedField, equals: .age)
                    .keyboardType(.numberPad)
                    .font(.system(.title2, design: .rounded))
                    .padding(.horizontal, 18)
                    .frame(height: 60)
                    .background(OnboardingPalette.cardFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                            .stroke(OnboardingPalette.controlStroke, lineWidth: 1)
                    }
                    .foregroundStyle(.primary)
                    .tint(OnboardingPalette.accent)

                if !ageText.isEmpty && Int(ageText) == nil {
                    Text("Use numbers only, or clear this field to continue without it.")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.48))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .flowItem(1)
        }
        .onChange(of: ageText) { newValue in
            let filtered = newValue.filter(\.isNumber)
            if filtered != newValue {
                ageText = filtered
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focusedField.wrappedValue = .age
            }
        }
    }
}

private struct AppCategoryScreen: View {
    @Binding var selectedCategories: Set<LockedAppCategory>

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        OnboardingScaffold {
            QuestionHeader(
                title: "Which apps steal the most time?",
                subtitle: "Pick the buckets you want to protect first."
            )

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(LockedAppCategory.allCases) { category in
                    SelectableTile(
                        title: category.title,
                        subtitle: category.subtitle,
                        systemImage: category.systemImage,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
            .flowItem(1)
        }
    }
}

private struct DailyTimeScreen: View {
    @Binding var selectedBucket: DailyHoursBucket?

    var body: some View {
        OnboardingScaffold {
            QuestionHeader(
                title: "Be honest. How long each day?",
                subtitle: "Use your own estimate for those apps. This stays on your device."
            )

            VStack(spacing: 8) {
                ForEach(DailyHoursBucket.all) { bucket in
                    SelectableRow(
                        title: bucket.label,
                        subtitle: bucket.detail,
                        systemImage: "timer",
                        isSelected: selectedBucket == bucket
                    ) {
                        selectedBucket = bucket
                    }
                }
            }
            .flowItem(1)

            PrivacyNote()
                .flowItem(2)
        }
    }
}

private struct CategoryScreen: View {
    @Binding var selectedCategories: Set<ExerciseCategory>

    var body: some View {
        OnboardingScaffold {
            QuestionHeader(
                title: "Which of these will help you most?",
                subtitle: "Pick the areas your unlocks should pull from — you can fine-tune per lock later."
            )

            VStack(spacing: 8) {
                ForEach(ExerciseCategory.allCases) { category in
                    SelectableRow(
                        title: category.title,
                        subtitle: category.subtitle,
                        systemImage: category.systemImage,
                        isSelected: selectedCategories.contains(category)
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }
            }
            .flowItem(1)
        }
    }
}

private struct ProjectionScreen: View {
    let projection: TimeProjection
    let bucket: DailyHoursBucket
    let appsLabel: String
    let isLightUser: Bool

    private var display: ProjectionDisplay {
        projection.display
    }

    var body: some View {
        // Fixed (non-scrolling) layout: the projection reads first, the Good News reframes it
        // in the middle, and the assumptions footnote anchors the bottom, just above the button.
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            VStack(spacing: 8) {
                Text("At \(bucket.hoursPhrase) a day, the next \(projection.years) years hold")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                CountUpProjectionText(display: display)
                    .accessibilityLabel("\(display.accessibilityText) of waking time")

                (Text("of waking time on ")
                    .foregroundColor(OnboardingPalette.secondaryText)
                    + Text(appsLabel)
                    .italic()
                    .underline()
                    .foregroundColor(OnboardingPalette.accentText))
                    .font(AppTheme.Typography.body)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("of waking time on \(appsLabel)")
            }
            .flowItem(0)

            Spacer(minLength: 24)

            GoodNewsCallout(
                text: isLightUser
                    ? "You're already keeping this contained — that time is yours, and worth protecting."
                    : "That time is still yours to spend. Cuewell turns the scroll into minutes you'll actually feel."
            )
            .flowItem(1)

            Spacer(minLength: 24)

            Text("Based on \(bucket.hoursPhrase)/day over \(projection.years) years, counting waking hours only.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(OnboardingPalette.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .flowItem(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
}

private struct ReclaimScreen: View {
    let projection: TimeProjection

    private var reclaim: ReclaimProjection {
        ReclaimProjection(totalHours: projection.totalHours)
    }

    var body: some View {
        OnboardingScaffold {
            QuestionHeader(
                title: "Same hours. Different spending.",
                subtitle: "These are simple conversions, not promises."
            )

            VStack(spacing: 8) {
                ReclaimMetricRow(value: reclaim.books, label: "books read", assumption: "about 6 hours each", systemImage: "book.fill")
                ReclaimMetricRow(value: reclaim.brainWorkouts, label: "brain workouts", assumption: "about 20 minutes each", systemImage: "brain.head.profile")
                ReclaimMetricRow(value: reclaim.mindfulResets, label: "mindful resets", assumption: "about 10 minutes each", systemImage: "wind")
                ReclaimMetricRow(value: reclaim.languages, label: "languages", assumption: "about 600 hours each", systemImage: "character.bubble.fill")
            }
            .flowItem(1)

            Text("The hours are the same. Only the spending changes.")
                .font(AppTheme.Typography.bodyMedium)
                .foregroundStyle(OnboardingPalette.accentText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .flowItem(2)
        }
    }
}

private struct SolutionScreen<PermissionControls: View>: View {
    let categories: Set<ExerciseCategory>
    @ViewBuilder var permissionControls: PermissionControls

    /// The first selected area (canonical order) drives the headline + stat.
    private var primary: ExerciseCategory {
        ExerciseCategory.allCases.first { categories.contains($0) } ?? .mentalStimulation
    }

    var body: some View {
        HeroLayout {
            BrandLogoView(size: 72)
                .flowItem(0)
        } content: {
            VStack(spacing: 20) {
                QuestionHeader(
                    title: solutionTitle,
                    subtitle: solutionCopy,
                    alignment: .center
                )

                StatCallout(category: primary)
            }
            .flowItem(1)
        } footer: {
            permissionControls
                .flowItem(2)
        }
    }

    private var solutionTitle: String {
        switch primary {
        case .mentalStimulation: return "Build a sharper hour."
        case .reading: return "Make room to read."
        case .language: return "Learn, one word at a time."
        case .wellness: return "Come back to yourself."
        }
    }

    private var solutionCopy: String {
        switch primary {
        case .mentalStimulation:
            return "Turn the pause before an app into a quick mental rep — math or pattern memory."
        case .reading:
            return "Trade a reflexive scroll for one short, genuinely interesting read."
        case .language:
            return "A few protected minutes can become a new word in Spanish, French, or German."
        case .wellness:
            return "Swap a reflexive scroll for one breath or one quiet reflection."
        }
    }
}

private struct SetupScreen<PermissionControls: View>: View {
    @ViewBuilder var permissionControls: PermissionControls

    var body: some View {
        HeroLayout {
            BrandLogoView(size: 72)
                .flowItem(0)
        } content: {
            QuestionHeader(
                title: "Ready when you are.",
                subtitle: "\(OnboardingConstants.appName) keeps the math local and turns locked apps into a pause you chose.",
                alignment: .center
            )
            .flowItem(1)
        } footer: {
            permissionControls
                .flowItem(2)
        }
    }
}

// MARK: - Components

private struct OnboardingScaffold<Content: View>: View {
    var alignment: HorizontalAlignment = .leading
    var bottomPadding: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: alignment, spacing: 20) {
                content
            }
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, bottomPadding)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Shared layout for the centered "hero" screens (welcome, projection, solution, soft path,
/// setup) so they all share the same rhythm: a top mark, centered content, optional bottom
/// controls — evenly distributed with consistent padding.
private struct HeroLayout<Mark: View, Content: View, Footer: View>: View {
    @ViewBuilder var mark: Mark
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            mark
            Spacer(minLength: 28)
            content
            Spacer(minLength: 28)
            footer
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
    }
}

/// The enlarged, prominent "Good news" block on the projection screen.
private struct GoodNewsCallout: View {
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("Good news")
            }
            .font(AppTheme.Typography.headline)
            .foregroundStyle(OnboardingPalette.accentText)

            Text(text)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(OnboardingPalette.selectedFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                .stroke(OnboardingPalette.accent.opacity(0.4), lineWidth: 1)
        }
    }
}

private struct QuestionHeader: View {
    let title: String
    let subtitle: String?
    var alignment: TextAlignment = .leading

    init(title: String, subtitle: String? = nil, alignment: TextAlignment = .leading) {
        self.title = title
        self.subtitle = subtitle
        self.alignment = alignment
    }

    var body: some View {
        VStack(alignment: stackAlignment, spacing: 8) {
            Text(title)
                .font(AppTheme.Typography.title)
                .foregroundStyle(.primary)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .multilineTextAlignment(alignment)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    private var stackAlignment: HorizontalAlignment {
        alignment == .center ? .center : .leading
    }

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
}

private struct SelectableTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.82) : OnboardingPalette.accentText)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? OnboardingPalette.accent : OnboardingPalette.controlFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTheme.Typography.subheadlineMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
            .padding(14)
            .background(isSelected ? OnboardingPalette.selectedFill : OnboardingPalette.cardFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                    .stroke(isSelected ? OnboardingPalette.accent : OnboardingPalette.controlStroke, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SelectableRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.82) : OnboardingPalette.accentText)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? OnboardingPalette.accent : OnboardingPalette.controlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTheme.Typography.subheadlineMedium)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingPalette.accentText : OnboardingPalette.tertiaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? OnboardingPalette.selectedFill : OnboardingPalette.cardFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                    .stroke(isSelected ? OnboardingPalette.accent : OnboardingPalette.controlStroke, lineWidth: isSelected ? 1.4 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct PrivacyNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(OnboardingPalette.accentText)
                .frame(width: 24, height: 24)

            Text("Your answers only feed the estimate on this device.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(OnboardingPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(OnboardingPalette.controlFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerSmall, style: .continuous))
    }
}

private struct InputProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? OnboardingPalette.accent : Color.primary.opacity(0.12))
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("Question \(current) of \(total)")
    }
}

private struct CountUpProjectionText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let display: ProjectionDisplay

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let currentValue = reduceMotion ? display.value : display.value * easedProgress(at: context.date)

            Text(formatted(currentValue))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingPalette.accentText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 64)
        }
        .onAppear {
            startDate = Date()
            Haptics.success()
        }
        .onChange(of: display.value) { _ in
            startDate = Date()
        }
    }

    private func easedProgress(at date: Date) -> Double {
        let progress = min(max(date.timeIntervalSince(startDate) / 1.1, 0), 1)
        return 1 - pow(1 - progress, 3)
    }

    private func formatted(_ value: Double) -> String {
        switch display.kind {
        case .months:
            return "\(max(0, Int(value.rounded()))) months"
        case .years:
            return "\(formatOneDecimal(value)) years"
        }
    }
}

private struct ReclaimMetricRow: View {
    let value: Int
    let label: String
    let assumption: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(width: 36, height: 36)
                .background(OnboardingPalette.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(formatWhole(value)) \(label)")
                    .font(AppTheme.Typography.subheadlineMedium)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(assumption)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(OnboardingPalette.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(OnboardingPalette.cardFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                .stroke(OnboardingPalette.controlStroke, lineWidth: 1)
        }
    }
}

private struct StatCallout: View {
    let category: ExerciseCategory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(OnboardingPalette.accentText)
                .frame(width: 36, height: 36)
                .background(OnboardingPalette.controlFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(calloutCopy)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(OnboardingPalette.cardFill, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                .stroke(OnboardingPalette.controlStroke, lineWidth: 1)
        }
    }

    private var calloutCopy: String {
        switch category {
        case .mentalStimulation:
            // Associational framing only (NEJM Evidence review of 22 studies on mental activity).
            return "People who keep their minds active with puzzles and problem-solving tend to stay noticeably sharper as they age."
        case .reading:
            return "Reading even a little every day is linked with a richer vocabulary, stronger focus, and a calmer mind."
        case .language:
            return "Even a couple of minutes of language practice a day adds up — short, frequent reps are how vocabulary sticks."
        case .wellness:
            // Univ. of Bath & Southampton, BJHP (n=1,247). Framed as felt wellbeing, not treatment.
            return "In a study of over 1,200 people, 10 minutes of daily mindfulness left people feeling calmer, and they still felt it a month later."
        }
    }
}

// MARK: - Model

private enum OnboardingConstants {
    static let appName = "Cuewell"
    static let inputStepCount = 5
}

private enum OnboardingPalette {
    /// Saturated mint for FILLS (icon chips, selected states) — pairs with dark text and reads
    /// on both light and dark backgrounds.
    static let accent = Color(red: 0.42, green: 0.86, blue: 0.68)
    /// Accent tuned for TEXT / emphasis on the page background; deep green in light, mint in dark.
    static let accentText = AppTheme.accentOnChrome
    static let secondaryText = Color.secondary
    static let tertiaryText = Color.secondary.opacity(0.75)
    static let controlFill = Color.primary.opacity(0.06)
    static let controlStroke = AppTheme.chromeStroke
    static let cardFill = Color.primary.opacity(0.04)
    static let selectedFill = Color(red: 0.42, green: 0.86, blue: 0.68).opacity(0.18)
}

private enum OnboardingStep: Equatable {
    case welcome
    case name
    case age
    case apps
    case dailyTime
    case goal
    case projection
    case reclaim
    case solution
    case setup

    var showsInputProgress: Bool {
        switch self {
        case .name, .age, .apps, .dailyTime, .goal:
            return true
        default:
            return false
        }
    }

    var canSkip: Bool {
        switch self {
        case .solution, .setup:
            return false
        default:
            return true
        }
    }

    var usesPermissionControls: Bool {
        switch self {
        case .solution, .setup:
            return true
        default:
            return false
        }
    }

    /// The first screen has no previous step, so it shows no back button and the primary
    /// button fills the width instead.
    var showsBackButton: Bool {
        switch self {
        case .welcome:
            return false
        default:
            return true
        }
    }
}

private enum OnboardingField: Hashable {
    case name
    case age
}

private enum LockedAppCategory: String, CaseIterable, Identifiable {
    case socials
    case shortVideo
    case news
    case games

    var id: String { rawValue }

    var title: String {
        switch self {
        case .socials:
            return "Socials"
        case .shortVideo:
            return "Short video"
        case .news:
            return "News"
        case .games:
            return "Games"
        }
    }

    var subtitle: String {
        switch self {
        case .socials:
            return "Feeds and DMs"
        case .shortVideo:
            return "Reels and clips"
        case .news:
            return "Headlines"
        case .games:
            return "Quick sessions"
        }
    }

    var projectionLabel: String {
        switch self {
        case .socials:
            return "social media"
        case .shortVideo:
            return "short video"
        case .news:
            return "news"
        case .games:
            return "games"
        }
    }

    var systemImage: String {
        switch self {
        case .socials:
            return "bubble.left.and.bubble.right.fill"
        case .shortVideo:
            return "play.rectangle.fill"
        case .news:
            return "newspaper.fill"
        case .games:
            return "gamecontroller.fill"
        }
    }
}

private struct DailyHoursBucket: Identifiable, Equatable {
    let label: String
    let value: Double
    let detail: String

    var id: String { label }

    var isLightUse: Bool {
        value < 1
    }

    var hoursPhrase: String {
        "\(formatHours(value)) \(value == 1 ? "hour" : "hours")"
    }

    // Self-report buckets use representative hours/day on the locked apps.
    // Source: onboarding spec supplied by Daniel; self-report is intentionally primary.
    static let all: [DailyHoursBucket] = [
        DailyHoursBucket(label: "Under 1 hour", value: 0.75, detail: "Light use"),
        DailyHoursBucket(label: "1-2 hours", value: 1.5, detail: "A daily pocket"),
        DailyHoursBucket(label: "2-3 hours", value: 2.5, detail: "A real block"),
        DailyHoursBucket(label: "3-4 hours", value: 3.5, detail: "Half a workday"),
        DailyHoursBucket(label: "4-6 hours", value: 5.0, detail: "A deep chunk"),
        DailyHoursBucket(label: "6+ hours", value: 7.0, detail: "Most of an open day")
    ]

    static let defaultBucket = DailyHoursBucket(label: "2-3 hours", value: 2.5, detail: "A real block")
}

private struct TimeProjection: Equatable {
    let years: Int
    let totalHours: Int
    let wakingMonths: Int
    let wakingYears: Double

    var display: ProjectionDisplay {
        if wakingYears < 1 {
            return ProjectionDisplay(value: Double(max(wakingMonths, 1)), kind: .months)
        }
        return ProjectionDisplay(value: wakingYears, kind: .years)
    }

    static func projectFixedWindow(dailyHours: Double, years: Int = 10) -> TimeProjection {
        let totalHours = dailyHours * 365.25 * Double(years)
        return TimeProjection(
            years: years,
            totalHours: Int(totalHours.rounded()),
            wakingMonths: Int((totalHours / (16 * 30.44)).rounded()),
            wakingYears: (totalHours / (16 * 365.25)).rounded(toPlaces: 1)
        )
    }
}

private struct ProjectionDisplay: Equatable {
    enum Kind {
        case months
        case years
    }

    let value: Double
    let kind: Kind

    var accessibilityText: String {
        switch kind {
        case .months:
            return "\(Int(value.rounded())) months"
        case .years:
            return "\(formatOneDecimal(value)) years"
        }
    }
}

private struct ReclaimProjection {
    let books: Int
    let brainWorkouts: Int
    let languages: Int
    let mindfulResets: Int

    init(totalHours: Int) {
        books = max(1, Int((Double(totalHours) / 6).rounded()))
        brainWorkouts = max(1, totalHours * 3)   // ~20 minutes each
        languages = max(1, Int((Double(totalHours) / 600).rounded()))
        mindfulResets = max(1, totalHours * 6)   // ~10 minutes each
    }
}

// MARK: - Formatting

private func formatHours(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
        ? "\(Int(value))"
        : formatOneDecimal(value)
}

private func formatOneDecimal(_ value: Double) -> String {
    String(format: "%.1f", value)
}

private func formatWhole(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
