import SwiftUI
import DeviceActivity
import FamilyControls

// Extension to define our custom contexts (matching the extension)
extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
    static let topApps = Self("Top Apps")
}

/// Dashboard view showing screen time progress using real DeviceActivity data
struct ScreenTimeDashboardView: View {
    @ObservedObject var appGroupManager = AppGroupManager.shared
    @StateObject var model = FamilyControlModel.shared

    @State private var filter = DeviceActivityFilter(
        segment: .daily(
            during: Calendar.current.dateInterval(of: .day, for: .now)!
        ),
        users: .all,
        devices: .init([.iPhone, .iPad])
    )

    var goalMinutes: Double {
        Double(appGroupManager.screenTimeGoalMinutes)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text("Today's Screen Time")
                    .font(.headline)

                Spacer()

                Button(action: { showSettings() }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }

                Button(action: { refreshData() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 24) {
                // Circular Progress with real data from DeviceActivityReport
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 16)

                    // The DeviceActivityReport for total time
                    DeviceActivityReport(.totalActivity, filter: filter)
                        .frame(width: 100, height: 60)
                }
                .frame(width: 160, height: 160)

                // Top apps from DeviceActivityReport
                VStack(alignment: .leading, spacing: 8) {
                    DeviceActivityReport(.topApps, filter: filter)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }

            // Goal indicator
            HStack {
                Text("Goal: \(formatTime(goalMinutes))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { adjustGoal() }) {
                    Text("Adjust")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }

    private func formatTime(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    private func refreshData() {
        // Refresh the filter to trigger a new data fetch
        filter = DeviceActivityFilter(
            segment: .daily(
                during: Calendar.current.dateInterval(of: .day, for: .now)!
            ),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }

    private func showSettings() {
        // Navigate to settings
    }

    private func adjustGoal() {
        // Show goal adjustment UI
    }
}

#Preview {
    ScreenTimeDashboardView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
