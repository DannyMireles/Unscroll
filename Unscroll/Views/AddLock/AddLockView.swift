import FamilyControls
import SwiftUI

struct AddLockView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lockStore: LockStore

    @State private var selection = FamilyActivitySelection()
    @State private var lockName: String = ""
    /// Tracks the last lock name used for launch-scheme syncing (see `onChange(of: lockName)`).
    @State private var previousLockNameForScheme: String = ""
    @State private var launchScheme: String = ""
    @State private var isPickerPresented = false
    @State private var hours = 0
    @State private var minutes = 30
    @State private var method: UnlockMethod = .mentalMath
    @State private var rewardMode: UnlockRewardMode = .incrementalByLimit
    @State private var showAdvancedLaunchOptions = false

    private enum LockFormField: Hashable {
        case lockName
        case launchScheme
    }

    @FocusState private var focusedField: LockFormField?

    private var totalMinutes: Int {
        hours * 60 + minutes
    }

    private var canSave: Bool {
        selectionItemCount > 0 && totalMinutes > 0
    }

    private var selectionItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private var hasSelection: Bool {
        selectionItemCount > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        appPickerSection
                        nameSection
                        advancedLaunchSection
                        limitSection
                        rewardModeSection
                        methodSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Lock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await lockStore.add(
                                selection: selection,
                                name: lockName,
                                launchURLScheme: launchScheme,
                                limitMinutes: totalMinutes,
                                method: method,
                                rewardMode: rewardMode
                            )
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .onChange(of: focusedField) { newValue in
                guard let new = newValue else { return }
                switch new {
                case .lockName:
                    if LockStore.shouldClearLockNameOnFocus(lockName) {
                        lockName = ""
                    }
                case .launchScheme:
                    if LockStore.shouldClearLaunchSchemeOnFocus(launchScheme, selection: selection, lockName: lockName) {
                        launchScheme = ""
                    }
                }
            }
            // Auto-populate the name whenever the user changes their app selection.
            // Application.localizedDisplayName is only populated on a fresh picker result,
            // so we capture it here before the selection is saved to disk.
            .onChange(of: selection) { newSelection in
                let suggested = LockStore.displayName(for: newSelection)
                previousLockNameForScheme = suggested
                lockName = suggested
                let trimmedScheme = launchScheme.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedScheme.isEmpty {
                    // Do not fill e.g. "selectedapp" when Screen Time only gives a generic label —
                    // that blocks later sync when the user enters the real app name.
                    if !LockStore.shouldClearLockNameOnFocus(suggested) {
                        launchScheme = LockStore.suggestedScheme(for: newSelection, fallbackName: suggested)
                    } else {
                        launchScheme = ""
                    }
                }
            }
            .onChange(of: lockName) { newName in
                let oldName = previousLockNameForScheme
                previousLockNameForScheme = newName
                let oldSuggested = LockStore.suggestedScheme(for: selection, fallbackName: oldName)
                let newSuggested = LockStore.suggestedScheme(for: selection, fallbackName: newName)
                let current = launchScheme.trimmingCharacters(in: .whitespacesAndNewlines)
                if current.isEmpty || current.caseInsensitiveCompare(oldSuggested) == .orderedSame {
                    launchScheme = newSuggested
                }
            }
        }
    }

    private var appPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "App")
            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: hasSelection ? "checkmark.circle.fill" : "app.badge")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(hasSelection ? LockStore.displayName(for: selection) : "Select apps or categories")
                            .font(.headline.weight(.medium))
                        Text(hasSelection ? "\(selectionItemCount) item\(selectionItemCount == 1 ? "" : "s") selected." : "Use Apple's secure Screen Time picker.")
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

            SelectedAppsSummaryView(selection: selection)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Lock Name")
            VStack(alignment: .leading, spacing: 6) {
                TextField("e.g. TikTok", text: $lockName)
                    .focused($focusedField, equals: .lockName)
                    .autocorrectionDisabled()
                    .glassCard()
                Text("Use the real app name as it appears on your Home Screen (e.g. TikTok, Instagram). That keeps your list clear and helps Unscroll open the right app after you unlock.")
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
                    TextField("Scheme (no ://)", text: $launchScheme)
                        .focused($focusedField, equals: .launchScheme)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .glassCard()
                    Text("Most people never need this. If the app doesn’t open after unlocking, ask a friend or search for the app’s URL scheme, then enter it here.")
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

                Text(totalMinutes == 0 ? "Choose at least 1 minute." : "Limit: \(AppLock(selection: selection, appDisplayName: "", dailyLimitMinutes: totalMinutes, unlockMethod: method).limitLabel) each day")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .glassCard()
        }
    }

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Unlock Method")
            UnlockMethodSelectionGrid(selection: $method)
        }
    }

    private var rewardModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Unlock Timing")
            VStack(alignment: .leading, spacing: 12) {
                Picker("Unlock Timing", selection: $rewardMode) {
                    ForEach(UnlockRewardMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(rewardMode.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .glassCard()
        }
    }
}

struct UnlockMethodRow: View {
    let method: UnlockMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(method.title)
                        .font(.headline.weight(.medium))
                    Text(method.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.5))
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch method {
        case .mentalMath: return "function"
        case .patternMemory: return "square.grid.3x3"
        case .breathing: return "wind"
        case .reflect: return "character.book.closed"
        case .random: return "shuffle"
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
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(.titleAndIcon)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .glassCard()
        }
    }
}

struct UnlockMethodSelectionGrid: View {
    @Binding var selection: UnlockMethod

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(UnlockMethod.challengeMethods) { option in
                    UnlockMethodTile(method: option, isSelected: selection == option) {
                        selection = option
                    }
                }
            }

            Button {
                selection = .random
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "shuffle")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("All Methods")
                            .font(.headline.weight(.medium))
                        Text("Randomly choose any unlock each time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: selection == .random ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection == .random ? AppTheme.accent : Color.secondary.opacity(0.5))
                }
                .glassCard()
            }
            .buttonStyle(.plain)
        }
    }
}

private struct UnlockMethodTile: View {
    let method: UnlockMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppTheme.accent : Color.secondary.opacity(0.5))
                }

                Text(method.shortTitle)
                    .font(.headline.weight(.medium))
                    .lineLimit(1)

                Text(method.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch method {
        case .mentalMath: return "function"
        case .patternMemory: return "square.grid.3x3"
        case .breathing: return "wind"
        case .reflect: return "character.book.closed"
        case .random: return "shuffle"
        }
    }
}
