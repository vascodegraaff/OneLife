import Foundation
import FamilyControls
import ManagedSettings

/// Represents a user's intention for limiting app usage
struct AppIntention: Codable, Identifiable {
    let id: UUID
    var tokenHash: String // Hash of ApplicationToken for identification
    var appDisplayName: String
    var maxOpensPerDay: Int
    var sessionDurationMinutes: Int // How long shield stays disabled after opening
    var isActive: Bool
    var createdAt: Date

    // Tracking
    var currentOpens: Int
    var streakDays: Int
    var lastResetDate: Date

    init(
        tokenHash: String,
        displayName: String,
        maxOpensPerDay: Int = 10,
        sessionDurationMinutes: Int = 5
    ) {
        self.id = UUID()
        self.tokenHash = tokenHash
        self.appDisplayName = displayName
        self.maxOpensPerDay = maxOpensPerDay
        self.sessionDurationMinutes = sessionDurationMinutes
        self.isActive = true
        self.createdAt = Date()
        self.currentOpens = 0
        self.streakDays = 0
        self.lastResetDate = Date()
    }

    /// Returns true if the user has exceeded their daily limit
    var isOverLimit: Bool {
        currentOpens >= maxOpensPerDay
    }

    /// Progress towards the daily limit (0.0 to 1.0+)
    var progress: Double {
        guard maxOpensPerDay > 0 else { return 0 }
        return Double(currentOpens) / Double(maxOpensPerDay)
    }

    /// Remaining opens for today
    var remainingOpens: Int {
        max(0, maxOpensPerDay - currentOpens)
    }
}

// MARK: - Token Identifier Helper
extension AppIntention {
    /// Creates a stable identifier string from an ApplicationToken for storage
    /// Uses Base64 encoded token data instead of hashValue (which varies between processes)
    static func hashFromToken(_ token: ApplicationToken) -> String {
        // Encode token to Data and convert to Base64 for a stable cross-process identifier
        if let data = try? PropertyListEncoder().encode(token) {
            return data.base64EncodedString()
        }
        // Fallback - should not happen since ApplicationToken is Codable
        return String(token.hashValue)
    }

    /// Decodes an ApplicationToken from a stored identifier string
    static func tokenFromIdentifier(_ identifier: String) -> ApplicationToken? {
        guard let data = Data(base64Encoded: identifier),
              let token = try? PropertyListDecoder().decode(ApplicationToken.self, from: data) else {
            return nil
        }
        return token
    }
}

// MARK: - Session Duration Options
extension AppIntention {
    static let sessionDurationOptions: [Int] = [1, 2, 3, 5, 10, 15, 20, 30]
    static let maxOpensOptions: [Int] = Array(1...20) + [25, 30, 40, 50]
}
