import SwiftUI

/// Tab view for managing blocking schedules
struct ScheduleTab: View {
    @StateObject private var scheduleManager = ScheduleManager.shared
    @State private var showingEditor = false
    @State private var editingSchedule: BlockSchedule?

    var body: some View {
        NavigationView {
            Group {
                if scheduleManager.schedules.isEmpty {
                    emptyStateView
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Schedules")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditor = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                ScheduleEditorSheet(schedule: nil) { newSchedule in
                    scheduleManager.saveSchedule(newSchedule)
                }
            }
            .sheet(item: $editingSchedule) { schedule in
                ScheduleEditorSheet(schedule: schedule) { updatedSchedule in
                    scheduleManager.saveSchedule(updatedSchedule)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Schedules")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create schedules to automatically block apps during specific times.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showingEditor = true }) {
                Label("Add Schedule", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var scheduleList: some View {
        List {
            ForEach(scheduleManager.schedules) { schedule in
                ScheduleRowView(
                    schedule: schedule,
                    onToggle: { scheduleManager.toggleSchedule(schedule) },
                    onTap: { editingSchedule = schedule }
                )
            }
            .onDelete { offsets in
                scheduleManager.deleteSchedule(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Schedule Row View
struct ScheduleRowView: View {
    let schedule: BlockSchedule
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(schedule.isEnabled && schedule.isActiveNow() ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(schedule.timeRangeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        ForEach(BlockSchedule.weekdaySymbols, id: \.id) { day in
                            Text(day.short)
                                .font(.caption2)
                                .fontWeight(schedule.activeDays.contains(day.id) ? .bold : .regular)
                                .foregroundColor(schedule.activeDays.contains(day.id) ? .primary : .secondary.opacity(0.5))
                        }
                    }
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScheduleTab()
}
