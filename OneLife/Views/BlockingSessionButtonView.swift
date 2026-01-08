import SwiftUI
import FamilyControls

/// Button view for starting/stopping blocking sessions
struct BlockingSessionButtonView: View {
    @ObservedObject var sessionManager = BlockingSessionManager.shared
    @ObservedObject var familyControlModel = FamilyControlModel.shared

    @State private var timer: Timer?
    @State private var displayedDuration: String = "00:00:00"

    var hasAppsSelected: Bool {
        !familyControlModel.selectionToDiscourage.applicationTokens.isEmpty ||
        !familyControlModel.selectionToDiscourage.categoryTokens.isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            if sessionManager.isSessionActive {
                // Active session view
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "shield.fill")
                        Text("Session Active")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)

                    Text(displayedDuration)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green)
                )

                // End Session Button
                Button(action: { sessionManager.endSession() }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Session")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.red)
                    )
                }
            } else {
                // Start button
                Button(action: {
                    sessionManager.startSession(with: familyControlModel.selectionToDiscourage)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Blocking Session")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(hasAppsSelected ? Color.blue : Color.gray)
                    )
                }
                .disabled(!hasAppsSelected)

                if !hasAppsSelected {
                    Text("Select apps to block first")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: sessionManager.isSessionActive) { _, isActive in
            if isActive {
                startTimerIfNeeded()
            } else {
                stopTimer()
            }
        }
    }

    private func startTimerIfNeeded() {
        guard sessionManager.isSessionActive else { return }
        updateDuration()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateDuration()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateDuration() {
        displayedDuration = sessionManager.formattedSessionDuration
    }
}

#Preview {
    VStack {
        BlockingSessionButtonView()
    }
    .padding()
}
