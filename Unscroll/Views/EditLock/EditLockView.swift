import FamilyControls
import SwiftUI

struct EditLockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lockStore: LockStore

    @State private var draft: AppLock
    @State private var previousLockNameForScheme: String
    @State private var isPickerPresented = false
    @State private var hours: Int
    @State private var minutes: Int
    @State private var showAdvancedLaunchOptions: Bool

    private enum LockFormField: Hashable {
        case lockName
        case launchScheme
    }

    @FocusState private var focusedField: LockFormField?

    init(lock: AppLock) {
        _draft = State(initialValue: lock)
        _previousLockNameForScheme = State(initialValue: lock.appDisplayName)
        _hours = State(initialValue: lock.dailyLimitMinutes / 60)
        _minutes = State(initialValue: lock.dailyLimitMinutes % 60)
        let suggested = LockStore.suggestedScheme(for: lock.selection, fallbackName: lock.appDisplayName)
        let current = (lock.launchURLScheme ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let needsAdvanced = !current.isEmpty && current.caseInsensitiveCompare(suggested) != .orderedSame
        _showAdvancedLaunchOptions = State(initialValue: needsAdvanced)
    }

    private var totalMinutes: Int {
        hours * 60 + minutes
    }

    private var canSave: Bool {
        draft.hasSelection && totalMinutes > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        appSection
                        nameSection
                        advancedLaunchSection
                        limitSection
                        rewardModeSection
                        methodSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            draft.dailyLimitMinutes = totalMinutes
                            // Only fall back to displayName if the user cleared the field.
                            if draft.appDisplayName.trimmingCharacters(in: .whitespaces).isEmpty {
                                draft.appDisplayName = LockStore.displayName(for: draft.selection)
                            }
                            await lockStore.update(draft)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $draft.selection)
            .onChange(of: focusedField) { newValue in
                guard let new = newValue else { return }
                switch new {
                case .lockName:
                    if LockStore.shouldClearLockNameOnFocus(draft.appDisplayName) {
                        draft.appDisplayName = ""
                    }
                case .launchScheme:
                    let scheme = draft.launchURLScheme ?? ""
                    if LockStore.shouldClearLaunchSchemeOnFocus(scheme, selection: draft.selection, lockName: draft.appDisplayName) {
                        draft.launchURLScheme = ""
                    }
                }
            }
            // When the user picks a new app set, refresh the name from Application metadata
            // (only populated on a fresh picker result, not after JSON decode).
            .onChange(of: draft.selection) { newSelection in
                let suggested = LockStore.displayName(for: newSelection)
                previousLockNameForScheme = suggested
                draft.appDisplayName = suggested
                let trimmedScheme = draft.launchURLScheme?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if trimmedScheme.isEmpty {
                    if !LockStore.shouldClearLockNameOnFocus(suggested) {
                        draft.launchURLScheme = LockStore.suggestedScheme(for: newSelection, fallbackName: suggested)
                    } else {
                        draft.launchURLScheme = nil
                    }
                }
            }
            .onChange(of: draft.appDisplayName) { newName in
                let oldName = previousLockNameForScheme
                previousLockNameForScheme = newName
                let oldSuggested = LockStore.suggestedScheme(for: draft.selection, fallbackName: oldName)
                let newSuggested = LockStore.suggestedScheme(for: draft.selection, fallbackName: newName)
                let current = draft.launchURLScheme?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if current.isEmpty || current.caseInsensitiveCompare(oldSuggested) == .orderedSame {
                    draft.launchURLScheme = newSuggested.isEmpty ? nil : newSuggested
                }
            }
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "App")
            Button { isPickerPresented = true } label: {
                HStack(spacing: 12) {
                    AppTokenIconView(lock: draft)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LockStore.displayName(for: draft.selection))
                            .font(.headline.weight(.medium))
                        Text("\(draft.selectedItemCount) item\(draft.selectedItemCount == 1 ? "" : "s") selected.")
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

            SelectedAppsSummaryView(selection: draft.selection)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Lock Name")
            VStack(alignment: .leading, spacing: 6) {
                TextField("e.g. TikTok", text: $draft.appDisplayName)
                    .focused($focusedField, equals: .lockName)
                    .autocorrectionDisabled()
                    .glassCard()
                Text("Use the real app name as it appears on your Home Screen. That helps Unscroll open the correct app after you unlock.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var advancedLaunchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvancedLaunchOptions.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.accent.opacity(0.9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Advanced")
                            .font(.subheadline.weight(.semibold))
                        Text("Custom URL scheme — only if “Open app” fails")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showAdvancedLaunchOptions ? 90 : 0))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if showAdvancedLaunchOptions {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Scheme (no ://)", text: Binding(
                        get: { draft.launchURLScheme ?? "" },
                        set: { draft.launchURLScheme = $0 }
                    ))
                    .focused($focusedField, equals: .launchScheme)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .glassCard()
                    Text("Most people never need this. Enter a custom scheme only if opening the app after unlock doesn’t work.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var limitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Daily Limit")
            VStack(spacing: 10) {
                Stepper(value: $hours, in: 0...12) {
                    HStack {
                        Text("Hours")
                        Spacer()
                        Text("\(hours)")
                            .foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $minutes, in: 0...55, step: 5) {
                    HStack {
                        Text("Minutes")
                        Spacer()
                        Text("\(minutes)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .glassCard()
        }
    }

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Unlock Method")
            UnlockMethodSelectionGrid(selection: $draft.unlockMethod)
        }
    }

    private var rewardModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Unlock Timing")
            VStack(alignment: .leading, spacing: 12) {
                Picker("Unlock Timing", selection: $draft.unlockRewardMode) {
                    ForEach(UnlockRewardMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(draft.unlockRewardMode.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .glassCard()
        }
    }
}
