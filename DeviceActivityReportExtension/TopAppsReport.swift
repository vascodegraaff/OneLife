import DeviceActivity
import SwiftUI
import ManagedSettings
import FamilyControls

// MARK: - App Activity Info
struct AppActivityInfo: Identifiable, Hashable {
    let id = UUID()
    let applicationToken: ApplicationToken
    let durationInMinutes: Double
    let numberOfPickups: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AppActivityInfo, rhs: AppActivityInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Top Apps Configuration
struct TopAppsConfiguration {
    let apps: [AppActivityInfo]
    let totalDurationInMinutes: Double
}

// MARK: - Top Apps Report Scene
struct TopAppsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .topApps

    let content: (TopAppsConfiguration) -> TopAppsView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TopAppsConfiguration {
        var appActivities: [ApplicationToken: (duration: TimeInterval, pickups: Int)] = [:]
        var totalDuration: TimeInterval = 0

        // Iterate through the activity data
        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration

                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        let token = appActivity.application.token
                        let duration = appActivity.totalActivityDuration
                        let pickups = appActivity.numberOfPickups

                        if token != nil {
                            if var existing = appActivities[token!] {
                                existing.duration += duration
                                existing.pickups += pickups
                                appActivities[token!] = existing
                            } else {
                                appActivities[token!] = (duration, pickups)
                            }
                        }
                    }
                }
            }
        }

        // Convert to AppActivityInfo and sort by duration
        let sortedApps = appActivities
            .map { token, info in
                AppActivityInfo(
                    applicationToken: token,
                    durationInMinutes: info.duration / 60.0,
                    numberOfPickups: info.pickups
                )
            }
            .sorted { $0.durationInMinutes > $1.durationInMinutes }

        return TopAppsConfiguration(
            apps: Array(sortedApps.prefix(10)), // Top 10 apps
            totalDurationInMinutes: totalDuration / 60.0
        )
    }
}

// MARK: - Top Apps View
struct TopAppsView: View {
    let topApps: TopAppsConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(topApps.apps.prefix(5))) { app in
                HStack(spacing: 12) {
                    // App icon using Label with ApplicationToken
                    Label(app.applicationToken)
                        .labelStyle(.iconOnly)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Text(formatDuration(app.durationInMinutes))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
