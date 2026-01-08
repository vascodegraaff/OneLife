import Foundation
import FamilyControls
import ManagedSettings
import Combine

// Darwin notification name for cross-process communication
let kIntentionsDidChangeNotification = "com.luminote.screentime.intentionsDidChange" as CFString

/// Manages shared data between the main app and extensions via App Groups
final class AppGroupManager: ObservableObject {
    static let shared = AppGroupManager()

    private let suiteName = "group.com.luminote.screentime"
    private let userDefaults: UserDefaults?

    // In-memory cache of the selection for token lookup
    @Published var intentionSelection = FamilyActivitySelection()

    // Publisher for intention changes from extensions
    let intentionsDidChange = PassthroughSubject<Void, Never>()

    private init() {
        userDefaults = UserDefaults(suiteName: suiteName)
        loadIntentionSelection()
        setupDarwinNotificationObserver()
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    // MARK: - Darwin Notifications (Cross-Process Communication)

    private func setupDarwinNotificationObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()

        CFNotificationCenterAddObserver(
            center,
            observer,
            { (center, observer, name, object, userInfo) in
                // Called when extension posts notification
                DispatchQueue.main.async {
                    AppGroupManager.shared.handleIntentionsDidChange()
                }
            },
            kIntentionsDidChangeNotification,
            nil,
            .deliverImmediately
        )
    }

    private func handleIntentionsDidChange() {
        // Force reload from disk
        userDefaults?.synchronize()
        objectWillChange.send()
        intentionsDidChange.send()
    }

    /// Post notification that intentions changed (call from extensions)
    static func postIntentionsDidChangeNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(kIntentionsDidChangeNotification),
            nil,
            nil,
            true
        )
    }

    // MARK: - Keys
    private enum Keys {
        static let intentions = "intentions"
        static let intentionSelection = "intentionSelection"
        static let totalAppOpenAttempts = "totalAppOpenAttempts"
        static let dailyAppOpenAttempts = "dailyAppOpenAttempts"
        static let lastResetDate = "lastResetDate"
        static let isBlockingSessionActive = "isBlockingSessionActive"
        static let sessionStartTime = "sessionStartTime"
        static let screenTimeGoalMinutes = "screenTimeGoalMinutes"
        static let allowedUntil = "allowedUntil" // Dictionary of app token hash -> timestamp
    }

    // MARK: - Intention Selection (for token lookup)
    func saveIntentionSelection(_ selection: FamilyActivitySelection) {
        intentionSelection = selection
        if let data = try? PropertyListEncoder().encode(selection) {
            userDefaults?.set(data, forKey: Keys.intentionSelection)
        }
    }

    func loadIntentionSelection() {
        guard let data = userDefaults?.data(forKey: Keys.intentionSelection),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }
        intentionSelection = selection
    }

    func addTokenToIntentionSelection(_ token: ApplicationToken) {
        var selection = intentionSelection
        selection.applicationTokens.insert(token)
        saveIntentionSelection(selection)
    }

    func getToken(forHash identifier: String) -> ApplicationToken? {
        // Try to decode token directly from Base64 identifier (new format)
        if let data = Data(base64Encoded: identifier),
           let token = try? PropertyListDecoder().decode(ApplicationToken.self, from: data) {
            return token
        }
        // Fallback: search in stored selection (for backwards compatibility with old hash format)
        return intentionSelection.applicationTokens.first { String($0.hashValue) == identifier }
    }

    // MARK: - Screen Time Goal
    var screenTimeGoalMinutes: Int {
        get { userDefaults?.integer(forKey: Keys.screenTimeGoalMinutes) ?? 120 } // Default 2 hours
        set {
            objectWillChange.send()
            userDefaults?.set(newValue, forKey: Keys.screenTimeGoalMinutes)
        }
    }

    // MARK: - App Open Attempts Counter
    var totalAppOpenAttempts: Int {
        get { userDefaults?.integer(forKey: Keys.totalAppOpenAttempts) ?? 0 }
        set { userDefaults?.set(newValue, forKey: Keys.totalAppOpenAttempts) }
    }

    var dailyAppOpenAttempts: Int {
        get {
            resetDailyCounterIfNeeded()
            return userDefaults?.integer(forKey: Keys.dailyAppOpenAttempts) ?? 0
        }
        set { userDefaults?.set(newValue, forKey: Keys.dailyAppOpenAttempts) }
    }

    func incrementAppOpenAttempts() {
        resetDailyCounterIfNeeded()
        totalAppOpenAttempts += 1
        dailyAppOpenAttempts += 1
    }

    private func resetDailyCounterIfNeeded() {
        let lastReset = userDefaults?.object(forKey: Keys.lastResetDate) as? Date ?? Date.distantPast
        if !Calendar.current.isDateInToday(lastReset) {
            userDefaults?.set(0, forKey: Keys.dailyAppOpenAttempts)
            userDefaults?.set(Date(), forKey: Keys.lastResetDate)
        }
    }

    func resetDailyCounters() {
        userDefaults?.set(0, forKey: Keys.dailyAppOpenAttempts)
        userDefaults?.set(Date(), forKey: Keys.lastResetDate)

        // Also reset intention counters
        var intentions = loadIntentions()
        for i in intentions.indices {
            intentions[i].currentOpens = 0
            intentions[i].lastResetDate = Date()
        }
        saveIntentions(intentions)
    }

    // MARK: - Blocking Session
    var isBlockingSessionActive: Bool {
        get { userDefaults?.bool(forKey: Keys.isBlockingSessionActive) ?? false }
        set { userDefaults?.set(newValue, forKey: Keys.isBlockingSessionActive) }
    }

    var sessionStartTime: Date? {
        get { userDefaults?.object(forKey: Keys.sessionStartTime) as? Date }
        set { userDefaults?.set(newValue, forKey: Keys.sessionStartTime) }
    }

    // MARK: - App Intentions
    func loadIntentions() -> [AppIntention] {
        guard let data = userDefaults?.data(forKey: Keys.intentions),
              let intentions = try? JSONDecoder().decode([AppIntention].self, from: data) else {
            return []
        }
        return intentions
    }

    func saveIntentions(_ intentions: [AppIntention]) {
        if let data = try? JSONEncoder().encode(intentions) {
            userDefaults?.set(data, forKey: Keys.intentions)
        }
    }

    func getIntention(forTokenHash hash: String) -> AppIntention? {
        return loadIntentions().first { $0.tokenHash == hash }
    }

    func incrementIntentionOpens(forTokenHash hash: String) -> AppIntention? {
        var intentions = loadIntentions()
        guard let index = intentions.firstIndex(where: { $0.tokenHash == hash }) else {
            return nil
        }

        // Check if we need to reset for new day
        if !Calendar.current.isDateInToday(intentions[index].lastResetDate) {
            intentions[index].currentOpens = 0
            intentions[index].lastResetDate = Date()
        }

        intentions[index].currentOpens += 1
        saveIntentions(intentions)
        return intentions[index]
    }

    // MARK: - Temporary App Access (Allow for X minutes)
    func setAllowedUntil(forTokenHash hash: String, until date: Date) {
        var allowed = getAllowedUntilMap()
        allowed[hash] = date
        if let data = try? JSONEncoder().encode(allowed) {
            userDefaults?.set(data, forKey: Keys.allowedUntil)
        }
    }

    func getAllowedUntil(forTokenHash hash: String) -> Date? {
        let allowed = getAllowedUntilMap()
        return allowed[hash]
    }

    func isCurrentlyAllowed(forTokenHash hash: String) -> Bool {
        guard let allowedUntil = getAllowedUntil(forTokenHash: hash) else {
            return false
        }
        return Date() < allowedUntil
    }

    func clearAllowedUntil(forTokenHash hash: String) {
        var allowed = getAllowedUntilMap()
        allowed.removeValue(forKey: hash)
        if let data = try? JSONEncoder().encode(allowed) {
            userDefaults?.set(data, forKey: Keys.allowedUntil)
        }
    }

    func clearExpiredAllowances() {
        var allowed = getAllowedUntilMap()
        let now = Date()
        allowed = allowed.filter { $0.value > now }
        if let data = try? JSONEncoder().encode(allowed) {
            userDefaults?.set(data, forKey: Keys.allowedUntil)
        }
    }

    private func getAllowedUntilMap() -> [String: Date] {
        guard let data = userDefaults?.data(forKey: Keys.allowedUntil),
              let map = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return map
    }

    // MARK: - Debug Logs (from ShieldAction extension)
    func getShieldActionLogs() -> [String] {
        return userDefaults?.stringArray(forKey: "shieldActionLogs") ?? []
    }

    func clearShieldActionLogs() {
        userDefaults?.removeObject(forKey: "shieldActionLogs")
    }

    // MARK: - Streak Tracking
    func updateStreak(forTokenHash hash: String, didStayUnderLimit: Bool) {
        var intentions = loadIntentions()
        guard let index = intentions.firstIndex(where: { $0.tokenHash == hash }) else {
            return
        }

        if didStayUnderLimit {
            intentions[index].streakDays += 1
        } else {
            intentions[index].streakDays = 0
        }
        saveIntentions(intentions)
    }
}
