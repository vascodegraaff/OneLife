//
//  ContentView.swift
//  ScreenTimeAPIDemo3
//
//  Created by Kei Fujikawa on 2023/08/11.
//

import SwiftUI
import FamilyControls
import UIKit
import UserNotifications

struct ContentView: View {
    var body: some View {
        TabView {
            HomeTab()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            AppsTab()
                .tabItem {
                    Label("Apps", systemImage: "app.badge")
                }

            ScheduleTab()
                .tabItem {
                    Label("Schedule", systemImage: "calendar.badge.clock")
                }

            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Home Tab
struct HomeTab: View {
    @StateObject var model = FamilyControlModel.shared
    @StateObject var intentionsManager = IntentionsManager.shared
    @StateObject var appGroupManager = AppGroupManager.shared
    @StateObject var scheduleManager = ScheduleManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Screen Time Dashboard
                    ScreenTimeDashboardView()
                        .padding(.horizontal)

                    // Schedule Status (shows when schedule is active or on break)
                    if scheduleManager.isWithinAnyActiveSchedule() || scheduleManager.isOnBreak {
                        ScheduleStatusView()
                    }

                    // Start Blocking Session Button
                    BlockingSessionButtonView()

                    // App Intentions
                    IntentionsHorizontalList()

                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Screen Time")
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshData()
        }
        .onReceive(appGroupManager.intentionsDidChange) { _ in
            // Received Darwin notification from extension - reload data
            refreshData()
        }
    }

    private func refreshData() {
        // Reload intentions to get updated open counts
        intentionsManager.loadIntentions()
        // Reload token selection for icons
        appGroupManager.loadIntentionSelection()
        // Re-apply shields for any expired sessions
        intentionsManager.reapplyExpiredShields()
        // Check if break has expired and re-apply blocking
        scheduleManager.checkBreakExpiration()
        scheduleManager.checkAndApplyScheduleBlocking()
    }
}

// MARK: - Apps Tab
struct AppsTab: View {
    @StateObject var model = FamilyControlModel.shared
    @State private var isPickerPresented = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Current selection info
                if !model.selectionToDiscourage.applicationTokens.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("\(model.selectionToDiscourage.applicationTokens.count) app(s) selected")
                            .font(.headline)

                        if !model.selectionToDiscourage.categoryTokens.isEmpty {
                            Text("\(model.selectionToDiscourage.categoryTokens.count) category(s) selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "apps.iphone")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No apps selected")
                            .font(.headline)

                        Text("Select apps to create shields and intentions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }

                // Select Apps Button
                Button(action: {
                    Task {
                        try await model.authorize()
                        isPickerPresented = true
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Select Apps to Block")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.blue)
                    )
                }
                .padding(.horizontal)
                .familyActivityPicker(
                    isPresented: $isPickerPresented,
                    selection: $model.selectionToDiscourage
                )

                // Clear Selection Button
                if !model.selectionToDiscourage.applicationTokens.isEmpty {
                    Button(action: {
                        model.encourageAll()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Clear All Selections")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                }

                Spacer()
            }
            .padding(.top, 40)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Select Apps")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Settings Tab
struct SettingsTab: View {
    @AppStorage("screenTimeGoalHours") private var goalHours: Int = 2
    @State private var showingDebugLogs = false

    // Permission states
    @State private var screenTimeStatus: AuthorizationStatus = .notDetermined
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Screen Time Permission
                    HStack {
                        Label("Screen Time", systemImage: "hourglass")
                        Spacer()
                        switch screenTimeStatus {
                        case .approved:
                            Text("Authorized")
                                .foregroundColor(.green)
                        case .denied:
                            Button("Open Settings") {
                                openAppSettings()
                            }
                        case .notDetermined:
                            Button("Request") {
                                requestScreenTimePermission()
                            }
                        @unknown default:
                            Text("Unknown")
                                .foregroundColor(.secondary)
                        }
                    }

                    // Notifications Permission
                    HStack {
                        Label("Notifications", systemImage: "bell")
                        Spacer()
                        switch notificationStatus {
                        case .authorized, .provisional, .ephemeral:
                            Text("Authorized")
                                .foregroundColor(.green)
                        case .denied:
                            Button("Open Settings") {
                                openAppSettings()
                            }
                        case .notDetermined:
                            Button("Request") {
                                requestNotificationPermission()
                            }
                        @unknown default:
                            Text("Unknown")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("These permissions are required for the app to function properly.")
                }

                Section {
                    Stepper("Daily Goal: \(goalHours) hours", value: $goalHours, in: 1...12)
                } header: {
                    Text("Screen Time Goal")
                } footer: {
                    Text("Set your daily screen time goal. The dashboard will show your progress.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)

                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                } header: {
                    Text("About")
                }

                Section {
                    Button(role: .destructive) {
                        // Reset all data
                        AppGroupManager.shared.resetDailyCounters()
                        IntentionsManager.shared.loadIntentions()
                    } label: {
                        Text("Reset All Data")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("This will reset all counters and intentions.")
                }

                Section {
                    NavigationLink("Shield Action Logs") {
                        DebugLogsView()
                    }
                } header: {
                    Text("Debug")
                } footer: {
                    Text("View logs from shield button presses to debug data flow.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                checkPermissions()
            }
        }
    }

    // MARK: - Permission Methods

    private func checkPermissions() {
        // Check Screen Time status
        screenTimeStatus = AuthorizationCenter.shared.authorizationStatus

        // Check Notification status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestScreenTimePermission() {
        Task {
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                await MainActor.run {
                    screenTimeStatus = AuthorizationCenter.shared.authorizationStatus
                }
            } catch {
                print("Screen Time authorization failed: \(error)")
                await MainActor.run {
                    screenTimeStatus = AuthorizationCenter.shared.authorizationStatus
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    notificationStatus = .authorized
                } else {
                    // Re-check the actual status
                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                        DispatchQueue.main.async {
                            notificationStatus = settings.authorizationStatus
                        }
                    }
                }
            }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Debug Logs View
struct DebugLogsView: View {
    @State private var logs: [String] = []
    @State private var intentions: [AppIntention] = []
    @State private var allowedUntilInfo: String = ""

    var body: some View {
        List {
            Section {
                if intentions.isEmpty {
                    Text("No intentions stored")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(intentions) { intention in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intention.appDisplayName)
                                .font(.headline)
                            Text("Hash: \(intention.tokenHash)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Opens: \(intention.currentOpens)/\(intention.maxOpensPerDay)")
                                .font(.subheadline)
                            Text("Session: \(intention.sessionDurationMinutes) min")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Stored Intentions (\(intentions.count))")
            }

            Section {
                Text(allowedUntilInfo.isEmpty ? "No active sessions" : allowedUntilInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Active Sessions")
            }

            Section {
                if logs.isEmpty {
                    Text("No logs yet. Press buttons on a shield to generate logs.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(logs.reversed(), id: \.self) { log in
                        Text(log)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            } header: {
                HStack {
                    Text("Shield Action Logs (\(logs.count))")
                    Spacer()
                    Button("Clear") {
                        AppGroupManager.shared.clearShieldActionLogs()
                        loadData()
                    }
                    .font(.caption)
                }
            }
        }
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Refresh") {
                    loadData()
                }
            }
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        logs = AppGroupManager.shared.getShieldActionLogs()
        intentions = AppGroupManager.shared.loadIntentions()

        // Load allowed until info
        let userDefaults = UserDefaults(suiteName: "group.com.luminote.screentime")
        if let data = userDefaults?.data(forKey: "allowedUntil"),
           let allowed = try? JSONDecoder().decode([String: Date].self, from: data) {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            allowedUntilInfo = allowed.map { hash, date in
                let status = date > Date() ? "ACTIVE" : "EXPIRED"
                return "\(hash.prefix(8))...: \(formatter.string(from: date)) [\(status)]"
            }.joined(separator: "\n")
        } else {
            allowedUntilInfo = ""
        }
    }
}

// MARK: - Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
