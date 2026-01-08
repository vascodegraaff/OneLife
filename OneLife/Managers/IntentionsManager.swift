import Foundation
import Combine
import FamilyControls
import ManagedSettings

/// Manages app intentions (usage limits per app)
final class IntentionsManager: ObservableObject {
    static let shared = IntentionsManager()

    @Published var intentions: [AppIntention] = []

    private let appGroupManager = AppGroupManager.shared
    private let store = ManagedSettingsStore()

    private init() {
        loadIntentions()
    }

    // MARK: - CRUD Operations

    func loadIntentions() {
        objectWillChange.send()
        intentions = appGroupManager.loadIntentions()
    }

    func addIntention(
        token: ApplicationToken,
        displayName: String,
        maxOpensPerDay: Int,
        sessionDurationMinutes: Int
    ) {
        let tokenHash = AppIntention.hashFromToken(token)

        // Check if intention already exists for this app
        if intentions.contains(where: { $0.tokenHash == tokenHash }) {
            return
        }

        let intention = AppIntention(
            tokenHash: tokenHash,
            displayName: displayName,
            maxOpensPerDay: maxOpensPerDay,
            sessionDurationMinutes: sessionDurationMinutes
        )

        intentions.append(intention)
        saveIntentions()

        // Store token in FamilyActivitySelection for later retrieval (icon display)
        appGroupManager.addTokenToIntentionSelection(token)

        // Apply shield for this app
        applyShieldForIntention(token: token)
    }

    func updateIntention(_ intention: AppIntention) {
        guard let index = intentions.firstIndex(where: { $0.id == intention.id }) else {
            return
        }
        intentions[index] = intention
        saveIntentions()
    }

    func removeIntention(id: UUID) {
        intentions.removeAll { $0.id == id }
        saveIntentions()
        // Note: Shield removal would need to be handled separately
        // by updating the ManagedSettingsStore
    }

    func removeIntention(forTokenHash hash: String) {
        intentions.removeAll { $0.tokenHash == hash }
        saveIntentions()
    }

    // MARK: - Shield Management

    private func applyShieldForIntention(token: ApplicationToken) {
        // Add this token to the shield
        var shieldedApps = store.shield.applications ?? Set<ApplicationToken>()
        shieldedApps.insert(token)
        store.shield.applications = shieldedApps
    }

    func applyAllIntentionShields(tokens: Set<ApplicationToken>) {
        // Shield all apps that have intentions
        var tokensToShield = Set<ApplicationToken>()

        for token in tokens {
            let hash = AppIntention.hashFromToken(token)
            if intentions.contains(where: { $0.tokenHash == hash && $0.isActive }) {
                // Check if currently allowed (within session time)
                if !appGroupManager.isCurrentlyAllowed(forTokenHash: hash) {
                    tokensToShield.insert(token)
                }
            }
        }

        if !tokensToShield.isEmpty {
            store.shield.applications = tokensToShield
        }
    }

    func removeShieldForToken(hash: String) {
        // This would need the actual token to remove from shield
        // For now, we can clear all shields if needed
        appGroupManager.clearAllowedUntil(forTokenHash: hash)
    }

    /// Re-applies shields for apps whose temporary access has expired
    func reapplyExpiredShields() {
        // Clear any expired allowances first
        appGroupManager.clearExpiredAllowances()

        // Get all active intentions and re-apply shields for apps that are no longer allowed
        var tokensToShield = Set<ApplicationToken>()

        for intention in intentions where intention.isActive {
            // Check if this app is currently allowed (within session time)
            if !appGroupManager.isCurrentlyAllowed(forTokenHash: intention.tokenHash) {
                // Session expired or never started - need to re-shield this app
                if let token = appGroupManager.getToken(forHash: intention.tokenHash) {
                    tokensToShield.insert(token)
                }
            }
        }

        // Apply shields for expired sessions
        if !tokensToShield.isEmpty {
            // Merge with any existing shields
            var currentShields = store.shield.applications ?? Set<ApplicationToken>()
            currentShields.formUnion(tokensToShield)
            store.shield.applications = currentShields
        }
    }

    // MARK: - Persistence

    private func saveIntentions() {
        appGroupManager.saveIntentions(intentions)
    }

    // MARK: - Queries

    func getIntention(forTokenHash hash: String) -> AppIntention? {
        return intentions.first { $0.tokenHash == hash }
    }

    func hasActiveIntention(forTokenHash hash: String) -> Bool {
        return intentions.contains { $0.tokenHash == hash && $0.isActive }
    }

    // MARK: - Daily Reset

    func resetDailyCounters() {
        for index in intentions.indices {
            // Check if user stayed under limit yesterday for streak
            let wasUnderLimit = intentions[index].currentOpens <= intentions[index].maxOpensPerDay
            if wasUnderLimit {
                intentions[index].streakDays += 1
            } else {
                intentions[index].streakDays = 0
            }

            intentions[index].currentOpens = 0
            intentions[index].lastResetDate = Date()
        }
        saveIntentions()
    }

    // MARK: - Statistics

    var totalIntentions: Int {
        intentions.count
    }

    var activeIntentions: Int {
        intentions.filter { $0.isActive }.count
    }

    var averageProgress: Double {
        guard !intentions.isEmpty else { return 0 }
        let total = intentions.reduce(0.0) { $0 + $1.progress }
        return total / Double(intentions.count)
    }
}
