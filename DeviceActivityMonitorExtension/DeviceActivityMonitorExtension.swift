//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//
//  Auto-generated for session monitoring
//

import DeviceActivity
import ManagedSettings
import Foundation
import FamilyControls

/// Monitors device activity and re-applies shields when sessions expire
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let suiteName = "group.com.onelife.app"
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logToSharedFile("intervalDidStart for activity: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logToSharedFile("intervalDidEnd for activity: \(activity.rawValue)")

        // Check if this is a session activity (format: "session.{tokenHash}")
        let activityName = activity.rawValue
        if activityName.hasPrefix("session.") {
            let tokenHash = String(activityName.dropFirst("session.".count))
            logToSharedFile("Session ended for tokenHash: \(String(tokenHash.prefix(20)))...")
            reapplyShieldForToken(tokenHash: tokenHash)
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        logToSharedFile("eventDidReachThreshold: \(event.rawValue) for activity: \(activity.rawValue)")
    }

    // MARK: - Shield Management

    private func reapplyShieldForToken(tokenHash: String) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            logToSharedFile("ERROR: Failed to get UserDefaults")
            return
        }

        // Clear the allowedUntil for this token
        clearAllowedUntil(forTokenHash: tokenHash)

        // Load the token from stored selection and re-shield it
        if let token = getApplicationToken(forTokenHash: tokenHash) {
            var shieldedApps = store.shield.applications ?? Set<ApplicationToken>()
            shieldedApps.insert(token)
            store.shield.applications = shieldedApps
            logToSharedFile("Re-shielded app with tokenHash: \(String(tokenHash.prefix(20)))...")
        } else {
            logToSharedFile("Could not find token for hash: \(String(tokenHash.prefix(20)))... - will re-shield all intention apps")
            // Fallback: re-shield all intention apps
            reapplyAllIntentionShields()
        }

        // Notify main app
        postIntentionsDidChangeNotification()
    }

    private func reapplyAllIntentionShields() {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let data = userDefaults.data(forKey: "intentionSelection"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            logToSharedFile("Could not load intention selection for re-shielding")
            return
        }

        // Get current allowed tokens
        let allowedTokens = getAllowedTokenHashes()

        // Re-shield all tokens that are not currently allowed
        var tokensToShield = Set<ApplicationToken>()
        for token in selection.applicationTokens {
            let hash = stableIdentifier(for: token)
            if !allowedTokens.contains(hash) {
                tokensToShield.insert(token)
            }
        }

        if !tokensToShield.isEmpty {
            var shieldedApps = store.shield.applications ?? Set<ApplicationToken>()
            shieldedApps.formUnion(tokensToShield)
            store.shield.applications = shieldedApps
            logToSharedFile("Re-shielded \(tokensToShield.count) apps")
        }
    }

    private func getApplicationToken(forTokenHash hash: String) -> ApplicationToken? {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let data = userDefaults.data(forKey: "intentionSelection"),
              let selection = try? PropertyListDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }

        for token in selection.applicationTokens {
            if stableIdentifier(for: token) == hash {
                return token
            }
        }
        return nil
    }

    private func stableIdentifier(for token: ApplicationToken) -> String {
        if let data = try? PropertyListEncoder().encode(token) {
            return data.base64EncodedString()
        }
        return String(token.hashValue)
    }

    // MARK: - Allowed Until Management

    private func clearAllowedUntil(forTokenHash hash: String) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else { return }

        var allowed = getAllowedUntilMap()
        allowed.removeValue(forKey: hash)

        if let data = try? JSONEncoder().encode(allowed) {
            userDefaults.set(data, forKey: "allowedUntil")
            userDefaults.synchronize()
        }
    }

    private func getAllowedUntilMap() -> [String: Date] {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let data = userDefaults.data(forKey: "allowedUntil"),
              let map = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return map
    }

    private func getAllowedTokenHashes() -> Set<String> {
        let map = getAllowedUntilMap()
        let now = Date()
        var allowed = Set<String>()
        for (hash, until) in map {
            if now < until {
                allowed.insert(hash)
            }
        }
        return allowed
    }

    // MARK: - Darwin Notifications

    private func postIntentionsDidChangeNotification() {
        let notificationName = "com.onelife.app.intentionsDidChange" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )
    }

    // MARK: - Logging

    private func logToSharedFile(_ message: String) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[MONITOR \(timestamp)] \(message)"

        var logs = userDefaults.stringArray(forKey: "deviceActivityMonitorLogs") ?? []
        logs.append(logEntry)
        if logs.count > 50 {
            logs = Array(logs.suffix(50))
        }
        userDefaults.set(logs, forKey: "deviceActivityMonitorLogs")
        userDefaults.synchronize()
    }
}
