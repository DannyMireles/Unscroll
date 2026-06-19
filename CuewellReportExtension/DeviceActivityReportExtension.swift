import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct CuewellReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        CuewellUsageReport { summary in
            CuewellUsageReportView(summary: summary)
        }
        CuewellLockUsageReport { summary in
            CuewellLockUsageReportView(summary: summary)
        }
    }
}

/// Computed usage for the report's view. The report extension also records any app
/// identity iOS exposes while it walks the Screen Time data.
struct CuewellUsageSummary {
    var totalSeconds: Double = 0
    var hasData: Bool = false
}

private struct CuewellUsageReport: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("Cuewell App Identity Capture")
    let content: (CuewellUsageSummary) -> CuewellUsageReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> CuewellUsageSummary {
        var summary = CuewellUsageSummary()
        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                for await category in segment.categories {
                    for await applicationActivity in category.applications {
                        if let token = applicationActivity.application.token {
                            AppIdentityStore.record(
                                token: token,
                                bundleID: applicationActivity.application.bundleIdentifier,
                                displayName: applicationActivity.application.localizedDisplayName
                            )
                            NSLog(
                                "🧾 Cuewell report identity token=present bundle=%@ name=%@",
                                applicationActivity.application.bundleIdentifier ?? "nil",
                                applicationActivity.application.localizedDisplayName ?? "nil"
                            )
                        }
                        summary.hasData = true
                        summary.totalSeconds += applicationActivity.totalActivityDuration
                    }
                }
            }
        }
        return summary
    }
}

// MARK: - Per-lock usage (Today + last 7 days)

/// Computed usage shown on a lock's Info screen.
struct CuewellLockUsageSummary {
    var todaySeconds: Double = 0
    var weekSeconds: Double = 0
    var hasData: Bool = false
}

private struct CuewellLockUsageReport: DeviceActivityReportScene {
    let context = DeviceActivityReport.Context("Cuewell Lock Usage")
    let content: (CuewellLockUsageSummary) -> CuewellLockUsageReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> CuewellLockUsageSummary {
        var summary = CuewellLockUsageSummary()
        let calendar = Calendar.current
        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                let isToday = calendar.isDate(segment.dateInterval.start, inSameDayAs: Date())
                for await category in segment.categories {
                    for await applicationActivity in category.applications {
                        let duration = applicationActivity.totalActivityDuration
                        guard duration > 0 else { continue }
                        summary.hasData = true
                        summary.weekSeconds += duration
                        if isToday { summary.todaySeconds += duration }
                    }
                }
            }
        }
        return summary
    }
}

struct CuewellLockUsageReportView: View {
    let summary: CuewellLockUsageSummary

    var body: some View {
        VStack(spacing: 12) {
            row(title: "Today", seconds: summary.todaySeconds, emphasized: true)
            Divider().opacity(0.4)
            row(title: "Last 7 days", seconds: summary.weekSeconds, emphasized: false)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(title: String, seconds: Double, emphasized: Bool) -> some View {
        HStack {
            Text(title)
                .font(emphasized ? .headline : .subheadline)
                .foregroundStyle(emphasized ? .primary : .secondary)
            Spacer(minLength: 8)
            Text(formatted(seconds))
                .font(emphasized ? .title3.weight(.semibold) : .body.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private func formatted(_ seconds: Double) -> String {
        guard summary.hasData, seconds > 0 else { return "—" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}

struct CuewellUsageReportView: View {
    let summary: CuewellUsageSummary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.footnote.weight(.semibold))
            Text(label)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var label: String {
        guard summary.hasData, summary.totalSeconds > 0 else {
            return "Usage tracking is on"
        }
        let total = Int(summary.totalSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m used recently"
        }
        return "\(max(minutes, 1))m used recently"
    }
}
