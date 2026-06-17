import FamilyControls
import ManagedSettings
import SwiftUI

struct EditLockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lockStore: LockStore

    @State private var draft: AppLock
    @State private var isPickerPresented = false
    @State private var pickerCapturedAppName = ""
    @State private var hours: Int
    @State private var minutes: Int
    @State private var isSaving = false

    init(lock: AppLock) {
        _draft = State(initialValue: lock)
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
                            .flowItem(0)
                        limitSection
                            .flowItem(1)
                        rewardSection
                            .flowItem(2)
                        methodSection
                            .flowItem(3)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 116)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    PrimaryButton(title: "Save Changes", isDisabled: !canSave) { save() }
                }
                .glassBottomBarChrome()
                .flowAppear(delay: 0.08)
            }
            .navigationTitle("Edit Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .flowNavigationChrome()
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $draft.selection)
            .background {
                FamilyActivityPickerNameCapture(isActive: isPickerPresented) { name in
                    pickerCapturedAppName = name
                    applyPickerCapturedAppNameIfPossible(name)
                }
                .frame(width: 0, height: 0)
            }
            // Store whatever Screen Time exposes and let extension-captured identity
            // refine the display name / launch hint later.
            .onChange(of: draft.selection) { newSelection in
                LockStore.captureSelectionIdentities(newSelection, source: "edit.selection")
                let detected = LockStore.displayName(for: newSelection)
                draft.appDisplayName = detected
                draft.launchURLScheme = LockStore.suggestedScheme(for: newSelection, fallbackName: detected)
                applyPickerCapturedAppNameIfPossible(pickerCapturedAppName)
                Haptics.success()
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
                            .font(AppTheme.Typography.headlineMedium)
                            .foregroundStyle(.primary)
                        Text("\(draft.selectedItemCount) item\(draft.selectedItemCount == 1 ? "" : "s") selected")
                            .font(AppTheme.Typography.subheadline)
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
                    ZStack(alignment: .topLeading) {
                        ApplicationTokenNameCapture(token: token) { token, name in
                            applyCapturedAppName(name, for: token)
                        }
                        .id(token.hashValue)
                        .frame(width: 260, height: 44)

                        AppIdentityReportCapture(selection: draft.selection)
                    }
                }
            }

            if draft.selectedItemCount > 1 {
                SelectedAppsSummaryView(selection: draft.selection)
            }

            if isSingleApplicationSelection {
                SingleApplicationNote()
            }
        }
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
                    .font(AppTheme.Typography.footnoteMedium)
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
        let detected = LockStore.displayName(for: draft.selection)
        if !LockStore.isGenericDisplayName(detected) {
            return detected
        }

        return draft.appDisplayName
    }

    private func applyCapturedAppName(_ name: String, for token: ApplicationToken) {
        guard isSingleApplicationSelection,
              draft.selection.applicationTokens.contains(token)
        else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !LockStore.isGenericDisplayName(trimmed) else { return }

        AppIdentityStore.record(token: token, bundleID: nil, displayName: trimmed)
        draft.appDisplayName = trimmed
        if let scheme = LockStore.launchSchemes(forName: trimmed).first {
            draft.launchURLScheme = scheme
        }
        NSLog("🔗 Unscroll: captured edited app label '%@'", trimmed)
    }

    private func applyPickerCapturedAppNameIfPossible(_ name: String) {
        guard isSingleApplicationSelection else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !LockStore.isGenericDisplayName(trimmed),
              let token = draft.selection.applicationTokens.first
        else { return }

        applyCapturedAppName(trimmed, for: token)
        NSLog("🔗 Unscroll: captured edited picker app label '%@'", trimmed)
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Haptics.celebrationDing()

        Task {
            LockStore.captureSelectionIdentities(draft.selection, source: "edit.save")
            draft.dailyLimitMinutes = totalMinutes

            let detectedName = LockStore.displayName(for: draft.selection)
            if !LockStore.isGenericDisplayName(detectedName) || LockStore.isGenericDisplayName(draft.appDisplayName) {
                draft.appDisplayName = detectedName
            }
            draft.launchURLScheme = LockStore.suggestedScheme(for: draft.selection, fallbackName: draft.appDisplayName)

            await lockStore.update(draft)
            dismiss()
        }
    }
}
