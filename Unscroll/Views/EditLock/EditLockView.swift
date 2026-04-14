import FamilyControls
import SwiftUI

struct EditLockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lockStore: LockStore

    @State private var draft: AppLock
    @State private var isPickerPresented = false
    @State private var hours: Int
    @State private var minutes: Int

    init(lock: AppLock) {
        _draft = State(initialValue: lock)
        _hours = State(initialValue: lock.dailyLimitMinutes / 60)
        _minutes = State(initialValue: lock.dailyLimitMinutes % 60)
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
                            draft.appDisplayName = LockStore.displayName(for: draft.selection)
                            await lockStore.update(draft)
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $draft.selection)
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
