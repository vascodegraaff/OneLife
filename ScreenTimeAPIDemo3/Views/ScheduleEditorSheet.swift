import SwiftUI
import FamilyControls

/// Sheet for creating or editing a blocking schedule
struct ScheduleEditorSheet: View {
    let schedule: BlockSchedule?
    let onSave: (BlockSchedule) -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var name: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var activeDays: Set<Int> = Set(1...7)
    @State private var excludedApps = FamilyActivitySelection()
    @State private var isEnabled: Bool = true

    @State private var isExclusionPickerPresented = false

    private var isEditing: Bool {
        schedule != nil
    }

    var body: some View {
        NavigationView {
            Form {
                // Name Section
                Section {
                    TextField("Schedule Name", text: $name)
                } header: {
                    Text("Name")
                }

                // Time Section
                Section {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Time")
                } footer: {
                    if isOvernightSchedule {
                        Text("This schedule spans overnight (crosses midnight).")
                    }
                }

                // Days Section
                Section {
                    DayPickerView(selectedDays: $activeDays)
                } header: {
                    Text("Active Days")
                }

                // Excluded Apps Section
                Section {
                    Button(action: { isExclusionPickerPresented = true }) {
                        HStack {
                            Text("Excluded Apps")
                            Spacer()
                            if !excludedApps.applicationTokens.isEmpty {
                                Text("\(excludedApps.applicationTokens.count) apps")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("None")
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                    .familyActivityPicker(
                        isPresented: $isExclusionPickerPresented,
                        selection: $excludedApps
                    )
                } header: {
                    Text("Exceptions")
                } footer: {
                    Text("These apps will NOT be blocked during this schedule.")
                }

                // Enable/Disable Section
                Section {
                    Toggle("Schedule Enabled", isOn: $isEnabled)
                }
            }
            .navigationTitle(isEditing ? "Edit Schedule" : "New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadScheduleData()
            }
        }
    }

    private var isOvernightSchedule: Bool {
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startTime)
        let startMinute = calendar.component(.minute, from: startTime)
        let endHour = calendar.component(.hour, from: endTime)
        let endMinute = calendar.component(.minute, from: endTime)

        return startHour > endHour || (startHour == endHour && startMinute > endMinute)
    }

    private func loadScheduleData() {
        guard let schedule = schedule else {
            // Default values for new schedule
            name = "New Schedule"

            // Default: 10 PM to 7 AM
            var startComponents = DateComponents()
            startComponents.hour = 22
            startComponents.minute = 0
            startTime = Calendar.current.date(from: startComponents) ?? Date()

            var endComponents = DateComponents()
            endComponents.hour = 7
            endComponents.minute = 0
            endTime = Calendar.current.date(from: endComponents) ?? Date()

            return
        }

        // Load existing schedule data
        name = schedule.name
        activeDays = schedule.activeDays
        isEnabled = schedule.isEnabled

        var startComponents = DateComponents()
        startComponents.hour = schedule.startHour
        startComponents.minute = schedule.startMinute
        startTime = Calendar.current.date(from: startComponents) ?? Date()

        var endComponents = DateComponents()
        endComponents.hour = schedule.endHour
        endComponents.minute = schedule.endMinute
        endTime = Calendar.current.date(from: endComponents) ?? Date()

        // Load excluded apps (we store token hashes, but need to reload selection)
        // For now, excluded apps won't persist across edit sessions since we store hashes
        // A full implementation would need to rebuild the FamilyActivitySelection from stored hashes
    }

    private func saveSchedule() {
        let calendar = Calendar.current

        // Extract excluded app token hashes
        var excludedHashes = Set<String>()
        for token in excludedApps.applicationTokens {
            let hash = AppIntention.hashFromToken(token)
            excludedHashes.insert(hash)
        }

        var newSchedule: BlockSchedule
        if let existingSchedule = schedule {
            // Update existing
            newSchedule = existingSchedule
            newSchedule.name = name.trimmingCharacters(in: .whitespaces)
            newSchedule.startHour = calendar.component(.hour, from: startTime)
            newSchedule.startMinute = calendar.component(.minute, from: startTime)
            newSchedule.endHour = calendar.component(.hour, from: endTime)
            newSchedule.endMinute = calendar.component(.minute, from: endTime)
            newSchedule.activeDays = activeDays
            newSchedule.excludedAppTokenHashes = excludedHashes
            newSchedule.isEnabled = isEnabled
        } else {
            // Create new
            newSchedule = BlockSchedule(
                name: name.trimmingCharacters(in: .whitespaces),
                startHour: calendar.component(.hour, from: startTime),
                startMinute: calendar.component(.minute, from: startTime),
                endHour: calendar.component(.hour, from: endTime),
                endMinute: calendar.component(.minute, from: endTime),
                activeDays: activeDays,
                excludedAppTokenHashes: excludedHashes,
                isEnabled: isEnabled
            )
        }

        onSave(newSchedule)
        dismiss()
    }
}

// MARK: - Day Picker View
struct DayPickerView: View {
    @Binding var selectedDays: Set<Int>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BlockSchedule.weekdaySymbols, id: \.id) { day in
                DayButton(
                    label: day.short,
                    isSelected: selectedDays.contains(day.id),
                    action: { toggleDay(day.id) }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func toggleDay(_ day: Int) {
        if selectedDays.contains(day) {
            // Don't allow deselecting all days
            if selectedDays.count > 1 {
                selectedDays.remove(day)
            }
        } else {
            selectedDays.insert(day)
        }
    }
}

struct DayButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScheduleEditorSheet(schedule: nil) { _ in }
}
