import FamilyControls
import ManagedSettings
import SwiftUI

struct AddLockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lockStore: LockStore

    /// Called with the newly created lock just before the sheet dismisses, so the home
    /// screen can show the "lock ready" popup that captures the app's identity.
    var onCreated: (AppLock) -> Void = { _ in }

    @State private var selection = FamilyActivitySelection()
    @State private var launchScheme = ""
    @State private var confirmedLaunchName = ""
    @State private var pickerCapturedAppName = ""
    @State private var isPickerPresented = false
    @State private var hours = 0
    @State private var minutes = 30
    @State private var methods: Set<UnlockMethod> = AddLockView.initialMethods()
    @State private var rewardMode: UnlockRewardMode = .incrementalByLimit

    @State private var step = 0
    @State private var showConfetti = false
    @State private var confettiBurstID = 0
    @State private var confettiStart: ConfettiStart = .top
    @State private var isSaving = false
    @State private var previewMethod: UnlockMethod?
    @State private var createdLock: AppLock?

    private let lastStep = 3
    private let completionStep = 4

    private var totalMinutes: Int { hours * 60 + minutes }

    private var hasSelection: Bool {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count > 0
    }

    private var canSave: Bool {
        hasSelection && totalMinutes > 0 && !methods.isEmpty
    }

    /// The selected exercises in the stable display order (so the saved lock keeps a
    /// predictable order rather than the Set's arbitrary one).
    private var orderedMethods: [UnlockMethod] {
        UnlockMethod.allSelectable.filter { methods.contains($0) }
    }

    /// Default selection for a new lock = the exercises of the categories the user picked
    /// during onboarding (falls back to Mental Math if none were chosen).
    private static func initialMethods() -> Set<UnlockMethod> {
        let raw = UserDefaults.standard.string(forKey: "preferredCategories") ?? ""
        let leaves = raw.split(separator: ",")
            .compactMap { ExerciseCategory(rawValue: String($0)) }
            .flatMap { $0.exercises }
        return leaves.isEmpty ? [.mentalMath] : Set(leaves)
    }

    private var primaryDisabled: Bool {
        switch step {
        case 0: return !hasSelection
        case 1: return totalMinutes <= 0
        case lastStep: return !canSave || isSaving
        case completionStep: return createdLock == nil
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    progressBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .flowAppear()

                    ZStack {
                        if step == completionStep {
                            completionStepView
                                .transition(.opacity)
                        } else {
                            TabView(selection: $step) {
                                appStep.tag(0)
                                limitStep.tag(1)
                                timingStep.tag(2)
                                methodStep.tag(3)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(AppTheme.Motion.quick, value: step == completionStep)

                    bottomBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .flowAppear(delay: 0.08)
                }

                if showConfetti {
                    ConfettiView(
                        pieceCount: step == completionStep ? 72 : 64,
                        start: confettiStart
                    )
                    .id(confettiBurstID)
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .navigationTitle("New Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != completionStep {
                        Button("Cancel") { dismiss() }
                            .disabled(isSaving)
                    }
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .background {
                FamilyActivityPickerNameCapture(isActive: isPickerPresented) { name in
                    pickerCapturedAppName = name
                    applyPickerCapturedAppNameIfPossible(name)
                }
                .frame(width: 0, height: 0)
            }
            // iOS often hides app names from the main app, so we store what it gives us
            // and let extension-captured identity upgrade the lock later.
            .onChange(of: selection) { newSelection in
                confirmedLaunchName = ""
                LockStore.captureSelectionIdentities(newSelection, source: "add.selection")
                let detected = LockStore.displayName(for: newSelection)
                launchScheme = LockStore.suggestedScheme(for: newSelection, fallbackName: detected)
                if !LockStore.isGenericDisplayName(detected) {
                    confirmedLaunchName = detected
                }
                applyPickerCapturedAppNameIfPossible(pickerCapturedAppName)
                if hasSelection {
                    Haptics.success()
                }
            }
            .sheet(item: $previewMethod) { method in
                MethodPreviewView(method: method)
                    .presentationDetents([.fraction(0.82), .large])
                    .flowSheetPresentation()
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0...lastStep, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? AppTheme.accent : Color.secondary.opacity(0.18))
                    .frame(height: 5)
            }
        }
    }

    private var bottomBar: some View {
        Group {
            // First step and the completion step have no back button — let the primary
            // button fill the width.
            if step == completionStep || step == 0 {
                PrimaryButton(
                    title: primaryButtonTitle,
                    isDisabled: primaryDisabled,
                    action: primaryAction
                )
            } else {
                HStack(spacing: 12) {
                    Button {
                        Haptics.softTap()
                        withAnimation(AppTheme.Motion.page) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(AppTheme.accentOnChrome)
                            .frame(width: 54, height: 54)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                                    .stroke(AppTheme.chromeStroke, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)

                    PrimaryButton(
                        title: primaryButtonTitle,
                        isDisabled: primaryDisabled,
                        action: primaryAction
                    )
                }
            }
        }
    }

    private func primaryAction() {
        if step == completionStep {
            if let createdLock {
                onCreated(createdLock)
            }
            dismiss()
        } else if step == lastStep {
            save()
        } else {
            withAnimation(AppTheme.Motion.page) { step += 1 }
        }
    }

    private var primaryButtonTitle: String {
        if step == completionStep { return "Done" }
        if step == lastStep { return isSaving ? "Creating..." : "Create Lock" }
        return "Continue"
    }

    // MARK: - Steps

    private var appStep: some View {
        StepScaffold(
            title: "Which app?",
            subtitle: "Pick the app that pulls you in."
        ) {
            VStack(spacing: 12) {
                Button {
                    isPickerPresented = true
                } label: {
                    AppPickerCard(
                        selection: selection,
                        hasSelection: hasSelection,
                        selectedItemCount: selectedItemCount,
                        fallbackName: displayNameForCurrentSelection,
                        isHighlighted: false
                    )
                }
                .buttonStyle(.plain)

                if hasSelection {
                    if isSingleApplicationSelection {
                        SingleApplicationNote()
                    } else {
                        MultiSelectionNote()
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if isSingleApplicationSelection, let token = selection.applicationTokens.first {
                    ZStack(alignment: .topLeading) {
                        ApplicationTokenNameCapture(token: token) { token, name in
                            applyCapturedAppName(name, for: token)
                        }
                        .id(token.hashValue)
                        .frame(width: 260, height: 44)

                        AppIdentityReportCapture(selection: selection)
                    }
                }
            }
        }
    }

    private var limitStep: some View {
        StepScaffold(
            title: "How long each day?",
            subtitle: "Set when Cuewell steps in."
        ) {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Picker("Hours", selection: $hours) {
                        ForEach(0...12, id: \.self) { Text("\($0) h").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Minutes", selection: $minutes) {
                        ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0) m").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 170)

                Text(totalMinutes > 0 ? "\(limitLabel) of daily use before a challenge" : "Choose at least 1 minute")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .glassCard(padding: 14)
        }
    }

    private var timingStep: some View {
        StepScaffold(
            title: "After an unlock?",
            subtitle: "Choose what one challenge earns."
        ) {
            VStack(spacing: 12) {
                ForEach(UnlockRewardMode.allCases) { mode in
                    BigChoiceCard(
                        title: mode.title,
                        subtitle: mode.description,
                        systemImage: mode == .incrementalByLimit ? "timer" : "sun.max.fill",
                        isSelected: rewardMode == mode
                    ) {
                        rewardMode = mode
                    }
                }
            }
        }
    }

    private var methodStep: some View {
        StepScaffold(
            title: "Pick your challenges",
            subtitle: "Choose one or more. We'll pick one at random each unlock."
        ) {
            UnlockMethodSelectionGrid(selection: $methods) { previewMethod = $0 }
        }
    }

    private var completionStepView: some View {
        StepScaffold(
            title: "Lock created",
            subtitle: nil
        ) {
            if let createdLock {
                VStack(spacing: 22) {
                    Button {
                        Haptics.celebrationDing()
                        triggerConfetti(from: .point(UnitPoint(x: 0.5, y: 0.30)))
                    } label: {
                        BrandAppLockMark(lock: createdLock, size: 124)
                            .scaleEffect(showConfetti ? 1.015 : 1.0)
                            .frame(maxWidth: .infinity, minHeight: 178, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Lock created")

                    LockCreatedStepsCard(lock: createdLock)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    if createdLock.canDeepLink, let token = createdLock.selection.applicationTokens.first {
                        ZStack(alignment: .topLeading) {
                            ApplicationTokenNameCapture(token: token) { token, name in
                                applyCapturedAppName(name, for: token)
                            }
                            .id(token.hashValue)
                            .frame(width: 260, height: 44)

                            AppIdentityReportCapture(selection: createdLock.selection)
                        }
                    }
                }
            }
        }
    }

    private var limitLabel: String {
        AppLock(selection: selection, appDisplayName: "", dailyLimitMinutes: totalMinutes, unlockMethods: orderedMethods).limitLabel
    }

    private var selectedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private var isSingleApplicationSelection: Bool {
        selection.applicationTokens.count == 1
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    private var displayNameForCurrentSelection: String {
        let detected = LockStore.displayName(for: selection)
        if !LockStore.isGenericDisplayName(detected) {
            return detected
        }

        return detected
    }

    // MARK: - Actions

    private func save() {
        guard !isSaving, canSave else { return }
        isSaving = true

        LockStore.captureSelectionIdentities(selection, source: "add.save")
        let resolvedName = resolvedLockName()
        let resolvedScheme = LockStore.normalizeScheme(launchScheme)
            ?? LockStore.suggestedScheme(for: selection, fallbackName: resolvedName)

        Task {
            let created = await lockStore.add(
                selection: selection,
                name: resolvedName,
                launchURLScheme: resolvedScheme,
                limitMinutes: totalMinutes,
                methods: orderedMethods,
                rewardMode: rewardMode
            )
            createdLock = created
            isSaving = false
            Haptics.celebrationDing()
            withAnimation(AppTheme.Motion.quick) {
                step = completionStep
            }
            triggerConfetti(from: .top)
        }
    }

    private func resolvedLockName() -> String {
        let confirmed = confirmedLaunchName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !confirmed.isEmpty {
            return confirmed
        }

        return LockStore.displayName(for: selection)
    }

    private func applyCapturedAppName(_ name: String, for token: ApplicationToken) {
        guard isSingleApplicationSelection,
              selection.applicationTokens.contains(token)
        else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !LockStore.isGenericDisplayName(trimmed) else { return }

        confirmedLaunchName = trimmed
        AppIdentityStore.record(token: token, bundleID: nil, displayName: trimmed)

        if let scheme = LockStore.launchSchemes(forName: trimmed).first {
            launchScheme = scheme
        }

        if var created = createdLock,
           created.selection.applicationTokens.contains(token) {
            let resolvedScheme = LockStore.launchSchemes(forName: trimmed).first
                ?? LockStore.normalizeScheme(created.launchURLScheme)
            created.appDisplayName = trimmed
            created.launchURLScheme = resolvedScheme
            createdLock = created
            Task {
                await lockStore.update(created)
                await lockStore.resolveAndApplyAppStoreIdentity(lockID: created.id, token: token, name: trimmed)
                if let updated = lockStore.locks.first(where: { $0.id == created.id }) {
                    createdLock = updated
                }
            }
        } else {
            Task {
                guard let resolved = await LockStore.resolveAppStoreApp(named: trimmed) else { return }
                AppIdentityStore.record(token: token, bundleID: resolved.bundleID, displayName: resolved.displayName)
                confirmedLaunchName = resolved.displayName
                if let scheme = resolved.launchSchemes.first {
                    launchScheme = scheme
                }
            }
        }

        NSLog("🔗 Cuewell: captured selected app label '%@'", trimmed)
    }

    private func applyPickerCapturedAppNameIfPossible(_ name: String) {
        guard isSingleApplicationSelection,
              let token = selection.applicationTokens.first
        else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !LockStore.isGenericDisplayName(trimmed) else { return }
        applyCapturedAppName(trimmed, for: token)
        NSLog("🔗 Cuewell: captured picker app label '%@'", trimmed)
    }

    private func triggerConfetti(from start: ConfettiStart = .top) {
        confettiStart = start
        confettiBurstID += 1
        withAnimation(AppTheme.Motion.quick) {
            showConfetti = true
        }

        let currentID = confettiBurstID
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard currentID == confettiBurstID else { return }
            withAnimation(AppTheme.Motion.quick) {
                showConfetti = false
            }
        }
    }
}

// MARK: - Step building blocks

private struct StepScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(AppTheme.Typography.title)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .flowItem(0)

                content
                    .flowItem(1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct LockCreatedStepsCard: View {
    let lock: AppLock

    var body: some View {
        VStack(spacing: 0) {
            LockCreatedStepRow(
                systemImage: "shield.fill",
                title: "Shield appears",
                text: "Tap Go To Activity when your limit is reached."
            )

            Divider()
                .padding(.leading, 50)

            LockCreatedStepRow(
                systemImage: "bell.badge.fill",
                title: "Notification opens Cuewell",
                text: "Tap it to start the quick activity."
            )

            Divider()
                .padding(.leading, 50)

            LockCreatedStepRow(
                systemImage: "lock.open.fill",
                title: "Finish to unlock",
                text: lock.canDeepLink
                    ? "Complete the challenge and open your app."
                    : "Complete the challenge and your apps unlock."
            )
        }
        .glassCard(padding: 0)
    }
}

private struct LockCreatedStepRow: View {
    let systemImage: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

/// Shown when a lock covers one app. The native Screen Time picker already knows the
/// target, so we do not ask the user to manually name it.
struct SingleApplicationNote: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "app.badge.checkmark")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
            Text("When shielded, tap Go To Activity.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
    }
}

/// Shown when a lock covers more than one app (or a category / website). There's no single
/// app to jump to, so we don't ask for a name — the user opens what they need from the
/// Home Screen as usual.
struct MultiSelectionNote: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
            Text("Your apps unlock together.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
    }
}

struct BigChoiceCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !isSelected { Haptics.softTap() }
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? AppTheme.accent : AppTheme.accentSoft)
                        .frame(width: 48, height: 48)
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : AppTheme.accent)
                        .scaleEffect(isSelected ? 1.12 : 1.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.4))
            }
            .glassCard(padding: 16)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
            }
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .shadow(color: isSelected ? AppTheme.accent.opacity(0.22) : .clear, radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
        .animation(AppTheme.Motion.selection, value: isSelected)
    }
}

// MARK: - Shared components (also used by EditLockView)

private struct AppPickerCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let selection: FamilyActivitySelection
    let hasSelection: Bool
    let selectedItemCount: Int
    let fallbackName: String
    var isHighlighted = false

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            if hasSelection {
                SelectionTokenIcon(selection: selection)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accentSoft)
                        .frame(width: 48, height: 48)
                    Image(systemName: "plus")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                if hasSelection {
                    SelectionTokenTitleView(
                        applicationTokens: selection.applicationTokens,
                        categoryTokens: selection.categoryTokens,
                        webDomainCount: selection.webDomainTokens.count,
                        selectedItemCount: selectedItemCount,
                        fallbackName: fallbackName
                    )
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                    Text("Tap to change")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Choose an app")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Apple Screen Time picker")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: 14)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                .stroke(AppTheme.accent.opacity(isHighlighted ? 0.68 : 0), lineWidth: 2)
        }
        .scaleEffect(!reduceMotion && isHighlighted && isPulsing ? 1.012 : 1.0)
        .animation(AppTheme.Motion.selection, value: isHighlighted)
        .onAppear {
            updatePulse()
        }
        .onChange(of: isHighlighted) { _ in
            updatePulse()
        }
    }

    private func updatePulse() {
        guard isHighlighted, !reduceMotion else {
            withAnimation(AppTheme.Motion.quick) { isPulsing = false }
            return
        }

        withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}

struct SelectedAppsSummaryView: View {
    let selection: FamilyActivitySelection

    var body: some View {
        let selectedCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count

        if selectedCount > 0 {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(selectedCount) selected")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .glassCard()
        }
    }
}

struct UnlockMethodSelectionGrid: View {
    @Binding var selection: Set<UnlockMethod>
    var onPreview: ((UnlockMethod) -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\(selection.count) selected")
                    .font(AppTheme.Typography.captionSemibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(selection.count > 1 ? "One picked at random each unlock" : "Tap a category to add more")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 2)

            ForEach(ExerciseCategory.allCases) { category in
                CategorySection(
                    category: category,
                    selection: $selection,
                    onPreview: onPreview,
                    toggleExercise: toggle,
                    toggleCategory: toggleCategory
                )
            }
        }
    }

    private func toggle(_ method: UnlockMethod) {
        if selection.contains(method) {
            // Always keep at least one exercise selected overall.
            guard selection.count > 1 else {
                Haptics.retry()
                return
            }
            selection.remove(method)
        } else {
            selection.insert(method)
        }
        Haptics.softTap()
    }

    private func toggleCategory(_ category: ExerciseCategory) {
        let leaves = Set(category.exercises)
        if leaves.isSubset(of: selection) {
            // All on → turn the category off, but never leave zero selected overall.
            let remaining = selection.subtracting(leaves)
            guard !remaining.isEmpty else {
                Haptics.retry()
                return
            }
            selection = remaining
        } else {
            selection.formUnion(leaves)
        }
        Haptics.softTap()
    }
}

/// One category, collapsible. Collapsed by default to keep the page clean — tap the
/// header to reveal and pick its sub-exercises. Shared by the Add and Edit lock flows.
private struct CategorySection: View {
    let category: ExerciseCategory
    @Binding var selection: Set<UnlockMethod>
    var onPreview: ((UnlockMethod) -> Void)?
    let toggleExercise: (UnlockMethod) -> Void
    let toggleCategory: (ExerciseCategory) -> Void

    @State private var isExpanded = false

    private var selectedInCategory: [UnlockMethod] {
        category.exercises.filter { selection.contains($0) }
    }
    private var selectedCount: Int { selectedInCategory.count }
    private var allOn: Bool { selectedCount == category.exercises.count }
    private var anyOn: Bool { selectedCount > 0 }
    private var hasMultiple: Bool { category.exercises.count > 1 }

    /// When collapsed, the secondary line names what's selected (or the category blurb).
    private var summaryLine: String {
        guard anyOn else { return category.subtitle }
        return selectedInCategory.map(\.shortTitle).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                VStack(spacing: 10) {
                    if hasMultiple {
                        selectAllRow
                    }

                    ForEach(category.exercises) { exercise in
                        ChallengeChoiceRow(
                            method: exercise,
                            isSelected: selection.contains(exercise),
                            onPreview: onPreview.map { handler in { handler(exercise) } }
                        ) {
                            toggleExercise(exercise)
                        }
                    }
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        Button {
            Haptics.softTap()
            withAnimation(AppTheme.Motion.page) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(anyOn ? AppTheme.accentOnChrome : .secondary)
                    .frame(width: 38, height: 38)
                    .background(
                        (anyOn ? AppTheme.accentSoft : Color.secondary.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(AppTheme.Typography.headlineMedium)
                        .foregroundStyle(.primary)
                    Text(summaryLine)
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(anyOn ? AppTheme.accentOnChrome : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if anyOn {
                    Text("\(selectedCount)")
                        .font(AppTheme.Typography.captionSemibold)
                        .foregroundStyle(AppTheme.accentOnChrome)
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 5)
                        .background(AppTheme.accentSoft, in: Capsule())
                }

                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                    .stroke(anyOn ? AppTheme.accent.opacity(0.5) : AppTheme.chromeStroke, lineWidth: anyOn ? 1.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(AppTheme.Motion.selection, value: anyOn)
    }

    private var selectAllRow: some View {
        Button {
            toggleCategory(category)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: allOn ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(allOn ? AppTheme.accent : Color.secondary.opacity(0.5))
                Text(allOn ? "Clear all" : "Select all")
                    .font(AppTheme.Typography.captionSemibold)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ChallengeChoiceRow: View {
    let method: UnlockMethod
    let isSelected: Bool
    var onPreview: (() -> Void)?
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: method.setupIcon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isSelected ? AppTheme.accentOnChrome : .secondary)
                        .frame(width: 34, height: 34)
                        .background(
                            (isSelected ? AppTheme.accentSoft : Color.secondary.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(method.title)
                            .font(AppTheme.Typography.headlineMedium)
                            .foregroundStyle(.primary)
                        Text(method.shortSetupDescription)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .frame(height: 30, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 4)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.38))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onPreview {
                Button {
                    Haptics.softTap()
                    onPreview()
                } label: {
                    Image(systemName: "eye")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.accentOnChrome)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay { Circle().stroke(AppTheme.chromeStroke, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview \(method.title)")
            }
        }
        .padding(12)
        .frame(height: 82)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                .stroke(isSelected ? AppTheme.accent.opacity(0.64) : AppTheme.chromeStroke, lineWidth: isSelected ? 1.5 : 1)
        }
        .shadow(color: isSelected ? AppTheme.accent.opacity(0.16) : .clear, radius: 14, x: 0, y: 8)
        .animation(AppTheme.Motion.selection, value: isSelected)
    }
}

private extension UnlockMethod {
    var setupIcon: String {
        switch self {
        case .mentalMath: return "function"
        case .patternMemory: return "square.grid.3x3"
        case .read: return "book.fill"
        case .spanish, .french, .german: return "character.bubble.fill"
        case .breathing: return "wind"
        case .journaling: return "square.and.pencil"
        }
    }

    var shortSetupDescription: String {
        switch self {
        case .mentalMath: return "A quick number prompt."
        case .patternMemory: return "Watch and repeat taps."
        case .read: return "Read a short article."
        case .spanish: return "Learn one Spanish word."
        case .french: return "Learn one French word."
        case .german: return "Learn one German word."
        case .breathing: return "Three guided breaths."
        case .journaling: return "Pause on a prompt."
        }
    }
}

// MARK: - Challenge previews

struct MethodPreviewView: View {
    let method: UnlockMethod
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        Text(method.description)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .flowItem(0)

                        preview
                            .padding(.horizontal, 20)
                            .flowItem(1)

                        Text("Preview only.")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(.secondary)
                            .flowItem(2)
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle(method.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .flowNavigationChrome()
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch method {
        case .mentalMath: MathPreview()
        case .patternMemory: PatternPreview()
        case .breathing: BreathingPreview()
        case .read: ReadPreview()
        case .spanish: LanguagePreview(language: .spanish)
        case .french: LanguagePreview(language: .french)
        case .german: LanguagePreview(language: .german)
        case .journaling: JournalingPreview()
        }
    }
}

private struct MathPreview: View {
    @State private var problem = MathChallengeEngine.generate()

    var body: some View {
        VStack(spacing: 14) {
            Text(problem.prompt)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text("Answer: \(problem.answer)")
                .font(.headline.weight(.medium))
                .foregroundStyle(AppTheme.accentOnChrome)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                withAnimation { problem = MathChallengeEngine.generate() }
            }
        }
    }
}

private struct PatternPreview: View {
    private let sequence = [0, 4, 8, 5]
    @State private var highlighted: Int?

    var body: some View {
        VStack(spacing: 12) {
            Text("Watch, then repeat the taps")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(highlighted == index ? AppTheme.accent : Color.secondary.opacity(0.12))
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(highlighted == index ? 1.06 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: highlighted)
                }
            }
            .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .task {
            while !Task.isCancelled {
                for tile in sequence {
                    highlighted = tile
                    try? await Task.sleep(nanoseconds: 480_000_000)
                    highlighted = nil
                    try? await Task.sleep(nanoseconds: 180_000_000)
                }
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
        }
    }
}

private struct BreathingPreview: View {
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.14))
                    .frame(width: 160, height: 160)
                    .scaleEffect(expanded ? 1.0 : 0.6)
                Circle()
                    .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                    .frame(width: 164, height: 164)
                Text(expanded ? "Inhale" : "Exhale")
                    .font(.title3.weight(.light))
            }
            .animation(.easeInOut(duration: expanded ? 3.6 : 4.4), value: expanded)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard()
        .task {
            while !Task.isCancelled {
                expanded = true
                try? await Task.sleep(nanoseconds: 3_600_000_000)
                expanded = false
                try? await Task.sleep(nanoseconds: 4_400_000_000)
            }
        }
    }
}

private struct LanguagePreview: View {
    let language: LearnableLanguage
    @State private var card: LanguageCard
    @State private var choices: [String]
    @State private var revealed = false

    init(language: LearnableLanguage) {
        self.language = language
        // Use the instant bundled fallback so the preview needs no network.
        let sample = LanguageEngine.fallbackCard(for: language, avoiding: nil)
        _card = State(initialValue: sample)
        _choices = State(initialValue: LanguageEngine.choices(for: sample))
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(card.word)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))

            ForEach(choices, id: \.self) { choice in
                let correct = LanguageEngine.isCorrectAnswer(choice, for: card)
                HStack {
                    Text(choice)
                        .font(.headline.weight(.medium))
                    Spacer()
                    if revealed && correct {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    (revealed && correct) ? AppTheme.accentSoft : Color.secondary.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation { revealed = true }
        }
    }
}

private struct JournalingPreview: View {
    @State private var prompt = WellnessPromptEngine.fallbackPrompt()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Journaling", systemImage: "square.and.pencil")
                .font(AppTheme.Typography.captionSemibold)
                .foregroundStyle(AppTheme.accentOnChrome)

            Text(prompt.text)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("In the unlock, sit with the prompt for a few seconds, then continue.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

private struct ReadPreview: View {
    @State private var article = WikipediaReadEngine.fallbackArticle()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Read Something", systemImage: "book.fill")
                .font(AppTheme.Typography.captionSemibold)
                .foregroundStyle(AppTheme.accentOnChrome)

            Text(article.title)
                .font(AppTheme.Typography.title2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(article.extract)
                .font(AppTheme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("In the unlock, read for a few seconds, then continue. Tap for a fresh article anytime.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
