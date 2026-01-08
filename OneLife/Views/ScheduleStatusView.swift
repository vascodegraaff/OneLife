import SwiftUI

/// View showing active schedule status with break functionality
struct ScheduleStatusView: View {
    @ObservedObject var scheduleManager = ScheduleManager.shared

    @State private var showingBreakOptions = false
    @State private var breakTimeDisplay: String = ""
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            if scheduleManager.isOnBreak {
                breakActiveView
            } else if let activeSchedule = scheduleManager.getCurrentActiveSchedule() {
                scheduleActiveView(schedule: activeSchedule)
            }
        }
        .padding(.horizontal)
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: scheduleManager.isOnBreak) { _, isOnBreak in
            if isOnBreak {
                startTimerIfNeeded()
            }
        }
    }

    // MARK: - Schedule Active View

    private func scheduleActiveView(schedule: BlockSchedule) -> some View {
        VStack(spacing: 12) {
            // Schedule info card
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                        Text(schedule.name)
                            .font(.headline)
                    }

                    Text("Until \(schedule.formattedEndTime)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Active indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            // Take a break button
            Button(action: { showingBreakOptions = true }) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                    Text("Take a Break")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange)
                )
            }
            .confirmationDialog("Break Duration", isPresented: $showingBreakOptions, titleVisibility: .visible) {
                ForEach(BlockSchedule.breakDurationOptions, id: \.minutes) { option in
                    Button(option.label) {
                        scheduleManager.startBreak(durationMinutes: option.minutes)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How long do you need?")
            }
        }
    }

    // MARK: - Break Active View

    private var breakActiveView: some View {
        VStack(spacing: 12) {
            // Break info card
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.orange)
                    Text("On Break")
                        .font(.headline)
                }

                Text(breakTimeDisplay)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)

                Text("remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.orange.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )

            // End break button
            Button(action: { scheduleManager.endBreak() }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("End Break")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red)
                )
            }
        }
    }

    // MARK: - Timer

    private func startTimerIfNeeded() {
        guard scheduleManager.isOnBreak else { return }
        updateBreakTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateBreakTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateBreakTime() {
        breakTimeDisplay = scheduleManager.formattedBreakTimeRemaining
    }
}

#Preview {
    VStack {
        ScheduleStatusView()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
