import Combine
import SafariServices
import SwiftUI
import UIKit

// NOTE: This file hosts the redesigned unlock activity views (Activity chooser, Read,
// Mindfulness, Go Outside). The filename is kept to avoid Xcode project surgery.

// MARK: - Dwell persistence

/// Remembers, per lock + activity, the wall-clock instant at which a link-out activity's
/// minimum dwell is satisfied. Persisting the *deadline* (not a running counter) means the
/// countdown reflects real elapsed time no matter what happens in between: the user can leave
/// to read in Safari or meditate in YouTube, the phone can sleep, and iOS can even terminate
/// Cuewell while it's backgrounded — when they return to the same activity, the timer resumes
/// from where it really is (or is already complete) instead of resetting to full.
enum DwellStore {
    private static let key = "cuewell.dwell.deadlines"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppConstants.appGroupIdentifier) }

    private static func entryKey(lock: UUID, method: UnlockMethod) -> String {
        "\(lock.uuidString)|\(method.rawValue)"
    }

    static func deadline(lock: UUID, method: UnlockMethod) -> Date? {
        guard let map = defaults?.dictionary(forKey: key) as? [String: Double],
              let timestamp = map[entryKey(lock: lock, method: method)] else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Starts (or restarts) the dwell for this lock + activity and returns the new deadline.
    @discardableResult
    static func start(lock: UUID, method: UnlockMethod, seconds: Int) -> Date {
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        var map = (defaults?.dictionary(forKey: key) as? [String: Double]) ?? [:]
        // Drop anything more than a day old so this never grows unbounded.
        let cutoff = Date().addingTimeInterval(-86_400).timeIntervalSince1970
        map = map.filter { $0.value > cutoff }
        map[entryKey(lock: lock, method: method)] = deadline.timeIntervalSince1970
        defaults?.set(map, forKey: key)
        return deadline
    }

    static func clear(lock: UUID, method: UnlockMethod) {
        guard var map = defaults?.dictionary(forKey: key) as? [String: Double] else { return }
        map.removeValue(forKey: entryKey(lock: lock, method: method))
        defaults?.set(map, forKey: key)
    }
}

// MARK: - Activity chooser

/// Shown when a lock has more than one activity. Lets the user pick which one to do now,
/// instead of getting a random one (which is wrong for heterogeneous activities — you can't
/// force "Go Outside" at midnight).
struct ActivityChooserView: View {
    let lock: AppLock
    let onPick: (UnlockMethod) -> Void

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Choose your activity",
            subtitle: "Pick one to earn more time on \(displayName)."
        ) {
            VStack(spacing: 12) {
                ForEach(lock.unlockMethods) { method in
                    Button {
                        Haptics.softTap()
                        onPick(method)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: method.systemImage)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.accentOnChrome)
                                .frame(width: 42, height: 42)
                                .background(AppTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(method.title)
                                    .font(AppTheme.Typography.headlineMedium)
                                    .foregroundStyle(.primary)
                                Text(method.tagline)
                                    .font(AppTheme.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                                .stroke(AppTheme.chromeStroke, lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var displayName: String {
        LockStore.isGenericDisplayName(lock.appDisplayName) ? "your app" : lock.appDisplayName
    }
}

// MARK: - Read

struct ReadUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var article: ReadArticle?
    @State private var isLoading = true
    @State private var hasOpened = false
    @State private var canContinue = false
    @State private var secondsLeft = ReadUnlockView.dwellSeconds
    @State private var dwellDeadline: Date?
    @State private var showReader = false

    /// Ticks every second on the common run-loop mode so the visible countdown keeps moving
    /// while a sheet is up or the list is scrolling. It pauses while backgrounded and resumes
    /// on return; because progress is derived from a wall-clock deadline, the displayed value
    /// snaps to the correct remaining time on the very next tick.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let dwellSeconds = 45

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Read something worth your time.",
            subtitle: "A fresh piece from a topic you chose."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding today's read…")
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else if let article {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(article.source.uppercased())
                            .font(AppTheme.Typography.captionSemibold)
                            .foregroundStyle(AppTheme.accentOnChrome)
                        Text(article.title)
                            .font(AppTheme.Typography.title2)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let summary = article.summary {
                            Text(summary)
                                .font(AppTheme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)

                    PrimaryButton(title: hasOpened ? "Keep reading" : "Open article") {
                        Haptics.softTap()
                        openArticle()
                    }
                }

                SecondaryActionButton(
                    title: "Different article",
                    icon: "arrow.triangle.2.circlepath",
                    isDisabled: isLoading
                ) {
                    Task { await loadDifferent() }
                }

                Button {
                    Haptics.success()
                    DwellStore.clear(lock: lock.id, method: .read)
                    onComplete()
                } label: {
                    Text(continueLabel)
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.5)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(canContinue ? AppTheme.accentOnChrome : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            }
        }
        .animation(AppTheme.Motion.reveal, value: isLoading)
        .animation(AppTheme.Motion.quick, value: canContinue)
        .animation(AppTheme.Motion.quick, value: hasOpened)
        .task { await loadInitial() }
        .onAppear { restoreDwellIfNeeded() }
        .onReceive(ticker) { _ in updateDwellProgress() }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            updateDwellProgress()
        }
        .sheet(isPresented: $showReader) {
            if let article { SafariView(url: article.url) }
        }
    }

    private var continueLabel: String {
        if canContinue { return "I'm done, unlock" }
        if hasOpened { return "Keep reading… \(secondsLeft)s" }
        return "Open the article first"
    }

    /// First appearance: fetch an article, then resume any dwell already in progress for this
    /// lock (e.g. the user opened the article, left to read, and came back).
    @MainActor
    private func loadInitial() async {
        isLoading = true
        article = await ArticleFeedEngine.nextArticle()
        isLoading = false
        restoreDwellIfNeeded()
    }

    /// "Different article" — the user wants a new read, so the dwell starts over.
    @MainActor
    private func loadDifferent() async {
        resetDwell()
        isLoading = true
        article = await ArticleFeedEngine.nextArticle()
        isLoading = false
    }

    private func openArticle() {
        showReader = true
        guard !hasOpened else { return }
        hasOpened = true
        dwellDeadline = DwellStore.start(lock: lock.id, method: .read, seconds: Self.dwellSeconds)
        updateDwellProgress()
    }

    /// If a dwell deadline survived from before (backgrounding, or even a full app restart),
    /// pick it back up so the countdown continues instead of resetting.
    private func restoreDwellIfNeeded() {
        guard !hasOpened, let deadline = DwellStore.deadline(lock: lock.id, method: .read) else { return }
        hasOpened = true
        dwellDeadline = deadline
        updateDwellProgress()
    }

    private func resetDwell() {
        DwellStore.clear(lock: lock.id, method: .read)
        hasOpened = false
        canContinue = false
        secondsLeft = Self.dwellSeconds
        dwellDeadline = nil
    }

    private func updateDwellProgress(now: Date = Date()) {
        guard hasOpened, !canContinue else { return }
        guard let dwellDeadline else {
            finishDwell()
            return
        }

        let remaining = max(0, Int(ceil(dwellDeadline.timeIntervalSince(now))))
        secondsLeft = remaining
        if remaining == 0 {
            finishDwell()
        }
    }

    private func finishDwell() {
        guard !canContinue else { return }
        secondsLeft = 0
        canContinue = true
        Haptics.success()
    }
}

// MARK: - Mindfulness

struct MindfulnessUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var session = MindfulnessSourceEngine.nextSession()
    @State private var hasOpened = false
    @State private var canContinue = false
    @State private var secondsLeft = MindfulnessUnlockView.dwellSeconds
    @State private var dwellDeadline: Date?

    /// See `ReadUnlockView.ticker` — keeps the visible countdown moving and self-corrects from
    /// the wall-clock deadline on the next tick after returning from a backgrounded session.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private static let dwellSeconds = 90

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Take a few minutes for yourself.",
            subtitle: "A short, free guided session."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(session.type.title, systemImage: session.type.systemImage)
                        .font(AppTheme.Typography.captionSemibold)
                        .foregroundStyle(AppTheme.accentOnChrome)
                    Text(session.title)
                        .font(AppTheme.Typography.title2)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(session.source)
                        .font(AppTheme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)

                PrimaryButton(title: hasOpened ? "Back to session" : "Start session") {
                    Haptics.softTap()
                    openSession()
                }

                SecondaryActionButton(
                    title: "Different session",
                    icon: "arrow.triangle.2.circlepath",
                    isDisabled: false
                ) {
                    Haptics.softTap()
                    resetDwell()
                    session = MindfulnessSourceEngine.nextSession()
                }

                Button {
                    Haptics.success()
                    DwellStore.clear(lock: lock.id, method: .mindful)
                    onComplete()
                } label: {
                    Text(continueLabel)
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.5)
                .font(AppTheme.Typography.headline)
                .foregroundStyle(canContinue ? AppTheme.accentOnChrome : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous))
            }
        }
        .animation(AppTheme.Motion.quick, value: canContinue)
        .animation(AppTheme.Motion.quick, value: hasOpened)
        .onAppear { restoreDwellIfNeeded() }
        .onReceive(ticker) { _ in updateDwellProgress() }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            updateDwellProgress()
        }
    }

    private var continueLabel: String {
        if canContinue { return "I'm done, unlock" }
        if hasOpened { return "Stay a moment… \(secondsLeft)s" }
        return "Start the session first"
    }

    private func openSession() {
        openURL(session.url)
        guard !hasOpened else { return }
        hasOpened = true
        dwellDeadline = DwellStore.start(lock: lock.id, method: .mindful, seconds: Self.dwellSeconds)
        updateDwellProgress()
    }

    /// Resume a dwell that was already running for this session activity (the user started it,
    /// left for YouTube/Safari, and came back — even if Cuewell was terminated in between).
    private func restoreDwellIfNeeded() {
        guard !hasOpened, let deadline = DwellStore.deadline(lock: lock.id, method: .mindful) else { return }
        hasOpened = true
        dwellDeadline = deadline
        updateDwellProgress()
    }

    private func resetDwell() {
        DwellStore.clear(lock: lock.id, method: .mindful)
        hasOpened = false
        canContinue = false
        secondsLeft = Self.dwellSeconds
        dwellDeadline = nil
    }

    private func updateDwellProgress(now: Date = Date()) {
        guard hasOpened, !canContinue else { return }
        guard let dwellDeadline else {
            finishDwell()
            return
        }

        let remaining = max(0, Int(ceil(dwellDeadline.timeIntervalSince(now))))
        secondsLeft = remaining
        if remaining == 0 {
            finishDwell()
        }
    }

    private func finishDwell() {
        guard !canContinue else { return }
        secondsLeft = 0
        canContinue = true
        Haptics.success()
    }
}

// MARK: - Go Outside

struct OutsideUnlockView: View {
    let lock: AppLock
    let onComplete: () -> Void

    @State private var showCamera = false
    @State private var status: Status = .idle

    private enum Status: Equatable {
        case idle
        case checking
        case failed(String)
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        UnlockScreenScaffold(
            lock: lock,
            title: "Go outside.",
            subtitle: "Step out, point your camera at nature, the sky, or your street, and take the shot."
        ) {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.cornerLarge, style: .continuous)
                        .fill(AppTheme.accentSoft)
                        .frame(height: 150)
                    VStack(spacing: 8) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(AppTheme.accentOnChrome)
                        Text(statusText)
                            .font(AppTheme.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if case .checking = status {
                    ProgressView().padding(.bottom, 2)
                }

                Button {
                    Haptics.softTap()
                    showCamera = true
                } label: {
                    Label(isChecking ? "Checking…" : "Open camera", systemImage: "camera.fill")
                        .font(AppTheme.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: AppTheme.cornerMedium, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isChecking || !cameraAvailable)

                Text(cameraAvailable
                     ? "The photo is taken right here in Cuewell, so it's always fresh. We check it privately on your device, and it never leaves your phone."
                     : "Open Cuewell on your iPhone to use the camera for this activity.")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(AppTheme.Motion.reveal, value: status)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                if let image { verify(image) }
            }
            .ignoresSafeArea()
        }
    }

    private var isChecking: Bool { status == .checking }

    private var statusIcon: String {
        switch status {
        case .idle: return "sun.max.fill"
        case .checking: return "hourglass"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusText: String {
        switch status {
        case .idle: return "Take a photo of where you are right now."
        case .checking: return "Checking your photo…"
        case .failed(let reason): return reason
        }
    }

    private func verify(_ image: UIImage) {
        status = .checking
        Task {
            let result = await OutdoorVerifier.verify(image)
            await MainActor.run {
                switch result {
                case .success:
                    Haptics.success()
                    onComplete()
                default:
                    Haptics.retry()
                    status = .failed(result.failureReason ?? "Give it another try.")
                }
            }
        }
    }
}

/// Live in-app camera capture for the Go Outside activity. Using the camera (rather than the
/// photo library) guarantees the shot is taken right now, so old photos can't be reused.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}

// MARK: - Shared

/// A soft secondary action used inside unlock cards (e.g. "Different article").
struct SecondaryActionButton: View {
    let title: String
    let icon: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.softTap()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(AppTheme.Typography.subheadlineMedium)
                .foregroundStyle(isDisabled ? .secondary : AppTheme.accentOnChrome)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(AppTheme.accentSoft.opacity(isDisabled ? 0.4 : 1), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

/// In-app reader for article link-outs.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
