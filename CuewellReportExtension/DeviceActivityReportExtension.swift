import DeviceActivity
import ExtensionKit
import SwiftUI

@main
struct CuewellReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        CuewellUsageReport { summary in
            CuewellUsageReportView(summary: summary)
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
