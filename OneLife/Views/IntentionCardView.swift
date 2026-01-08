import SwiftUI
import FamilyControls
import ManagedSettings

/// A compact card view showing an app intention's progress
struct IntentionCardView: View {
    let intention: AppIntention
    let token: ApplicationToken?
    var onTap: (() -> Void)?

    var progressColor: Color {
        if intention.isOverLimit {
            return .red
        } else if intention.progress > 0.7 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 8) {
                // App icon
                AppIconView(token: token, fallbackLetter: String(intention.appDisplayName.prefix(1)))
                    .frame(width: 50, height: 50)

                // Label
                Text("OPENS")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)

                // Progress text
                Text("\(intention.currentOpens)/\(intention.maxOpensPerDay)")
                    .font(.headline)
                    .foregroundColor(progressColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Separate view for app icon to avoid Label reuse issues
struct AppIconView: View {
    let token: ApplicationToken?
    let fallbackLetter: String

    var body: some View {
        Group {
            if let token = token {
                Label(token)
                    .labelStyle(.iconOnly)
                    .scaleEffect(1.5)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))

                    Text(fallbackLetter.uppercased())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Horizontal scrolling list of intention cards with add button
struct IntentionsHorizontalList: View {
    @ObservedObject var intentionsManager = IntentionsManager.shared
    @ObservedObject var appGroupManager = AppGroupManager.shared
    @State private var showingAddSheet = false
    @State private var selectedIntention: AppIntention?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "app.badge.checkmark")
                    .foregroundColor(.primary)
                Text("App Intentions")
                    .font(.headline)

                Spacer()

                Button(action: { intentionsManager.loadIntentions() }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // Horizontal scroll of cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(intentionsManager.intentions) { intention in
                        IntentionCardView(
                            intention: intention,
                            token: appGroupManager.getToken(forHash: intention.tokenHash)
                        ) {
                            selectedIntention = intention
                        }
                    }

                    // Add button
                    AddIntentionButton {
                        showingAddSheet = true
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            IntentionEditorSheet(mode: .add)
        }
        .sheet(item: $selectedIntention) { intention in
            IntentionEditorSheet(mode: .edit(intention))
        }
        .onAppear {
            // Reload both intentions and token selection
            intentionsManager.loadIntentions()
            appGroupManager.loadIntentionSelection()
        }
    }
}

/// Add button for creating new intentions
struct AddIntentionButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)

                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                Text(" ")
                    .font(.caption2)

                Text(" ")
                    .font(.headline)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    IntentionsHorizontalList()
        .padding()
        .background(Color(.systemGroupedBackground))
}
