import FamilyControls
import ManagedSettings
import SwiftUI

struct EditLockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lockStore: LockStore

    @State private var draft: AppLock
    @State private var lockName: String
    @State private var capturedAppName: String?
    @State private var isPickerPresented = false
    @State private var hours: Int
    @State private var minutes: Int
    @State private var isSaving = false

    init(lock: AppLock) {
        _draft = State(initialValue: lock)
        // Show an editable field with a placeholder rather than the "App" placeholder name.
        _lockName = State(initialValue: LockStore.isGenericDisplayName(lock.appDisplayName) ? "" : lock.appDisplayName)
        _hours = State(initialValue: lock.dailyLimitMinutes / 60)
        _minutes = State(initialValue: lock.dailyLimitMinutes % 60)
    }

    private var totalMinutes: Int { hours * 60 + minutes }

    private var canSave: Bool {
        draft.hasSelection && totalMinutes > 0 && !isSaving
    }

    private var limitLabel: String {
        AppLock(selection: draft.selection, appDisplayName: "", dailyLimitMinutes: totalMinutes, unlockMethod: draft.unlockMethod).limitLabel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        appSection
                        limitSection
                        rewardSection
                        methodSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Save Changes", isDisabled: !canSave) { save() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .background(.clear)
            }
            .navigationTitle("Edit Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $draft.selection)
            // Picking a new app pre-fills the name when iOS exposes one; the launch link
            // is derived from the confirmed name (that's what makes the lock open the app).
            .onChange(of: draft.selection) { newSelection in
                capturedAppName = nil
                let detected = LockStore.displayName(for: newSelection)
                lockName = LockStore.isGenericDisplayName(detected) ? "" : detected
                draft.launchURLScheme = LockStore.isGenericDisplayName(detected)
                    ? nil
                    : LockStore.suggestedScheme(for: newSelection, fallbackName: detected)
                Haptics.success()
            }
            .onChange(of: lockName) { newName in
                let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.appDisplayName = trimmed.isEmpty ? draft.appDisplayName : trimmed
                guard !trimmed.isEmpty, !LockStore.isGenericDisplayName(trimmed) else { return }
                if let scheme = LockStore.launchSchemes(forName: trimmed).first {
                    draft.launchURLScheme = scheme
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    // MARK: - Sections

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "App")

            Button {
                Haptics.softTap()
                isPickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    AppTokenIconView(lock: draft)
                    VStack(alignment: .leading, spacing: 3) {
                        AppTokenTitleView(lock: draft, fallbackName: displayNameForCurrentSelection)
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("\(draft.selectedItemCount) item\(draft.selectedItemCount == 1 ? "" : "s") selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .glassCard()
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                if isSingleApplicationSelection, let token = draft.selection.applicationTokens.first {
                    ApplicationTokenNameCapture(token: token) { token, name in
                        applyCapturedAppName(name, for: token)
                    }
                    .id(token.hashValue)
                }
            }

            if draft.selectedItemCount > 1 {
                SelectedAppsSummaryView(selection: draft.selection)
            }

            if isSingleApplicationSelection {
                appNameField
            }
        }
    }

    private var appNameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Which app is this?")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LockStore.commonAppNames, id: \.self) { name in
                        AppNameChip(name: name, isSelected: trimmedLockName.caseInsensitiveCompare(name) == .orderedSame) {
                            lockName = name
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
            }

            TextField("Or type its name", text: $lockName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(linkHint)
                .font(.caption)
                .foregroundStyle(linkResolves ? AppTheme.accent : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .glassCard(padding: 14)
    }

    private var trimmedLockName: String {
        lockName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var linkResolves: Bool {
        !trimmedLockName.isEmpty && !LockStore.isGenericDisplayName(trimmedLockName)
    }

    private var linkHint: String {
        guard linkResolves else {
            return "Tap your app above (or type it) so tapping this lock opens it."
        }
        return "Tapping this lock will open \(trimmedLockName)."
    }

    private var limitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Daily Limit")

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

                Text(totalMinutes > 0
                     ? "\(limitLabel) of daily use before a challenge"
                     : "Choose at least 1 minute")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .glassCard(padding: 14)
        }
    }

    private var rewardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "After an Unlock")

            VStack(spacing: 12) {
                ForEach(UnlockRewardMode.allCases) { mode in
                    BigChoiceCard(
                        title: mode.title,
                        subtitle: mode.description,
                        systemImage: mode == .incrementalByLimit ? "timer" : "sun.max.fill",
                        isSelected: draft.unlockRewardMode == mode
                    ) {
                        draft.unlockRewardMode = mode
                    }
                }
            }
        }
    }

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Unlock Method")
            UnlockMethodSelectionGrid(selection: $draft.unlockMethod)
        }
    }

    // MARK: - Actions

    private var isSingleApplicationSelection: Bool {
        draft.selection.applicationTokens.count == 1
            && draft.selection.categoryTokens.isEmpty
            && draft.selection.webDomainTokens.isEmpty
    }

    private var displayNameForCurrentSelection: String {
        if let capturedAppName {
            return capturedAppName
        }

        let detected = LockStore.displayName(for: draft.selection)
        if !LockStore.isGenericDisplayName(detected) {
            return detected
        }

        return lockName
    }

    private func applyCapturedAppName(_ name: String, for token: ApplicationToken) {
        guard isSingleApplicationSelection,
              draft.selection.applicationTokens.contains(token)
        else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !LockStore.isGenericDisplayName(trimmed) else { return }

        capturedAppName = trimmed

        // Silently self-heal the draft's name + launch link when ours is still generic.
        if LockStore.isGenericDisplayName(lockName) {
            lockName = trimmed
            draft.appDisplayName = trimmed
            if let scheme = LockStore.launchSchemes(forName: trimmed).first {
                draft.launchURLScheme = scheme
            }
        }

        NSLog("🔗 Unscroll: captured edited app label '%@'", trimmed)
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Haptics.celebrationDing()

        Task {
            draft.dailyLimitMinutes = totalMinutes

            let trimmedName = resolvedLockName()
            draft.appDisplayName = trimmedName.isEmpty
                ? LockStore.displayName(for: draft.selection)
                : trimmedName

            // Keep the launch scheme in sync with the confirmed name (so "X" → twitter).
            if let nameScheme = LockStore.launchSchemes(forName: draft.appDisplayName).first {
                draft.launchURLScheme = nameScheme
            }

            await lockStore.update(draft)
            dismiss()
        }
    }

    private func resolvedLockName() -> String {
        let trimmedName = lockName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !LockStore.isGenericDisplayName(trimmedName) {
            return trimmedName
        }

        if let capturedAppName,
           !LockStore.isGenericDisplayName(capturedAppName) {
            return capturedAppName
        }

        // Re-resolve from the selection (Apple metadata + bundle-ID mapping).
        return LockStore.displayName(for: draft.selection)
    }
}
