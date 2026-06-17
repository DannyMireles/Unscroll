import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

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
                    .foregroundStyle(AppTheme.accentDeep)
            } else {
                Image(systemName: "app.dashed")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accentDeep)
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

/// Resolves a Screen Time token's real app name (e.g. "TikTok") by hosting Apple's
/// `Label(token)` title in an isolated, invisible hosting controller and reading the name
/// back out of that subtree's accessibility tree. App-Store-safe: only public SwiftUI
/// rendering + public UIAccessibility properties, no private APIs. iOS resolves the label
/// asynchronously, so we re-read a few times.
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
        host.view.clipsToBounds = true
        context.coordinator.host = host
        return host
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.token = token
        context.coordinator.onResolve = onResolve
        context.coordinator.scheduleReads()
    }

    private struct CaptureLabel: View {
        let token: ApplicationToken
        var body: some View {
            Label(token)
                .labelStyle(.titleOnly)
                .font(.body)
                .lineLimit(1)
                .fixedSize()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -10_000, y: 0)
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
            let delays: [TimeInterval] = [0.1, 0.35, 0.7, 1.3, 2.2, 3.4]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.generation == current else { return }
                    self.readOnce()
                }
            }
        }

        private func readOnce() {
            guard let view = host?.view else { return }
            view.setNeedsLayout()
            view.layoutIfNeeded()

            var found: [String] = []
            Self.collect(from: view, into: &found)
            if let name = found.lazy.compactMap(Self.sanitized(from:)).first {
                emit(name)
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

        private static func isGenericAppName(_ name: String) -> Bool {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else { return true }
            if ["app", "chosen app", "selected app", "selected apps", "no selection"].contains(trimmed) {
                return true
            }
            let parts = trimmed.split(separator: " ")
            if parts.count == 2, Int(parts[0]) != nil,
               ["app", "apps", "item", "items"].contains(String(parts[1])) {
                return true
            }
            return false
        }
    }
}
