//
//  ShieldConfigurationExtension.swift
//  ShieldConfig
//
//  Created by Kei Fujikawa on 2023/08/21.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private let suiteName = "group.com.onelife.app"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        let appName = application.localizedDisplayName ?? "this app"

        // Try to get intention data from App Groups
        let intentionData = getIntentionData(for: application)

        // Build subtitle with intention info
        var subtitleText = "Stay focused on your goals"
        var progressText = ""

        if let data = intentionData {
            subtitleText = "Don't open this app more than \(data.maxOpens) times today"
            progressText = "\(data.currentOpens)/\(data.maxOpens) Opens Today"
            if data.streakDays > 0 {
                progressText += "\n\(data.streakDays) Day Streak 🔥"
            }
        }

        let fullSubtitle = progressText.isEmpty ? subtitleText : "\(subtitleText)\n\n\(progressText)"

        return ShieldConfiguration(
            backgroundBlurStyle: UIBlurEffect.Style.dark,
            backgroundColor: UIColor.black,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "Open \(appName)?",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: fullSubtitle,
                color: UIColor.lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Nevermind",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Open \(appName)",
                color: UIColor.systemBlue
            )
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        // Use the same configuration for category-shielded apps
        return configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        let domainName = webDomain.domain ?? "this website"

        return ShieldConfiguration(
            backgroundBlurStyle: UIBlurEffect.Style.dark,
            backgroundColor: UIColor.black,
            icon: UIImage(named: "AppIcon"),
            title: ShieldConfiguration.Label(
                text: "Open \(domainName)?",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Stay focused on your goals",
                color: UIColor.lightGray
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Nevermind",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Website",
                color: UIColor.systemBlue
            )
        )
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: webDomain)
    }

    // MARK: - App Groups Data Access

    private struct IntentionDisplayData {
        let maxOpens: Int
        let currentOpens: Int
        let streakDays: Int
    }

    /// Creates a stable identifier from ApplicationToken using Base64 encoded data
    private func stableIdentifier(for token: ApplicationToken) -> String {
        if let data = try? PropertyListEncoder().encode(token) {
            return data.base64EncodedString()
        }
        return String(token.hashValue)
    }

    private func getIntentionData(for application: Application) -> IntentionDisplayData? {
        guard let userDefaults = UserDefaults(suiteName: suiteName),
              let data = userDefaults.data(forKey: "intentions"),
              let intentions = try? JSONDecoder().decode([StoredIntention].self, from: data) else {
            return nil
        }

        // Try to find matching intention by token identifier (Base64 encoded)
        if let token = application.token {
            let identifier = stableIdentifier(for: token)
            if let intention = intentions.first(where: { $0.tokenHash == identifier && $0.isActive }) {
                return IntentionDisplayData(
                    maxOpens: intention.maxOpensPerDay,
                    currentOpens: intention.currentOpens,
                    streakDays: intention.streakDays
                )
            }
        }

        return nil
    }

    // Minimal struct to decode intention data
    private struct StoredIntention: Codable {
        let tokenHash: String
        let maxOpensPerDay: Int
        let currentOpens: Int
        let streakDays: Int
        let isActive: Bool
    }
}
