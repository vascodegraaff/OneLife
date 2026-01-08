//
//  OneLifeApp.swift
//  OneLife
//
//  Created by Kei Fujikawa on 2023/08/11.
//

import SwiftUI

@main
struct OneLifeApp: App {
    @State private var openedFromShield = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "onelife" else { return }

        switch url.host {
        case "open":
            // App opened from shield secondary button
            openedFromShield = true
        case "settings":
            // Navigate to settings (could use @Environment(\.openURL) in iOS 16+)
            break
        default:
            break
        }
    }
}
