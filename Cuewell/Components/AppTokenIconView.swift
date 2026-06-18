import FamilyControls
import DeviceActivity
import Foundation
import ManagedSettings
import SwiftUI
import UIKit
import Vision

struct AppTokenIconView: View {
    let lock: AppLock

    var body: some View {
        SelectionTokenIcon(
            applicationTokens: lock.selection.applicationTokens,
            categoryTokens: lock.selection.categoryTokens,
            webDomainCount: lock.selectedWebDomainCount,
            selectedItemCount: lock.selectedItemCount
        )
    }
}

struct SelectionTokenIcon: View {
    let applicationTokens: Set<ApplicationToken>
    let categoryTokens: Set<ActivityCategoryToken>
    let webDomainCount: Int
    let selectedItemCount: Int

    init(selection: FamilyActivitySelection) {
        self.applicationTokens = selection.applicationTokens
        self.categoryTokens = selection.categoryTokens
        self.webDomainCount = selection.webDomainTokens.count
        self.selectedItemCount = selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    init(
        applicationTokens: Set<ApplicationToken>,
        categoryTokens: Set<ActivityCategoryToken>,
        webDomainCount: Int,
        selectedItemCount: Int
    ) {
        self.applicationTokens = applicationTokens
        self.categoryTokens = categoryTokens
        self.webDomainCount = webDomainCount
        self.selectedItemCount = selectedItemCount
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.accentSoft)
                .frame(width: 48, height: 48)

            if let appToken = applicationTokens.first {
                Label(appToken)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            } else if let categoryToken = categoryTokens.first {
                Label(categoryToken)
                    .labelStyle(.iconOnly)
                    .frame(width: 28, height: 28)
            } else if webDomainCount > 0 {
                Image(systemName: "globe")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentOnChrome)
            } else {
                Image(systemName: "app.dashed")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentOnChrome)
            }

            if selectedItemCount > 1 {
                Text("\(selectedItemCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppTheme.accentDeep, in: Capsule())
                    .offset(x: 17, y: -17)
            }
        }
        .accessibilityHidden(true)
    }
}

struct AppTokenTitleView: View {
    let lock: AppLock
    var fallbackName: String?

    var body: some View {
        SelectionTokenTitleView(
            applicationTokens: lock.selection.applicationTokens,
            categoryTokens: lock.selection.categoryTokens,
            webDomainCount: lock.selectedWebDomainCount,
            selectedItemCount: lock.selectedItemCount,
            fallbackName: fallbackName ?? lock.appDisplayName
        )
    }
}

struct SelectionTokenTitleView: View {
    let applicationTokens: Set<ApplicationToken>
    let categoryTokens: Set<ActivityCategoryToken>
    let webDomainCount: Int
    let selectedItemCount: Int
    let fallbackName: String

    var body: some View {
        HStack(spacing: 4) {
            if let appToken = applicationTokens.first {
                Label(appToken)
                    .labelStyle(.titleOnly)
            } else if let categoryToken = categoryTokens.first {
                Label(categoryToken)
                    .labelStyle(.titleOnly)
            } else {
                Text(fallbackName)
            }

            if selectedItemCount > 1 {
                Text("+ \(selectedItemCount - 1)")
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }
}

/// Resolves a Screen Time token's visible app name by rendering Apple's own
/// `Label(token)` title in an isolated, nearly invisible host and reading the
/// resolved text from that host's accessibility tree, then falling back to on-device OCR.
struct ApplicationTokenNameCapture: UIViewControllerRepresentable {
    let token: ApplicationToken
    let onResolve: (ApplicationToken, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(token: token, onResolve: onResolve)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIHostingController(rootView: CaptureLabel(token: token))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.alpha = 0.02
        host.view.clipsToBounds = false
        host.view.frame = CGRect(x: 0, y: 0, width: 260, height: 44)
        context.coordinator.host = host
        context.coordinator.scheduleReads()
        NSLog("🔎 Cuewell token label capture mounted")
        return host
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.token = token
        context.coordinator.onResolve = onResolve
        controller.view.frame = CGRect(x: 0, y: 0, width: 260, height: 44)
        context.coordinator.scheduleReads()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: UIViewController,
        context: Context
    ) -> CGSize? {
        CGSize(width: 260, height: 44)
    }

    private struct CaptureLabel: View {
        let token: ApplicationToken

        var body: some View {
            Label(token)
                .labelStyle(.titleOnly)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 8)
                .frame(width: 260, height: 44, alignment: .leading)
                // No persistent fill — the OCR snapshot temporarily forces a white background
                // when it actually reads the name, so on screen this stays invisible instead of
                // leaving a faint white card behind the lock cards.
                .background(Color.clear)
        }
    }

    final class Coordinator {
        var token: ApplicationToken
        var onResolve: (ApplicationToken, String) -> Void
        weak var host: UIViewController?
        private var generation = 0
        private var emitted = Set<String>()

        init(token: ApplicationToken, onResolve: @escaping (ApplicationToken, String) -> Void) {
            self.token = token
            self.onResolve = onResolve
        }

        func scheduleReads() {
            generation += 1
            let current = generation
            let delays: [TimeInterval] = [0.1, 0.35, 0.7, 1.3, 2.2, 3.4, 5.0, 8.0, 12.0]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.generation == current else { return }
                    self.readOnce(delay: delay)
                }
            }
        }

        private func readOnce(delay: TimeInterval) {
            guard let view = host?.view else { return }
            view.setNeedsLayout()
            view.layoutIfNeeded()

            var found: [String] = []
            Self.collect(from: view, into: &found)
            if let name = found.lazy.compactMap(Self.sanitized(from:)).first {
                emit(name)
            } else if let image = Self.snapshot(from: view) {
                let currentGeneration = generation
                Self.recognizeText(in: image) { [weak self] names in
                    guard let self, self.generation == currentGeneration else { return }
                    for name in names {
                        if let sanitized = Self.sanitized(from: name) {
                            NSLog("🔎 Cuewell token OCR captured '%@'", sanitized)
                            self.emit(sanitized)
                            return
                        }
                    }
                    if delay == 0.7 || delay == 3.4 || delay == 12.0 {
                        NSLog("🔎 Cuewell token OCR empty at %.1fs raw=[%@]", delay, names.prefix(4).joined(separator: " | "))
                    }
                }
            } else if delay == 0.7 || delay == 3.4 || delay == 12.0 {
                let sample = found.prefix(4).joined(separator: " | ")
                NSLog("🔎 Cuewell token label capture empty at %.1fs raw=[%@]", delay, sample)
            }
        }

        private func emit(_ name: String) {
            let key = name.lowercased()
            guard !emitted.contains(key) else { return }
            emitted.insert(key)
            onResolve(token, name)
        }

        private static func collect(from view: UIView, into out: inout [String], depth: Int = 0) {
            guard depth <= 14 else { return }

            if let label = view.accessibilityLabel, !label.isEmpty { out.append(label) }
            if let value = view.accessibilityValue, !value.isEmpty { out.append(value) }

            if let elements = view.accessibilityElements {
                for element in elements {
                    if let object = element as? NSObject {
                        if let label = object.accessibilityLabel, !label.isEmpty { out.append(label) }
                        if let value = object.accessibilityValue, !value.isEmpty { out.append(value) }
                    }
                }
            }

            for subview in view.subviews {
                collect(from: subview, into: &out, depth: depth + 1)
            }
        }

        private static func sanitized(from rawValue: String) -> String? {
            var candidate = rawValue
                .replacingOccurrences(of: "\u{00a0}", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty else { return nil }

            if let firstLine = candidate.components(separatedBy: .newlines).first {
                candidate = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let commaRange = candidate.range(of: ",") {
                candidate = String(candidate[..<commaRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard !candidate.isEmpty, candidate.count <= 40, !isGenericAppName(candidate) else {
                return nil
            }

            let rejected = ["selected", "no selection", "tap to", "double tap"]
            let normalized = candidate.lowercased()
            guard !rejected.contains(where: { normalized.contains($0) }) else { return nil }

            return candidate
        }

        private static func snapshot(from view: UIView) -> UIImage? {
            guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }

            let oldAlpha = view.alpha
            let oldBackground = view.backgroundColor
            view.alpha = 1
            view.backgroundColor = .white
            view.setNeedsLayout()
            view.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.scale = UIScreen.main.scale
            format.opaque = true
            let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: format)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(view.bounds)
                view.layer.render(in: context.cgContext)
            }

            view.alpha = oldAlpha
            view.backgroundColor = oldBackground
            return image
        }

        private static func recognizeText(in image: UIImage, completion: @escaping ([String]) -> Void) {
            guard let cgImage = image.cgImage else {
                completion([])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, _ in
                    let names = (request.results as? [VNRecognizedTextObservation])?
                        .compactMap { $0.topCandidates(1).first?.string } ?? []
                    DispatchQueue.main.async {
                        completion(names)
                    }
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false

                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                } catch {
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }

        private static func isGenericAppName(_ name: String) -> Bool {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else { return true }
            if ["app", "chosen app", "selected app", "selected apps", "no selection"].contains(trimmed) {
                return true
            }
            let parts = trimmed.split(separator: " ")
            if parts.count == 2,
               Int(parts[0]) != nil,
               ["app", "apps", "item", "items"].contains(String(parts[1])) {
                return true
            }
            return false
        }
    }
}

struct AppIdentityReportCapture: View {
    let selection: FamilyActivitySelection

    var body: some View {
        if #available(iOS 16.0, *),
           selection.applicationTokens.count == 1,
           selection.categoryTokens.isEmpty,
           selection.webDomainTokens.isEmpty {
            DeviceActivityReport(reportContext, filter: reportFilter)
                .frame(width: 1, height: 1)
                .opacity(0.02)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onAppear {
                    NSLog("🧾 Cuewell report capture mounted applications=%d", selection.applicationTokens.count)
                }
        }
    }

    @available(iOS 16.0, *)
    private var reportContext: DeviceActivityReport.Context {
        DeviceActivityReport.Context("Cuewell App Identity Capture")
    }

    @available(iOS 16.0, *)
    private var reportFilter: DeviceActivityFilter {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let interval = DateInterval(start: start, end: Date())
        return DeviceActivityFilter(
            segment: .daily(during: interval),
            devices: .all,
            applications: selection.applicationTokens
        )
    }
}

/// Captures the visible app title from Apple's FamilyActivityPicker while it is on screen.
/// The picker can render names that are not exposed later through `FamilyActivitySelection`,
/// so this gives us an automatic, user-visible title without asking for manual input.
struct FamilyActivityPickerNameCapture: UIViewRepresentable {
    var isActive: Bool
    let onResolve: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResolve: onResolve)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onResolve = onResolve
        context.coordinator.setActive(isActive)
    }

    final class Coordinator {
        var onResolve: (String) -> Void
        private var generation = 0
        private var emitted = Set<String>()

        init(onResolve: @escaping (String) -> Void) {
            self.onResolve = onResolve
        }

        func setActive(_ active: Bool) {
            generation += 1
            guard active else { return }

            let current = generation
            let delays: [TimeInterval] = [0.2, 0.45, 0.8, 1.2, 1.8, 2.6, 3.6, 5.0, 7.0]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.generation == current else { return }
                    self.scan(delay: delay)
                }
            }
        }

        private func scan(delay: TimeInterval) {
            let raw = Self.collectVisibleAccessibilityText()
            let ranked = Self.rankedCandidates(from: raw)
            if let chosen = ranked.first?.name {
                emit(chosen)
            } else if delay == 0.8 || delay == 3.6 {
                NSLog(
                    "🧭 Cuewell picker label capture empty at %.1fs raw=[%@]",
                    delay,
                    raw.prefix(8).joined(separator: " | ")
                )
            }
        }

        private func emit(_ name: String) {
            let key = name.lowercased()
            guard emitted.insert(key).inserted else { return }
            NSLog("🧭 Cuewell picker captured visible app label '%@'", name)
            onResolve(name)
        }

        private static func collectVisibleAccessibilityText() -> [String] {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap(\.windows).filter { !$0.isHidden && $0.alpha > 0.01 }
            var values: [String] = []
            for window in windows {
                collect(from: window, into: &values)
            }
            return values
        }

        private static func collect(from view: UIView, into out: inout [String], depth: Int = 0) {
            guard depth <= 18, !view.isHidden, view.alpha > 0.01 else { return }

            append(view.accessibilityLabel, to: &out)
            append(view.accessibilityValue, to: &out)

            if let label = view as? UILabel {
                append(label.text, to: &out)
            }
            if let button = view as? UIButton {
                append(button.currentTitle, to: &out)
            }

            if let elements = view.accessibilityElements {
                for element in elements {
                    guard let object = element as? NSObject else { continue }
                    append(object.accessibilityLabel, to: &out)
                    append(object.accessibilityValue, to: &out)
                }
            }

            for subview in view.subviews {
                collect(from: subview, into: &out, depth: depth + 1)
            }
        }

        private static func append(_ value: String?, to out: inout [String]) {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return }
            out.append(value)
        }

        private struct RankedCandidate {
            let name: String
            let score: Int
        }

        private static func rankedCandidates(from rawValues: [String]) -> [RankedCandidate] {
            var bestByName: [String: RankedCandidate] = [:]
            for raw in rawValues {
                for name in candidateNames(from: raw) {
                    let key = name.lowercased()
                    let score = score(raw: raw, name: name)
                    let candidate = RankedCandidate(name: name, score: score)
                    if let existing = bestByName[key], existing.score >= score {
                        continue
                    }
                    bestByName[key] = candidate
                }
            }
            return bestByName.values.sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.name.count < rhs.name.count
            }
        }

        private static func candidateNames(from raw: String) -> [String] {
            let normalizedRaw = raw
                .replacingOccurrences(of: "\u{00a0}", with: " ")
                .replacingOccurrences(of: "✓", with: " ")
                .replacingOccurrences(of: "✔", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let separators = CharacterSet(charactersIn: ",\n")
            return normalizedRaw
                .components(separatedBy: separators)
                .compactMap(sanitizedCandidate)
        }

        private static func sanitizedCandidate(_ value: String) -> String? {
            var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty else { return nil }

            let removableWords = [
                "not selected", "selected", "button", "image", "icon", "checkbox",
                "app", "apps", "application", "applications"
            ]
            for word in removableWords {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
                candidate = candidate.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: [.caseInsensitive, .regularExpression]
                )
            }
            candidate = candidate
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".:-"))

            guard candidate.count >= 2, candidate.count <= 42 else { return nil }
            guard !isBlocked(candidate) else { return nil }
            guard candidate.rangeOfCharacter(from: .letters) != nil else { return nil }
            return candidate
        }

        private static func score(raw: String, name: String) -> Int {
            var score = 0
            let lowerRaw = raw.lowercased()
            if (lowerRaw.contains("selected") && !lowerRaw.contains("not selected"))
                || lowerRaw.contains("✓")
                || lowerRaw.contains("✔") {
                score += 100
            }
            if name.count <= 18 {
                score += 4
            }
            return score
        }

        private static func isBlocked(_ name: String) -> Bool {
            let normalized = name.lowercased()
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let blockedExact: Set<String> = [
                "choose", "choose an", "choose an app", "which app", "new lock",
                "cancel", "done", "search", "clear text", "back", "close",
                "not",
                "categories", "category", "websites", "website", "screen time",
                "activity", "family activity", "select", "selection", "no selection",
                "all", "none", "show more", "show less", "continue", "create lock",
                "social", "games", "entertainment", "creativity", "productivity",
                "education", "information & reading", "shopping & food",
                "health & fitness", "travel", "utilities", "other"
            ]
            if blockedExact.contains(normalized) { return true }

            let blockedFragments = [
                "pick the app", "tap choose", "when shielded", "go to activity",
                "daily limit", "family controls", "activity picker", "selected categor"
            ]
            return blockedFragments.contains { normalized.contains($0) }
        }
    }
}
