import DeviceActivity
import SwiftUI

@main
struct DeviceActivityReportExtensionApp: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Total activity report for the circular progress view
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }

        // Top apps report for the app list
        TopAppsReport { topApps in
            TopAppsView(topApps: topApps)
        }
    }
}
