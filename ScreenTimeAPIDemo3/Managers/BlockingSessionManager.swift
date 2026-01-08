import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Manages blocking sessions for screen time control
final class BlockingSessionManager: ObservableObject {
    static let shared = BlockingSessionManager()

    @Published var isSessionActive: Bool = false
    @Published var sessionStartTime: Date?

    private let appGroupManager = AppGroupManager.shared
    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()

    private init() {
        // Restore session state from App Groups
        isSessionActive = appGroupManager.isBlockingSessionActive
        sessionStartTime = appGroupManager.sessionStartTime
    }

    // MARK: - Session Management

    func startSession(with selection: FamilyActivitySelection) {
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            print("No apps or categories selected to block")
            return
        }

        isSessionActive = true
        sessionStartTime = Date()

        // Persist state
        appGroupManager.isBlockingSessionActive = true
        appGroupManager.sessionStartTime = sessionStartTime

        // Apply shields
        applyShields(for: selection)

        // Start monitoring
        startMonitoring()
    }

    func endSession() {
        isSessionActive = false
        sessionStartTime = nil

        // Persist state
        appGroupManager.isBlockingSessionActive = false
        appGroupManager.sessionStartTime = nil

        // Remove all shields
        clearAllShields()

        // Stop monitoring
        stopMonitoring()
    }

    // MARK: - Shield Management

    private func applyShields(for selection: FamilyActivitySelection) {
        // Shield selected applications
        let applications = selection.applicationTokens
        store.shield.applications = applications.isEmpty ? nil : applications

        // Shield selected categories
        let categories = selection.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }

    private func clearAllShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
    }

    // MARK: - Device Activity Monitoring

    private func startMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(.blocking, during: schedule)
        } catch {
            print("Failed to start monitoring: \(error)")
        }
    }

    private func stopMonitoring() {
        center.stopMonitoring([.blocking])
    }

    // MARK: - Session Duration

    var sessionDuration: TimeInterval? {
        guard let start = sessionStartTime else { return nil }
        return Date().timeIntervalSince(start)
    }

    var formattedSessionDuration: String {
        guard let duration = sessionDuration else { return "00:00:00" }

        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - DeviceActivityName Extension
extension DeviceActivityName {
    static let blocking = Self("blocking")
}
