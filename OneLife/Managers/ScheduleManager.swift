import Foundation
import Combine
import ManagedSettings
import FamilyControls
import DeviceActivity
import UserNotifications

/// Manages blocking schedules with break functionality
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    @Published var schedules: [BlockSchedule] = []
    @Published var isOnBreak: Bool = false
    @Published var breakEndTime: Date?
    @Published var isBlockingActive: Bool = false

    private let userDefaults: UserDefaults?
    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()

    private let schedulesKey = "blockSchedules"
    private let breakEndTimeKey = "scheduleBreakEndTime"
    private let suiteName = "group.com.onelife.app"

    private var breakCheckTimer: Timer?

    // Notification identifiers
    private let breakWarningNotificationId = "breakWarning30s"
    private let breakEndedNotificationId = "breakEnded"

    private init() {
        userDefaults = UserDefaults(suiteName: suiteName)
        loadSchedules()
        loadBreakState()
        checkAndApplyScheduleBlocking()
        setupNotificationCategories()
    }

    // MARK: - Notification Setup

    private func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        // Create action for ending break from notification
        let endBreakAction = UNNotificationAction(
            identifier: "END_BREAK",
            title: "End Break Now",
            options: .foreground
        )

        let breakCategory = UNNotificationCategory(
            identifier: "BREAK_CATEGORY",
            actions: [endBreakAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([breakCategory])
    }

    // MARK: - CRUD Operations

    func loadSchedules() {
        guard let data = userDefaults?.data(forKey: schedulesKey),
              let decoded = try? JSONDecoder().decode([BlockSchedule].self, from: data) else {
            schedules = []
            return
        }
        schedules = decoded
    }

    func saveSchedule(_ schedule: BlockSchedule) {
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[index] = schedule
        } else {
            schedules.append(schedule)
        }
        persistSchedules()
        checkAndApplyScheduleBlocking()
    }

    func deleteSchedule(_ schedule: BlockSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        persistSchedules()
        checkAndApplyScheduleBlocking()
    }

    func deleteSchedule(at offsets: IndexSet) {
        schedules.remove(atOffsets: offsets)
        persistSchedules()
        checkAndApplyScheduleBlocking()
    }

    func toggleSchedule(_ schedule: BlockSchedule) {
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[index].isEnabled.toggle()
        persistSchedules()
        checkAndApplyScheduleBlocking()
    }

    private func persistSchedules() {
        if let data = try? JSONEncoder().encode(schedules) {
            userDefaults?.set(data, forKey: schedulesKey)
        }
    }

    // MARK: - Break State Persistence

    private func loadBreakState() {
        if let endTime = userDefaults?.object(forKey: breakEndTimeKey) as? Date {
            if endTime > Date() {
                breakEndTime = endTime
                isOnBreak = true
                startBreakCheckTimer()
            } else {
                // Break has expired while app was closed
                clearBreakState()
                // Re-apply blocking since break ended
                checkAndApplyScheduleBlocking()
            }
        }
    }

    private func saveBreakState() {
        userDefaults?.set(breakEndTime, forKey: breakEndTimeKey)
    }

    private func clearBreakState() {
        userDefaults?.removeObject(forKey: breakEndTimeKey)
        breakEndTime = nil
        isOnBreak = false
        breakCheckTimer?.invalidate()
        breakCheckTimer = nil
    }

    // MARK: - Schedule Blocking

    /// Check if any schedule is active and apply blocking
    func checkAndApplyScheduleBlocking() {
        // First check if break has expired
        if isOnBreak, let endTime = breakEndTime, Date() >= endTime {
            // Break has expired
            clearBreakState()
            cancelBreakNotifications()
        }

        let activeSchedules = getActiveSchedules()

        if activeSchedules.isEmpty {
            // No active schedules - remove blocking
            if isBlockingActive {
                removeAllBlocking()
            }
            return
        }

        // If on break, don't apply blocking
        if isOnBreak {
            if isBlockingActive {
                removeAllBlocking()
            }
            return
        }

        // Active schedule and not on break - apply blocking
        applyBlockingForSchedules(activeSchedules)
    }

    private func applyBlockingForSchedules(_ activeSchedules: [BlockSchedule]) {
        // Get all excluded apps across active schedules
        var excludedTokens = Set<ApplicationToken>()

        for schedule in activeSchedules {
            for tokenHash in schedule.excludedAppTokenHashes {
                if let token = AppIntention.tokenFromIdentifier(tokenHash) {
                    excludedTokens.insert(token)
                }
            }
        }

        // Block ALL app categories
        store.shield.applicationCategories = .all(except: excludedTokens)
        store.shield.webDomainCategories = .all()

        isBlockingActive = true
    }

    private func removeAllBlocking() {
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        store.shield.applications = nil
        isBlockingActive = false
    }

    // MARK: - Break Management

    /// Start a break for the specified duration in minutes
    func startBreak(durationMinutes: Int) {
        let endTime = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        breakEndTime = endTime
        isOnBreak = true
        saveBreakState()

        // Remove blocking during break
        removeAllBlocking()

        // Schedule notifications
        scheduleBreakNotifications(endTime: endTime)

        // Start timer to check break status
        startBreakCheckTimer()
    }

    /// End the current break early
    func endBreak() {
        breakCheckTimer?.invalidate()
        breakCheckTimer = nil
        clearBreakState()
        cancelBreakNotifications()

        // Re-apply blocking if schedule is still active
        checkAndApplyScheduleBlocking()
    }

    /// Called when app comes to foreground - check if break expired
    func checkBreakExpiration() {
        guard isOnBreak, let endTime = breakEndTime else { return }

        if Date() >= endTime {
            // Break has expired
            breakDidExpire()
        }
    }

    private func startBreakCheckTimer() {
        breakCheckTimer?.invalidate()

        // Check every second for accurate countdown and expiration
        breakCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkBreakTimer()
        }
    }

    private func checkBreakTimer() {
        guard let endTime = breakEndTime else {
            breakCheckTimer?.invalidate()
            breakCheckTimer = nil
            return
        }

        if Date() >= endTime {
            breakDidExpire()
        }
    }

    private func breakDidExpire() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.breakCheckTimer?.invalidate()
            self.breakCheckTimer = nil
            self.clearBreakState()

            // Send break ended notification
            self.sendBreakEndedNotification()

            // Re-apply blocking
            self.checkAndApplyScheduleBlocking()
        }
    }

    // MARK: - Break Notifications

    private func scheduleBreakNotifications(endTime: Date) {
        let center = UNUserNotificationCenter.current()

        // Cancel any existing break notifications
        cancelBreakNotifications()

        let timeUntilEnd = endTime.timeIntervalSinceNow

        // Schedule 30-second warning if break is longer than 30 seconds
        if timeUntilEnd > 30 {
            let warningContent = UNMutableNotificationContent()
            warningContent.title = "Break Ending Soon"
            warningContent.body = "Your break ends in 30 seconds. Apps will be blocked again."
            warningContent.sound = .default
            warningContent.categoryIdentifier = "BREAK_CATEGORY"

            let warningTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: timeUntilEnd - 30,
                repeats: false
            )

            let warningRequest = UNNotificationRequest(
                identifier: breakWarningNotificationId,
                content: warningContent,
                trigger: warningTrigger
            )

            center.add(warningRequest) { error in
                if let error = error {
                    print("Failed to schedule warning notification: \(error)")
                }
            }
        }

        // Schedule break ended notification
        let endedContent = UNMutableNotificationContent()
        endedContent.title = "Break Ended"
        endedContent.body = "Your break is over. Apps are now blocked again."
        endedContent.sound = .default

        let endedTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeUntilEnd,
            repeats: false
        )

        let endedRequest = UNNotificationRequest(
            identifier: breakEndedNotificationId,
            content: endedContent,
            trigger: endedTrigger
        )

        center.add(endedRequest) { error in
            if let error = error {
                print("Failed to schedule ended notification: \(error)")
            }
        }
    }

    private func cancelBreakNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [breakWarningNotificationId, breakEndedNotificationId]
        )
    }

    private func sendBreakEndedNotification() {
        // Only send if app is in background
        let content = UNMutableNotificationContent()
        content.title = "Break Ended"
        content.body = "Your break is over. Apps are now blocked again."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "breakEndedImmediate",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Remaining break time in seconds
    var breakTimeRemaining: TimeInterval {
        guard let endTime = breakEndTime else { return 0 }
        return max(0, endTime.timeIntervalSinceNow)
    }

    /// Formatted remaining break time
    var formattedBreakTimeRemaining: String {
        let remaining = breakTimeRemaining
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Query Methods

    /// Returns all currently active schedules (enabled and within time window)
    func getActiveSchedules() -> [BlockSchedule] {
        return schedules.filter { $0.isActiveNow() }
    }

    /// Check if any schedule is currently active
    func isWithinAnyActiveSchedule() -> Bool {
        return schedules.contains { $0.isActiveNow() }
    }

    /// Get the currently active schedule (first one if multiple)
    func getCurrentActiveSchedule() -> BlockSchedule? {
        return getActiveSchedules().first
    }

    /// Check if an app should be blocked based on active schedules
    func shouldBlockApp(tokenHash: String) -> Bool {
        if isOnBreak { return false }

        let activeSchedules = getActiveSchedules()
        for schedule in activeSchedules {
            if !schedule.isAppExcluded(tokenHash) {
                return true
            }
        }
        return false
    }

    /// Get all excluded app token hashes across active schedules
    func getExcludedAppTokenHashes() -> Set<String> {
        var excluded = Set<String>()
        for schedule in getActiveSchedules() {
            excluded.formUnion(schedule.excludedAppTokenHashes)
        }
        return excluded
    }

    // MARK: - Statistics

    var totalSchedules: Int {
        schedules.count
    }

    var enabledSchedules: Int {
        schedules.filter { $0.isEnabled }.count
    }

    var activeSchedulesCount: Int {
        getActiveSchedules().count
    }
}
