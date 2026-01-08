import SwiftUI
import FamilyControls
import ManagedSettings

/// Sheet for creating or editing app intentions
struct IntentionEditorSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(AppIntention)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let intention): return intention.id.uuidString
            }
        }
    }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var intentionsManager = IntentionsManager.shared

    @State private var selectedApps = FamilyActivitySelection()
    @State private var isPickerPresented = false
    @State private var maxOpensPerDay: Int = 10
    @State private var sessionDurationMinutes: Int = 5

    // For edit mode
    @State private var editingIntention: AppIntention?

    var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationView {
            Form {
                if !isEditMode {
                    // App Selection (only for add mode)
                    Section {
                        Button(action: { isPickerPresented = true }) {
                            HStack {
                                Text("Select App")
                                Spacer()
                                if !selectedApps.applicationTokens.isEmpty {
                                    Text("\(selectedApps.applicationTokens.count) selected")
                                        .foregroundColor(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .familyActivityPicker(
                            isPresented: $isPickerPresented,
                            selection: $selectedApps
                        )
                    } header: {
                        Text("App")
                    }
                } else if let intention = editingIntention {
                    // Show app name for edit mode
                    Section {
                        HStack {
                            Text("I'll only open")
                            Spacer()
                            Text(intention.appDisplayName)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("App")
                    }
                }

                // Limits Section
                Section {
                    // Opens per day
                    HStack {
                        Picker("", selection: $maxOpensPerDay) {
                            ForEach(AppIntention.maxOpensOptions, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )

                        Text("times a day")
                            .foregroundColor(.primary)
                    }

                    // Session duration
                    HStack {
                        Text("for")
                            .foregroundColor(.primary)

                        Picker("", selection: $sessionDurationMinutes) {
                            ForEach(AppIntention.sessionDurationOptions, id: \.self) { mins in
                                Text("\(mins) min").tag(mins)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )

                        Text("each time")
                            .foregroundColor(.primary)
                    }
                } header: {
                    Text("Limits")
                } footer: {
                    Text("After opening the app, the shield will be disabled for the specified duration.")
                }

                // Stats (only for edit mode)
                if let intention = editingIntention {
                    Section {
                        HStack {
                            Text("Opens today")
                            Spacer()
                            Text("\(intention.currentOpens)/\(intention.maxOpensPerDay)")
                                .foregroundColor(intention.isOverLimit ? .red : .green)
                        }

                        HStack {
                            Text("Streak")
                            Spacer()
                            HStack(spacing: 4) {
                                Text("\(intention.streakDays)")
                                if intention.streakDays > 0 {
                                    Text("days")
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                } else {
                                    Text("days")
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Statistics")
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit App Intention" : "New App Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveIntention()
                        dismiss()
                    }
                    .disabled(!isEditMode && selectedApps.applicationTokens.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditMode {
                    Button(role: .destructive) {
                        if let intention = editingIntention {
                            intentionsManager.removeIntention(id: intention.id)
                        }
                        dismiss()
                    } label: {
                        Text("Remove")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            setupForMode()
        }
    }

    private func setupForMode() {
        if case .edit(let intention) = mode {
            editingIntention = intention
            maxOpensPerDay = intention.maxOpensPerDay
            sessionDurationMinutes = intention.sessionDurationMinutes
        }
    }

    private func saveIntention() {
        if isEditMode, var intention = editingIntention {
            intention.maxOpensPerDay = maxOpensPerDay
            intention.sessionDurationMinutes = sessionDurationMinutes
            intentionsManager.updateIntention(intention)
        } else {
            // Add new intentions for each selected app
            for token in selectedApps.applicationTokens {
                // Try to get display name (might not be available)
                let displayName = "App"
                intentionsManager.addIntention(
                    token: token,
                    displayName: displayName,
                    maxOpensPerDay: maxOpensPerDay,
                    sessionDurationMinutes: sessionDurationMinutes
                )
            }
        }
    }
}

#Preview {
    IntentionEditorSheet(mode: .add)
}
