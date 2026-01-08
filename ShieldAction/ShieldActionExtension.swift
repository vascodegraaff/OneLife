//
//  ShieldActionExtension.swift
//  ShieldAction
//
//  Created by Kei Fujikawa on 2023/08/21.
//

import Foundation
import ManagedSettings
import os.log

// Darwin notification name for cross-process communication
private let kIntentionsDidChangeNotification = "com.luminote.screentime.intentionsDidChange" as CFString

// Logger for debugging
private let logger = Logger(subsystem: "com.luminote.screentime.shieldaction", category: "ShieldAction")

class ShieldActionExtension: ShieldActionDelegate {

    private let suiteName = "group.com.luminote.screentime"
    private let store = ManagedSettingsStore()

    /// Post notification to main app that intentions changed
    private func postIntentionsDidChangeNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(kIntentionsDidChangeNotification),
            nil,
            nil,
            true
        )
    }

    /// Log to shared file for debugging (readable by main app)
    private func logToSharedFile(_ message: String) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"

        var logs = userDefaults.stringArray(forKey: "shieldActionLogs") ?? []
        logs.append(logEntry)
        // Keep only last 50 entries
        if logs.count > 50 {
            logs = Array(logs.suffix(50))
        }
        userDefaults.set(logs, forKey: "shieldActionLogs")
        userDefaults.synchronize()
    }

    // MARK: - Application Shield Actions

    /// Creates a stable identifier from ApplicationToken using Base64 encoded data
    private func stableIdentifier(for token: ApplicationToken) -> String {
        if let data = try? PropertyListEncoder().encode(token) {
            return data.base64EncodedString()
        }
        // Fallback - should not happen
        return String(token.hashValue)
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let tokenIdentifier = stableIdentifier(for: application)
        let shortId = String(tokenIdentifier.prefix(20)) + "..."

        // USE FAULT LEVEL - highest priority, ALWAYS shows in Console
        logger.fault("=== HANDLE CALLED === action: \(String(describing: action)) tokenId: \(shortId)")

        switch action {
        case .primaryButtonPressed:
            // "Nevermind" - User chose to stay focused, close the shield
            logger.fault("PRIMARY button pressed (Nevermind) for tokenId: \(shortId)")
            logToSharedFile("PRIMARY (Nevermind) pressed - tokenId: \(shortId)")
            completionHandler(.close)

        case .secondaryButtonPressed:
            // "Open [App]" - User wants to open the app
            logger.fault("SECONDARY button pressed (Open App) for tokenId: \(shortId)")
            logToSharedFile("SECONDARY (Open App) pressed - tokenId: \(shortId)")
            handleOpenApp(for: application, identifier: tokenIdentifier)
            completionHandler(.defer)

        @unknown default:
            logger.fault("Unknown action for tokenId: \(shortId)")
            logToSharedFile("UNKNOWN action - tokenId: \(shortId)")
            completionHandler(.close)
        }
    }

    // MARK: - Web Domain Shield Actions

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            incrementTotalAttempts()
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Category Shield Actions

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            incrementTotalAttempts()
            completionHandler(.defer)
        @unknown default:
            completionHandler(.close)
        }
    }

    // MARK: - Private Helpers

    private func handleOpenApp(for token: ApplicationToken, identifier: String) {
        let shortId = String(identifier.prefix(20)) + "..."
        // Use NSLog to bypass privacy redaction
        NSLog("=== handleOpenApp START === identifier: %@", shortId)
        logger.fault("=== handleOpenApp START === tokenId: \(shortId, privacy: .public)")
        logToSharedFile("handleOpenApp START - tokenId: \(shortId)")

        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            logger.fault("ERROR: Failed to get UserDefaults for suite: \(self.suiteName)")
            logToSharedFile("ERROR: Failed to get UserDefaults")
            return
        }
        logger.fault("UserDefaults OK for suite: \(self.suiteName)")

        // Increment total app open attempts
        incrementTotalAttempts()
        logToSharedFile("Incremented total attempts")

        // Remove this app from the shield to allow it to open
        var shieldedApps = store.shield.applications ?? Set<ApplicationToken>()
        let beforeCount = shieldedApps.count
        logger.fault("Shield BEFORE remove: \(beforeCount) apps")
        shieldedApps.remove(token)
        store.shield.applications = shieldedApps.isEmpty ? nil : shieldedApps
        logger.fault("Shield AFTER remove: \(shieldedApps.count) apps (removed tokenId: \(shortId))")
        logToSharedFile("Shield updated - before: \(beforeCount), after: \(shieldedApps.count)")

        // Default session duration if no intention found
        var sessionMinutes = 5
        var intentionFound = false
        var newOpenCount = 0

        // Try to find and update the intention
        if var intentions = loadIntentions() {
            logger.fault("Loaded \(intentions.count) intentions")
            logToSharedFile("Loaded \(intentions.count) intentions")

            if let index = intentions.firstIndex(where: { $0.tokenHash == identifier }) {
                intentionFound = true
                logger.fault("FOUND intention at index \(index) for tokenId: \(shortId)")

                // Check if we need to reset for new day
                let lastReset = intentions[index].lastResetDate
                if !Calendar.current.isDateInToday(lastReset) {
                    intentions[index].currentOpens = 0
                    intentions[index].lastResetDate = Date()
                    logger.fault("Reset daily counter (new day)")
                    logToSharedFile("Reset daily counter (new day)")
                }

                // Increment opens
                intentions[index].currentOpens += 1
                newOpenCount = intentions[index].currentOpens
                sessionMinutes = intentions[index].sessionDurationMinutes

                logger.fault("Intention opens: \(newOpenCount)/\(intentions[index].maxOpensPerDay), session: \(sessionMinutes)min")
                logToSharedFile("Intention found - opens: \(newOpenCount)/\(intentions[index].maxOpensPerDay), session: \(sessionMinutes)min")

                // Save updated intentions
                if let data = try? JSONEncoder().encode(intentions) {
                    userDefaults.set(data, forKey: "intentions")
                    logToSharedFile("Saved updated intentions")
                } else {
                    logToSharedFile("ERROR: Failed to encode intentions")
                }
            } else {
                // Use NSLog and privacy: .public to see actual values
                let storedShortIds = intentions.map { String($0.tokenHash.prefix(20)) + "..." }
                NSLog("NO matching intention for tokenId: %@", shortId)
                logger.fault("NO matching intention for tokenId: \(shortId, privacy: .public)")
                // Log all stored identifiers for comparison
                for (i, intention) in intentions.enumerated() {
                    let storedShort = String(intention.tokenHash.prefix(20)) + "..."
                    NSLog("  Stored[%d]: %@", i, storedShort)
                    logger.fault("  Stored[\(i)]: \(storedShort, privacy: .public)")
                }
                logToSharedFile("No matching intention for tokenId: \(shortId)")
            }
        } else {
            logger.fault("No intentions loaded (nil or decode error)")
            logToSharedFile("No intentions loaded (nil or decode error)")
        }

        // Always set allowedUntil timestamp
        let allowedUntil = Date().addingTimeInterval(TimeInterval(sessionMinutes * 60))
        setAllowedUntil(forTokenHash: identifier, until: allowedUntil)
        logToSharedFile("Set allowedUntil: \(allowedUntil)")

        // Force sync and notify main app
        userDefaults.synchronize()
        postIntentionsDidChangeNotification()

        logger.info("handleOpenApp completed. IntentionFound: \(intentionFound), NewOpens: \(newOpenCount)")
        logToSharedFile("handleOpenApp DONE - found: \(intentionFound), opens: \(newOpenCount)")
    }

    private func incrementTotalAttempts() {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else { return }

        // Increment total attempts
        let total = userDefaults.integer(forKey: "totalAppOpenAttempts")
        userDefaults.set(total + 1, forKey: "totalAppOpenAttempts")

        // Increment daily attempts (with reset check)
        let lastReset = userDefaults.object(forKey: "lastResetDate") as? Date ?? Date.distantPast
        if !Calendar.current.isDateInToday(lastReset) {
            userDefaults.set(0, forKey: "dailyAppOpenAttempts")
            userDefaults.set(Date(), forKey: "lastResetDate")
        }
        let daily = userDefaults.integer(forKey: "dailyAppOpenAttempts")
        userDefaults.set(daily + 1, forKey: "dailyAppOpenAttempts")
    }

    private func setAllowedUntil(forTokenHash hash: String, until date: Date) {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else { return }

        var allowed: [String: Date] = [:]
        if let data = userDefaults.data(forKey: "allowedUntil"),
           let existing = try? JSONDecoder().decode([String: Date].self, from: data) {
            allowed = existing
        }

        allowed[hash] = date

        if let data = try? JSONEncoder().encode(allowed) {
            userDefaults.set(data, forKey: "allowedUntil")
        }
    }

    private func loadIntentions() -> [StoredIntention]? {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let data = userDefaults.data(forKey: "intentions"),
              let intentions = try? JSONDecoder().decode([StoredIntention].self, from: data) else {
            return nil
        }
        return intentions
    }

    // Struct matching AppIntention for encoding/decoding
    private struct StoredIntention: Codable {
        var id: UUID
        var tokenHash: String
        var appDisplayName: String
        var maxOpensPerDay: Int
        var sessionDurationMinutes: Int
        var isActive: Bool
        var createdAt: Date
        var currentOpens: Int
        var streakDays: Int
        var lastResetDate: Date
    }
}
