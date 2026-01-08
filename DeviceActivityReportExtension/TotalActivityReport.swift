import DeviceActivity
import SwiftUI

// Extension to define our custom context
extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let topApps = Self("Top Apps")
}

// MARK: - Total Activity Configuration
struct TotalActivityConfiguration {
    let totalDurationInMinutes: Double
    let numberOfPickups: Int
    let numberOfNotifications: Int
}

// MARK: - Total Activity Report Scene
struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity

    let content: (TotalActivityConfiguration) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TotalActivityConfiguration {
        var totalDuration: TimeInterval = 0
        var pickups = 0
        var notifications = 0

        // Iterate through the activity data
        for await activityData in data {
            // Get activity segments for each user/device combination
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration

                // Sum up pickups and notifications from all apps
                for await categoryActivity in segment.categories {
                    for await appActivity in categoryActivity.applications {
                        pickups += appActivity.numberOfPickups
                        notifications += appActivity.numberOfNotifications
                    }
                }
            }
        }

        let totalMinutes = totalDuration / 60.0

        return TotalActivityConfiguration(
            totalDurationInMinutes: totalMinutes,
            numberOfPickups: pickups,
            numberOfNotifications: notifications
        )
    }
}

// MARK: - Total Activity View
struct TotalActivityView: View {
    let totalActivity: TotalActivityConfiguration

    var body: some View {
        VStack(spacing: 8) {
            // Main time display
            Text(formatDuration(totalActivity.totalDurationInMinutes))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Additional stats
            HStack(spacing: 16) {
                Label("\(totalActivity.numberOfPickups)", systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(totalActivity.numberOfNotifications)", systemImage: "bell")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
